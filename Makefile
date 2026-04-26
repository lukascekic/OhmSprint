.PHONY: all build upload buildfs uploadfs monitor clean compile_commands

all: build

build:
	pio run

upload:
	pio run --target upload

buildfs:
	pio run --target buildfs

uploadfs:
	pio run --target uploadfs

upload-all: build buildfs upload uploadfs
	@echo "Done! Firmware and filesystem uploaded."

monitor:
	pio device monitor

clean:
	pio run --target clean

compile_commands:
	pio run --target compiledb
