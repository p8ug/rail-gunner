#!/usr/bin/env python3
"""A copy of a GameTank cartridge image that is quick to write to a cartridge.

    python3 tools/gametank/flash_image.py IMAGE.gtr

writes IMAGE-flash.gtr beside it.  The compiler fills the banks that the
program does not use with $ff, and gtld writes every bank that is not all
$00, which is all 128 of them.  In the copy the banks that are all $ff are
all $00, so gtld leaves them out.  It is for gtld only: what is in those
banks on the cartridge afterwards is not said by this file.
"""
import sys
from pathlib import Path

BANK = 16384

source = Path(sys.argv[1])
image = bytearray(source.read_bytes())
used = []
for bank in range(len(image) // BANK):
    if image[bank * BANK:(bank + 1) * BANK] == b"\xff" * BANK:
        image[bank * BANK:(bank + 1) * BANK] = bytes(BANK)
    else:
        used.append(bank + 128)
target = source.with_name(source.stem + "-flash.gtr")
target.write_bytes(image)
print("%s: banks %s to write" % (target, ", ".join(str(bank) for bank in used)))
