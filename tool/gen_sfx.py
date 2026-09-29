#!/usr/bin/env python3
"""Synthesizes the placeholder sound effects and ambient music.

Pure standard library (no numpy) so it runs anywhere:
    python3 tool/gen_sfx.py
Writes 16-bit mono WAVs into assets/audio/. Replace with recorded/CC0
sounds later; file names are the contract with lib/systems/audio.dart.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
ROOT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')


def silence(seconds):
    return [0.0] * int(seconds * RATE)


def mix(dst, src, offset=0.0, gain=1.0):
    start = int(offset * RATE)
    if start + len(src) > len(dst):
        dst.extend([0.0] * (start + len(src) - len(dst)))
    for i, s in enumerate(src):
        dst[start + i] += s * gain
    return dst


def noise(seconds, rng):
    return [rng.uniform(-1, 1) for _ in range(int(seconds * RATE))]


def lowpass(samples, cutoff):
    a = 1 - math.exp(-2 * math.pi * cutoff / RATE)
    out, y = [], 0.0
    for s in samples:
        y += a * (s - y)
        out.append(y)
    return out


def highpass(samples, cutoff):
    low = lowpass(samples, cutoff)
    return [s - l for s, l in zip(samples, low)]


def envelope(samples, attack, decay_rate):
    """Linear attack, then exponential decay (decay_rate per second)."""
    a = max(1, int(attack * RATE))
    out = []
    for i, s in enumerate(samples):
        if i < a:
            g = i / a
        else:
            g = math.exp(-decay_rate * (i - a) / RATE)
        out.append(s * g)
    return out


def tone(freq, seconds, shape='sine', sweep=0.0):
    out, phase = [], 0.0
    n = int(seconds * RATE)
    for i in range(n):
        f = freq * (1 + sweep * i / n)
        phase += 2 * math.pi * f / RATE
        if shape == 'sine':
            out.append(math.sin(phase))
        else:  # saw
            out.append(2 * ((phase / (2 * math.pi)) % 1) - 1)
    return out


def normalize(samples, peak=0.9):
    m = max(1e-9, max(abs(s) for s in samples))
    return [s * peak / m for s in samples]


def fade_edges(samples, seconds=0.005):
    n = int(seconds * RATE)
    for i in range(min(n, len(samples))):
        samples[i] *= i / n
        samples[-1 - i] *= i / n
    return samples


def write(name, samples, peak=0.9):
    samples = fade_edges(normalize(samples, peak))
    path = os.path.join(ROOT, name)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(
            struct.pack('<h', int(max(-1, min(1, s)) * 32767)) for s in samples))
    print('wrote', path)


def thud(freq, seconds, decay, grit, rng, grit_cutoff=900):
    body = envelope(tone(freq, seconds, sweep=-0.5), 0.002, decay)
    dirt = envelope(lowpass(noise(seconds, rng), grit_cutoff), 0.001, decay * 1.8)
    return mix(body, dirt, gain=grit)


def tinks(seconds, count, rng, lo=2200, hi=5200, spread=0.0):
    out = silence(seconds)
    for _ in range(count):
        t = rng.uniform(0, spread)
        f = rng.uniform(lo, hi)
        ping = envelope(tone(f, 0.25), 0.001, rng.uniform(18, 35))
        mix(out, ping, t, rng.uniform(0.3, 1))
    return out


def main():
    rng = random.Random(7)

    # Launch, impacts, breaks, unit down, victory and defeat now come from
    # Kenney's CC0 packs (see assets/CREDITS.md); only the effects below
    # are synthesized.

    # Powder explosion: sharp crack, deep boom, rolling rumble.
    boom = mix(thud(40, 1.6, 3, 1.5, rng, 500),
               envelope(highpass(noise(0.08, rng), 1500), 0.0005, 40), gain=0.8)
    mix(boom, envelope(lowpass(noise(1.8, rng), 180), 0.02, 2.2), 0.05, 1.2)
    write('sfx/explosion.wav', boom)

    # Ignition: a breathy whoomph of flame.
    whoomph = lowpass(noise(0.7, rng), 900)
    whoomph = [x * math.sin(math.pi * min(1, i / (0.12 * RATE))) ** 2 *
               math.exp(-3 * i / RATE) for i, x in enumerate(whoomph)]
    write('sfx/ignite.wav', mix(whoomph, thud(70, 0.3, 10, 0.4, rng), gain=0.6))

    # Fire crackle: sparse pops over a soft roar.
    crackle = mix(silence(0.6), lowpass(noise(0.6, rng), 400), gain=0.15)
    for _ in range(14):
        pop = envelope(highpass(noise(0.015, rng), 1200), 0.0003, 200)
        mix(crackle, pop, rng.uniform(0, 0.55), rng.uniform(0.3, 1))
    write('sfx/fire_crackle.wav', crackle, peak=0.6)

    # Cluster split: rope snap plus a scatter of small whooshes.
    snap = envelope(highpass(noise(0.03, rng), 2000), 0.0003, 120)
    for k in range(4):
        w = lowpass(highpass(noise(0.25, rng), 600), 2500)
        w = [x * math.sin(math.pi * i / len(w)) for i, x in enumerate(w)]
        mix(snap, w, 0.02 + k * 0.03, 0.4)
    write('sfx/split.wav', snap)

    # Ballista: taut string twang and a thud of the stock.
    twang = silence(0.6)
    for f, g in ((180, 1), (362, 0.5), (545, 0.3)):
        mix(twang, envelope(tone(f, 0.6, sweep=-0.08), 0.001, 7), gain=g)
    write('sfx/ballista.wav', mix(twang, thud(110, 0.25, 18, 0.6, rng)))

    # Weak point sting: low drum and a rising metallic ring.
    sting = thud(55, 1.0, 4, 0.7, rng, 350)
    ring = envelope(tone(330, 1.2, sweep=0.5), 0.05, 2.5)
    write('sfx/weak_point.wav', mix(sting, ring, 0.08, 0.35), peak=0.8)

    # Arrow loosed: short bow thrum and a thin whistle.
    thrum = envelope(tone(140, 0.25, sweep=-0.1), 0.001, 20)
    whistle = lowpass(highpass(noise(0.35, rng), 2500), 6000)
    whistle = [x * math.sin(math.pi * i / len(whistle)) for i, x in enumerate(whistle)]
    write('sfx/arrow.wav', mix(thrum, whistle, 0.03, 0.5), peak=0.7)

    # Engineer's hammer: three metallic knocks.
    hammer = silence(0.8)
    for k in range(3):
        knock = silence(0.25)
        for f, g in ((1180, 1), (2650, 0.5), (3900, 0.3)):
            mix(knock, envelope(tone(f, 0.25), 0.0005, 35), gain=g)
        mix(hammer, mix(knock, thud(160, 0.1, 40, 0.5, rng)), 0.22 * k)
    write('sfx/hammer.wav', hammer, peak=0.6)

    # Player's engine struck: splintering wood crunch.
    crunch = thud(80, 0.5, 9, 1.2, rng, 1200)
    for _ in range(6):
        mix(crunch, envelope(highpass(noise(0.04, rng), 1000), 0.0005, 70),
            rng.uniform(0, 0.15), rng.uniform(0.4, 0.9))
    write('sfx/player_hit.wav', crunch)

    # Enemy war horn: a low, slightly bending blast.
    horn = lowpass(tone(98, 1.3, 'saw', sweep=0.04), 700)
    horn = [x * min(1, i / (0.15 * RATE)) * min(1, (len(horn) - i) / (0.4 * RATE))
            for i, x in enumerate(horn)]
    write('sfx/war_horn.wav', mix(horn, lowpass(tone(147, 1.3, 'saw'), 600), gain=0.4),
          peak=0.7)



if __name__ == '__main__':
    main()
