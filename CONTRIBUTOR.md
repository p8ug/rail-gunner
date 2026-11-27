# Contributing to Rail Gunner

Read [BUILD.md](BUILD.md) for the offline toolchain and [AGENTS.md](AGENTS.md) for the code map and current release baseline. Work from `main`, open a topic branch, and keep each pull request focused on one change.

- For bugs, include the release or commit, game mode, starting wave, ammo rule, X Shots setting, and exact steps. Include the hardware or X16Emu version and input device.
- For gameplay changes, describe what a player will notice and test the affected modes and entry points. Capture performance numbers for renderer, audio, or enemy-update changes.
- Run `build.cmd` or `sh build.sh`. Run the result on an 8 MHz Commander X16 or in X16Emu R49 at 8 MHz with 512 KB. Include what you verified and which checks still need hardware.
- Keep generated build outputs, high-score files, ROMs, and emulator captures out of commits. Update the shipped reference PRG only when preparing a new release. Keep the bundle's tool and music credits accurate when adding third-party material.
- Update the player docs for visible gameplay changes. The editable wiki pages are in [docs/wiki](docs/wiki). Publish corresponding updates to the GitHub wiki when authorized.
