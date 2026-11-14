"""Synthesises the ambience loops the game needs (no samples, so no licence questions).

Run:  python audio/make_sounds.py   -> audio/city_hum.wav, audio/wind.wav, audio/car_engine.wav
All loops are seamless: the tail is cross-faded into the head.
"""
import os
import wave

import numpy as np

RATE = 22050
OUT = os.path.dirname(os.path.abspath(__file__))
rng = np.random.default_rng(939)


def lowpass(x, cutoff):
    """One-pole low-pass, run forwards and backwards (no phase shift)."""
    a = np.exp(-2.0 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    for direction in (1, -1):
        src = x if direction == 1 else y[::-1].copy()
        acc = 0.0
        out = np.empty_like(src)
        for i, v in enumerate(src):
            acc = (1 - a) * v + a * acc
            out[i] = acc
        y = out if direction == 1 else out[::-1]
    return y


def bandpass(x, low, high):
    return lowpass(x, high) - lowpass(x, low)


def seamless(x, fade_seconds=1.0):
    n = int(fade_seconds * RATE)
    head, body, tail = x[:n], x[n:-n], x[-n:]
    t = np.linspace(0.0, 1.0, n)
    joined = tail * (1 - t) + head * t
    return np.concatenate([joined, body])


def smooth_noise(seconds, rate_hz):
    """Slowly varying 0..1 control signal."""
    points = max(4, int(seconds * rate_hz) + 2)
    keys = rng.random(points)
    xs = np.linspace(0, points - 1, int(seconds * RATE))
    i = np.floor(xs).astype(int)
    f = xs - i
    f = f * f * (3 - 2 * f)
    return keys[i] * (1 - f) + keys[np.minimum(i + 1, points - 1)] * f


def write(name, x, gain=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print("wrote", name, len(data) / RATE, "s")


def city_hum(seconds=24.0):
    n = int(seconds * RATE)
    brown = np.cumsum(rng.standard_normal(n))
    brown -= lowpass(brown, 2.0)  # remove drift
    rumble = lowpass(brown, 180.0)
    swell = 0.55 + 0.45 * smooth_noise(seconds, 0.25)
    # Occasional distant car passing: a band of noise that rises and falls.
    passes = np.zeros(n)
    for _ in range(5):
        centre = rng.uniform(2.0, seconds - 2.0) * RATE
        width = rng.uniform(1.5, 3.0) * RATE
        idx = np.arange(n)
        passes += np.exp(-((idx - centre) / width) ** 2)
    hiss = bandpass(rng.standard_normal(n), 250.0, 1400.0) * passes * 0.35
    t = np.arange(n) / RATE
    hum = 0.04 * np.sin(2 * np.pi * 50 * t) + 0.02 * np.sin(2 * np.pi * 100 * t)
    return seamless(rumble * swell / np.std(rumble) * 0.3 + hiss + hum, 2.0)


def wind(seconds=20.0):
    n = int(seconds * RATE)
    gusts = 0.25 + 0.75 * smooth_noise(seconds, 0.35) ** 2
    body = bandpass(rng.standard_normal(n), 120.0, 700.0)
    whistle = bandpass(rng.standard_normal(n), 700.0, 1500.0) * 0.25
    return seamless((body + whistle) * gusts, 2.0)


def car_engine(seconds=2.0):
    # 4-cylinder at ~1800 rpm: firing frequency 60 Hz; whole periods so it loops.
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    f0 = 60.0
    wobble = 1.0 + 0.01 * np.sin(2 * np.pi * 3.0 * t)
    phase = 2 * np.pi * f0 * np.cumsum(wobble) / RATE
    tone = sum(np.sin(k * phase) / k ** 0.9 for k in range(1, 9))
    tone += 0.6 * np.sin(0.5 * phase)  # crankshaft half-order
    tyres = lowpass(rng.standard_normal(n), 900.0) * 1.2
    return seamless(tone * 0.6 + tyres * 0.4, 0.3)


def swing_creak(seconds=3.2):
    """Two squeaks per swing period (forward and back), rusty chain-on-hook pitch glide."""
    n = int(seconds * RATE)
    out = np.zeros(n)
    for start, up in ((0.25, True), (1.85, False)):
        length = 0.42
        m = int(length * RATE)
        t = np.arange(m) / RATE
        f = np.linspace(780, 1150, m) if up else np.linspace(1100, 820, m)
        f = f * (1 + 0.02 * np.sin(2 * np.pi * 37 * t))
        phase = 2 * np.pi * np.cumsum(f) / RATE
        tone = np.sin(phase) + 0.45 * np.sin(2 * phase) + 0.2 * np.sin(3.01 * phase)
        env = np.sin(np.pi * t / length) ** 1.5
        rough = 1 + 0.35 * rng.standard_normal(m)
        i = int(start * RATE)
        out[i:i + m] += tone * env * rough
    return out


write("city_hum.wav", city_hum(), 0.7)
write("swing_creak.wav", swing_creak(), 0.5)
write("wind.wav", wind(), 0.7)
write("car_engine.wav", car_engine(), 0.75)
