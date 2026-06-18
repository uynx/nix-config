#!/usr/bin/env python3
import time
import subprocess
import sys

def main():
    while True:
        # Calculate time remaining until the next exact second
        t = time.time()
        sleep_time = 1.0 - (t % 1.0)
        time.sleep(sleep_time)
        
        # Trigger the custom event in sketchybar
        subprocess.run(["sketchybar", "--trigger", "clock_tick"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
