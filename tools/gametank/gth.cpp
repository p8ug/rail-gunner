// gth: a GameTank without a window, for tests.
//
// It runs a cartridge image (.gtr, 2 MB) and does what it is told on standard
// input, one command a line, answering on standard output.  tools/gametank/gt.py
// drives it from Python; tests/gametank_test.py is what `make test` runs.
//
//   run N              run N frames (a frame ends with the vsync interrupt)
//   btn [NAMES...]     hold these buttons of gamepad 1, and no others:
//                      UP DOWN LEFT RIGHT A B C START
//   peek ADDR N        N bytes of main RAM, in hex (ADDR is hex)
//   poke ADDR VALUE    write a byte of main RAM (both hex)
//   aram ADDR N        N bytes of the audio RAM
//   crc                the CRC-32 of the framebuffer that is shown
//   shot FILE          that framebuffer as a file: 16384 colour bytes
//   stat               frames and flips so far, and since the last stat the
//                      average and the highest number of cycles of a frame
//                      that were not spent waiting (see idle)
//   idle LO HI         the addresses (hex) of the loop that waits for a frame
//   prof on            start counting cycles for every address
//   prof FILE          stop, and write "address cycles" lines (an address in
//                      a bank has the bank's number, less 127, in front)
//   busylog FILE|off   write "frame cycles flips" for every frame
//   loadflash FILE     the save bank (254) from a file of 16384 bytes
//   saveflash FILE     and to one
//
// The memory map, the blitter, the flash and the gamepad are those of
// GameTankEmulator (gte.cpp, blitter.cpp, joystick_adapter.cpp; MIT license,
// Copyright (c) 2020 Clyde Shaffer), without its window, sound output and
// tools.  The cpu is its mos6502 (mos6502/, see the license there).  The
// audio coprocessor runs its firmware as there, but nothing is heard.
//
// Build:  c++ -O2 -std=c++17 -o gth gth.cpp mos6502/mos6502.cpp
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <string>
#include <iostream>
#include <sstream>
#include "mos6502/mos6502.h"

static const int CYCLES_PER_FRAME = 315000000 / 88 / 60;

static uint8_t ram[32768], vram[32768], gram[16384 * 32], via[16], aram[4096];
static uint8_t *rom;
static uint8_t dma_control, banking, bank_shifter, bank_mask = 0xff;
static bool dma_irq, write_mode;
static uint64_t total_cycles;
static mos6502 *cpu, *acp;
static uint64_t flips, frames;
static uint16_t padmask;
static bool pad1State, pad2State;

// what a frame costs
static uint16_t idle_lo = 1, idle_hi = 0;
static uint64_t last_fetch, busy_cycles, busy_max, busy_sum, busy_frames;
static bool last_idle;
static FILE *busylog;
static uint64_t *prof;
static uint32_t last_key;
static bool profiling;

// ---- blitter (blitter.cpp) ----
static uint8_t cVX, cVY, cGX, cGY, cW, cH, params[8], gram_mid_bits;
static bool trigger, binit, brunning;
static uint64_t last_updated;

static void blit_catchup() {
    uint64_t cycles = total_cycles - last_updated;
    last_updated = total_cycles;
    while (cycles--) {
        if (!brunning && !binit && !trigger) break;
        if (brunning) --cW;
        if (binit) cW = params[4] & 0x7f;
        if (brunning) {
            ++cVX;
            cGX = (dma_control & 16) ? cGX + 1 : ((cGX & 0xf0) | ((cGX + 1) & 0x0f));
            if (cW == 0) {
                ++cVY;
                cGY = (dma_control & 16) ? cGY + 1 : ((cGY & 0xf0) | ((cGY + 1) & 0x0f));
                --cH;
            }
        }
        if (cW == 0 || binit) { cVX = params[0]; cGX = params[2]; }
        if (binit) { cVY = params[1]; cGY = params[3]; cH = params[5] & 0x7f; }
        if (cH == 0) brunning = false;
        brunning = brunning || binit;
        if (cW == 0) cW = params[4] & 0x7f;
        binit = trigger;
        trigger = trigger && !binit;
        if (brunning) {
            bool xdir = params[4] & 0x80, ydir = params[5] & 0x80;
            uint8_t colorbus;
            if (xdir) cGX = ~cGX;
            if (ydir) cGY = ~cGY;
            gram_mid_bits = (!!(cGY & 0x80) * 2) + (!!(cGX & 0x80));
            if (dma_control & 8) colorbus = ~params[7];
            else {
                uint32_t off = ((banking & 7) << 16) + (!!(cGY & 0x80) << 15) + (!!(cGX & 0x80) << 14);
                colorbus = gram[((cGY & 0x7f) << 7) | (cGX & 0x7f) | off];
            }
            if (xdir) cGX = ~cGX;
            if (ydir) cGY = ~cGY;
            if ((dma_control & 1)
                && ((dma_control & 128) || colorbus != 0)
                && !((cVX & 0x80) && (banking & 16))
                && !((cVY & 0x80) && (banking & 32))) {
                int voff = (banking & 8) ? 0x4000 : 0;
                vram[((cVY & 0x7f) << 7) | (cVX & 0x7f) | voff] = colorbus;
            }
        }
    }
}

static void blit_param(uint8_t address, uint8_t value) {
    if ((address & 7) == 6) {
        trigger = value & 1;
        cpu->ClearIRQ();
        if (trigger) cpu->ScheduleIRQ((params[5] & 0x7f) * (params[4] & 0x7f), &dma_irq);
    } else params[address & 7] = value;
}

// ---- audio coprocessor (audio_coprocessor.cpp, as with --nosound) ----
static bool acp_resetting, acp_running;
static uint8_t acp_irqRate;
static int16_t acp_irqCounter;
static uint64_t acp_cps = 1024, acp_cc;
static uint8_t acp_read(uint16_t a) { return aram[a & 0xfff]; }
static void acp_write(uint16_t a, uint8_t v) { aram[a & 0xfff] = v; }
static void nothing() {}

static void acp_frame() {
    for (int i = 0; i < 233 / 2; i++) {
        acp_irqCounter -= 1024;
        while (acp_irqCounter < 0 && acp_irqRate > 0) {
            if (acp_resetting) { acp_resetting = false; acp->Reset(); }
            acp_irqCounter += acp_irqRate;
            acp_cc = 0;
            if (acp_running) { acp->IRQ(); acp->ClearIRQ(); acp->Run(acp_cps, acp_cc); }
        }
    }
}

// ---- memory map (gte.cpp, for a 2 MB flash cartridge) ----
static uint8_t mem_read(uint16_t a) {
    if (a & 0x8000) {
        if (a & 0x4000) return rom[0x1fc000 | (a & 0x3fff)];
        return rom[((bank_mask & 0x7f) << 14) | (a & 0x3fff)];
    } else if (a & 0x4000) {
        blit_catchup();
        if (dma_control & 1) return 0xea;
        if (dma_control & 32) return vram[(a & 0x3fff) | ((banking & 8) ? 0x4000 : 0)];
        return gram[(a & 0x3fff) | ((((banking & 7) << 2) | gram_mid_bits) << 14)];
    } else if (a >= 0x3000) return aram[a & 0xfff];
    else if (a >= 0x2800) return via[a & 15];
    else if (a < 0x2000) return ram[((banking & 0xc0) << 7) | (a & 0x1fff)];
    else if (a == 0x2008 || a == 0x2009) {
        uint8_t out;
        if (a & 1) { out = 0; pad1State = false; pad2State = !pad2State; }
        else { out = pad1State ? (padmask >> 8) : (padmask & 0xff); pad2State = false; pad1State = !pad1State; }
        return ~out;
    }
    return 0xff;
}

static void mem_write(uint16_t a, uint8_t v) {
    if (a & 0x8000) {
        // the flash: a byte after $a0, a sector erase with $30
        if (write_mode) {
            uint8_t *loc = (a & 0x4000) ? &rom[0x1fc000 | (a & 0x3fff)] : &rom[((bank_mask & 0x7f) << 14) | (a & 0x3fff)];
            *loc &= v;
            write_mode = false;
        } else if (v == 0x30) {
            uint8_t sectorBits = ((a & (1 << 13)) >> 13) | ((bank_mask & 0x7f) << 1);
            uint8_t sectorNum = sectorBits >> 3;
            if (sectorNum < 31) memset(rom + (sectorNum << 16), 0xff, 1 << 16);
            else if ((sectorBits & 4) == 0) memset(rom + 0x1f0000, 0xff, 1 << 15);
            else if (sectorBits == 0xfc) memset(rom + 0x1f8000, 0xff, 1 << 13);
            else if (sectorBits == 0xfd) memset(rom + 0x1fa000, 0xff, 1 << 13);
            else if ((sectorBits >> 1) == 0x7f) memset(rom + 0x1fc000, 0xff, 1 << 14);
        } else if (v == 0xa0) write_mode = true;
    } else if (a & 0x4000) {
        blit_catchup();
        if (dma_control & 1) blit_param(a, v);
        else if (dma_control & 32) vram[(a & 0x3fff) | ((banking & 8) ? 0x4000 : 0)] = v;
        else gram[(a & 0x3fff) | ((((banking & 7) << 2) | gram_mid_bits) << 14)] = v;
    } else if (a >= 0x3000) aram[a & 0xfff] = v;
    else if (a & 0x2000) {
        if (a & 0x800) {
            // The cartridge's bank is shifted in a bit at a time on port A,
            // then latched.  Only the pins that the direction register (3)
            // makes outputs are driven; it is 0 after a reset, as on a 6522.
            uint8_t old = via[1] & via[3];
            via[a & 15] = v;
            uint8_t now = via[1] & via[3];
            uint8_t rising = now & ~old;
            if (rising & 1) bank_shifter = ((bank_shifter << 1) & 0xfe) | !!(old & 2);
            else if (rising & 4) bank_mask = bank_shifter | 0x80;
            via[a & 15] = v;
        } else if ((a & 15) == 7) {
            blit_catchup();
            if ((v & 2) != (dma_control & 2)) flips++;
            dma_control = v;
            dma_irq = (v & 64) != 0;
        } else if ((a & 15) == 5) {
            blit_catchup();
            banking = v;
        } else switch (a & 7) {
            case 0: acp_resetting = true; acp_irqCounter = 255; break;
            case 1: acp->NMI(); acp->Run(acp_cps, acp_cc); break;
            case 6: acp_irqRate = ((v << 1) & 0xfe) | (v & 1); acp_running = (v & 0x80) != 0; acp_cps = acp_irqRate * 4; break;
        }
    } else ram[((banking & 0xc0) << 7) | (a & 0x1fff)] = v;
}

// every instruction's first byte comes through here
static uint8_t mem_sync(uint16_t a) {
    uint64_t spent = total_cycles - last_fetch;
    if (!last_idle) busy_cycles += spent;
    if (profiling) {
        prof[last_key] += spent;
        last_key = (a >= 0x8000 && a < 0xc000) ? (((bank_mask & 0x7f) + 1) << 16) | a : a;
    }
    last_fetch = total_cycles;
    last_idle = (a >= idle_lo && a <= idle_hi);
    return mem_read(a);
}

static void run_frame() {
    uint64_t before = total_cycles;
    cpu->Run(CYCLES_PER_FRAME, total_cycles);
    total_cycles = before + CYCLES_PER_FRAME;
    last_fetch = total_cycles;
    if (cpu->illegalOpcode) {
        printf("illegal opcode %02x at %04x, bank %d\n", cpu->illegalOpcodeSrc, cpu->pc, bank_mask);
        exit(2);
    }
    if (dma_control & 4) cpu->NMI();
    blit_catchup();
    acp_frame();
    frames++;
    if (busy_cycles > busy_max) busy_max = busy_cycles;
    busy_sum += busy_cycles;
    busy_frames++;
    if (busylog) fprintf(busylog, "%llu %llu %llu\n", (unsigned long long) frames, (unsigned long long) busy_cycles, (unsigned long long) flips);
    busy_cycles = 0;
}

static uint16_t button(const std::string &n) {
    if (n == "UP") return 0x0808;
    if (n == "DOWN") return 0x0404;
    if (n == "LEFT") return 0x0200;
    if (n == "RIGHT") return 0x0100;
    if (n == "A") return 0x0010;
    if (n == "B") return 0x1000;
    if (n == "C") return 0x2000;
    if (n == "START") return 0x0020;
    fprintf(stderr, "gth: no button %s\n", n.c_str());
    exit(1);
}

static uint32_t crc32(const uint8_t *data, size_t length) {
    uint32_t crc = 0xffffffff;
    for (size_t i = 0; i < length; i++) {
        crc ^= data[i];
        for (int bit = 0; bit < 8; bit++) crc = (crc >> 1) ^ (0xedb88320 & -(crc & 1));
    }
    return ~crc;
}

static const int PROF_KEYS = 129 << 16;

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: gth game.gtr < commands\n"); return 1; }
    rom = (uint8_t *) malloc(1 << 21);
    FILE *f = fopen(argv[1], "rb");
    if (!f) { perror(argv[1]); return 1; }
    size_t n = fread(rom, 1, 1 << 21, f);
    fclose(f);
    if (n != (1 << 21)) { fprintf(stderr, "gth: %s is not a 2 MB cartridge image\n", argv[1]); return 1; }
    // memory is not empty when a GameTank is switched on
    srand(1);
    for (int i = 0; i < 32768; i++) ram[i] = rand();
    for (int i = 0; i < 4096; i++) aram[i] = rand();
    cpu = new mos6502(mem_read, mem_write, nothing, mem_sync);
    acp = new mos6502(acp_read, acp_write, nothing);
    cpu->Reset();
    std::string line;
    while (std::getline(std::cin, line)) {
        std::istringstream in(line);
        std::string cmd;
        if (!(in >> cmd) || cmd[0] == '#') continue;
        if (cmd == "run") { int k; in >> k; while (k-- > 0) run_frame(); }
        else if (cmd == "btn") { padmask = 0; std::string b; while (in >> b) padmask |= button(b); }
        else if (cmd == "peek" || cmd == "aram") {
            unsigned a, l; in >> std::hex >> a >> std::dec >> l;
            for (unsigned i = 0; i < l; i++) printf("%s%02x", i ? " " : "", cmd == "peek" ? ram[(a + i) & 0x1fff] : aram[(a + i) & 0xfff]);
            printf("\n");
        } else if (cmd == "poke") {
            unsigned a, v; in >> std::hex >> a >> v; ram[a & 0x1fff] = v;
        } else if (cmd == "crc") {
            printf("%08x\n", crc32(vram + ((dma_control & 2) ? 0x4000 : 0), 16384));
        } else if (cmd == "shot") {
            std::string name; in >> name;
            FILE *o = fopen(name.c_str(), "wb");
            if (!o) { perror(name.c_str()); return 1; }
            fwrite(vram + ((dma_control & 2) ? 0x4000 : 0), 1, 16384, o);
            fclose(o);
        } else if (cmd == "stat") {
            printf("%llu %llu %llu %llu\n", (unsigned long long) frames, (unsigned long long) flips,
                (unsigned long long) (busy_frames ? busy_sum / busy_frames : 0), (unsigned long long) busy_max);
            busy_max = busy_sum = busy_frames = 0;
        } else if (cmd == "idle") {
            unsigned a, b; in >> std::hex >> a >> b; idle_lo = a; idle_hi = b;
        } else if (cmd == "prof") {
            std::string name; in >> name;
            if (!prof) prof = (uint64_t *) calloc(PROF_KEYS, sizeof(uint64_t));
            if (name == "on") { profiling = true; memset(prof, 0, PROF_KEYS * sizeof(uint64_t)); }
            else {
                profiling = false;
                FILE *o = fopen(name.c_str(), "w");
                if (!o) { perror(name.c_str()); return 1; }
                for (int k = 0; k < PROF_KEYS; k++) if (prof[k]) fprintf(o, "%x %llu\n", k, (unsigned long long) prof[k]);
                fclose(o);
            }
        } else if (cmd == "busylog") {
            std::string name; in >> name;
            if (busylog) fclose(busylog);
            busylog = name == "off" ? NULL : fopen(name.c_str(), "w");
        } else if (cmd == "loadflash") {
            std::string name; in >> name;
            FILE *o = fopen(name.c_str(), "rb");
            if (!o) { perror(name.c_str()); return 1; }
            fread(rom + 0x1f8000, 1, 0x4000, o);
            fclose(o);
        } else if (cmd == "saveflash") {
            std::string name; in >> name;
            FILE *o = fopen(name.c_str(), "wb");
            if (!o) { perror(name.c_str()); return 1; }
            fwrite(rom + 0x1f8000, 1, 0x4000, o);
            fclose(o);
        } else { fprintf(stderr, "gth: what is %s\n", cmd.c_str()); return 1; }
        fflush(stdout);
    }
    return 0;
}
