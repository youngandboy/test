/*
 * demo_iic.c - Small end-to-end demo using the simulated I2C bus.
 *
 * It behaves exactly like firmware on a real board: initialise the bus,
 * scan it, write an EEPROM page and read it back, then read a sensor.
 *
 * Run with: make demo
 */
#include <stdio.h>
#include <string.h>

#include "iic.h"
#include "iic_sim.h"

#define EEPROM_ADDR 0x50U
#define SENSOR_ADDR 0x48U

int main(void)
{
    iic_sim_t *sim = iic_sim_new();
    iic_bus_t bus;
    iic_config_t config;
    iic_status_t status;
    uint8_t found_addrs[8];
    size_t found = 0;
    uint8_t page[5] = {0x00, 0xCA, 0xFE, 0xBA, 0xBE};
    uint8_t readback[4];
    uint8_t temperature[2] = {0x1A, 0x2B};
    uint8_t reg = 0x00;
    int sensor;
    int eeprom;
    size_t i;

    if (sim == NULL) {
        fprintf(stderr, "out of memory\n");
        return 1;
    }
    eeprom = iic_sim_add_eeprom(sim, EEPROM_ADDR);
    sensor = iic_sim_add_sensor(sim, SENSOR_ADDR);
    if (eeprom < 0 || sensor < 0) {
        fprintf(stderr, "could not create simulated devices\n");
        iic_sim_free(sim);
        return 1;
    }
    (void)iic_sim_set_sensor(sim, sensor, temperature, sizeof(temperature));

    memset(&config, 0, sizeof(config));
    config.port = iic_sim_port(sim);
    status = iic_init(&bus, &config);
    if (status != IIC_OK) {
        fprintf(stderr, "i2c init failed: %s\n", iic_status_str(status));
        iic_sim_free(sim);
        return 1;
    }

    status = iic_scan(&bus, found_addrs, sizeof(found_addrs), &found);
    if (status != IIC_OK) {
        fprintf(stderr, "i2c scan failed: %s\n", iic_status_str(status));
        iic_deinit(&bus);
        iic_sim_free(sim);
        return 1;
    }
    printf("devices found: %u", (unsigned)found);
    for (i = 0; i < found && i < sizeof(found_addrs); ++i) {
        printf(" 0x%02X", found_addrs[i]);
    }
    printf("\n");

    /* EEPROM page write: first byte is the memory address. */
    status = iic_write(&bus, EEPROM_ADDR, page, sizeof(page));
    if (status != IIC_OK) {
        fprintf(stderr, "EEPROM write failed: %s\n", iic_status_str(status));
        iic_deinit(&bus);
        iic_sim_free(sim);
        return 1;
    }

    /* Random read of the four data bytes we just wrote. */
    status = iic_write_read(&bus, EEPROM_ADDR, &reg, 1, readback, sizeof(readback));
    if (status != IIC_OK) {
        fprintf(stderr, "EEPROM read failed: %s\n", iic_status_str(status));
        iic_deinit(&bus);
        iic_sim_free(sim);
        return 1;
    }
    printf("EEPROM[0x00..0x03]: %02X %02X %02X %02X\n",
           readback[0], readback[1], readback[2], readback[3]);

    status = iic_read(&bus, SENSOR_ADDR, temperature, sizeof(temperature));
    if (status != IIC_OK) {
        fprintf(stderr, "sensor read failed: %s\n", iic_status_str(status));
        iic_deinit(&bus);
        iic_sim_free(sim);
        return 1;
    }
    printf("sensor: %02X %02X\n", temperature[0], temperature[1]);

    iic_deinit(&bus);
    iic_sim_free(sim);
    return 0;
}
