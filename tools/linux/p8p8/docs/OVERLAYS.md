# Overlays

An overlay is a part of a program's code that is kept outside main memory and
is only there while it runs.  With overlays a program can be larger than the
memory its machine gives it at once.

Overlays are p8p8's own: Prog8's reference compiler has no such thing.  This
page is for writing programs with them.  How the compiler does it is in
[DESIGN.md](DESIGN.md), "Overlays".

## A program with overlays

```prog8
%import textio
%zeropage basicsafe

main {
    sub start() {
        txt.print_uw(report.total(3, 4))
        txt.nl()
        editor.run()
    }
}

report {
    %overlay 1

    uword calls                 ; in main memory, like every variable

    sub total(uword a, uword b) -> uword {
        calls++
        return a + b
    }
}

editor {
    %overlay 2

    sub run() {
        txt.print("editing, after ")
        txt.print_uw(report.calls)
        txt.print(" call")
        txt.nl()
    }
}
```

`%overlay n` in a block puts the code of that block into overlay n.  Nothing
else changes: the block's subroutines are called as before, from the main
program, from other overlays and from the overlay itself, and they call
whatever they like.  The compiler writes what a call needs to get there and
back.

Several blocks may share a number; they are then in the same overlay and
call each other at no extra cost.  The `main` block cannot be in an overlay.

### One subroutine

`%overlay n` can also stand in a subroutine, and then only that subroutine
goes into the overlay:

```prog8
main {
    sub start() {
        ...
    }

    sub substitute() {
        %overlay 3
        ...
    }
}
```

That is the way to move code out of `main`, or to take one large
subroutine out of a block (which may itself be in another overlay).
Subroutines declared inside it go with it.  `main.start` stays in main
memory.  Blocks are the tidier unit: what belongs together is together, and
calls between its subroutines cost nothing extra.

### All in one place

The same can be said at the top of a module, outside every block, as a list:
the overlay's number, then the blocks and the subroutines (`block.name`)
that are in it.

```prog8
%import editor

%overlay 1, view, main.execute, main.substitute
%overlay 2, report
```

The number can be the name of a constant, here and inside a block or a
subroutine, so that an overlay is moved by changing one number:

```prog8
%overlay banks.CODE, view, main.execute
%overlay banks.TITLE, title

banks {
    const ubyte CODE = 128
    const ubyte TITLE = CODE + 2
}
```

Write the constant with its block's name; it has to come out at 1 to 255.

Then nothing in the blocks themselves says anything about overlays.  That
suits a program whose sources are shared between machines or between
compilers: the list is in the one file that is for the machine with
overlays, and it shows at a glance what is where.  A program that uses the
list and also has `%overlay` inside a block or a subroutine gets a warning;
where both name the same thing, the list counts.

## Building and running

```
p8c -target cx16 -out build game.p8
```

writes two files that belong together: `game.prg` and `game.non`.  Put both
on the same disk or in the same directory and run `game.prg`.

`-meminfo` prints what the main program and each overlay take and what is
left, what is in an overlay that has more than one thing in it, and what
the overlays cost in main memory:

```
memory of p8vi_cx16ovl (cx16):
  main program  $0801-$8a99  33433 bytes, 5222 free below $9f00
  overlay   1   $a000-$b48b   5260 bytes, 2932 free of 8192
      main.execute                       554
      main.subst_cmd                     757
      main.save_file                     271
      view                              2290
      ...
  for them in main memory 813 bytes: the ways in 210, the ways out and back 564, the code they share 39
  files: p8vi_cx16ovl.prg (the loader) 306 bytes, p8vi_cx16ovl.non 36651 bytes
```

So moving those 5,260 bytes out of main memory cost 813 there.

### What can go into an overlay?

`-overlayinfo` answers that for a program as it is: every block with its
bytes in main memory, and for a block that stays (`main` above all) its
subroutines of 100 bytes and more.

```
what could go into an overlay, of p8vi_cx16ovl (cx16):
  main                             13691   no: main stays; its subroutines can go one by one
      main.key_mode_nav                 1425   yes
      main.execute                             in overlay 1
      ...
  buffer                           12038   yes
  xmem                                24   no: its subroutine select chooses a bank itself
  prog8_math                         279   no: the compiler's own code calls it
  conv                               323   no: assembly in txt.print_uw names conv.internal_uword2decimal
  diskio                            1054   yes
```

It says no when

- the compiler's own code calls the block by name (the runtime: `prog8_lib`,
  `prog8_math`, `sys`, `floats`...);
- the block has a place of its own (an address, a jump table);
- assembly somewhere else names one of its subroutines, since only calls in
  Prog8 code are led into an overlay (assembly inside the block itself is no
  obstacle to moving the whole block);
- a subroutine is installed as an interrupt handler;
- on the X16 and the GameTank, a subroutine chooses a bank itself;
- on the machines that copy an overlay in, and where it is ROM, the block's
  assembly keeps variables in its own code (it writes to a place that the
  same assembly defines).

Blocks of the library are judged like any other, and one that gets a yes
can be named in an `%overlay` list (`%overlay 2, diskio`).  The gain is
smaller than the block: every one of its subroutines that is called from
outside needs its way in.

**A yes is not a promise.**  It means nothing in how the program is put
together stands against the move.  What the compiler cannot see is what a
subroutine does with addresses: one that reads or writes through an address
in the overlay's window (p8vi's `load_file`, which reads a file straight
into a page of banked text) has to stay in main memory, and so on the X16
does code that is called with such an address.  `buffer` gets a yes above
and must not go: it is the code that maps the banked text.

An overlay that does not fit is an error from the assembler that names it:
"overlay 2 is too large by 131 bytes".  Move a subroutine to another block.

## The machines

| Machine | Where the overlays are | Where one runs | An overlay holds |
|---|---|---|---|
| Commander X16 (`-target cx16`, also `-cpu 65816`) | RAM bank n of high memory | $a000-$bfff, by choosing the bank | 8 KB |
| C64 (`-target c64`) | a RAM Expansion Unit | $c000-$cfdf, copied in | 4 KB |
| C128 (`-target c128`) | a RAM Expansion Unit | $b000-$bfff, copied in | 4 KB |
| MEGA65 (`-target mega65`) | memory from $40000 on (banks 4 and 5) | $a000-$bfff, copied in by DMA | 8 KB |
| GameTank (`-target gametank`) | bank n of the cartridge, 128 to 254 | $8000-$bfff, by choosing the bank | 16 KB |

On every other machine `%overlay` is ignored and the program is built in one
piece, if it fits.  That is also a way to try a program on the host
(`-target llvm64`) or to compare.  `-nooverlays` does the same on a machine
that has overlays: one source, built with them and without.

**Commander X16.**  Overlay n is RAM bank n, so the numbers choose the
banks: `%overlay 10` and `%overlay 11` leave banks 1 to 9 alone.  A program
that keeps data in banks has to keep it out of the overlays' banks: nothing
stops it from writing over its own code there.  `game.prg` is a small loader:
it reads `game.non`, which has the main program and all overlays in it, and
starts the program.  The banks above the last overlay are the program's.

**C64 and C128.**  `game.prg` is the program itself.  The first time it
calls into an overlay it reads `game.non` from the disk it was loaded from
and puts the overlays into the REU; after that the disk is not needed.  The
overlays take the REU from its start, $1000 bytes each; what the program
keeps there itself belongs behind the last one.  The main program ends
below the window: it has up to $c000 on the C64 and up to $b000 on the
C128.

On the C64 and the C128 a program whose overlays are numbered from 1 uses
the REU from its start; a gap in the numbers is a gap there.

**MEGA65.**  As on the C64, with the machine's own memory in place of an
REU: `game.prg` is the program, and the first call into an overlay reads
`game.non` from drive 8.  Nothing is banked or mapped, so the ROM is where
it always is.  The main program has up to $a000.  Sixteen overlays fit in
banks 4 and 5; a program that keeps data of its own there has to stay clear
of them.

**GameTank.**  Overlay n is bank n of the cartridge, so the numbers are 128
to 254; the main program is in the fixed bank (255) at $c000.  `p8c` writes
one file, `game.gtr`: the whole 2 MB cartridge, with the main program, the
overlays in their banks, and $ff everywhere else.  The banks that are not
overlays are the program's, for assets it chooses with `cartbank`; as on the
X16 the bank the main program chose is still chosen after a call into an
overlay, and when an overlay calls into the main program.

What a block includes with `%asmbinary`, or defines in an `%asm` block, is in
the block's bank with its code.  That is the place for an asset and the
subroutine that uses it: whoever calls the subroutine need not know which
bank the asset is in.

```prog8
%overlay 130, title

title {
    %option overlay_data
picture:
    %asmbinary "title.rle"

    ; unpacks the picture into the sprite memory
    sub show() -> uword {
        return compression.decode_rle(picture, gametank.SCREENRAM, 128*128)
    }
}
```

`%option overlay_data` is what lets `show` hand the picture's address to a
routine of the library: from such a block the library is called with the
block's bank still in the window.  Without it every call out of an overlay
finds the main program's bank there, which is right for code but would
have `decode_rle` read something else at that address.  The program's own
subroutines in the main program always get the main program's bank.

A test picture of 10 KB, moved this way out of the fixed bank, leaves 11,397
bytes free there where 1,190 were.

## What is where

**Code is in the overlay; data is not, unless you say so.**  The variables
of an overlay block, its strings and its arrays are in main memory with all
the others (on the GameTank: the variables in RAM, the strings and arrays
with values in the fixed bank).  So

- a variable keeps its value whichever overlay is running, and any code may
  use it;
- a string or an array of an overlay block can be passed to any subroutine;
- an overlay does not make a program's data smaller, only its code.

**`%option overlay_data` puts a block's strings and arrays into its overlay.**
With it the block's strings, its arrays that have values, and the string
literals that only its code uses are in the overlay beside the code:

```prog8
%overlay 129, credits

credits {
    %option overlay_data
    str title = "Space Man GT"
    ubyte[] colours = [3, 14, 15, 92]

    sub show() {
        txt.print(title)
        txt.print(" by many hands")
    }
}
```

That is where they belong on the GameTank, whose fixed bank is 16 KB for
everything else.  What it asks of the block:

- only its own code uses them, or routines of the library that it hands
  them to (those are called with the overlay left in the window).  The
  library is what comes from the library directory (`txt`, `strings`,
  `compression`...), not a module of your own, whatever it is for.  A
  subroutine of the main program, or of another overlay, that is given such
  a string finds something else at that address;
- a block of your own that such data may be handed to says so with
  `%option overlay_safe` (in the block, or once for its module): it is then
  called like the library.  That is a promise that it never chooses a bank
  itself and needs nothing from the bank the main program had chosen: a
  decompressor, a copy routine, a text routine;
- they are not written to.  In a cartridge they cannot be; on the C64, the
  C128 and the MEGA65 what is written is gone when the overlay is brought
  in again.

Variables without values (and single variables with one) stay in main
memory as before, so the block can still keep state.

**The library is in main memory.**  `textio`, `diskio` and the rest are
there for every overlay, and are not counted against one.

**The address of a subroutine in an overlay** can be taken, kept and called
(`call(pointer)`) like any other.

## What to keep out of an overlay

- **Interrupt handlers.**  An interrupt comes whatever is in the window.
  The compiler refuses a subroutine in an overlay whose address is given to
  a routine or stored in a vector with `irq` or `nmi` in its name
  (`sys.set_irq`, `cbm.CINV`...); a handler installed another way it cannot
  see.  A handler in the main program must not call into an overlay
  either.
- **Code that works on banked data, on the X16.**  An overlay runs in the
  window at $a000, so it cannot look at another bank there.  The
  subroutines that read and write a program's own banks (the text of an
  editor, say) belong in the main program; overlays call them, and get what
  they need in variables or in a buffer in main memory, not as an address
  in the window.  The bank register stays the main program's own: the
  overlay's bank is in the window only while the overlay's code runs, and
  whatever the main program chose is chosen again whenever its code runs,
  also when an overlay calls it, and stays chosen from one such call to
  the next.  So a subroutine that maps a page of data and leaves it mapped
  works as it does without overlays.
- **An address in the window, on the X16 and the GameTank.**  What the
  main program hands out as an address in the window (a pointer into a
  mapped page) is of no use to code in an overlay: there it points into the
  overlay itself.  A subroutine that reads a file straight into such a
  page, or walks through one, stays in the main program.  (Handing such an
  address on to a subroutine outside the overlay works: that one runs with
  the main program's bank.)
- **Inner loops across two overlays.**  A call into another overlay costs
  more than a plain call (see below).  Put what calls each other often into
  the same overlay, or into the main program.
- **Assembly that jumps into another overlay by its label.**  The compiler
  writes the way into an overlay for calls in Prog8 code; a `jsr` in an
  `%asm` block goes where it says, and what is at that address depends on
  the overlay that is in.  There is a warning for a `jsr` or `jmp` to a
  subroutine in another overlay when its name is written in full
  (`p8b_block.p8s_name`).

### Variables in the window

`-varshigh`, `-varsgolden` and `-varsaddress` must not put the variables
where the overlays are brought in: the compiler refuses that.  On the C64
this means no `-varshigh` in a program with overlays, since its high memory
($c000-$cfdf) is the window.  The virtual registers at $cfe0 are above the
window and are left alone: an overlay that would reach them is an error of
the assembler ("overlay n is too large").

## What a call costs

Within an overlay: nothing more than any call.  From an overlay into the
main program or the library: the same on the C64, the C128 and the MEGA65;
on the X16 the bank changes hands on the way out and back, through a stub
in main memory of nine bytes for each subroutine that an overlay calls
(routines of the ROM are called as they are).

Into an overlay from outside it:

- on the X16, a dozen instructions that choose the bank, call, and put back
  the bank that was there: about twice a plain call.  In main memory each
  subroutine that is called from outside its overlay takes nine bytes, and
  each overlay 18 more once;
- on the GameTank the same (nine bytes in the fixed bank for each such
  subroutine, 18 for each bank that has any), but choosing a bank there is
  a subroutine of some fifty instructions (the bank's number goes out a bit
  at a time), and it runs twice for a call;
- on the C64, the C128 and the MEGA65, about twice a plain call when the
  overlay is in the window already, and a copy of the overlay's code (as
  many bytes as it has) when another one is.  After the call the caller's
  overlay is brought back if the caller was in one.

Measured, 20,000 calls of a subroutine that adds one to a byte, in jiffies:

| | plain call | into an overlay that is there | 4,000 calls, two overlays in turn |
|---|---|---|---|
| X16 | 8 | 17 | 4 |
| C64 with an REU | 76 | 150 | 72 |
| C128 with an REU | 77 | 156 | 74 |

## When it does not work

| What you see | What it means |
|---|---|
| `?cannot load the program's file` (X16) | the loader did not find `name.non` on drive 8 beside `name.prg` |
| `?cannot load the program's overlays` (C64, C128, MEGA65) | the same, at the first call into an overlay |
| `?overlays need a ram expansion unit` (C64, C128) | no REU answers |
| "overlay n is too large by ... bytes" when building | more code than the window holds |
| "a subroutine in an overlay cannot be an interrupt handler" when building | its address is given to something with `irq` or `nmi` in its name |
| "warning: assembly in ... names ..., which is in overlay n" when building | a `jsr` or `jmp` in assembly to a subroutine that is in another overlay |
| "warning: overlay n has nothing in it" when building | nothing in the program calls a subroutine of that overlay, so it has no code (the program is still built as one with overlays) |
| "Program too long" when building | the main program reaches the window; on the C64, C128 and MEGA65 it ends below it |

## Trying it in an emulator

The emulator has to find `name.non` as a file on drive 8.

```
cd build
x16emu -prg game.prg -run

x64sc -reu -reusize 512 -devicebackend8 1 -fs8 . +drive8truedrive -trapdevice8 game.prg

c1541 -format "game,p8" d81 game.d81 -write game.non game.non
xmega65 -8 game.d81 -prg game.prg
```

(`x128` takes the same options as `x64sc`.)

## What is not there yet

- An overlay larger than its window, and a window of another size than the
  target file gives.
- Library code in an overlay.
- A check that the REU is large enough for the number of overlays (the
  MEGA65 has room for sixteen, and a higher number is an error).
- Another drive than 8 on the X16 and the MEGA65.
- Overlays in an IR file (`-ir` does not write the directive).
