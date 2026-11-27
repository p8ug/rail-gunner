# Rail Gunner R30

[Beta downloads](https://github.com/p8ug/rail-gunner/releases) · [Player and developer wiki](https://github.com/p8ug/rail-gunner/wiki) · [Contributing](CONTRIBUTOR.md)

Rail Gunner is an original grid shooter for the Commander X16. Your one-cell ship faces up and starts with a single gun in the center. At wave 6, two guns fire on either side of the ship. At wave 12, the center gun joins them. At either wall, the outside lane drops away. Each round hits at most one target.

## Ammo and Power Shot

Hold Space or SNES B for full auto. On the title screen, select Ammo and press Left or Right to choose a rule.

- **Unlimited** starts selected and fires at full speed without an ammo counter.
- **Slowdown** gradually increases the interval from six to twelve ticks as the gauge drains. The guns keep firing at zero. Release Fire to refill gradually or collect a green pod to refill immediately.
- **Auto-reload** starts each wave or retry with 40 volleys. At empty, wait 45 gameplay ticks for 12 more. You can move and hold Fire during the reload. A green pod adds six volleys and ends the reload early.
- **Ammo Packs (preview)** starts each wave or retry with 40 volleys. At eight or fewer, a nearby green pod flashes if there is time to reach it. At empty, a dry click sounds. If no fresh pod is in range, collect the yellow **+** reserve pack. Both green pods and yellow reserve packs refill the full 40-volley magazine. The reserve stays until collected or until a green pod refills the gun.

Limited modes count one unit per volley, including with two or three guns. The maximum is 40. Collect five fresh green pods in any mode to prepare a Power Shot. The next volley destroys armor and planted pods in one hit. Each projectile stops at its first target.

## Modes and waves

The title opens on Play with Classic and wave 1 selected. Up and Down select a menu row. Left and Right change the highlighted setting. Tap for a one-wave adjustment or hold to move faster through waves 1–65,535. Space or SNES B activates Play, High Scores, or Controls & Credits. The high-score table is local and includes all modes and starting waves.

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

| Action | Keyboard | SNES |
|---|---|---|
| Move | Arrows, or 1 up, grave down, Left Ctrl left, 2 right | D-pad |
| Fire or activate the selected title choice | Space | B |
| Pause or resume during play | Enter | Start |
| Go back, return to title from play, or exit from the main menu | Esc | Select |

The grave key is immediately left of 1 on US keyboards. After 12 seconds with Play focused and idle, the Classic attract demo plays. Any supported input returns to the title with the current mode and starting wave intact.

## Run and build

For offline build steps using the bundled tools, see [BUILD.md](BUILD.md).

On an X16 with writable storage, load the PRG name as shipped:

```basic
LOAD"RAILGUN.PRG",8,1
RUN
```

The build ZIP includes the original PRG as `RAILGUN-R30-REFERENCE.PRG`. The build scripts produce `build/RAILGUN.PRG` with the soundtrack embedded.

```sh
x16emu -c02 -mhz 8 -ram 512 -joy1 -prg RAILGUN.PRG -run -scale 2
mkdir -p build
p8c -target cx16 -out build rail_gunner.p8
```

Build with p8p8 v0.6.0 and 64tass. The optional music regeneration step is `python3 arrange_music.py` with Python and Mido. This regenerates `PUNCH.ZSM` and `music_data.p8` from the included source MIDI.

## Music credit

“Punch Your Way Through” by northivanastan, released under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). Original source and license are on [OpenGameArt](https://opengameart.org/content/punch-your-way-through). The R22 arrangement uses the X16's YM2151 for a sub-octave bass and riff, a brighter lead, and contrasting FM kick and noise snare patches. The same loop plays during live play and attract. Gunfire, hits, warnings, explosions, pickups, and reload cues use VERA PSG.
