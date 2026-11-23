#!/usr/bin/env python3
"""Synthesise the Bathtub Edition's template sounds (playful, toy-like) as
16-bit mono WAV files in assets/audio/bathtub/template_<name>.wav.

Run from the repository root:  python3 tools/bathtub/make_sounds.py
Users replace any of them with custom/audio/bathtub/<name>.ogg|.wav|.mp3.
"""
import os
import wave
import numpy as np

SR = 22050
OUT = "assets/audio/bathtub"
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, attack=0.005, decay=0.2):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-t / max(decay, 1e-4))


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def sweep(f0, f1, dur, shape="exp"):
    t = t_axis(dur)
    if shape == "exp":
        f = f0 * (f1 / f0) ** (t / dur)
    else:
        f = f0 + (f1 - f0) * t / dur
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def blip(freq0, freq1, dur, decay):
    s = sweep(freq0, freq1, dur)
    return s * env(len(s), 0.002, decay)


def mix(*xs):
    out = np.zeros(max(len(x) for x in xs))
    for x in xs:
        out[: len(x)] += x
    return out


def place(buf, snd, at):
    i = int(at * SR)
    j = min(len(buf), i + len(snd))
    buf[i:j] += snd[: j - i]


def bubbles(dur, n, f_lo, f_hi, gain=0.5, falling=False):
    buf = np.zeros(int(SR * dur))
    for k in range(n):
        at = rng.uniform(0, dur * 0.85)
        f = rng.uniform(f_lo, f_hi)
        if falling:
            f *= 1.0 - 0.5 * at / dur
        b = blip(f, f * rng.uniform(1.6, 2.4), 0.06, 0.025) * rng.uniform(0.4, 1.0)
        place(buf, b, at)
    return buf * gain


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def write(name, x, gain=0.85):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * gain
    fade = min(len(x), int(0.004 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, f"template_{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def main():
    os.makedirs(OUT, exist_ok=True)
    # Torpedo away: a bubbly whoosh.
    wh = highpass(lowpass(noise(0.45), 2500), 300) * env(int(0.45 * SR), 0.03, 0.18)
    write("bubble_launch", wh * 0.8 + bubbles(0.45, 9, 500, 1400, 0.6))
    # Toy hit: a hollow plastic clunk and a splash.
    n = int(0.5 * SR)
    t = t_axis(0.5)
    clunk = (np.sin(2 * np.pi * 190 * t) + 0.5 * np.sin(2 * np.pi * 410 * t)) * env(n, 0.001, 0.07)
    click = noise(0.5) * env(n, 0.0005, 0.008)
    spl = highpass(lowpass(noise(0.5), 4000), 600) * env(n, 0.01, 0.12)
    write("toy_hit", clunk + 0.6 * click + 0.5 * spl)
    write("splash_small", highpass(lowpass(noise(0.3), 5000), 700) * env(int(0.3 * SR), 0.005, 0.07) + bubbles(0.3, 4, 700, 1500, 0.4))
    write("plink", blip(2600, 2200, 0.05, 0.015), 0.5)
    write("pew", blip(950, 280, 0.09, 0.04), 0.55)
    # Depth charge: a thump and a bubbly rumble.
    n = int(1.0 * SR)
    t = t_axis(1.0)
    thump = np.sin(2 * np.pi * np.cumsum(70 * (1 - 0.4 * t)) / SR) * env(n, 0.002, 0.25)
    rumble = lowpass(noise(1.0), 400) * env(n, 0.01, 0.35)
    write("depth_boom", thump + 1.5 * rumble + bubbles(1.0, 14, 200, 600, 0.5))
    write("plop", mix(blip(320, 1100, 0.12, 0.05), 0.3 * blip(900, 1600, 0.05, 0.02)))
    # A cheerful little sonar ping.
    t = t_axis(1.0)
    write("ping", np.sin(2 * np.pi * (1250 + 6 * np.sin(2 * np.pi * 5 * t)) * t) * env(len(t), 0.002, 0.3), 0.55)
    # Rubber duck squeak: a nasal pitch bend up and down.
    def squeak(dur, f0, f1):
        t = t_axis(dur)
        bend = f0 + (f1 - f0) * np.sin(np.pi * t / dur)
        ph = 2 * np.pi * np.cumsum(bend) / SR
        tone = np.sin(ph) + 0.6 * np.sin(2 * ph) + 0.35 * np.sin(3 * ph) + 0.2 * np.sin(5 * ph)
        tone += 0.15 * highpass(noise(dur), 3000)
        e = np.clip(t / 0.02, 0, 1) * np.clip((dur - t) / 0.05, 0, 1)
        return tone * e
    write("squeak", squeak(0.38, 900, 1500))
    write("squeak_small", squeak(0.18, 1300, 1900), 0.6)
    # Quack: two buzzy honks.
    buf = np.zeros(int(0.5 * SR))
    for k, at in enumerate([0.0, 0.22]):
        d = 0.18
        tt = t_axis(d)
        f = 420 * (1 - 0.25 * tt / d) * (1.0 if k == 0 else 0.92)
        ph = 2 * np.pi * np.cumsum(f) / SR
        saw = 2 * (ph / (2 * np.pi) % 1) - 1
        honk = lowpass(saw, 1800) * np.clip(tt / 0.01, 0, 1) * np.clip((d - tt) / 0.04, 0, 1)
        place(buf, honk, at)
    write("quack", buf)
    n = int(0.25 * SR)
    t = t_axis(0.25)
    write("thud", np.sin(2 * np.pi * 120 * t) * env(n, 0.001, 0.06) + 0.4 * lowpass(noise(0.25), 800) * env(n, 0.001, 0.04))
    # Sinking: glug-glug and falling bubbles.
    buf = bubbles(1.8, 30, 250, 900, 0.7, falling=True)
    for at in [0.1, 0.5, 0.95]:
        place(buf, blip(260, 140, 0.2, 0.1), at)
    write("sink", buf)
    # Candy: a two-note chime.
    buf = np.zeros(int(0.7 * SR))
    for f, at in [(1318.5, 0.0), (1975.5, 0.09)]:
        tt = t_axis(0.6)
        place(buf, (np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(2 * np.pi * 2 * f * tt)) * env(len(tt), 0.002, 0.18), at)
    write("candy", buf, 0.6)
    write("gurgle", lowpass(bubbles(0.9, 18, 150, 500, 1.0), 2000) + 0.3 * lowpass(noise(0.9), 300) * env(int(0.9 * SR), 0.05, 0.4))
    write("pop", blip(1800, 3000, 0.04, 0.01) + 0.5 * noise(0.04) * env(int(0.04 * SR), 0.0005, 0.005), 0.5)
    write("bubble", blip(500, 1100, 0.08, 0.03), 0.45)
    write("dive", bubbles(0.7, 14, 300, 900, 0.8, falling=True) + 0.4 * lowpass(noise(0.7), 500) * env(int(0.7 * SR), 0.05, 0.25))
    write("surface", highpass(lowpass(noise(0.5), 3500), 400) * env(int(0.5 * SR), 0.02, 0.12) + bubbles(0.5, 8, 600, 1400, 0.6))
    write("lift", sweep(300, 1400, 0.5) * env(int(0.5 * SR), 0.05, 0.4) * 0.5 + 0.3 * highpass(noise(0.5), 2000) * env(int(0.5 * SR), 0.05, 0.2))
    # Tap running: modulated filtered noise.
    t = t_axis(3.0)
    tap = highpass(lowpass(noise(3.0), 3000), 250) * (0.7 + 0.3 * np.sin(2 * np.pi * 7 * t))
    tap *= np.clip(t / 0.3, 0, 1) * np.clip((3.0 - t) / 0.6, 0, 1)
    write("faucet", tap + bubbles(3.0, 30, 400, 1200, 0.3), 0.5)
    # A toy referee's whistle with a trill.
    t = t_axis(0.7)
    f = 2100 + 120 * np.sign(np.sin(2 * np.pi * 28 * t))
    whistle = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.clip(t / 0.02, 0, 1) * np.clip((0.7 - t) / 0.1, 0, 1)
    write("whistle", whistle + 0.1 * highpass(noise(0.7), 4000), 0.5)
    write("ui_click", blip(1400, 900, 0.03, 0.01), 0.4)
    # Music: a gentle music-box loop in C major, 96 bpm, 16 bars.
    bpm = 96
    beat = 60 / bpm
    bars = 16
    dur = bars * 4 * beat
    buf = np.zeros(int(SR * dur) + SR)
    def note(m):
        return 440.0 * 2 ** ((m - 69) / 12)
    def bell(f, d, amp):
        tt = t_axis(d)
        return amp * (np.sin(2 * np.pi * f * tt) + 0.4 * np.sin(2 * np.pi * 2.01 * f * tt) + 0.15 * np.sin(2 * np.pi * 3.98 * f * tt)) * env(len(tt), 0.003, d * 0.35)
    chords = [[60, 64, 67], [57, 60, 64], [65, 69, 72], [67, 71, 74]]
    melody = [76, 79, 81, 79, 76, 74, 72, 74, 76, 76, 74, 72, 74, 76, 79, 76,
              77, 76, 74, 72, 69, 72, 74, 72, 71, 72, 74, 79, 77, 76, 74, 72]
    for bar in range(bars):
        ch = chords[bar % 4]
        t0 = bar * 4 * beat
        # Bass on beats 1 and 3, soft pad chord.
        place(buf, bell(note(ch[0] - 24), 2 * beat, 0.35), t0)
        place(buf, bell(note(ch[0] - 17), 2 * beat, 0.25), t0 + 2 * beat)
        for k, m in enumerate(ch):
            place(buf, bell(note(m), 4 * beat, 0.12), t0 + k * 0.03)
        # Arpeggio in eighths.
        for e in range(8):
            m = ch[[0, 1, 2, 1, 0, 2, 1, 2][e]] + 12
            place(buf, bell(note(m), beat, 0.1), t0 + e * beat / 2)
        # Melody: two notes a bar, with rests on the last bars of each phrase.
        for k in range(2):
            idx = (bar * 2 + k) % len(melody)
            if bar % 4 == 3 and k == 1:
                continue
            place(buf, bell(note(melody[idx]), 2 * beat, 0.32), t0 + k * 2 * beat)
    loop = buf[: int(SR * dur)]
    # Fold the overhanging tail back to the start so the loop is seamless.
    tail = buf[int(SR * dur):]
    loop[: len(tail)] += tail
    write("music", loop, 0.7)
    print("sounds written to", OUT)


if __name__ == "__main__":
    main()
