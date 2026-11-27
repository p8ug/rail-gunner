#!/usr/bin/env python3
"""Make the GameTank picture data of Rail Gunner.

Writes, into src/gametank/:
  tiles.deflate   a 128 x 128 sprite sheet: the 3 x 4 pixel cells of the arena
                  in every colour, and the title page's 16 x 16 pictures
  font.deflate    a 128 x 128 sprite sheet: a 3 x 5 pixel font in ten colours
  frames.bin      the frame table of the 16 x 16 pictures

Only the Python standard library is needed.  The results are checked in, so
a build does not run this; run it again after changing a shape below.

    python3 tools/gametank/make_assets.py [--preview DIR | --check]

--check writes nothing: it fails when the files are not what this would make
(`make test` does that).

The 16 x 16 pictures are the Commander X16 version's 8 x 8 tiles, doubled:
they are read from src/cx16/video_platform.p8.
"""
import re
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "src" / "gametank"

# The colours of the GameTank as a capture card saw them: 256 times red,
# green, blue.  From GameTankEmulator (src/gametank_palette.h), MIT license,
# Copyright (c) 2020 Clyde Shaffer.
PALETTE = bytes.fromhex(
    "1a1a1a3131314747475d5d5d7474748b8b8aa1a1a1b9b9b91a1e0031350a474b215e613575784d8c8f65a2a57cb9bd93"
    "1a2200313900474f005d650e727b248b933da2aa52b9c2691a2600313d004854005d6a007480008c9814a2ae29b9c541"
    "1b1b1b3131314848485e5e5e7575758c8c8ca2a2a2b9b9b92c1900422f1558462d705c418672599e896fb49f86cbb79f"
    "3c1600532d0069430f80592496703bae8752c49e68dcb57f4c1500632a007b4100925909a76e1ebf8635d69b4bedb262"
    "1a1a1a3232324848485e5e5e7474738b8b8ba2a2a2b9b9b932141b482a315e404776575e8c6e74a3858cb99ba2d1b3ba"
    "480c19602330773a478f505ea36674bb7d8bd294a2eaacb961061b781d318e3348a64a5ebc5f74d3778cea8ca2ffa5ba"
    "1a1a1a3131314747475d5d5d7474738b8b8ba2a2a2b9b9b92b123541294d5740606e557c846c919b83a8b299bec8b0d6"
    "3d0b515521696a387f824e969965acb07cc3c792dbdda9f14e046d651a837c309a9348b2a95ec8c074ded68af5eda2ff"
    "1a1a1a3131314747475d5d5d7474748c8c8ca2a2a2b9b9b91a1640312d5748446e5e5a8475719b8c88b2a29ec8b9b5df"
    "1a126631297d483f935e56ac746cc18c84daa29af0b9b1ff1b0f8f3225a6483cbe5f52d47468eb8c80ffa296ffb9adff"
    "1a1a1a3131314747475d5d5d7474748b8b8ba2a2a2b8b8b8081c331f334a364a604c607862778e7a8da590a4bba7bcd2"
    "001d50103467274b7e3b62945278aa6a90c280a6d996bdf000216d003782154e9a2c64b0417ac65a92de70a8f487c0ff"
    "1a1a1a3131314747475d5d5d7373738b8b8ba2a2a2b8b9b90420171a362f314d4746645d5e7a7475928c8aa89fa1bfb6"
    "002719033d311a54472f6b5d4681735d998b73afa289c6b8002f1a004531015c4717725d2d887345a08b5cb6a272cdb8"
    "1a1a193030304747475d5d5e7474748b8b8ba2a2a2b9b9b90a2200213813374f2b4c6540637b577a936d91a982a8c099"
    "0028000f3e002756123b6d2653833d6a9a5680b16b97c782003000004700155e002c750b418a2158a23970b94f85d066"
)

BLACK = 0           # in a sheet: not drawn by a blit with transparency

# A colour byte is HHHSSLLL: hue, saturation, brightness.  These are the 16
# colours that the Commander X16 version uses (VERA's default palette: black,
# white, red, cyan, purple, green, blue, yellow, orange, brown, light red,
# dark grey, grey, light green, light blue, light grey), chosen by eye from
# the GameTank's.
SHADE = [BLACK, 7, 91, 222, 125, 252, 187, 30, 61, 50, 94, 2, 4, 254, 190, 5]


def lighter(colour):
    saturation = max(0, ((colour >> 3) & 3) - 1)
    return (colour & 0xe0) | (saturation << 3) | min(7, (colour & 7) + 1)


def darker(colour):
    return (colour & 0xf8) | max(1, (colour & 7) - 3)


LIGHT = [lighter(c) if c else BLACK for c in SHADE]
DARK = [darker(c) if c else BLACK for c in SHADE]
FIXED = {"w": 7, "r": 93, "y": 31, "c": 223, "k": 3}
DOT = 170           # the corner of every cell of the grid

# ---- the cells: 3 pixels wide, 4 high ----
#   # the colour that the game asks for    o lighter    x darker
#   w r y c k  always white, red, yellow, cyan, dark grey
#   . nothing: the grid's dot shows in its corner
# The number is the tile as src/gametank/video_platform.p8 names it, less 127.
CELLS = {
    1: ("SHIP", ".#. .#. ### #.#"),
    5: ("PULSE", ".o. .#. .#. ..."),
    6: ("SHARD", "... .#. #o# .#."),
    7: ("TRAIN", "#.# #o# .#. ..."),
    8: ("PATROL", ".#. #o# ### #.#"),
    9: ("ARMORED", "### #x# #x# ###"),
    10: ("BOLT", "#.# .o. #.# ..."),
    11: ("CELL", "### #.# ### ..."),
    12: ("POD_WAKING", ".#. #.# .#. ..."),
    13: ("POD_ARMED", "#o# ### .#. #.#"),
    14: ("RAIL", "x#x x#x x#x x#x"),
    15: ("BAR", "xxx ### ### xxx"),
    16: ("BURST", "o.o .w. o.o ..."),
    18: ("GUN_RIGHT", "#xx ##o ##o #xx"),
    19: ("GUN_UP", "xoo x## ### ###"),
    20: ("RAIL_POD_SEED", "... .#. .#. ..."),
    21: ("RAIL_SHOT_RIGHT", "... ##w ##w ..."),
    22: ("RAIL_SHOT_UP", ".w. .#. .#. ..."),
    23: ("RAIL_CHARGE", "#.# #o# .#. .#."),
    24: ("IMPACT_FLASH", "o#o #w# #w# o#o"),
    25: ("IMPACT_SMOKE", "#.. ..# .#. #.."),
    26: ("IMPACT_FRAGMENT", "... .#. ... ..."),
    27: ("TRAIN_FLAP", ".#. #o# #.# ..."),
    28: ("SHIP_WARNING", ".r. .#. ### r.r"),
    29: ("AMMO_PACK", "### #o# ### ..."),
    30: ("RESERVE_PACK", ".#. ### ### .#."),
}
NO_DOT = {14, 15, 18, 19}       # the cells of the frame around the grid

# ---- the 16 x 16 pictures: a tile of the X16 version and its colour ----
PICTURES = [("SHIP", 1), ("PULSE", 7), ("TRAIN", 3), ("TRAIN_FLAP", 3), ("PATROL", 8),
            ("ARMORED", 2), ("SHARD", 15), ("BOLT", 10), ("AMMO_PACK", 13), ("POD_WAKING", 7),
            ("POD_ARMED", 8), ("RAIL_POD_SEED", 3), ("RAIL_CHARGE", 10), ("GUN_RIGHT", 8),
            ("GUN_UP", 8), ("RAIL_SHOT_RIGHT", 3), ("BURST", 7), ("CELL", 13)]

# ---- the font: 3 x 5 pixels, characters 32 to 95 ----
FONT = """
    000 000 000 000 000   010 010 010 000 010   101 101 000 000 000   101 111 101 111 101
    011 110 010 011 110   101 001 010 100 101   010 101 010 101 011   010 010 000 000 000
    001 010 010 010 001   100 010 010 010 100   000 101 010 101 000   000 010 111 010 000
    000 000 000 010 100   000 000 111 000 000   000 000 000 000 010   001 001 010 100 100
    111 101 101 101 111   010 110 010 010 111   111 001 111 100 111   111 001 011 001 111
    101 101 111 001 001   111 100 111 001 111   111 100 111 101 111   111 001 001 010 010
    111 101 111 101 111   111 101 111 001 111   000 010 000 010 000   000 010 000 010 100
    001 010 100 010 001   000 111 000 111 000   100 010 001 010 100   111 001 011 000 010
    010 101 111 100 011   010 101 111 101 101   110 101 110 101 110   011 100 100 100 011
    110 101 101 101 110   111 100 110 100 111   111 100 110 100 100   011 100 101 101 011
    101 101 111 101 101   111 010 010 010 111   001 001 001 101 010   101 101 110 101 101
    100 100 100 100 111   101 111 111 101 101   110 101 101 101 101   010 101 101 101 010
    110 101 110 100 100   010 101 101 110 011   110 101 110 101 101   011 100 010 001 110
    111 010 010 010 010   101 101 101 101 111   101 101 101 101 010   101 101 111 111 101
    101 101 010 101 101   101 101 010 010 010   111 001 010 100 111   011 010 010 010 011
    100 100 010 001 001   110 010 010 010 110   010 101 000 000 000   000 000 000 000 111
""".split()
# The shades that text is printed in: src/gametank/gfx.p8 has the same list.
FONT_SHADES = [1, 2, 3, 7, 8, 10, 11, 13, 14, 15]


def deflate(pixels):
    packer = zlib.compressobj(9, zlib.DEFLATED, -15)
    return packer.compress(bytes(pixels)) + packer.flush()


def x16_art():
    """The 8 x 8 tiles of the X16 version, by name."""
    text = (ROOT / "src" / "cx16" / "video_platform.p8").read_text()
    names = {int(n): name for name, n in re.findall(r"const ubyte (\w+) = (1[2-5]\d)\b", text)}
    table = re.search(r"art = \[(.*?)\]", text, re.S).group(1)
    data = [int(v, 16) for v in re.findall(r"\$([0-9a-f]{2})", table)]
    return {names[128 + i]: data[i * 8:i * 8 + 8] for i in range(len(data) // 8) if 128 + i in names}


def tiles_sheet():
    sheet = bytearray(128 * 128)
    for index in range(32):
        rows = CELLS.get(index, ("", "... ... ... ..."))[1].split()
        for shade in range(16):
            for y, row in enumerate(rows):
                for x, mark in enumerate(row):
                    if mark == "#":
                        colour = SHADE[shade]
                    elif mark == "o":
                        colour = LIGHT[shade] if shade else BLACK
                    elif mark == "x":
                        colour = DARK[shade]
                    elif mark == ".":
                        colour = BLACK
                    else:
                        colour = FIXED[mark] if shade else BLACK
                    if colour == BLACK and x == 0 and y == 0 and index not in NO_DOT:
                        colour = DOT
                    sheet[(shade * 4 + y) * 128 + index * 4 + x] = colour
    art = x16_art()
    frames = bytearray()
    for number, (name, shade) in enumerate(PICTURES):
        gx, gy = (number % 8) * 16, 64 + (number // 8) * 16
        for y in range(16):
            for x in range(16):
                if art[name][y // 2] & (0x80 >> (x // 2)):
                    sheet[(gy + y) * 128 + gx + x] = SHADE[shade]
        # drawn around the position that is asked for
        frames += bytes([0xf8, 0xf8, 16, 16, gx, gy, 0, 0])
    return sheet, frames


def font_sheet():
    sheet = bytearray(128 * 128)
    for group, shade in enumerate(FONT_SHADES):
        left, top = (group % 2) * 64, (group // 2) * 24
        for code in range(64):
            rows = FONT[code * 5:code * 5 + 5]
            for y, row in enumerate(rows):
                for x, mark in enumerate(row):
                    if mark == "1":
                        sheet[(top + (code // 16) * 6 + y) * 128 + left + (code % 16) * 4 + x] = SHADE[shade]
    return sheet


def preview(sheet, path):
    """A PPM of a sheet, four times as large."""
    with open(path, "wb") as out:
        out.write(b"P6\n512 512\n255\n")
        for y in range(512):
            row = bytearray()
            for x in range(512):
                colour = sheet[(y // 4) * 128 + x // 4]
                row += PALETTE[colour * 3:colour * 3 + 3] if colour else b"\x00\x00\x00"
            out.write(row)


def main():
    assert len(FONT) == 64 * 5
    tiles, frames = tiles_sheet()
    font = font_sheet()
    if sys.argv[1:] == ["--check"]:
        made = {"tiles.deflate": deflate(tiles), "font.deflate": deflate(font), "frames.bin": bytes(frames)}
        stale = [name for name, data in made.items() if (OUT / name).read_bytes() != data]
        if stale:
            sys.exit("not what tools/gametank/make_assets.py makes: " + ", ".join(stale))
        return
    (OUT / "tiles.deflate").write_bytes(deflate(tiles))
    (OUT / "font.deflate").write_bytes(deflate(font))
    (OUT / "frames.bin").write_bytes(frames)
    print("tiles.deflate", len(deflate(tiles)), "font.deflate", len(deflate(font)), "frames.bin", len(frames))
    print("shades", SHADE, "dot", DOT)
    if len(sys.argv) == 3 and sys.argv[1] == "--preview":
        preview(tiles, Path(sys.argv[2]) / "tiles.ppm")
        preview(font, Path(sys.argv[2]) / "font.ppm")


if __name__ == "__main__":
    main()
