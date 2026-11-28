#!/usr/bin/env python3
"""Make the GameTank sound data of Rail Gunner.

Writes, into src/gametank/:
  song.bin        northivanastan's CC0 MIDI as a song for the GameTank SDK's
                  tracker player (gametank.play_song): 4 channels of FM
  sfx_data.p8     the sound effects, for gametank.play_sound_effect

The song needs mido, as arrange_music.py does (BUILD.md says how to install
it from tools/python).  The results are checked in, so a build does not run
this.

    python3 tools/gametank/make_sound.py

The effects are the Commander X16 version's: its tables of frequency and
loudness for each frame (src/cx16/audio_platform.p8) are read, and every
frame becomes the notes and loudnesses of one FM channel's four operators.
"""
import math
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "src" / "gametank"
MIDI = ROOT / "punch_your_way_through.mid"

# ---------------------------------------------------------------- the song

STEP_FRAMES = 6         # a sixteenth note: 5.6 frames in the MIDI
PATTERN_LENGTH = 16     # one bar
SILENT = 128            # an operator's amplitude: 128 is silence, 0 and 255 the loudest
NO_NOTE = 255


def envelope(*values):
    """17 bytes: the first is not used, then the amplitude of 16 frames; the
    last one stays until the next note."""
    values = list(values)
    values += [values[-1]] * (16 - len(values))
    return bytes([16] + values[:16])


QUIET = envelope(SILENT)
# An instrument: the transposition of the four operators, and their envelopes.
# The operators are a chain: the first changes the phase of the second, and so
# on; the fourth is what is heard.  The shapes follow the SDK's jingle.
INSTRUMENTS = [
    # 0: nothing, to end a held note
    ((0, 0, 0, 0), (QUIET, QUIET, QUIET, QUIET)),
    # 1: the riff, plucked and bright
    ((16, 0, 244, 0), (
        envelope(88, 96, 104, 112, 120),
        envelope(64, 68, 72, 76, 81, 85, 89, 93, 98, 102, 106, 110, 115, 119, 123, 128),
        envelope(40, 56, 72, 88, 104, 104, 105, 106, 106, 107, 108, 109, 109, 110, 111, 112),
        envelope(56, 57, 58, 60, 61, 62, 64, 65, 66, 68, 69, 70, 72, 90, 109, 128))),
    # 2: the lead, held
    ((16, 0, 244, 0), (
        envelope(88, 96, 104, 112, 120),
        envelope(64, 66, 68, 70, 72, 74, 76, 78, 80, 82, 84, 86, 88, 93, 98, 104),
        envelope(40, 56, 72, 88, 104, 104, 105, 106, 106, 107, 108, 109, 109, 110, 111, 112),
        envelope(64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 80))),
    # 3: the bass, round
    ((0, 0, 0, 0), (
        QUIET, QUIET,
        envelope(88, 96, 104, 110, 114, 118, 120),
        envelope(40, 42, 44, 46, 48, 52, 56, 60, 66, 72, 80, 88, 96, 106, 116, 128))),
    # 4: the kick
    ((0, 0, 7, 0), (
        QUIET, QUIET,
        envelope(64, 96, 120, 128),
        envelope(32, 40, 56, 76, 96, 112, 122, 128))),
    # 5: the snare, a rattle of operators that are not in tune
    ((43, 31, 19, 0), (
        envelope(24, 40, 60, 84, 104, 120, 128),
        envelope(24, 40, 60, 84, 104, 120, 128),
        envelope(32, 48, 68, 90, 108, 122, 128),
        envelope(48, 60, 76, 92, 108, 120, 128))),
]
RIFF, LEAD, BASS, KICK, SNARE = 1, 2, 3, 4, 5


def song_steps():
    """For each of the 4 channels: {step: (note, instrument)}."""
    import mido

    song = mido.MidiFile(MIDI)
    grid = song.ticks_per_beat // 4
    starts = defaultdict(list)      # MIDI channel -> (step, note)
    ends = defaultdict(list)
    for track in song.tracks:
        tick = 0
        for event in track:
            tick += event.time
            if event.type == "note_on" and event.velocity > 0:
                starts[event.channel].append((round(tick / grid), event.note))
            elif event.type in ("note_on", "note_off"):
                ends[event.channel].append((round(tick / grid), event.note))

    def melody(channel, instrument, highest=False, release=False):
        steps = {}
        for step, note in starts[channel]:
            # a chord: only its highest note
            if step not in steps or (highest and note - 12 > steps[step][0]):
                steps[step] = (note - 12, instrument)
        if release:
            for step, note in ends[channel]:
                if step not in steps:
                    steps[step] = (0, 0)
        return steps

    drums = {}
    for step, note in starts[9]:
        if note in (35, 36):
            drums.setdefault(step, (22, KICK))
        else:
            drums[step] = (52, SNARE)
    lead = melody(1, LEAD, highest=True, release=True)
    # the pad fills where the lead is silent
    for step, value in melody(4, LEAD, highest=True, release=True).items():
        lead.setdefault(step, value)
    return [melody(0, RIFF), lead, melody(2, BASS), drums]


def song_bytes():
    channels = song_steps()
    length = max(max(steps) for steps in channels) + 1
    bars = -(-length // PATTERN_LENGTH)

    # the instruments, then the channels, behind the header
    header_size = 16 + 2 * len(INSTRUMENTS)
    body = bytearray()
    instrument_offsets = []
    for transpose, envelopes in INSTRUMENTS:
        start = header_size + len(body)
        instrument_offsets.append(start)
        addresses = [start + 12 + 17 * n for n in range(4)]
        body += bytes(transpose)
        for address in addresses:
            body += address.to_bytes(2, "little")
        for data in envelopes:
            assert len(data) == 17
            body += data

    channel_offsets = []
    for steps in channels:
        patterns, sequence = [], []
        for bar in range(bars):
            pattern = bytearray()
            for step in range(bar * PATTERN_LENGTH, (bar + 1) * PATTERN_LENGTH):
                note, instrument = steps.get(step, (NO_NOTE, 0))
                assert note == NO_NOTE or instrument == 0 or 12 <= note <= 107 - 16
                pattern += bytes([note, instrument])
            if bytes(pattern) not in patterns:
                patterns.append(bytes(pattern))
            sequence.append(patterns.index(bytes(pattern)))
        start = header_size + len(body)
        channel_offsets.append(start)
        sequence_at = start + 4 + 2 * len(patterns)
        pattern_at = sequence_at + len(sequence)
        body += bytes([len(patterns), len(sequence)]) + sequence_at.to_bytes(2, "little")
        for n in range(len(patterns)):
            body += (pattern_at + n * 2 * PATTERN_LENGTH).to_bytes(2, "little")
        body += bytes(sequence)
        for pattern in patterns:
            body += pattern

    header = bytearray([0, STEP_FRAMES, PATTERN_LENGTH, 0, 0, 0, 0])
    for offset in channel_offsets:
        header += offset.to_bytes(2, "little")
    header += bytes([len(INSTRUMENTS)])
    for offset in instrument_offsets:
        header += offset.to_bytes(2, "little")
    assert len(header) == header_size
    return bytes(header + body)


# ---------------------------------------------------------------- the effects

def x16_tables():
    """The arrays of audio_platform.p8 of the X16 version, by name."""
    text = (ROOT / "src" / "cx16" / "audio_platform.p8").read_text()
    tables = {}
    for name, values in re.findall(r"u(?:byte|word)\[\d+\] (\w+) = \[(.*?)\]", text, re.S):
        tables[name] = [int(v[1:], 16) if v.startswith("$") else int(v) for v in re.findall(r"\$?[0-9a-f]+", values)]
    return tables


def note_of(word):
    """The note number (0-107, 60 is about 520 Hz) of a frequency word of VERA's PSG."""
    hertz = word * 48828.125 / 131072
    if hertz < 20:
        return 0
    return max(0, min(107, round(60 + 12 * math.log2(hertz / 523.25))))


def loudness(gain, scale=1.0):
    """0-15 from a PSG volume of 0-63."""
    return max(0, min(15, round(gain * scale * 15 / 63)))


def effect(tone, gain, grain=None, noise=None, buzz=2):
    """The bytes of an effect.  tone and gain are a frequency word and a volume
    for every frame; grain and noise the same for a voice of noise, which
    becomes the three operators in front of the one that is heard."""
    frames = []
    for n in range(len(tone)):
        hiss = noise[n] if noise else 0
        if gain[n] == 0 and hiss == 0:
            frames.append(None)
            continue
        carrier = note_of(tone[n]) if gain[n] else note_of(grain[n] if isinstance(grain, list) else grain) // 2
        volume = loudness(max(gain[n], hiss * 0.8))
        if hiss:
            rattle = note_of(grain[n] if isinstance(grain, list) else grain)
            frames.append((loudness(hiss, 0.7), loudness(hiss, 0.8), loudness(hiss, 0.6), volume,
                           min(107, rattle + 5), max(0, rattle - 14), max(0, rattle - 31), carrier))
        else:
            # a little of an operator an octave up, for an edge on the tone
            frames.append((0, 0, buzz if volume > 4 else 0, volume, 0, 0, min(107, carrier + 12), carrier))
    while frames and frames[-1] is None:
        frames.pop()
    frames = [f if f else (0, 0, 0, 0, 0, 0, 0, 0) for f in frames]
    feedback = 96 if noise else 0
    data = bytearray([len(frames), feedback])
    for frame in frames:
        data += bytes(frame)
    return data


def effects():
    t = x16_tables()
    menu_tone = [1120] + [820 + left * 70 for left in (4, 3, 2, 1)]
    return {
        "menu": effect(menu_tone, t["menu_gain"][:5], buzz=0),
        "dry": effect(t["dry_pitch"], t["dry_gain"], grain=t["dry_pitch"], noise=t["dry_gain"]),
        "pickup": effect(t["pickup_pitch"], t["pickup_gain"], buzz=0),
        # On the X16 a shot, a hit and a blast are a tone with noise, each on
        # voices of its own.  Here the three share a channel, and with the guns
        # at full auto and many hits the noise was all that was heard, without
        # an end (on a console).  So they are short, and mostly tone:
        # the shot is its tone only, falling, three frames at half the loudness;
        "shot": effect(t["shot_pitch"][:3], [gain // 2 for gain in t["shot_gain"][:3]], buzz=0),
        # a hit is a quick boom: the low end of its tone, noise in the first frame;
        "hit": effect(t["hit_pitch"][2:5], [48, 35, 18], grain=4410, noise=[40, 0, 0]),
        # a blast is every other frame of the X16's, seven of them, noise in two.
        "blast": effect(t["blast_pitch"][0:14:2], t["blast_gain"][0:14:2], grain=t["blast_grain"][0:14:2],
                        noise=[50, 30, 0, 0, 0, 0, 0]),
        "warn": effect(t["warn_pitch"], t["warn_gain"], buzz=4),
        "launch": effect(t["launch_pitch"], t["launch_gain"], grain=t["launch_grain"], noise=t["launch_noise"]),
        "down": effect(t["down_pitch"], t["down_gain"], grain=t["down_grain"], noise=t["down_noise"]),
        "start": effect(t["start_pitch"], t["start_gain"], buzz=0),
        "wave_low": effect(t["wave_pitch"], t["wave_gain"], grain=8600, noise=t["wave_noise"]),
        "wave_high": effect([p + 590 if p else 0 for p in t["wave_pitch"]], t["wave_gain"],
                            grain=8600, noise=t["wave_noise"]),
    }


def effects_module():
    lines = ["; Rail Gunner's sound effects for the GameTank: made by tools/gametank/make_sound.py",
             "; from the tables of src/cx16/audio_platform.p8.  Do not change by hand.",
             ";",
             "; An effect is the number of frames, the feedback of the channel's first",
             "; operator, and for every frame the loudness (0-15) and the note (0-107) of",
             "; the channel's four operators.",
             "",
             "sfxdata {",
             "%option overlay_data",
             ""]
    for name, data in effects().items():
        lines.append(name + ":")
        lines.append("    %asm {{")
        lines.append("        .byte " + ",".join(str(b) for b in data[:2]))
        for start in range(2, len(data), 8):
            lines.append("        .byte " + ",".join(str(b) for b in data[start:start + 8]))
        lines.append("    }}")
    lines += ["}", ""]
    return "\n".join(lines)


if __name__ == "__main__":
    song = song_bytes()
    (OUT / "song.bin").write_bytes(song)
    (OUT / "sfx_data.p8").write_text(effects_module())
    print("song.bin", len(song), "bytes;", "sfx_data.p8", sum(len(d) for d in effects().values()), "bytes of effects")
