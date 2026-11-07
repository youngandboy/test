/*
 * iic_sim.h - Bit-level I2C bus simulator for testing the iic driver.
 *
 * The simulator models the two open-drain wires with pull-ups and a set of
 * simple slaves. Every master transition on SCL/SDA is seen by the slaves,
 * which drive their ACK/data bits and release the lines at the same points as
 * real hardware. This exercises the driver's actual bit-banging logic, not a
 * mocked transaction API.
 *
 * Supported slave models:
 *   - EEPROM:       write/read with an internal memory pointer (24Cxx style)
 *   - sensor:       read-only 2+ byte register
 *   - stretcher:    like a sensor, but holds SCL low (clock stretching) on
 *                   every address ACK
 *   - data NACK:    ACKs its address and NACKs the first data byte
 *
 * Fault injection:
 *   - iic_sim_hold_sda() simulates a slave that keeps SDA low, optionally
 *     releasing it after a number of SCL falling edges (bus recovery test).
 *   - a stretcher with a huge stretch count simulates a clock-stretch timeout.
 */
#ifndef IIC_SIM_H
#define IIC_SIM_H

#include <stddef.h>
#include <stdint.h>

#include "iic.h"

#ifdef __cplusplus
extern "C" {
#endif

#define IIC_SIM_MAX_DEVICES 8
#define IIC_SIM_EEPROM_SIZE 256
#define IIC_SIM_SENSOR_MAX 4

/** Simulator instance; create with iic_sim_new(), free with iic_sim_free(). */
typedef struct iic_sim iic_sim_t;

/** Observable bus activity, useful for assertions in tests. */
typedef struct {
    uint32_t starts;           /**< START conditions (including repeated). */
    uint32_t stops;            /**< STOP conditions. */
    uint32_t stretch_events;   /**< Address ACKs where a slave stretched SCL. */
    uint32_t scl_falling_edges; /**< Total SCL falling edges generated. */
} iic_sim_stats_t;

/** Create an idle bus (both lines released/high). Returns NULL on OOM. */
iic_sim_t *iic_sim_new(void);

/** Destroy a simulator. Safe with NULL. */
void iic_sim_free(iic_sim_t *sim);

/**
 * Return a port whose callbacks drive @p sim. The returned struct contains a
 * pointer to @p sim, so the simulator must outlive any driver using it.
 */
iic_port_t iic_sim_port(iic_sim_t *sim);

/**
 * Attach a slave. Addresses are 7-bit and must be unique.
 * @return a non-negative handle, or -1 on invalid address / no free slot.
 */
int iic_sim_add_eeprom(iic_sim_t *sim, uint8_t addr7);
int iic_sim_add_sensor(iic_sim_t *sim, uint8_t addr7);
int iic_sim_add_stretcher(iic_sim_t *sim, uint8_t addr7, uint32_t stretch_ticks);
int iic_sim_add_data_nack(iic_sim_t *sim, uint8_t addr7);

/** Direct access to an EEPROM's 256-byte memory (for preload/verification). */
uint8_t *iic_sim_eeprom(iic_sim_t *sim, int handle);

/** Set the bytes returned by a sensor or stretcher (1..IIC_SIM_SENSOR_MAX). */
int iic_sim_set_sensor(iic_sim_t *sim, int handle,
                       const uint8_t *data, size_t len);

/**
 * Hold SDA low, as a confused slave would after a reset in mid-transfer.
 * @param release_after_scl_falls Number of SCL falling edges after which the
 *        line is released; 0 holds SDA low forever (until explicitly released).
 */
void iic_sim_hold_sda(iic_sim_t *sim, uint32_t release_after_scl_falls);

/** Release a line held by iic_sim_hold_sda(). */
void iic_sim_release_sda(iic_sim_t *sim);

/** Snapshot the bus statistics. */
iic_sim_stats_t iic_sim_stats(const iic_sim_t *sim);

#ifdef __cplusplus
}
#endif

#endif /* IIC_SIM_H */
