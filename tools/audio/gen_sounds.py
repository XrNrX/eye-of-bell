"""Procedural sound effects and an ambient loop, written to res://audio/.

    python tools/audio/gen_sounds.py                 # everything
    python tools/audio/gen_sounds.py --only door_open
    python tools/audio/gen_sounds.py --out some/folder     # write somewhere else (used by the test)
    python tools/audio/gen_sounds.py --list

Like the art, the sound is generated from code (pure Python, no extra packages, seeded, so the
same command always writes the same files). Output is 22050 Hz, mono, 16-bit WAV:

    audio/sfx/<name>.wav          one-shots. Variants are named <name>_2.wav, <name>_3.wav ...;
                                  the game picks one at random when it plays <name>.
    audio/music/dungeon_drone.wav a 24 second loop that joins up with itself exactly.

To use a real recording instead, drop a WAV with the same name in the same folder (and keep it out
of the generator's way by deleting its entry from SOUNDS, or just don't re-run the generator).

How a sound is made: a few oscillators (sine, saw, triangle), filtered noise, an envelope, and
mixing at offsets, each a few lines in its recipe below. Every one-shot is faded in and out over a
few milliseconds so it never clicks, and scaled to its own peak level (the game adds a little
random pitch on top so repeats don't sound identical).
"""
import argparse
import math
import random
import struct
import sys
import wave
from pathlib import Path

HERE = Path(__file__).resolve().parent
PROJECT_ROOT = HERE.parent.parent
OUT_DIR = PROJECT_ROOT / "audio"
RATE = 22050
TAU = 2 * math.pi


# --------------------------------------------------------------------------
# Building blocks (signals are plain lists of floats in -1..1)
# --------------------------------------------------------------------------

def count(sec):
    return max(1, int(RATE * sec))


def osc(freq, sec, shape="sine", vibrato=0.0, vib_rate=6.0, phase=0.0):
    """A steady tone. freq may be a number or a function of time in seconds (a glide)."""
    out, ph = [], phase
    for i in range(count(sec)):
        t = i / RATE
        f = freq(t) if callable(freq) else freq
        if vibrato:
            f *= 1.0 + vibrato * math.sin(TAU * vib_rate * t)
        ph += f / RATE
        frac = ph % 1.0
        if shape == "sine":
            out.append(math.sin(TAU * ph))
        elif shape == "saw":
            out.append(2.0 * frac - 1.0)
        elif shape == "tri":
            out.append(4.0 * abs(frac - 0.5) - 1.0)
        elif shape == "square":
            out.append(1.0 if frac < 0.5 else -1.0)
        else:
            raise ValueError(shape)
    return out


def glide(f0, f1, sec, curve=2.0):
    """A frequency function that moves f0 -> f1 over `sec`, quickly at first (curve > 1)."""
    return lambda t: f1 + (f0 - f1) * max(0.0, 1.0 - t / sec) ** curve


def noise(sec, seed):
    rnd = random.Random(seed)
    return [rnd.uniform(-1.0, 1.0) for _ in range(count(sec))]


def lowpass(x, cutoff):
    a = 1.0 - math.exp(-TAU * cutoff / RATE)
    y, out = 0.0, []
    for s in x:
        y += a * (s - y)
        out.append(y)
    return out


def highpass(x, cutoff):
    return [s - l for s, l in zip(x, lowpass(x, cutoff))]


def bandpass(x, lo, hi):
    return highpass(lowpass(x, hi), lo)


def decay(x, tau, attack=0.002):
    """Exponential decay with a short attack ramp (a struck or plucked sound)."""
    out = []
    for i, s in enumerate(x):
        t = i / RATE
        out.append(s * math.exp(-t / tau) * min(1.0, t / attack if attack else 1.0))
    return out


def swell(x, attack, release):
    """Linear attack and release across the whole sound (a bowed or breathed sound)."""
    n = len(x)
    a, r = max(1, int(attack * RATE)), max(1, int(release * RATE))
    return [s * min(1.0, i / a, (n - 1 - i) / r) for i, s in enumerate(x)]


def tremolo(x, rate, depth):
    return [s * (1.0 - depth + depth * 0.5 * (1.0 + math.sin(TAU * rate * i / RATE))) for i, s in enumerate(x)]


def gain(x, g):
    return [s * g for s in x]


def mix(*layers):
    """Sum layers; each is a signal or a (signal, start_seconds) pair."""
    parts = [(l, 0.0) if not isinstance(l, tuple) else l for l in layers]
    n = max(int(RATE * off) + len(sig) for sig, off in parts)
    out = [0.0] * n
    for sig, off in parts:
        start = int(RATE * off)
        for i, s in enumerate(sig):
            out[start + i] += s
    return out


def finish(x, peak, fade_in=0.003, fade_out=0.012):
    """Fade the ends so it never clicks, then scale so the loudest sample is `peak`."""
    n = len(x)
    fi, fo = max(1, int(fade_in * RATE)), max(1, int(fade_out * RATE))
    x = [s * min(1.0, i / fi, (n - 1 - i) / fo) for i, s in enumerate(x)]
    top = max(abs(s) for s in x) or 1.0
    return [s * peak / top for s in x]


# --------------------------------------------------------------------------
# One-shots
# --------------------------------------------------------------------------

def thud(f0, f1, tau, sec, seed, grit=0.5, grit_cut=500):
    body = decay(osc(glide(f0, f1, sec * 0.6), sec), tau)
    return mix(body, gain(decay(lowpass(noise(sec, seed), grit_cut), tau * 0.6), grit))


def step(seed):
    return finish(thud(90, 45, 0.07, 0.2, seed, 0.5, 450), 0.5)


def turn():
    return finish(swell(gain(highpass(lowpass(noise(0.18, 3), 2500), 600), 1.0), 0.04, 0.12), 0.3)


def bump():
    return finish(thud(70, 35, 0.09, 0.24, 4, 0.6, 300), 0.7)


def door_open():
    creak = lowpass(osc(glide(120, 70, 1.0, 1.0), 1.0, "saw", vibrato=0.03, vib_rate=7), 900)
    rasp = gain(lowpass(noise(1.0, 5), 600), 0.5)
    return finish(swell(mix(creak, rasp), 0.12, 0.5), 0.6)


def portcullis():
    """A placeholder rattle: a grinding rumble with a run of clanking chain links."""
    grind = gain(lowpass(noise(1.3, 71), 500), 0.5)
    clanks = []
    for i in range(11):
        f = 700 + (i * 137) % 500
        clanks.append((decay(osc(f, 0.1, "square"), 0.025), 0.05 + 0.105 * i))
    return finish(swell(mix(grind, *clanks), 0.1, 0.35), 0.6)


def door_close():
    return finish(thud(80, 38, 0.12, 0.38, 6, 0.6, 700), 0.7)


def metal_click(seed):
    return mix(decay(bandpass(noise(0.05, seed), 1500, 3500), 0.012), gain(decay(osc(900, 0.05), 0.02), 0.4))


def door_locked():
    return finish(mix(metal_click(7), (metal_click(8), 0.09), (metal_click(9), 0.19)), 0.55)


def unlock():
    ring = mix(decay(osc(1400, 0.5), 0.12), gain(decay(osc(2100, 0.5), 0.08), 0.5))
    return finish(mix(metal_click(10), (metal_click(11), 0.07), (ring, 0.1)), 0.6)


def lever():
    return finish(mix(thud(120, 60, 0.05, 0.2, 12, 0.7, 900), (thud(90, 45, 0.07, 0.25, 13, 0.7, 700), 0.13)), 0.7)


def plate():
    return finish(mix(decay(osc(glide(260, 120, 0.15), 0.18), 0.06), gain(decay(noise(0.04, 14), 0.01), 0.4)), 0.5)


def pickup():
    return finish(mix(decay(osc(660, 0.1), 0.05), (decay(osc(990, 0.14), 0.07), 0.06)), 0.45)


def drop():
    return finish(thud(150, 90, 0.05, 0.16, 15, 0.5, 800), 0.5)


def swing():
    return finish(swell(highpass(lowpass(noise(0.24, 16), 3000), 500), 0.05, 0.16), 0.55)


def whiff():
    return finish(swell(highpass(noise(0.15, 17), 1200), 0.02, 0.1), 0.3)


def hit():
    return finish(mix(thud(180, 55, 0.06, 0.28, 18, 0.9, 1500)), 0.85)


def throw():
    return finish(mix(swell(highpass(noise(0.2, 19), 800), 0.03, 0.12), gain(decay(osc(1800, 0.12), 0.05), 0.2)), 0.5)


def monster_attack():
    return finish(swell(lowpass(osc(70, 0.38, "saw", vibrato=0.05, vib_rate=28), 500), 0.05, 0.2), 0.6)


def monster_hurt():
    return finish(mix(decay(osc(glide(320, 110, 0.25), 0.26, "tri"), 0.1), gain(decay(bandpass(noise(0.2, 20), 400, 1800), 0.05), 0.5)), 0.65)


def monster_die():
    return finish(tremolo(decay(osc(glide(380, 50, 0.7, 1.5), 0.75, "saw"), 0.3), 18, 0.5), 0.65)


def hero_hurt():
    return finish(mix(decay(osc(glide(240, 170, 0.2), 0.2, "tri"), 0.08), gain(decay(lowpass(noise(0.15, 21), 900), 0.04), 0.5)), 0.6)


def hero_die():
    return finish(lowpass(decay(osc(glide(300, 60, 0.9, 1.5), 0.95, "saw"), 0.45), 600), 0.7)


def potion():
    pops = []
    rnd = random.Random(22)
    for i in range(6):
        f0 = 350 + rnd.uniform(0, 150)
        pops.append((decay(osc(glide(f0, f0 * 2.2, 0.05), 0.07), 0.02), 0.06 * i + rnd.uniform(0, 0.02)))
    gulp = (decay(osc(glide(220, 110, 0.12), 0.15), 0.06), 0.5)
    return finish(mix(*pops, gulp), 0.5)


def zap():
    return finish(mix(decay(lowpass(osc(glide(1800, 250, 0.35), 0.38, "saw"), 3000), 0.15), gain(decay(highpass(noise(0.3, 23), 3000), 0.1), 0.3)), 0.6)


def fireball():
    """A rising rush of flame: breathy noise swelling up, with a low saw growl underneath."""
    rush = swell(bandpass(noise(0.55, 61), 300, 2200), 0.3, 0.2)
    growl = swell(lowpass(osc(glide(90, 200, 0.5, 0.6), 0.55, "saw"), 700), 0.25, 0.25)
    return finish(mix(rush, gain(growl, 0.6)), 0.6)


def explosion():
    """A boom: a sine dropping into the floor, a rumble of low noise, a crackle of embers."""
    boom = decay(osc(glide(150, 36, 0.35), 0.9), 0.3)
    rumble = decay(lowpass(noise(0.9, 41), 700), 0.28)
    crackle = decay(highpass(noise(0.7, 42), 2500), 0.09)
    return finish(mix(boom, gain(rumble, 0.9), gain(crackle, 0.3)), 0.85)


def chord_tone(freq, sec, tau):
    return mix(decay(osc(freq, sec), tau), gain(decay(osc(freq * 2, sec), tau * 0.6), 0.3))


def heal():
    return finish(mix(chord_tone(523.25, 0.5, 0.25), (chord_tone(659.25, 0.5, 0.25), 0.09), (chord_tone(783.99, 0.6, 0.3), 0.18)), 0.55)


def shield():
    a = mix(osc(520, 0.7), osc(524, 0.7), gain(osc(1040, 0.7), 0.3))
    return finish(tremolo(swell(a, 0.15, 0.5), 8, 0.4), 0.5)


def bless():
    a = mix(osc(392, 1.0), osc(493.88, 1.0), osc(587.33, 1.0), gain(osc(784, 1.0), 0.25))
    return finish(swell(a, 0.25, 0.55), 0.5)


def ui_click():
    return finish(mix(decay(osc(1200, 0.05), 0.012), gain(decay(osc(800, 0.05), 0.012), 0.5)), 0.35)


def ui_swap():
    return finish(mix(decay(osc(900, 0.05), 0.012), (decay(osc(1200, 0.06), 0.015), 0.055)), 0.4)


def save():
    return finish(mix(decay(osc(660, 0.12), 0.05), (decay(osc(880, 0.2), 0.08), 0.07)), 0.45)


def load():
    return finish(mix(decay(osc(880, 0.12), 0.05), (decay(osc(660, 0.2), 0.08), 0.07)), 0.45)


def level_complete():
    notes = [(392, 0.0, 0.14), (523.25, 0.14, 0.14), (659.25, 0.28, 0.14), (783.99, 0.42, 0.5)]
    layers = [(swell(mix(osc(f, d + 0.05, "tri"), gain(osc(f * 2, d + 0.05), 0.2)), 0.01, 0.06 if d < 0.2 else 0.3), t) for f, t, d in notes]
    return finish(mix(*layers), 0.55)


def game_over():
    notes = [(392, 0.0, 0.32), (349.23, 0.32, 0.32), (311.13, 0.64, 0.32), (261.63, 0.96, 0.9)]
    layers = [(swell(lowpass(osc(f, d + 0.05, "saw"), 1200), 0.02, d * 0.6), t) for f, t, d in notes]
    return finish(mix(*layers), 0.55)


# name -> (function, sound name -> files). A tuple of seeds makes variants (name, name_2, ...).
SOUNDS = {
    "step": (step, (30, 31, 32)),
    "turn": (turn, None), "bump": (bump, None),
    "door_open": (door_open, None), "door_close": (door_close, None), "door_locked": (door_locked, None),
    "unlock": (unlock, None), "lever": (lever, None), "plate": (plate, None),
    "pickup": (pickup, None), "drop": (drop, None),
    "swing": (swing, None), "whiff": (whiff, None), "hit": (hit, None), "throw": (throw, None),
    "monster_attack": (monster_attack, None), "monster_hurt": (monster_hurt, None), "monster_die": (monster_die, None),
    "hero_hurt": (hero_hurt, None), "hero_die": (hero_die, None),
    "potion": (potion, None), "zap": (zap, None), "heal": (heal, None), "shield": (shield, None), "bless": (bless, None), "portcullis": (portcullis, None), "fireball": (fireball, None), "explosion": (explosion, None),
    "ui_click": (ui_click, None), "ui_swap": (ui_swap, None), "save": (save, None), "load": (load, None),
    "level_complete": (level_complete, None), "game_over": (game_over, None),
}


# --------------------------------------------------------------------------
# The ambient loop
# --------------------------------------------------------------------------

LOOP_SECONDS = 24


def dungeon_drone():
    """Low humming chord, a faint wind and a few drips. Every tone completes a whole number of
    cycles in the loop, and so does every slow swell, so the last sample runs straight into the first
    with no seam."""
    n = RATE * LOOP_SECONDS
    rnd = random.Random(40)

    def exact(f):  # The nearest frequency with a whole number of cycles in the loop.
        return round(f * LOOP_SECONDS) / LOOP_SECONDS

    tones = []  # (frequency, amplitude, swell cycles per loop, phase)
    for f, a in ((55, 0.5), (82.5, 0.3), (110.0, 0.2), (164.5, 0.12), (220, 0.06)):
        tones.append((exact(f), a, rnd.randint(1, 3), rnd.uniform(0, 1)))
    for _ in range(16):  # The wind: many quiet tones, each swelling on its own slow cycle.
        tones.append((exact(rnd.uniform(140, 800)), rnd.uniform(0.01, 0.03), rnd.randint(1, 6), rnd.uniform(0, 1)))
    out = [0.0] * n
    for f, a, m, ph in tones:
        for i in range(n):
            t = i / RATE
            swell_ = 0.65 + 0.35 * math.sin(TAU * (m * t / LOOP_SECONDS + ph))
            out[i] += a * swell_ * math.sin(TAU * (f * t + ph))
    for when, freq in ((4.2, 1380), (11.7, 1210), (19.3, 1560)):  # Drips: a ping and two fading echoes.
        for k, level in enumerate((1.0, 0.35, 0.12)):
            ping = decay(osc(freq, 0.6), 0.07)
            start = int((when + 0.23 * k) * RATE)
            for i, s in enumerate(ping):
                out[start + i] += 0.12 * level * s
    top = max(abs(s) for s in out)
    return [s * 0.5 / top for s in out]


# --------------------------------------------------------------------------
# Writing
# --------------------------------------------------------------------------

def write_wav(path, samples):
    path.parent.mkdir(parents=True, exist_ok=True)
    data = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    return path


def build(out=OUT_DIR, only=None):
    """Write every sound (or just `only`). Returns the paths written."""
    out = Path(out)
    written = []
    for name, (fn, seeds) in SOUNDS.items():
        if only and only != name:
            continue
        if seeds:
            for i, seed in enumerate(seeds):
                suffix = "" if i == 0 else f"_{i + 1}"
                written.append(write_wav(out / "sfx" / f"{name}{suffix}.wav", fn(seed)))
        else:
            written.append(write_wav(out / "sfx" / f"{name}.wav", fn()))
    if not only or only == "dungeon_drone":
        written.append(write_wav(out / "music" / "dungeon_drone.wav", dungeon_drone()))
    return written


def main(argv=None):
    ap = argparse.ArgumentParser(description="Generate the game's sound effects and ambient loop.")
    ap.add_argument("--only", help="just this sound (a name from --list)")
    ap.add_argument("--out", default=str(OUT_DIR), help="output folder (default: audio/ in the project)")
    ap.add_argument("--list", action="store_true", help="list the sound names and exit")
    args = ap.parse_args(argv)
    if args.list:
        print("\n".join(sorted(list(SOUNDS) + ["dungeon_drone"])))
        return 0
    paths = build(args.out, args.only)
    for p in paths:
        print(f"    wrote {p.relative_to(PROJECT_ROOT) if PROJECT_ROOT in p.parents else p}")
    print(f"{len(paths)} file(s)")
    return 0 if paths else 1


if __name__ == "__main__":
    sys.exit(main())
