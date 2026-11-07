# Portable I2C master + simulation tests (host build).
#
#   make test   build and run the simulation test suite
#   make demo   build and run a small EEPROM/sensor demo
#   make clean  remove build artifacts
#
# Cross-compiling for a target only needs src/iic.c and include/iic.h; the
# simulator (sim/iic_sim.c) and tests are host-only.

CC ?= cc
CFLAGS ?= -std=c99 -O2 -g
WARNINGS = -Wall -Wextra -Wpedantic -Werror
CPPFLAGS += -Iinclude

BUILD_DIR := build

LIB_SRCS := src/iic.c
SIM_SRCS := sim/iic_sim.c
TEST_SRCS := test/test_iic.c
DEMO_SRCS := examples/demo_iic.c

TEST_BIN := $(BUILD_DIR)/test_iic
DEMO_BIN := $(BUILD_DIR)/demo_iic

.PHONY: all test demo clean

all: test

test: $(TEST_BIN)
	./$(TEST_BIN)

demo: $(DEMO_BIN)
	./$(DEMO_BIN)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(TEST_BIN): $(LIB_SRCS) $(SIM_SRCS) $(TEST_SRCS) include/iic.h include/iic_sim.h | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(WARNINGS) -o $@ $(LIB_SRCS) $(SIM_SRCS) $(TEST_SRCS)

$(DEMO_BIN): $(LIB_SRCS) $(SIM_SRCS) $(DEMO_SRCS) include/iic.h include/iic_sim.h | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(WARNINGS) -o $@ $(LIB_SRCS) $(SIM_SRCS) $(DEMO_SRCS)

clean:
	rm -rf $(BUILD_DIR)
