"""Synthesises the sounds of smashing things with the bat (no samples, so no licence questions).

Run:  python audio/make_smash_sounds.py
  -> audio/glass_shatter.wav  a shop window giving way: the crack, the burst, shards raining down
     audio/car_dent.wav       the bat caving in a car panel: thump, sheet-metal ring, crunch
     audio/car_alarm.wav      a car alarm, one seamless 2 s loop (sweeps, then two-tone)
     audio/car_horn.wav       a driver leaning on the horn
"""
import os
import wave

import numpy as np
from scipy import signal

RATE = 44100
OUT = os.path.dirname(os.path.abspath(__file__))
rng = np.random.default_rng(2026)


def band(x, low, high, order=2):
    sos = signal.butter(order, [low, high], btype="bandpass", fs=RATE, output="sos")
    return signal.sosfilt(sos, x)


def high(x, cutoff, order=2):
    sos = signal.butter(order, cutoff, btype="highpass", fs=RATE, output="sos")
    return signal.sosfilt(sos, x)


def low(x, cutoff, order=2):
    sos = signal.butter(order, cutoff, btype="lowpass", fs=RATE, output="sos")
    return signal.sosfilt(sos, x)


def write(name, x, gain=0.85):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print("wrote", name, round(len(data) / RATE, 2), "s")


def tink(out, start, freq, decay, amp):
    """One shard: a few inharmonic partials ringing down, added into `out` at `start` seconds."""
    i = int(start * RATE)
    m = min(int(decay * 6 * RATE), len(out) - i)
    if m <= 8:
        return
    t = np.arange(m) / RATE
    tone = np.zeros(m)
    for ratio, weight in ((1.0, 1.0), (1.47, 0.55), (2.09, 0.35), (2.73, 0.2)):
        tone += weight * np.sin(2 * np.pi * freq * ratio * (1 + rng.uniform(-0.01, 0.01)) * t + rng.uniform(0, 6.3))
    env = np.exp(-t / decay) * (1 - np.exp(-t / 0.0004))
    out[i:i + m] += tone * env * amp


def glass_shatter(seconds=2.2):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    out = np.zeros(n)
    # The crack: a hard broadband snap.
    snap = high(rng.standard_normal(n), 1500.0) * np.exp(-t / 0.006)
    out += snap * 2.5
    # The burst: bright noise bursting and dying away fast, with a little body under it.
    burst = high(rng.standard_normal(n), 2500.0) * np.exp(-t / 0.09)
    body = band(rng.standard_normal(n), 400.0, 2000.0) * np.exp(-t / 0.05) * 0.6
    out += burst * 1.2 + body
    # The pane breaking up: hundreds of shards ringing, densest at first.
    for _ in range(420):
        start = rng.exponential(0.12)
        if start > 0.9:
            continue
        tink(out, start, rng.uniform(2200, 9500), rng.uniform(0.004, 0.03), rng.uniform(0.15, 0.6) * np.exp(-start / 0.4))
    # Then the pieces land on the pavement and skitter: sparse, quieter, lower.
    for _ in range(140):
        start = rng.uniform(0.25, 1.7) ** 1.3
        if start > seconds - 0.2:
            continue
        tink(out, start, rng.uniform(1500, 7000), rng.uniform(0.003, 0.02), rng.uniform(0.05, 0.3) * np.exp(-(start - 0.25) / 0.6))
        if rng.random() < 0.3:
            i = int(start * RATE)
            m = int(0.012 * RATE)
            out[i:i + m] += high(rng.standard_normal(m), 3000.0) * np.exp(-np.arange(m) / (0.003 * RATE)) * 0.25
    fade = np.minimum(1.0, (seconds - t) / 0.3)
    return out * fade


def car_dent(seconds=0.9):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    # Thump of the bat on the panel: a pitch-dropping low sine.
    f = 95.0 * np.exp(-t / 0.08) + 45.0
    thump = np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t / 0.09)
    # Sheet metal: inharmonic modes ringing, the high ones dying fastest.
    ring = np.zeros(n)
    for freq in (173.0, 291.0, 418.0, 633.0, 877.0, 1240.0, 1715.0, 2390.0):
        freq *= rng.uniform(0.97, 1.03)
        decay = 0.32 * (300.0 / freq) ** 0.6
        wobble = 1 + 0.004 * np.sin(2 * np.pi * rng.uniform(5, 11) * t)
        ring += np.sin(2 * np.pi * freq * np.cumsum(wobble) / RATE) * np.exp(-t / decay) * rng.uniform(0.3, 0.7)
    # Crunch of the metal giving way: gritty mid noise, a few crackles.
    crunch = band(rng.standard_normal(n), 700.0, 4500.0) * np.exp(-t / 0.04)
    for _ in range(12):
        i = int(rng.uniform(0.005, 0.12) * RATE)
        m = int(0.006 * RATE)
        crunch[i:i + m] += band(rng.standard_normal(m), 1500.0, 6000.0) * 0.8
    return thump * 1.4 + ring * 0.45 + crunch * 0.7


def car_alarm(seconds=2.0):
    """Four fast up-sweeps, then a two-tone warble: whole cycles, so it loops cleanly."""
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    f = np.empty(n)
    half = n // 2
    sweep_t = (t[:half] * 4.0) % 1.0
    f[:half] = 750.0 + 950.0 * sweep_t ** 0.7
    warble = (np.floor(t[half:] * 8.0) % 2).astype(float)
    f[half:] = 1050.0 - 330.0 * warble
    phase = 2 * np.pi * np.cumsum(f) / RATE
    # A small piezo siren: square-ish, a bit buzzy, through a cheap horn.
    tone = np.tanh(3.0 * np.sin(phase)) + 0.25 * np.sin(3 * phase)
    tone = band(tone, 500.0, 5000.0)
    return tone


def car_horn(seconds=0.75):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    tone = np.zeros(n)
    for freq in (415.0, 505.0):  # the usual two-horn pair, a minor third apart
        phase = 2 * np.pi * freq * t
        tone += np.tanh(2.5 * np.sin(phase)) + 0.3 * np.sin(2 * phase + 0.4)
    tone = band(tone, 300.0, 4000.0)
    env = np.minimum(1.0, t / 0.015) * np.minimum(1.0, (seconds - t) / 0.06)
    return tone * env


write("glass_shatter.wav", glass_shatter(), 0.9)
write("car_dent.wav", car_dent(), 0.9)
write("car_alarm.wav", car_alarm(), 0.6)
write("car_horn.wav", car_horn(), 0.7)
