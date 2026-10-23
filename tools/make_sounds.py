#!/usr/bin/env python3
"""Synthesises the sound effects and the music of THE DESCENT into projects/dungeon_crawler/sounds/*.wav (16 bit PCM, mono). Pure Python, no libraries, deterministic (a seeded generator).
The engine has no sample streaming or mixer (docs/AUDIO.md "Not built"): `sound.play` starts a whole file, so the music is short loops that game/music.lua restarts at their length, by area:
beds of 16 seconds (lobby, dungeon, ballroom waltz, cave, safe room, boss) and a 7 second percussion layer for fights that is played on top.
usage: tools/make_sounds.py [OUT_DIR] [--only name ...]"""
import math, os, random, struct, sys, wave

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SR = 22050      # effects
MR = 16000      # music

rnd = random.Random(4471902)

# ------------------------------------------------------------------------------------------------------------------------------------------ small synth kit
def n2f(name):
    """'C4' 'F#3' 'Bb2' -> Hz"""
    notes = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    base = notes[name[0]]
    i = 1
    if len(name) > 2 and name[1] in "#b": base += 1 if name[1] == "#" else -1; i = 2
    octave = int(name[i:])
    return 440.0 * 2 ** ((base - 9 + (octave - 4) * 12) / 12.0)

def env(i, n, a=0.01, d=0.1, s=0.6, r=0.1, sr=SR):
    t = i / sr; total = n / sr
    if t < a: return t / a
    if t < a + d: return 1 - (1 - s) * (t - a) / d
    if t < total - r: return s
    return max(0.0, s * (total - t) / r)

def tone(freq, dur, shape="sine", sr=SR, vol=1.0, a=0.005, d=0.08, s=0.7, r=0.08, vib=0.0, slide=0.0, duty=0.5):
    n = int(dur * sr)
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        t = i / sr
        f = freq * (1 + slide * t / max(dur, 1e-6)) * (1 + vib * math.sin(2 * math.pi * 5.5 * t))
        ph += f / sr
        x = ph % 1.0
        if shape == "sine": v = math.sin(2 * math.pi * x)
        elif shape == "square": v = 1.0 if x < duty else -1.0
        elif shape == "saw": v = 2 * x - 1
        elif shape == "tri": v = 4 * abs(x - 0.5) - 1
        elif shape == "noise": v = rnd.uniform(-1, 1)
        else: v = 0.0
        out[i] = v * vol * env(i, n, a, d, s, r, sr)
    return out

def noise(dur, sr=SR, vol=1.0, a=0.002, d=0.05, s=0.5, r=0.05):
    n = int(dur * sr)
    return [rnd.uniform(-1, 1) * vol * env(i, n, a, d, s, r, sr) for i in range(n)]

def lowpass(x, cutoff, sr=SR):
    a = 1 - math.exp(-2 * math.pi * cutoff / sr)
    y, out = 0.0, []
    for v in x:
        y += a * (v - y); out.append(y)
    return out

def highpass(x, cutoff, sr=SR):
    lp = lowpass(x, cutoff, sr)
    return [v - l for v, l in zip(x, lp)]

def bandpass(x, lo, hi, sr=SR): return lowpass(highpass(x, lo, sr), hi, sr)

def sweep_lp(x, f0, f1, sr=SR):
    n = len(x); y = 0.0; out = []
    for i, v in enumerate(x):
        c = f0 + (f1 - f0) * i / max(1, n - 1)
        a = 1 - math.exp(-2 * math.pi * c / sr)
        y += a * (v - y); out.append(y)
    return out

def mix(*tracks, offsets=None):
    n = 0
    offs = offsets or [0] * len(tracks)
    for t, o in zip(tracks, offs): n = max(n, len(t) + o)
    out = [0.0] * n
    for t, o in zip(tracks, offs):
        for i, v in enumerate(t): out[i + o] += v
    return out

def gain(x, g): return [v * g for v in x]
def sat(x, k=2.0): return [math.tanh(v * k) / math.tanh(k) for v in x]
def fade(x, n_in=0.005, n_out=0.01, sr=SR):
    a, b = int(n_in * sr), int(n_out * sr)
    for i in range(min(a, len(x))): x[i] *= i / a
    for i in range(min(b, len(x))): x[-1 - i] *= i / b
    return x
def concat(*tracks): return [v for t in tracks for v in t]
def silence(dur, sr=SR): return [0.0] * int(dur * sr)

def peak_norm(x, peak=0.9):
    m = max(abs(v) for v in x) or 1
    return [v * peak / m for v in x]

def write_chunks(name, x, out_dir, sr=MR, chunk=2.0, overlap=0.12, norm=0.8):
    """(unused since phase 3: `sound.play{ loop = true, bus = "music" }` plays a whole file in a loop) Music as 2 second pieces.
    Every piece carries `overlap` seconds of the next one, faded out, and starts with a fade in of the same length: the sum is the original."""
    x = peak_norm(x, norm)
    n, o = int(chunk * sr), int(overlap * sr)
    count = len(x) // n
    for k in range(count):
        piece = list(x[k * n:(k + 1) * n + o])
        if len(piece) < n + o: piece += x[:n + o - len(piece)]           # the loop wraps
        for i in range(o):
            piece[len(piece) - 1 - i] *= i / o                           # the tail fades out
            piece[i] *= i / o                                            # the head fades in
        if k == 0 and name == "m_victory": pass
        write("%s_%d" % (name, k + 1), piece, out_dir, sr=sr, norm=0)
    return count

def write(name, x, out_dir, sr=SR, norm=0.9):
    x = peak_norm(x, norm) if norm else x
    path = os.path.join(out_dir, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32000)) for v in x))
    return len(x) / sr

# ------------------------------------------------------------------------------------------------------------------------------------------ effects
def voice_blip():
    # a robotic syllable: a square wave with a formant-ish band, a quick pitch dip
    x = tone(310, 0.075, "square", a=0.004, d=0.02, s=0.8, r=0.03, slide=-0.18, duty=0.35)
    y = tone(930, 0.075, "saw", a=0.004, d=0.02, s=0.4, r=0.03, vol=0.35)
    return fade(mix(x, y), 0.003, 0.01)

def honk_blip():
    x = tone(260, 0.08, "saw", a=0.004, d=0.02, s=0.7, r=0.03, slide=0.25)
    return fade(bandpass(x, 300, 1800), 0.003, 0.01)

def honk():
    x = mix(tone(330, 0.12, "saw", vol=1, a=0.01, d=0.03, s=0.9, r=0.02, slide=0.1), tone(300, 0.2, "saw", vol=1, a=0.01, d=0.05, s=0.8, r=0.08, slide=-0.2))
    first = bandpass(tone(340, 0.13, "saw", a=0.01, d=0.03, s=0.9, r=0.02, slide=0.08), 350, 2400)
    second = bandpass(tone(300, 0.26, "saw", a=0.01, d=0.05, s=0.85, r=0.1, slide=-0.25), 300, 2200)
    return fade(concat(first, silence(0.03), second), 0.003, 0.02)

def honk_bite(): return fade(mix(sat(noise(0.09, vol=0.9, d=0.03, s=0.2), 2), tone(1400, 0.1, "square", vol=0.3, a=0.002, d=0.04, s=0.2, slide=-0.5)), 0.001, 0.02)

def swing(): return fade(sweep_lp(noise(0.26, vol=0.8, a=0.05, d=0.1, s=0.5, r=0.1), 400, 4200), 0.01, 0.05)
def hit(): return fade(mix(tone(150, 0.14, "sine", vol=1.0, a=0.001, d=0.05, s=0.3, slide=-0.55), lowpass(noise(0.1, vol=0.9, d=0.03, s=0.1), 2500)), 0.001, 0.02)
def hit_crit(): return fade(mix(hit(), tone(1760, 0.25, "tri", vol=0.45, a=0.001, d=0.1, s=0.3, r=0.1), tone(2217, 0.2, "tri", vol=0.3, a=0.001, d=0.1, s=0.2, r=0.08)), 0.001, 0.05)
def hurt(): return fade(mix(tone(110, 0.28, "sine", a=0.001, d=0.12, s=0.4, slide=-0.5), lowpass(noise(0.2, vol=0.8, d=0.06, s=0.2), 900), tone(220, 0.2, "saw", vol=0.2, a=0.001, d=0.1, s=0.2, slide=-0.4)), 0.001, 0.05)

def squish():
    x = []
    for k in range(3):
        x = mix(x, lowpass(tone(380 - k * 60, 0.09, "sine", a=0.003, d=0.04, s=0.3, slide=-0.5), 900), offsets=[0, 0] if False else None) if False else x
    pop1 = tone(420, 0.09, "sine", a=0.002, d=0.04, s=0.2, slide=-0.6)
    pop2 = tone(300, 0.1, "sine", a=0.002, d=0.04, s=0.2, slide=-0.6)
    return fade(mix(pop1, lowpass(noise(0.12, vol=0.4, d=0.05, s=0.1), 1800), pop2, offsets=[0, 0, 1100]), 0.001, 0.02)
def squish_die():
    parts = [tone(500 - k * 70, 0.1, "sine", a=0.002, d=0.04, s=0.3, slide=-0.6) for k in range(5)]
    return fade(mix(*parts, lowpass(noise(0.4, vol=0.4, a=0.02, d=0.2, s=0.3, r=0.1), 1500), offsets=[0, 1500, 3000, 4500, 6000, 0]), 0.001, 0.05)
def bone():
    parts = [bandpass(noise(0.05, vol=1.0, d=0.015, s=0.1, r=0.02), 900 + 400 * k, 3000 + 500 * k) for k in range(3)]
    return fade(mix(*parts, offsets=[0, 800, 1700]), 0.001, 0.01)
def bone_die():
    parts = [bandpass(noise(0.06, vol=1.0, d=0.02, s=0.1, r=0.02), 700 + rnd.randint(0, 1200), 2500 + rnd.randint(0, 2000)) for k in range(9)]
    return fade(mix(*parts, offsets=[int(i * 0.05 * SR + rnd.randint(0, 600)) for i in range(9)]), 0.001, 0.05)
def goblin_hit(): return fade(bandpass(tone(430, 0.18, "saw", a=0.005, d=0.05, s=0.5, r=0.08, slide=-0.45, vib=0.02), 400, 2000), 0.003, 0.03)
def goblin_die(): return fade(bandpass(tone(520, 0.45, "saw", a=0.01, d=0.1, s=0.6, r=0.2, slide=-0.7, vib=0.03), 350, 2200), 0.003, 0.05)
def squeak(): return fade(tone(2100, 0.09, "sine", a=0.003, d=0.03, s=0.5, slide=0.3) + tone(2500, 0.07, "sine", a=0.002, d=0.03, s=0.4, slide=-0.2), 0.002, 0.01)
def squeak_die(): return fade(tone(2300, 0.28, "sine", a=0.003, d=0.1, s=0.5, slide=-0.7, vib=0.04), 0.002, 0.05)
def spit(): return fade(mix(tone(300, 0.18, "sine", a=0.004, d=0.06, s=0.3, slide=1.6), lowpass(noise(0.16, vol=0.5, a=0.01, d=0.06, s=0.2), 2600)), 0.002, 0.04)
def boss_hit(): return fade(mix(tone(90, 0.22, "saw", vol=0.7, a=0.002, d=0.08, s=0.3, slide=-0.5), hit()), 0.001, 0.04)
def boss_roar():
    x = tone(72, 1.3, "saw", a=0.15, d=0.3, s=0.8, r=0.5, vib=0.06, vol=1.0)
    am = [v * (0.65 + 0.35 * math.sin(2 * math.pi * 17 * i / SR)) for i, v in enumerate(x)]
    return fade(mix(sat(lowpass(am, 700), 2.5), lowpass(noise(1.3, vol=0.5, a=0.2, d=0.3, s=0.6, r=0.5), 1400)), 0.01, 0.1)
def boss_die():
    x = tone(95, 2.2, "saw", a=0.05, d=0.5, s=0.7, r=1.0, slide=-0.75, vib=0.05)
    return fade(mix(sat(lowpass(x, 600), 2), lowpass(noise(2.2, vol=0.5, a=0.05, d=0.8, s=0.3, r=1.0), 900), tone(48, 2.2, "sine", vol=0.8, a=0.02, d=0.8, s=0.5, r=1.0)), 0.01, 0.1)
def boss_stinger():
    ch = [tone(n2f(n), 1.6, "saw", vol=0.35, a=0.01, d=0.3, s=0.5, r=0.7) for n in ("C2", "G2", "Eb3", "G3", "C4")]
    return fade(sat(lowpass(mix(*ch, tone(n2f("C1"), 1.6, "sine", vol=1.0, a=0.01, d=0.4, s=0.6, r=0.6)), 2200), 2.0), 0.005, 0.1)
def slam(): return fade(mix(tone(60, 0.6, "sine", a=0.001, d=0.25, s=0.3, r=0.2, slide=-0.6), lowpass(noise(0.55, vol=0.9, d=0.2, s=0.1, r=0.2), 700)), 0.001, 0.08)
def explosion(): return fade(mix(sweep_lp(noise(1.0, vol=1.0, a=0.003, d=0.4, s=0.2, r=0.5), 3000, 150), tone(55, 0.9, "sine", a=0.001, d=0.4, s=0.3, r=0.3, slide=-0.5)), 0.001, 0.1)
def rumble(): return fade(mix(lowpass(noise(1.6, vol=1.0, a=0.3, d=0.3, s=0.8, r=0.7), 220), tone(38, 1.6, "sine", a=0.3, d=0.3, s=0.8, r=0.7, vib=0.04)), 0.01, 0.1)
def levelup():
    notes = ["C5", "E5", "G5", "C6", "E6"]
    return fade(concat(*[tone(n2f(n), 0.14, "square", vol=0.5, a=0.004, d=0.04, s=0.6, r=0.04, duty=0.3) for n in notes[:-1]], tone(n2f(notes[-1]), 0.5, "square", vol=0.5, a=0.004, d=0.1, s=0.6, r=0.25, duty=0.3)), 0.002, 0.05)
def achievement():
    a = tone(n2f("E5"), 0.2, "tri", a=0.002, d=0.08, s=0.5, r=0.1) + tone(n2f("G5"), 0.2, "tri", a=0.002, d=0.08, s=0.5, r=0.1) + tone(n2f("C6"), 0.6, "tri", a=0.002, d=0.15, s=0.5, r=0.4)
    b = mix(tone(n2f("C6"), 0.9, "sine", vol=0.4, a=0.002, d=0.3, s=0.2, r=0.5), tone(n2f("E6"), 0.9, "sine", vol=0.25, a=0.002, d=0.3, s=0.2, r=0.5), offsets=[int(0.3 * SR)] * 2)
    return fade(mix(a, b), 0.002, 0.08)
def checkpoint(): return fade(mix(tone(n2f("G5"), 0.6, "sine", vol=0.6, a=0.003, d=0.3, s=0.2, r=0.3), tone(n2f("D6"), 0.6, "sine", vol=0.4, a=0.003, d=0.3, s=0.2, r=0.3), tone(n2f("G6"), 0.5, "sine", vol=0.25, a=0.003, d=0.3, s=0.1, r=0.3)), 0.002, 0.1)
def coin(): return fade(concat(tone(n2f("B5"), 0.07, "square", vol=0.45, a=0.002, d=0.03, s=0.5, r=0.02, duty=0.4), tone(n2f("E6"), 0.22, "square", vol=0.45, a=0.002, d=0.06, s=0.4, r=0.12, duty=0.4)), 0.001, 0.03)
def pickup(): return fade(tone(520, 0.14, "sine", vol=0.8, a=0.002, d=0.05, s=0.4, r=0.05, slide=1.0), 0.001, 0.02)
def crate_open():
    creak = bandpass(tone(180, 0.45, "saw", vol=0.7, a=0.05, d=0.1, s=0.7, r=0.15, slide=0.6, vib=0.05), 200, 1200)
    spark = concat(*[tone(n2f(n), 0.08, "sine", vol=0.5, a=0.002, d=0.04, s=0.3, r=0.02) for n in ("G5", "B5", "D6", "G6", "B6")])
    return fade(mix(creak, spark, offsets=[0, int(0.4 * SR)]), 0.002, 0.08)
def equip(): return fade(mix(bandpass(noise(0.06, vol=0.9, d=0.02, s=0.1), 1500, 6000), tone(1200, 0.12, "sine", vol=0.3, a=0.001, d=0.05, s=0.2, r=0.05)), 0.001, 0.02)
def heal(): return fade(mix(tone(n2f("C5"), 0.5, "sine", vol=0.5, a=0.1, d=0.1, s=0.5, r=0.2, slide=0.5), tone(n2f("G5"), 0.5, "sine", vol=0.4, a=0.15, d=0.1, s=0.5, r=0.2, slide=0.5)), 0.01, 0.1)
def ui_click(): return fade(tone(900, 0.04, "square", vol=0.4, a=0.001, d=0.015, s=0.3, r=0.01), 0.001, 0.005)
def ui_open(): return fade(tone(500, 0.14, "square", vol=0.35, a=0.002, d=0.05, s=0.4, r=0.05, slide=0.6, duty=0.3), 0.001, 0.02)
def death():
    notes = [("G3", 0.35), ("Gb3", 0.35), ("F3", 0.35), ("E3", 1.0)]
    return fade(concat(*[bandpass(tone(n2f(n), d, "saw", vol=0.8, a=0.03, d=0.1, s=0.7, r=0.1, vib=0.05), 150, 2200) for n, d in notes]), 0.003, 0.1)
def lever(): return fade(mix(tone(90, 0.18, "square", vol=0.7, a=0.001, d=0.06, s=0.3, slide=-0.4), bandpass(noise(0.25, vol=0.5, d=0.1, s=0.1), 400, 2400)), 0.001, 0.04)
def trap_click(): return fade(mix(tone(1800, 0.03, "square", vol=0.5, a=0.001, d=0.01, s=0.2, r=0.01), bandpass(noise(0.05, vol=0.7, d=0.02, s=0.1), 2000, 6000)), 0.001, 0.01)
def sweep(): return fade(mix(sweep_lp(noise(0.4, vol=0.8, a=0.05, d=0.1, s=0.5, r=0.2), 300, 3000), bandpass(noise(0.3, vol=0.4, a=0.1, d=0.1, s=0.3, r=0.1), 2000, 7000)), 0.01, 0.05)
def firebolt(): return fade(mix(sweep_lp(noise(0.5, vol=0.9, a=0.02, d=0.2, s=0.5, r=0.2), 500, 5000), tone(180, 0.5, "saw", vol=0.3, a=0.01, d=0.2, s=0.3, r=0.2, slide=1.4)), 0.005, 0.1)
def chord(): return fade(sat(mix(*[tone(n2f(n), 0.9, "saw", vol=0.3, a=0.005, d=0.2, s=0.6, r=0.4, vib=0.01) for n in ("E3", "B3", "E4", "G#4")]), 1.8), 0.002, 0.1)
def audit(): return fade(mix(tone(130, 0.18, "square", vol=0.7, a=0.001, d=0.06, s=0.3, slide=-0.4), tone(n2f("A6"), 0.5, "sine", vol=0.3, a=0.002, d=0.2, s=0.2, r=0.25), offsets=[0, int(0.12 * SR)]), 0.001, 0.08)

EFFECTS = [voice_blip, honk_blip, honk, honk_bite, swing, hit, hit_crit, hurt, squish, squish_die, bone, bone_die, goblin_hit, goblin_die, squeak, squeak_die, spit, boss_hit, boss_roar, boss_die,
           boss_stinger, slam, explosion, rumble, levelup, achievement, checkpoint, coin, pickup, crate_open, equip, heal, ui_click, ui_open, death, lever, trap_click, sweep, firebolt, chord, audit]

# ------------------------------------------------------------------------------------------------------------------------------------------ music
class Track:
    def __init__(self, seconds, sr=MR):
        self.sr = sr; self.n = int(seconds * sr); self.buf = [0.0] * self.n
    def add(self, samples, t, vol=1.0):
        i0 = int(t * self.sr)
        for k, v in enumerate(samples):
            j = i0 + k
            if j >= self.n: j -= self.n          # wrap: a loop
            self.buf[j] += v * vol

def note(freq, dur, kind, sr=MR, vol=1.0):
    n = int(dur * sr)
    out = [0.0] * n
    ph = ph2 = 0.0
    for i in range(n):
        t = i / sr
        ph += freq / sr; x = ph % 1.0
        if kind == "pluck":
            e = math.exp(-5.0 * t); v = (2 * x - 1) * 0.6 + math.sin(2 * math.pi * x * 2) * 0.3
            v *= e
        elif kind == "lead":
            e = env(i, n, 0.01, 0.06, 0.7, 0.08, sr); v = (1.0 if x < 0.3 else -1.0) * 0.6 * e
        elif kind == "brass":
            e = env(i, n, 0.04, 0.1, 0.8, 0.1, sr); ph2 += freq * 1.003 / sr
            v = ((2 * x - 1) + (2 * (ph2 % 1.0) - 1)) * 0.4 * e
        elif kind == "bass":
            e = env(i, n, 0.005, 0.1, 0.7, 0.05, sr); v = (math.sin(2 * math.pi * x) * 0.8 + (2 * x - 1) * 0.2) * e
        elif kind == "pad":
            e = env(i, n, 0.5, 0.3, 0.8, 0.6, sr); ph2 += freq * 1.005 / sr
            v = ((2 * x - 1) + (2 * (ph2 % 1.0) - 1)) * 0.3 * e
        elif kind == "bell":
            e = math.exp(-2.2 * t); v = (math.sin(2 * math.pi * x) + 0.5 * math.sin(2 * math.pi * x * 2.76)) * 0.5 * e
        elif kind == "box":
            e = math.exp(-3.5 * t); v = (math.sin(2 * math.pi * x) + 0.3 * math.sin(2 * math.pi * x * 3)) * 0.6 * e
        else: v = 0
        out[i] = v * vol
    return out

def kick(sr=MR):
    n = int(0.25 * sr); return [math.sin(2 * math.pi * (45 * (1 - math.exp(-i / sr * 18)) * 1 + 50) * (i / sr)) * math.exp(-i / sr * 14) for i in range(n)]
def snare(sr=MR):
    n = int(0.18 * sr); return [(rnd.uniform(-1, 1) * 0.7 + math.sin(2 * math.pi * 190 * i / sr) * 0.3) * math.exp(-i / sr * 22) for i in range(n)]
def hat(sr=MR):
    n = int(0.05 * sr); return [rnd.uniform(-1, 1) * math.exp(-i / sr * 70) * 0.4 for i in range(n)]
def tom(sr=MR, f=110):
    n = int(0.3 * sr); return [math.sin(2 * math.pi * f * (1 - 0.3 * i / n) * i / sr) * math.exp(-i / sr * 10) for i in range(n)]

def finish(track):
    x = lowpass(track.buf, 5500, track.sr)
    return sat(x, 1.3)

def beat_time(bpm): return 60.0 / bpm

def music_lobby():
    """The show's jingle: a bright 4/4 march in C, a brass lead over a bouncing bass, a hat on the off-beats (8 bars at 120 BPM)."""
    bpm = 120; b = beat_time(bpm); T = Track(16.0)
    chords = ["C", "F", "G", "C", "A", "F", "G", "G"]
    roots = {"C": "C3", "F": "F3", "G": "G3", "A": "A3"}
    mel = [("E5", 1), ("G5", 1), ("C6", 2), ("A5", 1), ("F5", 1), ("A5", 2), ("G5", 1), ("B5", 1), ("D6", 2), ("C6", 2), ("G5", 2),
           ("A5", 1), ("C6", 1), ("E6", 2), ("F5", 1), ("A5", 1), ("C6", 2), ("D6", 1), ("B5", 1), ("G5", 2), ("G5", 1), ("A5", 1), ("B5", 2)]
    t = 0.0
    for bar, ch in enumerate(chords):
        root = roots[ch]
        for k in range(4):
            T.add(note(n2f(root), b * 0.9, "bass", vol=0.5), (bar * 4 + k) * b)
            T.add(hat(), (bar * 4 + k) * b + b / 2, 0.5)
        T.add(kick(), bar * 4 * b, 0.8); T.add(kick(), (bar * 4 + 2) * b, 0.8); T.add(snare(), (bar * 4 + 1) * b, 0.5); T.add(snare(), (bar * 4 + 3) * b, 0.5)
    t = 0.0
    for nme, beats in mel:
        T.add(note(n2f(nme), b * beats * 0.95, "brass", vol=0.45), t); t += b * beats
    return finish(T)

def music_dungeon():
    """A low drone in A minor, a sparse plucked figure, a slow heartbeat (16 s)."""
    T = Track(16.0)
    for n, t in (("A2", 0), ("E3", 0), ("F2", 8), ("C3", 8)):
        T.add(note(n2f(n), 8.2, "pad", vol=0.55), t)
    fig = ["A3", "C4", "E4", "C4", "A3", "E4", "G4", "E4"]
    for i in range(16):
        if i % 2 == 0 or i in (3, 7, 11): T.add(note(n2f(fig[i % 8] if i < 8 else ["F3", "A3", "C4", "A3", "F3", "C4", "E4", "C4"][i - 8]), 0.6, "pluck", vol=0.35), i * 1.0)
    for i in range(16): T.add(kick(), i * 1.0, 0.45)
    return finish(T)

def music_ballroom_unused():
    b = 0.5; T = Track(16.0)
    prog = [("D3", ["F4", "A4", "D5"]), ("G2", ["G4", "B4", "D5"]), ("A2", ["E4", "A4", "C#5"]), ("D3", ["F4", "A4", "D5"]),
            ("B2", ["F#4", "B4", "D5"]), ("E3", ["G4", "B4", "E5"]), ("A2", ["A4", "C#5", "E5"]), ("A2", ["E4", "G4", "A4"])]
    for bar, (root, chord) in enumerate(prog):
        t0 = bar * 3 * b * 1.0
        T.add(note(n2f(root), b * 0.9, "bass", vol=0.6), t0)
        for k in (1, 2):
            for n in chord: T.add(note(n2f(n), b * 0.6, "pluck", vol=0.22), t0 + k * b)
    mel = ["A5", "D6", "F6", "E6", "D6", "B5", "G5", "B5", "D6", "C#6", "E6", "A5", "F6", "A5", "D6", "B5", "D6", "F#6", "E6", "G6", "B5", "C#6", "E6", "A5"]
    # 24 notes over 8 bars of 3 beats (one per beat), half-length so that the loop is 16 s with b = 0.5 / 1.5 s a bar: shift to a bar = 2 s
    return finish(T)

def music_ballroom():
    """The waltz of the Zero-G Ballroom: 3/4, a music box over an oom-pah-pah (8 bars of 2 s = 16 s)."""
    prog = [("D3", ["F4", "A4", "D5"]), ("G2", ["G4", "B4", "D5"]), ("A2", ["E4", "A4", "C#5"]), ("D3", ["F4", "A4", "D5"]),
            ("B2", ["F#4", "B4", "D5"]), ("E3", ["G4", "B4", "E5"]), ("A2", ["A4", "C#5", "E5"]), ("A2", ["E4", "G4", "A4"])]
    mel = ["A5", "D6", "F6", "E6", "D6", "B5", "G5", "B5", "D6", "C#6", "E6", "A5", "F6", "A5", "D6", "B5", "D6", "F#6", "E6", "G6", "B5", "C#6", "E6", "A5"]
    T2 = Track(16.0)
    bar_len = 2.0; beat = bar_len / 3
    for bar, (root, chord) in enumerate(prog):
        t0 = bar * bar_len
        T2.add(note(n2f(root), beat * 0.9, "bass", vol=0.6), t0)
        for k in (1, 2):
            for n in chord: T2.add(note(n2f(n), beat * 0.7, "pluck", vol=0.2), t0 + k * beat)
    for i, n in enumerate(mel): T2.add(note(n2f(n), beat * 1.6, "box", vol=0.5), i * beat)
    return finish(T2)

def music_cave():
    """Airy: bells over a deep drone in D (16 s)."""
    T = Track(16.0)
    for n, t in (("D2", 0), ("A2", 0), ("Bb1", 8), ("F2", 8)): T.add(note(n2f(n), 8.3, "pad", vol=0.5), t)
    for n, t in (("D5", 0.5), ("F5", 2.5), ("A5", 4.0), ("G5", 6.5), ("Bb4", 8.5), ("D5", 10.5), ("F5", 12.5), ("E5", 14.0)): T.add(note(n2f(n), 2.4, "bell", vol=0.4), t)
    return finish(T)

def music_safe():
    """The stairwell: a calm music box in C major (60 BPM, 16 s)."""
    T = Track(16.0)
    seq = ["C5", "E5", "G5", "E5", "A4", "C5", "E5", "C5", "F4", "A4", "C5", "A4", "G4", "B4", "D5", "B4"]
    for rep in range(2):
        for i, n in enumerate(seq): T.add(note(n2f(n), 1.4, "box", vol=0.5), rep * 8 + i * 0.5)
    for n, t in (("C3", 0), ("A2", 2), ("F2", 4), ("G2", 6), ("C3", 8), ("A2", 10), ("F2", 12), ("G2", 14)): T.add(note(n2f(n), 1.9, "pad", vol=0.35), t)
    return finish(T)

def music_boss():
    """The meeting: 150 BPM in C minor, a stabbing brass riff over a four on the floor (8 bars = 12.8 s) padded to 16 s."""
    bpm = 150; b = beat_time(bpm); T = Track(b * 4 * 10)
    roots = ["C2", "C2", "Ab1", "Bb1", "C2", "C2", "Eb2", "G1", "C2", "C2", "Ab1", "Bb1", "C2", "G1", "C2", "C2"]
    for i in range(80):
        T.add(note(n2f(roots[(i // 4) % len(roots)]), b * 0.45, "bass", vol=0.5), i * b * 0.5)
    for i in range(40): T.add(kick(), i * b, 0.8)
    for i in range(10): T.add(snare(), (i * 4 + 2) * b, 0.6)
    riff = [("C4", 0.5), ("Eb4", 0.5), ("G4", 1), ("F4", 0.5), ("Eb4", 0.5), ("C4", 1)]
    t = 0.0
    for rep in range(10):
        for n, beats in riff:
            T.add(note(n2f(n), b * beats * 0.9, "brass", vol=0.4), rep * 4 * b + (t % (4 * b)))
            t += b * beats
        t = 0.0
    return finish(T)

def music_combat():
    """The fight layer: 4 bars of drums and a driving bass at 140 BPM (6.86 s), played on top of whatever bed is running."""
    bpm = 120; b = beat_time(bpm); T = Track(b * 16)
    for i in range(16): T.add(kick(), i * b, 0.8)
    for i in range(8): T.add(snare(), (i * 2 + 1) * b, 0.55)
    for i in range(32): T.add(hat(), i * b * 0.5, 0.35)
    for i in range(32):
        n = ["A1", "A1", "C2", "A1", "E2", "A1", "G1", "A1"][i % 8]
        T.add(note(n2f(n), b * 0.4, "bass", vol=0.5), i * b * 0.5)
    for i in (0, 4, 8, 12): T.add(tom(f=100 + i * 5), (i + 3.5) * b, 0.5)
    return finish(T)

def music_victory():
    b = 0.25; T = Track(8.0)
    seq = [("C5", 1), ("E5", 1), ("G5", 1), ("C6", 3), ("G5", 1), ("C6", 5), ("E6", 8)]
    t = 0.0
    for n, beats in seq:
        T.add(note(n2f(n), b * beats * 0.95, "brass", vol=0.5), t); T.add(note(n2f(n) / 2, b * beats * 0.95, "bass", vol=0.4), t); t += b * beats
    return finish(T)

MUSIC = [("m_lobby", music_lobby), ("m_dungeon", music_dungeon), ("m_ballroom", music_ballroom), ("m_cave", music_cave), ("m_safe", music_safe), ("m_boss", music_boss), ("m_combat", music_combat), ("m_victory", music_victory)]

def main():
    for f in os.listdir(os.path.join(ROOT, "projects", "dungeon_crawler", "sounds")) if os.path.isdir(os.path.join(ROOT, "projects", "dungeon_crawler", "sounds")) else []:
        if f.startswith("m_") and f[-6:-4].startswith("_") and f.endswith(".wav"): os.remove(os.path.join(ROOT, "projects", "dungeon_crawler", "sounds", f))   # the old 2 s pieces
    args = sys.argv[1:]
    only = []
    if "--only" in args:
        i = args.index("--only"); only = args[i + 1:]; args = args[:i]
    out = args[0] if args else os.path.join(ROOT, "projects", "dungeon_crawler", "sounds")
    os.makedirs(out, exist_ok=True)
    for fn in EFFECTS:
        if only and fn.__name__ not in only: continue
        d = write(fn.__name__, fn(), out)
        print("%-14s %.2f s" % (fn.__name__, d))
    for name, fn in MUSIC:
        if only and name not in only: continue
        d = write(name, fn(), out, sr=MR, norm=0.8)
        print("%-14s %.2f s (a seamless loop: the notes wrap round the end)" % (name, d))

if __name__ == "__main__":
    main()
