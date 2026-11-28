#!/usr/bin/env python3
"""The tests of the GameTank build, which `make test` runs.

The cartridge image runs in gth (tools/gametank/gth.cpp), a GameTank without
a window, and this prints what it finds, a line for each thing.  `make test`
compares that with tests/expected/gametank.txt.

A page of text is checked by the CRC of the picture, so a line changes when
the page does: look at the page (tools/gametank/gt.py shot) and, when it is
as intended, put the new line in the expected file.  The rest are yes or no.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "gametank"))
from gt import GameTank, BOOT_FRAMES    # noqa: E402

FLASH = ROOT / "build" / "test_flash.bin"
CONWAY = 1


def yes(value):
    return "yes" if value else "NO"


def pages():
    tank = GameTank()
    tank.run(BOOT_FRAMES)
    print("title page:", tank.crc())
    tank.tap("DOWN", 5)
    tank.tap("A")
    print("high scores page, empty:", tank.crc())
    tank.tap("C")
    tank.tap("DOWN")
    tank.tap("A")
    print("help page:", tank.crc())
    tank.tap("C")
    print("back on the title page:", yes(tank.peek("game.menuPage") == 0))

    # the settings: MODE is the second row, STARTING WAVE the third
    tank.tap("UP", 6)
    tank.tap("DOWN")
    tank.tap("RIGHT")
    print("mode changed:", yes(tank.peek("game.mode") == 1))
    tank.tap("LEFT", 2)
    print("mode wraps around:", yes(tank.peek("game.mode") == 4))
    tank.tap("RIGHT")
    tank.tap("DOWN")
    tank.tap("RIGHT", 3)
    print("starting wave changed:", yes(tank.peek("game.selectedWave", 2) == 4))
    tank.tap("C")
    print("C does not leave the title page:", yes(tank.peek("game.menuPage") == 0))

    # nothing pressed for 12 seconds: the demo
    tank.tap("UP", 3)
    tank.run(760)
    print("demo starts:", yes(tank.peek("game.demoMode") == 1))
    tank.tap("A")
    tank.run(20)
    print("demo ends at a button:", yes(tank.peek("game.demoMode") == 0))
    tank.close()


def play():
    for wave, mode, name in ((1, 0, "classic, wave 1"), (12, 0, "classic, wave 12"),
                             (20, CONWAY, "Conway Life, wave 20"), (20, 2, "HighLife, wave 20"),
                             (20, 3, "rule 30, wave 20"), (20, 4, "rule 110, wave 20")):
        tank = GameTank()
        tank.run(BOOT_FRAMES)
        tank.start_game(wave, mode)
        ticks, playing = tank.play(900)
        score = tank.peek("game.points", 4) + tank.peek("game.wavePoints", 4)
        print("%s: plays %s, scores %s, at least 90%% of full speed %s" % (
            name, yes(playing >= 300), yes(score > 0), yes(ticks >= playing * 0.9)))
        tank.close()

    tank = GameTank()
    tank.run(BOOT_FRAMES)
    tank.start_game(1, 0)
    tank.run(60)
    _, before, _, _ = tank.stat()
    tank.tap("START")
    tank.run(60)
    _, during, _, _ = tank.stat()
    tank.tap("START")
    tank.run(60)
    _, after, _, _ = tank.stat()
    print("START pauses and resumes:", yes(during - before < 10 and after - during > 30))
    tank.tap("C")
    tank.run(10)
    print("C returns to the title page:", yes(tank.peek("game.ships") == 3 and tank.peek("video.arenaShown") == 0))
    tank.close()


def lose_a_game(tank, score):
    """A game that ends with this score: fly up into a Conway formation."""
    tank.start_game(20, CONWAY)
    tank.run(60)
    tank.poke("game.wavePoints", score, 4)
    tank.hold("UP")
    for _ in range(40):
        tank.run(150)
        if tank.peek("game.ships") == 0:
            break
    tank.hold()
    tank.run(60)


def saving():
    FLASH.unlink(missing_ok=True)
    tank = GameTank()
    tank.run(BOOT_FRAMES)
    lose_a_game(tank, 12345)
    print("the game ends:", yes(tank.peek("game.ships") == 0))
    print("results page:", tank.crc())
    tank.tap("UP", 1, 20)       # the first letter, a few steps on
    tank.tap("A")
    tank.run(30)
    print("score in the table:", yes(tank.peek("scores.points", 4) == 12345))
    print("saved:", yes(tank.peek("scores.last_save_ok") == 1))
    tank.tell("saveflash %s" % FLASH)
    tank.close()

    tank = GameTank(flash=FLASH)
    tank.run(BOOT_FRAMES)
    print("score still there after a restart:", yes(tank.peek("scores.points", 4) == 12345))
    lose_a_game(tank, 54321)
    tank.tap("A")
    tank.run(30)
    tank.tell("saveflash %s" % FLASH)
    tank.close()
    flash = FLASH.read_bytes()
    print("second save in the other sector:", yes(flash[0] != 0xff and flash[0x2000] != 0xff and flash[64] == 0xff))

    tank = GameTank(flash=FLASH)
    tank.run(BOOT_FRAMES)
    print("both scores after a restart, the higher first:",
          yes(tank.peek("scores.points", 4) == 54321 and tank.peek(tank.address("scores.points") + 4, 4) == 12345))
    tank.close()

    # a sector with no room left is erased for the save
    full = bytearray(b"\xff" * 0x4000)
    for at in range(0, 0x2000, 64):
        full[at:at + 43] = bytes([42] + [1] * 42)
    FLASH.write_bytes(full)
    tank = GameTank(flash=FLASH)
    tank.run(BOOT_FRAMES)
    print("records that are not a table are ignored:", yes(tank.peek("scores.points", 4) == 0))
    lose_a_game(tank, 777)
    tank.tap("A")
    tank.run(30)
    tank.tell("saveflash %s" % FLASH)
    saved = tank.peek("scores.last_save_ok") == 1
    tank.close()
    flash = FLASH.read_bytes()
    print("full sector erased and saved to:", yes(saved and flash[0] == 42 and flash[1:3] == b"IB" and flash[64] == 0xff))


if __name__ == "__main__":
    pages()
    play()
    saving()
