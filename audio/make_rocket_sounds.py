"""Synthesises the bazooka's sounds (no samples, so no licence questions).

Run:  python audio/make_rocket_sounds.py
  -> audio/rocket_launch.wav  the tube firing: a hard thump, the hiss of the motor lighting, the whoosh away
     audio/rocket_fly.wav     the motor's roar, one seamless 1 s loop (played on the rocket in flight)
     audio/rubble.wav         concrete and brick coming down after a blast: crunch, then pieces raining
"""
import os
import wave

import numpy as np
from scipy import signal

RATE = 44100
OUT = os.path.dirname(os.path.abspath(__file__))
rng = np.random.default_rng(1945)


def band(x, lo, hi, order=2):
    return signal.sosfilt(signal.butter(order, [lo, hi], btype="bandpass", fs=RATE, output="sos"), x)


def low(x, cutoff, order=2):
    return signal.sosfilt(signal.butter(order, cutoff, btype="lowpass", fs=RATE, output="sos"), x)


def high(x, cutoff, order=2):
    return signal.sosfilt(signal.butter(order, cutoff, btype="highpass", fs=RATE, output="sos"), x)


def write(name, x, gain=0.85):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print("wrote", name, round(len(data) / RATE, 2), "s")


def rocket_launch(seconds=1.6):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    noise = rng.standard_normal(n)
    # The thump of the charge: a low sine drop and a burst of low noise.
    thump = np.sin(2 * np.pi * (70 * t - 25 * t * t)) * np.exp(-t / 0.09)
    thump += low(noise, 400) * np.exp(-t / 0.06) * 1.4
    crack = high(noise, 2500) * np.exp(-t / 0.012) * 0.8
    # The motor: hiss rising fast, its pitch falling away (Doppler) as it leaves.
    centre = 2200 - 1400 * np.clip(t / seconds, 0, 1)
    hiss = np.zeros(n)
    block = 2048
    for i in range(0, n, block):
        c = float(np.mean(centre[i:i + block]))
        hiss[i:i + block] = band(noise[max(0, i - 512):i + block], c * 0.55, c * 1.6)[-len(noise[i:i + block]):]
    env = (1 - np.exp(-t / 0.05)) * np.exp(-t / 0.55)
    roar = low(noise, 300) * env * 0.9
    return thump * 1.3 + crack + hiss * env * 0.9 + roar


def rocket_fly(seconds=1.0):
    n = int(seconds * RATE)
    noise = rng.standard_normal(n * 2)
    x = band(noise, 500, 3200) + low(noise, 250) * 0.8
    x = x[n // 2:n // 2 + n]
    # Crossfade the ends so the loop is seamless.
    fade = int(0.05 * RATE)
    x[:fade] = x[:fade] * np.linspace(0, 1, fade) + x[-fade:] * np.linspace(1, 0, fade)
    flutter = 1 + 0.15 * np.sin(2 * np.pi * 23 * np.arange(n) / RATE)
    return x[:n - fade] * flutter[:n - fade]


def rubble(seconds=3.0):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    noise = rng.standard_normal(n)
    out = low(noise, 700) * np.exp(-t / 0.35) * 1.2 # the crunch of the wall giving
    for _ in range(90): # chunks landing, thinning out
        start = rng.exponential(0.7)
        if start > seconds - 0.2:
            continue
        i = int(start * RATE)
        m = int(rng.uniform(0.03, 0.12) * RATE)
        m = min(m, n - i)
        tt = np.arange(m) / RATE
        f = rng.uniform(150, 1400)
        hit = band(rng.standard_normal(m), f * 0.6, f * 1.8) * np.exp(-tt / rng.uniform(0.01, 0.04))
        out[i:i + m] += hit * rng.uniform(0.2, 1.0) * np.exp(-start / 1.2)
    return out


write("rocket_launch.wav", rocket_launch(), 0.9)
write("rocket_fly.wav", rocket_fly(), 0.6)
write("rubble.wav", rubble(), 0.85)
