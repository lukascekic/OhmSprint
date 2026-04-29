.PHONY: all build upload buildfs uploadfs monitor clean compile_commands simulator

ESP_PORT ?= /dev/ttyACM0
SIM_PORT ?= /dev/ttyUSB0

all: build

build:
	pio run

upload:
	pio run --target upload --upload-port $(ESP_PORT)

buildfs:
	pio run --target buildfs

uploadfs:
	pio run --target uploadfs

upload-all: build buildfs upload uploadfs
	@echo "Done! Firmware and filesystem uploaded."

monitor:
	pio device monitor -p $(ESP_PORT)

clean:
	pio run --target clean

compile_commands:
	pio run --target compiledb

simulator:
	python3 tools/uart_simulator.py $(SIM_PORT) -b 115200
