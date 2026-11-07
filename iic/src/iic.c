/*
 * iic.c - Portable, blocking I2C master built on five port callbacks.
 *
 * The generated waveform follows the I2C-bus specification:
 *   START : SDA falls while SCL is high
 *   bit   : SDA changes while SCL is low, sampled while SCL is high
 *   STOP  : SDA rises while SCL is high
 *
 * Every transfer uses open-drain emulation: writing 1 releases the line and
 * writing 0 pulls it low, exactly like a GPIO configured as open-drain.
 */
#include "iic.h"

#include <string.h>

/* ------------------------------------------------------------------------- */
/* Small helpers                                                             */
/* ------------------------------------------------------------------------- */

static int iic_addr_valid(uint8_t addr7)
{
    return addr7 <= IIC_7BIT_ADDR_MAX;
}

static int iic_ready(const iic_bus_t *bus)
{
    return bus != NULL && bus->initialized != 0 &&
           bus->config.port.delay_half_bit != NULL;
}

static void iic_delay(iic_bus_t *bus)
{
    bus->config.port.delay_half_bit(bus->config.port.ctx);
}

static void iic_release_lines(iic_bus_t *bus)
{
    bus->config.port.sda_write(bus->config.port.ctx, 1);
    bus->config.port.scl_write(bus->config.port.ctx, 1);
}

/*
 * Release SCL and wait until it is actually high. A slave may stretch the
 * clock by keeping SCL low; each poll costs one half-bit delay. This also
 * bounds the wait, so a dead bus cannot hang the caller forever.
 */
static iic_status_t iic_wait_scl_high(iic_bus_t *bus)
{
    const iic_port_t *port = &bus->config.port;
    uint32_t loops = bus->config.scl_timeout_loops;
    uint32_t i;

    port->scl_write(port->ctx, 1);
    for (i = 0; i < loops; ++i) {
        if (port->scl_read(port->ctx) != 0) {
            port->delay_half_bit(port->ctx);
            return IIC_OK;
        }
        port->delay_half_bit(port->ctx);
    }
    return IIC_ERR_TIMEOUT;
}

/* START condition; the bus is left with SCL low. */
static iic_status_t iic_start(iic_bus_t *bus)
{
    const iic_port_t *port = &bus->config.port;
    iic_status_t status;

    /* Make sure both lines are released; SCL must be high before SDA falls. */
    port->sda_write(port->ctx, 1);
    iic_delay(bus);
    status = iic_wait_scl_high(bus);
    if (status != IIC_OK) {
        return status;
    }
    if (port->sda_read(port->ctx) == 0) {
        return IIC_ERR_BUS; /* somebody else holds SDA low */
    }

    port->sda_write(port->ctx, 0);
    iic_delay(bus);
    port->scl_write(port->ctx, 0);
    iic_delay(bus);
    return IIC_OK;
}

/* STOP condition; both lines are released afterwards. */
static iic_status_t iic_stop(iic_bus_t *bus)
{
    const iic_port_t *port = &bus->config.port;
    iic_status_t status;

    /* SCL low, then SDA low, then SCL high, then SDA high. */
    port->scl_write(port->ctx, 0);
    port->sda_write(port->ctx, 0);
    iic_delay(bus);
    status = iic_wait_scl_high(bus);
    iic_delay(bus);
    port->sda_write(port->ctx, 1);
    iic_delay(bus);
    return status;
}

/* Clock out one byte and sample the ACK bit. */
static iic_status_t iic_write_byte(iic_bus_t *bus, uint8_t value, int *acked)
{
    const iic_port_t *port = &bus->config.port;
    iic_status_t status;
    int bit;

    *acked = 0;
    for (bit = 7; bit >= 0; --bit) {
        port->sda_write(port->ctx, (value >> bit) & 0x01);
        iic_delay(bus);
        status = iic_wait_scl_high(bus);
        if (status != IIC_OK) {
            return status;
        }
        port->scl_write(port->ctx, 0);
        iic_delay(bus);
    }

    /* Ninth clock: release SDA, let the slave drive ACK low or leave it high. */
    port->sda_write(port->ctx, 1);
    iic_delay(bus);
    status = iic_wait_scl_high(bus);
    if (status != IIC_OK) {
        return status;
    }
    *acked = (port->sda_read(port->ctx) == 0);
    port->scl_write(port->ctx, 0);
    iic_delay(bus);
    return IIC_OK;
}

/* Clock in one byte and send ACK (ack != 0) or NACK (ack == 0). */
static iic_status_t iic_read_byte(iic_bus_t *bus, uint8_t *value, int ack)
{
    const iic_port_t *port = &bus->config.port;
    iic_status_t status;
    uint8_t result = 0;
    int bit;

    port->sda_write(port->ctx, 1); /* release SDA so the slave can drive it */
    for (bit = 0; bit < 8; ++bit) {
        iic_delay(bus);
        status = iic_wait_scl_high(bus);
        if (status != IIC_OK) {
            return status;
        }
        result = (uint8_t)(((uint32_t)result << 1) |
                           (port->sda_read(port->ctx) ? 0x01U : 0x00U));
        port->scl_write(port->ctx, 0);
        iic_delay(bus);
    }

    /* Ninth clock: ACK except for the final byte of a read. */
    port->sda_write(port->ctx, ack ? 0 : 1);
    iic_delay(bus);
    status = iic_wait_scl_high(bus);
    if (status != IIC_OK) {
        return status;
    }
    port->scl_write(port->ctx, 0);
    iic_delay(bus);
    port->sda_write(port->ctx, 1);

    *value = result;
    return IIC_OK;
}

/* Finish a transfer: STOP on success/NACK, or release the bus on hard errors. */
static iic_status_t iic_finish(iic_bus_t *bus, iic_status_t status)
{
    if (status == IIC_OK) {
        iic_status_t stop_status = iic_stop(bus);
        if (stop_status != IIC_OK) {
            status = stop_status;
        }
    } else if (status == IIC_ERR_NACK_ADDR || status == IIC_ERR_NACK_DATA) {
        (void)iic_stop(bus); /* try to leave the bus idle even after a NACK */
    } else {
        /* A timeout or stuck bus may make a STOP impossible; just release. */
        iic_release_lines(bus);
        iic_delay(bus);
    }
    ++bus->transactions;
    return status;
}

static iic_status_t iic_recover_impl(iic_bus_t *bus)
{
    const iic_port_t *port = &bus->config.port;
    uint8_t clocks = bus->config.recover_clocks;
    uint8_t i;

    port->sda_write(port->ctx, 1);
    port->scl_write(port->ctx, 1);
    iic_delay(bus);

    /* A slave cannot hold SCL low forever during recovery; if it does, fail. */
    if (iic_wait_scl_high(bus) != IIC_OK) {
        iic_release_lines(bus);
        return IIC_ERR_BUS;
    }

    /* Up to nine clocks release a slave that is stuck in the middle of a bit. */
    for (i = 0; i < clocks && port->sda_read(port->ctx) == 0; ++i) {
        port->scl_write(port->ctx, 0);
        iic_delay(bus);
        if (iic_wait_scl_high(bus) != IIC_OK) {
            iic_release_lines(bus);
            return IIC_ERR_BUS;
        }
    }
    if (port->sda_read(port->ctx) == 0) {
        iic_release_lines(bus);
        return IIC_ERR_BUS;
    }

    /* Generate a STOP so every slave returns to its idle state. */
    port->scl_write(port->ctx, 0);
    port->sda_write(port->ctx, 0);
    iic_delay(bus);
    if (iic_wait_scl_high(bus) != IIC_OK) {
        iic_release_lines(bus);
        return IIC_ERR_BUS;
    }
    iic_delay(bus);
    port->sda_write(port->ctx, 1);
    iic_delay(bus);

    return (port->sda_read(port->ctx) != 0) ? IIC_OK : IIC_ERR_BUS;
}

/* ------------------------------------------------------------------------- */
/* Public API                                                                */
/* ------------------------------------------------------------------------- */

iic_status_t iic_init(iic_bus_t *bus, const iic_config_t *config)
{
    iic_config_t effective;
    const iic_port_t *port;
    iic_status_t status;

    if (bus == NULL || config == NULL) {
        return IIC_ERR_PARAM;
    }
    if (config->port.scl_write == NULL || config->port.scl_read == NULL ||
        config->port.sda_write == NULL || config->port.sda_read == NULL ||
        config->port.delay_half_bit == NULL) {
        return IIC_ERR_PARAM;
    }

    effective = *config;
    if (effective.scl_timeout_loops == 0) {
        effective.scl_timeout_loops = IIC_DEFAULT_TIMEOUT_LOOPS;
    }
    if (effective.recover_clocks == 0) {
        effective.recover_clocks = IIC_DEFAULT_RECOVER_CLOCKS;
    }
    if (effective.recover_clocks > IIC_MAX_RECOVER_CLOCKS) {
        effective.recover_clocks = IIC_MAX_RECOVER_CLOCKS;
    }

    memset(bus, 0, sizeof(*bus));
    bus->config = effective;
    bus->initialized = 1;

    port = &bus->config.port;
    port->sda_write(port->ctx, 1);
    port->scl_write(port->ctx, 1);
    iic_delay(bus);

    if (port->sda_read(port->ctx) != 0 && port->scl_read(port->ctx) != 0) {
        return IIC_OK;
    }

    status = iic_recover_impl(bus);
    if (status != IIC_OK) {
        iic_release_lines(bus);
        bus->initialized = 0;
        return status;
    }
    return IIC_OK;
}

void iic_deinit(iic_bus_t *bus)
{
    if (bus == NULL || bus->initialized == 0) {
        return;
    }
    iic_release_lines(bus);
    bus->initialized = 0;
}

iic_status_t iic_probe(iic_bus_t *bus, uint8_t addr7)
{
    return iic_write(bus, addr7, NULL, 0);
}

iic_status_t iic_write(iic_bus_t *bus, uint8_t addr7, const uint8_t *data, size_t len)
{
    iic_status_t status;
    size_t i;
    int acked;

    if (!iic_ready(bus) || !iic_addr_valid(addr7) ||
        (len > 0 && data == NULL)) {
        return IIC_ERR_PARAM;
    }

    status = iic_start(bus);
    if (status == IIC_OK) {
        status = iic_write_byte(bus, IIC_ADDR_WRITE(addr7), &acked);
        if (status == IIC_OK && !acked) {
            status = IIC_ERR_NACK_ADDR;
        }
        for (i = 0; status == IIC_OK && i < len; ++i) {
            status = iic_write_byte(bus, data[i], &acked);
            if (status == IIC_OK && !acked) {
                status = IIC_ERR_NACK_DATA;
            }
        }
    }
    return iic_finish(bus, status);
}

iic_status_t iic_read(iic_bus_t *bus, uint8_t addr7, uint8_t *data, size_t len)
{
    iic_status_t status;
    size_t i;
    int acked;

    if (!iic_ready(bus) || !iic_addr_valid(addr7) || data == NULL || len == 0) {
        return IIC_ERR_PARAM;
    }

    status = iic_start(bus);
    if (status == IIC_OK) {
        status = iic_write_byte(bus, IIC_ADDR_READ(addr7), &acked);
        if (status == IIC_OK && !acked) {
            status = IIC_ERR_NACK_ADDR;
        }
        for (i = 0; status == IIC_OK && i < len; ++i) {
            status = iic_read_byte(bus, &data[i], (i + 1 < len));
        }
    }
    return iic_finish(bus, status);
}

iic_status_t iic_write_read(iic_bus_t *bus, uint8_t addr7,
                            const uint8_t *tx, size_t tx_len,
                            uint8_t *rx, size_t rx_len)
{
    iic_status_t status;
    size_t i;
    int acked;

    if (!iic_ready(bus) || !iic_addr_valid(addr7) ||
        (tx_len > 0 && tx == NULL) || rx == NULL || rx_len == 0) {
        return IIC_ERR_PARAM;
    }

    status = iic_start(bus);
    if (status == IIC_OK) {
        status = iic_write_byte(bus, IIC_ADDR_WRITE(addr7), &acked);
        if (status == IIC_OK && !acked) {
            status = IIC_ERR_NACK_ADDR;
        }
        for (i = 0; status == IIC_OK && i < tx_len; ++i) {
            status = iic_write_byte(bus, tx[i], &acked);
            if (status == IIC_OK && !acked) {
                status = IIC_ERR_NACK_DATA;
            }
        }
    }

    /* Repeated START: the bus is currently left with SCL low. */
    if (status == IIC_OK) {
        status = iic_start(bus);
    }
    if (status == IIC_OK) {
        status = iic_write_byte(bus, IIC_ADDR_READ(addr7), &acked);
        if (status == IIC_OK && !acked) {
            status = IIC_ERR_NACK_ADDR;
        }
        for (i = 0; status == IIC_OK && i < rx_len; ++i) {
            status = iic_read_byte(bus, &rx[i], (i + 1 < rx_len));
        }
    }
    return iic_finish(bus, status);
}

iic_status_t iic_scan(iic_bus_t *bus, uint8_t *addrs, size_t capacity, size_t *found)
{
    size_t count = 0;
    uint8_t addr;

    if (!iic_ready(bus) || found == NULL ||
        (addrs == NULL && capacity > 0)) {
        return IIC_ERR_PARAM;
    }

    for (addr = 0x08; addr <= 0x77; ++addr) {
        iic_status_t status = iic_probe(bus, addr);

        if (status == IIC_OK) {
            if (count < capacity) {
                addrs[count] = addr;
            }
            ++count;
        } else if (status != IIC_ERR_NACK_ADDR) {
            *found = count;
            return status;
        }
    }
    *found = count;
    return IIC_OK;
}

iic_status_t iic_recover(iic_bus_t *bus)
{
    if (!iic_ready(bus)) {
        return IIC_ERR_PARAM;
    }
    return iic_recover_impl(bus);
}

const char *iic_status_str(iic_status_t status)
{
    switch (status) {
    case IIC_OK:
        return "OK";
    case IIC_ERR_PARAM:
        return "invalid argument";
    case IIC_ERR_NACK_ADDR:
        return "address NACK";
    case IIC_ERR_NACK_DATA:
        return "data NACK";
    case IIC_ERR_TIMEOUT:
        return "clock stretch timeout";
    case IIC_ERR_BUS:
        return "stuck bus";
    default:
        return "unknown error";
    }
}
