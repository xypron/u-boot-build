#!/usr/bin/env python3

import serial
import sys
import time

class Communicate:

   def __init__(self, dev='/dev/ttyUSB1', baudrate=115200):
        self.device = serial.Serial(
            port=dev,
            baudrate=baudrate,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            bytesize=serial.EIGHTBITS,
            timeout=0.1
        )

   def reset(self):
        self.device.setDTR (False)
        self.device.setRTS (False)
        time.sleep(0.1)
        self.device.setDTR (True)
        time.sleep(0.1)
        self.device.setRTS (False)
        time.sleep(0.1)

def main():
    if len(sys.argv) == 2:
        dev = sys.argv[1];
    else:
        print('No device specified')
        exit(1)

    com = Communicate(dev = dev)
    com.reset()

if __name__ == '__main__':
    main()
