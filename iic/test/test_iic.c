/*
 * test_iic.c - Simulation tests for the portable I2C master.
 *
 * Build and run:
 *   cc -std=c99 -Wall -Wextra -Wpedantic -Werror -Iinclude \
 *      src/iic.c sim/iic_sim.c test/test_iic.c -o test_iic && ./test_iic
 * or simply: make test
 */
#include <stdio.h>
#include <string.h>

#include "iic.h"
#include "iic_sim.h"

static int failures;

#define CHECK(cond)                                                            \
    do {                                                                       \
        if (!(cond)) {                                                         \
            fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond);   \
            ++failures;                                                        \
        }                                                                      \
    } while (0)

#define CHECK_EQ(actual, expected)                                             \
    do {                                                                       \
        long long check_a = (long long)(actual);                               \
        long long check_e = (long long)(expected);                             \
        if (check_a != check_e) {                                              \
            fprintf(stderr,                                                    \
                    "FAIL %s:%d: %s == %lld, expected %lld (%s)\n",           \
                    __FILE__, __LINE__, #actual, check_a, check_e, #expected); \
            ++failures;                                                        \
        }                                                                      \
    } while (0)

typedef struct {
    iic_sim_t *sim;
    iic_bus_t bus;
} fixture_t;

static void fixture_create(fixture_t *f, uint32_t timeout_loops)
{
    iic_config_t config;

    memset(f, 0, sizeof(*f));
    f->sim = iic_sim_new();
    CHECK(f->sim != NULL);

    memset(&config, 0, sizeof(config));
    config.port = iic_sim_port(f->sim);
    config.scl_timeout_loops = timeout_loops;
    CHECK_EQ(iic_init(&f->bus, &config), IIC_OK);
}

static void fixture_destroy(fixture_t *f)
{
    iic_deinit(&f->bus);
    iic_sim_free(f->sim);
    f->sim = NULL;
}

static void test_init_validation(void)
{
    fixture_t f;
    iic_config_t config;
    iic_bus_t bus;
    size_t found = 99;

    CHECK_EQ(iic_init(NULL, NULL), IIC_ERR_PARAM);

    memset(&config, 0, sizeof(config));
    CHECK_EQ(iic_init(&bus, &config), IIC_ERR_PARAM); /* no callbacks */

    f.sim = iic_sim_new();
    CHECK(f.sim != NULL);
    config.port = iic_sim_port(f.sim);
    CHECK_EQ(iic_init(&bus, &config), IIC_OK);
    CHECK(bus.initialized != 0);
    CHECK_EQ(iic_probe(&bus, 0x50), IIC_ERR_NACK_ADDR); /* empty bus */
    CHECK_EQ(iic_probe(&bus, 0x80), IIC_ERR_PARAM);

    CHECK_EQ(iic_scan(&bus, NULL, 0, NULL), IIC_ERR_PARAM);
    CHECK_EQ(iic_scan(&bus, NULL, 0, &found), IIC_OK);
    CHECK_EQ(found, 0);

    iic_deinit(&bus);
    CHECK(bus.initialized == 0);
    CHECK_EQ(iic_probe(&bus, 0x50), IIC_ERR_PARAM);
    CHECK_EQ(iic_recover(&bus), IIC_ERR_PARAM);

    /* A second init must work and clear the transaction counter. */
    bus.transactions = 42;
    CHECK_EQ(iic_init(&bus, &config), IIC_OK);
    CHECK_EQ(bus.transactions, 0);
    iic_deinit(&bus);
    iic_sim_free(f.sim);
}

static void test_probe_and_scan(void)
{
    fixture_t f;
    uint8_t addrs[8];
    size_t found = 0;

    fixture_create(&f, 0);
    CHECK(iic_sim_add_eeprom(f.sim, 0x50) >= 0);
    CHECK(iic_sim_add_sensor(f.sim, 0x48) >= 0);

    CHECK_EQ(iic_probe(&f.bus, 0x50), IIC_OK);
    CHECK_EQ(iic_probe(&f.bus, 0x48), IIC_OK);
    CHECK_EQ(iic_probe(&f.bus, 0x51), IIC_ERR_NACK_ADDR);
    CHECK_EQ(iic_probe(&f.bus, 0x00), IIC_ERR_NACK_ADDR);

    memset(addrs, 0, sizeof(addrs));
    CHECK_EQ(iic_scan(&f.bus, addrs, sizeof(addrs), &found), IIC_OK);
    CHECK_EQ(found, 2);
    CHECK_EQ(addrs[0], 0x48);
    CHECK_EQ(addrs[1], 0x50);

    /* The count reflects every device even when the output array is small. */
    found = 0;
    CHECK_EQ(iic_scan(&f.bus, addrs, 1, &found), IIC_OK);
    CHECK_EQ(found, 2);
    CHECK_EQ(addrs[0], 0x48);

    found = 0;
    CHECK_EQ(iic_scan(&f.bus, NULL, 0, &found), IIC_OK);
    CHECK_EQ(found, 2);

    fixture_destroy(&f);
}

static void test_eeprom_write_read(void)
{
    fixture_t f;
    uint8_t *mem;
    uint8_t tx[5] = {0x10, 0xDE, 0xAD, 0xBE, 0xEF};
    uint8_t rx[4];
    uint8_t expected[4];
    uint8_t reg = 0x10;
    iic_sim_stats_t stats;
    int eeprom;
    int i;

    fixture_create(&f, 0);
    eeprom = iic_sim_add_eeprom(f.sim, 0x50);
    CHECK(eeprom >= 0);
    mem = iic_sim_eeprom(f.sim, eeprom);
    CHECK(mem != NULL);
    for (i = 0; i < IIC_SIM_EEPROM_SIZE; ++i) {
        mem[i] = (uint8_t)(i ^ 0xA5);
    }
    for (i = 0; i < 4; ++i) {
        expected[i] = (uint8_t)((0x14 + i) ^ 0xA5);
    }

    stats = iic_sim_stats(f.sim);
    CHECK_EQ(iic_write(&f.bus, 0x50, tx, sizeof(tx)), IIC_OK);
    CHECK(mem[0x10] == 0xDE);
    CHECK(mem[0x11] == 0xAD);
    CHECK(mem[0x12] == 0xBE);
    CHECK(mem[0x13] == 0xEF);
    CHECK_EQ(iic_sim_stats(f.sim).starts, stats.starts + 1);
    CHECK_EQ(iic_sim_stats(f.sim).stops, stats.stops + 1);

    /* Random read: write the memory address, repeated START, read back. */
    stats = iic_sim_stats(f.sim);
    memset(rx, 0, sizeof(rx));
    CHECK_EQ(iic_write_read(&f.bus, 0x50, &reg, 1, rx, sizeof(rx)), IIC_OK);
    CHECK(memcmp(rx, tx + 1, sizeof(rx)) == 0);
    CHECK_EQ(iic_sim_stats(f.sim).starts, stats.starts + 2);
    CHECK_EQ(iic_sim_stats(f.sim).stops, stats.stops + 1);

    /* The EEPROM pointer now points past the four bytes just read. */
    memset(rx, 0, sizeof(rx));
    CHECK_EQ(iic_read(&f.bus, 0x50, rx, sizeof(rx)), IIC_OK);
    CHECK(memcmp(rx, expected, sizeof(rx)) == 0);

    /* Zero-length write is an address probe and must not touch memory. */
    CHECK_EQ(iic_write(&f.bus, 0x50, NULL, 0), IIC_OK);
    CHECK_EQ(f.bus.transactions, 4U);

    /* Argument validation. */
    CHECK_EQ(iic_read(&f.bus, 0x50, rx, 0), IIC_ERR_PARAM);
    CHECK_EQ(iic_write(&f.bus, 0x50, NULL, 1), IIC_ERR_PARAM);
    CHECK_EQ(iic_read(&f.bus, 0x50, NULL, 1), IIC_ERR_PARAM);
    CHECK_EQ(iic_write_read(&f.bus, 0x50, NULL, 1, rx, 1), IIC_ERR_PARAM);
    CHECK_EQ(iic_write_read(&f.bus, 0x50, &reg, 1, NULL, 1), IIC_ERR_PARAM);
    CHECK_EQ(iic_write_read(&f.bus, 0x50, &reg, 1, rx, 0), IIC_ERR_PARAM);
    CHECK_EQ(f.bus.transactions, 4U);

    fixture_destroy(&f);
}

static void test_combined_zero_length_write_phase(void)
{
    fixture_t f;
    uint8_t *mem;
    uint8_t ptr = 0x20;
    uint8_t rx[3];
    uint8_t expected[3];
    iic_sim_stats_t stats;
    int eeprom;
    int i;

    fixture_create(&f, 0);
    eeprom = iic_sim_add_eeprom(f.sim, 0x50);
    CHECK(eeprom >= 0);
    mem = iic_sim_eeprom(f.sim, eeprom);
    CHECK(mem != NULL);
    for (i = 0; i < 3; ++i) {
        mem[0x20 + i] = (uint8_t)(0x40 + i);
        expected[i] = (uint8_t)(0x40 + i);
    }

    /* Select the memory address without a following data byte. */
    CHECK_EQ(iic_write(&f.bus, 0x50, &ptr, 1), IIC_OK);

    /* tx_len == 0: START, address+W, repeated START, address+R, read. */
    stats = iic_sim_stats(f.sim);
    memset(rx, 0, sizeof(rx));
    CHECK_EQ(iic_write_read(&f.bus, 0x50, NULL, 0, rx, sizeof(rx)), IIC_OK);
    CHECK(memcmp(rx, expected, sizeof(rx)) == 0);
    CHECK_EQ(iic_sim_stats(f.sim).starts, stats.starts + 2);
    CHECK_EQ(iic_sim_stats(f.sim).stops, stats.stops + 1);

    fixture_destroy(&f);
}

static void test_nack(void)
{
    fixture_t f;
    uint8_t data[2] = {0x00, 0x11};
    uint8_t byte = 0;

    fixture_create(&f, 0);
    CHECK(iic_sim_add_eeprom(f.sim, 0x50) >= 0);
    CHECK(iic_sim_add_data_nack(f.sim, 0x60) >= 0);

    /* Address is ACKed, first data byte is NACKed. */
    CHECK_EQ(iic_write(&f.bus, 0x60, data, sizeof(data)), IIC_ERR_NACK_DATA);

    /* NACK must still leave the bus idle and usable. */
    CHECK_EQ(iic_probe(&f.bus, 0x50), IIC_OK);

    CHECK_EQ(iic_write(&f.bus, 0x51, data, 1), IIC_ERR_NACK_ADDR);
    CHECK_EQ(iic_read(&f.bus, 0x51, &byte, 1), IIC_ERR_NACK_ADDR);
    CHECK_EQ(iic_write_read(&f.bus, 0x51, NULL, 0, &byte, 1), IIC_ERR_NACK_ADDR);

    fixture_destroy(&f);
}

static void test_sensor(void)
{
    fixture_t f;
    uint8_t value[2] = {0x19, 0x20};
    uint8_t rx[2];
    int sensor;

    fixture_create(&f, 0);
    sensor = iic_sim_add_sensor(f.sim, 0x48);
    CHECK(sensor >= 0);
    CHECK_EQ(iic_sim_set_sensor(f.sim, sensor, value, sizeof(value)), 0);

    memset(rx, 0, sizeof(rx));
    CHECK_EQ(iic_read(&f.bus, 0x48, rx, sizeof(rx)), IIC_OK);
    CHECK(memcmp(rx, value, sizeof(rx)) == 0);

    /* A second read starts from the first register again. */
    memset(rx, 0, sizeof(rx));
    CHECK_EQ(iic_read(&f.bus, 0x48, rx, sizeof(rx)), IIC_OK);
    CHECK(memcmp(rx, value, sizeof(rx)) == 0);

    fixture_destroy(&f);
}

static void test_clock_stretching(void)
{
    fixture_t f;
    uint8_t value[2] = {0x12, 0x34};
    uint8_t rx[2];
    int stretcher;

    fixture_create(&f, 1000);
    stretcher = iic_sim_add_stretcher(f.sim, 0x30, 25);
    CHECK(stretcher >= 0);
    CHECK_EQ(iic_sim_set_sensor(f.sim, stretcher, value, sizeof(value)), 0);

    memset(rx, 0, sizeof(rx));
    CHECK_EQ(iic_read(&f.bus, 0x30, rx, sizeof(rx)), IIC_OK);
    CHECK(memcmp(rx, value, sizeof(rx)) == 0);
    CHECK_EQ(iic_sim_stats(f.sim).stretch_events, 1);

    /* Every address phase stretches, and the master keeps waiting. */
    CHECK_EQ(iic_read(&f.bus, 0x30, rx, sizeof(rx)), IIC_OK);
    CHECK_EQ(iic_sim_stats(f.sim).stretch_events, 2);

    fixture_destroy(&f);
}

static void test_clock_stretch_timeout(void)
{
    fixture_t f;
    uint8_t rx[2];

    fixture_create(&f, 40);
    CHECK(iic_sim_add_stretcher(f.sim, 0x30, 100000) >= 0);
    CHECK_EQ(iic_read(&f.bus, 0x30, rx, sizeof(rx)), IIC_ERR_TIMEOUT);
    CHECK_EQ(iic_sim_stats(f.sim).stretch_events, 1);

    /* The bus is intentionally left stuck by the slave in this test. */
    fixture_destroy(&f);
}

static void test_bus_recovery(void)
{
    fixture_t f;
    iic_config_t config;
    int eeprom;

    /* A slave that releases SDA after three clocks is cleared by init. */
    memset(&f, 0, sizeof(f));
    f.sim = iic_sim_new();
    CHECK(f.sim != NULL);
    eeprom = iic_sim_add_eeprom(f.sim, 0x50);
    CHECK(eeprom >= 0);
    iic_sim_hold_sda(f.sim, 3);
    memset(&config, 0, sizeof(config));
    config.port = iic_sim_port(f.sim);
    CHECK_EQ(iic_init(&f.bus, &config), IIC_OK);
    CHECK_EQ(iic_probe(&f.bus, 0x50), IIC_OK);
    iic_deinit(&f.bus);
    iic_sim_free(f.sim);

    /* A permanently stuck bus must make init fail cleanly. */
    memset(&f, 0, sizeof(f));
    f.sim = iic_sim_new();
    CHECK(f.sim != NULL);
    CHECK(iic_sim_add_eeprom(f.sim, 0x50) >= 0);
    iic_sim_hold_sda(f.sim, 0);
    memset(&config, 0, sizeof(config));
    config.port = iic_sim_port(f.sim);
    CHECK_EQ(iic_init(&f.bus, &config), IIC_ERR_BUS);
    CHECK(f.bus.initialized == 0);
    iic_sim_free(f.sim);

    /* Explicit recovery after the lines are released again. */
    fixture_create(&f, 0);
    CHECK(iic_sim_add_eeprom(f.sim, 0x50) >= 0);
    iic_sim_hold_sda(f.sim, 2);
    CHECK_EQ(iic_recover(&f.bus), IIC_OK);
    CHECK_EQ(iic_probe(&f.bus, 0x50), IIC_OK);

    /* A permanently stuck line cannot be recovered. */
    iic_sim_hold_sda(f.sim, 0);
    CHECK_EQ(iic_recover(&f.bus), IIC_ERR_BUS);
    iic_sim_release_sda(f.sim);
    CHECK_EQ(iic_probe(&f.bus, 0x50), IIC_OK);

    /* Recovery of an already idle bus is harmless. */
    CHECK_EQ(iic_recover(&f.bus), IIC_OK);
    CHECK_EQ(iic_probe(&f.bus, 0x50), IIC_OK);

    fixture_destroy(&f);
}

int main(void)
{
    test_init_validation();
    test_probe_and_scan();
    test_eeprom_write_read();
    test_combined_zero_length_write_phase();
    test_nack();
    test_sensor();
    test_clock_stretching();
    test_clock_stretch_timeout();
    test_bus_recovery();

    if (failures != 0) {
        fprintf(stderr, "%d check(s) failed\n", failures);
        return 1;
    }
    printf("all tests passed\n");
    return 0;
}
