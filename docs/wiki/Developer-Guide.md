# Developer guide

Clone [p8ug/rail-gunner](https://github.com/p8ug/rail-gunner) and work from `main`. The checkout includes p8p8 0.6.0, its standard library, 64tass 1.60.3243, and the source and generated music assets. Run `build.cmd` from Command Prompt on Windows x64 or `sh build.sh` on Linux x86-64 with glibc 2.38 or later. Both produce `build/RAILGUN.PRG`. [Build and music regeneration instructions](https://github.com/p8ug/rail-gunner/blob/main/BUILD.md)

| File | Responsibility |
|---|---|
| `rail_gunner.p8` | Entry point, menus, player, formations, rail hazards, scoring logic and gameplay updates |
| `video.p8` | Tile art, VERA setup, draw buffers, tile-map presentation |
| `input.p8` | Keyboard and SNES input |
| `audio.p8`, `music.p8` | PSG effects and YM2151 playback |
| `scores.p8` | Local score validation and two-slot persistence |

Before changing a subsystem, build the baseline and compare it byte for byte with `RAILGUN-R30-REFERENCE.PRG`. After edits, test the affected behavior in X16Emu R49. Include keyboard and pad for input changes, and exercise waves 1, 6, and 12 for weapons or collisions. For timing work, measure actual update cycles. The 60 Hz budget at 8 MHz is about 133,333 cycles. Ordinary replays fit, while the synthetic 36-drone cascade can exceed it.

[Contributor guide](https://github.com/p8ug/rail-gunner/blob/main/CONTRIBUTOR.md) · [Agent handoff](https://github.com/p8ug/rail-gunner/blob/main/AGENTS.md) · [Replay evidence](https://github.com/p8ug/rail-gunner/blob/main/REPLAY-RESULTS.md)
