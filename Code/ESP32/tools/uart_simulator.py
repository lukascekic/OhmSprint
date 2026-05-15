#!/usr/bin/env python3
import argparse
import random
import struct
import sys
import time
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.resolve()
PROTO_FILE = SCRIPT_DIR.parent / "proto" / "simple.proto"
OUTPUT_DIR = SCRIPT_DIR

try:
    import serial
except ImportError:
    print("Error: pyserial not installed. Run: pip install -r tools/requirements.txt")
    sys.exit(1)

try:
    import simple_pb2
except ImportError:
    print("Error: simple_pb2.py not found. Generating from proto...")
    import subprocess
    result = subprocess.run(
        ["protoc", "--python_out", str(OUTPUT_DIR), "-I", str(PROTO_FILE.parent), PROTO_FILE.name],
        cwd=str(SCRIPT_DIR.parent),
        capture_output=True,
        text=True
    )
    if result.returncode != 0:
        print(f"Failed to generate protobuf: {result.stderr}")
        sys.exit(1)
    sys.path.insert(0, str(OUTPUT_DIR))
    import simple_pb2

BAUD_RATE = 115200
DEFAULT_DELAY = 1.0

def generate_random_data():
    data = simple_pb2.MeasureData()
    data.current = round(random.uniform(0.0, 10.0), 2)
    data.voltage = round(random.uniform(110.0, 240.0), 2)
    data.power = round(random.uniform(0.0, 2400.0), 2)
    data.frequency = round(random.uniform(49.5, 50.5), 2)
    data.power_usage = round(random.uniform(0.0, 10000.0), 2)
    data.sd_logs_enable = True
    data.wifi_enable = True
    return data

def send_message(ser, data):
    serialized = data.SerializeToString()
    length = len(serialized)
    length_bytes = struct.pack(">I", length)
    message = length_bytes + serialized
    ser.write(message)
    return serialized

def main():
    parser = argparse.ArgumentParser(description="UART protobuf simulator")
    parser.add_argument("port", help="Serial port (e.g., /dev/ttyUSB0)")
    parser.add_argument("-b", "--baud", type=int, default=BAUD_RATE, help="Baud rate")
    parser.add_argument("-d", "--delay", type=float, default=DEFAULT_DELAY, help="Delay between messages (seconds)")
    parser.add_argument("-c", "--count", type=int, default=0, help="Number of messages to send (0 = infinite)")
    args = parser.parse_args()

    try:
        ser = serial.Serial(args.port, args.baud, timeout=1)
    except serial.SerialException as e:
        print(f"Error: Cannot open port {args.port}: {e}")
        sys.exit(1)

    print(f"Connected to {args.port} at {args.baud} baud")
    print(f"Sending messages with {args.delay}s delay (Ctrl+C to stop)")

    count = 0
    try:
        while True:
            data = generate_random_data()
            serialized = send_message(ser, data)
            count += 1

            print(f"[{count}] Sent {len(serialized)} bytes: "
                  f"I={data.current}A V={data.voltage}V P={data.power}W "
                  f"F={data.frequency}Hz E={data.power_usage}kWh "
                  f"SD={data.sd_logs_enable} WiFi={data.wifi_enable}")

            if args.delay > 0:
                time.sleep(args.delay)

            if args.count > 0 and count >= args.count:
                break
    except KeyboardInterrupt:
        print(f"\nStopped after sending {count} messages")
    finally:
        ser.close()

if __name__ == "__main__":
    main()