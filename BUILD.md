# Build Rail Gunner 1.0

Extract the entire ZIP. The build uses the included p8p8 0.6.0 compiler, standard library, and 64tass 1.60.3243 assembler. The normal build works offline and needs only the host OS and its standard runtime.

| Host | From a terminal in the extracted directory |
|---|---|
| Windows x64 | Run `build.cmd` in Command Prompt |
| Linux x86-64 with glibc 2.38 or newer | Run `sh build.sh` |

Both scripts write **`build/RAILGUN.PRG`**, the Commander X16 version. `src/rail_gunner.p8` is the main Prog8 source file; the scripts add `src/cx16` to the compiler's source directories. See [README.md](README.md) for loading the PRG on the X16 and running it in an emulator.

The archive includes the released binary as `RAILGUN-1.0-REFERENCE.PRG`, with SHA-256 `df48d71bd8f935235105e186d6bd79f238af306d84e9017bed78bf9ce92f6a3e`. The 1.0 sources (commit `e661603`) build it byte for byte. Since the sources were split for the GameTank port the X16 build is the same game in a different arrangement of code, 33,597 bytes where the release is 33,382, so `cmp` against the reference no longer matches.

## GameTank

`make` builds both versions with the `p8c` on the path: `build/cx16/rail_gunner.prg` and `build/gametank/rail_gunner.gtr`, the image of the 2 MB cartridge. This needs a p8p8 that has the `gametank` target (0.6.1-dev was used). `make run` starts the image in GameTankEmulator.

The p8p8 has to be one whose GameTank startup code makes the pins outputs that change the cartridge's bank (`startup.asm` sets `VIA1DDRA`; in p8p8 since 27 November 2026). With an older one the image runs in GameTankEmulator and stops on a black screen after the logo on a console; `make test` fails with it too, on every line.

### On a console

Beside each image the build writes a copy for `gtld`, `rail_gunner-flash.gtr` (`tools/gametank/flash_image.py`): the banks that the program does not use are `$00` in it where the compiler writes `$ff`, and `gtld` leaves out a bank that is all `$00`. Writing it takes about 25 seconds; all 128 banks take many times that. Use the plain `.gtr` for the emulator and the tests.

The gamepad goes in port 1. A port with nothing in it reads as all buttons held.

`make debug` builds `build/gametank-debug/rail_gunner.gtr` (and its `-flash.gtr`), for a console that does not get to the title page or does something the emulator does not. After the logo it shows:

- what the console reads from the banks 128-130, twice: the bank, its first four bytes and the sum of its bytes. `make debug` prints what the lines have to be;
- what the library reads from the two gamepads, as it changes. START goes on, and so do 40 seconds;
- a block for every step on the way to the title page, written into the picture by the CPU, so it shows whatever the blitter does. The last block that is lit is the last step that was done; `src/gametank/debug/dbg.p8` lists the steps and the colours.

The build is the game with `src/gametank/debug/dbg.p8` in place of `src/gametank/dbg.p8`, which is empty. A new question for a console is a new `dbg.step()` or a line on that screen.

The GameTank's pictures and sound are checked in under `src/gametank/`. To make them again after a change in `tools/gametank/`:

```sh
python3 tools/gametank/make_assets.py
python -c "import sys, runpy; sys.path.insert(0, '.music-deps'); runpy.run_path('tools/gametank/make_sound.py', run_name='__main__')"
```

The first needs only Python; the second reads the MIDI and needs mido, installed as below.

## Tests

`make test` builds both versions, builds `build/gth` from `tools/gametank/gth.cpp` with the C++ compiler (`CXX`, by default `c++`), and runs `tests/gametank_test.py`: the GameTank image runs in `gth`, a GameTank without a window, and what the test finds is compared with `tests/expected/gametank.txt`. It needs Python 3 and takes about 20 seconds. The X16 version is only built.

`gth` reads commands (run frames, hold buttons, read and write memory, save the picture or the save bank); the comment at its top lists them. `tools/gametank/gt.py` drives it from Python by the names of the program's variables, and on its own takes a screenshot, measures the speed of a game, or prints where the time of a frame goes:

```sh
python3 tools/gametank/gt.py shot build/wave12.ppm --wave 12 --frames 900
python3 tools/gametank/gt.py speed --wave 20 --mode 1
python3 tools/gametank/gt.py profile --wave 12
```

## Music regeneration

The default build compiles the checked-in `src/cx16/music_data.p8`. To regenerate it and `PUNCH.ZSM` from the supplied MIDI, use Python 3.10 or newer with pip.

```sh
python -m pip install --target .music-deps --no-index --find-links tools/python mido==1.3.3 packaging==26.4
python -c "import sys, runpy; sys.path.insert(0, '.music-deps'); runpy.run_path('arrange_music.py', run_name='__main__')"
```

See [tools/UPSTREAM.md](tools/UPSTREAM.md) for tool origins and license files.
