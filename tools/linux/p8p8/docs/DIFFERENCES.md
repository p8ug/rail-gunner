# Differences from prog8c

p8p8 compiles the Prog8 language as the reference compiler, `prog8c`, defines
it, and tries to behave the same.  This is the list of where it does not, or
not yet.  It is meant to be complete about the kinds of difference and honest
about how much has been checked; where a statement rests on a test, the test
is named.

"Upstream" below is `prog8c` and its standard library, by Irmen de Jong
(<https://github.com/irmen/prog8>).  p8p8 is compared against its LLVM
branch (<https://github.com/gillham/prog8>), which is a fork of upstream's
compiler with LLVM targets added.

## What is the same

- **The language.**  The parser takes upstream's whole grammar.  Every file
  of upstream's standard library, examples and the two directories of
  compiler test programs loads and checks (`make programs`, `make corpus`).
- **The standard library.**  p8p8 has no library of its own: programs are
  built with upstream's.  Its files are not edited; a few modules are
  replaced by copies with bug fixes or changes for the added targets, which
  the library repository lists.
- **The intermediate representation.**  p8p8 writes upstream's `.p8ir`
  format.  Its IR runs in upstream's virtual machine and builds with
  upstream's IR back ends.  An IR file is accepted as input, as upstream
  does; that works for the IR p8p8 writes, and for little of what upstream
  writes (it uses instructions p8p8's back ends do not have).
- **The conventions of 6502 programs:** symbol prefixes, how arguments reach
  `asmsub`s, split word arrays, the layout that library assembly expects,
  64tass as the assembler.
- **What programs do.**  Test programs built by both compilers print the same
  in the virtual machine, as native executables, and in emulators of the
  Commander X16 and Commodore 64, and programs that draw end on the same
  picture (`make vmcmp`, `nativecmp`, `emucmp`, `emucmp64`, `gfxcmp`).  All
  of upstream's C64 and X16 examples build (`make buildall`).
- **The language, feature by feature.**  `tests/conformance/` goes through
  the language one area in each program (arithmetic, comparisons, control
  flow, assignments, subroutines, arrays and strings, pointers and structs,
  builtin functions, variables and scopes, floating point, the string and
  conversion modules), with values the compiler cannot know in advance.
  Each prints the same from both compilers in the virtual machine and
  natively, and on the two emulated machines except for one program that
  is skipped there: the remainder of signed numbers, which upstream does
  not have for the 6502.  The set is not complete: it has what one pass
  through the language thought of.

## Targets

| | upstream | p8p8 |
|---|---|---|
| 6502 and 65C02 machines | built in: c64, c128, cx16, pet32; others as custom targets | every machine is a target file, the four built-in ones included; a code generator of p8p8's own |
| `%option romable` | checks that the variables are moved to RAM; warns about some constructs | the same check, and the assembler refuses any instruction that writes into the program, the library's included (upstream builds a ROM that calls `math.rnd()`, which changes its own code; p8p8 does not) |
| `@requirezp` on an array or string with initial values | placed in the zero page | an error: the 6502 code generator does not copy values into the zero page at the start (without values, and for every other kind of variable, the tags work as upstream's) |
| 65816 | no | `-cpu 65816`: the 65C02's code, with runs of word arithmetic in the 16-bit accumulator |
| 45GS02 | no | no (planned) |
| 68000 (Amiga and others) | yes | a first code generator of p8p8's own, for qemu68k and the two Amigas, new and with little optimization |
| the virtual machine | yes, with the machine itself | p8p8 writes the IR for it and has no virtual machine: upstream's runs it |
| the host, through LLVM | in the fork's LLVM branch | yes; it is how p8p8 compiles itself |

On a 65C02 p8p8 uses only instructions that a 65816 in emulation mode has
as well (no `bbr`, `bbs`, `rmb`, `smb`), as upstream does.

## The code that is generated

- **Where R0-R15 are in the C64's and C128's zero page.**  Both compilers
  move the virtual registers into the zero page with `%zeropage kernalsafe`
  and `full`.  Upstream puts them at `$04` (C64) and `$0a` (C128), where
  they share two bytes with the scratch pointer its own code uses; p8p8
  puts them at `$06` and `$0d`.  Code that names them (`cx16.r0`) does not
  see the difference.
- **A defer inside a defer** is an error.  Upstream accepts it and never
  runs the inner one.

- **A different code generator.**  For the 6502, p8p8 does not use upstream's
  code generator or its output.  It translates the IR one instruction at a
  time and improves the result with its own passes ([DESIGN.md](DESIGN.md)).
  The assembly looks different, has no source lines as comments, and
  variables and temporaries are at other addresses, also in the zero page.
- **No optimizer in the front end.**  Upstream optimizes the program before
  generating code: constant propagation, inlining of small subroutines,
  removal of dead stores and of unreachable code, and more.  p8p8 folds
  constants, removes subroutines and variables that nothing refers to, and
  leaves the rest to its 6502 passes and to LLVM.  Two visible consequences:
  - `inline` on a subroutine is not acted on, except for an `asmsub` whose
    body is put in place of the call as upstream does;
  - upstream sometimes accepts a program because its optimizer changed it
    first (a variable that is never written becomes a constant and may then
    stand where a constant is required).  p8p8 does this for the places
    where it matters, an array initializer and a `when` choice
    (`tests/programs/neverwritten.p8`), not everywhere.
- **Size and speed** are measured on whole programs and are close to
  upstream's default code generator, a little smaller on some programs and a
  little larger on others.  They are not the same and are not meant to be.
- **Floating point on the 6502** goes through the ROM routines, as upstream's
  does.  Some forms of float arithmetic are not implemented in p8p8's
  generator and are reported as an error when a program uses them.
- **The remainder of signed numbers** is not there for the 6502 in either
  compiler.  Upstream says so when it checks the program; p8p8's message
  comes from its code generator and names the instruction.

## Checking and messages

- **Errors.**  p8p8 reports the errors of upstream's that have been ported,
  with upstream's wording.  `tools/checkprobe.py` compares the two compilers
  on 195 small invalid programs: they agree on 180 (against the LLVM
  branch at 62101daa8).  In 9 of the others p8p8 rejects a program that
  upstream lets through, because its optimizer removed the code first
  (it rejects them too once the values are used).  In 6 upstream stops and
  p8p8 does not: two of those are internal errors of upstream (an `inline`
  subroutine that calls itself, `repeat` with a string as its count), two
  are errors of its constant folding that it does not give for the same
  operation on variables (`~` of a boolean constant, `&` of a float
  constant), and two are in the list below.  Known programs that
  upstream rejects and p8p8 accepts:
  - an `if` expression whose two values have types that cannot be assigned;
  - `unroll` with a count that is not constant;
  - `p^^ = array[i]` and `array[i] = p^^` for structs, where upstream asks
    for `&`;
  - a `long` parameter in one register (`long v @R0`), where upstream wants
    a pair (`@R0R1`);
  - a `for` loop over a `long` range with a step that is a variable, which
    the LLVM branch refuses for the 6502;
  - `w * w` of a signed `word` passed where a `word` is wanted: upstream
    makes it a square, whose type is `uword`, and then reports a type
    mismatch;
  - a `str` assigned to a `long` on a 6502 target.  Upstream's
    documentation says it is allowed on every target; `prog8c` took it for
    the virtual machine only (seen at e13ac65c7).  The LLVM branch takes it
    everywhere since 94f9494c2.

  And the other way round, programs that upstream accepts and p8p8 does not:
  - an `if` expression whose first value begins with a sign and has no
    `then`: `if v < 0 -v else v`.  p8p8 reads `0 - v`; write `then`, or
    parentheses;
  - on a target with addresses wider than a word, an array of `uword`
    initialized with addresses of subroutines.

  An address variable indexed by a signed variable (`ptr[i]`, where an
  array would be refused) is accepted by both and counts backwards for a
  negative index.  For a signed *byte* on the 6502, `prog8c`'s code added
  the index as if it were unsigned (seen at e13ac65c7); p8p8 extends its
  sign, as the virtual machine does, and so does the LLVM branch since
  94f9494c2.

  The values of a multi-value return are computed in the order they are
  written, on every target.  Upstream's 6502 code computes the first one
  last, which shows when the values are calls with side effects; its other
  targets use the written order.

  `len()` of an array that is a field of a struct is accepted by p8p8 and
  refused by upstream.  The address of an element of such a field
  (`&p.values[2]`) crashed `prog8c` (seen at b9fae1820); p8p8 compiles it,
  and so does the LLVM branch since 9ed2fe9ea.

  There will be others: the 195 cases were written here, they are not
  upstream's own test suite.
- **Warnings and notes.**  Upstream prints warnings and information lines
  (a variable made constant, recursion, and so on).  p8p8 prints errors and
  three warnings, and has others on request (`-warnunused`,
  `-warnunreachable`, `-warnshadow`, `-warnall`).  One of the three is
  p8p8's own: a symbol named `a` in a block with
  `%option no_symbol_prefixing` on a 6502 machine, which the assembler
  takes for the operand of `asl a` in assembly written by hand.  (p8p8's
  own code is not affected; upstream's computes wrong values there.)
- **Format.**  p8p8's messages are `file:line:column: error: text`, without
  colors.  Parse errors are worded differently (the parser is written by
  hand, not generated from the grammar).

- **Declarations nothing uses are checked too.**  Upstream removes a
  variable that nothing uses before some of its checks, so `ubyte u = 300`
  or `ubyte[-1] a` passes there when `u` and `a` are never used; p8p8
  reports them.
- **Private means private.**  Upstream lets a private array of another
  block be read with an index (`other.table[1]`), and a variable inside
  another block's private subroutine be reached; p8p8 refuses both.

## The command line

Options are upstream's where both have them, with one dash or two.

- **Accepted and ignored**, because they only concern what upstream prints:
  `-plaintext`, `-quiet`, `-quietasm`, `-nosourcelines`, `-timings`,
  `-warnimplicitcasts`, `-ircomments`.
- **Under upstream's name, p8p8's way:** `-noasm` is `-check` (the program
  is checked and nothing is written), `-dumpsymbols` is `-symbols` (p8p8's
  own listing), `-ignorefootguns` is accepted (p8p8 has no such warnings).
- **Not there** (an error, not ignored): `-profiling`, `-newcodegen`,
  `-watch`, `-daemon`, `-emu2`, and the tools that upstream has built in:
  `-libsearch`, `-libdump`, `-dumpvars`, `-gendoc`, `-printast1`,
  `-printast2`, `-float2bytes`, `-bytes2float`, `-vm`, `-vmtrace`,
  `-compareir`.
- `-O`, `-clang` and `-Xlink` apply to the programs clang builds for
  llvm64 and llvm32; llvm16 keeps its own level.
- **p8p8's own:** `-asm`, `-codegen own|upstream`, `-encoding`, `-lib`, `-libpath`,
  `-verbose`, `-ir`, `-llvm`, `-build`, `-run`, `-report` and
  `-reportnosource` (everything about one run in a directory, to attach to
  a report of a problem), and options that print the compiler's internal
  tables.
- Without an option that says what to do the program is compiled, as by
  upstream: a program file for a machine, the `.ll` file for an llvm
  target.  (Up to 0.1.0 p8p8 only checked a program for an llvm target.)
- `-srcdirs` takes `:` and `;` between directories on every system;
  upstream takes `:` on Unix and `;` on Windows.
- `-codegen upstream` is p8p8's: the program is built from p8p8's IR by
  `prog8c-llvm`'s back end, for the 6502 and the 68000 machines.
- `-cpu 6502|65c02|65816` is p8p8's: the CPU to write 6502 code for, in
  place of the one the target's file names.
- `-floats auto|hard|soft` is p8p8's: on an 8086 machine, which float
  arithmetic the program has (see the README's options).
- `-map` is p8p8's: after the build, the program's map (`name.p8map`),
  which `p8size` reports from.  Nothing changes without it.
- `-Xcompile` is there for llvm32 only.
- `-triple` for llvm32 reads the LLVM branch's profile files, but only the
  keys of the hosted 32-bit platforms ([TARGETS.md](TARGETS.md)); for llvm64
  and llvm16 it takes a few names that are built in.
- The output directory of `-out` or `-o` has to exist.
- One program for each run of the compiler: several source files on one
  command line are not reliable.

## The library

- Upstream carries its library inside the compiler.  p8p8 reads it from a
  directory, which is a repository of its own: upstream's library unchanged,
  with machines, modules, and minor bugfixes that are added beside it
  ([TARGETS.md](TARGETS.md)).
- A machine's description is a properties file in the format of upstream's
  custom targets, with a few keys of p8p8's own (the startup code among
  them, which upstream has in its Kotlin sources for its built-in machines).
- `%import` looks in the same places in the same order; the library has more
  layers.  `-traceimports` shows which file a module came from.

## Overlays

`%overlay n` in a block puts the block's code into overlay n (in a
subroutine: that subroutine's; at the top of a module, with names after
the number: theirs): code that is
kept outside main memory and is only there while it runs (a RAM bank of the
Commander X16, a RAM Expansion Unit on the C64 and C128, memory beyond
64 KB on the MEGA65, a bank of the GameTank's cartridge).  The block's variables, strings and arrays stay in
main memory, and the compiler writes the calls into an overlay, between
overlays and back.  `p8c` writes two files that belong together,
`name.prg` and `name.non`.  On a machine without overlays the directive is
ignored and the program is built in one piece.  Upstream has no such
directive.

`%option overlay_data` in a block of an overlay puts the block's strings and
arrays with values into the overlay too, and has routines of the library
called with the overlay left in the window, so that they can be given the
address of what is there.  `%option overlay_safe` in a block of the program
has it called the same way.

[OVERLAYS.md](OVERLAYS.md) is the guide: the machines, what belongs in an
overlay and what does not, what a call costs.

## A custom launcher knows the zero page setting

A target's `custom_launcher_code` is one text for every program.  p8p8
defines `prog8_zeropage_safe` (1 or 0) in front of it, so that the launcher
can do what the compiler's own startup code does: put the address of
`sys.reset_system` on the stack when the program uses zero page that BASIC
needs (`.if prog8_zeropage_safe == 0`).  The MEGA65's launcher does; a
program built with `-D "prog8_exit_noreset:=1"` returns to BASIC all the
same (the tests read the screen afterwards).

## Far memory

On a machine with memory beyond 64 KB and a CPU that reaches it (the MEGA65;
the C64 with a SuperCPU and `-cpu 65816`), a long constant is an address:
`&ubyte ATTIC = $8000000`, `ATTIC[i]`, `@($40000)`, `peek($40000)`,
`pokew($40000, w)`.  Upstream has no such targets and refuses an address of
more than 16 bits; so does p8p8 everywhere else.  A long variable or
expression is an address too: `@(base + i)`, `peek(base)`, `base[i]`; and
`&` of a variable in far memory is a long.  Pointers are words there as
everywhere: there is no typed pointer to far memory, a far address does not
go into a word, and a far array cannot be passed to a subroutine or
searched with `in`.

The library module `farmem` (for those two machines) copies and fills
there: `farmem.copy(source, target, count)` and
`farmem.fill(target, count, value)`, the addresses longs, with the
MEGA65's DMA controller and the 65816's block moves.  The blocks may
overlap; one block stays inside a 64 KB bank.

## Things upstream has that p8p8 does not

- the virtual machine, and running a program in it;
- a language server and editor support;
- the syntax files, documentation and examples: those are upstream's and
  apply to p8p8 as they are;
- years of use.  p8p8 is new and has been run on few programs.  Mistakes in
  basic behaviour have been found as late as its first week (where an
  uninitialized local is set to zero, the address of an element behind a
  pointer, the value of a call through a pointer); each now has a test, and
  there will be more of the same.

## Things p8p8 has that upstream does not

- A target file can say that the program file is the image of a whole
  cartridge (`image_size`, `image_ext`).  The GameTank's does: `p8c` writes
  a 2 MB `name.gtr` with the program at its end, where `prog8c` writes the
  16 KB `name.bin`.  `-noimage` gives that file.
- On the Color Computers a float is the ROM BASIC's (five bytes, about nine
  digits) and prints as BASIC prints it; `floats.round` takes a half up.
  `sim6809` has no floats.
- On an 8086 machine a float is an IEEE double, as on the llvm64 target, but
  prints with up to 15 digits (there: as many as tell the number apart, up
  to 17), and the functions of `floats` are series that are good for about
  15 digits.  A number too small for a double's normal range is 0.
- On an 8086 machine (`dos`) an `asmsub` or `extsub` names the 8086's
  registers: `AL`, `AH`, `BL`, `BH`, `CL`, `CH`, `DL`, `DH` (a byte), `AX`,
  `BX`, `CX`, `DX`, `SI`, `DI`, `BP` (a word), and `Pc`.
- On a 6809 machine (`coco2`, `coco3`, `sim6809`) an `asmsub` or `extsub`
  names the 6809's registers: `A`, `B` (a byte), `D`, `X`, `Y`, `U` (a
  word).  `X` and `Y` are words there, and there are no pairs (`AY`).
- A target file can make the golden ram the place of the variables without
  an option (`vars_golden`; the GameTank's does), where `prog8c` wants
  `-varsgolden`.  With that key no variable with an initial value is in the
  program either, as in every program of `prog8c`'s.
- A target file can have blocks at an address placed out of line
  (`fixed_blocks_apart`; the GameTank's does), where `prog8c` has the rest
  of the program follow such a block.
- `-map` and `p8size`: a map of the built program in one format for every
  CPU (the address and bytes of each block, subroutine and variable), and a
  tool that says from it where the program's size goes, per block,
  subroutine, variable or source file, and what changed between two builds.
- It is written in Prog8 and compiles itself; it is built from its own
  earlier output with clang alone, on macOS, Linux and Windows.
- It starts at once: there is no Java virtual machine to start.
- Every 6502 machine, the built-in ones too, is a text file that can be
  changed without rebuilding the compiler.
