"""Synthesises the sounds of money and the police (no samples, so no licence questions).

Run:  python audio/make_game_sounds.py
  -> audio/coin.wav      a coin picked up: two bright bell tones, one after the other
     audio/purchase.wav  something bought in the shop: a till's ka-ching
     audio/siren.wav     a police siren, one seamless 4 s loop (a slow wail, then a yelp)
"""
import os
import wave

import numpy as np
from scipy import signal

RATE = 44100
OUT = os.path.dirname(os.path.abspath(__file__))
rng = np.random.default_rng(2611)


def band(x, low, high, order=2):
    sos = signal.butter(order, [low, high], btype="bandpass", fs=RATE, output="sos")
    return signal.sosfilt(sos, x)


def write(name, x, gain=0.85):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def bell(t, freq, decay):
    """A small metal bell: the fundamental plus slightly inharmonic partials."""
    tone = np.zeros_like(t)
    for ratio, amp in [(1.0, 1.0), (2.76, 0.45), (5.4, 0.25), (8.93, 0.12)]:
        tone += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t * decay * ratio ** 0.5)
    return tone


def coin(seconds=0.45):
    n = int(RATE * seconds)
    out = np.zeros(n)
    t = np.arange(n) / RATE
    out += bell(t, 1567.0, 9.0) * 0.8
    k = int(RATE * 0.075)
    out[k:] += bell(t[: n - k], 2093.0, 7.0)
    attack = np.minimum(t / 0.002, 1.0)
    return out * attack


def purchase(seconds=1.1):
    n = int(RATE * seconds)
    t = np.arange(n) / RATE
    out = np.zeros(n)
    # "Ka": the drawer's mechanism, a short noisy clack.
    clack = band(rng.standard_normal(n), 900, 4200) * np.exp(-t * 60.0)
    out += clack * 0.7
    # "-ching": a bell rung twice, the drawer shooting out under it.
    k = int(RATE * 0.09)
    out[k:] += bell(t[: n - k], 2637.0, 4.0)
    k2 = int(RATE * 0.16)
    out[k2:] += bell(t[: n - k2], 3520.0, 5.0) * 0.6
    slide = band(rng.standard_normal(n), 300, 1500) * np.exp(-((t - 0.25) / 0.12) ** 2) * 0.25
    return out + slide


def siren(seconds=4.0):
    """Wail for 2.5 s, then yelp; the pitch curve starts and ends at the same place, so it loops."""
    n = int(RATE * seconds)
    t = np.arange(n) / RATE
    low_f, high_f = 640.0, 1480.0
    freq = np.empty(n)
    wail = t < 2.5
    # One slow rise and fall.
    freq[wail] = low_f + (high_f - low_f) * np.sin(np.pi * t[wail] / 2.5) ** 2
    # Fast yelps over the remaining 1.5 s: five up-down sweeps.
    yt = t[~wail] - 2.5
    freq[~wail] = low_f + (high_f - low_f) * np.sin(np.pi * (yt * 5 / 1.5)) ** 2
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    # A horn-like timbre: odd harmonics, a little squared off.
    tone = np.sin(phase) + 0.35 * np.sin(3 * phase) + 0.18 * np.sin(5 * phase)
    tone = np.tanh(tone * 1.6)
    tone = band(tone, 300, 6000)
    # Fade the first and last few ms so the loop point doesn't click.
    edge = int(RATE * 0.004)
    ramp = np.linspace(0.0, 1.0, edge)
    tone[:edge] *= ramp
    tone[-edge:] *= ramp[::-1]
    return tone


write("coin.wav", coin(), 0.7)
write("purchase.wav", purchase(), 0.75)
write("siren.wav", siren(), 0.55)
