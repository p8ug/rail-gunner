# Rail Gunner R30

X16Emu R49 at 8 MHz and 512 KB recorded isolated effects. The menu bloop rose from 119 to 1,449 RMS sample units. The normal volley measured 1,705 RMS, about 1.4 dB above the new bloop. The new menu tone peaked at 4,088 of 32,767. The same bloop plays for single changes and rate-limited wave scrolling.

## Ion Break R29

X16Emu R49 at 8 MHz and 512 KB verified both X Shots choices on keyboard and virtual SNES pad, the two-cell gap after LIVES, and the setting's survival through attract mode and a return from play.

Instrumented runs exercised a shot from a transformed pod and a falling charge from a mature rail pod. Either can collide with a player round on the round's step or its own step. The shootable setting removed both without awarding score. The unbreakable setting let rounds pass through and left both projectile types lethal. The rail pod was still targetable before it discharged.

The 360-update Classic wave 12 and HighLife wave 20 performance replays stayed within the 133,333-cycle frame budget, with peaks of 94,532 and 94,348 cycles. The synthetic 36-drone cascades still exceed the budget. They peaked at 308,736 and 305,599 cycles, with 27 and 33 over-budget updates.

## Ion Break R28

X16Emu R49 at 8 MHz and 512 KB. Instrumented runs used the release source with a test entry point.

- Eight growth runs used the normal seed and generation routines, covering Conway Life, HighLife, Rule 30, and Rule 110 with two seeds each. The fixture freed old drone slots to allow an uninterrupted pass. Each formation reached row 24, held there while survivors remained, and generated no drones on rows 25 or 26.
- Twenty-four survivor scenarios covered all four rules, wave 1 (one gun), wave 6 (two guns), wave 12 (three guns), and the leftmost and rightmost cellular columns. Real movement and projectile processing took the ship from above the survivor to row 26, where it destroyed the volatile drone from outside the blast.
- When the wave had more enemies to spawn, another pass generated a new drone on the top row. When the quota was exhausted, clearing the survivor advanced the wave.

## Ion Break R27

X16Emu R49 at 8 MHz and 512 KB verified that green pods and yellow reserve packs refill all 40 volleys in Ammo Packs. Green pods still charge Power Shot. Auto-reload green pods still add six volleys.

## Ion Break R26 release candidate

## Performance

These 360-update instrumented replays ran at 8 MHz and 512 KB in X16Emu R49. Each used Unlimited, with title-independent scripted steering and fire. The threshold was 133,333 cycles per update.

| Replay | Peak cycles | Over budget |
|---|---:|---:|
| Classic wave 12 | 90,792 | 0 |
| HighLife wave 20 | 90,348 | 0 |
| Classic forced 36-drone cascade | 308,946 | 18 |
| HighLife forced 36-drone cascade | 304,541 | 28 |

Blast resolution was the largest section in the sampled cascade frame. R26 clips and stamps the blast footprint in assembly, uses that footprint for volatile drone effects, and coalesces simultaneous drone destruction sounds. The worst peaks fell by about 34,000 cycles from R25. The forced fixture still exceeds the budget, and its over-budget count increased.

Physical hardware testing and first-time-player feedback on the Ammo Packs preview are pending.

## Ion Break R25 ammo verification

At 8 MHz and 512 KB in X16Emu R49, the release build passed keyboard and virtual SNES checks for selecting all four ammo rules, preserving the selected rule through attract mode and play, moving while firing, pausing, and returning to the title. Audio was present in both runs.

Instrumented runs verified full-speed Unlimited, Slowdown at zero and recovery by releasing Fire or collecting a pod, 45-tick auto-reload with Fire held, an emergency pickup at the right wall, one ammo unit per one-, two-, and three-gun volley at waves 1, 6, and 12, and Power Shot against armor and planted pods.

Physical hardware and a full playthrough are pending. The frame timings below were collected on R24.

## Ion Break R24 replay results

8 MHz 65C02 with 512 KB RAM in the Commander X16 emulator. The DC VM ran the keyboard and virtual SNES-pad checks, the replay fixtures, and the dense-load timing runs. Physical hardware and controllers are pending.

## Three-gun comparison

The same wave 12 starting state ran for 60 gameplay ticks in Classic and HighLife. The ship held fire from the bottom row, with a point impact seeded just above it. We compared the active projectile positions with the tiles on the displayed foreground map after each update. A projectile covered by an effect or a stale tile counts as a masked projectile.

| Build | Classic volleys | Classic masked | HighLife volleys | HighLife masked |
|---|---:|---:|---:|---:|
| R23 | 10 | 7 | 10 | 7 |
| R24 renderer with unlimited ammo | 10 | 0 | 10 | 0 |
| R24 with ammo | 10 | 0 | 10 | 0 |

A separate test wrote 418 cells to the hidden VERA map and checked that they became visible only on presentation. The next swap retained all other cells. An eight-drone volatile chain destroyed all eight drones and left visual coverage at both ends until it faded.

## Ammo checks

A three-barrel volley charged one ammo. Clipped volleys at both walls charged one ammo and fired two legal lanes. Too few free projectile slots preserved both ammunition and charge. Holding Fire and Right through an empty magazine allowed movement, preserved the charged volley, and fired it on the first available tick after the 45-tick reload.

The green pickup supplied six volleys exactly once, canceled a reload in progress, and respected the 40-volley and five-charge caps.

## Frame timing

Each timed mode used 360 updates with input polls, scripted movement and fire, music, effects, gameplay, and both tile-map writes. A late update records a gap over 200,000 emulated CPU cycles between vertical-sync wakeups. A prolonged update can span multiple refresh periods.

| Replay | Peak cycles in one update | Late updates |
|---|---:|---:|
| Classic wave 12 | 91,825 | 0 |
| HighLife wave 20 | 92,917 | 0 |
| Classic forced 36-drone volatile cascade | 345,164 | 24 |
| HighLife forced 36-drone volatile cascade | 341,331 | 33 |

The forced-cascade fixture repeatedly filled the arena with volatile drones plus live rails, pods, missiles, and fragments. The cascade can overrun the approximately 133,000-cycle budget at 60 Hz. The regular replays used the game's normal spawns.

The build uses the R23 soundtrack bytes. Keyboard and virtual-pad play used the packaged PRG with the native input paths.
