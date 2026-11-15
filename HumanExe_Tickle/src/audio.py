"""Synthesize cinematic electronic music + SFX and mix with narration.

All audio is generated procedurally here (no third-party samples).
Usage: python3 audio.py BUILD_DIR
"""
import sys
import numpy as np
import soundfile as sf
from scipy import signal

SR = 48000
DUR = 27.5
N = int(SR * DUR)
rng = np.random.default_rng(7)
T = np.arange(N) / SR
BPM = 120.0
BEAT = 60.0 / BPM

IMPACT_T = (528 - 1) / 30.0  # frame where the other person's hand lands
CUTS = [1.5, 3.0, 5.0, 7.0, 9.0, 11.5, 13.5, 15.5, 17.3, 19.3, 21.5]


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def lp(x, fc, order=2):
    b, a = signal.butter(order, fc / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def hp(x, fc, order=2):
    b, a = signal.butter(order, fc / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bp(x, f1, f2, order=2):
    b, a = signal.butter(order, [f1 / (SR / 2), f2 / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def env_adsr(n, a, d, s, r, hold):
    a, d, r, hold = int(a * SR), int(d * SR), int(r * SR), int(hold * SR)
    e = np.concatenate([np.linspace(0, 1, max(a, 1)), np.linspace(1, s, max(d, 1)),
                        np.full(max(hold, 0), s), np.linspace(s, 0, max(r, 1))])
    return e[:n] if len(e) >= n else np.pad(e, (0, n - len(e)))


def saw(f, t, detune=0.0):
    ph = (f * (1 + detune)) * t
    return 2 * (ph - np.floor(ph + 0.5))


def place(buf, x, t0, gain=1.0):
    i0 = int(t0 * SR)
    if i0 >= len(buf):
        return
    x = x[: len(buf) - i0]
    if i0 < 0:
        x = x[-i0:]; i0 = 0
    buf[i0:i0 + len(x)] += gain * x


# ------------------------------------------------------------------ music
def music():
    out = np.zeros((N, 2))
    # A minor progression, 2 bars (4 s) each: Am - F - C - G
    prog = [(57, [57, 60, 64]), (53, [53, 57, 60]), (48, [55, 60, 64]), (55, [55, 59, 62])]
    pad = np.zeros(N); bass = np.zeros(N); arp = np.zeros(N)
    seg = 4.0
    k = 0
    t0 = 0.0
    while t0 < DUR:
        root, chord = prog[k % 4]
        n = int(seg * SR) + int(0.6 * SR)
        tt = np.arange(n) / SR
        e = env_adsr(n, 0.9, 0.5, 0.8, 0.8, seg - 1.6)
        v = np.zeros(n)
        for m in chord + [chord[0] + 12]:
            for dt in (-0.004, 0.0, 0.005):
                v += saw(midi(m), tt, dt)
        v = lp(v, 900) * e * 0.05
        place(pad, v, t0)
        # pulsing bass on 8ths (sidechain-like envelope)
        for j in range(int(seg / (BEAT / 2))):
            tb = t0 + j * BEAT / 2
            nb = int(BEAT / 2 * SR)
            tt2 = np.arange(nb) / SR
            f = midi(root - 12)
            b = (np.sin(2 * np.pi * f * tt2) + 0.35 * saw(f, tt2)) * np.exp(-tt2 * 7)
            b *= np.minimum(1, tt2 / 0.004)
            place(bass, lp(b, 380), tb, 0.33)
        # glassy 16th arpeggio
        notes = chord + [chord[1] + 12, chord[2] + 12, chord[0] + 24, chord[2] + 12]
        for j in range(int(seg / (BEAT / 4))):
            ta = t0 + j * BEAT / 4
            na = int(0.25 * SR)
            tt3 = np.arange(na) / SR
            f = midi(notes[j % len(notes)] + 12)
            a = (np.sin(2 * np.pi * f * tt3) + 0.2 * np.sin(4 * np.pi * f * tt3)) * np.exp(-tt3 * 16)
            place(arp, a, ta, 0.05)
        t0 += seg; k += 1
    # drums
    kick = np.zeros(N); hat = np.zeros(N)
    nk = int(0.35 * SR); tk = np.arange(nk) / SR
    kf = 45 + 110 * np.exp(-tk * 30)
    ks = np.sin(2 * np.pi * np.cumsum(kf) / SR) * np.exp(-tk * 9)
    ks = np.tanh(ks * 1.6) * 0.55
    nh = int(0.05 * SR)
    for i in range(int(DUR / BEAT) + 1):
        tb = i * BEAT
        drop = (14.9 < tb < IMPACT_T) or tb < 2.95 or tb > 21.4
        if not drop:
            place(kick, ks, tb)
        if 3.0 < tb < 21.4 and not (14.9 < tb < IMPACT_T):
            h = hp(rng.standard_normal(nh), 7000) * np.exp(-np.arange(nh) / SR * 70)
            place(hat, h, tb + BEAT / 2, 0.06)
    # gentle sidechain duck from kicks on pad/bass
    sc = np.ones(N)
    for i in range(int(DUR / BEAT) + 1):
        tb = i * BEAT
        if not ((14.9 < tb < IMPACT_T) or tb < 2.95 or tb > 21.4):
            i0 = int(tb * SR); n = int(0.25 * SR)
            sc[i0:i0 + n] = np.minimum(sc[i0:i0 + n], 0.55 + 0.45 * np.linspace(0, 1, len(sc[i0:i0 + n])) ** 0.7)
    # arp only after hook, thins out for the outro
    arp_gain = np.clip((T - 2.8) / 0.3, 0, 1) * np.clip((22.5 - T) / 1.5, 0.25, 1)
    mono = (pad * 1.0 + bass * sc) * sc + kick + hat
    out[:, 0] = mono + arp * arp_gain * 0.9
    out[:, 1] = mono + np.roll(arp * arp_gain, int(0.012 * SR)) * 1.0  # stereo width
    # fade out end
    fade = np.clip((DUR - T) / 2.0, 0, 1)
    out *= fade[:, None]
    return out


# ------------------------------------------------------------------ sfx
def whoosh(d=0.55, up=True):
    n = int(d * SR); t = np.arange(n) / SR
    x = rng.standard_normal(n)
    fc = np.linspace(400, 5000, n) if up else np.linspace(5000, 400, n)
    y = np.zeros(n)
    # time-varying bandpass via short blocks
    blk = 512
    for i in range(0, n, blk):
        f = fc[i]
        y[i:i + blk] = bp(x[max(0, i - 2048):i + blk], f * 0.6, min(f * 1.6, 20000))[-len(y[i:i + blk]):]
    e = np.sin(np.pi * np.clip(t / d, 0, 1)) ** 2
    return y * e * 0.5


def impact(big=1.0):
    n = int(1.6 * SR); t = np.arange(n) / SR
    f = 32 + 80 * np.exp(-t * 14)
    sub = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 2.8)
    noise = lp(rng.standard_normal(n), 2500) * np.exp(-t * 14)
    crack = hp(rng.standard_normal(n), 3000) * np.exp(-t * 40)
    return np.tanh((sub * 1.2 + noise * 0.5 + crack * 0.3) * 1.5) * 0.7 * big


def zap(d=0.35, f0=1800, f1=300):
    n = int(d * SR); t = np.arange(n) / SR
    f = np.geomspace(f0, f1, n)
    s = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.3 + np.sin(2 * np.pi * np.cumsum(f * 1.5) / SR) * 0.4
    s *= (rng.random(n) > 0.15)  # crackle
    return lp(s, 6000) * np.exp(-t * 7) * 0.35


def blip(f=1400, d=0.09):
    n = int(d * SR); t = np.arange(n) / SR
    return np.sin(2 * np.pi * f * t) * np.exp(-t * 45) * 0.35


def riser(d=0.9):
    n = int(d * SR); t = np.arange(n) / SR
    x = rng.standard_normal(n)
    y = np.zeros(n); blk = 512
    for i in range(0, n, blk):
        f = 300 + 7000 * (i / n) ** 2
        y[i:i + blk] = bp(x[max(0, i - 2048):i + blk], f * 0.7, min(f * 1.4, 20000))[-len(y[i:i + blk]):]
    tone = np.sin(2 * np.pi * np.cumsum(np.geomspace(200, 1600, n)) / SR) * 0.25
    return (y * 0.5 + tone) * (t / d) ** 2


def shimmer(d=1.4):
    n = int(d * SR); t = np.arange(n) / SR
    s = np.zeros(n)
    for m in (76, 81, 84, 88, 93):
        s += np.sin(2 * np.pi * midi(m) * t + rng.random() * 6) * np.exp(-t * 2.2) * (0.5 + 0.5 * np.sin(2 * np.pi * 7 * t))
    return s * 0.06 * np.minimum(1, t / 0.05)


def sfx():
    L = np.zeros(N); R = np.zeros(N)

    def put(x, t0, g=1.0, pan=0.0):
        place(L, x, t0, g * (1 - max(pan, 0)))
        place(R, x, t0, g * (1 + min(pan, 0)))

    put(impact(1.0), 0.0, 0.9)
    put(zap(0.5, 3000, 200), 0.02, 0.7)
    put(whoosh(0.7), -0.15, 0.6)  # fast zoom
    for i, c in enumerate(CUTS):
        put(whoosh(0.45, up=(i % 2 == 0)), c - 0.28, 0.42, pan=0.4 if i % 2 else -0.4)
    # touch / nerve / brain events
    for tt in np.arange(3.2, 5.0, 0.55):
        put(blip(2200, 0.06), tt, 0.35, pan=-0.3)
    put(zap(0.9, 2400, 500), 5.15, 0.55, pan=-0.2)          # nerve pulse travels
    put(zap(0.6, 600, 2400), 7.1, 0.45)                     # climbs brainstem
    put(impact(0.35), 8.25, 0.6)                            # arrives at cortex
    put(shimmer(1.6), 9.6, 1.0)                             # cerebellum lights up
    put(zap(0.5, 2600, 900), 13.6, 0.4, pan=0.3)            # prediction signal
    put(zap(0.5, 700, 1500), 13.65, 0.35, pan=-0.3)         # touch signal
    put(blip(880, 0.12), 14.55, 0.5); put(blip(1320, 0.12), 14.68, 0.5)  # "match"
    for tt in np.arange(15.6, 17.3, 0.55):
        put(blip(2200, 0.06), tt, 0.3, pan=-0.3)
    put(riser(0.75), IMPACT_T - 0.75, 0.6)
    put(impact(1.3), IMPACT_T, 1.0)
    put(zap(0.6, 4000, 300), IMPACT_T + 0.02, 0.6)
    put(zap(0.7, 3500, 250), 19.32, 0.55)
    put(impact(0.9), 19.3, 0.75)                            # brain lights up
    put(riser(0.6), 20.9, 0.35)
    put(impact(0.7), 21.5, 0.6)                             # logo slam
    put(shimmer(2.2), 21.55, 1.2)
    put(zap(0.3, 2000, 800), 21.6, 0.35)
    # headline text pops
    for tt in (0.1, 3.05, 9.05, 17.6, 25.0):
        put(blip(1800, 0.05), tt, 0.4)
    return np.stack([L, R], axis=1)


def envelope(x, att=0.01, rel=0.25):
    a = np.exp(-1 / (att * SR)); r = np.exp(-1 / (rel * SR))
    e = np.zeros_like(x); v = 0.0
    ax = np.abs(x)
    # block-wise for speed
    blk = 240
    for i in range(0, len(x), blk):
        m = ax[i:i + blk].max()
        v = m if m > v else v * (r ** blk)
        e[i:i + blk] = v
    return e


def main(build):
    voice, vsr = sf.read(f"{build}/narration.wav")
    voice = signal.resample_poly(voice, SR, vsr)
    v = np.zeros(N); v[:min(N, len(voice))] = voice[:N]
    # voice polish: high-pass rumble, gentle presence, normalize
    v = hp(v, 80)
    v = v + 0.25 * bp(v, 2500, 6000)
    v = v / np.max(np.abs(v)) * 0.85
    mus = music()
    mus = mus / np.max(np.abs(mus)) * 0.55
    fx = sfx()
    fx = fx / np.max(np.abs(fx)) * 0.75
    # duck music under narration (~ -9 dB)
    ve = envelope(v, 0.02, 0.35)
    duck = 1.0 - 0.65 * np.clip(ve / 0.15, 0, 1)
    duck = lp(duck, 8)
    mix = mus * (0.42 * duck)[:, None] + fx * 0.55 + np.stack([v, v], 1) * 1.0
    mix = np.tanh(mix * 1.1) / 1.1
    sf.write(f"{build}/mix_raw.wav", mix.astype(np.float32), SR)
    sf.write(f"{build}/music_only.wav", (mus * 0.42).astype(np.float32), SR)
    sf.write(f"{build}/sfx_only.wav", (fx * 0.55).astype(np.float32), SR)


if __name__ == "__main__":
    main(sys.argv[1])
