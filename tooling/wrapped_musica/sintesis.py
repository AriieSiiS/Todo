# Pequeña biblioteca de síntesis para las bandas sonoras del Wrapped.
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve, lfilter

SR = 44100
rng = np.random.default_rng(7)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


class Pista:
    def __init__(self, segundos):
        self.n = int(segundos * SR)
        self.buses = {}

    def bus(self, nombre):
        if nombre not in self.buses:
            self.buses[nombre] = np.zeros((self.n, 2))
        return self.buses[nombre]

    def poner(self, nombre, inicio, senal, pan=0.0, gan=1.0):
        b = self.bus(nombre)
        i = int(inicio * SR)
        if i >= self.n or i < 0:
            return
        senal = senal[: self.n - i]
        if senal.ndim == 1:
            l = np.cos((pan + 1) * np.pi / 4) * 1.414
            r = np.sin((pan + 1) * np.pi / 4) * 1.414
            b[i:i + len(senal), 0] += senal * l * gan
            b[i:i + len(senal), 1] += senal * r * gan
        else:
            b[i:i + len(senal)] += senal * gan


def paso_bajo(x, f, orden=2):
    return sosfilt(butter(orden, min(f, SR / 2 - 100), 'low', fs=SR, output='sos'), x, axis=0)


def paso_alto(x, f, orden=2):
    return sosfilt(butter(orden, f, 'high', fs=SR, output='sos'), x, axis=0)


def paso_banda(x, lo, hi, orden=2):
    return sosfilt(butter(orden, [lo, hi], 'band', fs=SR, output='sos'), x, axis=0)


def env_adsr(n, a=0.01, d=0.1, s=0.7, r=0.2):
    t = np.arange(n) / SR
    dur = n / SR
    e = np.where(t < a, t / max(a, 1e-4),
                 np.where(t < a + d, 1 - (1 - s) * (t - a) / max(d, 1e-4), s))
    rel = np.clip((dur - t) / max(r, 1e-4), 0, 1)
    return e * rel


def reverb(x, seg=2.5, oscuro=5000, mezcla=0.3, semilla=1):
    g = np.random.default_rng(semilla)
    n = int(seg * SR)
    t = np.arange(n) / SR
    env = np.exp(-t * 6.9 / seg)
    ir = np.stack([g.standard_normal(n) * env, g.standard_normal(n) * env], 1)
    ir = paso_bajo(ir, oscuro)
    ir[: int(0.015 * SR)] *= np.linspace(0, 1, int(0.015 * SR))[:, None]
    ir /= np.sqrt((ir ** 2).sum() / 2)
    h = np.stack([fftconvolve(x[:, c], ir[:, c])[: len(x)] for c in range(2)], 1)
    return x * (1 - mezcla) + h * mezcla * 0.5


def eco(x, retardo, fb=0.35, veces=5, oscuro=3500, cruzado=True):
    d = int(retardo * SR)
    sal = np.zeros_like(x)
    for k in range(1, veces + 1):
        s = np.zeros_like(x)
        s[d * k:] = x[: len(x) - d * k]
        if cruzado and k % 2:
            s = s[:, ::-1]
        sal += s * fb ** k
    return x + paso_bajo(sal, oscuro)


# ------------------------------------------------------------ instrumentos

def pulsada(f, dur=2.0, brillo=0.5, decaimiento=0.996, vel=1.0):
    """Cuerda pulsada (laúd, arpa) por Karplus-Strong."""
    n = int(dur * SR)
    N = max(2, int(round(SR / f - 0.5)))
    exc = rng.standard_normal(N)
    exc = paso_bajo(exc, 1500 + 7000 * brillo)
    x = np.zeros(n)
    x[:N] = exc
    a = np.zeros(N + 2)
    a[0] = 1
    a[N] = -decaimiento / 2
    a[N + 1] = -decaimiento / 2
    y = lfilter([1.0], a, x)
    y *= np.minimum(1, (n - np.arange(n)) / (0.05 * SR))
    return y / (np.max(np.abs(y)) + 1e-9) * 0.5 * vel


def flauta(f, dur, vel=1.0, vibrato=5.2):
    n = int(dur * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.006 * np.sin(2 * np.pi * vibrato * t) * np.clip((t - 0.25) / 0.3, 0, 1)
    fase = 2 * np.pi * np.cumsum(f * vib) / SR
    tono = np.sin(fase) + 0.18 * np.sin(2 * fase) + 0.08 * np.sin(3 * fase)
    aire = paso_banda(rng.standard_normal(n), f * 0.9, min(f * 3, 12000)) * 0.12
    env = env_adsr(n, 0.07, 0.15, 0.85, min(0.25, dur / 3))
    return (tono + aire) * env * 0.32 * vel


def epiano(f, dur, vel=1.0):
    """Piano eléctrico por FM (carácter de Rhodes)."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    indice = 1.8 * vel * np.exp(-t * 3.5) + 0.25
    mod = np.sin(2 * np.pi * f * t) * indice
    car = np.sin(2 * np.pi * f * t + mod)
    campana = np.sin(2 * np.pi * f * 14 * t) * np.exp(-t * 40) * 0.12
    env = np.exp(-t * 1.1) * np.minimum(1, t / 0.004) * np.clip((dur - t) / 0.08, 0, 1)
    return (car + campana) * env * 0.28 * vel


def sierra(f, dur, voces=5, desafinar=0.12, armonicos=30, lim=9000):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for v in range(voces):
        cents = desafinar * (v - (voces - 1) / 2) / max(1, (voces - 1) / 2)
        fv = f * 2 ** (cents / 12)
        ph = rng.uniform(0, 2 * np.pi)
        h = 1
        while h <= armonicos and fv * h < lim:
            out += np.sin(2 * np.pi * fv * h * t + ph * h) / h
            h += 1
    return out / voces


def cuerdas(f, dur, brillo=4000):
    s = sierra(f, dur, 5, 0.1, 25, brillo)
    return s * env_adsr(len(s), min(0.6, dur / 3), 0.2, 0.9, min(0.8, dur / 3)) * 0.25


def metal(f, dur, vel=1.0):
    """Metales: sierra con filtro que se abre al inicio."""
    s = sierra(f, dur, 3, 0.06, 22, 6000)
    n = len(s)
    t = np.arange(n) / SR
    # apertura del filtro aproximada mezclando versión oscura y brillante
    oscuro = paso_bajo(s, 700)
    mezcla = np.clip(t / 0.25, 0, 1) * 0.6
    s = oscuro * (1 - mezcla) + s * mezcla
    return s * env_adsr(n, 0.06, 0.2, 0.8, 0.25) * 0.3 * vel


def coro(f, dur):
    s = sierra(f, dur, 4, 0.08, 30, 5000)
    v = sum(paso_banda(s, a, b) * g for a, b, g in
            [(600, 850, 1.0), (1050, 1350, 0.6), (2400, 2800, 0.25)])
    return v * env_adsr(len(s), 0.5, 0.2, 0.9, 0.6) * 0.6


def zanfona(f, dur):
    """Bordón nasal de zanfona/gaita."""
    s = sierra(f, dur, 2, 0.05, 40, 7000)
    s = paso_banda(s, 300, 3500) + 0.3 * paso_banda(s, 1200, 1700)
    return s * env_adsr(len(s), 0.3, 0.1, 1, 0.5) * 0.18


def bajo(f, dur, vel=1.0, suave=True):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.sin(2 * np.pi * f * t) + 0.2 * np.sin(4 * np.pi * f * t)
    if not suave:
        s = np.tanh(s * 2)
    env = np.minimum(1, t / 0.008) * np.exp(-t * 1.0) * np.clip((dur - t) / 0.05, 0, 1)
    return s * env * 0.45 * vel


def bajo_sierra(f, dur, vel=1.0):
    s = paso_bajo(sierra(f, dur, 2, 0.05, 20, 4000), 900)
    return s * env_adsr(len(s), 0.005, 0.15, 0.6, 0.05) * 0.5 * vel


# ------------------------------------------------------------ percusión

def bombo(suave=False):
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    f = 45 + (90 if suave else 120) * np.exp(-t * 30)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * (6 if suave else 7.5))
    if not suave:
        s[: int(0.003 * SR)] += rng.standard_normal(int(0.003 * SR)) * 0.2
    return np.tanh(s * 1.3)


def caja(lofi=True):
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    ruido = paso_banda(rng.standard_normal(n), 800, 5000 if lofi else 9000) * np.exp(-t * 18)
    tono = np.sin(2 * np.pi * 185 * t) * np.exp(-t * 28)
    s = ruido * 0.6 + tono * 0.4
    return paso_bajo(s, 4500) if lofi else s


def palmada():
    n = int(0.3 * SR)
    s = np.zeros(n)
    for k, g in [(0, 1), (0.011, 0.8), (0.022, 0.7)]:
        i = int(k * SR)
        m = n - i
        tt = np.arange(m) / SR
        s[i:] += paso_banda(rng.standard_normal(m), 900, 3500) * np.exp(-tt * 30) * g
    return s * 0.7


def pandero(mano=True):
    """Pandero o bendir: golpe grave con cuero y un toque de cascabel."""
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    f = 95 + 40 * np.exp(-t * 25)
    cuero = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)
    golpe = paso_banda(rng.standard_normal(n), 200, 1800) * np.exp(-t * 35) * 0.5
    return (cuero + golpe) * (0.9 if mano else 0.6)


def tek():
    n = int(0.2 * SR)
    t = np.arange(n) / SR
    return paso_banda(rng.standard_normal(n), 1500, 6000) * np.exp(-t * 45) * 0.5


def charles(abierto=False):
    n = int((0.25 if abierto else 0.05) * SR)
    t = np.arange(n) / SR
    return paso_alto(rng.standard_normal(n), 7000, 4) * np.exp(-t * (14 if abierto else 80)) * 0.3


def sonajero():
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    env = np.minimum(1, t / 0.02) * np.exp(-t * 30)
    return paso_banda(rng.standard_normal(n), 4000, 11000) * env * 0.25


def timbal():
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    f = 65 + 25 * np.exp(-t * 6)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 2.2)
    s += paso_bajo(rng.standard_normal(n), 300) * np.exp(-t * 12) * 0.4
    return s * 0.9


# ------------------------------------------------------------ acabado

def vinilo(n, nivel=1.0):
    ruido = paso_banda(rng.standard_normal(n), 300, 6000) * 0.004 * nivel
    chasquidos = np.zeros(n)
    pos = rng.integers(0, n, int(n / SR * 9))
    chasquidos[pos] = rng.uniform(0.05, 0.25, len(pos)) * rng.choice([-1, 1], len(pos))
    chasquidos = paso_bajo(chasquidos, 3500) * nivel
    return np.stack([ruido + chasquidos, ruido + np.roll(chasquidos, 37)], 1)


def cinta(x, profundidad=0.0018, velocidad=0.55):
    """Ligero vaivén de afinación, como una cinta vieja."""
    n = len(x)
    t = np.arange(n) / SR
    desvio = profundidad * np.sin(2 * np.pi * velocidad * t) + 0.0006 * np.sin(2 * np.pi * 3.1 * t)
    idx = np.clip(np.arange(n) + desvio * SR, 0, n - 1)
    return np.stack([np.interp(idx, np.arange(n), x[:, c]) for c in range(2)], 1)


def bombeo(n, golpes, profundidad=0.5, dur=0.35):
    env = np.ones(n)
    dl = int(dur * SR)
    curva = 1 - profundidad * np.exp(-np.arange(dl) / SR * 10)
    for g in golpes:
        i = int(g * SR)
        j = min(n, i + dl)
        if i < n:
            env[i:j] = np.minimum(env[i:j], curva[: j - i])
    return env[:, None]


def masterizar(x, segundos, lufs_objetivo=0.22, fundido_entrada=1.0, fundido_salida=3.0):
    x = paso_alto(x, 30)
    pico = np.max(np.abs(x)) + 1e-9
    x = x / pico
    rms = np.sqrt((x ** 2).mean())
    x = x * (lufs_objetivo / rms)
    x = np.tanh(x * 1.1) / np.tanh(1.1)
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.9
    t = np.arange(len(x)) / SR
    f = np.minimum(1, t / fundido_entrada) * np.clip((segundos - t) / fundido_salida, 0, 1)
    return x * f[:, None]
