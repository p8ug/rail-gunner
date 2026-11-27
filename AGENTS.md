# Rail Gunner contributor handoff

The repository is `p8ug/rail-gunner`. Use `main` as the integration branch. Rail Gunner 1.0 is the first stable release. It uses the tested R30 game binary. Release tags point to the source used to build their assets. The project was previously called Ion Break. The game uses the existing save filenames so players keep their high scores.

## Build and verify

- Read [BUILD.md](BUILD.md). The compiler is p8p8 0.6.0 and the assembler is 64tass 1.60.3243. Run `sh build.sh` or `build.cmd`, then use `build/RAILGUN.PRG`.
- The 1.0 reference binary in the repository has SHA-256 `df48d71bd8f935235105e186d6bd79f238af306d84e9017bed78bf9ce92f6a3e`. An untouched checkout should build byte for byte. Rebuild after any code edit and validate the changed behavior.
- Target the 65C02 Commander X16 at 8 MHz and 512 KB. X16Emu R49 is the tested emulator. The Linux build and offline soundtrack regeneration have been reproduced. The native Windows build script and physical console still need a run.
- Conventional gameplay replays are within the 60 Hz budget. The forced 36-drone cascade can overrun it. See [REPLAY-RESULTS.md](REPLAY-RESULTS.md) for scenarios and revision-specific readings. The game sits close to the end of unbanked RAM, so check the compiler's `-meminfo` report when adding code or data.

## Code map

- `rail_gunner.p8` owns the menus, game loop, player, forms of growth, rail machinery, ammo, and collisions. It is the compiler entry point.
- `video.p8` owns VERA tile setup, the two playfield tile maps, buffered cell writes, and display assets.
- `input.p8` unifies keyboard and SNES controls. `audio.p8` drives the VERA PSG. `music.p8` plays embedded YM2151 music from `music_data.p8`.
- `scores.p8` validates and writes the two-slot score files. Keep the existing filenames and compatibility with Ion Break scores.
- The MIDI, `arrange_music.py`, and the checked-in ZSM reproduce the embedded arrangement. Preserve the music credit in the README and wiki.

## Regression checkpoints

Cellular growth stops at row 24. Rows 25–26 allow an upward shot from outside a volatile cell's blast. The one-, two-, and three-gun layouts are reached on waves 1, 6, and 12. Test weapon and movement edits at those breakpoints and at both walls. A full refill in Ammo Packs is 40 volleys. X Shots is Shootable by default, with Unbreakable as the harder choice. Test menu navigation and simultaneous movement and fire on both keyboard and SNES after control changes.

For each release, attach a standalone `RAILGUN.PRG` alongside the runtime and build ZIPs. Verify that the direct PRG and the runtime ZIP contain the same binary.

Before a handoff, record the commit, changed behavior, build/hash, actual checks, and any open verification in the pull request or release notes. [CONTRIBUTOR.md](CONTRIBUTOR.md) covers contributions and wiki maintenance.
