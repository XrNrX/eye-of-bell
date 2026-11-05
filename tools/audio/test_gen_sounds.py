"""Self-test for the sound generator:   python tools/audio/test_gen_sounds.py
Writes only to a temporary folder."""
import hashlib
import struct
import sys
import tempfile
import wave
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import gen_sounds as gs  # noqa: E402

failed = 0


def check(name, cond):
    global failed
    print(("PASS  " if cond else "FAIL  ") + name)
    failed += 0 if cond else 1


def read(path):
    with wave.open(str(path), "rb") as w:
        n = w.getnframes()
        raw = w.readframes(n)
        return (w.getnchannels(), w.getsampwidth(), w.getframerate(), n), [v / 32768.0 for v in struct.unpack("<%dh" % n, raw)]


def digest(folder):
    return {p.relative_to(folder).as_posix(): hashlib.sha1(p.read_bytes()).hexdigest() for p in sorted(folder.rglob("*.wav"))}


with tempfile.TemporaryDirectory() as t:
    a, b = Path(t) / "a", Path(t) / "b"
    paths = gs.build(a)
    gs.build(b)
    check("the same command writes identical files twice (seeded)", digest(a) == digest(b))
    names = {p.stem for p in (a / "sfx").glob("*.wav")}
    check("every sound in the table was written", all(n in names for n in gs.SOUNDS))
    check("variants exist: step, step_2, step_3", {"step", "step_2", "step_3"} <= names)
    check("the ambient loop was written", (a / "music" / "dungeon_drone.wav").exists())

    bad_format, bad_len, bad_peak, bad_edge, bad_dc, silent = [], [], [], [], [], []
    for p in (a / "sfx").glob("*.wav"):
        fmt, s = read(p)
        if fmt[:3] != (1, 2, 22050):
            bad_format.append(p.name)
        sec = fmt[3] / fmt[2]
        if not 0.03 <= sec <= 2.0:
            bad_len.append((p.name, round(sec, 2)))
        peak = max(abs(v) for v in s)
        if not 0.25 <= peak <= 0.9:
            bad_peak.append((p.name, round(peak, 2)))
        if abs(s[0]) > 0.02 or abs(s[-1]) > 0.02:
            bad_edge.append(p.name)
        if abs(sum(s) / len(s)) > 0.05:
            bad_dc.append(p.name)
        if sum(v * v for v in s) / len(s) < 1e-4:
            silent.append(p.name)
    check("every effect is mono, 16-bit, 22050 Hz %s" % bad_format, not bad_format)
    check("every effect lasts between 0.03 and 2 seconds %s" % bad_len, not bad_len)
    check("every effect peaks between 0.25 and 0.9 (loud enough, never clipping) %s" % bad_peak, not bad_peak)
    check("every effect starts and ends at silence, so it never clicks %s" % bad_edge, not bad_edge)
    check("no effect has a DC offset %s" % bad_dc, not bad_dc)
    check("no effect is silent %s" % silent, not silent)

    fmt, d = read(a / "music" / "dungeon_drone.wav")
    check("the loop is %d seconds of mono 16-bit 22050 Hz" % gs.LOOP_SECONDS, fmt == (1, 2, 22050, 22050 * gs.LOOP_SECONDS))
    check("the loop is quiet (peak 0.5) so it sits under the effects", 0.45 <= max(abs(v) for v in d) <= 0.55)
    step = max(abs(d[i + 1] - d[i]) for i in range(0, len(d) - 1, 7))
    seam = abs(d[0] - d[-1])
    check("the loop joins itself: the jump from its last sample to its first (%.4f) is no bigger than a normal step (%.4f)" % (seam, step), seam <= step * 1.5 + 1e-4)
    check("the loop has no click at the seam: the 20 samples either side are as smooth as the rest", max(abs(d[i + 1] - d[i]) for i in range(len(d) - 20, len(d) - 1)) <= step * 1.5 + 1e-4)

    # A step is different from a heavier sound by its low end; a rough sanity check of character.
    _, st = read(a / "sfx" / "step.wav")
    _, zp = read(a / "sfx" / "zap.wav")
    def zero_crossings(x):
        return sum(1 for i in range(len(x) - 1) if (x[i] < 0) != (x[i + 1] < 0)) / (len(x) / 22050)
    check("a step is lower pitched than a zap (fewer zero crossings per second)", zero_crossings(st) < zero_crossings(zp))
    check("variants differ from each other", digest(a)["sfx/step.wav"] != digest(a)["sfx/step_2.wav"])

    only = Path(t) / "only"
    gs.build(only, only="door_open")
    check("--only writes just that sound", [p.name for p in only.rglob("*.wav")] == ["door_open.wav"])

print()
print("All good." if not failed else f"{failed} failed.")
sys.exit(1 if failed else 0)
