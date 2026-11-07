/*
 * iic.h - Portable, blocking I2C (IIC) master for embedded systems.
 *
 * The driver is platform independent: it talks to the hardware through the
 * five callbacks in iic_port_t (open-drain SCL/SDA plus a half-bit delay).
 * The same code can therefore run on a microcontroller and on a host-side
 * simulation of the bus.
 *
 * Features:
 *   - 7-bit addressing, 100 kHz / 400 kHz or any rate the port can generate
 *   - write, read and combined write-read (repeated START) transfers
 *   - ACK/NACK reporting, SCL clock-stretching wait with timeout
 *   - bus idle check at init and 9-clock bus recovery for a stuck slave
 *   - no dynamic memory allocation, no global state
 *
 * This is a blocking driver. Do not call it from an interrupt handler unless
 * the port callbacks and the whole bus are protected from re-entrancy.
 */
#ifndef IIC_H
#define IIC_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/** Highest valid 7-bit I2C address. */
#define IIC_7BIT_ADDR_MAX 0x7FU

/** Used when iic_config_t::scl_timeout_loops is zero. */
#define IIC_DEFAULT_TIMEOUT_LOOPS 1000U

/** Used when iic_config_t::recover_clocks is zero. */
#define IIC_DEFAULT_RECOVER_CLOCKS 9U

/** Upper bound applied to iic_config_t::recover_clocks. */
#define IIC_MAX_RECOVER_CLOCKS 32U

/** Convert a 7-bit address to the byte placed on the bus (write direction). */
#define IIC_ADDR_WRITE(addr7) ((uint8_t)(((uint8_t)(addr7) & 0x7FU) << 1))
/** Convert a 7-bit address to the byte placed on the bus (read direction). */
#define IIC_ADDR_READ(addr7) ((uint8_t)((((uint8_t)(addr7) & 0x7FU) << 1) | 0x01U))

/** Return codes. Every transfer returns one of these values. */
typedef enum {
    IIC_OK = 0,           /**< Transfer completed and every byte was ACKed. */
    IIC_ERR_PARAM = -1,   /**< NULL/invalid argument or driver not initialised. */
    IIC_ERR_NACK_ADDR = -2, /**< No slave ACKed the address byte. */
    IIC_ERR_NACK_DATA = -3, /**< Slave NACKed a data byte. */
    IIC_ERR_TIMEOUT = -4,   /**< SCL stayed low (clock stretching) too long. */
    IIC_ERR_BUS = -5        /**< SDA stuck low / bus could not be recovered. */
} iic_status_t;

/**
 * Hardware access used by the driver.
 *
 * Every callback receives the same opaque @c ctx pointer. The SCL and SDA
 * pins must be configured as open-drain outputs with external (or internal)
 * pull-up resistors:
 *
 *   - write(1) releases the line (high impedance, pulled high by the resistor)
 *   - write(0) drives the line low
 *   - read() returns 1 when the line is high, 0 when it is low
 *
 * delay_half_bit() must delay for one half of an SCL period. For 100 kHz use
 * about 5 us, for 400 kHz about 1.25 us. The exact value is not used by the
 * driver; it only defines the generated bus clock.
 */
typedef struct {
    void *ctx;
    void (*scl_write)(void *ctx, int level);
    int (*scl_read)(void *ctx);
    void (*sda_write)(void *ctx, int level);
    int (*sda_read)(void *ctx);
    void (*delay_half_bit)(void *ctx);
} iic_port_t;

/** Driver configuration. Zero-initialise unused fields. */
typedef struct {
    iic_port_t port;            /**< Required; all five callbacks must be set. */
    uint32_t scl_timeout_loops; /**< Clock-stretch wait, in half-bit delays.
                                     Zero selects IIC_DEFAULT_TIMEOUT_LOOPS. */
    uint8_t recover_clocks;     /**< SCL pulses used for bus recovery.
                                     Zero selects IIC_DEFAULT_RECOVER_CLOCKS. */
} iic_config_t;

/** Driver instance. Allocate one per bus; it may live on the stack or in BSS. */
typedef struct {
    iic_config_t config; /**< Effective configuration (defaults applied). */
    uint32_t transactions; /**< Transfer calls attempted (including failures). */
    int initialized;     /**< Non-zero after a successful iic_init(). */
} iic_bus_t;

/**
 * Initialise the driver and bring the bus to the idle state.
 *
 * Both lines are released, then checked. If either line is held low (for
 * example a slave was reset in the middle of a read), the bus is recovered
 * with up to recover_clocks SCL pulses and a STOP condition.
 *
 * @return IIC_OK, IIC_ERR_PARAM for bad arguments, or IIC_ERR_BUS when the
 *         bus stays stuck.
 */
iic_status_t iic_init(iic_bus_t *bus, const iic_config_t *config);

/** Release both lines and mark the instance uninitialised. Safe with NULL. */
void iic_deinit(iic_bus_t *bus);

/**
 * Check whether a slave responds to its address (address-only write/START).
 *
 * @return IIC_OK when the address is ACKed, IIC_ERR_NACK_ADDR when it is not.
 */
iic_status_t iic_probe(iic_bus_t *bus, uint8_t addr7);

/**
 * Write @p len bytes to a slave.
 *
 * A zero-length write is a valid address probe. The first data byte is sent
 * as-is; for EEPROMs it is usually the memory address.
 *
 * @return IIC_OK, IIC_ERR_NACK_ADDR, IIC_ERR_NACK_DATA, IIC_ERR_TIMEOUT,
 *         IIC_ERR_BUS or IIC_ERR_PARAM.
 */
iic_status_t iic_write(iic_bus_t *bus, uint8_t addr7, const uint8_t *data, size_t len);

/**
 * Read @p len bytes from a slave (current-address read).
 *
 * The master ACKs every byte except the last one, then generates a STOP.
 *
 * @return IIC_OK or an error code; IIC_ERR_PARAM when len is zero.
 */
iic_status_t iic_read(iic_bus_t *bus, uint8_t addr7, uint8_t *data, size_t len);

/**
 * Combined transfer: write @p tx (register/address phase), repeated START,
 * then read @p rx bytes. tx_len may be zero.
 *
 * @return IIC_OK or an error code; IIC_ERR_PARAM when rx_len is zero.
 */
iic_status_t iic_write_read(iic_bus_t *bus, uint8_t addr7,
                            const uint8_t *tx, size_t tx_len,
                            uint8_t *rx, size_t rx_len);

/**
 * Probe the usable 7-bit address range 0x08..0x77 and collect responders.
 *
 * @param addrs    Output array, may be NULL only when capacity is zero.
 * @param capacity Number of entries available in @p addrs.
 * @param found    Number of devices found (may exceed capacity).
 * @return IIC_OK, or the first non-NACK error from a probe.
 */
iic_status_t iic_scan(iic_bus_t *bus, uint8_t *addrs, size_t capacity, size_t *found);

/**
 * Manually clear a stuck bus: release both lines, emit up to recover_clocks
 * SCL pulses until SDA is released, then generate a STOP.
 *
 * Call this after IIC_ERR_TIMEOUT or IIC_ERR_BUS. Returns IIC_ERR_BUS if SDA
 * (or SCL) cannot be released.
 */
iic_status_t iic_recover(iic_bus_t *bus);

/** Human-readable name of a status code (never NULL). */
const char *iic_status_str(iic_status_t status);

#ifdef __cplusplus
}
#endif

#endif /* IIC_H */
