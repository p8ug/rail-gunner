#!/usr/bin/env python3
"""What the debug build of Rail Gunner (make debug) has to show on a console.

    python3 tools/gametank/bank_sums.py build/gametank-debug/rail_gunner.gtr

A line for each of the banks 128-130 of the cartridge image, as
src/gametank/debug/dbg.p8 prints them: the bank, its first four bytes and
the sum of its bytes, in hex.  The console shows the three lines twice.
"""
import sys

image = open(sys.argv[1], "rb").read()
print("the debug screen has to show, twice:")
for bank in (128, 129, 130):
    data = image[(bank - 128) * 16384:(bank - 127) * 16384]
    print("  %02X %s %04X" % (bank, data[:4].hex().upper(), sum(data) & 0xffff))
