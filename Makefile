#
# Simple Makefile for a Prog8 program.
#
# This Makefile requires basic Windows or Unix shell tools
# and the Prog8 compiler as `prog8c-llvm`.
#
# The 64tass (or Tass64) assembler is needed by the compiler.
# The C64 emulation requires VICE.
# The X16 emulation requires x16emu.
#
# Make targets and explanations:
# all:
#     default target if you just run `make` which ensures
#     the `build/` directory exists and tries to compile
#     whatever targets are in the PROGS variable
#
# build:
#     creates the `build/` directory
#
# clean:
#     removes everything in `build/`
#
# build/mainc64.prg:
#     builds the program for the C64 target
#
# build/maincx16.prg:
#     builds the program for the CX16 target
#
# build/main.p8ir:
#     builds the program for the virtual target
#
# run:
#     depends on the `all` target and then runs in the virtual emulator target
#
# c64:
#     depends on $(SRCS), builds the C64 binary and launches it in VICE.
#
# cx16:
#     depends on $(SRCS), builds the CX16 binary and launches it in x16emu.
#
# check:
#     runs a compiler syntax check without attempting to compile.
#     use it for quickly finding syntax errors in the source code.
#
# test:
#     compiles and runs on the virtual target and compares the output
#     to expected output.  use to validate correct source code changes
#     (presumably the expected results will change as features are written)

# Cross-platform removal command
ifeq ($(OS),Windows_NT)
    CLEAN = del /S /Q build\*
    CP = copy
    RM = del /Q
    MD = mkdir
    MV = cmd -c "move"
else
    CLEAN = rm -fr build/*
    CP = cp -p
    RM = rm -f
    MD = mkdir -p
    MV = mv
endif

PCC=p8c
PCCARGSCX16=-srcdirs src:src/cx16 -asmlist -target cx16 -out build/
PCCARGSGTC=-meminfo -srcdirs src:src/gametank -asmlist -target gametank

PROGS	= build/rail-gunner.prg build/rail-gunner.gtr
SRCS	= rail_gunner.p8

.PHONY:	all check test clean run emu

all: build $(PROGS)

build:
	$(MD) build/

build/rail-gunner.prg: $(SRCS)
	$(PCC) $(PCCARGSCX16) -o $@ $<

build/rail-gunner.gtr: $(SRCS)
	$(PCC) $(PCCARGSGTC) -o $@ $<

check:
	$(PCC) -check -quiet $(PCCARGSCX16) $(SRCS)

clean:
	$(CLEAN)

run:	build/rail-gunner.gtr
	GameTankEmulator $<

cx16:	$(SRCS)
	$(PCC) $(PCCARGSCX16) $< -emu

test:	all
	true

#
# end-of-file
#
