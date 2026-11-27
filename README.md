# Rail Gunner 1.0

[Download Rail Gunner 1.0](https://github.com/p8ug/rail-gunner/releases/tag/v1.0.0) · [Player and developer wiki](https://github.com/p8ug/rail-gunner/wiki) · [Contributing](CONTRIBUTOR.md)

Rail Gunner is an original grid shooter for the Commander X16 and the GameTank, written in [Prog8](https://prog8.readthedocs.io). Both versions are built from the same game code and play the same; [what differs on the GameTank](#on-the-gametank) is listed below. Version 1.0 is the Commander X16 release; the GameTank version is new in this source tree and has no release yet.

Your one-cell ship faces up and starts with a single gun in the center. At wave 6, two guns fire on either side of the ship. At wave 12, the center gun joins them. At either wall, the outside lane drops away. Each round hits at most one target.

## Ammo and Power Shot

Hold Fire (Space, SNES B, or A or B on the GameTank) for full auto. On the title screen, select Ammo and press Left or Right to choose a rule.

- **Unlimited** starts selected and fires at full speed without an ammo counter.
- **Slowdown** gradually increases the interval from six to twelve ticks as the gauge drains. The guns keep firing at zero. Release Fire to refill gradually or collect a green pod to refill immediately.
- **Auto-reload** starts each wave or retry with 40 volleys. At empty, wait 45 gameplay ticks for 12 more. You can move and hold Fire during the reload. A green pod adds six volleys and ends the reload early.
- **Ammo Packs (preview)** starts each wave or retry with 40 volleys. At eight or fewer, a nearby green pod flashes if there is time to reach it. At empty, a dry click sounds. If no fresh pod is in range, collect the yellow **+** reserve pack. Both green pods and yellow reserve packs refill the full 40-volley magazine. The reserve stays until collected or until a green pod refills the gun.

Limited modes count one unit per volley, including with two or three guns. The maximum is 40. Collect five fresh green pods in any mode to prepare a Power Shot. The next volley destroys armor and planted pods in one hit. Each projectile stops at its first target.

## Modes and waves

The title opens on Play with Classic and wave 1 selected. Up and Down select a menu row. Left and Right change the highlighted setting. Tap for a one-wave adjustment or hold to move faster through waves 1–65,535. Fire activates Play, High Scores, or Controls & Credits. The high-score table is local and includes all modes and starting waves.

| Mode | Formations |
|---|---|
| Classic | Independent, single-file butterfly trains, patrols, and armored drones. |
| Conway Life | A finite 16 × 8 B3/S23 board generates drone formations. Cells are born with three neighbors and survive with two or three. |
| HighLife | Uses B36/S23. Births also happen with six neighbors. |
| Rule 30 | An elementary cellular automaton. Each new line depends on the prior line's left, center, and right cell at each column. |
| Rule 110 | Uses the same three-cell neighborhood with a different set of outcomes, producing different attack rows. |

Each cellular formation starts on the top playable row. The next generation appears one row below it. A drone stays in its birth cell until destroyed. Rule 30 and Rule 110 evolve one 16-cell row at a time. Conway Life and HighLife evolve a 16 × 8 board and use its occupied columns for the next playable row. Life and HighLife start from two mirrored R-pentominoes. Rules 30 and 110 start from an uneven five-cell pattern. Higher waves add seed cells. Up to 36 cellular drones can occupy the board, and their sprites hold steady as new rows appear. Destroying a drone on the current growth row removes its source column from the next calculation. Reducing that row to one live column can accelerate the next generation. If Life or HighLife runs out of live cells, yellow outlines mark a small new seed near the last surviving column. Yellow outlines also mark growth near the ship. A ship directly in an incoming cell gets a white outline around it. Cellular growth stops two playable rows above the bottom. Fly underneath the formation to line up an upward shot outside a volatile drone’s blast radius. Rail guns and other hazards can still reach that space. Clear the remaining drones to advance the wave or start another pass at the top.

Classic starts with two ten-segment trains on waves 1 and 2, with a third from wave 3. They enter from alternate sides in the top four rows and move one square every four ticks through wave 5. From wave 6, more complete trains queue as waves advance, and movement accelerates in steps until wave 19. The three patrol and armored entries follow the opening trains. Cellular growth normally pauses for 14 ticks between rows on wave 1 and 8 ticks from wave 19, plus generation and spawn time. The game continues beyond wave 31 and holds the displayed wave at 65,535. The game reads existing Ion Break leaderboard files from the same directory.

Orange drones are volatile. A hit clears the surrounding 3 × 3 area, including diagonals. It can set off other volatile drones and destroy a nearby ship. Ordinary drone kills leave collectible green pods.

## Rail guns

The guns sweep the left and bottom rails one cell at a time. They alternate firing, pausing and flashing before each shot, then resume their sweeps. One enemy collision, enemy projectile, or unblocked rail shot costs a life. You start with three lives. Later rail shots and player rounds stop at the first planted rail pod in their lane.

A planted pod turns yellow at four seconds and red at seven. Fly through a red pod without stopping. An eight-tick stay on its cell kills the ship. A mature pod discharges downward at 30 seconds. The falling charge kills on contact.

The red X shots launched by transformed pods and falling charges from rail pods can both be destroyed with player fire. The title screen starts with **X Shots** set to **Shootable**. Select **Unbreakable** for a harder game.

## Controls

| Action | X16 keyboard | X16 SNES pad | GameTank gamepad |
|---|---|---|---|
| Move | Arrows, or 1 up, grave down, Left Ctrl left, 2 right | D-pad | D-pad |
| Fire or activate the selected title choice | Space | B | A or B |
| Pause or resume during play | Enter | Start | Start |
| Go back, or return to title from play | Esc | Select | C |
| Exit from the main menu | Esc | Select | (a console has nowhere to exit to) |

The grave key is immediately left of 1 on US keyboards. On the GameTank either gamepad works. After 12 seconds with Play focused and idle, the Classic attract demo plays. Any supported input returns to the title with the current mode and starting wave intact.

## On the GameTank

The rules, the 40 by 30 grid, the waves and the modes are the Commander X16's. What the machine changes:

- The picture is 128 by 128 pixels, so a cell of the arena is 3 by 4 pixels and every object is a small coloured shape. The grid shows as a dot in the corner of each cell. Text is in a 3 by 5 pixel font, and the pages of the menu are laid out for 31 characters to a line.
- The high scores are saved in the cartridge's flash memory. An Ion Break or X16 score file cannot be carried over.
- The CPU has under half the time per frame. Play is at full speed through wave 12 and a few percent slower in the busiest scenes after that (measured at waves 20 and 30).
- The soundtrack is the same tune arranged for four FM channels, a little slower (150 beats a minute for 160). A sound effect borrows a channel from the music while it plays.

It has been tested in an emulator only, not on a console.

## Run

On an X16 with writable storage, load the PRG name as shipped:

```basic
LOAD"RAILGUN.PRG",8,1
RUN
```

```sh
x16emu -c02 -mhz 8 -ram 512 -joy1 -prg RAILGUN.PRG -run -scale 2
GameTankEmulator build/gametank/rail_gunner.gtr
```

The GameTank version is a 2 MB cartridge image (`.gtr`) for [GameTankEmulator](https://github.com/clydeshaffer/GameTankEmulator) or a flash cartridge.

## Build and test

```sh
make            # build/cx16/rail_gunner.prg and build/gametank/rail_gunner.gtr
make test       # runs the GameTank version without a window and checks it
make cx16       # the X16 version in x16emu
make run        # the GameTank version in GameTankEmulator
```

`make` needs [p8p8](https://github.com/gillham/p8p8) with its `gametank` target as `p8c` (0.6.1-dev was used) and 64tass; `make test` also needs a C++ compiler and Python 3. [BUILD.md](BUILD.md) has the details, the offline build of the X16 version with the bundled tools (`sh build.sh` or `build.cmd`), and how the music and the GameTank's pictures and sound are made again.

## The source

| Where | What |
|---|---|
| `src/rail_gunner.p8` | The entry point |
| `src/game.p8`, `src/scores.p8` | The game and the high score table, the same for both machines |
| `src/cx16/`, `src/gametank/` | What a machine does in its own way: video, screens, input, sound, music, storage, start-up. The modules have the same names in both, and the build is given one of the two directories |
| `tools/gametank/` | Makes the GameTank's pictures and sound, and `gth`, the GameTank without a window that the tests run in |
| `tests/` | What `make test` runs, and what it expects |
| `docs/wiki/` | The player and developer guides |
| `.context/`, `AGENTS.md`, `setup.py` | For AI coding assistants: see below |

The [developer guide](docs/wiki/Developer-Guide.md) says more about each module. [CONTRIBUTOR.md](CONTRIBUTOR.md) is for changes.

### AI coding assistants

`AGENTS.md` is the one set of instructions for AI agents; `CLAUDE.md`, `GEMINI.md`, `.github/copilot-instructions.md`, `.cursor/rules/prog8.mdc` and `.aiassistant/rules/AGENT_RULES.md` only point at it. It sends an agent to the Prog8 compiler's own skills, documentation and library source, which are not in this repository: `python3 setup.py` downloads them into `.prog8-reference` (ignored by git) to match the installed compiler. Run it once after cloning, and again after installing another compiler version. `.context/gametank_sdk.md` is the reference for the GameTank library, with what was learned in this port.

## Music credit

“Punch Your Way Through” by northivanastan, released under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). Original source and license are on [OpenGameArt](https://opengameart.org/content/punch-your-way-through). The R22 arrangement uses the X16's YM2151 for a sub-octave bass and riff, a brighter lead, and contrasting FM kick and noise snare patches. The same loop plays during live play and attract. Gunfire, hits, warnings, explosions, pickups, and reload cues use VERA PSG. The GameTank arrangement is `tools/gametank/make_sound.py`: riff, lead, bass and drums on the four FM channels of the console's sound chip.

## Licenses

Rail Gunner is under the [MIT license](LICENSE). The music is CC0, as credited above. The bundled tools and the CPU core of the test harness keep their own licenses: see [tools/UPSTREAM.md](tools/UPSTREAM.md). The GameTank library that the program is built with comes with p8p8; parts of it are from the GameTank SDK (MIT).
