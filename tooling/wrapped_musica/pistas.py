# Bandas sonoras originales del Wrapped. Uso: python pistas.py <nombre> <salida.wav>
import sys
import numpy as np
from scipy.io import wavfile
from sintesis import *


def notas(lista):
    """('A4', ...) → números MIDI."""
    base = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
    res = []
    for n in lista:
        s = 0
        nombre = n[0]
        resto = n[1:]
        if resto[0] in '#b':
            s = 1 if resto[0] == '#' else -1
            resto = resto[1:]
        res.append(12 * (int(resto) + 1) + base[nombre] + s)
    return res


def melodia(p, bus, inicio_compas, compas, frases, instrumento, pan=0.0, gan=1.0, transp=0):
    """frases: lista de compases; cada compás, lista de (nota|None, pulsos)."""
    pulso = compas / 4
    for k, comp in enumerate(frases):
        t = (inicio_compas + k) * compas
        for nota, dur in comp:
            if nota is not None:
                f = midi(notas([nota])[0] + transp)
                p.poner(bus, t, instrumento(f, dur * pulso * 1.05), pan=pan, gan=gan)
            t += dur * pulso


# ============================================================ taberna
def taberna():
    bpm = 78
    pulso = 60 / bpm
    compas = pulso * 4
    compases = 36
    seg = compases * compas + 4
    p = Pista(seg)
    acordes = [
        notas(['D3', 'A3', 'D4', 'F4', 'A4']), notas(['C3', 'G3', 'C4', 'E4', 'G4']),
        notas(['D3', 'A3', 'D4', 'F4', 'A4']), notas(['A2', 'E3', 'A3', 'C4', 'E4']),
        notas(['D3', 'A3', 'D4', 'F4', 'A4']), notas(['C3', 'G3', 'C4', 'E4', 'G4']),
        notas(['Bb2', 'F3', 'Bb3', 'D4', 'F4']), notas(['A2', 'E3', 'A3', 'C#4', 'E4']),
    ]
    patron = [0, 2, 3, 4, 1, 3, 4, 2]
    golpes = []
    for c in range(compases):
        ac = acordes[c % 8]
        t0 = c * compas
        final = c >= 32
        for i, idx in enumerate(patron):
            sw = 0.06 * pulso if i % 2 else 0
            vel = 0.95 if i in (0, 4) else 0.62
            if final and i > 4 and c == compases - 1:
                break
            p.poner('laud', t0 + i * pulso / 2 + sw,
                    pulsada(midi(ac[idx]), 2.2, brillo=0.35, vel=vel),
                    pan=(-0.35 if idx < 2 else 0.3))
        if 4 <= c < 32:
            p.poner('bajo', t0, bajo(midi(ac[0] - 12), pulso * 1.8), gan=0.9)
            p.poner('bajo', t0 + 2.5 * pulso, bajo(midi(ac[1] - 12), pulso * 1.2), gan=0.7)
        if 4 <= c < 32 and not (c in (19, 27)):
            for k in (0, 1.75, 2.5):
                p.poner('perc', t0 + k * pulso, pandero(), gan=0.85)
                golpes.append(t0 + k * pulso)
            for k in (1, 3):
                p.poner('perc', t0 + k * pulso + 0.012, tek(), pan=0.15, gan=0.9)
                p.poner('perc', t0 + k * pulso, caja() * 0.35)
            for i in range(8):
                sw = 0.07 * pulso if i % 2 else 0
                p.poner('perc', t0 + i * pulso / 2 + sw, sonajero(), pan=0.4,
                        gan=0.8 if i % 2 == 0 else 0.5)
    tema = [
        [('A4', 1.5), ('D5', .5), ('E5', 1), ('F5', 1)],
        [('G5', 1.5), ('F5', .5), ('E5', 1), ('C5', 1)],
        [('D5', 1), ('F5', 1), ('A5', 1.5), ('G5', .5)],
        [('E5', 3), (None, 1)],
        [('A5', 1.5), ('G5', .5), ('F5', 1), ('E5', 1)],
        [('D5', 1), ('E5', 1), ('G5', 1), ('E5', 1)],
        [('F5', 1.5), ('E5', .5), ('D5', 1), ('F5', 1)],
        [('E5', 2), ('C#5', 1), ('E5', 1)],
    ]
    melodia(p, 'flauta', 12, compas, tema, flauta, pan=0.1, gan=0.85)
    melodia(p, 'flauta', 20, compas, tema, flauta, pan=0.1, gan=0.8)
    melodia(p, 'flauta2', 20, compas, tema, lambda f, d: pulsada(f, 1.6, 0.6), pan=-0.3, gan=0.55, transp=-12)
    melodia(p, 'flauta', 28, compas, tema[:4], flauta, pan=0.1, gan=0.6)
    melodia(p, 'flauta', 32, compas, [[('D5', 4)], [('A4', 2), ('D5', 2)]], flauta, gan=0.55)
    m = (reverb(p.bus('laud'), 1.8, 4000, 0.25) * 0.75
         + reverb(eco(p.bus('flauta'), pulso * 0.75, 0.3), 2.6, 5000, 0.35) * 0.55
         + p.bus('flauta2') * 0.5
         + p.bus('bajo') * 0.7 * bombeo(p.n, golpes, 0.35)
         + reverb(p.bus('perc'), 1.0, 3500, 0.18) * 0.55)
    m = paso_bajo(m, 6500)
    m = cinta(m) + vinilo(p.n, 1.1)
    return masterizar(m, seg, 0.2)


# ============================================================ bardo
def bardo():
    bpm = 68
    pulso = 60 / bpm
    compas = pulso * 4
    compases = 32
    seg = compases * compas + 5
    p = Pista(seg)
    acordes = [notas(x) for x in [
        ['A2', 'E3', 'A3', 'C4', 'E4', 'A4'], ['G2', 'D3', 'G3', 'B3', 'D4', 'G4'],
        ['F2', 'C3', 'F3', 'A3', 'C4', 'F4'], ['G2', 'D3', 'G3', 'B3', 'D4', 'G4'],
        ['A2', 'E3', 'A3', 'C4', 'E4', 'A4'], ['E2', 'B2', 'E3', 'G3', 'B3', 'E4'],
        ['F2', 'C3', 'F3', 'A3', 'C4', 'F4'], ['E2', 'B2', 'E3', 'G#3', 'B3', 'E4'],
    ]]
    patron = [0, 2, 4, 5, 3, 4, 2, 1, 0, 3, 4, 5, 4, 3, 2, 3]
    golpes = []
    p.poner('bordon', 0, zanfona(midi(45), seg - 2) + zanfona(midi(52), seg - 2) * 0.7, gan=0.8)
    for c in range(compases):
        ac = acordes[c % 8]
        t0 = c * compas
        for i, idx in enumerate(patron):
            sw = 0.05 * pulso if i % 2 else 0
            vel = 0.9 if i % 4 == 0 else 0.55
            p.poner('arpa', t0 + i * pulso / 4 + sw,
                    pulsada(midi(ac[idx] + 12), 2.6, brillo=0.55, decaimiento=0.998, vel=vel),
                    pan=-0.4 + 0.8 * (idx / 5))
        if 4 <= c < 28:
            p.poner('bajo', t0, bajo(midi(ac[0] - 12), compas * 0.9), gan=0.8)
            for k in (0, 2.5):
                p.poner('perc', t0 + k * pulso, pandero(), gan=0.75)
                golpes.append(t0 + k * pulso)
            p.poner('perc', t0 + 2 * pulso, tek(), gan=0.8)
            p.poner('perc', t0 + 3.5 * pulso, tek(), gan=0.45)
            for i in range(4):
                p.poner('perc', t0 + (i + 0.5) * pulso, sonajero(), pan=0.35, gan=0.5)
    tema = [
        [('E5', 2), ('D5', 1), ('C5', 1)],
        [('B4', 2), ('G4', 2)],
        [('A4', 1), ('C5', 1), ('F5', 1.5), ('E5', .5)],
        [('D5', 4)],
        [('E5', 1.5), ('G5', .5), ('A5', 2)],
        [('G5', 1), ('E5', 1), ('B4', 2)],
        [('C5', 1), ('A4', 1), ('F5', 1), ('E5', 1)],
        [('E5', 3), (None, 1)],
    ]
    melodia(p, 'flauta', 8, compas, tema, flauta, gan=0.8)
    melodia(p, 'flauta', 16, compas, tema, flauta, gan=0.85, transp=12)
    melodia(p, 'flauta', 24, compas, tema[:4] + [[('A4', 4)]], flauta, gan=0.6)
    lluvia = paso_bajo(paso_alto(np.random.default_rng(3).standard_normal((p.n, 2)), 500), 4000) * 0.012
    m = (reverb(p.bus('arpa'), 3.0, 4500, 0.35) * 0.7
         + reverb(p.bus('bordon'), 2.0, 3000, 0.3) * 0.4
         + reverb(eco(p.bus('flauta'), pulso * 0.75, 0.33), 3.4, 5000, 0.4) * 0.55
         + p.bus('bajo') * 0.6 * bombeo(p.n, golpes, 0.3)
         + reverb(p.bus('perc'), 1.2, 3000, 0.2) * 0.45)
    m = paso_bajo(m, 6000)
    m = cinta(m, 0.0022, 0.45) + vinilo(p.n, 0.9) + lluvia
    return masterizar(m, seg, 0.18, 2.0, 4.0)


# ============================================================ café
def cafe():
    bpm = 80
    pulso = 60 / bpm
    compas = pulso * 4
    compases = 36
    seg = compases * compas + 4
    p = Pista(seg)
    acordes = [notas(x) for x in [
        ['F3', 'A3', 'C4', 'E4', 'G4'], ['E3', 'G3', 'B3', 'D4', 'F#4'],
        ['D3', 'F3', 'A3', 'C4', 'E4'], ['C3', 'E3', 'G3', 'B3', 'D4'],
        ['Bb2', 'D3', 'F3', 'A3', 'C4'], ['A2', 'C#3', 'G3', 'Bb3', 'E4'],
        ['D3', 'F3', 'A3', 'C4', 'E4'], ['G2', 'F3', 'B3', 'E4', 'A4'],
    ]]
    raices = notas(['F2', 'E2', 'D2', 'C2', 'Bb1', 'A1', 'D2', 'G1'])
    golpes = []
    for c in range(compases):
        ac = acordes[c % 8]
        t0 = c * compas
        comp = [(0, 1.6, 0.8), (1.5, 0.9, 0.55), (3.0, 1.2, 0.6)] if c % 2 == 0 else [(0, 2.2, 0.8), (2.5, 1.4, 0.6)]
        for k, d, v in comp:
            for j, n in enumerate(ac):
                p.poner('rhodes', t0 + k * pulso + j * 0.012, epiano(midi(n), d * pulso + 0.5, v),
                        pan=-0.3 + 0.15 * j)
        if c >= 2:
            r = raices[c % 8]
            p.poner('bajo', t0, bajo(midi(r), pulso * 1.6), gan=1.0)
            p.poner('bajo', t0 + 2.5 * pulso, bajo(midi(r + 7), pulso * 1.0), gan=0.6)
            p.poner('bajo', t0 + 3.5 * pulso, bajo(midi(r + 12 if c % 2 else r + 5), pulso * 0.5), gan=0.5)
        if 4 <= c < 34 and c not in (17, 18):
            sw = 0.11 * pulso
            for k in (0, 1.75 + 0.0, 2.5):
                p.poner('bat', t0 + k * pulso + (sw if k % 1 else 0), bombo(True), gan=0.95)
                golpes.append(t0 + k * pulso)
            for k in (1, 3):
                p.poner('bat', t0 + k * pulso + 0.015, caja(), gan=0.6)
            for i in range(8):
                p.poner('bat', t0 + i * pulso / 2 + (sw if i % 2 else 0), charles(i == 7),
                        pan=0.3, gan=0.7 if i % 2 == 0 else 0.4)
    tema = [
        [(None, 1), ('E5', .5), ('G5', .5), ('A5', 1), ('C6', 1)],
        [('B5', 2), ('A5', 1), ('F#5', 1)],
        [('A5', 1.5), ('G5', .5), ('E5', 1), ('C5', 1)],
        [('D5', 3), (None, 1)],
        [(None, 1), ('F5', .5), ('A5', .5), ('C6', 1), ('A5', 1)],
        [('G5', 1), ('E5', 1), ('C#5', 2)],
        [('F5', 1), ('E5', .5), ('D5', .5), ('C5', 1), ('A4', 1)],
        [('B4', 3), (None, 1)],
    ]
    melodia(p, 'solo', 12, compas, tema, lambda f, d: epiano(f, d + 0.6, 0.9), pan=0.2, gan=0.9)
    melodia(p, 'solo', 20, compas, tema, lambda f, d: epiano(f, d + 0.6, 1.0), pan=0.2, gan=0.95)
    m = (reverb(p.bus('rhodes'), 2.2, 4000, 0.3) * 0.6 * bombeo(p.n, golpes, 0.25)
         + reverb(eco(p.bus('solo'), pulso * 0.75, 0.3), 2.4, 4500, 0.35) * 0.55
         + p.bus('bajo') * 0.8 * bombeo(p.n, golpes, 0.3)
         + reverb(p.bus('bat'), 0.8, 3000, 0.12) * 0.6)
    m = paso_bajo(m, 5500)
    m = cinta(m, 0.0025, 0.5) + vinilo(p.n, 1.3)
    return masterizar(m, seg, 0.2)


# ============================================================ crónica
def cronica():
    bpm = 92
    pulso = 60 / bpm
    compas = pulso * 4
    compases = 38
    seg = compases * compas + 5
    p = Pista(seg)
    acordes = [notas(x) for x in [
        ['D3', 'A3', 'D4', 'F4'], ['Bb2', 'F3', 'Bb3', 'D4'],
        ['F2', 'C3', 'F3', 'A3'], ['C3', 'G3', 'C4', 'E4'],
    ]]
    raices = notas(['D2', 'Bb1', 'F1', 'C2'])
    golpes = []
    for c in range(compases):
        ac = acordes[c % 4]
        t0 = c * compas
        fase = 0 if c < 8 else (1 if c < 16 else (2 if c < 32 else 3))
        if fase < 3 or c < 36:
            for j, n in enumerate(ac):
                p.poner('pad', t0, cuerdas(midi(n), compas + 0.6, 2500 + 1200 * fase), pan=-0.5 + j * 0.33, gan=0.8)
        # ostinato de cuerdas en corcheas
        if 2 <= c < 36:
            for i in range(8):
                n = ac[0] + 12 if i % 2 == 0 else ac[1] + 12
                s = sierra(midi(n), 0.2, 3, 0.05, 20, 5000) * env_adsr(int(0.2 * SR), 0.005, 0.08, 0.3, 0.06) * 0.35
                p.poner('ostinato', t0 + i * pulso / 2, s, pan=0.25, gan=0.8 if i % 2 == 0 else 0.6)
        if fase >= 1 and c < 36:
            p.poner('bajo', t0, metal(midi(raices[c % 4] + 12), compas * 0.95, 0.7), gan=0.8)
            p.poner('timbal', t0, timbal(), gan=0.9)
            golpes.append(t0)
            if fase >= 2:
                p.poner('timbal', t0 + 2.5 * pulso, timbal(), gan=0.6)
                p.poner('timbal', t0 + 3.5 * pulso, timbal(), gan=0.5)
        if fase >= 2 and c < 36:
            for j, n in enumerate(ac[1:]):
                p.poner('coro', t0, coro(midi(n + 12), compas + 0.4), pan=-0.3 + 0.3 * j, gan=0.6)
        if c in (15, 31):
            for i in range(16):
                p.poner('caja', t0 + 2 * pulso + i * pulso / 8, caja(False) * (0.2 + i * 0.05))
    tema = [
        [('D5', 1.5), ('E5', .5), ('F5', 1), ('A5', 1)],
        [('Bb5', 2), ('A5', 1), ('F5', 1)],
        [('C6', 1.5), ('A5', .5), ('F5', 2)],
        [('G5', 3), ('E5', 1)],
        [('F5', 1.5), ('G5', .5), ('A5', 1), ('D6', 1)],
        [('D6', 2), ('C6', 1), ('Bb5', 1)],
        [('A5', 1.5), ('G5', .5), ('F5', 1), ('A5', 1)],
        [('G5', 2), ('E5', 2)],
    ]
    melodia(p, 'metal', 16, compas, tema, lambda f, d: metal(f, d, 0.9), pan=-0.1, gan=0.75, transp=-12)
    melodia(p, 'violin', 24, compas, tema, lambda f, d: cuerdas(f, d + 0.2, 6000) * 1.8, pan=0.15, gan=0.8)
    melodia(p, 'metal', 24, compas, tema, lambda f, d: metal(f, d, 1.0), pan=-0.1, gan=0.7, transp=-12)
    melodia(p, 'violin', 32, compas, [[('D6', 4)], [('Bb5', 4)], [('A5', 4)], [('D5', 4)], [('D5', 4)]],
            lambda f, d: cuerdas(f, d + 0.4, 5000) * 1.6, gan=0.6)
    p.poner('timbal', 36 * compas, timbal(), gan=1.0)
    m = (reverb(p.bus('pad'), 3.5, 5000, 0.45) * 0.55
         + reverb(p.bus('ostinato'), 1.8, 6000, 0.3) * 0.5
         + reverb(p.bus('bajo'), 2.0, 3000, 0.3) * 0.5
         + reverb(p.bus('timbal'), 2.8, 2500, 0.35) * 0.75
         + reverb(p.bus('coro'), 4.0, 5000, 0.5) * 0.45
         + reverb(p.bus('caja'), 1.5, 6000, 0.3) * 0.4
         + reverb(p.bus('metal'), 2.8, 5000, 0.4) * 0.6
         + reverb(p.bus('violin'), 3.2, 7000, 0.4) * 0.55)
    return masterizar(m, seg, 0.21, 1.5, 4.0)


# ============================================================ neón
def neon():
    bpm = 100
    pulso = 60 / bpm
    compas = pulso * 4
    compases = 48
    seg = compases * compas + 4
    p = Pista(seg)
    acordes = [notas(x) for x in [
        ['A3', 'C4', 'E4', 'B4'], ['F3', 'A3', 'C4', 'E4'],
        ['C4', 'E4', 'G4', 'D5'], ['G3', 'B3', 'D4', 'F#4'],
    ]]
    raices = notas(['A1', 'F1', 'C2', 'G1'])
    golpes = []
    for c in range(compases):
        ac = acordes[c % 4]
        t0 = c * compas
        fase = 0 if c < 8 else (1 if c < 24 else (2 if c < 40 else 3))
        for j, n in enumerate(ac):
            p.poner('pad', t0, sierra(midi(n), compas + 0.3, 7, 0.18, 30, 2200 + 1800 * min(fase, 2))
                    * env_adsr(int((compas + 0.3) * SR), 0.2, 0.3, 0.8, 0.3) * 0.22, pan=-0.6 + 0.4 * j)
        if fase >= 1 and not (fase == 3 and c >= 46):
            r = raices[c % 4]
            for i in range(16):
                n = r + (12 if i % 2 else 0)
                p.poner('bajo', t0 + i * pulso / 4, bajo_sierra(midi(n), pulso / 4 * 0.9, 0.9 if i % 4 == 0 else 0.7))
            for k in range(4):
                p.poner('bat', t0 + k * pulso, bombo(), gan=0.95)
                golpes.append(t0 + k * pulso)
            for k in (1, 3):
                p.poner('cajarev', t0 + k * pulso, caja(False), gan=0.8)
                p.poner('bat', t0 + k * pulso, palmada(), gan=0.5)
            for i in range(4):
                p.poner('bat', t0 + (i + 0.5) * pulso, charles(True), pan=0.3, gan=0.6)
        if fase in (0, 1, 2):
            for i in range(8):
                n = ac[[0, 1, 2, 3, 2, 1, 2, 3][i]] + 12
                p.poner('arp', t0 + i * pulso / 2, sierra(midi(n), 0.25, 2, 0.08, 20, 6000)
                        * env_adsr(int(0.25 * SR), 0.003, 0.1, 0.2, 0.05) * 0.3, pan=0.4 if i % 2 else -0.4)
    tema = [
        [('E5', 1.5), ('D5', .5), ('C5', 1), ('B4', 1)],
        [('C5', 1.5), ('A4', .5), ('A4', 2)],
        [('G5', 1.5), ('E5', .5), ('D5', 1), ('C5', 1)],
        [('D5', 3), (None, 1)],
        [('E5', 1.5), ('G5', .5), ('A5', 1), ('E5', 1)],
        [('F5', 1.5), ('E5', .5), ('C5', 2)],
        [('E5', 1), ('D5', 1), ('C5', 1), ('D5', 1)],
        [('B4', 3), (None, 1)],
    ]
    lead = lambda f, d: sierra(f, d, 3, 0.07, 25, 7000) * env_adsr(int(d * SR), 0.01, 0.2, 0.7, 0.1) * 0.32
    melodia(p, 'lead', 24, compas, tema, lead, gan=0.8)
    melodia(p, 'lead', 32, compas, tema, lead, gan=0.85, transp=12)
    caja_puerta = reverb(p.bus('cajarev'), 1.2, 8000, 0.6)
    # reverb con puerta: se corta tras cada golpe
    m = (reverb(p.bus('pad'), 3.0, 6000, 0.35) * 0.5 * bombeo(p.n, golpes, 0.55)
         + p.bus('bajo') * 0.55 * bombeo(p.n, golpes, 0.45)
         + p.bus('bat') * 0.6 + caja_puerta * 0.5
         + reverb(eco(p.bus('arp'), pulso * 0.75, 0.35), 2.0, 6000, 0.25) * 0.4
         + reverb(eco(p.bus('lead'), pulso * 0.75, 0.3), 2.5, 7000, 0.3) * 0.55)
    return masterizar(m, seg, 0.23)


if __name__ == '__main__':
    nombre, salida = sys.argv[1], sys.argv[2]
    mezcla = globals()[nombre]()
    wavfile.write(salida, SR, (mezcla * 32767).astype(np.int16))
    print(nombre, round(len(mezcla) / SR, 1), 's')
