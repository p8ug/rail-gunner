# What Prog8 made easier

Rail Gunner is written in Prog8 and built with Gillham's p8p8 compiler. Prog8 lets the bulk of the game read like game logic while keeping direct access to the X16 hardware.

- **Game state and formations.** Typed byte and word arrays represent enemy positions, projectiles, timers, and the cellular boards. Loops and subroutines make Conway Life, HighLife, Rule 30, and Rule 110 easier to read and tune than hand-writing every branch in 65C02 assembly.
- **Menus and game rules.** Choice tables, named constants, and ordinary control flow keep the title screen, ammo rules, wave selection, and high-score entry close to how the player sees them.
- **Modules and hardware access.** Language modules keep the renderer, sound, input, score storage, and game rules in separate files. The X16 library supplies frame synchronization and disk I/O. Memory-mapped register access still gives the game direct control of VERA.
- **Assembly where it matters.** Inline assembly and register-assigned subroutines make it possible to optimize collision lookup, tile writes, and the blast footprint without moving the rest of the game to assembly. The compiler's memory report helps when the program approaches the X16's unbanked RAM limit.

Prog8 helped make gameplay changes locally. Heavy scenes still benefit from cycle measurements on the target, especially the dense explosion replay.
