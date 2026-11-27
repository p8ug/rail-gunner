# Target machines

A 6502 machine is described to p8p8 by a text file, in the format of the
upstream compiler's custom targets (a Java properties file).  Nothing about
the Commodore 64, the Commander X16 or any other machine is built into the
compiler: its memory map, zero page and startup code come from such a file,
and changing them is editing it.

```
p8c -target c64 ...                             a name
p8c -target config/mega65.properties ...        a file
```

A name is looked for as

1. `<lib>/<name>/target.properties`
2. `<lib>/targets/<name>/target.properties`
3. `<lib>/targets/<name>.properties`

where `<lib>` is the library directory (see "Where the library is").  The
machines that the upstream compiler has built in (c64, c128, cx16 and pet32)
are files of the library too, with the values of its built-in targets; a
library without them, such as a plain copy of upstream's `prog8lib`, has no
6502 machine for p8p8.

The llvm targets, `virtual` and the 68000 targets are not machines of this
kind and have no file.

## A library in parts

When the `-lib` directory has a `prog8lib` directory in it, it is a library
laid out in parts: `prog8lib/` with upstream's standard library as it comes,
`common/` with shared modules that are added or changed, and
`targets/<name>/` with each machine's `target.properties` and the modules
that are its own (also for a target without a configuration file, such as
llvm64).  A module is then looked for in the `-srcdirs` directories, in
`targets/<name>/`, in `prog8lib/<name>/`, in `common/` and in `prog8lib/`,
in that order, so what is added lies over the standard library without
changing it.  `library:` files of `%asminclude` and `%asmbinary` are found
the same way.

A `library` value that starts with `../` is beside the configuration file's
directory (`library = ../vic20` for a variant that shares another machine's
modules); any other path is from where the compiler runs, as upstream has
it.  The assembler is given the configuration file's directory as an include
directory, for the files its startup code includes.

## Where the library is

1. the directory `-lib` names
2. `P8P8_LIB` in the environment
3. `../lib/p8p8` from the directory the compiler is in (an installed compiler:
   `bin/p8c` and `lib/p8p8`; `make install` puts them there)
4. `../../lib` from there (a compiler in its repository: `build/<host>/p8c`)
5. `.prog8-reference/compiler/res/prog8lib` in the current directory

The compiler's own place is found in `PATH` when it was started by name, and
symbolic links to it are followed.  `p8c -libpath` prints the library
directory that is used.

## The file

`key = value` lines; `#` and `;` start a comment line; a value goes on in
the next line after a backslash at the end; `\n` in a value is a new line.
Numbers are decimal, `$hex`, `0xhex` or `%binary`.  A list of addresses is
`$02-$06,$0a,$9b` (ranges include both ends).

### Keys of the upstream format

| Key | Meaning |
|-----|---------|
| `cpu` | `6502`, `65c02`, `65816` or `45gs02` (the MEGA65; `-cpu` on the command line chooses another) |
| `native65816` | `rest`: with a 65816 the program runs in native mode from start to end, because the machine's ROM allows it.  Without the key it stays in emulation mode, and the 16-bit runs of the code switch to native mode and back |
| `encoding` | the default text encoding: `petscii`, `iso`, `atascii`, ... |
| `output_type` | `PRG`, `RAW`, `XEX` or `LIBRARY`: the default of `%output`, and what the assembler is asked to write |
| `launcher` | `BASIC` or `NONE`: the default of `%launcher` |
| `load_address` | the default of `%address` |
| `memtop` | the default of `%memtop`: the program must end below it |
| `zp_scratch_b1`, `zp_scratch_reg`, `zp_scratch_w1`, `zp_scratch_w2`, `zp_scratch_ptr` | the zero page cells the library's assembly code uses (`P8ZP_SCRATCH_...`); `zp_scratch_reg` is `zp_scratch_b1` + 1 |
| `zp_fullsafe`, `zp_kernalsafe`, `zp_basicsafe` | the free zero page locations for `%zeropage full`, `kernalsafe` and `basicsafe` |
| `virtual_registers` | where the library has the 32 bytes of R0-R15; when that is in the zero page they are not given to variables |
| `overlay_window_start`, `overlay_window_end` | (optional) where an overlay's code is while it runs (the end is the first address after it); with `overlay_thunk` this gives the machine overlays (`%overlay n`) |
| `overlay_thunk` | the code a call into an overlay goes through, in main memory: `%t` is the subroutine, `%n` the overlay's number; it has to keep A, X, Y and the flags both ways |
| `overlay_in`, `overlay_in_full` | (optional) routines written once for each overlay (`p8_overlay_in_N`, `p8_overlay_inp_N`), for thunks that call them first and so stay short |
| `overlay_thunk_fast` | (optional) the thunk for an ordinary subroutine, which only has to keep A, X and Y |
| `overlay_max` | (optional) the highest overlay number the machine has room for |
| `overlay_thunk_cross`, `overlay_thunk_cross_fast` | (optional) the thunks for a call from one overlay into another, where that differs from a call out of the main program |
| `overlay_return`, `overlay_return_fast` | (optional) for a machine where the window is also the program's for its data: the whole stub, in main memory, that a call out of overlay `%n` to `%t` goes through |
| `overlay_back`, `overlay_back_full` | (optional) routines written once for each overlay (`p8_overlay_back_N`, `p8_overlay_backp_N`), for the stubs to end in |
| `overlay_select` | the address where one byte chooses the overlay that the next record of the program's file is loaded into |
| `overlay_loader` | (optional) an assembly file beside the target file: the loader of a program with overlays, assembled as `name.prg` with `p8_entry` and the macro `p8_file` defined; `name.non` then has the main program in it too.  Without it `name.prg` is the main program and `name.non` has the overlays only |
| `image_size`, `image_ext` | (optional) for a machine whose program file is the image of a whole cartridge: p8c writes one file of that size, filled with `$ff`, with the program at its end (the extension, `.bin` unless given).  A program with overlays has its banks in the same file.  `-noimage` gives the program alone.  (`overlay_image_size` and `overlay_image_ext` are read as well: the keys' earlier names.) |
| `fixed_blocks_apart` | (optional) `true`: a block at an address (`name $fdfe { ... }`) is placed there out of line, and what comes after it in the program goes on where the program was (without it, as with `prog8c`, the rest of the program follows the block).  The assembler refuses a block that lies where the program is.  `sys.progend()` is then the end of the program without such blocks, so this is for a machine whose program is ROM. |
| `overlay_image_first` | (optional) for overlays that are banks of a cartridge: the number of the bank at the start of the image |
| `overlay_store` | (optional) where the overlays are kept, for a support file that wants to know (the MEGA65: an address beyond 64 KB) |
| `overlay_support` | (optional) an assembly file that is included in a program with overlays (what the thunk calls), after `p8_overlay_window`, `p8_overlay_size`, `p8_overlay_select`, `p8_overlay_store`, the table `p8_overlay_sizes` (a word for each overlay: the bytes of its code) and the macro `p8_overlay_file` |
| `far_address_bits` | (optional) how many bits an address of data can have on a machine with memory beyond 64 KB (24, 28); a long is such an address when the program's CPU is the 65816 or the 45GS02 |
| `virtual_registers_zp` | (optional) the zero page address R0-R15 are moved to when the program has the zero page to itself (`%zeropage kernalsafe` or `full`) |
| `bss_goldenram_start`, `bss_goldenram_end` | the memory `-varsgolden` puts the variables without an initial value in |
| `bss_highram_start`, `bss_highram_end` | the same for `-varshigh N` (N: the RAM bank, for the library's startup code) |
| `vars_golden` | (optional) `true`: for a machine whose program is ROM.  The variables go to the golden ram (`bss_goldenram_start`, `bss_goldenram_end`) when no option (`-varsgolden`, `-varshigh`, `-varsaddress`) and no `%varsaddress` says where, and a variable with an initial value is with them wherever they go and gets its value from code at the start (an array or string with values stays in the program).  A program with `%option romable` then needs no option either. |
| `vars_address` | where those variables go when no option says so (`-varsaddress` on the command line) |
| `library` | the directory of the machine's own library modules (syslib and so on).  Without it: `<lib>/<name>`.  The modules all machines share come from `-lib` |
| `custom_launcher_code` | when not empty: the whole launcher and startup code, written after the `* = address` line as it is, instead of what p8p8 writes.  The text is the same for every program, so p8p8 defines the assembler symbol `prog8_zeropage_safe` before it (an extension): 1 when the program leaves the zero page as BASIC needs it (`%zeropage basicsafe` or `dontuse`), 0 when the machine has to be reset at the end, as the compiler's own startup code does it |
| `assembler_options` | more options for 64tass, before `--output` |

Read by the upstream compiler and not used by p8p8 yet: `io_regions`,
`supports_banked_calls`, `pointer_size`.

### Keys of p8p8's own

These express what the upstream compiler has in its code for its built-in
targets.  The upstream compiler ignores keys it does not know, so one file
serves both.

| Key | Meaning |
|-----|---------|
| `zp_floatsafe` | the free zero page locations for `%zeropage floatsafe` (without it: the basicsafe list) |
| `asm_symbols` | lines for the assembler before the program: symbols the library expects |
| `asm_symbols_floats` | used in place of `asm_symbols` in a program that uses floats |
| `startup_code` | the first instructions of the program, before the stack pointer is saved |
| `startup_code_floats` | instructions before the call of `main.start`, in a program that uses floats |
| `exit_code` | lines after the startup code: routines the library jumps to at the end |
| `reset_address` | what is pushed as the return address of the program when the zero page is not kept (default `sys.reset_system`) |
| `jsrfar_routine` | the routine for a call into another bank (default `<name>.x16jsrfar`) |
| `asm_end` | lines for the assembler after the whole program (`atari`: one more part of the `.xex`, which puts the program's start in `RUNAD`, where DOS starts what it has loaded) |
| `run_command` | what `-run` runs, with `{file}` for the program (`appleii`: bobbin; `atari`: atari800).  Without it `-run` knows the C64 (`x64sc`) and the Commander X16 (`x16emu`) |

### A target file made from another

`base = file` (beside this one, or a whole path) names a target file whose
keys this one has as well: what a file says itself comes first.  A path in
a key of the base is still read from where the file that names it is, so a
file elsewhere states `library` (and `float_source`) itself.  The tests'
trs80gp variants are made this way.

### A Z80 machine

`cpu = z80` makes the target a Z80 machine: p8p8's Z80 code generator
writes the program (assembly for z88dk's z80asm), and none of the 6502 keys
above apply.  `cpm`, `trs80` and `trs80m4` are such targets.  The routines are lines of
assembly that end by returning; a line that ends with a colon is a label.
`tests/z80/trs80gp.properties` is a target file of one's own made from
`trs80`: its console also prints, and its end stops the emulator, which is
how the tests see what a program does in trs80gp.  The keys it reads:

| Key | Meaning |
|-----|---------|
| `load_address` | where the program begins (`$0100` for CP/M) |
| `output_extension` | of the program file (`.com`, `.cmd`) |
| `output_format` | `cmd`: a TRS-80 command file (load records and a start address), which p8c makes of the assembler's plain image; without it the plain image |
| `startup_code` | the first instructions, when the machine needs any: where the stack is (`\n` between lines) |
| `stack_size` | the program gets a stack of its own of this many bytes (the TRS-80, whose DOS calls a program on a small stack) |
| `exit_code` | how the program ends; `sys.exit` comes here too |
| `exit_hook` | lines before the end, whichever it is (the tests' trs80gp variant stops the emulator there) |
| `console_out` | a routine: the character in A to the console |
| `key_poll` | a routine: A = a key, or 0 when none is waiting |
| `char_in` | a routine: A = a character that is waited for and shown |
| `console_tap` | lines that see every character first, with it in A (the tests' trs80gp variants send it to the printer) |
| `machine_cells` | lines that are always part of the program: places that the machine's routines and its library share |
| `wait_jiffy` | a routine that takes a 60th of a second, for `sys.wait` (without it there is no wait) |
| `ticks` | a routine: HL = the clock in 60ths of a second (without it `sys.ticks()` is 0) |
| `command_line` | a routine: HL = the command line, a text that ends with 0 (without it there are no arguments).  With it the program has a word `p8_entry_hl`, for what the first instructions are given, and 82 bytes at `p8_line` to copy a line to |
| `run_command` | what `-run` runs, with `{file}` for the program (p8p8) |
| `zcc_platform` | z88dk's platform for a program with floats, which `zcc` links (`+cpm`) |
| `library` | for a Z80 machine the target's own directory is searched before it: `trs80` has its own `textio.p8` and takes the rest from `../z80` |
| `zcc_init` | lines for the start of zcc's own first instructions (the TRS-80: an empty command line, since zcc's code writes into the one it is given) |
| `float_source` | a C file that is linked with such a program, from the target's directory (`../z80/z80-float.c`: the one the Z80 machines share) |
| `library` | the directory with the target's modules, as for any target |
| `library_platform` | a subdirectory of `library` that is searched before it (p8p8) |

### An 8086 machine

`cpu = 8086` makes the target an 8086 machine: p8p8's 8086 code generator
writes the program (assembly for nasm, which makes a flat file of it).
`dos` (an MS-DOS `.COM` program) and `dosexe` (an `.EXE` program) are such targets.  The routines are lines of
assembly that end by returning; a line that ends with a colon is a label.
A routine may change every register but the segment registers and SP.  The
keys it reads:

| Key | Meaning |
|-----|---------|
| `load_address` | where the program begins (`$0100` for a `.COM` file) |
| `output_extension` | of the program file (`.com`, `.exe`) |
| `output_format` | `exe`: an `.EXE` file, with the code in a segment of its own and the data and the stack in another; without it the program is one piece from the load address on |
| `startup_code` | the first instructions, when the machine needs any |
| `memory_end` | the first address that is not the program's: the assembler stops with an error when the program and its variables do not end before it (the stack is above) |
| `exit_code` | how the program ends; `sys.exit` comes here too, with the status in AL |
| `exit_hook` | lines before the end |
| `console_out` | a routine: the character in AL to the console |
| `key_poll` | a routine: AL = a key, or 0 when none is waiting |
| `char_in` | a routine: AL = a character that is waited for |
| `machine_cells` | lines that are always part of the program's data |
| `end_code` | lines after the variables with values |
| `wait_jiffy` | a routine that takes a 60th of a second, for `sys.wait` (without it there is no wait) |
| `ticks` | a routine: AX = the clock in 60ths of a second (without it `sys.ticks()` is 0) |
| `arguments` | the routines `p8rt_argc` (AX = the number of arguments) and `p8rt_argv` (AX = the argument whose number is in AX); without it there is one argument, which is empty |
| `arguments_data` | the data of those routines |
| `floats` | how the float routines are written: `8087` or `hard` (with its instructions alone), `software` or `soft` (without them), or `auto`, the default: both, and the program uses the 8087 when it finds one at its start.  `-floats` on the command line comes before it |
| `run_command` | what `-run` runs, with `{file}` for the program |
| `library` | the directory with the target's modules, as for any target |

### A 6809 machine

`cpu = 6809` makes the target a 6809 machine: p8p8's 6809 code generator
writes the program (assembly for lwasm of lwtools).  `coco2`, `coco3`,
`coco2ram`, `coco3ram`, `dragon32`, `dragon64` and `sim6809` are such targets.  The routines are lines of assembly that end by
returning, as for a Z80 machine; a line that ends with a colon is a label.
`tests/m6809/xroar-coco2.properties` is a target file made from `coco2`
(`base`): its program ends at a fixed address, where XRoar is told to stop,
and keeps what it prints in memory, which is how the tests see what a
program does in XRoar.  The keys it reads:

| Key | Meaning |
|-----|---------|
| `load_address` | where the program begins (`$0e00` for the Color Computer) |
| `output_extension` | of the program file (`.bin`, `.hex`) |
| `output_format` | lwasm's format: `decb` (a file for `LOADM`, the default), `dragon` (a DragonDOS binary), `ihex`, `srec`, `raw` |
| `startup_code` | the first instructions, when the machine needs any |
| `stack_size` | the program gets a stack of its own of this many bytes; without it the stack is the one it was called on |
| `memory_end` | the first address that is not the program's: the assembler stops with an error when the program and its variables (and that stack) do not end before it. A program that `%address` or `-address` put above it is not checked |
| `exit_code` | how the program ends; `sys.exit` comes here too, with the status in B.  The stack pointer is what it was at the start, so `rts` goes back to who called the program |
| `exit_hook` | lines before the end |
| `console_out` | a routine: the character in A to the console |
| `key_poll` | a routine: A = a key, or 0 when none is waiting |
| `char_in` | a routine: A = a character that is waited for (not shown) |
| `console_tap` | lines that see every character first, with it in A |
| `machine_cells` | lines that are always part of the program |
| `wait_jiffy` | a routine that takes a 60th of a second, for `sys.wait` (without it there is no wait) |
| `ticks` | a routine: D = the clock in 60ths of a second (without it `sys.ticks()` is 0) |
| `tail_code` | lines after everything else (the simulator's reset vector) |
| `rom_out`, `rom_in`, `rom_start` | a machine whose program runs with the ROMs switched out (`coco2ram`): the lines that switch them out and in, and the address from which a call is one into the ROM (default `$8000`).  The generator switches them out after `startup_code`, in before `exit_code`, and around every call into the ROM.  The lines must keep the registers (`coco3ram`, where they change the memory blocks, saves A) |
| `upper_variables`, `upper_variables_end`, `lower_blocks` | on such a machine: variables in the memory that the program has in place of the ROMs, from the first address up to (not including) the second.  The variables without values go there, and the generator's own places for values, but no floats, structs or slabs, and not the variables of the blocks that `lower_blocks` names (with commas): what a routine of the ROM is given the address of must stay below.  `sys.upperstart()` is the first address after them (`coco3ram`) |
| `high_code_end`, `high_loader` | on such a machine: code in that memory too, for a program that is too long for the memory below (`coco3ram`).  p8c assembles the program once to measure it, and when it does not end before `memory_end`, the code of some of its blocks (not those of `lower_blocks`) is put after the variables there, up to (not including) `high_code_end`.  The records of the program's file for that memory are moved behind the record that ends the file (a length, an address and the bytes of each, and a length of 0 last), and `high_loader`, lines of assembly, is put before `startup_code` (or where `startup_code` has the line `;high_loader`) to read them into the memory.  Only for a DECB file |
| `bss_highram_start`, `bss_highram_end` | on such a machine: the same memory for the same variables, from the first address to the last, when the program is built with `-varshigh N` and only then (`coco2ram`; N means nothing here) |
| `float_accumulator`, `float_load`, `float_store`, `float_add`, `float_sub`, `float_mul`, `float_div`, `float_compare`, `float_from_word`, `float_normalize`, `float_to_long`, `float_floor`, `float_half`, `float_unpack`, `float_power`, `float_sqrt`, `float_sin`, `float_cos`, `float_tan`, `float_atan`, `float_ln` | floats are those of a Microsoft BASIC in the machine's ROM: where its accumulator is, and its routines (the comments in `coco2/target.properties` say which each is).  Without them the machine has no floats |
| `run_command` | what `-run` runs, with `{file}` for the program |
| `library` | the directory with the modules; the target's own directory is searched before it |

## What the zero page lists do

Scalar variables go to the free zero page locations: those with `@zp` or
`@requirezp` first, then the others, the most used first; what is left
goes to the temporary cells of the generated code.  The scratch cells and
`%zpreserved` ranges are taken out, `%zpallowed` restricts the rest.  With
`%zeropage dontuse` nothing is placed there.

## Platforms of llvm32: triple profiles

`-target llvm32` is for 32-bit platforms through LLVM, and which one is a
*triple profile*: a properties file in the format of the LLVM branch of Prog8
(its `llvm-triples` directory), in the library's `triples/` directory.

```
p8c -target llvm32 program.p8                                    # wasm32-wasip1 (on a 32-bit machine: that machine)
p8c -target llvm32 -triple armv7-unknown-linux-gnueabihf program.p8
p8c -target llvm32 -triple config/mine.properties program.p8     # a file of your own
```

| Profile | Platform |
|---|---|
| `wasm32-wasip1` | WebAssembly with WASI, run by wasmtime; the default |
| `armv7-unknown-linux-gnueabihf` | 32-bit ARM Linux |
| `riscv32-unknown-linux-gnu` | 32-bit RISC-V Linux |

The keys p8p8 reads:

| Key | Meaning |
|---|---|
| `triple`, `datalayout` | what the LLVM IR says it is for |
| `c_long_size` | has to be 4 |
| `dirent_name_offset`, `readdir_symbol` | where `readdir()` has a file's name, and its C name |
| `clang_args` | arguments for clang; `${VAR:-default}` is the shell's |
| `link_args` | arguments after the files (`-lm`) |
| `getkey_source` | the console runtime to build along when the program reads keys or asks for the terminal's size |
| `output_extension` | of the program file |
| `run_command` | what `-run` runs, with `{file}` for the program; without it the program itself |
| `strict_indirect_signatures` | calls through a pointer name the exact type (WebAssembly) |
| `c_main_symbol` | the name the C library calls `main` by |

A profile with any other key is refused, so that nothing it asks for is
left out silently: the bare-metal, Z80 and 6809 profiles of the LLVM branch
are not usable yet.  `-Xcompile <argument>` gives clang one more argument
(a sysroot), and can be repeated.  clang is `clang` in the `PATH`, or `P8P8_CLANG`; for
WebAssembly it is Homebrew's (`P8P8_WASM_CLANG`), because Apple's clang has
none.  Building for another machine than the one p8c runs on needs that
platform's sysroot in `clang_args`; `-llvm` writes the LLVM IR to build
there instead.

llvm64 and llvm16 do not read profiles yet: `-triple` takes one of the names
built into p8p8 for them.
