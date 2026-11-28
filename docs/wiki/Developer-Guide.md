# Developer guide

Clone [p8ug/rail-gunner](https://github.com/p8ug/rail-gunner) and work from `main`. The checkout includes p8p8 0.6.0, its standard library, 64tass 1.60.3243, and the source and generated music assets. Run `build.cmd` from Command Prompt on Windows x64 or `sh build.sh` on Linux x86-64 with glibc 2.38 or later. Both produce `build/RAILGUN.PRG`, the Commander X16 version. With a p8p8 that has the `gametank` target on the path, `make` builds both versions and `make test` runs the tests. [Build and music regeneration instructions](https://github.com/p8ug/rail-gunner/blob/main/BUILD.md)

The game is built for the Commander X16 and for the GameTank from one set of sources in `src/`. What a machine does in its own way is in a module of the same name in `src/cx16/` and in `src/gametank/`; the compiler is given `src` and one of the two (`-srcdirs src:src/cx16`).

| File | Responsibility |
|---|---|
| `rail_gunner.p8` | Entry point |
| `game.p8` | Menus' logic, player, formations, rail hazards, scoring and gameplay updates |
| `scores.p8` | Local score validation and the two-slot table |
| `*/video_platform.p8` | The grid of cells and showing a frame. X16: tile art, VERA setup, two tile maps. GameTank: a map of 3 by 4 pixel cells, drawn by the blitter into two framebuffers |
| `*/screens_platform.p8` | Every page of text and the layout of the HUD (on the GameTank with `pages.p8`) |
| `*/input_platform.p8` | X16: keyboard and SNES pads. GameTank: the gamepad in port 1 |
| `*/audio_platform.p8`, `*/music_platform.p8` | X16: PSG effects and YM2151 playback. GameTank: the SDK's FM player, with `sfx_data.p8` and `song.bin` |
| `*/storage_platform.p8` | Where the scores are kept. X16: two files. GameTank: the two save sectors of the cartridge's flash |
| `*/target_platform.p8` | Start-up, and on the GameTank which code is in which bank of the cartridge |

On the GameTank the program is a cartridge of 16 KB banks: `-meminfo` (which `make` passes) prints how full the fixed bank and each bank are, and the fixed bank and the 6 KB of RAM are the tight ones. A frame there is about 59,600 cycles, under half of the X16's.

The 1.0 sources (commit `e661603`) build `RAILGUN-1.0-REFERENCE.PRG` byte for byte; the split sources build the same game in a different arrangement. After edits, run `make test`: it runs the GameTank version in `gth`, a GameTank without a window (`tools/gametank/`), through the menu, a short game in every mode, pause, the demo and saving, and checks the speed of play. `tools/gametank/gt.py` takes screenshots and profiles a game the same way. For a fault that only a console has, `make debug` builds a cartridge that shows how far it got: see `BUILD.md`. The X16 version has no automatic test: test the affected behavior in X16Emu R49. Include keyboard and pad for input changes, and exercise waves 1, 6, and 12 for weapons or collisions. For timing work, measure actual update cycles. The 60 Hz budget at 8 MHz is about 133,333 cycles. Ordinary replays fit, while the synthetic 36-drone cascade can exceed it.

[Contributor guide](https://github.com/p8ug/rail-gunner/blob/main/CONTRIBUTOR.md) · [Agent handoff](https://github.com/p8ug/rail-gunner/blob/main/AGENTS.md) · [Replay evidence](https://github.com/p8ug/rail-gunner/blob/main/REPLAY-RESULTS.md)
