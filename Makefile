#
# Makefile for Rail Gunner, a Prog8 program for two machines.
#
# It needs basic Windows or Unix shell tools, the p8p8 compiler as `p8c`,
# and the 64tass (or Tass64) assembler, which the compiler runs.
# x16emu runs the Commander X16 version, GameTankEmulator the GameTank's.
#
# The sources are in src/.  What a machine does in its own way is in
# src/cx16/ and src/gametank/, in modules of the same names, and -srcdirs
# names the one directory that belongs to the target.
#
# Make targets:
# all:
#     build/cx16/rail_gunner.prg (Commander X16) and
#     build/gametank/rail_gunner.gtr (GameTank: the image of the whole 2 MB
#     cartridge).  Each has a directory of its own, because the compiler's
#     other output files have the same names for both.
#
# check:
#     a syntax check of both versions, without building them
#
# cx16:
#     builds the Commander X16 version and runs it in x16emu
#
# run:
#     builds the GameTank version and runs it in GameTankEmulator
#
# assets:
#     makes the GameTank's picture and sound data again, after a change in
#     tools/gametank/ (the results are checked in; the sound needs mido:
#     see BUILD.md)
#
# test:
#     builds both versions, then runs the GameTank version in gth, a
#     GameTank without a window (tools/gametank/gth.cpp, built with the C++
#     compiler), and compares what tests/gametank_test.py finds with
#     tests/expected/gametank.txt.  It also checks that the GameTank's
#     picture data is what tools/gametank/make_assets.py makes.
#
# clean:
#     removes everything in `build/`

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
PCCARGSCX16=-srcdirs src:src/cx16 -asmlist -target cx16
PCCARGSGTC=-meminfo -srcdirs src:src/gametank -asmlist -target gametank

CX16PRG	= build/cx16/rail_gunner.prg
GTROM	= build/gametank/rail_gunner.gtr
PROGS	= $(CX16PRG) $(GTROM)
SRCS	= src/rail_gunner.p8
COMMON	= $(SRCS) src/game.p8 src/scores.p8
CX16SRCS = $(COMMON) $(wildcard src/cx16/*)
GTSRCS	= $(COMMON) $(wildcard src/gametank/*)

GTH	= build/gth
CXX	?= c++

.PHONY:	all check test clean run cx16 assets

all: $(PROGS)

build/cx16 build/gametank:
	$(MD) $@

$(CX16PRG): $(CX16SRCS) | build/cx16
	$(PCC) $(PCCARGSCX16) -out build/cx16 $(SRCS)

$(GTROM): $(GTSRCS) | build/gametank
	$(PCC) $(PCCARGSGTC) -out build/gametank $(SRCS)

check:
	$(PCC) -check -quiet $(PCCARGSCX16) $(SRCS)
	$(PCC) -check -quiet $(PCCARGSGTC) $(SRCS)

clean:
	$(CLEAN)

run:	$(GTROM)
	GameTankEmulator $<

cx16:	$(CX16PRG)
	x16emu -prg $< -run

assets:
	python3 tools/gametank/make_assets.py
	python3 tools/gametank/make_sound.py

$(GTH): tools/gametank/gth.cpp tools/gametank/mos6502/mos6502.cpp tools/gametank/mos6502/mos6502.h | build/gametank
	$(CXX) -O2 -std=c++17 -w -o $@ tools/gametank/gth.cpp tools/gametank/mos6502/mos6502.cpp

test:	all $(GTH)
	python3 tools/gametank/make_assets.py --check
	python3 tests/gametank_test.py > build/gametank_test.txt
	diff tests/expected/gametank.txt build/gametank_test.txt
	@echo all tests passed

#
# end-of-file
#
