/*
 * iic_sim.c - Bit-level open-drain I2C bus simulator.
 *
 * Electrical model
 * ----------------
 * Each wire is high when nobody pulls it low (pull-up resistor) and low when
 * the master or any slave pulls it low. The master's port callbacks update
 * its drive, then the simulator settles the lines and notifies the slaves of
 * every SCL edge and of START/STOP conditions. Slaves change SDA only while
 * SCL is low, as real I2C devices do.
 *
 * Slave protocol states
 * ---------------------
 *   ADDR      shift in 8 address bits; on the 8th falling edge compare
 *   ADDR_ACK  drive ACK (low) during the 9th clock, then switch to RX/TX
 *   RX        shift in 8 data bits, then ACK/NACK
 *   TX        drive 8 data bits, release SDA, sample the master's ACK
 *
 * A device that does not match the address ignores the rest of the
 * transaction until the next START/STOP.
 */
#include "iic_sim.h"

#include <stdlib.h>
#include <string.h>

typedef enum {
    SIM_KIND_EEPROM = 0,
    SIM_KIND_SENSOR,
    SIM_KIND_STRETCHER,
    SIM_KIND_DATA_NACK
} sim_kind_t;

typedef enum {
    SIM_IDLE = 0,
    SIM_ADDR,
    SIM_ADDR_ACK,
    SIM_RX,
    SIM_RX_ACK,
    SIM_TX,
    SIM_TX_ACK,
    SIM_IGNORE
} sim_state_t;

typedef struct {
    int used;
    sim_kind_t kind;
    uint8_t addr;
    sim_state_t state;

    unsigned bit;        /* address/data bits shifted so far (0..8) */
    uint8_t shift;       /* receive shift register */
    uint8_t tx_byte;     /* transmit shift register */
    int rw;              /* direction bit of the current address */
    int master_ack;      /* set when the master ACKs a transmitted byte */
    unsigned tx_bits;    /* data bits already transmitted (0..8) */
    unsigned tx_pos;     /* sensor byte position */

    int sda_low;         /* this slave pulls SDA low */
    int scl_low;         /* this slave pulls SCL low (clock stretching) */
    int stretching;
    uint32_t stretch_ticks;     /* configured stretch length */
    uint32_t stretch_remaining; /* half-bit delays remaining */

    int has_ptr;
    uint8_t mem_ptr;
    uint8_t eeprom[IIC_SIM_EEPROM_SIZE];
    uint8_t sensor[IIC_SIM_SENSOR_MAX];
    size_t sensor_len;
} sim_dev_t;

struct iic_sim {
    sim_dev_t devs[IIC_SIM_MAX_DEVICES];

    int master_scl_low;
    int master_sda_low;
    int scl; /* settled electrical level, 1 = high */
    int sda;

    int stuck_hold;
    uint32_t stuck_remaining;

    iic_sim_stats_t stats;
};

/* ------------------------------------------------------------------------- */
/* Helpers                                                                   */
/* ------------------------------------------------------------------------- */

static void sim_update(iic_sim_t *sim);

static void sim_compute_lines(const iic_sim_t *sim, int *scl, int *sda)
{
    int scl_low = sim->master_scl_low;
    int sda_low = sim->master_sda_low;
    int i;

    if (sim->stuck_hold) {
        sda_low = 1;
    }
    for (i = 0; i < IIC_SIM_MAX_DEVICES; ++i) {
        const sim_dev_t *dev = &sim->devs[i];
        if (dev->used) {
            scl_low = scl_low || dev->scl_low;
            sda_low = sda_low || dev->sda_low;
        }
    }
    *scl = !scl_low;
    *sda = !sda_low;
}

static void sim_present_tx_bit(sim_dev_t *dev)
{
    /* A 1 bit is released (pulled high), a 0 bit is driven low. */
    dev->sda_low = ((dev->tx_byte & 0x80U) == 0) ? 1 : 0;
}

static uint8_t sim_next_tx_byte(sim_dev_t *dev)
{
    switch (dev->kind) {
    case SIM_KIND_EEPROM: {
        uint8_t value = dev->eeprom[dev->mem_ptr];
        dev->mem_ptr = (uint8_t)(dev->mem_ptr + 1U);
        return value;
    }
    case SIM_KIND_SENSOR:
    case SIM_KIND_STRETCHER: {
        uint8_t value;
        if (dev->sensor_len == 0) {
            return 0xFFU;
        }
        value = dev->sensor[dev->tx_pos % (unsigned)dev->sensor_len];
        dev->tx_pos = (dev->tx_pos + 1U) % (unsigned)dev->sensor_len;
        return value;
    }
    default:
        return 0xFFU;
    }
}

static void sim_process_rx_byte(sim_dev_t *dev, uint8_t value)
{
    if (dev->kind != SIM_KIND_EEPROM) {
        return; /* sensor models ignore writes */
    }
    if (!dev->has_ptr) {
        dev->mem_ptr = value; /* first write byte selects the memory address */
        dev->has_ptr = 1;
    } else {
        dev->eeprom[dev->mem_ptr] = value;
        dev->mem_ptr = (uint8_t)(dev->mem_ptr + 1U);
    }
}

static void sim_dev_begin(sim_dev_t *dev)
{
    dev->state = SIM_ADDR;
    dev->bit = 0;
    dev->shift = 0;
    dev->tx_byte = 0;
    dev->rw = 0;
    dev->master_ack = 0;
    dev->tx_bits = 0;
    dev->tx_pos = 0;
    dev->sda_low = 0;
    dev->scl_low = 0;
    dev->stretching = 0;
    dev->stretch_remaining = 0;
    dev->has_ptr = 0;
}

static void sim_dev_end(sim_dev_t *dev)
{
    dev->state = SIM_IDLE;
    dev->bit = 0;
    dev->shift = 0;
    dev->tx_byte = 0;
    dev->rw = 0;
    dev->master_ack = 0;
    dev->tx_bits = 0;
    dev->tx_pos = 0;
    dev->sda_low = 0;
    dev->scl_low = 0;
    dev->stretching = 0;
    dev->stretch_remaining = 0;
    dev->has_ptr = 0;
}

static void sim_start_condition(iic_sim_t *sim)
{
    int i;
    for (i = 0; i < IIC_SIM_MAX_DEVICES; ++i) {
        if (sim->devs[i].used) {
            sim_dev_begin(&sim->devs[i]);
        }
    }
}

static void sim_stop_condition(iic_sim_t *sim)
{
    int i;
    for (i = 0; i < IIC_SIM_MAX_DEVICES; ++i) {
        if (sim->devs[i].used) {
            sim_dev_end(&sim->devs[i]);
        }
    }
}

static void sim_dev_scl_rising(sim_dev_t *dev, int sda)
{
    switch (dev->state) {
    case SIM_ADDR:
    case SIM_RX:
        if (dev->bit < 8) {
            dev->shift = (uint8_t)(((uint32_t)dev->shift << 1) |
                                   (sda ? 1U : 0U));
            ++dev->bit;
        }
        break;
    case SIM_TX_ACK:
        dev->master_ack = (sda == 0);
        break;
    default:
        break;
    }
}

static void sim_dev_scl_falling(iic_sim_t *sim, sim_dev_t *dev)
{
    switch (dev->state) {
    case SIM_ADDR:
        if (dev->bit == 8) {
            if ((dev->shift >> 1) == dev->addr) {
                dev->rw = dev->shift & 0x01;
                dev->sda_low = 1; /* ACK */
                dev->state = SIM_ADDR_ACK;
                if (dev->kind == SIM_KIND_STRETCHER && dev->stretch_ticks > 0) {
                    /* Hold SCL low until the master has waited long enough. */
                    dev->scl_low = 1;
                    dev->stretching = 1;
                    dev->stretch_remaining = dev->stretch_ticks;
                    ++sim->stats.stretch_events;
                }
            } else {
                dev->state = SIM_IGNORE;
            }
            dev->bit = 0;
            dev->shift = 0;
        }
        break;

    case SIM_ADDR_ACK:
        dev->sda_low = 0;
        if (dev->rw) {
            if (dev->kind == SIM_KIND_DATA_NACK) {
                dev->state = SIM_IGNORE;
                break;
            }
            dev->tx_byte = sim_next_tx_byte(dev);
            dev->tx_bits = 0;
            sim_present_tx_bit(dev);
            dev->state = SIM_TX;
        } else {
            dev->state = SIM_RX;
            dev->bit = 0;
            dev->shift = 0;
        }
        break;

    case SIM_RX:
        if (dev->bit == 8) {
            int ack = 1;
            if (dev->kind == SIM_KIND_DATA_NACK) {
                ack = 0; /* ACK the address, reject the first data byte */
            } else {
                sim_process_rx_byte(dev, dev->shift);
            }
            dev->sda_low = ack ? 1 : 0;
            dev->state = SIM_RX_ACK;
            dev->bit = 0;
            dev->shift = 0;
        }
        break;

    case SIM_RX_ACK:
        dev->sda_low = 0;
        dev->state = SIM_RX;
        break;

    case SIM_TX:
        ++dev->tx_bits;
        if (dev->tx_bits >= 8) {
            dev->sda_low = 0; /* release SDA for the master's ACK/NACK */
            dev->state = SIM_TX_ACK;
        } else {
            dev->tx_byte = (uint8_t)(dev->tx_byte << 1);
            sim_present_tx_bit(dev);
        }
        break;

    case SIM_TX_ACK:
        if (dev->master_ack) {
            dev->tx_byte = sim_next_tx_byte(dev);
            dev->tx_bits = 0;
            sim_present_tx_bit(dev);
            dev->state = SIM_TX;
        } else {
            dev->state = SIM_IDLE;
        }
        break;

    default:
        break;
    }
}

static void sim_scl_rising(iic_sim_t *sim, int sda)
{
    int i;
    for (i = 0; i < IIC_SIM_MAX_DEVICES; ++i) {
        if (sim->devs[i].used) {
            sim_dev_scl_rising(&sim->devs[i], sda);
        }
    }
}

static void sim_scl_falling(iic_sim_t *sim)
{
    int i;

    ++sim->stats.scl_falling_edges;
    if (sim->stuck_hold && sim->stuck_remaining > 0) {
        --sim->stuck_remaining;
        if (sim->stuck_remaining == 0) {
            sim->stuck_hold = 0;
        }
    }
    for (i = 0; i < IIC_SIM_MAX_DEVICES; ++i) {
        if (sim->devs[i].used) {
            sim_dev_scl_falling(sim, &sim->devs[i]);
        }
    }
}

/*
 * Settle the bus after any drive change. Device changes triggered by one edge
 * are folded into the same iteration; the loop terminates when the levels stop
 * changing (normally after one or two iterations).
 */
static void sim_update(iic_sim_t *sim)
{
    int iter;
    for (iter = 0; iter < 64; ++iter) {
        int scl;
        int sda;
        int old_scl = sim->scl;
        int old_sda = sim->sda;

        sim_compute_lines(sim, &scl, &sda);
        if (scl == old_scl && sda == old_sda) {
            return;
        }

        /* SDA edges while SCL is high are START/STOP conditions. */
        if (old_scl && scl) {
            if (old_sda && !sda) {
                ++sim->stats.starts;
                sim_start_condition(sim);
            } else if (!old_sda && sda) {
                ++sim->stats.stops;
                sim_stop_condition(sim);
            }
        }

        if (!old_scl && scl) {
            sim_scl_rising(sim, sda);
        } else if (old_scl && !scl) {
            sim_scl_falling(sim);
        }

        sim->scl = scl;
        sim->sda = sda;
    }
}

/* ------------------------------------------------------------------------- */
/* Port callbacks                                                            */
/* ------------------------------------------------------------------------- */

static void sim_scl_write(void *ctx, int level)
{
    iic_sim_t *sim = (iic_sim_t *)ctx;
    sim->master_scl_low = (level == 0);
    sim_update(sim);
}

static int sim_scl_read(void *ctx)
{
    const iic_sim_t *sim = (const iic_sim_t *)ctx;
    return sim->scl;
}

static void sim_sda_write(void *ctx, int level)
{
    iic_sim_t *sim = (iic_sim_t *)ctx;
    sim->master_sda_low = (level == 0);
    sim_update(sim);
}

static int sim_sda_read(void *ctx)
{
    const iic_sim_t *sim = (const iic_sim_t *)ctx;
    return sim->sda;
}

static void sim_delay(void *ctx)
{
    iic_sim_t *sim = (iic_sim_t *)ctx;
    int i;

    for (i = 0; i < IIC_SIM_MAX_DEVICES; ++i) {
        sim_dev_t *dev = &sim->devs[i];
        if (dev->used && dev->stretching && dev->stretch_remaining > 0) {
            --dev->stretch_remaining;
            if (dev->stretch_remaining == 0) {
                dev->stretching = 0;
                dev->scl_low = 0;
            }
        }
    }
    sim_update(sim);
}

/* ------------------------------------------------------------------------- */
/* Public API                                                                */
/* ------------------------------------------------------------------------- */

iic_sim_t *iic_sim_new(void)
{
    iic_sim_t *sim = (iic_sim_t *)calloc(1, sizeof(*sim));

    if (sim != NULL) {
        sim->scl = 1;
        sim->sda = 1;
    }
    return sim;
}

void iic_sim_free(iic_sim_t *sim)
{
    free(sim);
}

iic_port_t iic_sim_port(iic_sim_t *sim)
{
    iic_port_t port;

    memset(&port, 0, sizeof(port));
    if (sim == NULL) {
        return port;
    }
    port.ctx = sim;
    port.scl_write = sim_scl_write;
    port.scl_read = sim_scl_read;
    port.sda_write = sim_sda_write;
    port.sda_read = sim_sda_read;
    port.delay_half_bit = sim_delay;
    return port;
}

static int sim_add_device(iic_sim_t *sim, uint8_t addr7, sim_kind_t kind,
                          uint32_t stretch_ticks)
{
    int slot = -1;
    int i;

    if (sim == NULL || addr7 > IIC_7BIT_ADDR_MAX) {
        return -1;
    }
    for (i = 0; i < IIC_SIM_MAX_DEVICES; ++i) {
        if (sim->devs[i].used) {
            if (sim->devs[i].addr == addr7) {
                return -1; /* duplicate address */
            }
        } else if (slot < 0) {
            slot = i;
        }
    }
    if (slot < 0) {
        return -1;
    }

    memset(&sim->devs[slot], 0, sizeof(sim->devs[slot]));
    sim->devs[slot].used = 1;
    sim->devs[slot].kind = kind;
    sim->devs[slot].addr = addr7;
    sim->devs[slot].state = SIM_IDLE;
    sim->devs[slot].sensor_len = 2;
    sim->devs[slot].stretch_ticks = stretch_ticks;
    if (kind == SIM_KIND_STRETCHER) {
        sim->devs[slot].sensor[0] = 0x5A;
        sim->devs[slot].sensor[1] = 0xA5;
    }
    return slot;
}

int iic_sim_add_eeprom(iic_sim_t *sim, uint8_t addr7)
{
    return sim_add_device(sim, addr7, SIM_KIND_EEPROM, 0);
}

int iic_sim_add_sensor(iic_sim_t *sim, uint8_t addr7)
{
    return sim_add_device(sim, addr7, SIM_KIND_SENSOR, 0);
}

int iic_sim_add_stretcher(iic_sim_t *sim, uint8_t addr7, uint32_t stretch_ticks)
{
    return sim_add_device(sim, addr7, SIM_KIND_STRETCHER, stretch_ticks);
}

int iic_sim_add_data_nack(iic_sim_t *sim, uint8_t addr7)
{
    return sim_add_device(sim, addr7, SIM_KIND_DATA_NACK, 0);
}

uint8_t *iic_sim_eeprom(iic_sim_t *sim, int handle)
{
    if (sim == NULL || handle < 0 || handle >= IIC_SIM_MAX_DEVICES) {
        return NULL;
    }
    if (!sim->devs[handle].used || sim->devs[handle].kind != SIM_KIND_EEPROM) {
        return NULL;
    }
    return sim->devs[handle].eeprom;
}

int iic_sim_set_sensor(iic_sim_t *sim, int handle, const uint8_t *data, size_t len)
{
    if (sim == NULL || data == NULL || handle < 0 ||
        handle >= IIC_SIM_MAX_DEVICES || len == 0 ||
        len > IIC_SIM_SENSOR_MAX) {
        return -1;
    }
    if (!sim->devs[handle].used) {
        return -1;
    }
    if (sim->devs[handle].kind != SIM_KIND_SENSOR &&
        sim->devs[handle].kind != SIM_KIND_STRETCHER) {
        return -1;
    }
    memcpy(sim->devs[handle].sensor, data, len);
    sim->devs[handle].sensor_len = len;
    return 0;
}

void iic_sim_hold_sda(iic_sim_t *sim, uint32_t release_after_scl_falls)
{
    if (sim == NULL) {
        return;
    }
    sim->stuck_hold = 1;
    sim->stuck_remaining = release_after_scl_falls;
    sim_update(sim);
}

void iic_sim_release_sda(iic_sim_t *sim)
{
    if (sim == NULL) {
        return;
    }
    sim->stuck_hold = 0;
    sim->stuck_remaining = 0;
    sim_update(sim);
}

iic_sim_stats_t iic_sim_stats(const iic_sim_t *sim)
{
    iic_sim_stats_t stats;

    memset(&stats, 0, sizeof(stats));
    if (sim != NULL) {
        stats = sim->stats;
    }
    return stats;
}
