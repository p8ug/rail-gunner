"""Arrange northivanastan's CC0 MIDI as a looping 60 Hz YM2151 ZSM."""
from collections import defaultdict
from pathlib import Path
from struct import pack

import mido

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "punch_your_way_through.mid"

# Each tuple is a multiplier, total level, attack, decay, sustain rate,
# and sustain level / release. All patches are synthesized in the YM2151.
# YM2151 operator register order is M1, M2, C1, C2. Algorithm 4
# lets C1 add an octave or a sub-octave while C2 carries the main note.
RIFF = [(1, 14, 31, 8, 4, 0x47), (2, 24, 31, 8, 3, 0x47),
        (0, 19, 31, 6, 3, 0x38), (1, 12, 31, 6, 2, 0x38)]
LEAD = [(2, 24, 31, 8, 4, 0x46), (1, 18, 31, 9, 3, 0x47),
        (2, 31, 31, 7, 3, 0x48), (1, 10, 31, 6, 2, 0x38)]
BASS = [(1, 30, 31, 10, 6, 0x48), (1, 22, 31, 8, 5, 0x48),
        (0, 11, 31, 8, 3, 0x39), (1, 14, 31, 7, 4, 0x38)]
PAD = [(1, 36, 24, 8, 3, 0x46), (2, 28, 28, 9, 3, 0x46),
       (1, 36, 24, 7, 3, 0x46), (1, 20, 27, 6, 4, 0x39)]
DRUM = [(2, 20, 31, 24, 17, 0x9f), (3, 25, 31, 26, 18, 0xaf),
        (4, 29, 31, 25, 18, 0xaf), (1, 14, 31, 22, 17, 0x9f)]
PATCHES = [(4, RIFF), (4, LEAD), (4, LEAD), (4, LEAD),
           (4, BASS), (4, PAD), (4, PAD), (0, DRUM)]
POOLS = {0: [0], 1: [1, 2, 3], 2: [4], 4: [5, 6], 9: [7]}
KEY_CODES = [0, 1, 2, 4, 5, 6, 8, 9, 10, 12, 13, 14]


def key_code(note):
    note = min(107, max(13, note))
    return ((note - 13) // 12) * 16 + KEY_CODES[(note - 13) % 12]


def build():
    frames = defaultdict(list)
    init = frames[0]
    init.extend([(0x18, 0), (0x0f, 0)])
    for voice, (algorithm, patch) in enumerate(PATCHES):
        init.extend([(8, voice), (0x20 + voice, 0xc0 | (4 << 3) | algorithm),
                     (0x38 + voice, 0)])
        for slot, values in enumerate(patch):
            for register, value in zip((0x40, 0x60, 0x80, 0xa0, 0xc0, 0xe0), values):
                init.append((register + slot * 8 + voice, value))

    song = mido.MidiFile(SOURCE)
    voices = {}
    elapsed = 0.0
    for event in song:
        elapsed += event.time
        if event.type not in ("note_on", "note_off") or event.channel not in POOLS:
            continue
        frame = frames[round(elapsed * 60)]
        pool = POOLS[event.channel]
        if event.type == "note_off" or event.velocity == 0:
            if event.channel != 9:
                for voice in pool:
                    if voice in voices and voices[voice][0] == event.note:
                        frame.append((8, voice))
                        del voices[voice]
                        break
            continue
        voice = next((v for v in pool if v not in voices), None)
        if voice is None:
            voice = min(pool, key=lambda v: voices[v][1])
        # Release first only when retriggering an occupied channel.
        if voice in voices:
            frame.append((8, voice))
        voices[voice] = (event.note, elapsed)
        note = event.note
        if event.channel == 9:
            kick = note in {35, 36}
            frame.append((0x0f, 0 if kick else 0x96))
            note = 31 if kick else 54
        level = PATCHES[voice][1][3][1] + (127 - event.velocity) // 8
        if event.channel == 1 and note < 64:
            level += 7
        frame.extend([(0x60 + 24 + voice, level),
                      (0x28 + voice, key_code(note)), (8, 0x78 | voice)])
    end = round(elapsed * 60)
    frames[end].extend((8, v) for v in range(8))

    body = bytearray()
    previous = 0
    register_state = {}
    for tick, commands in sorted(frames.items()):
        retained = []
        for register, value in commands:
            # Key writes have side effects even when the value repeats.
            if register == 8 or register_state.get(register) != value:
                retained.append((register, value))
            register_state[register] = value
        commands = retained
        if not commands:
            continue
        delta = tick - previous
        while delta:
            delay = min(delta, 127)
            body.append(0x80 | delay)
            delta -= delay
        for start in range(0, len(commands), 63):
            batch = commands[start:start + 63]
            body.append(0x40 | len(batch))
            for register, value in batch:
                body.extend((register, value))
        previous = tick
    body.extend((0x81, 0x80))
    header = b"zm\x01\x10\x00\x00\x00\x00\x00\xff\x00\x00" + pack("<HH", 60, 0)
    return header + body


if __name__ == "__main__":
    data = build()
    (ROOT / "PUNCH.ZSM").write_bytes(data)
    lines = ["music_data {", "    sub track() {", "        %asm {{"]
    for start in range(0, len(data), 24):
        lines.append("            .byte " + ",".join(str(b) for b in data[start:start + 24]))
    lines += ["        }}", "    }", "}", ""]
    (ROOT / "src" / "cx16" / "music_data.p8").write_text("\n".join(lines))
