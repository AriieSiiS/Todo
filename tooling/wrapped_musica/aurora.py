# Compone «Aurora», la primera banda sonora del Wrapped. Uso: python aurora.py <salida.wav>
import sys
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve
from scipy.io import wavfile

SR = 44100
BPM = 92
BEAT = 60 / BPM
BAR = BEAT * 4
BARS = 48
DUR = BARS * BAR + 4.0
N = int(DUR * SR)
rng = np.random.default_rng(2026)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def buf():
    return np.zeros((N, 2))


def place(bus, start, sig, pan=0.0, gain=1.0):
    i = int(start * SR)
    if i >= N:
        return
    sig = sig[: N - i]
    l = np.cos((pan + 1) * np.pi / 4)
    r = np.sin((pan + 1) * np.pi / 4)
    if sig.ndim == 1:
        bus[i:i + len(sig), 0] += sig * l * gain * 1.414
        bus[i:i + len(sig), 1] += sig * r * gain * 1.414
    else:
        bus[i:i + len(sig)] += sig * gain


def lowpass(x, f, order=2):
    sos = butter(order, f, 'low', fs=SR, output='sos')
    return sosfilt(sos, x, axis=0)


def highpass(x, f, order=2):
    sos = butter(order, f, 'high', fs=SR, output='sos')
    return sosfilt(sos, x, axis=0)


def bandpass(x, lo, hi, order=2):
    sos = butter(order, [lo, hi], 'band', fs=SR, output='sos')
    return sosfilt(sos, x, axis=0)


def reverb(x, seconds=2.8, damp=5000, mix=0.35):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    env = np.exp(-t * 6.9 / seconds)
    ir = np.stack([rng.standard_normal(n) * env, rng.standard_normal(n) * env], 1)
    ir = lowpass(ir, damp)
    ir[: int(0.012 * SR)] = 0
    ir /= np.sqrt((ir ** 2).sum() / 2)
    wet = np.stack([fftconvolve(x[:, c], ir[:, c])[: len(x)] for c in range(2)], 1)
    return x * (1 - mix) + wet * mix * 0.55


# Progresión (la menor): Am(add9) – Fmaj7 – C(add9) – G6, un compás cada uno.
CHORDS = [
    [57, 60, 64, 71],   # Am9 sin fundamental grave
    [53, 57, 60, 64],   # Fmaj7
    [55, 60, 64, 62 + 12 - 12],  # C add9 (sol en el grave)
    [55, 59, 62, 64],   # G6
]
ROOTS = [45, 41, 48, 43]


def chord_at(bar):
    return bar % 4


def section(bar):
    if bar < 8:
        return 'intro'
    if bar < 24:
        return 'b'
    if bar < 40:
        return 'c'
    return 'outro'


# ------------------------------------------------------------- pad
def pad_note(freq, dur, bright):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for det in (-0.11, -0.04, 0.04, 0.11):
        f = freq * 2 ** (det / 12)
        ph = rng.uniform(0, 2 * np.pi)
        h = 1
        while h * f < bright and h <= 24:
            out += np.sin(2 * np.pi * f * h * t + ph * h) / h * (0.92 ** h)
            h += 1
    a = min(0.9, dur / 3)
    r = min(1.2, dur / 3)
    env = np.minimum(1, t / a) * np.minimum(1, (dur - t) / r).clip(0)
    lfo = 1 + 0.08 * np.sin(2 * np.pi * 0.21 * t + rng.uniform(0, 6))
    return out * env * lfo / 6


pad = buf()
for bar in range(BARS):
    sec = section(bar)
    bright = {'intro': 1200 + bar * 120, 'b': 2600, 'c': 3800, 'outro': 2200 - (bar - 40) * 150}[sec]
    for k, note in enumerate(CHORDS[chord_at(bar)]):
        sig = pad_note(midi(note), BAR + 0.8, bright)
        place(pad, bar * BAR, sig, pan=(-0.45, -0.15, 0.15, 0.45)[k], gain=0.55)

# ------------------------------------------------------------- arpegio pulsado
def pluck(freq, dur=0.9, vel=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    mod = np.sin(2 * np.pi * freq * 2 * t) * 1.2 * np.exp(-t * 9)
    s = np.sin(2 * np.pi * freq * t + mod) + 0.3 * np.sin(2 * np.pi * freq * 2 * t)
    env = np.exp(-t * 5.5) * np.minimum(1, t / 0.003)
    return s * env * vel * 0.32


arp = buf()
PATTERN = [0, 1, 2, 3, 2, 1, 3, 2]
for bar in range(BARS):
    sec = section(bar)
    if sec == 'intro' and bar < 4:
        continue
    notes = CHORDS[chord_at(bar)]
    for i in range(8):
        n = notes[PATTERN[i]] + 12
        if sec == 'c' and i % 2 == 1:
            n += 12 if (bar + i) % 3 == 0 else 0
        vel = (0.9 if i % 2 == 0 else 0.6) * (0.6 if sec == 'intro' else 1)
        place(arp, bar * BAR + i * BEAT / 2, pluck(midi(n), vel=vel), pan=(-0.5 if i % 2 else 0.5) * 0.6)
# eco estéreo de corchea con puntillo
delay = int(BEAT * 0.75 * SR)
eco = np.zeros_like(arp)
src = arp.copy()
for k in range(1, 6):
    g = 0.42 ** k
    shifted = np.zeros_like(src)
    shifted[delay * k:] = src[: N - delay * k]
    if k % 2:
        shifted = shifted[:, ::-1]
    eco += shifted * g
arp = arp + lowpass(eco, 3500) * 0.8

# ------------------------------------------------------------- bajo
def bass_note(freq, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * freq * 2 * t)
    s = np.tanh(s * 1.6)
    env = np.minimum(1, t / 0.01) * np.exp(-t * 1.2) * np.minimum(1, (dur - t) / 0.05).clip(0)
    return s * env * 0.5


bass = buf()
for bar in range(BARS):
    sec = section(bar)
    if sec in ('intro',):
        continue
    root = ROOTS[chord_at(bar)]
    hits = [(0, 1.4), (1.5, 0.9), (2.5, 1.2), (3.5, 0.45)] if sec == 'c' else [(0, 1.9), (2.5, 1.4)]
    for b, d in hits:
        place(bass, bar * BAR + b * BEAT, bass_note(midi(root), d * BEAT), gain=0.9 if sec != 'outro' else 0.6)

# ------------------------------------------------------------- batería
def kick():
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    f = 46 + 110 * np.exp(-t * 28)
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = np.sin(ph) * np.exp(-t * 7.5)
    s[: int(0.004 * SR)] += rng.standard_normal(int(0.004 * SR)) * 0.25
    return np.tanh(s * 1.4) * 0.95


def snare():
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    noise = bandpass(rng.standard_normal(n), 900, 7000) * np.exp(-t * 16)
    tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30)
    return (noise * 0.55 + tone * 0.35)


def hat(open_=False):
    n = int((0.22 if open_ else 0.06) * SR)
    t = np.arange(n) / SR
    s = highpass(rng.standard_normal(n), 7500, 4) * np.exp(-t * (14 if open_ else 70))
    return s * 0.28


drums = buf()
snares = buf()
kick_times = []
for bar in range(BARS):
    sec = section(bar)
    if sec == 'intro' and bar < 6:
        continue
    t0 = bar * BAR
    if sec == 'intro':  # redoble de entrada
        if bar == 7:
            for i in range(8):
                place(snares, t0 + 2 * BEAT + i * BEAT / 4, snare(), gain=0.15 + i * 0.05)
        continue
    kicks = [0, 2, 2.75] if sec == 'c' else [0, 2.5]
    if sec == 'outro' and bar >= 46:
        kicks = [0]
    for k in kicks:
        place(drums, t0 + k * BEAT, kick(), gain=0.95)
        kick_times.append(t0 + k * BEAT)
    if sec != 'outro' or bar < 44:
        for b in (1, 3):
            place(snares, t0 + b * BEAT, snare(), gain=0.7)
    for i in range(8):
        sw = 0.018 if i % 2 else 0
        place(drums, t0 + i * BEAT / 2 + sw, hat(open_=(i == 7 and sec == 'c')),
              pan=0.25, gain=0.9 if i % 2 == 0 else 0.55)
snares = reverb(snares, 1.6, 6000, 0.3)

# ------------------------------------------------------------- melodía de campanas
def bell(freq, dur=2.4, vel=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    mod = np.sin(2 * np.pi * freq * 3.5 * t) * 2.2 * np.exp(-t * 3.5)
    s = np.sin(2 * np.pi * freq * t + mod)
    return s * np.exp(-t * 1.9) * np.minimum(1, t / 0.002) * 0.22 * vel


MELODY = [  # (compás relativo, pulso, nota)
    (0, 0, 76), (0, 1.5, 74), (0, 2.5, 72), (0, 3, 71),
    (1, 0, 72), (1, 2, 69), (1, 3, 72),
    (2, 0, 79), (2, 1.5, 76), (2, 2.5, 74), (2, 3, 72),
    (3, 0, 74), (3, 2, 71), (3, 3.5, 67),
]
lead = buf()
for bar in range(24, 40, 4):
    for rb, b, n in MELODY:
        place(lead, (bar + rb) * BAR + b * BEAT, bell(midi(n), vel=0.9 if bar < 32 else 1.05), pan=0.1)
for bar in range(40, 44, 4):
    for rb, b, n in MELODY[:7]:
        place(lead, (bar + rb) * BAR + b * BEAT, bell(midi(n), vel=0.55), pan=-0.1)

# ------------------------------------------------------------- mezcla
duck = np.ones(N)
dl = int(0.38 * SR)
curve = 1 - 0.55 * np.exp(-np.arange(dl) / SR * 9)
for kt in kick_times:
    i = int(kt * SR)
    j = min(N, i + dl)
    duck[i:j] = np.minimum(duck[i:j], curve[: j - i])
duck = duck[:, None]

pad_w = reverb(pad, 3.5, 4500, 0.45)
arp_w = reverb(arp, 2.6, 5000, 0.3)
lead_w = reverb(lead, 3.2, 6500, 0.42)
mix = (pad_w * 0.55 * duck + arp_w * 0.42 * (0.4 + 0.6 * duck) + bass * 0.55 * duck
       + drums * 0.62 + snares * 0.5 + lead_w * 0.5)
mix = highpass(mix, 28)
# ruido de cinta muy suave para dar calidez
mix += lowpass(rng.standard_normal((N, 2)) * 0.0025, 6000)
peak = np.max(np.abs(mix))
mix = np.tanh(mix / peak * 1.25) / np.tanh(1.25) * 0.89
t = np.arange(N) / SR
fade = np.minimum(1, t / 1.2) * np.minimum(1, (DUR - t) / 3.5).clip(0)
mix *= fade[:, None]
out = sys.argv[1]
wavfile.write(out, SR, (mix * 32767).astype(np.int16))
print('ok', DUR)
