#!/usr/bin/env python3
"""Drive the GameTank build of Rail Gunner in gth, the GameTank without a window.

As a module (tests/gametank_test.py uses it):

    from gt import GameTank
    tank = GameTank()               # build/gametank/rail_gunner.gtr in build/gth
    tank.run(330)                   # frames: the logo, then the title page
    tank.tap("A")                   # press and release a button
    tank.poke("game.mode", 1)       # a variable of the program, by its name
    print(tank.peek("game.ships"), tank.crc())
    tank.shot("page.ppm")           # what is on the screen

As a program, from the repository's directory, after `make build/gth`:

    python3 tools/gametank/gt.py shot FILE.ppm [--wave N] [--mode N] [--frames N]
    python3 tools/gametank/gt.py speed [--wave N] [--mode N] [--seconds N]
    python3 tools/gametank/gt.py profile [--wave N] [--mode N] [--skip N] [--frames N]

Each starts a game (after --frames of play for shot) with fire held and the
ship steered about.  speed prints how much of full speed the game ran at;
profile prints which subroutines the time of a frame goes to.

Names are those of the Prog8 source, block.name.  They are read from what
the compiler wrote beside the image (-asmlist), so they follow every build.
"""
import argparse
import bisect
import collections
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IMAGE = ROOT / "build" / "gametank" / "rail_gunner.gtr"
GTH = ROOT / "build" / "gth"
BOOT_FRAMES = 330       # the logo and the jingle, until the title page stands
STEERING = ["A", "A LEFT", "A", "A RIGHT", "A UP", "A RIGHT", "A DOWN", "A LEFT"]


class GameTank:
    def __init__(self, image=IMAGE, gth=GTH, flash=None):
        self.image = Path(image)
        self.symbols, self.banks, self.labels = read_symbols(self.image)
        self.process = subprocess.Popen([str(gth), str(self.image)], stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE, text=True)
        if flash:
            self.tell("loadflash %s" % flash)
        start = self.address("video.vsync")
        self.tell("idle %x %x" % (start, start + 6))

    def tell(self, command):
        self.process.stdin.write(command + "\n")
        self.process.stdin.flush()

    def ask(self, command):
        self.tell(command)
        answer = self.process.stdout.readline()
        if not answer or answer.startswith("illegal"):
            raise RuntimeError("gth stopped: " + (answer.strip() or "no answer to " + command))
        return answer.strip()

    def close(self):
        self.process.stdin.close()
        self.process.wait()

    def address(self, name):
        if isinstance(name, int):
            return name
        return self.symbols[name]

    def run(self, frames):
        self.tell("run %d" % frames)

    def hold(self, buttons=""):
        self.tell("btn " + buttons)

    def tap(self, button, times=1, frames=3, pause=6):
        for _ in range(times):
            self.hold(button)
            self.run(frames)
            self.hold()
            self.run(pause)

    def peek(self, name, count=1):
        """A variable as a number: count bytes, the low byte first."""
        data = bytes.fromhex(self.ask("peek %x %d" % (self.address(name), count)))
        return int.from_bytes(data, "little")

    def poke(self, name, value, count=1):
        for n in range(count):
            self.tell("poke %x %x" % (self.address(name) + n, (value >> (8 * n)) & 255))

    def crc(self):
        return self.ask("crc")

    def stat(self):
        """Frames, flips, and the average and highest busy cycles of a frame since the last call."""
        return tuple(int(v) for v in self.ask("stat").split())

    def shot(self, path):
        """The screen as a PPM picture, four times as large."""
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        from make_assets import PALETTE

        raw = Path(str(path) + ".raw")
        self.tell("shot %s" % raw)
        self.stat()                 # wait until it is written
        pixels = raw.read_bytes()
        raw.unlink()
        with open(path, "wb") as out:
            out.write(b"P6\n512 512\n255\n")
            for y in range(512):
                row = bytearray()
                for x in range(128):
                    colour = pixels[(y // 4) * 128 + x]
                    row += PALETTE[colour * 3:colour * 3 + 3] * 4
                out.write(row)

    def start_game(self, wave=1, mode=0, ammo=0):
        """From the title page into play, past the wave's banner."""
        self.poke("game.selectedWave", wave, 2)
        self.poke("game.mode", mode)
        self.poke("game.ammoMode", ammo)
        self.tap("A")
        self.run(80)

    def play(self, frames, step=150):
        """Hold fire and steer about.  Returns the ticks of the game and the
        frames in which it was playing (not showing a banner or a page)."""
        ticks = playing = 0
        _, flips, _, _ = self.stat()
        for n in range(frames // step):
            self.hold(STEERING[n % len(STEERING)])
            for _ in range(step // 30):
                self.run(30)
                _, now, _, _ = self.stat()
                if now - flips >= 20:
                    ticks += now - flips
                    playing += 30
                flips = now
        self.hold()
        return ticks, playing


def read_symbols(image):
    """The addresses of the program's variables and subroutines as block.name,
    the bank of every block that is in one, and the labels for a profile."""
    stem = image.with_suffix("")
    symbols, banks, labels = {}, {}, []
    bank = None
    for line in open(str(stem) + ".asm"):
        line = line.strip()
        found = re.match(r"p8ov_part_(\d+)\s+\.segment", line)
        if found:
            bank = int(found.group(1))
        elif line == ".endm":
            bank = None
        elif bank:
            found = re.match(r"p8b_(\w+)\s+\.proc", line)
            if found:
                banks[found.group(1)] = bank
        found = re.match(r"p8b_(\w+)\.p8v_(\w+) = (\d+)$", line)
        if found:
            symbols[found.group(1) + "." + found.group(2)] = int(found.group(3))
    for line in open(str(stem) + ".vice-mon-list"):
        found = re.match(r"al ([0-9a-f]+) \.(\S+)", line)
        if not found:
            continue
        address, parts = int(found.group(1), 16), found.group(2).split(":")
        block = parts[0][4:] if parts[0].startswith("p8b_") else parts[0]
        if len(parts) == 2:
            name = re.sub(r"^p8[vsl]_", "", parts[1])
            symbols.setdefault(block + "." + name, address)
        if address >= 0x8000 and len(parts) <= 2 and "p8_label_gen" not in parts[-1]:
            if address < 0xc000:
                if block not in banks:
                    continue
                address |= (banks[block] - 127) << 16
            labels.append((address, ".".join([block] + [re.sub(r"^p8[vsl]_", "", p) for p in parts[1:]])))
    labels.sort()
    return symbols, banks, labels


def profile(tank, path):
    keys = [label[0] for label in tank.labels]
    totals, total = collections.Counter(), 0
    for line in open(path):
        key, cycles = line.split()
        key, cycles = int(key, 16), int(cycles)
        total += cycles
        at = bisect.bisect_right(keys, key) - 1
        totals[tank.labels[at][1] if at >= 0 else hex(key)] += cycles
    for name, cycles in totals.most_common(30):
        print("%6.2f%%  %s" % (100 * cycles / total, name))


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("what", choices=["shot", "speed", "profile"])
    parser.add_argument("file", nargs="?")
    parser.add_argument("--wave", type=int, default=1)
    parser.add_argument("--mode", type=int, default=0, help="0 classic, 1 Conway Life, 2 HighLife, 3 rule 30, 4 rule 110")
    parser.add_argument("--frames", type=int, default=600)
    parser.add_argument("--seconds", type=int, default=60)
    parser.add_argument("--skip", type=int, default=600, help="frames of play before the profile starts")
    args = parser.parse_args()
    tank = GameTank()
    tank.run(BOOT_FRAMES)
    if args.what == "shot" and args.frames == 0:
        tank.shot(args.file)
        return
    tank.start_game(args.wave, args.mode)
    if args.what == "shot":
        tank.play(args.frames)
        tank.shot(args.file)
    elif args.what == "speed":
        ticks, playing = tank.play(args.seconds * 60)
        print("%d ticks in %d frames of play: %.1f%% of full speed" % (ticks, playing, 100 * ticks / max(1, playing)))
    else:
        tank.play(args.skip)
        out = ROOT / "build" / "profile.txt"
        tank.tell("prof on")
        tank.play(args.frames)
        tank.tell("prof %s" % out)
        tank.stat()
        profile(tank, out)
    tank.close()


if __name__ == "__main__":
    main()
