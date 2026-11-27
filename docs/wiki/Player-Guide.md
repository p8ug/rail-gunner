# Player guide

Download the beta ZIP from [Releases](https://github.com/p8ug/rail-gunner/releases) and extract `RAILGUN.PRG`. On the Commander X16, put it on writable storage so the local leaderboard can save.

```basic
LOAD"RAILGUN.PRG",8,1
RUN
```

For X16Emu R49, run this from the directory containing the PRG. The game targets a 65C02 at 8 MHz with 512 KB.

```sh
x16emu -c02 -mhz 8 -ram 512 -joy1 -prg RAILGUN.PRG -run -scale 2
```

| Action | Keyboard | SNES |
|---|---|---|
| Move or navigate options | Arrows | D-pad |
| Fire or open the selected menu item | Space | B |
| Pause or resume | Enter | Start |
| Return, or quit from the title screen | Esc | Select |

The movement aliases are 1 for up, grave for down, Left Ctrl for left, and 2 for right. Hold Fire for auto-fire. You start with one gun, get two side guns at wave 6, and add the center gun at wave 12. The outward gun cannot fire off the grid.

- **Classic** sends butterfly trains and other moving enemies. **Conway Life, HighLife, Rule 30, and Rule 110** grow stationary enemy rows downward. They leave the bottom two rows open for approach. Rail guns and enemy shots can reach those rows.
- Orange drones detonate in a 3×3 area. Step back before shooting one. Five fresh green pods prepare a **Power Shot** that destroys armor and planted pods in one hit.
- **Ammo** starts at **Unlimited**. **Slowdown** slows sustained fire. **Auto-reload** pauses at empty. **Ammo Packs** uses green pods and yellow reserve pickups to refill the full 40-volley magazine.
- Under **X Shots**, **Shootable** lets rounds destroy the red pod shots and falling charges. **Unbreakable** increases the challenge.
- Rail guns flash before firing. A rail shot can plant a pod. A mature pod turns red and is dangerous to stand on. Its eventual falling charge is lethal on contact.

Use **Starting Wave** to practice later layouts. The local top five includes all modes, starting waves, and option choices. [Detailed rules and music credits](https://github.com/p8ug/rail-gunner/blob/main/README.md)
