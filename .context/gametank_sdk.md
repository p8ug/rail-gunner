# GameTank game development in Prog8: SDK reference

This is the reference for writing a GameTank game in Prog8 with the library
in `lib/targets/gametank/`.  That library holds Prog8 versions of the
GameTank C SDK (`gametank_sdk/src/gt/`), with the C SDK's names.  Use only
what is described here; do not write C, and do not call the C SDK.

Read the `prog8-coder` skill for the Prog8 language itself.  This file
only adds what is specific to the GameTank.

Everything here was tested in a headless GameTank emulator, not on real
hardware.  "Not tested" is said where it applies.

## 1. The machine in one page

| Thing | Fact |
|-------|------|
| CPU | W65C02, about 59,600 cycles per frame at 60 frames per second |
| Screen | 128 x 128 pixels, one byte per pixel, two framebuffers (draw to one, show the other) |
| Visible part | A TV may hide a border: 7 rows at the top, 8 at the bottom, 1 column left and right |
| Color byte | `HHHSSLLL`: hue (bits 7-5), saturation (bits 4-3), brightness (bits 2-0) |
| Blitter | Copies a rectangle from sprite RAM to the framebuffer, or fills one with a color, one pixel per cycle |
| Sprite RAM | 8 pages of 256 x 256 pixels; each page is 4 quadrants of 128 x 128 |
| RAM | About 6 KB for the program's variables (`$0600-$1dff`), plus the zero page |
| Cartridge | 2 MB flash in 16 KB banks, numbered 128-255 |
| Fixed bank | Bank 255 is always at `$c000-$ffff`: the main program lives there |
| Banked window | One other bank at a time is at `$8000-$bfff` |
| Sound | A second 6502 with FM firmware: 4 channels of 4 operators |
| Gamepads | Two; directions, A, B, C, Start |

Some colors: `0` black, `3` dark grey, `7` white, `32` near black,
`92` pink-red, `220` blue-green, `28` olive.  A color with brightness 0 is
black whatever its hue.

## 2. A program

### 2.1 Skeleton

Every GameTank program starts like this.  `%memtop $fd00` and
`%option romable` are required: the program runs from ROM.

```prog8
; file: skeleton.p8
%memtop $fd00
%option romable

%import gametank
%import gametank_input
%import gametank_draw
%import gametank_sprites
%import gametank_drawqueue
%import gametank_text

main {
    ubyte px = 60
    ubyte py = 60

    sub start() {
        gametank.sdk_init()                 ; the GameTank logo and jingle (about 3 seconds)
        gametank.init_graphics()            ; the blitter's settings for drawing
        gametank.init_music()
        gametank.text_init()
        void gametank.text_load_font()

        repeat {
            gametank.update_inputs()
            if gametank.player1_buttons & gametank.INPUT_MASK_LEFT != 0   px--
            if gametank.player1_buttons & gametank.INPUT_MASK_RIGHT != 0  px++
            if gametank.player1_buttons & gametank.INPUT_MASK_UP != 0     py--
            if gametank.player1_buttons & gametank.INPUT_MASK_DOWN != 0   py++

            gametank.queue_clear_border(0)
            gametank.queue_clear_screen(3)
            gametank.queue_draw_box(px, py, 8, 8, 92)

            gametank.text_color = gametank.TEXT_COLOR_WHITE
            gametank.text_cursor_x = 8
            gametank.text_cursor_y = 16
            gametank.text_print_string("HELLO")

            gametank.await_draw_queue()     ; everything is drawn
            gametank.flip_pages()           ; show it, draw to the other framebuffer
            gametank.await_vsync(1)
            gametank.tick_music()
        }
    }
}
```

Without the logo: leave `sdk_init()` out, and call
`gametank.init_audio_coprocessor()` before `gametank.init_music()` if the
program has sound.

### 2.2 Build and run

```
p8c -meminfo -lib lib -srcdirs src:src/gametank -asmlist -varsgolden -target gametank -out build src/game.p8
GameTankEmulator build/game.gtr
```

- The result is `build/game.gtr`, the image of the whole 2 MB cartridge.
- `-meminfo` prints how full the fixed bank is.  Read it after every build.
- `-asmlist` writes `build/game.list`, with the address of every variable.
- The `Makefile` does not know the files of the library: run `make clean`
  after a change in `lib/`.

### 2.3 Space

The fixed bank has room for 15,616 bytes (`$c000-$fcff`).  The skeleton
above already takes 10,305 of them.  So:

- Import only the modules that the game uses.
- Put the game's own code and data in other banks: section 6.
- Variables: about 6 KB in all.  A 256 byte array is a lot.

## 3. Rules for a program in ROM

These are the mistakes that are easy to make.

1. **An array or string with values is read-only.**  `ubyte[4] t = [1,2,3,4]`
   and `str s = "abc"` are in ROM; writing to them stops the build with
   "ROMable code: this writes into the program".  For a table that changes,
   declare it without values (`ubyte[4] t`) and fill it in code.  A single
   variable with a start value (`ubyte lives = 3`) can be changed.
2. **Random numbers: the `_rom` routines.**  `math.rnd_rom()`,
   `math.rndw_rom()`, `math.randrange_rom(n)`, `math.randrangew_rom(n)`,
   after one `math.rndseed_rom($00c2, $1137)`.  `math.rnd()` and the others
   without `_rom` do not build.
3. **Do not name a parameter or variable after a builtin**: not `len`, `min`,
   `max`, `abs`, `sqrt`, `msb`, `lsb`.  The errors are confusing
   ("identifier kind", "can only loop over unsigned bytes").
4. **Do not name a variable `a`, `x` or `y`** in code that goes into the
   `gametank` block.  In `main` and your own blocks it is fine.
5. **`"\n"` is character 13**, and so is `"\r"`.  Character 10 is `"\x0a"`.
6. **No signed 16 bit remainder**: `word % word` does not build.  Cast both
   sides to `uword` when they are not negative.
7. **A bit test needs `!= 0` or `== 0`**: `if buttons & MASK != 0`.  (`&`
   binds tighter than `!=`, so no parentheses are needed.)
8. **A `ubyte` wraps at 256**, also in the middle of an expression: write
   `(x as uword) + w` when the sum can pass 255.
9. **Stay in RAM bank 0.**  Do not call `gametank.rambank()`: the draw queue
   and the interrupts need RAM bank 0.
10. **`cx16.r6` to `cx16.r10` are overwritten by inflate**, so by
    `load_spritesheet`, `allocate_sprite` and `text_load_font`.
    `cx16.r12` and `cx16.r13` carry arguments of `DIRECT_DRAW_COLOR`.

## 4. Drawing

There are two ways to use the blitter.  Both draw to the framebuffer that
is not shown; `gametank.flip_pages()` swaps the two.

| | Draw queue | Direct mode |
|---|---|---|
| Module | `gametank_drawqueue` | `gametank_draw` |
| A call | puts the blit in a queue and returns | starts the blit at once |
| Waiting | once per frame: `await_draw_queue()` | after every blit: `await_drawing()` |
| Use it for | most games | a few big blits, or special settings (tiling, no clipping) |

Use the draw queue unless there is a reason not to.  The two can be mixed:
a `direct_prepare_` routine waits for the queue first.

A color argument is the color byte of section 1.  A sprite's pixels are
color bytes too; color 0 is not drawn (transparent).

### 4.1 Frames and timing (module `gametank`)

| Routine | What it does |
|---------|--------------|
| `gametank.init_graphics()` | The blitter's settings; call once at the start |
| `gametank.flip_pages()` | Show what was drawn; draw to the other framebuffer from now on |
| `gametank.await_vsync(frames)` | Wait for that many frames (`ubyte`) |
| `gametank.await_drawing()` | Wait until the blit that is going on is done |
| `gametank.sdk_init()` | The logo and the jingle; starts the audio too |

The loop of a frame: read input, queue the drawing, `await_draw_queue()`,
`flip_pages()`, `await_vsync(1)`, `tick_music()`.

A frame that takes longer than 59,600 cycles shows for two frames (30 per
second).  A call to `queue_draw_sprite` costs some 600-700 cycles with its
interrupt, so a frame has room for about 80 of them, less what the game's
own code takes.

### 4.2 Draw queue (module `gametank_drawqueue`)

| Routine | What it does |
|---------|--------------|
| `gametank.queue_clear_screen(color)` | A box over the picture, without the border |
| `gametank.queue_clear_border(color)` | Four boxes over the border |
| `gametank.queue_draw_box(dst_x, dst_y, w, h, color)` | A filled box, clipped to the screen |
| `gametank.queue_draw_sprite(dst_x, dst_y, w, h, src_gx, src_gy, slot)` | `w` x `h` pixels from (`src_gx`, `src_gy`) of a sprite slot |
| `gametank.queue_draw_sprite_frame(slot, dst_x, dst_y, frame, flip)` | A frame of the slot's frame table; `flip` is a `SPRITE_FLIP_` constant |
| `gametank.await_draw_queue()` | Wait until everything queued is drawn |

- The queue holds 250 blits.  When it is full, a queue call waits until it
  is empty: nothing is lost, the frame only takes longer.
- A blit goes to the framebuffer that is drawn to when it is queued.  So
  call `await_draw_queue()` before `flip_pages()`.
- All arguments are `ubyte`.

### 4.3 Sprites (module `gametank_sprites`)

A sprite sheet is 128 x 128 pixels (16,384 bytes, row after row), packed
with deflate: section 7.  Loading it puts it in a quadrant of sprite RAM
and gives a **slot** number, which the drawing routines take.

| Routine | What it does |
|---------|--------------|
| `gametank.allocate_sprite(&sheet, bank) -> ubyte` | Find a free quadrant, unpack the sheet there; gives the slot, or `gametank.SPRITE_SLOT_NONE` |
| `gametank.free_sprite(slot)` | Give the quadrant back |
| `gametank.set_sprite_frametable(slot, &frames, bank)` | Say where the slot's frame table is |
| `gametank.clear_spritebank(quadrant)` | Fill a quadrant with 0 |
| `gametank.load_spritesheet(&sheet, bank, quadrant)` | Unpack to a quadrant that you choose: page (0-7) + `QUADRANT_0`..`QUADRANT_3` |
| `gametank.get_sprite_slot(mask) -> ubyte` | Reserve room for a bigger sheet (`PAGE_MASK_WIDE`, `PAGE_MASK_TALL`, `PAGE_MASK_FULL`) without loading |

- `bank` is the ROM bank where the data is; 255 for data in the main
  program.
- There is room for 32 sheets of 128 x 128.
- Loading a sheet takes a third of a second or so, and there is no vsync
  meanwhile: load at the start of the game or of a level, not during play.
- A frame table is 8 bytes for each frame: `x`, `y` (where the frame is
  drawn, from the position that is asked for; a signed offset as a byte),
  `w`, `h`, `gx`, `gy` (where it is in the sheet), and two bytes that are
  not used.

```prog8
; file: sprites.p8
%memtop $fd00
%option romable

%import gametank
%import gametank_sprites
%import gametank_drawqueue
%import spritedata

main {
    sub start() {
        ubyte hero
        ubyte frame
        gametank.init_graphics()
        hero = gametank.allocate_sprite(&spritedata.sheet, 130)
        gametank.set_sprite_frametable(hero, &spritedata.frames, 130)

        repeat {
            gametank.queue_clear_border(0)
            gametank.queue_clear_screen(3)
            ; 16 * 16 pixels from (32, 0) of the sheet
            gametank.queue_draw_sprite(20, 40, 16, 16, 32, 0, hero)
            ; a frame of the table, and the same one mirrored
            gametank.queue_draw_sprite_frame(hero, 64, 64, frame, gametank.SPRITE_FLIP_NONE)
            gametank.queue_draw_sprite_frame(hero, 96, 64, frame, gametank.SPRITE_FLIP_X)
            gametank.await_draw_queue()
            gametank.flip_pages()
            gametank.await_vsync(8)
            frame = (frame + 1) & 3
        }
    }
}
```

`spritedata` is the module of section 6.2.

### 4.4 Direct mode (modules `gametank` and `gametank_draw`)

Call a `direct_prepare_` routine once, then draw.  After each blit call
`gametank.await_drawing()` before the next blit or the next change of a
setting.

| Routine | What it does |
|---------|--------------|
| `gametank.direct_prepare_box_mode()` | Settings for filled boxes |
| `gametank.DIRECT_DRAW_COLOR(dst_x, dst_y, w, h, color)` | Fill a box |
| `gametank.direct_prepare_sprite_mode(slot)` | Settings for sprites from a slot, color 0 transparent |
| `gametank.direct_quick_select_sprite(slot)` | Another slot, the other settings stay |
| `gametank.DIRECT_DRAW_SPRITE(dst_x, dst_y, w, h, src_gx, src_gy)` | Blit from the selected slot |
| `gametank.direct_draw_sprite_frame(slot, dst_x, dst_y, frame, flip)` | A frame of the frame table (module `gametank_sprites`) |
| `gametank.direct_transparent_mode(bool)` | false: color 0 is drawn too |
| `gametank.direct_tiled_mode(bool)` | true: a blit repeats the 16 x 16 pixels where its source starts |
| `gametank.direct_clip_mode(mode)` | `CLIP_MODE_NONE`, `CLIP_MODE_X`, `CLIP_MODE_Y`, `CLIP_MODE_XY` |
| `gametank.direct_prepare_array_mode()` | `$4000-$7fff` is the framebuffer, for the CPU to read and write |
| `gametank.direct_prepare_sprite_ram_array_mode(slot)` | `$4000-$7fff` is the slot's quadrant of sprite RAM |

- The biggest blit is 127 x 127: clear the screen with
  `DIRECT_DRAW_COLOR(0, 0, 127, 127, color)`.
- Flipping with `DIRECT_DRAW_SPRITE`: add 128 to `w` and pass
  `~src_gx - (w-1)` as `src_gx` (the same for `h` and `src_gy`).  The
  `_frame` routines do this themselves.
- In an array mode a pixel is `@($4000 + y*128 + x)`.  The blitter is off
  then: call a `direct_prepare_box_mode()` or `_sprite_mode()` before the
  next blit.

### 4.5 Text (module `gametank_text`)

| Routine or variable | What it is |
|---------------------|------------|
| `gametank.text_init()` | Cursor at 0,0; width 128; black |
| `gametank.text_load_font() -> ubyte` | Load the 8 x 8 font into a sprite slot; call once, after `init_graphics()` |
| `gametank.text_print_string(text)` | Print at the cursor |
| `gametank.text_sprint_num(buffer, num)` | Two digits of a number 0-99 into a buffer (no 0 after them) |
| `gametank.text_cursor_x`, `text_cursor_y` | Where the next character goes, in pixels |
| `gametank.text_color` | `gametank.TEXT_COLOR_BLACK` or `gametank.TEXT_COLOR_WHITE` |
| `gametank.text_print_line_start`, `text_print_width` | The left edge and the width of a line, in pixels |

- 16 characters fit on a line of the screen, 14 inside the border.
- The text goes on top of what is there.  Printing waits for the draw queue
  and draws at once, so queue the background first.
- `"\n"` goes to `text_print_line_start` and a line down.  A line that is
  too long goes on on the next line.
- The font has the character codes up to 127, in black and in white only.
- A number: Prog8's `conv` module makes the digits (`conv.str_ub(n)`,
  `conv.str_uw(n)`), and `text_print_string(conv.string_out)` prints them.
- For a buffer to print from, declare `ubyte[3] buf` (no values, so it is
  in RAM): `text_sprint_num(buf, n)` then `text_print_string(buf)`.  The
  third byte stays 0.

The font takes 1,187 bytes of the fixed bank, and a sprite slot.

## 5. Input, sound, saving

### 5.1 Gamepads (module `gametank_input`)

Call `gametank.update_inputs()` once per frame.

| Variable | Meaning |
|----------|---------|
| `gametank.player1_buttons` | Buttons that are down now (`uword`) |
| `gametank.player1_new_buttons` | Down now and not at the previous `update_inputs()`: use for "pressed" |
| `gametank.player1_old_buttons` | Down at the previous `update_inputs()` |
| `gametank.player2_buttons` and so on | The same for the second gamepad |

Masks: `gametank.INPUT_MASK_UP`, `_DOWN`, `_LEFT`, `_RIGHT`, `_A`, `_B`,
`_C`, `_START`, `_ALL_KEYS`, `_ANY_DIRECTION`.

```prog8
if gametank.player1_new_buttons & gametank.INPUT_MASK_A != 0 {
    ; A was pressed this frame
}
```

For paddle controllers: `gametank.update_paddle_inputs()` in place of
`update_inputs()`, the `INPUT_MASK_PADDLE_` masks, and
`gametank.get_paddle_rotation(port)`.  Not tested with a paddle.

### 5.2 Music and sound effects (modules `gametank_audio`, `gametank_music`)

`%import gametank` brings both.

| Routine | What it does |
|---------|--------------|
| `gametank.init_audio_coprocessor()` | Start the sound chip; `sdk_init()` does this already |
| `gametank.init_music()` | Once, after the sound chip is started |
| `gametank.tick_music()` | Once per frame, always |
| `gametank.play_song(&song, bank, repeat)` | `gametank.REPEAT_NONE`, `REPEAT_LOOP` or `REPEAT_RESUME` (the song that plays now goes on afterwards) |
| `gametank.stop_music()` | Silence |
| `gametank.pause_music()`, `gametank.unpause_music()` | |
| `gametank.play_sound_effect(&sfx, bank, channel)` | On channel 0-3; it takes the channel from the music until it is over |
| `gametank.play_boot_jingle()` | The SDK's jingle |

A song is the binary file that the GameTank SDK's tracker writes
(`gametank_sdk/assets/sdk_default/jingle.bin` is one).  Include it with
`%asmbinary`; there is no way to make one in Prog8.

A sound effect is easy to write by hand: the number of frames, the
feedback (0 is fine), and then 8 bytes for each frame: the loudness of
the 4 operators (0-15) and the notes of the 4 operators (0-107, 12 for
each octave; 60 is about 520 Hz).  For a plain tone give only the fourth
operator a loudness, as below.

```prog8
; 6 frames, falling
ubyte[] zap = [6, 0,
    0,0,0,15, 72,72,72,72,   0,0,0,15, 68,68,68,68,   0,0,0,12, 64,64,64,64,
    0,0,0,10, 60,60,60,60,   0,0,0,6,  56,56,56,56,   0,0,0,3,  52,52,52,52]
...
gametank.play_sound_effect(&zap, 255, 3)
```

A priority can be added to the channel, 16 for each step
(`3 | (2 << 4)`): an effect with a lower priority than the one that plays on
that channel is not started.

Not tested: `REPEAT_RESUME`, `pause_music`, `unpause_music`, and songs or
effects in a bank other than 255.

### 5.3 Saving (module `gametank_persist`)

The saves are in ROM bank 254.  Never put anything else there.

| Routine | What it does |
|---------|--------------|
| `gametank.save_write(&data, dest, count) -> bool` | Write `count` bytes (1-255) from RAM to `dest`; true when they are there |
| `gametank.save_read(src, &data, count)` | Copy `count` bytes from the save bank to RAM |
| `gametank.clear_save_sector()` | Erase `$8000-$9fff`: all `$ff` again |
| `gametank.clear_save_sector2()` | Erase `$a000-$bfff` |
| `gametank.save_erase(sector) -> bool` | The same, with a result |

- `dest` and `src` are addresses from `gametank.SAVE_SECTOR1` (`$8000`) or
  `gametank.SAVE_SECTOR2` (`$a000`); each sector is 8,192 bytes.
- **A byte can be written once.**  Writing only changes 1 bits to 0, and a
  new cartridge is all `$ff`.  To write the same place again, erase the
  whole sector first.
- An erase stops the game, on real hardware probably for a second or so
  (the emulator does it at once).  Do it on a menu screen, not during play.
- What is written must be in RAM.

```prog8
; file: save.p8
%memtop $fd00
%option romable

%import gametank
%import gametank_persist

main {
    const ubyte SAVE_MAGIC = $42
    ubyte[4] savedata           ; magic, level, lives, score

    sub start() {
        gametank.init_graphics()
        gametank.save_read(gametank.SAVE_SECTOR1, &savedata, 4)
        if savedata[0] != SAVE_MAGIC {
            ; no save yet
            savedata[1] = 1
            savedata[2] = 3
            savedata[3] = 0
        }
        ; ... play ...
        savedata[0] = SAVE_MAGIC
        gametank.clear_save_sector()
        void gametank.save_write(&savedata, gametank.SAVE_SECTOR1, 4)
        repeat {}
    }
}
```

## 6. Banks: more room for code and data

| Banks | Use |
|-------|-----|
| 128-253 | The game's code and data |
| 254 | Saves only |
| 255 | The main program (fixed bank) |

### 6.1 Reading data from a bank

Routines that take an address and a bank (`allocate_sprite`,
`set_sprite_frametable`, `play_song`, `play_sound_effect`) switch banks
themselves.  To read data of your own (module `gametank_banking`):

```prog8
gametank.push_rom_bank()            ; remember the bank that is there
gametank.change_rom_bank(131)
value = @(address)                  ; an address in $8000-$bfff
gametank.pop_rom_bank()             ; and back
```

### 6.2 Putting data in a bank

A module of its own, with `%overlay` in its first line: the bank number and
the name of the block.  Everything in that block goes to that bank, at
`$8000` and up.

```prog8
; file: spritedata.p8
%overlay 130, spritedata

spritedata {
%option merge, overlay_data

sheet:
    %asmbinary "sheet.deflate"
frames:
    %asmbinary "frames.bin"
}
```

The main program imports it (`%import spritedata`) and uses the labels as
`&spritedata.sheet` with bank 130.  A bank holds 16,384 bytes; `-meminfo`
shows how full each one is.

### 6.3 Putting code in a bank

A block can have subroutines in a bank the same way: `%overlay 131, level1`
as the first line of the module, and `level1 { sub run() { ... } }`.  The
main program calls `level1.run()` as any other subroutine; the compiler
switches the bank for the call and back.  Without `overlay_data` in
`%option`.

- Code in a bank can call the library and the main program.
- Code in a bank cannot read data in another bank directly: let a routine
  of the main program do that.
- Data that an overlay's code reads can be in the same block.

## 7. Making the data

Deflate is the raw kind: no zlib or gzip header.

```python
# a 128 x 128 sprite sheet: 16384 color bytes, row after row, 0 = transparent
import zlib
pixels = bytearray(16384)
# ... pixels[y * 128 + x] = color ...
packer = zlib.compressobj(9, zlib.DEFLATED, -15)
open("sheet.deflate", "wb").write(packer.compress(bytes(pixels)) + packer.flush())

# a frame table: 8 bytes for each frame
frames = b""
for gx, gy in ((0, 0), (16, 0), (32, 0), (48, 0)):
    # x, y: -8 as a byte, so that the frame is centered on the position
    frames += bytes([0xf8, 0xf8, 16, 16, gx, gy, 0, 0])
open("frames.bin", "wb").write(frames)
```

A color in an image: pick the nearest color byte.  The GameTank SDK has a
palette image and a converter for BMP files (`gametank_sdk/scripts/`);
its `.gtg` output is the 16,384 bytes to pack.

Put the files next to the Prog8 module that includes them.

## 8. Other modules

| Module | For |
|--------|-----|
| `zlib` | `zlib.inflate(src, dest)`: unpack deflate data of your own (level maps) to RAM.  Uses `cx16.r6`-`cx16.r10` |
| `gametank_util` | `gametank.nop5()`, `nop10()`, `stop()`, `PROFILER_START(id)`, `PROFILER_END(id)` |
| `gametank_random` | The C SDK's random numbers; only for a game converted from C.  Use `math` (section 3) |
| `gametank_midi_fm` | The C SDK's older music player (`midi_fm.play_song` ...); only for old songs |
| `textio` (`txt`) | Prog8's usual text output, drawn by the CPU in a 5 x 6 font, 24 x 20 characters.  For debugging; `gametank_text` is the one for a game |
| `graphics` | Prog8's usual lines, circles and so on, drawn by the CPU.  Slow |
| `math`, `conv`, `strings` | Prog8's standard modules work.  `math`: the `_rom` routines only |

## 9. When something goes wrong

| What you see | Likely cause |
|--------------|--------------|
| "ROMable code: this writes into the program" | Writing to an array or string that has values (rule 1), or `math.rnd()` (rule 2) |
| "not defined symbol" for a `gametank.` name | The module that has it is not imported |
| The program is too big for the fixed bank | Move code and data to banks (section 6) |
| Nothing is drawn | No `flip_pages()`; or drawing in an array mode without a `direct_prepare_` after it |
| Half of a frame's drawing is missing or flickers | `flip_pages()` before `await_draw_queue()` |
| A sprite is garbage | Wrong bank for the sheet; or the sheet is not raw deflate; or not 16,384 bytes |
| The game hangs at a blit | `await_drawing()` after a blit of fewer than 5 pixels in direct mode: a note in the library says that GameTankEmulator may not signal its end |
| The game runs at half speed | A frame takes more than 59,600 cycles: fewer or smaller blits |
| A save reads back wrong | The place was written before without an erase |
| No sound | No `tick_music()` every frame; or no `init_audio_coprocessor()` (without `sdk_init()`) |

To look inside a running game: `build/game.list` has the address of every
variable, and an emulator's memory view shows RAM.
