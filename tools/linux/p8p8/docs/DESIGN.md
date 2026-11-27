# The design of p8p8

p8p8 is a Prog8 compiler written in Prog8.  This document says how it is
put together and why.  [TARGETS.md](TARGETS.md) describes target files and
the library; the README has the command line.  [INTERNALS.md](INTERNALS.md)
is the long version: how each part works, with real output.

## Aims

- **Compile the Prog8 language as the reference compiler does.**  The
  language, the standard library, the conventions of generated code and the
  command line are upstream's.  Where p8p8 differs it is by an option that
  changes nothing unless it is given.
- **Be written in what it compiles.**  The compiler is plain Prog8 with
  calls into the C library, no inline assembly, so that it compiles itself
  and stays portable to smaller hosts.
- **Good code for 8-bit machines.**  The 6502 code generator is p8p8's own
  and is measured against the reference compiler's on real programs, for
  size first.
- A compiler that runs on the 8-bit machines themselves is the long-term
  idea.  Nothing in the design should make that harder; it is not built yet.

## The pipeline

```
source ─ lexer ─ parser ─ importer ─ symbols ─ resolver ─ typer ─ checker
                                                                    │
                                     IR generation (irgen) ─ unused code removal (irprune)
                                                                    │
                        ┌───────────────────────┬───────────────────┴──────────┐
                   .p8ir text             LLVM IR (llvmgen)          6502 assembly (gen6502,
              (the reference VM,          then clang:                 peep6502), then 64tass:
               the reference back end)    the host, and p8p8 itself   the 8-bit machines
```

| Stage | File | Notes |
|---|---|---|
| lexer | `lexer.p8` | hand written; newlines are tokens, as the grammar needs |
| parser | `parser.p8` | recursive descent, precedence climbing; the whole grammar |
| importer | `importer.p8` | `%import` against `-srcdirs` and the library, in the order TARGETS.md gives |
| symbols, resolver | `symtab.p8`, `resolver.p8` | scopes, names, `%option merge` |
| typer | `typer.p8`, `types.p8` | types, constant folding, string literal encoding |
| checker | `checker.p8` | the errors the reference compiler reports |
| IR | `irgen.p8`, `ir.p8`, `irprune.p8` | the reference compiler's IR, instruction for instruction |
| back ends | `llvmgen.p8`, `gen6502.p8`, `peep6502.p8`, `gen68k.p8`, `genz80.p8`, `peepz80.p8` | below |
| driver | `main.p8`, `target.p8` | options, target files, running clang or 64tass |

There is one syntax tree, typed in place.  The reference compiler has two
(a compiler tree and a simplified one); that split is its history and not
something the language needs.

### Why the IR is the reference compiler's

Every back end takes the same intermediate representation, and it is the
`.p8ir` format of the reference compiler, not a format of p8p8's own.  That
buys three things:

- p8p8's IR runs in the reference compiler's virtual machine, so the front
  end can be tested without any back end of p8p8's.
- The reference compiler's back ends accept it (`-codegen upstream`), which
  gives a second way to build every program and to compare.
- A back end written for it once serves both compilers' idea of a program.

For the 6502 machines the IR is already in their conventions: register
arguments of `asmsub`s, split word arrays, the symbol prefixes (`p8b_`,
`p8s_`, `p8v_`) that library assembly expects.

Register numbers are words, one row of them for the whole program, each with
one type.  The code generators for real machines need that: every register
has a place of its own.  On the llvm targets a subroutine is a function with
registers to itself, so there a subroutine takes the numbers that earlier
ones had, and only those of the type it asks for (`ir.new_reg`: a list of
numbers for each type, and how many the subroutine in hand has taken), so the
table of types holds for all of them.  Without that the compiler could not
compile itself any more: it had passed 65,000 registers, and has under 2,000
numbers now.  On the other targets running out is an error, not a silent
start from zero.

An IR file can be the input too (`p8c program.p8ir`): `irread.p8` reads the
whole file into the same structures `irgen` builds, with `irparse.p8` (which
was there for the libraries' `%ir` blocks) for the instruction lines, and the
program goes on through `irprune` and a back end as generated IR does.  The
test is that p8p8's own IR comes back the same: written, read and written
again it is the same text, and the code made from the file is byte for byte
what the program gives directly (`make irroundtrip`).  For that the file
carries what the code generators take from the program besides the IR, as
attributes of `<PROGRAM>` that upstream's reader passes over: `FLOATS` and
`VARSADDRESS` when set, the order the variables were declared in
(`VARORDER`: the file groups them by kind, and the order decides zero page
addresses) and the registers' types (`REGTYPES`).  A block's chunks and
subroutines are written in source order.  IR that upstream wrote is another
matter: it has opcodes p8p8 does not generate or translate (`storep_inc`,
`loadiz`, `loadmzl`, `bsigb`, `midb`) and a `<LOOP>` element, so only the
simplest programs get through.

### Struct variables

A variable whose type is a struct (`Point p`) is not a variable in the IR
but a struct instance, like the one a struct initializer makes, with a name
made from where it is declared: `prog8_struct_instances.main_start_p` (and
`p8b_main_p8s_start_p8i_p` where names carry prefixes).  `sym_name` gives
that name, so everything that takes a variable's address works unchanged;
`identifier` and `field_address` load the address where they would load a
pointer's value, and from there a field is reached as through a pointer.
Field values in the declaration are the instance's data; another struct as
the initializer, and `q = p`, are a call of `sys.memcopy`.  One at a fixed
address (`&Point regs = $d000`) is a memory-mapped name whose address is
loaded as a number.  The code generators needed nothing new for this,
except that the 6502's puts instances without values in the BSS section.

## Conventions of the source

- **Memory is allocated and not freed.**  A compiler is a batch job.
  Allocation goes through `mem.p8` and a platform module, so another host
  can supply its own.
- **Tree nodes** are one record for every kind (kind, position, type, up
  to four children, a name, a value); lists are linked through a `next`
  pointer.
- **Names are interned** (`strtab.p8`) and compared by pointer.  The symbol
  record carries a few fields a back end may use for its own marks.
- **Text is in growable byte buffers** (`buf.p8`), never in Prog8 strings,
  which are static and limited.
- **Portable types:** `pointer` and typed pointers for addresses, never a
  64 bit integer; no arrays or strings as locals of subroutines that
  recurse (Prog8's locals are static).
- **Host specifics** are in `src/<target>/*_platform.p8`: files, the
  environment, running a command.

## Reports of problems

`-report dir` is for the user who has a problem and no small program that
shows it.  The compiler starts itself a second time with the same command
line, the output and the written files redirected into the directory, and
adds the versions, the command, the list of loaded files and copies of the
program's own sources.  It is a second process so that a run that crashes
is reported like any other.

The compiler keeps a note of what it is doing (`crumb.p8`: the stage, and
the file or subroutine where a stage records one).  A handler for the
signals of a crash prints that note and exits with status 70.


`llvmgen.p8` writes LLVM IR text from the IR: a function for each
subroutine, a basic block for each chunk of the IR, and every virtual
register as a stack slot that LLVM's optimizer turns back into a register.
clang builds it.  This is
how p8p8 itself is built, for macOS, Linux and Windows, and how Prog8
programs are built for the host.  A few helper functions that every program
needs are kept as text in `llvmrt.p8`.

## The 6502 code generator

`gen6502.p8` translates the IR to 64tass assembly; `peep6502.p8` improves
what it writes.  The layout of the output (launcher, startup, one scope per
block and subroutine, data, uninitialized data) is what the library's
assembly expects.

### One instruction at a time, then passes over the result

Each IR virtual register has a **cell**, a byte or more of memory.  The
generator translates each IR instruction by itself: operands from their
cells, the result to its cell.  That is simple and always right, and on its
own it is poor code.  All of the quality comes from the passes that run
over each subroutine's lines before they are written out:

- **Jumps:** threading, branches around jumps, unreachable code, labels
  nothing names, a call followed by a return as a jump.
- **Forward, with value numbers** for A, X, Y, the cells, plain variables,
  the virtual registers and the scratch pointer: a load of what a register
  already holds goes, a cell that is a copy of a variable is read as the
  variable, a constant is used as a constant.
- **Backward, with liveness** of A, X, Y, the flags, the carry and the
  scratch pointer: a load or transfer nobody uses goes, as does a store to
  a cell that is written again first.  What is known at each label is kept
  from one pass to the next, so loops are understood on the second round.
- **Stores:** a value stored to a cell and then to a variable is stored to
  the variable; a value stored from both arms of a test is stored once.
- **Operands in place:** a memory operand used where it is instead of by
  way of a cell; a word plus one made in A and Y; arguments computed in the
  order that needs no cell.

Lines the generator does not understand (inline assembly, a few runtime
sequences) are opaque to the passes: everything is forgotten there.

### What a call may change

A call makes the forward pass forget every variable, with three exceptions
that matter a great deal for size:

- a subroutine's **own variables**, when nothing else names them (no other
  subroutine, no assembly, no address taken) and the subroutine cannot be
  running a second time inside the call.  `own_variables` works that out
  from the call graph, where assembly, a call through a pointer or a call
  out of the program may reach any subroutine that assembly names or whose
  address is taken;
- the program's variables over the library's multiply and divide routines;
- cells, which are private to their subroutine.

### Cells and the zero page

Most cells do not survive the passes.  Those that do are short lived, so
cells that are not in use at the same time share storage:

- a few zero page bytes (the **pool**) serve the cells of every subroutine
  that are not in use over a call;
- cells in use over a call share among themselves within their subroutine;
- a subroutine that may run from an interrupt keeps off the pool.

A cell's lifetime is its first line to its last, stretched over a loop it
is in, unless every use is known to come after its first store.

The zero page is given out in this order: what `@requirezp` names (it is an
error, in upstream's words, when one does not fit), what `@zp` names (as
long as there is room), the pool's cells, and then the other variables by
how often they are named, with more weight for a pointer that is followed
(in the zero page it needs no copy).  `%zpreserved` and `%zpallowed` (the main module's) take bytes out of
what is free before any of that.  `@nozp` keeps a variable out, and a
parameter's tags count like a variable's.  Asked for, a variable of any
size goes there, and an array without values, which the start of the
program clears; an array or string with values does not (its values would
have to be copied in), which is an error for `@requirezp`.  Which zero page
bytes are free is the target file's business.

A float register's cell is used by address and keeps its place, so those are
given out before the others; only the float registers that the code left
after pruning still names get one (the library's float routines that a
program does not call used to cost 250 bytes of cells).

On the C64, the C128 and the PET the library has the virtual registers
R0-R15 outside the zero page.  When the program has the zero page to itself
(`%zeropage kernalsafe`, the default, or `full`; not a library, not with
floats unless the mode is given) they are moved into it, as upstream does,
so that assembly can use one as a pointer: `irgen.zeropage_registers` gives
`cx16`'s memory mapped variables new addresses from the target file's
`virtual_registers_zp` before anything is declared, and those 32 bytes are
not given to variables.

### The order of the blocks

`main` is first, then the blocks without an address in the order the program
and the libraries have them, then the blocks with an address of their own,
lowest first (`irgen.addressed_blocks_last`; upstream's order).  A block's
address becomes `* = address` in the assembly, and what follows it in the
file is assembled from there: so nothing may follow but blocks that say
where they go themselves.

### Programs for ROM

With `%option romable` nothing that is written may be in the program.  A
scalar with an initial value lives with the uninitialized variables and gets
its value from code at the start; the variables have to be somewhere else
(`-varsgolden`, `-varshigh`, `-varsaddress`, `%varsaddress` or the target's
`vars_address`), which is checked as upstream checks it.  (A target file
with `vars_golden` gets that much, the scalars in RAM, for every program:
`rom_target` beside `romable` in `ram_initialized`.  The rest of this
section is for `%option romable` only.)  What nobody can
check by reading the generator is that none of its code, none of its
peephole passes and no routine of the library writes into the program after
all.  So the assembler checks: `rom_guard` goes over the finished assembly
text and puts, after every instruction that writes to a named or numbered
address, a `.cerror` that fails when that address is inside the program.  A
write to an array with values, a library routine that changes its own code,
a variable that was left in the program: each stops the build with the
instruction named.  A write through a pointer is not seen.

### CPUs

The generator knows the 6502 and the 65C02.  On the 65C02 it uses `stz`,
`bra`, `inc a`/`dec a`, `(zp)`, `tsb` and `trb`.  It never uses `bbr`,
`bbs`, `rmb` or `smb`: the 65816, which many Commander X16s have, does not
have them.  The 65816 and the 45GS02 have sections of their own below.

The accumulator's instructions are written without an operand: `asl`,
`lsr`, `rol`, `ror`, and `ina` and `dea` for `inc a` and `dec a`.  In a
block with `%option no_symbol_prefixing` a variable may be named `a`, and
64tass would take an operand `a` for that variable.

Multiplication, division, shifts by a variable and floating point use the
library's routines, the same ones the reference compiler calls.  A
multiplication by a constant is done in line where that is cheaper: shifts
for a power of two, and shifts and additions for a constant with few bits
set (times 37 is five shifts and two additions).

## The 68000 code generator

`src/gen68k.p8` writes assembly for vasm from the same IR, one IR
instruction at a time.  It
writes programs for qemu68k (a bare 68020 in QEMU, where it can be tested
without an operating system), the Amiga 1200 and the Amiga 500.

- A virtual register is a cell of four bytes with the value at its low end,
  so that a value read narrower than it was written is its low part on a
  big-endian machine too.  d0, d1, a0 and a1 are scratch within one IR
  instruction.
- d2 to d7 keep values from one instruction to the next.  A subroutine's
  own plain variables, the most used ones, get one each for the whole
  subroutine (a pointer that is only loaded, stored and added to gets a2,
  a3 or a4); what is left goes to virtual registers that are only named
  within one chunk, each from its first to its last mention.  Everything
  else is in the frame.  A subroutine saves and restores the registers it
  uses, so a call keeps them; the ones that its calls pass arguments or take
  results in are not used in it, and a subroutine that calls through a
  pointer uses none.  `P8P8_NOREGS` in the environment turns this off.
- A virtual register often needs no place of its own: one that is loaded
  from a variable in a register and not changed is that register; so is a
  copy of a register, or of its low byte or word; one that only holds a
  number or an address is written as that wherever it is used; and "copy
  the base, add the index, use the sum as an address" becomes the addressing
  mode `offset(base,index.l)`; and "load a variable, work on it, store it
  back" is worked on in the variable's register.  Each of these is decided before the code is
  written, by looking ahead in the chunk for anything that changes one of
  the values involved.
- Multiplication, division and remainder by a power of two are shifts and
  masks; a 68020 multiplies and divides longs in the register that holds
  the value.  A subroutine with nothing in its frame has no `link`.  Two things
  are done to the lines as they are written: a value that was just stored
  in its cell is not fetched again, and a `tst` right after the `move` that
  set the same flags is left out.
- The cells of a subroutine are in a stack frame under a5.  So are its own
  plain variables and parameters, when nothing but the subroutine names them
  (no other subroutine, no assembly text, no address taken): that is what a
  subroutine that calls itself needs, and what the reference compiler does
  on this CPU.  The caller still writes an argument to the static parameter;
  the subroutine copies it into its frame when it is entered.
- Floating point is the FPU's.  A float in memory is four bytes, as the
  reference compiler and its library have it; a float register's cell is
  twelve and holds what the FPU had, so a value is only rounded to four
  bytes where the program stores it.
- A subroutine with assembly text in it has no frame, because the text may
  return on its own; its cells are in a static area.
- Arguments of assembly routines go into the registers their declarations
  name, results come from them; a subroutine's own value comes back in d0,
  several values in d0, d1 and so on.  The first two parameters of a
  subroutine that are not floats and that nothing but the subroutine names
  arrive in d0 and d1; the others in their static variables, as before.
- An assembly routine of the library that nothing refers to is left out,
  as for the 6502.
- On the Amiga a routine of a library is called through the library's jump
  table: its base in a6 (exec's from address 4, the others from the
  variables the library's startup code fills), then `jsr offset(a6)`.  The
  sizes and field offsets of structs are written as equates, which the
  library's assembly text uses.  vasm writes the hunk file itself.
- The Amiga 500 has a 68000, which multiplies and divides words only: for
  longs the code calls the routines of the library's `m68k_prog8_longmath`
  (they use utility.library where there is one).  A program with floats is
  assembled for a 68020 with an FPU there too, as the reference compiler
  does it: the floats library needs both.
- A block with `%option amiga_chipram` goes into sections of its own
  (`code_c`, `data_c`, `bss_c`), which AmigaOS loads into chip memory.  A
  call is always `jsr` with an absolute address, so it can cross sections.
- vasm assembles with names in full (`-ldots`), without scopes; vlink lays
  the program out with the target's `link.ld` from the library.

## The 65816

`-cpu 65816` (or `cpu = 65816` in a target's file) gives the same 6502 code
generator a CPU that has everything the 65C02 code here uses, and a 16-bit
accumulator.  The second is where the 6502 family is weakest: adding two
words is six instructions on a 65C02 and three on a 65816.

- **Runs.**  Within a chunk, a run of consecutive IR instructions on words
  is written for the 16-bit accumulator between one `rep #$20` and one
  `sep #$20`.  Inside it one value is in the accumulator; a register that
  was loaded from a variable is that variable until one of them changes, one
  that was loaded with a number is that number, and a second value that is
  still needed waits in one of the two scratch words.  A run names no
  virtual register that is named outside it, because the 8-bit code keeps
  every byte of a register in a cell of its own and the two bytes of a word
  need not be next to each other.  A run that would need more is written as
  8-bit code.  The peephole passes take a run for text.
- **Within a run.**  After a store the accumulator is that variable still,
  so a load of it writes nothing; a store that the next store to the same
  variable overtakes, with no memory named in between, is taken out;
  `(v << n) | (v >> (16 - n))` is a rotation (`asl a` / `adc #0` for one bit
  to the left, `xba` for eight); a comparison that branches on greater or
  less ends a run, unsigned by the carry and signed by the sign of a
  subtraction that `bvc` / `eor #$8000` corrects.
- **From run to run.**  A chunk that begins with a run has a second label
  after its `rep #$20`.  A branch at the end of a run that goes to such a
  chunk (a loop's way back) is taken 16 bits wide to that label, and a run
  that ends where its chunk ends, before a chunk that begins with one, falls
  into it without `sep` and `rep`.  Whatever else jumps to that chunk's own
  label finds it after the subroutine's code: `rep #$20`, and a jump to the
  second label.  So a loop of word arithmetic changes the width once on the
  way in and once on the way out.
- **Native mode.**  16-bit registers only exist in the 65816's native mode.
  Where the machine's ROM is written for programs in native mode (the
  target's `native65816 = rest`: the Commander X16), the entry code switches
  to it around `main.start`, with 8-bit registers as the rest of the code
  and the library's assembly expect, and a call of `sys.exit` switches back
  first.  On any other machine the program stays in emulation mode and each
  run switches for itself: the C64's BASIC ROM divides floats wrongly when
  it is called in native mode.  Where a loop is all runs the switching is
  outside it and costs nothing that can be measured (the word loop of the
  benchmarks: 89 jiffies either way, 366 for the 65C02's code); code that
  alternates between words and bytes pays for each change.
- **Interrupts.**  A subroutine that may run from an interrupt has no runs:
  the X16's ROM calls those in emulation mode.
- Not yet: word arrays (two byte arrays on this CPU family), anything through
  a pointer, values that come from outside a run (a call's result), 16-bit
  index registers, stack-relative addressing, block moves.

## The 45GS02

The MEGA65's CPU, and what `-target mega65` writes code for (the target's
file says `cpu = 45gs02`; `-cpu 6502` gives plain 6502 code for the machine).
It is the 6502 generator with two differences.

**Two 65C02 instructions mean something else.**  `stz` stores the Z register,
and `(zp)` is `(zp),z`.  With Z at zero they are the 65C02's.  The generated
code leaves Z at zero wherever it used it, but does not count on finding it
zero (whether the machine's ROM always hands it back so is not settled), so
those two forms are not written; the other 65C02 instructions are
(`c02z` is "a 65C02 for these two as well").  `P8P8_45_STZ` turns them on, to
try.

**Longs are 32 bits in one instruction.**  A, X, Y and Z together are the
register Q, and `ldq`, `stq`, `adq`, `sbq`, `anq`, `orq`, `eoq`, `cpq`, `inq`,
`deq` and the shifts of Q work on four bytes of memory.  `quad_instruction`
writes the long IR instructions with them (loads, stores, the arithmetic and
logic, shifts by a few places, comparisons, the long arguments of a call);
what it does not know goes the 6502's way, a byte at a time.  Between two
such instructions the value stays in Q, and a long that was only fetched from
a variable *is* that variable until something stores there (`qacc`, the
`qalias` tables; the tables of where a register is named are the 65816
runs'), so that `c = a + b` is `ldq a / clc / adq b / stq c`.  Before any
other instruction `q_flush` puts every value where the 6502's code looks for
it.  There is no immediate form: a constant operand is four
bytes of data (`p8_qconst_N`).  A signed comparison is a subtraction whose
sign the overflow flag turns round; the top byte is in Z, so `tza` first.

**Z is zero where the generated code is left**, not after every 32-bit
instruction: before a call, a return, a jump to another subroutine and
assembly text (`z_matters`).  The ROM is written for a Z of zero (BASIC gave
`?SYNTAX ERROR` when a program came back with another); the generated code
itself never counts on it.  Whether Z is zero is known along a chunk and
unknown where another chunk of a subroutine with longs begins.  The `ldz #0`
goes next to the 32-bit code or to the head of the chunk when a call follows
before the next long instruction (`z_wanted_from`): written just before the
call it would stand in the middle of what the peephole passes work on, and
every temporary around it stays alive.  Never between a comparison and its
branch.

**Where the 6502's way is quicker it stays.**  A 32-bit instruction costs
about as much as two or three of a byte.  Incrementing a long in memory
(`inc / bne`) and testing two longs for equality (compare, branch away at the
first byte that differs) are done after one byte most of the time, so those
are written the 6502's way with the names Q's code knows (`q_byte`).

**The flags.**  The instructions that make a value in Q set N and Z for all
32 bits, so a result that is tested against zero needs no comparison
(`qflags`): `if a & 1023 == 0` is `ldq a / anq mask / bne`.  `stq` does not
leave the flags alone: its prefix `$42 $42` is two real `neg a`, which set
them by the low byte.  (Found by a loop of 65536 turns that made 256;
`tests/mega65/qflags.p8` shows it in xmega65.)  So a value is stored before
a comparison, never between it and the branch, and a counter that has to be
stored is loaded again for its flags.

A long comes back from a call in R14 and R15 and is fetched from there into
Q; a long is returned by storing Q there.

**The MEGA65's arithmetic unit.**  The 45GS02 is that machine's CPU, so its
multiplier and divider are there: two 32-bit numbers at `$d770` and `$d774`,
their product at `$d778` at once and the quotient at `$d76c` when the busy
bit of `$d70f` is off.  A long multiplication is five 32-bit instructions.
The divider is unsigned and prog8's longs are not, so a division calls
`p8_qdivs`, which the generator writes into a program that divides longs:
it makes both numbers positive, divides, and gives the quotient its sign
(18 bytes of the register file are its cells).  Bytes and words go the same
way: where the 6502 code calls the library's `multiply_bytes`,
`multiply_words`, `multiply_ubyte_word`, `divmod_ub_asm` or `divmod_uw_asm`,
the 45GS02 code calls `prog8_hw_mulb` and its like, routines the generator
writes into the program that take and give the same but put the numbers into
the arithmetic unit (`math_routine`, `hw_routines`).  Their names begin with
`prog8_` because the peephole passes go by that for "a routine that reads the
scratch words"; under another name the stores of a dividend were removed.
Signed division is still the library's.  `P8P8_45_NOMATH` leaves all of it
to the library's routines.

The lines are written as text the peephole passes do not look into, and a
long register's cell has a fixed place (they would otherwise move and share
it), as a float's has.

64tass's names for these instructions are its own (`adq`, not `adcq`; `asl q`;
none for the negation of Q, which is three bytes `$42`), and a word it does
not know on a line of its own is a label to it, silently.  Library assembly
that switches to `.cpu "45gs02"` for a few lines goes back with
`.cpu "default"`, which is the CPU of the command line (`--m45gs02` when the
program is 45GS02 code).

`tools/benchmega65.sh` times four loops on longs both ways (by the VIC-IV's
frame counter; the jiffy clock stands still in xmega65).  Frames for the
6502 code and the 45GS02 code: addition 65 and 48, multiplication 18 and 1,
division 12 and 0, comparisons 71 and 63; 1,841 and 1,243 bytes.  Words and
bytes: multiplication 40 and 9, 13 and 6; division with remainder 72 and 13,
14 and 6.  The first
version, which made Z zero after every instruction and did everything with
Q, was slower than the 6502 code on two of the four.

**Words in the zero page** are counted up and down with `inw` and `dew`
(`word_step`): one instruction of two bytes.  For variables; where a
temporary will be is not known yet when the code is written.

**Z is not an index register** of the generated code.  It is left for the
28-bit pointers, `[zp],z`.

There is no other compiler to compare with: `make emucmp65` runs each test
program on the MEGA65 (xmega65, without a window) as 6502 code and as 45GS02
code and compares the screens.

## Addresses of more than 16 bits

An extension, where the CPU has the means and the target says the machine
has the memory: `far_address_bits` in the target's file (28 for the MEGA65,
24 for the C64, which counts with a SuperCPU and `-cpu 65816`; the Commander
X16 has the 65816's instructions and nothing to reach with them).  The
driver puts the number into `types.far_bits` when the program's CPU is the
65816 or the 45GS02; everywhere else an address of that size is refused as
upstream refuses it.

A long is a far address.  Pointers stay words: what needs a pointer to far
memory (a typed pointer, an array passed or searched) is refused, and so is
a far address into a word.

A constant address: a memory mapped variable or array
(`&ubyte ATTIC = $8000000`, `ATTIC[i]`), `@(constant)`, `peek` and `poke`
and their relatives.  In the IR those are what they are nearby: a memory
operand with a fixed address or the variable's name, only larger.

An address the program works out: a long variable or expression in `@()`,
in `peek` and `poke`, or with an index (`base[i]`); `&` of a far variable
is a long (the typer, `far_memvar`).  In the IR the load or store goes
through a register as always (`LOADI`, `STOREI`), and the register is a
long, not a pointer; that is how the code generator knows
(`far_indirect`: the register's bytes are the far pointer).

The code generator (`far_instruction`) does every instruction with a far
memory operand in one way: a pointer to the operand goes into the two scratch
words, which are four bytes in a row (three bytes and `[dp],y` on the 65816,
four and `[zp],z` on the 45GS02; the index of an array is added in), the
value is fetched through it into a few bytes of the register file, the
instruction is written as for a variable there, and what it changed is
stored back.  That is not fast (a byte read is some ten instructions) but
whatever can be done to a variable can be done to a far one at once.  On the 65816 a far operand at a known address needs no pointer: the
instruction names the address itself (`lda @l 262144`, and `,x` for an
element; `far_long`).  A plain load or store, of a register, of zero or of
a constant, goes straight between the register and far memory; anything
else still fetches the value, works on it and puts it back, without the
pointer.  These lines are instructions like any other for the peephole
passes, which have to know what becomes of A; the `@l` in front marks the
operand as one that only the accumulator's instructions take, so no pass
makes an `ldy`, `stx` or `stz` of it.  A loop that fills and sums a far
array of 200 bytes 300 times takes 11 jiffies on a SuperCPU where the
pointer took 24.  An address the program works out still goes through the
pointer, as everything does on the 45GS02; there a long is fetched and put
back with one `ldq`/`stq` through the pointer.  The 16-bit runs and the fusing of indexed patterns leave
chunks with far operands alone (the runs had written to the low 16 bits of
the address).

The library's part is the module `farmem` in the two machines' directories
of `lib/targets`: `copy` and `fill` with long addresses, a DMA order on the
MEGA65, `mvn`/`mvp` on the 65816 (the two bank numbers are in the
instruction, so it is put together in a variable and called there; nothing
is written into the program's code).

`make farcheck` runs these programs: the instructions written by hand (the
65816's absolute long, absolute long indexed, `[dp]`, `[dp],y` on the X16 and
the SuperCPU; the 45GS02's `[zp],z` and `ldq`/`stq` through it on the MEGA65)
and `tests/far/fardata.p8` (constant addresses) and `farcomputed.p8`
(worked out ones), where the compiler writes the code, and `farlib.p8`
(the library), on the two machines with far memory.  On the X16 a bank other than 0 is bank 0 again in
x16emu.

Assembly text that switches the CPU for a few lines goes back with
`.cpu "default"`, so p8c gives 64tass the program's CPU on its command line
whatever it is (`--m65c02`, `--m65816`, `--m45gs02`), not only in the file.

## Overlays

An extension: a block with `%overlay n` has its code in overlay n, on a
machine whose target file describes overlays (the Commander X16: a bank of
high memory, in the window at $a000 while its code runs).  Anywhere else the
directive says nothing and the program is built in one piece.

`%overlay n` in a subroutine puts that one subroutine into the overlay,
whatever its block says (`ir.Sub.overlay`; `overlay_prepare` gives every
subroutine the overlay its code is in, and one declared inside another the
overlay of that one).  Such a subroutine is written in its overlay's part
outside its block's scope but under its full name
(`p8b_main.p8s_name  .proc`), so nothing that names it changes.

The number of an `%overlay` may be a constant's name: nothing resolves names
in directives, so `typer.directive_number` looks it up when irgen reads the
directive.

`%overlay n, name, name...` at module level is the same said from outside:
`irgen.overlay_lists` looks each name up after all blocks are generated
and sets the block's or the subroutine's overlay.

Only code is in an overlay.  The variables, strings and arrays of such a
block are in main memory with all the others (the code generator writes them
outside the blocks anyway), so an overlay is never written back, a value is
there whichever overlay is in, and the same would do for banks of ROM.

The program is still compiled as one: one zero page, one set of names.  The
generator knows for every call where it is and where it goes
(`overlay_entry`): within an overlay and from an overlay into the main
program it is a plain `jsr`; into an overlay from outside it is a `jsr` to a
thunk in main memory, written from the target's `overlay_thunk` (on the X16
the ROM's JSRFAR, which keeps the registers and flags and puts back the bank
that was there, so a program that chooses banks for its data is not
disturbed).  The address of a subroutine in an overlay is its thunk's.
Every subroutine of an overlay block gets a thunk; the assembler leaves out
the ones nothing names.  A target may give two thunks: `overlay_thunk`
keeps A, X, Y and the flags both ways, which a subroutine in assembly may
need, and `overlay_thunk_fast` keeps A, X and Y, which is all an ordinary
subroutine takes and gives.  The X16's do without the ROM's JSRFAR, and are three instructions each:
`jsr p8_overlay_in_N / jsr subroutine / jmp p8_overlay_out`.  The first is
written once for each overlay (the target's `overlay_in`: keep the bank,
choose the overlay's), the last is in the support file.  A thunk is nine
bytes so, where it was 24 with all of it written out (33 on the GameTank),
and 20,000 calls take 17 jiffies (15 written out, 37 with JSRFAR, 8 for
plain calls).

A call out of an overlay is a plain `jsr` unless the target has
`overlay_return` (the X16).  There the window's bank is also what a program
keeps its data in, and its main part may choose a bank and count on it
staying chosen (a page store that maps a page and remembers that it did).
So the bank register is the main program's own, and the overlay's bank is in
the window only while the overlay's code runs:

- a call from the main program into an overlay (`overlay_thunk`) keeps the
  bank in a byte of main memory, chooses the overlay's, and afterwards
  chooses what that byte holds;
- a call out of an overlay goes to a stub in main memory, one for each
  subroutine and overlay that calls it (`overlay_out`): it chooses the
  main program's bank, calls, keeps what is chosen then, and chooses the
  overlay's bank again (two shared routines, the second one for each
  overlay: `overlay_back`); a call through a pointer has such a stub too;
- a call from one overlay into another (`overlay_thunk_cross`) keeps the
  caller's bank on the stack.

A block with `%option overlay_data` also has its data in its overlay: the
variables with values that are arrays or strings, and the string literals
that only its code names (`overlay_data_homes` gives each such variable its
`home`; `data_values` writes the ones of a part, the overlay's after its
code).

ROM routines called by their address are called as they are.  So are
routines of the library, and of a block of the program with `%option
overlay_safe`, when the calling block has `%option overlay_data`
(`ir.Block.overlay_data`): its overlay stays in the window, because the block
has data beside its code and gives the library the address.  That is not
the default: p8vi's code in an overlay passes an address in a text page on
to `diskio.f_write`, which has to find the text's bank there.  (The first
version put the overlay's bank back after the call, in the overlay: code
that is not there when the call returns.  The second did it in a stub but
left the main program with the overlay's bank, and the editor p8vi read
its text out of its own code.)

In the assembly the overlay blocks come last, each overlay as a segment
that is placed at the window's address when `prog8_overlay` is its number
and is virtual otherwise.  So the driver runs the assembler once for each
overlay and once for the main program (`overlay_build` in `main.p8`), every
run with the same labels, and cuts the overlay's bytes out of its run.  It
writes `name.non`: the main program and the overlays as records of length,
address and bytes (64tass's nonlinear format), an overlay after a record of
one byte at `overlay_select` that chooses it.  Then it assembles the
target's `overlay_loader` as `name.prg`, with the file's name and the
program's entry (read from the assembler's list of labels): on the X16 a
loader that moves itself to $0400 and reads the file, after the X16 Golden
Loader.

On the C64 and the C128 the overlays are in a RAM Expansion Unit and run in
a window of main memory, one at a time ($c000-$cfdf on the C64, $b000-$bfff
on the C128; the program itself then ends below the window).  The thunk is
`jsr p8_overlay.call` with the overlay's number and the subroutine's
address behind it.  That routine is in `overlay_reu.asm`, the target's
`overlay_support`, which the generator includes in such a program: it keeps
the registers and flags, fetches the wanted overlay from the REU when
another is in the window, calls, and fetches the caller's overlay back.
There is no loader: `name.prg` is the main program, and the first call
into an overlay reads `name.non` (the overlays only) from the disk the
program came from and puts each overlay into the REU, overlay n at
(n - 1) * $1000.  The generator gives the support file a table of the
overlays' sizes (`p8_overlay_sizes`, from labels the assembler works out),
so that a fetch moves the overlay's bytes and not the window's: two
overlays in turn, 4,000 calls, take 72 jiffies on a C64 where whole windows
took 1,162.  The fast thunk looks itself whether the overlay is in the
window and calls the support code only when it is not (20,000 calls: 150
jiffies; 398 through the general routine; 76 for a plain call).

The MEGA65 has the same arrangement with its own memory: the overlays are
kept from `overlay_store` on ($40000, bank 4) and the DMA controller copies
one into the window at $a000-$bfff (`overlay_dma.asm`).  Nothing is banked
or mapped, so the ROM stays where it is.

Three checks: assembly text is scanned for `jsr`/`jmp` to the full name of a
subroutine in another overlay (`asm_overlay_scan`, a warning); the IR is
scanned for the address of a subroutine in an overlay that goes to a call
or a store whose name has irq, nmi or cinv in it, or to $0314-$0318
(`overlay_interrupt_check`, an error); and an overlay that the directives
name but that has no code is said.  `-meminfo` lists what is in an overlay
from where each block and lone subroutine begins in the assembler's list
of labels (a symbol that nothing uses is not in that list, so sizes cannot
be symbols of their own), and what the thunks, the stubs and the support
file take in main memory from labels around them.

`-overlayinfo` (`gen6502.overlay_verdicts`, `main.overlay_info`) gives every
block and subroutine a reason why it cannot go into an overlay, or none:
the runtime blocks that the generator names itself, a block with an address,
a name that assembly elsewhere uses (every name in every piece of assembly
is looked up among the subroutines), an interrupt handler, a call of
something with "bank" in its name where the window is the program's too,
and assembly that writes to a place it defines itself (outside a section),
which only matters where an overlay is copied in or is ROM.  What code does
with addresses is not looked at, and the report says so.

After the build the driver removes what the assembler wrote for each part
(`name.ov0`, `name.ov1`...).

The GameTank's overlays are banks of its cartridge, in the window at
$8000-$bfff below the main program, which is in the fixed bank.  Its texts
are the X16's with `cartbank` for the bank register (the routine keeps the
bank it chose in a variable, which is what the thunks read).  The target
gives `image_size`: the driver then writes one file with the whole
cartridge (`overlay_image` in `main.p8`), bank `overlay_image_first` at its
start and the main program at its end (a program without overlays gets the
same file, from `plain_image`; `-noimage` leaves the assembler's file); an overlay's run of the assembler
begins with the overlay, the window being below the program.  The assembler
is only run for the overlays that exist (there are 127 numbers).

A target file with `fixed_blocks_apart = true` (the GameTank's) has a block
at an address placed out of line: the generator notes the program counter
before `* = address` and sets it back after the block, so the variables with
values and the strings that follow in the assembly stay with the program.
A `.cerror` at the end refuses a block that lies where the program is.

Not there: an overlay of more than the window, code of the library in an
overlay, overlays in an IR file (`-ir` does not write the directive).
Assembly in an overlay block that calls another overlay by its label is not
seen by the compiler.  `make overlaycheck` runs programs in x64sc and x128
with an REU, in xmega65 (as 45GS02 and as 6502 code), and three programs in x16emu, as
65C02 code and as 65816 code: there the program is in native mode when it
goes through JSRFAR, and the 16-bit runs are in the overlays as anywhere.

## The Z80

A beginning (`src/genz80.p8`).  A Z80 machine is a target with `cpu = z80`
in its target file; `cpm` is the first (`lib/targets/cpm`).  `-target cpm`
writes assembly for z88dk's z80asm and has it made into a CP/M program;
`-run` starts it in tnylpo.  `-target llvm16 -triple z80-cpm`, as
prog8c-llvm spells it, names the same target unless `-llvm` asks for the
LLVM IR: llvm16 itself stays the target that LLVM IR is written for.

What is the machine's and not the CPU's is in the target file: the load
address, the program's extension and format, the first instructions (where
the stack is), how the program ends, the console (a character out, a key
without waiting, a character in: three routines of a few lines) and what
`-run` runs.  The generator has nothing of CP/M in it.  `trs80` is the
second machine: the TRS-80 Model I and III, whose console and keys are ROM
calls, and whose program is a command file that the driver makes of the
assembler's plain image (`cmd_file`: load records, then the start
address).  A Z80 target's own directory is searched for modules before the
library it names (`importer.own_library`), so `trs80` has a `textio` of
its own (the 64 by 16 screen at $3c00, the ROM's cursor address) and
`cpm` one whose keys go through the target's routines.

A program with floats left the TRS-80's DOS damaged, in two ways.  The DOS
calls a program on its own stack, which is small, and the float routines
overran it (103 bytes of the DOS's variables changed), so the target gives
the program a stack of its own (`stack_size`).  And zcc's first
instructions take a command line where HL points at the start and put a 0
at its end; trs80gp starts a program with HL at a byte of the DOS's own,
which that 0 broke.  The target's `zcc_init` lines, which go into zcc's
section `code_crt_init`, give zcc's code an empty line of the program's own
(prog8c-llvm's TRS-80 profiles do the same in a startup source).  A program
ends as the target file says whether zcc linked it or not: zcc's own last
instructions leave the cursor at the top of the screen.  `make trs80dos`
types DIR after a program with floats and one without, and looks for the
directory on the screen that trs80gp saves.

One target serves the Model I and the Model III: they share the ROM calls
and the DOS's "ready" entry.  TRSDOS 1.3 on the Model III starts a program
with its stack in the system's memory, which zcc's first instructions would
overwrite, so the target's `zcc_init` lines move the stack to the
program's own before anything else.  `make trs80cmp3` is the comparison on
a Model III, with TRSDOS 1.3 and with LDOS: 65 the same, none different,
each.

`trs80m4` is the Model 4 in its own mode: programs at $3000, an 80 by 24
screen, and everything through the DOS's supervisor calls (`rst $28`).  Its
`textio` is the first library module with Z80 assembly: `%asm` on a Z80
machine is written into the program as it stands, and names variables as
the generator does (`_txt__plot__col`: two underscores for each dot, so that `main.page_lines` and `main.page.lines` stay apart); an `asmsub` is not possible yet,
because its register names are the 6502's.  z88dk has no Model 4 platform,
so a program with floats is linked for its TRS-80 one without the DOS
library (as prog8c-llvm's profile does).  `make trs80cmp4`: 65 the same,
none different.  `make trs80screen` runs the screen routines (a character
put and read back, the cursor moved and asked for) on the three models.

`make trs80cmp` is `make z80cmp` for the TRS-80: the programs are built
with `tests/z80/trs80gp.properties`, a variant of the target whose console
also writes to the printer and whose end tells the emulator to stop, and
run in trs80gp by `tests/trs80run.sh`, which prints the emulator's printer
file.  65 the same, none different.

For the front end and the IR a Z80 machine follows llvm16's rules
(`importer.family`): 16-bit addresses, register numbers used again in
every subroutine, no 6502 conventions.  Its library is `lib/targets/z80`,
which began as llvm16's modules and whose most used routines are Z80
assembly now (the digits of numbers in `conv`: one routine of about 60
bytes for every size, where the Prog8 ones came to 300, 645 and 711; the
library's README there says how assembly in a module is written): Prog8 code, and `%ir` blocks whose system calls are
what the machine has to do.  The generator turns those into instructions
with `irparse.expand` and lowers them like the rest.

Every IR register has a place in memory (`p8r_S_N`, S the subroutine:
register numbers are used again from one subroutine to the next); an
instruction takes its
operands from there into A, or HL and DE, works, and puts the result back.
A call stores its arguments in the subroutine's parameter variables and
takes a result from A or HL (a long: DE and HL, HL the low half).  Up to
three arguments stay in registers: from the last parameter back, the first
byte in A, the first word in HL, the next word in DE.  Such a subroutine
has a second way in, `p8e_name`, with the stores above its name, so they
are there once and not at every call (`param_register`).  A byte result is
also put in L only in a program that has a call through a pointer
somewhere, whose caller takes HL.  The name itself stays
the way in for whatever has stored all the arguments: a jump, a call
through a pointer, assembly.  (Not with `-noopt`.)  The IR's carry after a compare is the 6502's
(clear for "less"), the Z80's is the other way round, so a branch on the
carry looks at what set it.  System calls 2 and 3 (a character, a string)
go to CP/M's BDOS.  An instruction that is not written yet is an error that
names it: the system calls of the llvm targets' file routines, which the
Z80 machines do not use.

An `extsub` without an address is a routine of z88dk's C library, called by
its own name with an underscore (`c_call`): the arguments on the stack as
words, the first one first, taken off again after the call, and the result
in HL, as the library's routines are called from C.  A program with such a
call is linked by `zcc` like one with floats (`linked()`); `-Xlink` adds
options to that link (a heap for `malloc`).

The wait, the clock and the command line are routines of the target file
(`wait_jiffy`, `ticks`, `command_line`); the generator's part is the same
for every machine: the loop over 60ths of a second, and the arguments,
which it counts and copies out of the line the target gives.  The I/O
ports (`sys.inp`, `sys.outp`) are the Z80's own instructions.  Files are
not system calls here but a module of the target's library: `diskio` for
CP/M is Prog8 with one routine of assembly, the call of the BDOS, and
keeps a record of 128 bytes for the file that is read and one for the file
that is written.  `make z80sys` runs the command line and the files in
tnylpo against what they must print.

On the TRS-80 the file routines are one module for all its DOSes
(`lib/targets/z80/shared_trsdos_diskio.p8`), byte by byte through the DOS,
which keeps a file's exact length; the target's own `diskio` has only the
calls: addresses in the DOS and the ROM for the Model I and III, supervisor
calls for the Model 4.  A rename is a copy and a delete, since no call does
it on all of them, and the directory is the DOS's own DIR command.  The
command line is where HL points when the DOS starts the program: the first
instructions keep it (`startup_code`; in a program that zcc links,
`zcc_init` takes it from zcc's own first instruction), and the target's
`command_line` routine copies it, if it is one.  trs80gp starts a program
without a command line, so `make trs80sys` tests the arguments by setting
that HL itself; what a DOS really passes has not been run.

A float is a 32-bit IEEE one in four bytes; loads, stores and moves are
those of a long.  The arithmetic is z88dk's math32 library's (the left
operand on the stack, the right one in DE and HL, the result there), and so
are the conversions and the functions.  Three things come from a C source
that is linked along (`lib/targets/z80/z80-float.c`, which the Z80 machines
share; from prog8c-llvm's z80 profiles): the shortest digits of a float, reading one,
and rounding to even.  The library's square root can be off in the last
place (3.2500002 for 10.5625), so one step of Heron's method follows it.
A float constant's bits are worked out by the compiler (`float_bits`).

A program with floats is therefore not assembled as it is but linked by
z88dk's `zcc` for the machine (`zcc_platform` in the target file, with
`--math32`): it is a module with a `_main` that zcc's own first
instructions call, and it names what it takes from the library.  The body
is written first and the head after it, because only the body tells which
of the two the program is.  A program without floats is as before: one
assembly file with its own first instructions, made into the program by
z80asm alone.

The system calls that are there: the end of the program, a character and a
string out, a character and a key in (BDOS functions 1 and 6), copying and
filling memory, and the builtin functions that the IR leaves to the back
end (comparing strings, "is in" for a string and for arrays of bytes and
words, clamp for bytes and words).  Each is a small routine (`p8rt_...`)
that is written into the program when it is used; so is the square root, a
routine of whole numbers for a long (a byte or a word is made one).

The IR's carry is its own flag: only a compare, clc, sec and the shifts and
rotations by one bit change it, and roxl, roxr, bstcc and bstcs read it.
Mostly the reader comes straight after what set it and the Z80's carry
serves.  A subroutine where it does not (`carry_scan`; the library's string
hash rotates a byte around a loop) keeps the flag in a byte of its own,
clear at its start as on the host, stored by every instruction that sets it
and fetched by a reader that does not have it at hand.

### The pass over the assembly (`peepz80.p8`)

The generator writes each instruction by itself, so nearly every value
makes a trip through its IR register's place in memory.  After a
subroutine is written, `peepz80` reads its lines and takes most of those
trips out.  It follows only the places of IR registers (`p8r_S_N`): they
belong to one subroutine, are never reached through a pointer and are no
machine's memory-mapped anything, so what a register holds of one stays
true until a line the pass can see changes it.  A label, a call, and any
instruction it does not know forget everything; `%asm` of the program's own
is between two marker lines and is left alone.

- What A, HL and DE hold: a load of what is there already is dropped, or
  becomes a move between registers (`ld a,l`, `ex de,hl`).
- A value on its way through a place (`ld hl,S / ld (C),hl ... ld hl,(C)`):
  the later load takes S itself, when S is a constant or an ordinary
  variable that nothing between stores to.  Memory-mapped variables, whose
  names the generator hands over, are never treated so.
- A byte made a word through its place and then taken into DE or HL goes
  there while A still has it.
- A store that another store to the same place follows before any read is
  dropped (a byte store does not replace a word store: that was a fault of
  the first version, which the test programs caught), and so is every
  store to a place that no line reads any more, a load that another load
  of the same register follows at once, and whatever comes after a jump or
  return without a condition, up to the next label.

The rounds repeat until one changes nothing, since a dropped store frees a
register and a kept value saves a load.  `-noopt` turns the pass off.

In the generator itself: words are moved as words (arguments of calls,
copies, constants into memory), and a byte's arithmetic and compare with a
constant have the constant as their operand.

The variables without values and the places of the IR registers are not in
the program's file: they are names for addresses after its end, memory
that the first instructions clear.  (In a program that zcc links, the
memory after this module is another module's, so there they are in z88dk's
section for such memory, `bss_user`.)  Only the IR registers whose places
are still named once the pass has run get one (`still_named`): in a large
program most are not, and they were 6,490 bytes of a 128K editor that did
not fit its machine with them.

The pass also follows ordinary variables in A, HL and DE (a store through
a pointer or a call forgets them; memory-mapped ones are never followed),
and makes a jump to a label within 30 lines the short one: no instruction
the generator writes is longer than four bytes, so that is in reach
whatever the lines are.

A label of the compiler's own that only jumps above it name is not the end
of what is known: the registers hold there what they held at every one of
those jumps and, when the code above runs into it, there too (`joined`).
That is the end of an `if` with an `else`, and of a condition made into a
value, whose two stores and one load of a place become nothing.  And
`ld a,0` is `xor a` where no line reads the flags before they are set again,
and a test whose flags nobody reads is dropped (`zero_loads`, `dead_after`).
A load of A, HL or DE that only loads of other things follow before it is
loaded again is dropped too (`dead_loads_far`).

More in the generator: an element of a word array has its index doubled in
HL (`add hl,hl`), a word goes through a pointer by way of HL or DE and not
a byte at a time, and a byte against 0 is `or a`.  A multiplication by a constant is doubling and
adding from the constant's top bit down; a word is shifted in HL; word
logic with a constant touches only the bytes the constant changes; a word
against 0 is `ld a,h / or l`; the flags of a word's increment are made
only when a branch reads them; long addition, subtraction and logic walk
two pointers.  A long sum or difference is two word additions with the
carry between them.  The long multiplication is made of 16-bit products
in registers (the low words give 32 bits; a high word that is not zero
adds its product with the other's low word to the top), and the long
division by a 16-bit divisor, which most are, is two 16-step divisions in
registers, the high word first.  Only a wider divisor takes the routine
that works in memory, which moves the dividend up a byte at a time while
its top byte is empty.  And the pass sees the two halves of a long in an
IR register's place as two places, so a long's way through such a place
is taken out like a word's.

Measured on CP/M programs, bytes without and with all of this: the string
routines' test 10,263 and 4,694; long arithmetic 4,564 and 3,200;
fromtests 4,469 and 2,975; fromdocs_builtins 3,362 and 1,821; hello 138
and 80.  `make z80bench` times a sieve, a word loop and a long loop in
tnylpo: 2.6 seconds, in 1,838 bytes.  prog8c-llvm's build of the same
program takes 2.8 seconds and is 16,479 bytes.  (The word and long loops
start from a number that is read from memory and feed each result into
the next run: an earlier form of the program had loops that llvm worked
out while compiling, which made its build look five times faster than it
is.  Part by part: the sieve 0.58 seconds here and 0.64 there, the word
loop 1.37 and 1.51, the long loop 0.73 and 0.73.)

The IR's hardware register slots are places in memory here (`p8_slot_N`).
A subroutine with several results stores them there before it returns, and
the caller loads them; a call through a pointer leaves HL
in slot 10, where the code after it looks, and a byte is returned in A and
in L for that.

Longs are worked byte by byte through A (addition, subtraction, logic,
shifts, compares: a long compare leaves carry and zero as a short one does).
Multiplication and division of longs are routines (`p8rt_mul32`,
`p8rt_div32`, `p8rt_divs32`) with their operands in three cells; signed
division of bytes and words is `p8rt_divs16` around the unsigned one.  All
of them are written into the program only when it uses them.  A branch on
zero or on the sign tests the register again unless a compare came before:
the Z80's 16-bit additions and its loads leave no such flags.

A subroutine's variables and registers are in fixed places, as on the 6502.
A subroutine that calls itself, straight or by way of others, would lose
them, where the host and prog8c-llvm's Z80 code keep them on the stack; and
programs are written for that (an editor's `out_dec` that prints a number's
digits by calling itself).  So the generator works out which subroutine's
code can come to call which (`call_graph`: the calls in the instructions,
then everything that follows from them; a call through a pointer is not
followed), and a call whose callee can come back into the caller is wrapped
(`save_own`, `restore_own`): the caller's single-value variables and the
places of every IR register it names go on the stack before the arguments
are stored, and come back after the result is taken (the register of the
result is left out).  A subroutine that no call can come back into is as
before.

`make z80cmp` builds the test programs for the host and for CP/M and
compares what they print; a program the generator cannot build yet is
counted.  At the start: 19 the same, none different, 49 not built; with longs, signed
division and structs: 43 the same, 25 not built; with the slots: 47 and 20; with the
system calls: 58, and the 9 not built all use floats; with floats all build
and 65 are the same.  `make z80ref` builds each program for CP/M with
prog8c-llvm too (llvm-z80 and z88dk) and compares the two in tnylpo: 69 the
same, none different, with two left out (the recursion above, and an
address that prog8c-llvm gets wrong for CP/M).  The
library's virtual registers r0-r15, which it puts at addresses from $ff0000
for the back end to place, are 32 bytes of the program's own.

## The 6809

A beginning (`src/gen6809.p8`), put together as the Z80 generator is.  A
6809 machine is a target with `cpu = 6809` in its target file: `sim6809` (a
bare 6809 as usim09batch simulates it, the machine of the tests), `coco2`
and `coco3` (the Color Computers).  The generator writes assembly for lwasm
of lwtools, which makes the program in the format the target names: an
Intel hex file for the simulator, a DECB file for `LOADM` on the Color
Computer.  For the front end and the IR such a machine follows llvm16's
rules, as a Z80 machine does (`importer.z80` is set for both), and its
library is `lib/targets/m6809`, llvm16's modules: Prog8, with `%ir` blocks
for what the machine has to do.

Every IR register has a place in memory (`p8r_S_N`, as wide as its type).
An instruction takes its first operand from there into B (a byte) or D (a
word), works with the second one straight from memory or as an immediate
(`addd`, `cmpd`, `andb` take either), and puts the result back.  X holds
addresses: an indexed load is `ldx #array`, the index added with `abx` (a
byte, which that instruction takes as unsigned) or `leax d,x`, and a load
through a pointer is `ldx` and an offset in the instruction.  Shifts, `inc`,
`dec`, `neg`, `com` and `clr` work on memory itself.  A long is two words.
What that leaves of needless traffic a pass over the assembly takes out
(below).

The 6809 has the high byte of a word first.  The generator names a place by
the number of a byte counted from the low end and the width that is wanted
(`cell(r, k, w)`, `op_mem`), and the offset follows from the size of the
whole; nothing else in it knows the byte order.  The front end and the IR
do not depend on it (the 68000 is the same way round), but a program can
see it: a word that is poked and its bytes peeked.  One line of the
conformance programs shows that, and `tests/m6809/functions.out` is what a
6809 must print there.  The low byte of one of the library's virtual
registers (`cx16.r0L`, at the made-up address of `r0`) is the second of its
two bytes here.

Branches are written in their short form, and at the end
`peep6809.branches` makes those long whose label is not in reach: it adds
up the most bytes that each instruction between can be, from how it is
written (`most_bytes`), and takes the short form up to 127 of them, with
nothing but instructions between.  lwasm's own choice (`pragma
autobranchlength`) takes the long form for every branch forward.  A branch
in `%asm` is left as it is written.  The IR's carry is handled as on the
Z80: after a compare the 6809's is the other way round than the IR's, and a
subroutine where a reader does not come straight after what set it keeps the
flag in a byte of its own.  Loads and stores leave the carry alone.  The
signed compares are the CPU's own branches (`bgt`, `blt`, `bge`, `ble`); a
signed long compare decides by the high words unless they are the same.

A call stores its arguments in the subroutine's parameter variables; up to
three stay in registers (from the last parameter back: the first byte in B,
the first word in X, the next in U), and such a subroutine has a second way
in, `p8e_name`, where they are stored.  A result is in B, D, or X and D (a
long, D the low half): a byte is the low half of a word, so a call through
a pointer needs nothing special.  Recursion is handled as on the Z80: a
call that can come back into the calling subroutine saves its variables and
register places on the stack around it.

The multiplication of bytes is the CPU's `mul`; of words, three of them.
Division, the long routines, the square root and the routines of the system
calls (`p8rt_...`) are written into the program when it uses them.  Clamping
a byte or a word is inline.  The first instructions keep the stack pointer,
and the end restores it: on the Color Computer the program returns to
BASIC with `rts` from wherever `sys.exit` was called.

`%asm` is written into the program as it stands, and names variables as on
the Z80 (`_txt__plot__col`).

An `asmsub` and an `extsub` at an address name the 6809's own registers: A
and B for a byte, D (which is A and B), X, Y and U for a word, `Pc` for the
carry, and the library's virtual registers.  The checker knows them on a
6809 machine (`m6809_registers`; `importer.m6809`), and the IR has slots for
them (40 to 45).  A call puts the carry first (no load after it changes
it), then what goes through memory, then the registers, and `jsr`s the name
or the address.  The values come back from the registers; a carry that is
a value is rotated into B here, and the two instructions with which the IR
would do that are skipped (its load of 0 would be a `clr`, which clears
the carry).  A flag that is returned for a branch stays through the stores
of the other values (`pshs cc`).  An `asmsub`'s text is written as it
stands under its name; one declared `inline` gets the `rts` it does not
have and is called like the others.  `tests/m6809/asmsub.p8` runs them;
`tests/bad_m6809.p8` is what the checker refuses.

Files on the Color Computer are a module of the library, `diskio`
(`shared_coco_diskio`, for both machines): Disk BASIC's files, read and
written by the module itself.  It knows the disk as RS-DOS lays it out (the
directory on track 17, a file a chain of granules of nine sectors in the
table in that track's second sector, the bytes of the last sector in the
entry) and calls one routine of the ROM, DSKCON through its vector at
$c004, for a sector; Disk BASIC's own file routines have no entries that
stay where they are from one version to the next.  A file's length is exact.
`f_seek` walks the file's chain to the granule of the place.  The files of
a drive are listed one at a time (`lf_start_list`, `lf_next_entry`), with a
pattern of `*` and `?` at will; each entry reads the directory's sector
again, so the file routines can be called between two of them.
The table is written when a file is closed.  Disk BASIC keeps a copy of a
disk's table in memory only while it has files open on it, so after a
program that was started from the prompt it reads the table again.  `make
cocosys` runs `tests/cocosys/files.p8` and `lists.p8` in XRoar with a disk image that
toolshed's `decb` made, and has `decb` read the disk afterwards (its
directory, the files' bytes); Disk BASIC's own `DIR`, `FREE` and `LINE
INPUT` were tried on such a disk by hand.  Loading at $0e00 leaves Disk
BASIC's memory, which ends below it, alone.

Floats on a 6809 machine are those of the BASIC in its ROM: five bytes in
Microsoft's format (the 6502 machines' format, so the front end's float is
five bytes here too: `types.FLOAT_SIZE` under `importer.m6809`), and the
ROM's routines, through its accumulator, with the other number's address in
X.  The generator knows what the routines do and not where they are: the
target file has their addresses and the accumulator's (`float_...`), since
the Color Computer's and the Dragon's BASIC have the same routines at
different places; a target without those keys has no floats (`sim6809`: the
instruction is an error that says so).  A load, a store and a move are five
bytes copied; a constant is five immediate bytes.  `first op second` puts
the second into the accumulator and gives the routine the first's address:
the ROM's subtraction and division are "the number at X by the
accumulator".  A float result of a subroutine is in the accumulator.  The
conversions: a signed word is the ROM's own entry; an unsigned word and a
long are put into the accumulator's bytes as a whole number with an
exponent of 16 or 32 and normalized by the ROM, the carry saying that it is
not negative; a float becomes a long with the ROM's routine for it, which
goes down, so it gets the number without its sign and the long is turned
over after it (towards zero, as a cast is).  `floor` is the ROM's, `ceil`
is it with the sign turned over, `round` is a half more and down (a half
goes up, not to the even one), `log2` is the natural logarithm times a
constant, and the power is the ROM's routine behind its `^`.  The ROM's
errors are BASIC's: a division by zero or a number too large ends the
program with BASIC's message.  The `floats` module (`shared_coco_floats`)
is the llvm16 one with the two routines of its own that need the ROM:
`tostr` is BASIC's number-to-text (so a float prints as BASIC prints it,
`.5` and `3`), `parse` its text-to-number.

The addresses were read off a disassembly of Color BASIC 1.3 and Extended
BASIC 1.1; Color BASIC 1.2 differs from 1.3 in 11 bytes elsewhere, and the
Color Computer 3's ROM has the same code at these places (its differences
are in the first bytes and in its patches).  `make cococmp` runs the
programs with floats too: where one prints floats, `tests/floatsame.py`
compares its output with the host's number by number, to seven digits.  72
the same on XRoar's Color Computer 2 and 3.

`dragon32` and `dragon64` are the Dragons: the Color Computer's sisters,
with the same screen and the same Microsoft BASIC at other addresses.  Their
target file is `coco2`'s with the program written as a DragonDOS binary
(lwasm's `dragon` format), the keys through the ROM's jump at $8006, and
the float routines where the Dragon 32's ROM has them: each was found by
the bytes of the Color Computer's routine (most are byte for byte the same
for 16 bytes; the square root, the power and the trigonometric ones, which
begin with addresses, by the closest match and then read in a disassembly:
the Dragon's cosine and square root begin a few bytes before what matched).
The Dragon 64's first ROM has them at the same places.  `floats` is the
Color Computers' module with the four addresses it has itself changed
(`shared_dragon_floats`).  There is no `diskio`: DragonDOS is another
system.  `make dragoncmp`: 72 programs the same as on the host on XRoar's
Dragon 32 and on its Dragon 64, the ones with floats among them; keys were
tried with a script of key presses.

The upper 32 KB of a 64 KB Color Computer 1 or 2 or Dragon 64 is memory for
data (the user's choice of the two ways to use it): the `highram` module
(`shared_sam_highram`).  The program stays below $8000 with the ROMs on, so
the keys, the floats and the disk work as ever; `get`, `put`, `getbyte`,
`setbyte`, `fill` and `move` switch the RAM in at the SAM ($ffdf) for the
moment of the access, with interrupts off, since BASIC's interrupt routine
is in the ROM, and the ROMs back on ($ffde).  `present()` changes a byte up
there and reads it back, and looks that the lower half did not change with
it.  `make cocosys` runs it with 64 KB and with 32 KB, and on XRoar's
Dragon 64 and Dragon 32.

The Color Computer 3 has a `highram` module of its own (`shared_coco3_highram`),
with the same routines over a long address: its memory is blocks of 8 KB,
eight of them in the processor's 64 KB at a time by the registers at $ffa0,
and BASIC, which runs from RAM there, has blocks $38 to $3f.  The module
takes blocks $00 to $2f of a 512 KB machine (384 KB) and, with 128 KB,
blocks $30 to $35 (48 KB), which are BASIC's high resolution graphics
screen and what belongs to it.  It finds out which by writing to block $00
and looking whether block $30 changed (with 128 KB a block's number counts
four bits).  A routine puts the blocks it needs at $a000 and $c000 for the
moment, with interrupts off, and BASIC's back; a copy or a move goes in
pieces that end where a block does, a move downwards from the ends.  `make
cocosys` runs `tests/cocosys/blocks.p8` in XRoar with 128 KB and with
512 KB.

`coco2ram` is the other way to use that memory: the program runs with the
ROMs switched out.  It came from porting the user's editor: with its simple
text store the program is 25 KB and has no room for text below the ROMs, and
with its paged store over `highram` it is 33 KB (30 KB with every optional
feature off), which does not fit below them at all.  The target file has
`rom_out` and `rom_in` (the SAM's two addresses) and `rom_start`; with them
the generator switches the ROMs out after the target's first instructions
and in again at the end, and a call into the ROM is a call of a few
instructions of the program's own, one set for each routine (`p8rom_N`:
`jsr p8_rom_in`, the call, `jmp p8_rom_out`).  The two routines switch with
interrupts off for the moment of it and with the flags as they were, since
a routine takes and gives values in them, and count in `p8_rom_on` that the
ROMs are in.  Which calls: the generator's own of the float routines, a call
of an `extsub` at an address, and in assembly (the target file's, the
library's, the program's) a `jsr` of an address from `rom_start` on, or one
with the comment `;rom` (`rom_line`): so `diskio` and `floats` are as they
were, but for two places that read the ROM or call BASIC's character
routine in low memory, which carry the comment.  The program, its variables
and its stack (BASIC's) stay below $8000, where LOADM puts the program and
where the ROM's routines find what they work on; $8000-$feff is plain
memory.  The interrupts are the target's business: its first instructions
look whether there is RAM under the ROMs (without it the program returns to
BASIC) and put a routine of the target's in place of BASIC's interrupt
routine, which is in the ROM.  That routine switches the ROMs in and gives
BASIC's a made-up interrupt frame to return through, to where the ROMs go
out again; when the interrupt came during a call into the ROM it is
BASIC's as it is.  So the clock, the waits and the disk drive's motor work.
`make cocoramcmp`: 72 programs the same as on the host; `make cocosys` runs
the clock, the memory and the file test on it.

`coco3ram` is the same for the Color Computer 3, which has no ROMs to
switch (BASIC runs from RAM there): `rom_out` puts memory blocks $30 to
$33 at $8000-$ffff in place of BASIC's $3c to $3f, `rom_in` the reverse,
both keeping A.  The page at $fe00, where the interrupts come in, is
BASIC's whatever block is there, so the program has $8000-$fdff.  The
screen's routines, which put the screen's block at $e000 for a moment, put
back the block named in `p8_top_block` (a cell of the target's:
BASIC's on `coco3`, the program's here), and the `highram` module puts back
the blocks it found.  It came from porting the user's editor to the 80
column screen: with its page store over `highram` the editor is 35 KB of
code and does not fit below BASIC's stack, so the port is the gap buffer in
this memory, as on the Color Computer 2.

Even so the program was 1.5 KB too long, and the generator learned to put
variables into that memory (`upper_variables`, `upper_variables_end`,
`lower_blocks` in the target file).  What goes up: the places of the IR's
registers that are not a float's, the carry cells, and the variables without
values that are not floats, structs, slabs or of a block that the target
names, in their order, as long as they fit.  What must stay below is what a
routine of BASIC's is given the address of: a float (the accumulator's
routines take X), a sector's buffer (`diskio`), and the variables of the
modules that change the blocks themselves.  On `coco3ram` they go to
$8000-$9fff, the one block that `highram` never changes.  They are written
after an `org` at the end of the assembly (only `rmb`, so the file has no
bytes there), cleared at the start after `rom_out`, and `sys.upperstart()`
is the first address after them.  The editor's variables below went from
3.5 KB to 1.5 KB; with every feature on it ends 478 bytes before the limit
and has 30 KB for text.  On `coco2ram` it is there with `-varshigh 0`,
upstream's option for variables in a machine's high memory (the number, a
bank on the X16, means nothing here), and the target file says where with
the 6502 machines' keys (`bss_highram_start`, `bss_highram_end`): without
the option a program takes $8000 as the start of its memory, as before.
With it the editor's Color Computer 2 build ends at $7948 with every
feature on (marks and the z commands were left out for room before), and
its test build, which ended above the limit at $7ec1, at $7992.  `make coco3ramcmp`: 72
programs the same as on the host, on the 80 column screen; `make cocosys`
runs `tests/cocosys/ownblocks.p8`.

Code goes into that memory too on `coco3ram` when the program is too long
for the memory below (`high_code_end`, `high_loader` in the target file).
Two things had to be solved: which code, and how it gets there.

Which: a block of the program is a piece that can move, unless the target
keeps it below (`lower_blocks` again: the modules whose assembly changes
the memory blocks).  The first instructions with the interrupt routine, the
generator's own routines, the instructions around the calls into the ROM
and every variable with a value stay below, so what BASIC's routines are
given the address of is still where they see it, and a call into the ROM
from code above goes through instructions below.  The generator cannot
know the sizes, so `main.p8` has lwasm assemble the program once without
a file (`--no-output --symbol-dump`, with `p8_measure` defined, which
leaves the check of `memory_end` out): every piece has a label at its
start and its end.  When all of it ends before `memory_end`, that is the
program.  Else `gen6809.place` chooses pieces until the rest fits: the
smallest that is enough by itself, or else the largest, again and again,
each only if there is room above.  `compose` then writes the assembly
again from the same parts (the generator keeps them: the first lines, the
code with the pieces' places, the variables), with the chosen pieces after
the variables of the upper memory, and `p8_upper_end`, what
`sys.upperstart()` gives, after them.  A piece's size does not depend on
where it is: every call is a `jsr` of an address, and the branches were
made long or short from the lines between.

How it gets there: LOADM cannot load above $8000, where BASIC itself is
while it runs.  The first idea was records in the file that write the
block register, so that LOADM would load the upper part through a block
put at $4000.  LOADM reads every byte back after storing it (`sta ,x`,
`cmpa ,x+`, "IO ERROR" when they differ), and the two upper bits of a
block register are not defined when read: an emulator gives 0, a real
machine was reported to give bit 6 set.  So a file that works in the
emulator could fail on the machine, and that way was dropped.  Instead
`main.decb_upper` takes the records for addresses from `rom_start` on out
of lwasm's file and puts them after the record that ends it, where LOADM
does not look, each as a length, an address and its bytes, and a length of
0 last.  The program's first instructions (`high_loader`, 330 bytes of
assembly in the target file, written only when a piece is above) read
them: the name and the drive are the ones Disk BASIC used last ($094c,
$eb), which are the program's own right after LOADM; they read the
directory and the allocation table with DSKCON, walk the records LOADM
read (only the sectors with a record's first bytes are read), and store
each byte of what follows through block register $ffa2 with interrupts
off.  A drive error or a file that is not found ends in BASIC's error
routine as "IO ERROR", before anything of BASIC's is changed.  It follows
that such a program is started from its file on a disk; a program that
fits is the file it always was.  `tests/cocosys/bigcode.p8` is 39 KB,
with two of its blocks above; `make cocosys` runs it from a disk with 128
KB and 512 KB (`COCO_FROM_DISK` of `tests/cocorun.sh`).  Only in XRoar so
far.

A target file's `base` may itself have a `base` (up to four deep, each
beside the one that names it): the tests' variant of `coco2ram` is made
from `coco2ram`, which is made from `coco2`.

The user's editor (p8vi) is the second real program: with a platform file
of its own for the Color Computer (written outside this repository, from
its TRS-80 one), built for `coco2ram` with its gap buffer in the upper 32
KB, it runs in XRoar and passes the 17 file suites of its own tests that
its TRS-80 Model III build runs (a harness made from its TRS-80 one: a disk
image by `decb`, the keys played from a file).

`-target llvm16 -triple mc6809-coco`, as prog8c-llvm spells it, names the
`coco2` target (and `mc6809-sim` names `sim6809`) unless `-llvm` asks for
the LLVM IR, as `z80-cpm` names `cpm`; `%address` and `-address` say where
the program loads.  So the command line of a build for prog8c-llvm's 6809
profile builds with p8c as it is.

Not there yet: a command line for the program.

The Color Computer's console is the target file's: a character goes into
the screen's memory at the address BASIC keeps as its cursor's ($88), in the
screen's own codes, so BASIC goes on where the program stopped; the keys are
the ROM's POLCAT through its vector; the clock is Extended BASIC's TIMER,
read until two reads agree, and a wait is `sync` until it changes (none
when interrupts are off, where it never would).  `textio` for both Color
Computers is one module in the shared library (`shared_coco_textio`).  The
program loads at $0e00, over Disk BASIC's graphics pages and program text.

`coco3` has the Color Computer 3's 40 and 80 column screens as well, on
whichever BASIC's WIDTH has on (`$e7`).  Such a screen is cells of two bytes,
the character and its attribute, in memory block $36, which is not among the
64 KB that a program sees; BASIC puts it at $2000 while it writes to it,
where a program loaded at $0e00 is.  The target's console routine and the
`textio` module (`coco3/textio.p8`, its own: `setchr`, `getchr`, `plot`,
the colors) put it at $e000 instead, for as long as they read or write it,
with interrupts off: BASIC's own code is there, which is not called
meanwhile, and the page from $fe00 with BASIC's cursor variables stays what
it is.  The cursor is BASIC's (its address as BASIC has the screen, column,
line), so BASIC goes on where the program stopped; the underline that BASIC
leaves at the cursor is taken away.  `txt.set_width(32, 40 or 80)` calls
the ROM's own WIDTH routines after their argument is read ($f652, $f65c,
$f679 in the Color Computer 3's ROM; its PAL ROM differs there in table
values only).  `make coco3screen` has a program write to the 80 column
screen and compares what is in block $36 of XRoar's snapshot afterwards;
`make coco3cmp` runs the test programs for the `coco3` target on the 32
column screen and again on the 80 column one (72 the same each).

`src/peep6809.p8` goes over each subroutine's lines (not with `-noopt`).
It follows what A, B, D and X hold of the register places, of constants
and of the program's variables, and drops a load of what is there already,
or makes it a move between D and X; a test of a byte that was just loaded
or stored goes too.  Where a place was given the value of a constant, a
variable or another place, what reads the place reads that instead.  Then
every store to a place goes that nothing reads, or that is written over
before anything can read it; then a load whose register is loaded again,
and `std P`, `ldd Q`, `addd P` becomes `addd Q`.  A call and a return are a
jump.  A load also sets the flags for the sign and for zero, so one is
dropped only where nothing can read them, or where the line before left the
same.  What is known of variables is forgotten at every write to memory
that is not a place (it may be through a pointer) and at every call and
label; a memory-mapped variable is not followed, and a place that stands
for a variable is read as the variable once, so the program reads its
variables as often as it did.  A store through X leaves what X is known to
hold of a variable: only a pointer that points at itself would be changed
by it.  Smaller things: a load of D before a call of one of the program's
subroutines that is only moved to X is a load of X; a compare of B with 0
before a branch on zero goes after an instruction that left B's flags;
a load of 0 is a clear where nothing takes the carry.  The generator writes
for it: a byte in a register is counted, negated and shifted through B, not
in its place, so that the pass can join the pieces; times, divided by and
the remainder by a constant power of two are shifts and a mask.

The library's most carried routines are 6809 assembly, as on the Z80: the
decimal and hexadecimal digits of numbers and the reading of numbers in
`conv`, and `length`, `ncopy` and `compare` in `strings`.

The user's game (its Color Computer build, which was written for
prog8c-llvm's 6809 profile) is the real program this was measured on: it
builds, loads with LOADM from a disk image, shows its title screen and
starts a level on Enter in XRoar.  12,662 bytes when it first built; 10,931
after the above; 10,155 with the pass run twice over each subroutine (what
the first round takes out lets the second see more), with what a place is
known to hold of a constant or another place kept through a call (the
places are the subroutine's own), and with a store to a variable by its name
forgetting that variable only.  prog8c-llvm's build is 10,090.

The test programs are about a quarter
smaller for the pass (the conformance program `functions`: 5626 bytes with
`-noopt`, 4121 without, both as Color Computer files; `-noopt` also passes
no parameters in registers).

`make m6809cmp` builds the test programs for the host and for `sim6809` and
compares what they print: 62 the same, none different; 9 need floats.
`make cococmp` does it for the Color Computer in XRoar, which runs without a
window as fast as the host can (`tests/cocorun.sh`): the tests' variant of
the target ends at a fixed address, where XRoar writes a snapshot and
stops, and what the program printed is read out of that.  62 the same on
XRoar's Color Computer 2 and on its 3.

## The 8086

A beginning (`src/gen8086.p8`), put together as the 6809 generator is.  An
8086 machine is a target with `cpu = 8086` in its target file: `dos`, an
MS-DOS `.COM` program.  The generator writes assembly for nasm (`cpu 8086`,
so nothing of a later processor gets in), which makes a flat file of it.
For the front end and the IR such a machine follows llvm16's rules, as the
Z80 and 6809 machines do (`importer.z80` is set for all three), and its
library is `lib/targets/i8086`, llvm16's modules.

The program is one segment of 64 KB: code, data and stack share it, every
address is 16 bits, and no segment register is ever changed.  That is a
`.COM` file as DOS loads it, at `$0100`, with the stack at the segment's
end.

Every IR register has a place in memory (`p8r_S_N`, as wide as its type).
An instruction on a register takes the place into AL or AX, works there
with the second operand straight from memory or as a constant, and puts
the result back; the pass over the assembly (below) joins that with what
is around it.  An instruction on a variable works on the memory itself, as
the 8086 can: `add word [name], 5`, `inc byte [name]`, or the second
operand through AL or AX when it is no constant.  A shift by more than one
bit goes through CL, as the 8086 has no other.  BX holds addresses: an
indexed load is the index in BX, shifted for the element's size, plus the
array's address, and a load through a pointer is `mov bx, [pointer]` and an
offset in the instruction.  A long is two words, the low one first, with
`adc` and `sbb` for the second.  Nothing is kept in a register from one IR
instruction to the next, so the target's routines and a program's own
assembly may change them all.

Products are `mul`.  Divisions go through two short routines
(`p8rt_div16`, `p8rt_divs16`) and not `div` itself, because the 8086 stops
the program with an interrupt when the divisor is 0 or the quotient does
not fit (-32768 / -1): the routines give what the other generators give.
Long products, quotients and square roots are routines over three cells
(`p8_la`, `p8_lb`, `p8_lc`), as on the 6809.

The carry is the 6809's story again: after a compare the 8086's is the
other way round than the IR's, a `mov` leaves it alone, and a subroutine
whose reader of the carry does not follow the setter keeps it in a place of
its own (`lahf` and `sahf` carry it there and back).  A branch on the
status after an instruction that left no flags (a `mov`) tests the
register's place first, as on the Z80.

A conditional jump of the 8086 reaches 127 bytes.  The generator writes
every one as it is, and `branches` goes over the finished text: each line
gets the most bytes it can be (`most_bytes`: two for an instruction, two
more for an address, two more for a constant; data and what is not known
count as far), and a conditional jump whose label may be further than 126
of those becomes the opposite jump around a `jmp`.  Every conditional jump
counts as the five bytes of that form, so one pass is enough.  `loop` and
`jcxz` have no opposite; the generator only writes them around a few
instructions.

A call puts its arguments into the subroutine's parameter variables; with
optimizing on, the last byte parameter comes in AL and the last two word
parameters in BX and CX, through a second way in (`p8e_name`) that stores
them.  A result comes back in AL, AX, or DX and AX.  Recursion is the other
generators': a call that can come back into the subroutine saves its
variables and register places on the stack around it (`push word [place]`).

The variables without values are not in the file: after the last byte of
data the assembly goes on with `absolute`, where names only get addresses,
and the program's first instructions clear that memory.  The last line is
one that the assembler refuses (`times` with a negative count) when the
program and its variables go beyond the target's `memory_end`.

`make doscmp` (`tests/doscmp.sh`) builds each test program for the host and
for `dos` and compares what they print.  DOSBox-X runs without a window
(SDL's dummy video driver), once for all programs: they are `P001.COM`,
`P002.COM` ... in one mounted directory, and a batch file runs each with
its output in a file and writes a mark after it.  A program that does not
end stops the emulator at the time limit; it is the first one without its
mark, is counted as different, and the rest is run again.

An `asmsub` and an `extsub` at an address name the 8086's own registers:
AL, AH, BL, BH, CL, CH, DL and DH for a byte, AX, BX, CX, DX, SI, DI and BP
for a word, and Pc for the carry.  The checker takes these names on an
8086 machine (`i8086_registers`; `importer.i8086`), and the IR has slots
for them (50 to 64).  A call loads what goes into variables first, then the
registers, then the carry (`cmp byte [place], 1` and `cmc`): a `mov`
changes no flag, so nothing needs saving.  The values come back with `mov`
too, and a carry that the program takes as a value is `mov al, 0` and
`adc al, 0`.  `tests/dos/asmsub.p8` runs them; `tests/bad_i8086.p8` is what
the checker refuses.

The `dos` target's console is in its target file.  The first instructions
ask DOS whether the program's output is the screen and its input the
keyboard (IOCTL on the handles 1 and 0).  To the screen a character goes
through the BIOS: written with the text's colours where the cursor is
(int $10, function 9) and once more as a teletype would write it (function
$0e), which moves the cursor and scrolls.  Redirected, it goes through DOS.
Keys come from int $16, where a key without a character has a scan code,
which becomes 128 plus that; redirected input comes through DOS.  `textio`
(`lib/targets/dos/textio.p8`) is small routines over int $10 with their
arguments in the registers the BIOS wants them in.  The command line is
the text at $81 of the program's segment: its blanks are made zeros once,
and an argument is where it stands there; argument 0 is the program's name
from behind the environment's strings.  `tests/dos/screen.p8` prints with
the screen switched on by hand and reads the cells back; `tests/dos/args.p8`
is started with `tests/dos/args.args`.

`src/peep8086.p8` goes over each subroutine's lines (not with `-noopt`),
three passes, twice over:

- `loads` follows what AX, BX, CX, DX, SI, DI and the low halves hold: a
  place, a variable by its name, or a constant.  A load of what the
  register holds is dropped.  An instruction that reads a place reads the
  register that holds it instead, or what the place was given (a
  constant where the instruction takes one, a variable or another place
  where its other operand is no memory); a place stands for a variable
  once only, so the program reads its variables as often as it did.  A
  write to named memory forgets what shares a byte with it (names with
  offsets are compared as ranges, so the halves of a long are apart); a
  write through a register or to an address forgets every variable; a
  call forgets the registers and the variables, and a label everything.
  Memory-mapped variables (`volatile`) are not followed.  A `mov` changes
  no flag on the 8086, so none of this needs to look at flags.
- `stores` drops a `mov` to a place that no line reads, or that the same
  store writes over before a jump, a label or a line that names it.
- `small`: what follows a `ret` or `jmp` up to a label; `call` and `ret` as
  `jmp`; a conditional jump over a `jmp` as the opposite jump; a load of a
  register that gets another value before anything reads it (the halves
  of AX may go one after the other: `mov al` and `xor ah, ah`); `mov ax, X`
  and `mov r, ax` as `mov r, X` when AX is loaded next; `mov P, ax`,
  `mov ax, Q`, `add ax, P` as `add ax, Q`; `cmp r, 0` dropped after the
  arithmetic that left r's flags and before a jump on zero, else written
  `test r, r`; `mov r, 0` as `xor r, r` where an instruction that sets all
  flags follows before anything can read them.

The places that are left get memory (`still_named`).  Sizes of the `.COM`
files without the pass and with it: divmix 2180 and 1359 bytes, functions
5084 and 3206, strlib 10302 and 5653.

The library then got what the 6809's has: the digits of numbers (`decimal`,
one routine for every size, with `div`; `hexadecimal`), the reading of
numbers (`str2uword`, `hex2uword`) and `strings.length`, `ncopy` and
`compare` as `asmsub`s with their arguments in registers.  And a routine in
assembly (`asmsub`) that nothing uses is left out on an 8086 machine, and
on a Z80 and a 6809 machine too (`irprune.asmsubs_kept` is false there, as
for the 6502): the names that
assembly uses are found in the form the generator writes them
(`irprune.mangled`: `_conv__string_out` is `conv.string_out`), so what
assembly alone names stays.  Before that every program carried all of
`textio`'s and `diskio`'s routines.  With both: divmix 903 bytes, functions
2300, strlib 3986 (the 6809's are 1123, 2808 and 4227).

`sys.wait` counts 60ths of a second on the timer chip's first counter (the
8253 that every PC has, read through ports $43 and $40).  The BIOS has it
count down by two, so a 60th is 39772 of what is read; the first call
looks at it 16 times, and where odd numbers come too it counts by one and
a 60th is 19886.  The first version waited for the screen's retrace bit,
which took no time at all in QEMU, whose bit flips at every look.

`diskio` (`lib/targets/dos/diskio.p8`) is DOS's file handles (int $21,
DOS 2.0 and later): each call is an `asmsub` with its arguments in the
registers DOS wants and the carry as a `bool` beside the value.  The file
that is read has 128 bytes read ahead, for `f_readline`; `f_read` empties
that and reads the rest straight into the caller's buffer.  The list of a
directory is find-first and find-next with a record of the module's own
(DOS's default one is where the command line is).  `tests/dos/files.p8`
runs it all in a directory that it makes and removes.

The `dosexe` target (`output_format = exe`) is the same program as an
`.EXE` file with two segments: the code, and the data with the stack at
its end.  The generator writes the file's 32-byte header itself and nasm
makes a flat file of three sections (the header, `.text` counted from 0,
`.data` on a paragraph), so there is no linker.  Nothing in the program
names a segment, so the header has no relocations: DOS starts the program
with CS at the code and SS at the data, both from the header, and the
first instructions copy SS to DS and ES.  Before that they take the
command line and the number of the environment's segment out of the
segment that DOS made for the program (`p8dos_tail`, `p8dos_env`; in a
`.COM` file these names are the addresses $80 and $2c).  The data's
addresses begin at 256, as a `.COM` file's do, so that no variable is at
an address that a program takes for none: the data's segment begins 16
paragraphs before the data.  Everything that is data is written after the
code: the variables with values, the target's own (`machine_cells`,
`arguments_data`).  A variable's alignment is bytes of padding counted
from the data's start, not the assembler's `align`, which would move the
whole section.  The code is checked against 64 KB and the data against
`memory_end`.  Assembly of a program's own that has bytes in the code and
reads them through DS is wrong there.

A float is an IEEE double, eight bytes, as the host's are and as an 8087
has them (`types.FLOAT_SIZE` is 8 under `importer.i8086`).  Loads, stores
and moves are four words, through SI and DI with `movsw`; a constant is
four `mov`s of its words (`float_words` takes them from the compiler's own
float).  Arithmetic is routines that work on the float that DI points at
with the one that SI points at: `p8f_add`, `p8f_sub`, `p8f_mul`, `p8f_div`,
`p8f_cmp` (AL = -1, 0 or 1), `p8f_from_long` and `p8f_to_long` (DX and AX,
towards zero), `p8f_sqrt`, `p8f_floor`, `p8f_ceil`, `p8f_round`.  A float
that a subroutine returns is in `floats.fac`, a constant operand in
`floats.operand`.  The pass over the assembly forgets everything at a call
of a `p8f_` routine: it writes where DI points, which may be a place.

The routines are assembly at the end of the library's `floats` module
(`lib/targets/i8086/floats.p8`), each written twice: with the 8087's
instructions, and without them.  The code generator's first line for a
program with floats is `%define p8f_mode`, from `-floats` on the command
line or else the target file's `floats` key: 0 for the 8087 alone, 1 for software alone, 2 (`auto`, the default)
for both; then each routine begins by looking at `floats.has87`, which
`p8f_init` sets when the program starts (after `fninit` the status word's
low byte reads 0 and the control word $03xx when an 8087 is there).  With
an 8087 the number is loaded, worked on and stored back each time, with
the control word set to round results as doubles: what a program
computes is then the same, bit for bit, as without one, and as on the
host.  Every 8087 instruction has `fwait` before it, which the 8087 itself
needs (the later ones do not).

Without the 8087 a float is taken apart into 64 bits of digits with the
first one at the top, an exponent and a sign (`p8fs_unpack`), and put
together again rounded to the nearest, a half to the even one
(`p8fs_pack`).  A sum shifts the smaller number right and keeps what
leaves as the lowest bit; a product is 16 products of words into 128
bits; a quotient is 64 steps of compare and subtract; a square root is six
rounds of Newton's method from a guess with half the exponent.  A number
too small for an exponent is zero (none of the denormal ones), and one too
large is infinity.  `p8f_floor` clears the bits after the point in the
float itself, for both kinds.

Everything else is Prog8 in the module, the same with and without the
8087: the digits of a number (it is brought between 1 and 10, then 16
digits are taken as two whole numbers of eight and rounded to 15), the
reading of one (its digits as a whole number, times or divided by a power
of ten, which is exact up to the 22nd), and `sin`, `cos`, `tan`, `atan`,
`ln`, `log2`, `exp` and `pow` as series after the argument is brought
into a small range.  The 8087's own instructions for those differ from
the later coprocessors' (it has no `fsin`), so they are not used.

`make doscmp` runs DOSBox-X as an 8086, where an instruction of a later
processor would stop a program; `make dossoftcmp` builds with `floats =
software`; `make dosnofpucmp` runs the programs with floats, built with
both kinds of routines, on a machine without an 8087.  A program with
floats prints 15 digits here and up to 17 on the host, so those are
compared number by number (`tests/floatsame.py`).

## Machines and the library

Nothing about a particular machine is in the compiler.  A 6502 machine is a
properties file in the format of the reference compiler's custom targets:
memory map, zero page, startup code.  The machines the reference compiler
has built in are such files too.

The library that programs are built with is a separate repository: the
reference compiler's standard library as it comes, and beside it the
machines and modules that are added and a few modules with bug fixes that
take the place of upstream's.  See [TARGETS.md](TARGETS.md).

## The program's map

`-map` writes `name.p8map` beside a program that one of p8p8's code
generators built: where every block, subroutine and variable is and how many
bytes it takes, in one form for every CPU (`src/sizemap.p8`).  It is for
tools; `tools/p8size.py` is the one that comes with p8p8.

The compiler does not know the addresses: the assembler does.  So each
assembler is asked for its list of symbols, and a reader for each puts them
in one table:

| Assembler | Its list | What the reader leaves out |
|---|---|---|
| 64tass | the label list (`--vice-labels`), which every build writes | |
| lwasm | `--symbol-dump` | the names that the assembly defines with `equ` (the dump does not tell a constant from a place) |
| z80asm, zcc | the map (`-m`) | what it calls `const` |
| vasm | the symbols at the end of the listing (`-L`), with their sections | expressions (`E:`) |

From there on it is the same work for all of them.  A name says what it is:
`p8b_block.p8s_sub.p8v_variable` in scopes for 64tass and vasm,
`_block__sub__variable` for the other two.  A label inside a routine is no
entry of its own (`p8l_`, `p8_label_gen_`, a third scope in a library block
that is written in assembly, `p8<block>_...` after a routine of that block
on the Z80 and the 6809).  What is left is put in the order of its
addresses, and the bytes of each are the distance to the next: so a
subroutine has the tables and strings that follow it, and every byte of the
program belongs to exactly one entry.  Names that only end something
(`prog8_program_end`, `p8_bss_end`) are not entries, which keeps a gap
between two parts of the memory from being counted.  For the 6502 the
generator writes two labels more when `-map` is given, around the variables
(`p8map_vars`, `p8map_vars_end`): they may be in memory of their own
(`-varshigh`), where nothing else says where they end.

What only the compiler knows is added: the target, the source file of each
block, where the program must end and how much is left, and the 6502's
variables in the zero page, which have no label of their own.

Lines of the map of `tests/mapcheck/sizes.p8`, built for the X16:

```
p8map 1
program sizes
target cx16
cpu 65c02
region image 0801 0aa7
region vars 0aa7 0b56
limit 9f00
free 37802
zp 002b 2 main counter
module main sizes.p8
code 0801 22 (runtime) prog8_program_start
code 082e 37 main start
code 0853 48 main start.inner
data 0a9b 6 main primes
var 0ab5 100 main table
```

- `region NAME START END`: `image` is the program's bytes, `vars` the
  variables without a value; `uppervars` and `upper` are the variables and
  the code above $8000 on `coco3ram`.  `END` is the first address after it.
- `relocatable` (the 68000): addresses are offsets in the section of the
  entry's kind, and the regions are `image`, `data` and `vars`.
- `limit` and `free`: the first address the program may not reach, and the
  bytes left before it.
- `code`, `data`, `var`, `zp`, then address, bytes, block and name.  The name
  is a subroutine (an inner one as `outer.inner`), a variable
  (`sub.variable`), or `-` for what is the block's own.  `data` is a variable
  with a value where the assembler's names show it (`p8v_`, the 68000's data
  section); elsewhere it is counted with the code.

`make mapcheck` builds test programs for all four CPUs (with the variables
in high memory, a program in two parts on `coco3ram`, one linked with
z88dk) and has `p8size --check` say of each map that its entries fill each
region to the byte with nothing of the wrong kind in it.

Not there: a program with overlays (its parts are assembled apart, at the
same addresses), and the targets that `prog8c-llvm` or clang build.

## How it is tested

p8p8 has a reference to be compared with, and nearly every test is such a
comparison:

- **The front end over a corpus:** every file of the standard library, the
  examples and the reference compiler's tests must parse, print back to the
  same tree, and load with its imports.
- **Self-hosting:** p8p8 compiled by itself must compile itself to
  identical output.
- **Same behaviour:** test programs built by both compilers must print the
  same, in the reference virtual machine, as native executables, and in
  emulators of the Commander X16 and the Commodore 64; programs that draw
  must draw the same.
- **The language, area by area:** `tests/conformance` has a program for
  each area of the language, with values neither compiler can know in
  advance, compared in all of those places.
- **Everything builds:** each example for the X16 and the C64.
- **Other hosts:** the compiler built on Linux and Windows must reproduce
  itself there.

Size and speed are measured on whole programs against the reference
compiler's output, not on fragments.

## Building itself

p8p8 is built from a **seed**: its own output for its own sources, as LLVM
IR (`seed/p8c.ll.gz`).  clang makes a first compiler of the seed, that one
compiles the sources, and clang makes `p8c` of the result.  No other Prog8
compiler is needed.  The IR for macOS and Linux differs only in two target
lines, which the seed leaves out, so it is one file for both.  For Windows
four functions of the C library have other names; `tools/build-windows.ps1`
renames them where the seed calls or declares them, which gives exactly the
IR the compiler writes for Windows, and builds from that.

Two things keep this honest:

- `make bootstrap`: `p8c` compiles itself again, and the result must be
  identical.
- `make seedcheck`: the reference compiler's LLVM branch builds p8p8 from
  the same sources, and that compiler and the one from the seed must write
  identical output, for the compiler's own sources and for the test programs
  through the 6502 code generator.  A compiler that only ever builds itself
  could carry a mistake along from seed to seed; the first compiler p8p8
  built of itself did have mistakes that this comparison found.

The seed is refreshed (`make seed`) when the compiler's sources start to
use something that the compiler in the old seed does not compile, and for
releases.  Because the sources must always be compilable by the seed, a new
language feature is first implemented, then the seed refreshed, and only
then used in the compiler's own sources.

## A 32-bit host

The compiler builds for llvm32 too, and runs there.  Two host layers lie
over llvm64's, each with only the modules that differ:

- `src/llvm32/`: a 32-bit hosted platform (Linux on ARM).  The C library's
  sizes are 32 bits wide; everything else is as on a 64-bit host.  Source
  directories `src:src/llvm32:src/llvm64`.
- `src/wasi32/`: WebAssembly with WASI, run by wasmtime.  There is nothing
  to run a command or catch a signal with, so this compiler checks programs
  and writes assembly, IR and LLVM IR, and cannot start 64tass or clang.
  Source directories `src:src/wasi32:src/llvm32:src/llvm64`.

On a 32-bit host a program is for that machine by default: llvm32, with the
machine's triple profile.

`make wasihost` builds the WebAssembly compiler and compares what it writes
with the native compiler's: its own source for llvm32 (it reproduces itself)
and for llvm64, and the 6502 assembly of the test programs and examples.
`tests/hostcmp.sh` compares programs on another machine; with `P8P8_CROSS`
they are built here for it and copied with rsync, for a machine without
clang.  `tests/hostbootstrap.sh` with `HOSTCMP_TARGET=llvm32` checks the compiler on a
32-bit machine reached by ssh; `P8P8_HOST_BINARY` gives it a compiler that
was cross-built here.

`make cross` builds the compiler for such a machine and packs it like
`make dist` does, with the library and the documents:

```
make cross TRIPLE=armv7-unknown-linux-gnueabihf SYSROOT=<the platform's sysroot>
```

It needs a clang that knows the platform and links with lld (`CROSS_CLANG`;
Homebrew's is taken where there is one), and writes
`dist/p8p8-<version>-<triple>.tar.gz`.  `CROSS_FLAGS=-static` links the C
library in, for a machine whose own is older than the sysroot's.

The seed is for 64-bit hosts.  The first compiler of a 32-bit machine is
built by a 64-bit one (`make cross`), or from its LLVM IR by the clang of
the 32-bit machine.  From then on the machine builds its own: there `make`
takes the p8c that is installed in place of the seed (`BOOT=p8c`), the
target is llvm32 and the host layer `src/llvm32`, and `make bootstrap`
checks the result as everywhere.  As with the seed, the installed compiler
must know everything the sources use.

The platform of an llvm32 program is not built into the compiler: it is a
triple profile, a properties file of the library (`src/triple.p8`,
[TARGETS.md](TARGETS.md)).  The generator takes the data layout, the name
of `main`, the layout of a directory entry and whether indirect calls are
typed from it, the driver the clang command.  The platforms of llvm64 and
llvm16 are still in `main.p8` and `llvmgen.p8`.

## Not done yet

- `make` and the test suites on Windows: there is the build script, and the
  compiler built on Windows is checked from another host (`make
  hostbootstrap`).
- The 65816 and the 45GS02; a Z80 code generator.
- In the 68000 code generator: registers for values that live across
  chunks, passes over its output, and structs whose fields are at odd
  addresses on a 68000.
- The reference compiler's optimizer has no counterpart in p8p8's front
  end; the 6502 passes and LLVM do that work on their side.
- A compiler that runs on an 8-bit machine.
