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

    # Catapult release: creaking rope/wood, then a whoosh.
    creak = envelope(lowpass(tone(38, 0.3, 'saw', sweep=0.6), 700), 0.02, 9)
    whoosh_n = noise(0.6, rng)
    whoosh = [s * math.sin(math.pi * i / len(whoosh_n)) ** 2
              for i, s in enumerate(lowpass(highpass(whoosh_n, 300), 1800))]
    launch = mix(silence(0.8), creak)
    write('sfx/launch.wav', mix(launch, whoosh, 0.08, 1.4))

    write('sfx/impact_wood.wav',
          mix(thud(120, 0.35, 16, 0.9, rng),
              envelope(tone(520, 0.12), 0.001, 40), gain=0.5))
    write('sfx/impact_stone.wav', thud(70, 0.5, 11, 1.3, rng, 1400))
    write('sfx/impact_glass.wav',
          mix(tinks(0.4, 5, rng, spread=0.04), thud(200, 0.15, 30, 0.3, rng),
              gain=0.4))

    # Wood breaking: a volley of cracks over a creak.
    brk = mix(silence(0.8), envelope(lowpass(tone(55, 0.5, 'saw', -0.4), 600),
                                     0.01, 6), gain=0.5)
    for _ in range(9):
        crack = envelope(highpass(noise(0.05, rng), 800), 0.0005, 70)
        mix(brk, crack, rng.uniform(0, 0.3), rng.uniform(0.5, 1))
    write('sfx/break_wood.wav', mix(brk, thud(90, 0.4, 10, 1, rng), 0.02))

    # Stone crumbling: deep rumble with gravel grains.
    rumble = envelope(lowpass(noise(1.2, rng), 220), 0.01, 3.5)
    for _ in range(40):
        grain = envelope(lowpass(noise(0.04, rng), 2500), 0.0005, 90)
        mix(rumble, grain, rng.uniform(0, 0.9), rng.uniform(0.1, 0.35))
    write('sfx/break_stone.wav', mix(rumble, thud(55, 0.6, 7, 1, rng)))

    shatter = envelope(highpass(noise(0.7, rng), 2500), 0.001, 7)
    write('sfx/break_glass.wav',
          mix(shatter, tinks(0.8, 24, rng, spread=0.35), gain=1.2), peak=0.7)

    # Soldier down: armor clank (inharmonic partials) + body thud.
    clank = silence(0.5)
    for f, g in ((523, 1), (1270, 0.6), (2110, 0.4), (3380, 0.25)):
        mix(clank, envelope(tone(f, 0.5), 0.001, 14), gain=g)
    write('sfx/unit_down.wav', mix(clank, thud(95, 0.4, 12, 1, rng), 0.03, 1.2))

    # Victory: low war horns swelling on a fifth, octave above at the end.
    horn = silence(3.2)
    for f, t, g in ((110, 0, 1), (165, 0.35, 0.8), (220, 1.1, 0.7)):
        h = lowpass(tone(f, 3.2 - t, 'saw'), 900)
        h = [s * min(1, i / (0.4 * RATE)) * math.exp(-0.6 * i / RATE)
             for i, s in enumerate(h)]
        mix(horn, h, t, g)
    write('sfx/victory.wav', horn, peak=0.8)

    # Defeat: falling drone and two slow drum hits.
    drone = lowpass(tone(98, 2.8, 'saw', sweep=-0.25), 500)
    drone = [s * math.exp(-0.9 * i / RATE) for i, s in enumerate(drone)]
    for t in (0.0, 0.9):
        mix(drone, thud(50, 0.9, 5, 0.8, rng, 400), t, 1.4)
    write('sfx/defeat.wav', drone, peak=0.8)

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

    write('music/siege_ambient.wav', ambient(rng), peak=0.6)


def ambient(rng):
    """32 second seamless loop: drone fifth, war drums, wind."""
    seconds = 32.0
    n = int(seconds * RATE)
    out = [0.0] * n
    # Drone frequencies chosen to complete whole cycles over the loop.
    for f, g in ((55.0, 0.5), (82.5, 0.3), (110.0, 0.15)):
        for i in range(n):
            wobble = 1 + 0.25 * math.sin(2 * math.pi * i / n * 2)
            out[i] += g * wobble * math.sin(2 * math.pi * f * i / RATE)
    out = lowpass(out, 400)

    # Drums: 64 bpm, pattern accents, wraps evenly into 32 s.
    beat = 60 / 64
    t, k = 0.0, 0
    pattern = (1.0, 0.0, 0.55, 0.0, 1.0, 0.35, 0.55, 0.0)
    while t < seconds - 0.8:
        g = pattern[k % len(pattern)]
        if g:
            mix(out, thud(48, 0.8, 6, 0.6, rng, 300), t, 0.9 * g)
        t += beat / 2
        k += 1
    del out[n:]

    # Wind: slow-swelling filtered noise, crossfaded at the loop point.
    wind = lowpass(highpass(noise(seconds, rng), 150), 700)
    for i in range(n):
        swell = 0.5 + 0.5 * math.sin(2 * math.pi * i / n * 3)
        out[i] += wind[i] * 0.35 * swell
    xf = int(1.0 * RATE)
    for i in range(xf):
        a = i / xf
        out[i] = out[i] * a + out[n - xf + i] * (1 - a)
    return out[: n - xf]


if __name__ == '__main__':
    main()
