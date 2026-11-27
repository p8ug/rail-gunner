# Following upstream

p8p8 compiles the language as Prog8 defines it, so it has to notice when
Prog8 changes.  There are two upstreams: Prog8 itself
(<https://github.com/irmen/prog8>, `master`), and its LLVM branch
(<https://github.com/gillham/prog8>, `llvm`), which merges `master` and is
what p8p8 is compared with.

Three things together catch a change, and none of them alone:

1. **Notes written when `master` is merged into the LLVM branch.**  Whoever
   does the merge has read the commits and knows why things changed.  The
   notes say what to look at; they are a summary and may miss something.
2. **The diff, sorted by what concerns p8p8** (`make upstreamcheck`).  It is
   complete, and it shows in full the few files where every line matters.
3. **The test suites.**  Most changes of the language, the library and the
   behaviour of programs make a suite fail once the reference material is
   new.  Two kinds do not: a new command line option, and a new builtin
   function that no test program uses.  Those are what 1 and 2 are for.

## What p8p8 depends on

| Upstream | Where | What notices in p8p8 |
|---|---|---|
| the grammar | `parser/src/main/antlr/Prog8ANTLR.g4` | `make programs`, `roundtrip`, `corpus` |
| builtin functions | `codeCore/.../BuiltinFunctions.kt`, `compiler/.../BuiltinFunctions.kt` | nothing, until a program uses one |
| the command line | `compiler/src/prog8/CompilerMain.kt` | nothing |
| the library | `compiler/res/prog8lib/` | `tools/check_overrides.py` in the library repository; the comparison suites |
| the IR | `intermediate/src/` | `make vmcmp` |
| checks and messages | `compiler/.../astprocessing/`, `compilerAst/` | `tools/checkprobe.py` |
| targets, encodings | `codeCore/.../target/` | the library's target files; `tools/gen_enctables.py` |
| what programs do | everything else | `make conformance`, `vmcmp`, `nativecmp`, `emucmp`, `emucmp64`, `gfxcmp` |

Upstream's optimizer, its 6502 code generators, the virtual machine and the
language server change often and do not concern p8p8, except through what
programs do.

## The notes of a merge

One entry for each merge of `master` into the LLVM branch, in a file of that
branch, newest first.  The headings are fixed and all of them are there
every time: "nothing" under a heading says that it was looked at.  One line
for each change, with the commit.

```
## master <from commit> .. <to commit>, merged <date>

### Language and grammar
(new syntax, changed meaning of existing syntax, new directives or tags)

### Builtin functions
(added, removed, changed arguments or result types)

### Library
(new modules, changed signatures, routines the code generator calls by name)

### IR
(new or changed instructions, the file format)

### Errors and warnings
(new checks, checks that went, changed wording)

### Command line
(new options, changed defaults)

### Conventions of 6502 programs
(calling conventions, symbol prefixes, how variables are laid out, zero page)

### Bugs fixed
(especially ones that p8p8 reported or works around)

### LLVM branch only
(what the merge changed in the branch's own code, and conflicts worth knowing)

### Nothing for p8p8
(one line: what the rest of the commits were about)
```

## Taking a new upstream into p8p8

1. `make upstreamcheck PROG8_SRC=<checkout of Prog8>` prints what changed
   between the commit the library follows (`lib/VERSION`) and the
   checkout's `HEAD`.  `FROM=` and `TO=` name other commits.  Read it beside
   the notes of the merge: whatever it shows that the notes do not mention
   gets looked at.
2. In the library repository: replace `prog8lib/` with upstream's, update
   `VERSION`, run `tools/check_overrides.py` and look again at every
   replaced file it names.  Commit, and move the submodule in p8p8.
   The merge notes and the diff only cover `master`.  What the LLVM branch
   added of its own is looked at apart: the library of the llvm targets
   (`compiler/res/prog8lib/llvm16`, `llvm32`, `llvm64` against
   `targets/llvm*` of the library), syscalls from 200 up
   (`codeGenLlvm/.../InstrSyscall.kt` against `lower_syscall` in
   `src/llvmgen.p8`), and the C sources it builds programs with
   (`codeCore/res/prog8lib/llvm-triples/` against `runtime/`, and its
   profiles against the library's `triples/`: a key that is new there has
   to be known to `src/triple.p8` before a profile that uses it works).
3. `python3 setup.py`, for the new examples, tests and documentation.
4. `make programs`, `roundtrip`, `corpus`: the grammar.  Then
   `make conformance`, `vmcmp`, `nativecmp`, and the emulator suites.
5. For each new feature, builtin or option: implement it or list it in
   [DIFFERENCES.md](DIFFERENCES.md), and give new behaviour a few lines in
   the conformance program of its area.
6. `tools/checkprobe.py` for the messages that were added or reworded.
7. If [INTERNALS.md](INTERNALS.md) quotes numbers of the reference compiler,
   measure them again or say which commit they are from.
