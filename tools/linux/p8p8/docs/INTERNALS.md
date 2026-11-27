# Inside p8p8

A tour of how the compiler works, for people who know Prog8 and are curious
how a compiler for it looks when it is written in it.  [DESIGN.md](DESIGN.md)
is the short version: what the parts are and why.  This document shows how
they do it, with real output.

Everything quoted here (listings, sizes, times) was produced while writing,
with the compiler as it was on 2026-11-13 (the commit after `c7f3c76`) and
the reference compiler `prog8c-llvm` v14.0-BETA3-llvm.1 at commit `e25b4c29`, on an Apple M3 Max.
The source moves on; where this document and the source disagree, the source
is right.

"Upstream" is the reference compiler, `prog8c`, and its library.  p8p8
follows it in what a program means and differs in how it gets there.  The
differences described below are differences, not improvements: upstream has
a real optimizer, a virtual machine, and years of programs behind it.

## 1. The shape of it

About 31,700 lines of Prog8 in 36 source files.  The larger ones:

| Module | Lines | What it is |
|---|---|---|
| `irgen.p8` | 6113 | syntax tree to IR |
| `gen6502.p8` | 4026 | IR to 6502 assembly |
| `llvmgen.p8` | 3779 | IR to LLVM IR |
| `gen68k.p8` | 1994 | IR to 68000 assembly (new: qemu68k, no floats) |
| `peep6502.p8` | 2920 | the passes over the 6502 assembly |
| `checker.p8` | 1860 | the errors |
| `typer.p8` | 1789 | types and constant folding |
| `parser.p8` | 1550 | recursive descent |
| `main.p8` | 1365 | the driver |
| `ir.p8` | 1349 | the IR's records and its text form |

Compiled by itself for the host it is a 680 KB executable.  It compiles its
own source to 14 MB of LLVM IR in 0.22 seconds (clang then needs 4.4 seconds
to optimize that), and builds upstream's `textelite.p8` (1029 lines plus the
library) for the C64, assembler included, in 0.02 seconds.  The reference
compiler needs 1.6 seconds for the same program when it is started for the
one run, which includes starting the Java virtual machine, and 0.62 seconds
through its `-daemon` mode once that is warm (the first run through the
daemon took 2.1 seconds and the times settled after about ten runs; 32 runs
were measured).

For its own source the compiler makes 222,000 tokens, 122,000 tree nodes and
153,000 allocations, 25 MB in all.

## 2. A compiler in Prog8: the idioms

Prog8 is a language for small machines.  A compiler wants trees, strings,
tables and recursion.  This is how the source gets them.

### Memory: allocate, never free

`mem.alloc(size)` hands out zeroed memory from large chunks by moving a
pointer.  Nothing is freed: the compiler is a batch job and ends.  That
removes every question of ownership, and it is fast.  The platform module
(`src/llvm64/mem_platform.p8`) only has to supply chunks, so a host without
`malloc` can supply its own.

### One record for every tree node

```
struct Node {
    ^^Node next         ; next node in the same list
    ^^Node a            ; child slots, see the kind
    ^^Node b
    ^^Node c
    ^^Node d
    ^^ubyte name        ; interned text, or 0
    pointer extra       ; free for later stages (symbol, type) or raw text
    quad value          ; literal value, length, or 0
    uword line
    uword col
    uword type          ; type id (types.p8) of an expression or declaration
    ubyte kind
    ubyte op            ; operator or type keyword token kind, or 0
    ubyte flags
    ubyte file          ; source file index
}
```

There are 64 kinds, and what `a` to `d` mean depends on the kind; `ast.p8`
says it in a comment at each constant:

```
const ubyte N_VARDECL = 3   ; op=declaration kind; a=type; b=initializer or 0;
                            ; c=name list of IDENT; d=TAG list
```

Prog8 has no tagged unions, so nothing checks that code looking at `n.b` has
a kind where `b` is what it expects.  This is the largest single source of
mistakes in the compiler (section 9), and the price of a tree that is 74
bytes a node and needs no accessor code.

A list is the `next` pointer.  An argument list, the statements of a block,
the names of a declaration are all chains through `next`, built with a
`first` and a `last` pointer.

### Text is never a Prog8 string

A `str` is static and at most 255 bytes.  The compiler's text is in two
places instead:

- **`buf.Buf`**, a growable byte buffer (`data`, `len`, `cap`): the output
  being written, a message being put together, a name being built.
- **`strtab`**, a hash table that interns text.  A name is interned once
  and from then on is a pointer; two names are equal when their pointers
  are.  The symbol table, the IR and the 6502 passes compare names without
  ever looking at the characters.

String literals in the compiler's own source are used where the text is
fixed: messages, mnemonics, keywords.  Finding a keyword or a builtin by
name is a loop over a `str[]` with `strings.compare`.

### Recursion

A parser, a type checker and a code generator are recursive.  On the host
target a subroutine's parameters and scalar variables that nothing takes the
address of are on the stack, so recursion works as in any language.  Arrays
and strings are not: a local array is one static area, shared by every
activation.  So the rule in the source is *scalars only* in anything that
recurses, and where a routine needs a list across a recursive call it builds
a linked one:

```
; the arguments first: all evaluated before the call.  The argument
; list is built as a linked list held in scalar locals, because this
; sub recurses through expression() and a local array would be shared
; with the nested call.
^^ir.Arg first = 0
^^ir.Arg last = 0
```

On a 6502 target every local is static, and this source would not survive
there as it is.  A compiler that runs on an 8-bit machine is a different
piece of work, not a recompile.

### Parallel arrays where records would cost too much

The 6502 passes look at every line of a subroutine many times.  A line is
not a record but an index into parallel arrays:

```
^^ubyte lkind = 0      ; instruction, label, raw text, dead
^^ubyte lmn = 0        ; the mnemonic, as a number
^^ubyte lok = 0        ; the kind of operand: #number, cell, variable, other
^^long lval = 0        ; its number
^^pointer lsym = 0     ; its interned name
```

Removing a line is `lkind[i] = L_DEAD`.  Nothing moves.

### Several results

Prog8's multiple return values carry a lot.  An expression in `irgen`
returns the register its value is in and that register's type:

```
rr, rt = binary(e)
```

### Portable types

An address is `pointer` or a typed pointer, never an integer of a width the
host happens to have.  The file, memory and process functions are in
`src/llvm64/*_platform.p8`, about 240 lines, as `extsub` declarations of the
C library's functions.

That this holds is tested: `make wasihost` builds the compiler for llvm32 as
WebAssembly (`src/llvm32/` and `src/wasi32/` have the host modules whose C
declarations are 32 bits wide, and for WASI no processes or signals) and runs it with
wasmtime.  It writes what the native compiler writes, byte for byte, for
its own source and for the 6502 assembly of the test programs.

## 3. One subroutine through the pipeline

```
ubyte[] values = [3, 1, 4, 1, 5]

sub total(ubyte limit) -> uword {
    uword sum = 0
    ubyte i
    for i in 0 to len(values) - 1 {
        if values[i] < limit
            sum += values[i]
    }
    return sum
}
```

### Tokens

`p8c -tokens` prints them.  The line `sum += values[i]`:

```
12:17 IDENT sum
12:21 +=
12:24 IDENT values
12:30 [
12:31 IDENT i
12:32 ]
12:33 EOL
```

The end of a line is a token: Prog8's grammar needs it.

### The typed tree

`p8c -types -ast -nopos -nolib`:

```
SUB total
  a: PARAM limit
    a: TYPE op=ubyte : ubyte
  b: TYPE op=uword : uword
  c: VARDECL
    a: TYPE op=uword : uword
    b: INT 0 value=0 : ubyte
    c: IDENT sum
  c: VARDECL
    a: TYPE op=ubyte : ubyte
    c: IDENT i
  c: FOR
    a: IDENT i : ubyte
    b: RANGE op=to : ubyte
      a: INT 0 value=0 : ubyte
      b: INT 4 value=4 : ubyte
    c: IF
      a: BINARY op=< : bool
        a: INDEX : ubyte
          a: IDENT values : ubyte[5]
          b: IDENT i : ubyte
        b: IDENT limit : ubyte
      b: AUGASSIGN op=+=
        a: IDENT sum : uword
        b: INDEX : ubyte
          a: IDENT values : ubyte[5]
          b: IDENT i : ubyte
  c: RETURN
    a: IDENT sum : uword
```

The typer has written a type on every expression and folded
`len(values) - 1` to 4: `values` got its length, 5, from its initializer.
The tree is the same one the parser built.  Nothing is rewritten into a
second, simpler tree; the `for` is still a `for`.

### The IR

`p8c -ir` writes upstream's `.p8ir`.  The subroutine:

```
<CHUNK LABEL="p8b_main.p8s_total">
storezm.w [p8b_main.p8s_total.p8v_sum]
storezm.b [p8b_main.p8s_total.p8v_i]
<CHUNK LABEL="p8_label_gen_4">
loadm.b r2.b,[p8b_main.p8s_total.p8v_i]
loadx.b r1.b,[p8b_main.p8v_values+r2.b]
loadm.b r3.b,[p8b_main.p8s_total.p8v_limit]
bger.b r1.b,r3.b,p8_label_gen_7
loadm.b r5.b,[p8b_main.p8s_total.p8v_i]
loadx.b r4.b,[p8b_main.p8v_values+r5.b]
ext.b r6.w,r4.b
addm.w r6.w,[p8b_main.p8s_total.p8v_sum]
<CHUNK LABEL="p8_label_gen_7">
<CHUNK LABEL="p8_label_gen_6">
incm.b [p8b_main.p8s_total.p8v_i]
loadm.b r7.b,[p8b_main.p8s_total.p8v_i]
cmpi.b r7.b,#5.b
bstne p8_label_gen_4
<CHUNK LABEL="p8_label_gen_5">
loadm.w r8.w,[p8b_main.p8s_total.p8v_sum]
returnr.w r8.w
```

A loop whose bounds are constants is tested at its end and needs no test
before it.  `values[i]` is read twice: the IR generator does no common
subexpression work, here or anywhere.

### 6502, one instruction at a time

`p8c -noopt` shows what the code generator writes before any pass has run.
Every IR register has a **cell**, a byte or more in a table `p8_regfile`,
and every IR instruction is translated by itself: operands from their cells,
the result into its cell.

```
p8_label_gen_4:
    lda  p8b_main.p8s_total.p8v_i       ; loadm.b r2,[i]
    sta  p8_regfile+1
    ldy  p8_regfile+1                   ; loadx.b r1,[values+r2]
    lda  p8b_main.p8v_values,y
    sta  p8_regfile+0
    lda  p8b_main.p8s_total.p8v_limit   ; loadm.b r3,[limit]
    sta  p8_regfile+2
    lda  p8_regfile+0                   ; bger.b r1,r3
    cmp  p8_regfile+2
    bcs  p8_label_gen_7
    lda  p8b_main.p8s_total.p8v_i       ; loadm.b r5,[i]
    sta  p8_regfile+4
    ldy  p8_regfile+4                   ; loadx.b r4,[values+r5]
    lda  p8b_main.p8v_values,y
    sta  p8_regfile+3
    lda  p8_regfile+3                   ; ext.b r6.w,r4.b
    sta  p8_regfile+5
    lda  #0
    sta  p8_regfile+6
    clc                                 ; addm.w r6,[sum]
    lda  p8b_main.p8s_total.p8v_sum
    adc  p8_regfile+5
    sta  p8b_main.p8s_total.p8v_sum
    lda  p8b_main.p8s_total.p8v_sum+1
    adc  p8_regfile+6
    sta  p8b_main.p8s_total.p8v_sum+1
```

(The comments are added here.)  This is always right and it is poor code:
the whole program is 609 bytes this way.

### After the passes

```
p8b_main.p8s_total  .proc
    sta  p8b_main.p8s_total.p8v_limit
    lda  #0
    sta  p8b_main.p8s_total.p8v_sum
    sta  p8b_main.p8s_total.p8v_sum+1
    sta  p8b_main.p8s_total.p8v_i
p8_label_gen_4:
    ldy  p8b_main.p8s_total.p8v_i
    lda  p8b_main.p8v_values,y
    cmp  p8b_main.p8s_total.p8v_limit
    bcs  p8_label_gen_7
    clc
    lda  p8b_main.p8s_total.p8v_sum
    adc  p8b_main.p8v_values,y
    sta  p8b_main.p8s_total.p8v_sum
    bcc  +
    inc  p8b_main.p8s_total.p8v_sum+1
+
p8_label_gen_7:
    inc  p8b_main.p8s_total.p8v_i
    lda  p8b_main.p8s_total.p8v_i
    cmp  #5
    bne  p8_label_gen_4
    ldy  p8b_main.p8s_total.p8v_sum+1
    lda  p8b_main.p8s_total.p8v_sum
    rts
    .pend
```

Not one cell is left.  What happened:

- the cell for `i` was a copy of the variable, so `ldy` reads the variable;
- `limit` is compared where it is, without a cell;
- the second `ldy` of `i` went: Y still holds it;
- the element is added from the array, not from a cell, and the high byte of
  the extended value is the constant 0;
- the three zeros at the start are one `lda #0`;
- the labels nothing jumps to are gone.

- the second read of the element for the comparison's sake went: nothing
  used it, and reading an array of the program has no other effect;
- the carry into the high byte of `sum` is a branch and an `inc`, since
  neither A nor the flags are wanted after it.  That rewrite is made in the
  very last run, because the label it needs would make the forward pass
  forget what it knows.

One thing is left: A already holds `values[i]` when the addition starts, so
`clc / adc sum` would do, as upstream has it below.  The program is 521
bytes.

### What upstream writes

The reference compiler generates 6502 code from its syntax tree, not from
the IR, and knows the shape of what it is translating:

```
p8_label_gen_8_for_loop
	ldy  p8v_i
	lda  p8b_main.p8v_values,y
	cmp  p8v_limit
	bcs  p8_label_gen_10_afterif
	ldy  p8v_i
	lda  p8b_main.p8v_values,y
	clc
	adc  p8v_sum
	sta  p8v_sum
	bcc  +
	inc  p8v_sum+1
+
```

It reloads Y, which p8p8 does not, and it adds to the value it already has
in A, which p8p8 does not see.  Its program is 518 bytes.  The two
generators arrive at code of the same kind from opposite ends: upstream
writes a good sequence for each construct it recognizes, p8p8 writes a naive
sequence for everything and then removes what is not needed.  Neither is
uniformly smaller (section 8).

## 4. The front end

**Lexer** (`lexer.p8`).  Written by hand; one array of tokens for each file,
23 bytes a token.

**Parser** (`parser.p8`).  Recursive descent, with precedence climbing for
expressions.  It takes upstream's whole grammar: every file of upstream's
library, examples and compiler tests parses, and prints back to a tree that
is the same when parsed again (`make roundtrip`, 544 files).  It is more
permissive than the grammar where that is simpler, and leaves the rejecting
to the checker.

A hand-written parser has to decide by itself what a generated one resolves
by trying.  Prog8 has no statement terminator but the end of the line, and
an expression may continue on the next line after an operator.  Two cases
that the conformance tests found:

```
when x {
    0 -> return 1
    -1 -> return 2          ; not "1 - 1": the line has an arrow in it
}

word size = if v < 0 -v else v      ; upstream: -v is the first value
                                    ; p8p8: "0 - v", and then no value
```

The first is handled by looking ahead for the arrow.  The second is a known
difference; `then` or parentheses make it unambiguous.

**Importer** (`importer.p8`).  `%import` against the directories of
`-srcdirs` and then the layers of the library ([TARGETS.md](TARGETS.md)).

**Symbols and names** (`symtab.p8`, `resolver.p8`).  Scopes of symbols; a
symbol knows its declaring node, the scope it opens, its type, and its name
in the IR, made when first needed.

**Types** (`types.p8`, `typer.p8`).  A type is a number.  The simple types
are fixed numbers; an array, a pointer or a struct type is interned in a
hash table like a name, so two types are the same type when their numbers
are equal.  The typer writes the number on each node, folds constants
(`const_eval`), and encodes string literals for the target.

**Checker** (`checker.p8`).  The errors, with upstream's wording, ported one
by one.  How far the two compilers agree on what is an error is measured
with a set of small invalid programs (`tools/checkprobe.py`), and
[DIFFERENCES.md](DIFFERENCES.md) lists where they do not.

Upstream has an optimizer between its two trees: constant propagation,
inlining, dead code and dead store removal.  p8p8 has no counterpart.  It
folds constants in the typer and removes unused subroutines and variables
from the IR, and leaves the rest to the back ends.

## 5. The IR

`irgen.p8` walks the typed tree and writes upstream's IR, instruction for
instruction: 172 opcodes, virtual registers typed byte, word, long or float,
code in labelled chunks.  Using upstream's format unchanged was the most
useful decision in the project:

- p8p8's IR runs in upstream's virtual machine, so the front end could be
  tested before either back end existed;
- upstream's back ends accept it (`-codegen upstream`), which gives a second
  way to build any program and something to compare with;
- the IR already carries the conventions of 6502 programs: the `p8b_`,
  `p8s_`, `p8v_` prefixes that library assembly expects, register arguments
  of `asmsub`s, word arrays split into a low and a high half.

The cost is that the IR is not neutral.  It differs by target: on a 6502
word arrays are split and an address is a word; on the host an address is
64 bits.  `irgen` knows which it is writing for.

`irprune.p8` then removes the subroutines and variables that nothing refers
to, starting from `start` and from what assembly text names.

Where the 6502 has no instruction-level answer, the IR generator calls the
library as a program would.  The square root of a `long`, for example, is
`prog8_lib.sqrt_long`, a subroutine written in Prog8: `irgen` builds a call
node for it and lets it go the way of any call.

## 6. The 6502 code generator

`gen6502.p8` handles most of the IR's opcodes, each in a few lines that load
operands from cells and store a result to a cell, as shown above.  It also
writes what surrounds the code: the launcher, the startup code from the
target file, a scope for each block and subroutine, the data.  Multiply,
divide, shifts by a variable and floating point are calls of upstream's
library routines.

All of the quality is in `peep6502.p8`, which sees one subroutine at a time
as lines.  The order:

```
thread_jumps
up to 3 times:  jumps, unused_labels, unreachable
tail_calls
up to 4 times:  forward, dead_stores, forward_stores, fold_operands,
                fold_swapped, argument_order, word_increment, backward
merge_arms      (and forward, dead_stores, backward once more if it did anything)
up to 2 times:  backward, with what the pass before found at the labels
```

Then cells that survived are given storage, and the lines are written.

### Forward: value numbers

Going down the lines, the pass keeps a number for what is in A, X and Y, in
each cell, and in each plain variable.  Two things with the same number
hold the same value.

- `lda cell` when A already has the cell's number: the line goes.
- `ldy cell` when A has it: `tay`.
- a read of a cell that is a copy of a variable becomes a read of the
  variable; of a constant, an immediate.
- `cmp #0` after an instruction that set the flags from the same value goes.

A label forgets everything, since control may arrive from elsewhere.  So
does any line the generator does not understand: inline assembly is opaque.

### Backward: liveness

Going up the lines, the pass keeps what is still needed: A, X, Y, the
flags, the carry, the scratch pointer.

- a load into a register nothing needs goes;
- a store to a cell that is written again before it is read goes;
- `lda x` / `tay` with A not needed after becomes `ldy x`.

At a branch back to a label that comes earlier, the first run has to assume
that everything is needed.  It records what it found at each label, and a
second run uses that: this is how loops are understood without building a
flow graph.

### What a call may change

A `jsr` makes the forward pass forget every variable.  For the size of real
programs it matters a great deal when that is not necessary:

- a subroutine's **own variables** survive a call when nothing else names
  them (no other subroutine, no assembly, no address taken) and the
  subroutine cannot be entered a second time while it runs.
  `gen6502.own_variables` works this out from the call graph; a subroutine
  with assembly in it, or a call through a pointer, may reach any subroutine
  that assembly names or whose address is taken.
- the program's variables survive the library's multiply and divide
  routines, which are known not to touch them;
- cells belong to their subroutine and always survive.

### Cells and the zero page

Most cells are gone after the passes.  Those that are left are short lived,
so they share storage: cells that are not in use over a call share a small
pool of zero page bytes with every other subroutine's (`p8z_0`, `p8z_1`,
...); cells in use over a call share among themselves within their
subroutine.  A subroutine that an interrupt may run keeps off the pool.

The rest of the free zero page goes to variables: first those marked `@zp`,
then by how often they are named, with more weight for a pointer that is
followed, because in the zero page it can be used as it is.

### The 65C02

`stz`, `bra`, `inc a`, `dec a`, `(zp)`, `tsb` and `trb` are used when the
target has them.  `bbr`, `bbs`, `rmb` and `smb` never: a 65816 in emulation
mode, which many Commander X16s have, does not have them.

## 7. LLVM, and compiling itself

`llvmgen.p8` writes LLVM IR text from the same IR: a function for each
subroutine, a basic block for each chunk, an `alloca` for each virtual
register and for each scalar local, i1 slots for the status flags.  It is
as naive as the 6502 generator, and here somebody else's passes clean up:
`mem2reg` and the rest of clang's `-O2`.

That is how p8p8 is built.  Three things keep it honest:

- **Bootstrap.**  p8c compiled by itself must compile itself to the
  identical 14,092,869 bytes of IR (`make bootstrap`).
- **The seed.**  The repository carries the compiler's own LLVM IR,
  compressed (`seed/p8c.ll.gz`), so building needs clang and nothing else:
  clang makes a first compiler from the seed, that compiles the source,
  clang makes the real one.  The same file serves macOS, Linux and Windows;
  on Windows four C library functions are renamed in it first.
- **Seed check.**  The compiler built from the seed and the one built by
  `prog8c-llvm` must write identical output (`make seedcheck`), so the seed
  cannot drift from what the source says.

Self-compilation is also the largest test there is.  When p8c first
compiled itself the result wrote garbage, from three mistakes in `irgen`
that no test program had touched: where an uninitialized local is set to
zero, and the address of an element behind a pointer in two forms.  They
were found by running the two builds of the compiler side by side on the
same input and looking for the first place their output differed.

## 8. Testing against a reference

Almost every test is a comparison with upstream.  The same program is built
by both compilers and must print the same:

| Where | Suite | Programs |
|---|---|---|
| upstream's virtual machine | `make vmcmp` | 52 |
| native executables | `make nativecmp` | 56 |
| Commander X16, in x16emu | `make emucmp` | 66 |
| Commodore 64, in VICE | `make emucmp64` | 57 |

and programs that draw must end on the same picture (`make gfxcmp`).
`tests/conformance` goes through the language area by area with values
neither compiler can know in advance.

A reference cuts both ways.  One afternoon of conformance tests found eight
mistakes and gaps in p8p8 (the sign at the start of a `when` line, `len()`
of an array filled by a range, `float as ubyte` using the signed
conversion, `msb()` of a long taking the wrong byte on the 6502, and
others), and two mistakes in the reference compiler's 6502 code generator,
which have since been fixed there.

### Sizes

Program files of upstream's examples, in bytes, both compilers with their
default settings:

| Example | C64 upstream | C64 p8p8 | X16 upstream | X16 p8p8 |
|---|---|---|---|---|
| `primes` | 520 | 514 | 565 | 557 |
| `numbergame` | 1030 | 1035 | 1077 | 1083 |
| `queens` | 1053 | 1107 | 1103 | 1155 |
| `mandelbrot` | 1171 | 1804 | 1132 | 1829 |
| `pointers/sorting` | 1779 | 1995 | 1788 | 1976 |
| `maze` | 2992 | 3286 | 2791 | 3149 |
| `pointers/hashtable` | 3384 | 3251 | 2909 | 2974 |
| `textelite` | 11217 | 11269 | 10748 | 10805 |

p8p8 is within a percent on the larger text programs, smaller on a few, and
clearly larger where the program is floating point (`mandelbrot`) or tight
loops over arrays (`maze`, `sorting`): upstream has dedicated sequences for
those, and p8p8 goes through the general path.  The work on size so far was
driven by a few large programs that are not in the repository, which is
where the call and zero page rules of section 6 pay; small examples show
its weak spots better.

## 9. What went wrong, and why

The mistakes of the first weeks fall into a few families, and they say
something about the language as a tool for this job.

- **A node kind that was not handled.**  `len()` worked for an array
  declared with a literal or a string, and did nothing for one declared
  with a range, because the code looked at two of the three kinds an
  initializer can be.  With one record for every node and no checked
  `match`, nothing points at the missing case.
- **The wrong one of two similar things.**  A cast from float picked signed
  or unsigned by the type it came from, not the type asked for.  `msb()` of
  a long took byte 1, not byte 3.  Both give the right answer for small
  numbers.
- **Text that is ambiguous without a terminator.**  The parser cases in
  section 4.
- **State that outlives its use.**  Names and messages are built in shared
  buffers; a pointer into one is good until the next routine that uses it.

What found them was never inspection.  It was a second compiler to compare
with, and programs that compute with values the compiler cannot fold away.

## 10. Where to start reading

- `src/main.p8`, `compile_file`: the stages in order.
- `src/ast.p8`: the node kinds, each with what its slots mean.
- `src/irgen.p8`, `expression`: how a typed tree becomes IR.
- `src/gen6502.p8`, the big `when` over opcodes: one IR instruction each.
- `src/peep6502.p8`, the comment at the top and `optimize`.
- `p8c -tokens`, `-ast -types`, `-ir`, `-noopt`: every stage of this
  document, for a program of your own.
