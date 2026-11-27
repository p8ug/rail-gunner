# p8p8

A [Prog8](https://prog8.readthedocs.io/) compiler written in Prog8.

p8p8 is an independent project.  It is not the reference compiler: the Prog8
language, its compiler `prog8c` and its standard library are by Irmen de Jong,
at <https://github.com/irmen/prog8>.  p8p8 compiles the same language, builds
programs with that standard library, and follows `prog8c` in its command
line where it can.

The command is `p8c`.

## What it does

- Reads Prog8 source, checks it, and writes the same intermediate
  representation (`.p8ir`) that the reference compiler writes.
- For 6502 and 65C02 machines it has a code generator of its own, which
  writes 64tass assembly and builds the program.  The Commodore 64, the
  Commodore 128, the Commander X16 and the PET come with it; any other 6502
  machine is described by a properties file in the format of the reference
  compiler's custom targets (see [docs/TARGETS.md](docs/TARGETS.md)), and
  the library has such files for a number of them (the MEGA65, the VIC-20,
  the Plus/4, the Foenix F256, the GameTank, the Apple II, the Atari 800XL
  and others).
- The same code generator writes for two more CPUs of that family, which
  the reference compiler has no code for: the 65816 (`-cpu 65816`, for a
  Commander X16 that has one or a C64 with a SuperCPU) and the 45GS02 of
  the MEGA65.
- For the 68000 there is a first code generator, for the `qemu68k` target
  (a bare 68020 in QEMU), the Amiga 1200 and the Amiga 500: it writes vasm
  assembly.
- For the Z80 there is a code generator too: `-target cpm`, `-target trs80`
  (the TRS-80 Model I and III) and `-target trs80m4` (the Model 4) build a
  CP/M program and TRS-80 command files with z88dk (its assembler; for a
  program with floats or calls of its C library, its `zcc`).  Files, the
  command line and the I/O ports are there; a clock and `asmsub` are not.
  The test programs print what they print on the host, in tnylpo and
  trs80gp, and an editor of 30 KB runs on the Model 4.
- For the 6809 there is a first code generator: `-target coco2` and
  `-target coco3` build a Color Computer program (a DECB file for `LOADM`
  and `EXEC`) with lwasm of lwtools, and `-target sim6809` one for a bare
  6809 in usim09batch.  Text goes straight into the screen's memory, the
  keys are the ROM's.  A pass over the assembly takes out what the
  generator's simple way leaves.  `asmsub` and `extsub` name the 6809's
  registers, `diskio` reads and writes Disk BASIC's files, and floats are
  those of the BASIC in the ROM (five bytes, its routines).  A command line
  is not there (the machine has none), and the Color Computer 3's 40 and 80 column screens are there
  (`txt.set_width`).
  The test programs print what they print on the host, in usim09batch and
  in XRoar; nothing was run on a real machine.
- For the 8086 there is a first code generator: `-target dos` builds an
  MS-DOS program, a `.COM` file (one segment of 64 KB for code, data and
  stack), with nasm.  It uses nothing that the 8086 and 8088 do not have.
  `textio` is the BIOS's text screen in its 16 colours (cursor, cells read
  and written, scrolling) and the BIOS's keyboard, arrow and function keys
  included; when the program's output or input is redirected, it goes
  through DOS.  A pass over the assembly takes out what the generator's simple way
  leaves.  `asmsub` and `extsub` name the 8086's registers, the
  command line is there, and `sys.inp` and `sys.outp` are the I/O ports.
  `diskio` is DOS's files and directories.  `-target dosexe` builds an
  `.EXE` file of the same program, with 64 KB for its code and another
  64 KB for its data and stack; no linker is needed.  Floats are IEEE
  doubles, with the 8087 where the machine has one and without it where
  not: the program finds out when it starts (`-floats hard` or `-floats
  soft` asks for one kind alone, as `floats` in a target file does).  The test programs print what they print on the host, in DOSBox-X as an
  8086 with and without an 8087, and the DOS tests print the same under
  MS-DOS 6.22 in QEMU; nothing was run on a real machine.
  The upper 32 KB of a 64 KB machine are memory for data (the `highram`
  module), or, with `-target coco2ram`, the program runs with the ROMs
  switched out and has that memory as its own, its calls into the ROM
  switching them in for the moment.  On the Color Computer 3 `highram` is
  the memory beyond its 64 KB: 384 KB of a 512 KB machine, 48 KB with 128 KB;
  `-target coco3ram` is `coco2ram` for that machine (memory blocks of the
  program's own where BASIC is, 32 KB, with most of its variables there).
  A program that is too long for the memory below has part of its code
  there too, and loads that itself from its file on the disk
  (`LOADM"NAME":EXEC`), so it can be about 56 KB.
  `-varshigh 0` does that with the variables on `coco2ram`.
  `-target dragon32` and `-target dragon64` are the Dragons, with the same
  screen and floats (the ROM's, at the Dragon's addresses) and no `diskio`.
- For the host it writes LLVM IR and builds a native executable with clang.
  That is how p8p8 compiles itself.

It is a cross compiler.  It runs on macOS, Linux and Windows.  A compiler
that runs on the 8-bit machines themselves is the long-term idea, not what
this is today.

## Status

Experimental.  It compiles itself to a fixed point, builds every example
program of the reference compiler for the C64 and the X16, and its output is
compared with the reference compiler's by the test suites below.  Real
programs have been built with it for the C64, C128, X16, PET, VIC-20, Plus/4,
MEGA65, Foenix F256 and GameTank.  It has had far less use than the reference
compiler, so expect to find bugs.

[docs/DIFFERENCES.md](docs/DIFFERENCES.md) lists where p8p8 differs from
`prog8c`.  [docs/DESIGN.md](docs/DESIGN.md) says how the compiler is put
together.

## Installing a release

The archives of a release hold `bin/p8c` and the library beside it.  Unpack
one anywhere (`~/.local`, for example) and put its `bin` in your `PATH`.
What else you need depends on what you build:

| To build | You need |
|---|---|
| programs for 6502 machines | [64tass](https://sourceforge.net/projects/tass64/) |
| programs for 68000 machines | [vasm](http://www.compilers.de/vasm.html) (`vasmm68k_mot`), and [vlink](http://www.compilers.de/vlink.html) for `-target qemu68k` |
| programs for the host (`-target llvm64`) | clang.  On Windows clang links with Microsoft's tools: install LLVM, and the Visual Studio Build Tools with a Windows SDK |
| and to run a 6502 program with `-emu` | [VICE](https://vice-emu.sourceforge.io/) or [x16emu](https://github.com/X16Community/x16-emulator) |

The Linux archive is for x86-64 with glibc 2.39 or newer, the macOS one for
Apple silicon, the Windows one for x86-64.  They have been tried on fresh
installations of Debian 13 and Windows 11.

## Building

p8p8 builds itself.  You need:

- clang 15 or newer
- make
- [64tass](https://sourceforge.net/projects/tass64/) to build 6502 programs

```
git clone --recurse-submodules <this repository>
make                 # builds build/llvm64/p8c
```

`seed/p8c.ll.gz` is the compiler's own earlier output, as LLVM IR.  clang
makes a first compiler of it, that one compiles the sources, and clang makes
`p8c` of the result.  `make bootstrap` checks that `p8c` then reproduces
itself.  The seed is the same file for macOS, Linux and Windows.

On Windows there is a script in place of `make`, which needs clang and
nothing else:

```
powershell -ExecutionPolicy Bypass -File tools\build-windows.ps1
```

It builds `build\llvm64\p8c.exe` from the same seed and checks that it
reproduces itself.

The library that programs are built with is a repository of its own, the
submodule at `lib/`: Prog8's standard library as it comes, and beside it the
machines and modules that are added and a few modules with bug fixes that
take the place of upstream's (see its README).  A `p8c` in
`build/` finds it there.

For the tests, and as a second way to build the compiler
(`make BOOT=prog8c`), you also need:

- Python 3, and `python3 setup.py` once: it fetches Prog8's examples,
  compiler tests and documentation into `.prog8-reference`, which the test
  suites use.  They are not part of this repository and are never committed.
- Java 17 or newer and `prog8c-llvm`, the LLVM branch of the Prog8 compiler
  (<https://github.com/gillham/prog8>, branch `llvm`), in your `PATH`: the
  comparison suites build every test program with it too.
- optional, for the suites that run programs:
  [x16emu](https://github.com/X16Community/x16-emulator) and
  [VICE](https://vice-emu.sourceforge.io/)

To install the compiler with the library it builds programs with:

```
make install PREFIX=~/.local
```

That puts `p8c` in `PREFIX/bin` and the library in `PREFIX/lib/p8p8`, where
`p8c` finds it by itself.

`make dist` (on Windows `tools\build-windows.ps1 -Dist`) makes an archive
with the same layout in `dist/`, to unpack anywhere: `bin/p8c` finds the
library beside it.

`make cross TRIPLE=<profile> SYSROOT=<dir>` makes such an archive for a
32-bit ARM or RISC-V Linux machine, built here.  The seed is for 64-bit
machines, so on a 32-bit one the first p8c comes from such an archive;
with it in the `PATH`, `make` in this repository builds the next one there
(`BOOT=p8c`, which is also there on a 64-bit machine: `make BOOT=p8c`,
with `P8C=<file>` for another one than the `PATH`'s).  See
[docs/DESIGN.md](docs/DESIGN.md), "A 32-bit host".

## Using it

```
p8c -target c64 -out build program.p8
p8c -target cx16 -srcdirs src:src/cx16 -out build src/main.p8
p8c -target plus4 -out build program.p8              # a machine of the library
p8c -target config/mine.properties -out build program.p8     # or a file of your own
p8c -target llvm64 -out build -run program.p8
p8c -target cx16 -ir -out build program.p8           # the IR, as build/program.p8ir
p8c -out build build/program.p8ir                    # and the program from that file
```

The directories of `-srcdirs` are separated by `:` or by `;`, on every
system (the reference compiler wants `:` on Unix and `;` on Windows).

`-lib` names the library directory.  Without it `p8c` uses `P8P8_LIB` from
the environment, or the library installed with it (`../lib/p8p8` from the
directory `p8c` is in; `lib/` of the repository for one in `build/`);
`p8c -libpath` prints which, and `p8c -version` the version of the compiler
and of that library.  Run `p8c` without arguments
for the list of options.

`p8c -h` (or `-help`) lists the options.  `-target llvm` is another name
for `-target llvm64`.

For a 6502 machine the program is built with p8p8's own code generator and
64tass.  `-codegen upstream` hands p8p8's IR to `prog8c-llvm` instead (for a
68000 machine too), and `-ir` only writes the IR.

`-target qemu68k` builds a 68000 program with p8p8's 68000 code generator;
that needs `vasmm68k_mot` and `vlink`, and `qemu-system-m68k` for `-run`.
`-target amiga1200` (or `amiga500`) writes an AmigaOS program file (vasm
alone); `-run` starts it in vamos, which only runs programs that use the
console (`P8P8_VAMOS` names it when it is not in the PATH).

Without an option that says what to do, `p8c` compiles, as `prog8c` does:
a program for a 6502 or 68000 machine, the LLVM IR (`.ll`) for an llvm
target, the IR for `-target virtual`.  `-build`, `-run` or `-o <file>` make
an llvm target's executable; `-check` only checks the program.

`-target mega65` writes code for the MEGA65's own CPU, the 45GS02: `long`
values are handled 32 bits at a time, and multiplication and division use
the machine's arithmetic unit, which makes programs smaller and a good deal
faster.  `-cpu 6502` gives plain 6502 code for that machine.  It is a first
version.

On the MEGA65, and on a C64 with a SuperCPU (`-target c64 -cpu 65816`), data
can be at an address of more than 16 bits: `&ubyte ATTIC = $8000000`,
`@($40000)`, `peek` and `poke` with such a number or with a long variable,
and `farmem.copy` and `farmem.fill` from the library.  That is p8p8's own
([docs/DIFFERENCES.md](docs/DIFFERENCES.md), "Far memory").

A program can have parts of its code outside main memory: a block with
`%overlay 1` is in bank 1 of a Commander X16's high memory, in the RAM
Expansion Unit of a C64 or C128, in a MEGA65's memory beyond 64 KB, or (with
the bank's number) in a bank of a GameTank cartridge.  `p8c` writes the
calls and two files that belong together, `name.prg` and `name.non`.  That
is p8p8's own; [docs/OVERLAYS.md](docs/OVERLAYS.md) is the guide.

`-cpu 65816` writes code for that CPU on any 6502 machine (`-target cx16
-cpu 65816`, for a Commander X16 that has one; `-target c64 -cpu 65816` for
a C64 with a SuperCPU).  This is new: word arithmetic on variables uses
the 16-bit accumulator, everything else is the 65C02's code.

A command line written for `prog8c` mostly works as it is: options may
stand before the source file or after it, and may be
written with two dashes, `-emu` is `-run`, and the options of `prog8c` that
only concern what it prints (`-plaintext`, `-quiet`, `-quietasm`,
`-nosourcelines`, `-timings`, `-warnimplicitcasts`, `-ircomments`) are
accepted and ignored.  `-o file` names the program as it
does there: its directory is where the output goes, and its name is that of
every output file; the program is then built, also for an llvm target.
An option that would change the program and that p8p8
does not have is an error, not ignored.

Warnings about things that are not wrong but may not be meant are asked
for, each kind by its own option:

| Option | Warns about |
|---|---|
| `-warnunused` | a variable, parameter or subroutine that nothing uses |
| `-warnunreachable` | statements after a `return`, `goto`, `break` or `continue` |
| `-warnshadow` | (as `prog8c` has it) the assembler's warnings about symbols that hide others |
| `-warnall` | all of these |

They look at the program's own modules only, and say nothing in a block or
module with `%option ignore_unused`, about a `@shared` variable, or about
the variables of a subroutine or block that has assembly in it.

`-traceimports` prints, as it does for `prog8c`, which file every imported
module comes from and what imported it.  With a library in parts it also says
which file a module takes the place of:

```
[import-trace] Importing module 'syslib' from lib/targets/c128/syslib.p8 (the target's own) - imported by '~implicit~' - in place of lib/prog8lib/c128/syslib.p8
```

p8p8 prints errors and warnings and nothing else.  `-verbose` also prints
the commands it runs and lets the assembler print its summary of the
program's sections and sizes.

Of the reference compiler's options, these take a value: `-address <address>`
(where the program is loaded, in place of `%address`), `-D <name>=<value>`
(a symbol for the assembler), `-breakinstr brk|stp` (that instruction at
every `%breakpoint`), and for programs of the llvm targets `-O <level>`,
`-clang <path>`, `-Xcompile <argument>` and `-Xlink <argument>`.  With
`-run`, what follows `--` goes to the program that is started.
[docs/DIFFERENCES.md](docs/DIFFERENCES.md) lists the ones that are missing.

Options p8p8 has that the reference compiler does not:

| Option | What it does |
|---|---|
| `-encoding <name>` | the encoding of string and character literals without a prefix, in place of the target's (`%encoding` in a module and a prefix still override it) |
| `-codegen own\|upstream` | which back end builds a 6502 program |
| `-cpu 6502\|65c02\|65816\|45gs02` | the CPU a 6502 machine's program is written for, in place of the target's |
| `-triple <name>` | the platform of an llvm32 program: a profile in the library's `triples/` (WebAssembly, 32-bit ARM and RISC-V Linux) |
| `-noopt` | the own code generator without its optimizations |
| `-asm` | write the assembly of p8p8's code generator (`name.asm`) and stop: no assembler or linker is run, and none needs to be installed.  For the 6502 family, the 68000, the Z80 and the 6809 |
| `-verbose` | print the commands that are run and the assembler's summary |
| `-noimage` | on a machine whose program file is the image of a whole cartridge (the GameTank: a 2 MB `.gtr`): write the program alone (a `.bin`) |
| `-nooverlays` | take no notice of `%overlay`: the program is built in one piece, as on a machine without overlays |
| `-overlayinfo` | after a 6502 program is built: every block (and the larger subroutines of the ones that stay) with its bytes and whether it could go into an overlay, or why not |
| `-meminfo` | after a 6502 program is built: what it takes of main memory and of each overlay, and what is left (`-verbose` prints this too) |
| `-floats auto\|hard\|soft` | on an 8086 machine (`dos`, `dosexe`): the float arithmetic with the 8087's instructions alone (`hard`), without them (`soft`), or both, with the program looking for an 8087 when it starts (`auto`, which the targets have without the option).  An error on another target.  p8p8's own |
| `-map` | after a program is built by one of p8p8's code generators (6502 family, Z80, 6809, 68000): its map, `name.p8map`, with the address and the bytes of every block, subroutine and variable.  `p8size` reads it (see below) |
| `-libpath` | print the library directory that is used |
| `-report <dir>` | write a report of this run into the new directory `<dir>` (see below); `-reportnosource` leaves the program's sources out of it |


## Where a program's bytes go: `p8size`

`p8c -map` writes a map beside the program, and `p8size` (`tools/p8size.py`,
a Python script; `make install` puts it beside `p8c` when there is a
`python3`) reports from it.  The map is the same for every CPU, so the
reports are too.

```
p8c -target cx16 -map main.p8
p8size main.p8map                    # the memory map, the blocks, the 25 largest subroutines
p8size main.p8map --block main       # only the subroutines of one block
p8size main.p8map --vars             # the largest variables
p8size main.p8map --modules          # per source file: what a library costs
p8size old.p8map new.p8map           # what changed between two builds
p8size main.p8map --map --min-free 128   # for a Makefile: exit 1 when less room is left
p8size main.p8map --json             # everything, for a script
```

A subroutine's bytes are its code and what follows it up to the next one
(tables, strings it alone uses); the block `(runtime)` has what belongs to no
block: the startup code, the code generator's own routines and, for a Z80
program that is linked with z88dk, that library's.  `p8size` also reads a
64tass listing (`-asmlist`, `name.list`), which the reference compiler
writes too; the names in it are less exact.  No map is written for a
program with overlays.

The map is a text file with a line for each thing; its format is in
[docs/DESIGN.md](docs/DESIGN.md), "The program's map".

## When something goes wrong

If p8c rejects a program it should accept, builds one that misbehaves, or
stops with "internal error", please report it:
<https://github.com/gillham/p8p8/issues> (the form there asks for what is
needed).  The smallest program that shows the problem is the best report.  When that is hard to make, run the same
command once more with `-report` and a directory that does not exist yet:

```
p8c -target cx16 game.p8 -report problem
```

The compiler runs as it would without the option, and writes into
`problem/` everything needed to repeat the run somewhere else:

| File | What |
|---|---|
| `report.txt` | the versions of p8c and of the library, the kind of machine, the command, how the run ended, and every file that was loaded |
| `output.txt` | what the run printed, with the commands it ran and where each module came from |
| `out/` | the files the run wrote: assembly, IR, the program |
| `src/` | the program's own source files |
| `tools.txt` | the versions of 64tass and clang |

**The directory contains your source code.**  Look through it before you
attach it; `-reportnosource` writes the same report without `src/` (the
assembly in `out/` is still made from your program).  Files a program pulls
in with `%asminclude` or `%asmbinary` are not copied.

When the compiler itself crashes, it says in which stage and at which file or
subroutine, and exits with status 70.

## Working on the compiler

Nothing in this section is needed to compile programs with p8c, and none of it
is in a release archive.

### Tests

`make test` and `make bootstrap` need only this repository and its library,
and are what CI runs.  The suites that compare with the reference compiler
need `prog8c-llvm` (from its commit 486bd411 on: two programs of
`tests/conformance` fail on the 6502 with an older one), and the emulator
suites need 64tass, x16emu and VICE as well.

| Target | What it checks |
|---|---|
| `make test` | unit tests and the dumps of the sample files in `tests/` |
| `make bootstrap` | p8p8 compiled by itself compiles itself to identical output |
| `make seedcheck` | the compiler built from the seed and the one built by `prog8c-llvm` write identical output |
| `make conformance` | the programs of `tests/conformance`, one for each area of the language, built by both compilers: same output in the VM and natively |
| `make vmcmp` | test programs run in the reference compiler's VM from p8p8's IR and from the reference compiler's: same output |
| `make nativecmp` | the same for native executables |
| `make wasihost` | p8c built as WebAssembly (llvm32) and run with wasmtime writes what the native p8c writes: its own source, and the 6502 assembly of the test programs |
| `make buildall` | every C64 and X16 example builds |
| `make emucmp`, `make emucmp64` | programs built by both compilers print the same in x16emu and in VICE |
| `make emucmp816`, `make emucmp64816` | the same with p8p8's 65816 code, in `x16emu -c816` and VICE's `xscpu64` |
| `make emucmp65` | programs for the MEGA65 print the same as 6502 code and as 45GS02 code, in xmega65 |
| `make farcheck` | memory beyond 64 KB on the X16's 65816, the SuperCPU and the MEGA65: the addressing modes by hand, the compiler's code and the library's |
| `make overlaycheck` | programs with overlays (`%overlay n`), with their loader, in x16emu |
| `make z80cmp`, `make z80ref` | programs built for CP/M print in tnylpo what they print on the host, and what `prog8c-llvm`'s CP/M build prints |
| `make ataricmp` | the Atari target: the programs built for it by the reference compiler and by `p8c`, both run in atari800 without a window, the text screens they leave compared; and the text screen's routines |
| `make a2cmp` | the Apple II target: the programs built for it by the reference compiler and by `p8c`, both run in bobbin, what they print compared; and the text screen's routines |
| `make trs80cmp`, `make trs80cmp3`, `make trs80cmp4` | the same programs on a TRS-80 Model I, III and 4 in trs80gp (`TRS80GP` names the emulator), against the host |
| `make z80sys`, `make trs80sys`, `make trs80dos`, `make trs80screen` | on the Z80 machines: the command line and files, the DOS still working after a program has ended, and the screen routines |
| `make doscmp`, `make dosexecmp` | programs built for MS-DOS as `.COM` and as `.EXE` files print in DOSBox-X (an emulated 8086, without a window) what they print on the host |
| `make dossoftcmp`, `make dosnofpucmp` | the same with the float routines that use no 8087, and the programs with floats on a machine without one |
| `make m6809cmp`, `make cococmp` | programs built for a bare 6809 print in usim09batch, and built for the Color Computer print in XRoar (without a window; `COCO_MACHINE=coco3` for its Color Computer 3), what they print on the host |
| `make coco3cmp`, `make coco3screen` | the `coco3` target on XRoar's Color Computer 3: the test programs on its 32 and its 80 column screen, and what a program leaves in the 80 column screen's memory |
| `make cocoramcmp` | the same programs for `coco2ram`: the program with the ROMs switched out |
| `make coco3ramcmp` | the same programs for `coco3ram`, on the 80 column screen |
| `make dragoncmp` | the same programs for the `dragon32` target on XRoar's Dragon 32 and Dragon 64 |
| `make cocosys` | files on the Color Computer, in XRoar with a disk image that toolshed's `decb` makes and reads back |
| `make mapcheck` | the maps of `-map` for every CPU: `p8size --check` says of each whether its entries fill the program to the byte |
| `make z80bench` | the time and size of a benchmark for CP/M, against `prog8c-llvm`'s build |
| `make irroundtrip` | a program built from the IR file that `p8c -ir` wrote is the same bytes as from its source |
| `tools/benchmega65.sh` | loops of long, word and byte arithmetic on the MEGA65 as 6502 code and as 45GS02 code |
| `make qemucmpir` | the same programs built from p8p8's IR by `prog8c-llvm`'s 68000 back end (`-codegen upstream`) |
| `make qemucmp`, `make amigacmp`, `make amigacmp500` | programs built for qemu68k, the Amiga 1200 and the Amiga 500 by both compilers print the same in QEMU and in vamos |
| `tools/bench68k.sh` | how long small benchmarks take on an Amiga 500 in Copperline, from both compilers |
| `tools/bench65.sh` | the same benchmarks on a Commander X16 (`x16emu -c816`), from the reference compiler and from p8p8 for the 65C02 and the 65816 |
| `tools/benchx16.sh` | upstream's benchmark program (ten workloads) on a Commander X16, built by the reference compiler and by p8p8 for the 65C02 and the 65816 |
| `tools/kttests.py` | the Prog8 programs inside upstream's Kotlin unit tests (`PROG8_SRC` names the checkout), compiled by the reference compiler and by p8p8: where one accepts what the other rejects |
| `tools/benchp8vi.sh` | the same for one command of a real program, the editor [p8vi](https://github.com/retrodores/p8vi), which it clones; needs a Kickstart 1.3 ROM (`COPPERCMP_ROM`) |
| `make coppercmp`, `make amigacmpfloat` | upstream's Amiga examples show the same screen from both compilers in the Copperline emulator; the float program prints the same on an Amiga 1200 with an FPU |
| `make gfxcmp` | programs built by both compilers draw the same in x16emu |
| `make programs`, `make roundtrip`, `make corpus` | the front end over the whole reference material |
| `make upstreamcheck` | not a test: what changed in Prog8 since the commit p8p8 follows, sorted by what it means here ([docs/UPSTREAM.md](docs/UPSTREAM.md)) |

Set `EMUCMP_CODEGEN=own`, `GFXCMP_CODEGEN=own` or `BUILDALL_CODEGEN=own` to
run those suites with p8p8's own 6502 code generator.

### Layout

| Path | What is there |
|---|---|
| `src/` | the compiler |
| `lib/` | the library programs are built with (a submodule) |
| `seed/` | the compiler's own earlier output, which it is built from |
| `runtime/` | support code that some programs are built with |
| `tests/` | test programs, scripts and expected output |
| `docs/` | the differences from `prog8c`, the guide to overlays, the design, a tour of the internals, and the description of target files and the library |
| `tools/` | helper scripts for the tests |

## Licence and credits

Prog8 is the work of Irmen de Jong and is licensed under the GPLv3.  p8p8
builds programs with Prog8's standard library and was written with its
documentation and sources as the reference.  The startup code in
the library's `target.properties` files for the C64, C128, X16 and PET is
taken from the Prog8 compiler's sources.

The LLVM support files in `runtime/` (`mos-c64-support.c`,
`windows-console.c`, `hosted-keys.c` and the helper functions in the `.ll` files) come from
the LLVM branch of Prog8 that p8p8 is built with, which is by the author of
p8p8 and not part of Prog8 itself.

p8p8 is licensed under the GPLv3 too; see [LICENSE](LICENSE).  As with Prog8
itself, the files the compiler generates (intermediate files and the programs
it builds) are excluded: you can do with those whatever you want.
