"""Genera la primera maqueta de la habitación real a partir del croquis."""

import argparse
import json
import math
import struct
import sys
from pathlib import Path

from generate_home_twin_demo import cube_geometry


REPO = Path(__file__).resolve().parents[1]
OUTPUT = REPO / "assets" / "home_twin_models" / "mi_habitacion_base.glb"

# Coordenadas en metros: X = izquierda/derecha, Y = altura, Z = fondo/entrada.
# En box(nombre, material, (X, Y, Z), (ancho, alto, fondo)), 0.01 = 1 cm.
# La ventana y la puerta aún no tienen medidas aportadas por el usuario.
WIDTH = 2.10
LENGTH = 4.10
HEIGHT = 3.10
WALL = 0.11
WINDOW_LEFT = -0.10
WINDOW_RIGHT = 0.93
WINDOW_SILL = 0.90
WINDOW_TOP = 2.27
DOOR_LEFT = -0.88
DOOR_RIGHT = -0.06
DOOR_TOP = 2.18
VIGA_ENTRADA_ALTO = 0.25
VIGA_ENTRADA_FONDO = 0.11
VITRINA_ANCHO = 0.80
TABLON_ANCHO = 0.64
TABLON_ALTO = 0.50
TABLON_SEPARACION_VITRINA = 0.025
LIBRERIA_ANCHO = 0.60
ARMARIO_ANCHO = 1.40
JUNTA_MUEBLES = 0.005
EXTREMO_MUEBLES = LENGTH / 2 - WALL / 2 - 0.02
INICIO_ARMARIO = EXTREMO_MUEBLES - ARMARIO_ANCHO
INICIO_LIBRERIA = INICIO_ARMARIO - JUNTA_MUEBLES - LIBRERIA_ANCHO
INICIO_VITRINA = INICIO_LIBRERIA - JUNTA_MUEBLES - VITRINA_ANCHO


def generate(output: Path = OUTPUT) -> Path:
    positions, normals, indices = cube_geometry()
    binary = positions + normals + indices
    palette = {
        "pared_verde_salvia": (0.43, 0.53, 0.45, 1),
        "techo_blanco": (0.96, 0.96, 0.94, 1),
        "rodapié_blanco": (0.87, 0.85, 0.78, 1),
        "suelo_oscuro": (0.045, 0.052, 0.055, 1),
        "baldosa_a": (0.070, 0.080, 0.083, 1),
        "baldosa_b": (0.085, 0.090, 0.090, 1),
        "baldosa_c": (0.060, 0.072, 0.076, 1),
        "marco_blanco": (0.91, 0.89, 0.83, 1),
        "cristal": (0.11, 0.17, 0.19, 0.64),
        "persiana_clara": (0.74, 0.73, 0.69, 1),
        "metal": (0.48, 0.48, 0.42, 1),
        "madera_clara": (0.62, 0.45, 0.31, 1),
        "madera_respaldo": (0.59, 0.42, 0.29, 1),
        "madera_canteada": (0.48, 0.34, 0.24, 1),
        "corcho_tablon": (0.54, 0.37, 0.25, 1),
        "papel_cartel": (0.88, 0.85, 0.81, 1),
        "granate_vitrina": (0.28, 0.065, 0.055, 1),
        "cristal_vitrina": (0.075, 0.085, 0.095, 0.45),
        "vidrio_frontal_vitrina": (0.55, 0.58, 0.56, 0.14),
        "plata_maqueta": (0.47, 0.49, 0.49, 1),
        "oro_detalle": (0.64, 0.48, 0.19, 1),
        "papel_manga": (0.82, 0.80, 0.72, 1),
        "verde_vitrina": (0.08, 0.30, 0.26, 1),
        "azul_turquesa": (0.08, 0.56, 0.61, 1),
        "azul_futbol": (0.06, 0.22, 0.38, 1),
        "piel_figura": (0.65, 0.49, 0.36, 1),
        "piedra_vitrina": (0.42, 0.37, 0.34, 1),
        "negro_mueble": (0.035, 0.037, 0.040, 1),
        "negro_cajon": (0.14, 0.14, 0.145, 1),
        "blanco_opal_armario": (0.72, 0.73, 0.74, 1),
        "riel_armario": (0.58, 0.59, 0.60, 1),
        "negro_tela": (0.052, 0.053, 0.057, 1),
        "gris_cojin": (0.31, 0.32, 0.33, 1),
        "cojin_claro": (0.61, 0.61, 0.58, 1),
        "gris_silla": (0.22, 0.23, 0.25, 1),
        "blanco_mueble": (0.82, 0.82, 0.79, 1),
        "pantalla_oscura": (0.012, 0.018, 0.028, 1),
        "pantalla_azul": (0.045, 0.12, 0.24, 1),
        "luz_violeta": (0.35, 0.055, 0.45, 1),
        "luz_cian": (0.035, 0.32, 0.40, 1),
        "libro_azul": (0.08, 0.13, 0.25, 1),
        "libro_granate": (0.30, 0.06, 0.08, 1),
        "libro_crema": (0.67, 0.61, 0.49, 1),
        "libro_verde": (0.11, 0.21, 0.14, 1),
        "caja_ps4": (0.035, 0.16, 0.52, 1),
        "caja_ps3": (0.12, 0.13, 0.16, 1),
        "caratula_clara": (0.72, 0.72, 0.67, 1),
        "caratula_gris": (0.31, 0.34, 0.36, 1),
        "caratula_violeta": (0.23, 0.18, 0.32, 1),
        "caratula_naranja": (0.56, 0.24, 0.12, 1),
        "figura_verde": (0.16, 0.49, 0.22, 1),
        "figura_amarilla": (0.88, 0.67, 0.12, 1),
        "figura_roja": (0.70, 0.17, 0.14, 1),
        "figura_azul": (0.15, 0.32, 0.65, 1),
        "maceta_arcilla": (0.46, 0.24, 0.14, 1),
        "hojas_verde": (0.08, 0.27, 0.12, 1),
        "hojas_claras": (0.17, 0.38, 0.18, 1),
        "mimbre_miel": (0.58, 0.31, 0.12, 1),
        "mimbre_claro": (0.72, 0.44, 0.22, 1),
        "rejilla_marfil": (0.84, 0.78, 0.64, 1),
        "bombilla_calida": (0.96, 0.69, 0.38, 1),
    }
    materials = []
    meshes = []
    nodes = []
    roots = []
    material_index = {}
    for name, color in palette.items():
        material_index[name] = len(materials)
        material = {
            "name": name,
            "pbrMetallicRoughness": {
                "baseColorFactor": color,
                "metallicFactor": 0,
                "roughnessFactor": 0.9,
            },
            "doubleSided": True,
        }
        if name == "blanco_opal_armario":
            material["pbrMetallicRoughness"]["roughnessFactor"] = 0.5
            material["pbrMetallicRoughness"]["metallicFactor"] = 0.08
        if name in ("cristal", "cristal_vitrina",
                    "vidrio_frontal_vitrina"):
            material["alphaMode"] = "BLEND"
        if name in ("pantalla_azul", "luz_violeta", "luz_cian",
                    "bombilla_calida"):
            material["emissiveFactor"] = [color[0] * 0.45,
                                          color[1] * 0.45,
                                          color[2] * 0.45]
        materials.append(material)

    def box(name, material, position, size, rotation_y=None):
        mesh_index = len(meshes)
        meshes.append({
            "name": name,
            "primitives": [{
                "attributes": {"POSITION": 0, "NORMAL": 1},
                "indices": 2,
                "material": material_index[material],
            }],
        })
        node_index = len(nodes)
        node = {
            "name": name,
            "mesh": mesh_index,
            "translation": list(position),
            "scale": list(size),
        }
        if rotation_y is not None:
            node["rotation"] = [0, math.sin(rotation_y / 2), 0,
                                math.cos(rotation_y / 2)]
        nodes.append(node)
        roots.append(node_index)
        return node_index

    def group(name, children):
        for child in children:
            roots.remove(child)
        node_index = len(nodes)
        nodes.append({"name": name, "children": children})
        roots.append(node_index)

    def reflejar_en_eje_x(children):
        for child in children:
            nodes[child]["translation"][0] *= -1

    def desplazar_en_eje_z(children, distancia):
        for child in children:
            nodes[child]["translation"][2] += distancia

    def ajustar_ancho_en_pared(children, inicio, ancho):
        minimo = min(nodes[child]["translation"][2]
                     - nodes[child]["scale"][2] / 2 for child in children)
        maximo = max(nodes[child]["translation"][2]
                     + nodes[child]["scale"][2] / 2 for child in children)
        factor = ancho / (maximo - minimo)
        for child in children:
            node = nodes[child]
            node["translation"][2] = inicio + (
                node["translation"][2] - minimo) * factor
            node["scale"][2] *= factor

    # Suelo y baldosas. La planta conserva las medidas reales. Las baldosas oscuras son una
    # aproximación visual al suelo que aparece en la segunda fotografía.
    box("base_suelo", "suelo_oscuro", (0, -0.09, 0),
        (WIDTH + 0.18, 0.17, LENGTH + 0.18))
    for row in range(8):
        for column in range(4):
            x = -WIDTH / 2 + (column + 0.5) * WIDTH / 4
            z = -LENGTH / 2 + (row + 0.5) * LENGTH / 8
            tile = ("baldosa_a", "baldosa_b", "baldosa_c")[(row * 7 + column * 3) % 3]
            box(f"baldosa_{row + 1}_{column + 1}", tile, (x, 0.005, z),
                (WIDTH / 4 - 0.008, 0.02, LENGTH / 8 - 0.008))

    # Pared del fondo y hueco de la ventana: desplazados según el croquis.
    back = -LENGTH / 2
    left_segment = WINDOW_LEFT + WIDTH / 2
    right_segment = WIDTH / 2 - WINDOW_RIGHT
    box("pared_fondo_izquierda", "pared_verde_salvia",
        ((-WIDTH / 2 + WINDOW_LEFT) / 2, HEIGHT / 2, back),
        (left_segment, HEIGHT, WALL))
    box("pared_fondo_derecha", "pared_verde_salvia",
        ((WINDOW_RIGHT + WIDTH / 2) / 2, HEIGHT / 2, back),
        (right_segment, HEIGHT, WALL))
    box("pared_bajo_ventana", "pared_verde_salvia",
        ((WINDOW_LEFT + WINDOW_RIGHT) / 2, WINDOW_SILL / 2, back),
        (WINDOW_RIGHT - WINDOW_LEFT, WINDOW_SILL, WALL))
    box("pared_sobre_ventana", "pared_verde_salvia",
        ((WINDOW_LEFT + WINDOW_RIGHT) / 2, (WINDOW_TOP + HEIGHT) / 2, back),
        (WINDOW_RIGHT - WINDOW_LEFT, HEIGHT - WINDOW_TOP, WALL))

    # Pared izquierda y tabique derecho compartido: el visor atenúa el cercano.
    box("pared_larga_derecha", "pared_verde_salvia",
        (WIDTH / 2, HEIGHT / 2, 0), (0.09, HEIGHT, LENGTH))
    box("pared_larga_izquierda", "pared_verde_salvia",
        (-WIDTH / 2, HEIGHT / 2, 0), (WALL, HEIGHT, LENGTH))

    # Pared de entrada y hueco de la puerta.
    front = LENGTH / 2
    box("pared_entrada_izquierda", "pared_verde_salvia",
        ((-WIDTH / 2 + DOOR_LEFT) / 2, HEIGHT / 2, front),
        (DOOR_LEFT + WIDTH / 2, HEIGHT, WALL))
    box("pared_entrada_derecha", "pared_verde_salvia",
        ((DOOR_RIGHT + WIDTH / 2) / 2, HEIGHT / 2, front),
        (WIDTH / 2 - DOOR_RIGHT, HEIGHT, WALL))
    box("pared_entrada_sobre_puerta", "pared_verde_salvia",
        ((DOOR_LEFT + DOOR_RIGHT) / 2, (DOOR_TOP + HEIGHT) / 2, front),
        (DOOR_RIGHT - DOOR_LEFT, HEIGHT - DOOR_TOP, WALL))
    # La viga cruza toda la pared de entrada y sobresale hacia la habitación.
    box("pared_entrada_viga_superior", "pared_verde_salvia",
        (0, HEIGHT - VIGA_ENTRADA_ALTO / 2,
         front - WALL / 2 - VIGA_ENTRADA_FONDO / 2),
        (WIDTH, VIGA_ENTRADA_ALTO, VIGA_ENTRADA_FONDO))
    box("umbral_puerta", "rodapié_blanco",
        ((DOOR_LEFT + DOOR_RIGHT) / 2, 0.015, front),
        (DOOR_RIGHT - DOOR_LEFT, 0.03, 0.15))

    # Rodapiés de las tres paredes.
    box("rodapié_fondo", "rodapié_blanco", (0, 0.08, back + 0.065),
        (WIDTH, 0.16, 0.03))
    box("rodapié_izquierdo", "rodapié_blanco",
        (-WIDTH / 2 + 0.065, 0.08, 0), (0.03, 0.16, LENGTH))
    box("rodapié_derecho", "rodapié_blanco",
        (WIDTH / 2 - 0.065, 0.08, 0), (0.03, 0.16, LENGTH))

    # Techo blanco: fragmentos recortados para ver el suelo.
    box("techo_blanco_fondo", "techo_blanco",
        (0, HEIGHT + 0.025, back + 0.11), (WIDTH + 0.12, 0.08, 0.32))
    box("techo_blanco_lateral", "techo_blanco",
        (WIDTH / 2 - 0.07, HEIGHT + 0.025, 0),
        (0.22, 0.08, LENGTH + 0.12))

    # Lámpara circular de mimbre de la fotografía: un objeto independiente
    # para enlazar su futura entidad domótica sin alterar el mobiliario.
    luz_techo = [
        box("florón_luz_techo", "techo_blanco", (0, 3.075, 0.12),
            (0.15, 0.045, 0.15)),
        box("cable_luz_techo", "metal", (0, 3.005, 0.12),
            (0.012, 0.13, 0.012)),
        box("soporte_luz_techo", "mimbre_miel", (0, 2.945, 0.12),
            (0.09, 0.04, 0.09)),
        box("bombilla_luz_techo", "bombilla_calida", (0, 2.81, 0.12),
            (0.11, 0.11, 0.11)),
    ]
    radios = 20
    radio_pantalla = 0.32
    largo_segmento = 2 * radio_pantalla * math.sin(math.pi / radios) * 1.04
    for indice in range(radios):
        angulo = 2 * math.pi * indice / radios
        x = radio_pantalla * math.cos(angulo)
        z = 0.12 + radio_pantalla * math.sin(angulo)
        giro = -angulo - math.pi / 2
        for nivel, y in enumerate((2.71, 2.84, 2.97), start=1):
            luz_techo.append(box(f"aro_mimbre_{nivel}_{indice + 1}",
                "mimbre_miel" if nivel != 2 else "mimbre_claro",
                (x, y, z), (largo_segmento, 0.019, 0.017), giro))
        luz_techo.append(box(f"trama_mimbre_{indice + 1}",
            "mimbre_claro" if indice % 2 == 0 else "mimbre_miel",
            (x, 2.84, z), (0.016, 0.26, 0.018), giro))
    for indice, distancia in enumerate((-0.21, -0.14, -0.07, 0,
                                        0.07, 0.14, 0.21), start=1):
        largo = 2 * math.sqrt(radio_pantalla ** 2 - distancia ** 2) - 0.025
        luz_techo.append(box(f"rejilla_luz_techo_x_{indice}",
            "rejilla_marfil", (0, 2.695, 0.12 + distancia),
            (largo, 0.012, 0.012)))
        luz_techo.append(box(f"rejilla_luz_techo_z_{indice}",
            "rejilla_marfil", (distancia, 2.69, 0.12),
            (0.012, 0.012, largo)))
    group("luz_techo", luz_techo)

    # Ventana: cristal, marco, alféizar y persiana; ajustar WINDOW_* arriba.
    window = []
    window_center = (WINDOW_LEFT + WINDOW_RIGHT) / 2
    window_height = WINDOW_TOP - WINDOW_SILL
    window.extend([
        box("cristal_ventana", "cristal",
            (window_center, (WINDOW_SILL + WINDOW_TOP) / 2, back + 0.065),
            (WINDOW_RIGHT - WINDOW_LEFT - 0.07, window_height - 0.07, 0.025)),
        box("marco_ventana_izquierdo", "marco_blanco",
            (WINDOW_LEFT, (WINDOW_SILL + WINDOW_TOP) / 2, back + 0.11),
            (0.055, window_height + 0.10, 0.10)),
        box("marco_ventana_derecho", "marco_blanco",
            (WINDOW_RIGHT, (WINDOW_SILL + WINDOW_TOP) / 2, back + 0.11),
            (0.055, window_height + 0.10, 0.10)),
        box("marco_ventana_arriba", "marco_blanco",
            (window_center, WINDOW_TOP, back + 0.11),
            (WINDOW_RIGHT - WINDOW_LEFT + 0.11, 0.06, 0.10)),
        box("alféizar_ventana", "marco_blanco",
            (window_center, WINDOW_SILL - 0.015, back + 0.10),
            (WINDOW_RIGHT - WINDOW_LEFT + 0.11, 0.03, 0.10)),
        box("persiana_ventana", "persiana_clara",
            (window_center, (WINDOW_SILL + WINDOW_TOP) / 2,
             back + 0.13),
            (WINDOW_RIGHT - WINDOW_LEFT + 0.01, window_height + 0.01, 0.015)),
        box("borde_inferior_persiana", "marco_blanco",
            (window_center, WINDOW_SILL + 0.005, back + 0.15),
            (WINDOW_RIGHT - WINDOW_LEFT + 0.04, 0.018, 0.03)),
        box("barra_persiana", "marco_blanco",
            (window_center, WINDOW_TOP + 0.07, back + 0.17),
            (WINDOW_RIGHT - WINDOW_LEFT + 0.18, 0.065, 0.07)),
    ])
    group("ventana", window)

    # Puerta de entrada: marco, hoja, cristales y tirador; ajustar DOOR_* arriba.
    door = []
    door_center = (DOOR_LEFT + DOOR_RIGHT) / 2
    door.extend([
        box("marco_puerta_izquierdo", "marco_blanco",
            (DOOR_LEFT, DOOR_TOP / 2, front - 0.02),
            (0.065, DOOR_TOP + 0.10, 0.12)),
        box("marco_puerta_derecho", "marco_blanco",
            (DOOR_RIGHT, DOOR_TOP / 2, front - 0.02),
            (0.065, DOOR_TOP + 0.10, 0.12)),
        box("marco_puerta_arriba", "marco_blanco",
            (door_center, DOOR_TOP, front - 0.02),
            (DOOR_RIGHT - DOOR_LEFT + 0.11, 0.07, 0.12)),
    ])
    # Hoja abierta hacia el pasillo, con bisagras al lado izquierdo.
    leaf_x = DOOR_LEFT + 0.02
    leaf_z = front + 0.43
    door.extend([
        box("hoja_lateral_1", "marco_blanco", (leaf_x, 1.08, leaf_z - 0.40),
            (0.065, 2.16, 0.06)),
        box("hoja_lateral_2", "marco_blanco", (leaf_x, 1.08, leaf_z + 0.40),
            (0.065, 2.16, 0.06)),
        box("hoja_superior", "marco_blanco", (leaf_x, 2.13, leaf_z),
            (0.065, 0.06, 0.83)),
        box("hoja_inferior", "marco_blanco", (leaf_x, 0.43, leaf_z),
            (0.065, 0.86, 0.83)),
        box("cristales_puerta", "cristal", (leaf_x, 1.48, leaf_z),
            (0.025, 1.24, 0.73)),
    ])
    for index in range(1, 4):
        door.append(box(f"travesaño_puerta_{index}", "marco_blanco",
            (leaf_x - 0.03, 0.88 + index * 0.32, leaf_z),
            (0.035, 0.045, 0.83)))
    door.append(box("parteluz_puerta", "marco_blanco",
        (leaf_x - 0.03, 1.49, leaf_z), (0.035, 1.25, 0.045)))
    door.append(box("tirador_puerta", "metal",
        (leaf_x - 0.07, 0.99, leaf_z - 0.30), (0.07, 0.04, 0.10)))
    group("puerta", door)

    # Mesa / escritorio: tablero de 160 × 80 cm y cuatro patas.
    # La torre de 28 × 45 × 43 cm se monta en src/desk_details.js.
    escritorio = [
        box("tablero_escritorio", "madera_clara", (0.02, 0.74, -1.55),
            (1.60, 0.055, 0.80)),
    ]
    for x in (-0.70, 0.74):
        for z in (-1.87, -1.23):
            escritorio.append(box(f"pata_escritorio_{x}_{z}",
                "blanco_mueble", (x, 0.36, z), (0.055, 0.72, 0.055)))
    group("escritorio", escritorio)

    # Monitor 1: X = -0.45. Monitor 2: X = 0.16.
    # Cada pantalla tiene marco, superficie visible, pie y base.
    ordenador = []
    for indice, x in enumerate((-0.45, 0.16), start=1):
        ordenador.extend([
            box(f"monitor_{indice}", "negro_mueble", (x, 1.15, -1.73),
                (0.58, 0.36, 0.035)),
            box(f"pantalla_{indice}", "pantalla_azul",
                (x, 1.15, -1.705), (0.52, 0.30, 0.004)),
            box(f"pie_monitor_{indice}", "negro_mueble",
                (x, 0.91, -1.73), (0.035, 0.13, 0.08)),
            box(f"base_monitor_{indice}", "negro_mueble",
                (x, 0.82, -1.73), (0.22, 0.02, 0.15)),
        ])
    group("ordenador", ordenador)

    # Silla de escritorio: asiento, respaldo, columna, base y reposabrazos.
    silla = [
        box("asiento_silla", "gris_silla", (-0.12, 0.52, -0.78),
            (0.52, 0.11, 0.52)),
        box("respaldo_silla", "gris_silla", (-0.12, 0.97, -0.55),
            (0.53, 0.80, 0.10)),
        box("columna_silla", "negro_mueble", (-0.12, 0.28, -0.78),
            (0.055, 0.43, 0.055)),
        box("base_silla", "negro_mueble", (-0.12, 0.075, -0.78),
            (0.60, 0.06, 0.10)),
    ]
    for x in (-0.40, 0.16):
        silla.append(box(f"reposabrazos_silla_{x}", "gris_silla",
            (x, 0.69, -0.75), (0.055, 0.04, 0.39)))
    group("silla", silla)

    # Estantería / baldas compactas junto al sofá, en la pared izquierda. Los libros
    # quedan agrupados en cuatro niveles y una planta ocupa la balda superior.
    estanteria = [
        box("montante_estanteria_fondo", "madera_clara",
            (-0.99, 0.84, -0.83), (0.045, 1.68, 0.04)),
        box("montante_estanteria_sofa", "madera_clara",
            (-0.99, 0.84, -0.43), (0.045, 1.68, 0.04)),
    ]
    # Respaldo continuo de madera: los tablones y sus juntas quedan visibles
    # entre las baldas y detrás de los libros.
    for indice in range(5):
        estanteria.append(box(
            f"tablon_respaldo_estanteria_{indice + 1}",
            "madera_clara" if indice % 2 == 0 else "madera_respaldo",
            (-0.995, 0.84, -0.806 + indice * 0.086),
            (0.025, 1.68, 0.082),
        ))
    for indice, y in enumerate((0.16, 0.48, 0.80, 1.12, 1.44), start=1):
        estanteria.append(box(f"balda_{indice}", "madera_clara",
            (-0.83, y, -0.63), (0.30, 0.045, 0.44)))
    colores_baldas = ("libro_azul", "libro_granate", "libro_crema", "libro_verde")
    for fila, balda_y in enumerate((0.16, 0.48, 0.80, 1.12), start=1):
        for columna in range(7):
            altura = (0.21, 0.24, 0.22)[(fila + columna) % 3]
            estanteria.append(box(
                f"libro_estanteria_{fila}_{columna + 1}",
                colores_baldas[(fila + columna) % len(colores_baldas)],
                (-0.79, balda_y + 0.025 + altura / 2, -0.80 + columna * 0.052),
                (0.17, altura, 0.043),
            ))
    for indice, z in enumerate((-0.80, -0.75, -0.70), start=1):
        estanteria.append(box(f"libro_superior_{indice}",
            colores_baldas[indice % len(colores_baldas)],
            (-0.79, 1.575, z), (0.17, 0.22, 0.042)))
    estanteria.extend([
        box("maceta_estanteria", "maceta_arcilla", (-0.82, 1.52, -0.51),
            (0.12, 0.11, 0.12)),
        box("tallo_estanteria", "libro_verde", (-0.82, 1.64, -0.51),
            (0.025, 0.18, 0.025)),
        box("hojas_estanteria_1", "hojas_verde", (-0.82, 1.70, -0.51),
            (0.16, 0.09, 0.13)),
        box("hojas_estanteria_2", "hojas_claras", (-0.82, 1.64, -0.55),
            (0.14, 0.07, 0.11)),
        box("hojas_estanteria_3", "hojas_verde", (-0.82, 1.64, -0.47),
            (0.14, 0.07, 0.11)),
    ])
    group("estanteria", estanteria)

    # Vitrina roja: el primer mueble de la pared derecha, hacia la ventana.
    # Sus medidas y las del armario y librería están en las constantes de arriba.
    vitrina = [
        box("lateral_vitrina_1", "cristal_vitrina", (0.77, 1.12, -1.25),
            (0.44, 2.15, 0.012)),
        box("lateral_vitrina_2", "cristal_vitrina", (0.77, 1.12, -0.56),
            (0.44, 2.15, 0.012)),
        box("trasera_vitrina", "granate_vitrina", (1.00, 1.12, -0.905),
            (0.018, 2.20, 0.68)),
        box("corona_vitrina", "granate_vitrina", (0.77, 2.23, -0.905),
            (0.49, 0.06, 0.74)),
        box("base_vitrina", "granate_vitrina", (0.77, 0.06, -0.905),
            (0.49, 0.12, 0.74)),
        box("cristal_vitrina", "vidrio_frontal_vitrina", (0.525, 1.175, -0.905),
            (0.012, 2.09, 0.62)),
        box("marco_central_vitrina", "granate_vitrina",
            (0.51, 1.13, -0.905), (0.032, 2.24, 0.035)),
        box("marco_superior_puertas_vitrina", "granate_vitrina",
            (0.51, 2.22, -0.905), (0.035, 0.055, 0.72)),
        box("travesaño_frontal_vitrina", "granate_vitrina",
            (0.51, 0.96, -0.905), (0.035, 0.065, 0.72)),
        box("bolsa_encima_vitrina", "negro_mueble",
            (0.77, 2.34, -0.905), (0.27, 0.16, 0.38)),
        box("asa_bolsa_vitrina", "negro_cajon",
            (0.77, 2.435, -0.905), (0.05, 0.045, 0.16)),
    ]
    for x in (0.53, 1.00):
        for z in (-1.25, -0.56):
            vitrina.append(box(f"poste_vitrina_{x}_{z}",
                "granate_vitrina", (x, 1.12, z),
                (0.035, 2.24, 0.035)))
    for indice, y in enumerate((0.50, 0.96, 1.42, 1.88), start=1):
        vitrina.append(box(f"balda_vitrina_{indice}", "granate_vitrina",
            (0.77, y, -0.905), (0.46, 0.045, 0.70)))

    def libro_vitrina(nombre, z, base, alto, color, ancho=0.034, x=0.81):
        vitrina.extend([
            box(nombre, color, (x, base + alto / 2, z),
                (0.23, alto, ancho)),
            box(f"{nombre}_lomo", "oro_detalle" if color == "libro_verde"
                else "libro_granate", (x - 0.119, base + alto * 0.79, z),
                (0.006, 0.012, ancho * 0.72)),
        ])

    def figura_vitrina(nombre, x, z, base, ropa, alto=0.17):
        vitrina.extend([
            box(f"{nombre}_peana", "negro_mueble",
                (x, base + 0.009, z), (0.11, 0.018, 0.105)),
            box(f"{nombre}_piernas", "negro_mueble",
                (x, base + alto * 0.28, z),
                (0.032, alto * 0.43, 0.060)),
            box(f"{nombre}_camiseta", ropa,
                (x, base + alto * 0.60, z),
                (0.054, alto * 0.37, 0.075)),
            box(f"{nombre}_cabeza", "piel_figura",
                (x, base + alto * 0.89, z),
                (0.044, alto * 0.18, 0.052)),
        ])

    # Primera balda: novelas y naves a la izquierda; manga y fútbol a la derecha.
    for indice, (z, color) in enumerate((
            (-1.205, "papel_manga"), (-1.16, "negro_mueble"),
            (-1.115, "negro_mueble"), (-1.07, "negro_mueble")), start=1):
        libro_vitrina(f"libro_galactico_{indice}", z, 1.903,
            0.225 + (indice % 2) * 0.025, color, 0.036)
    vitrina.extend([
        box("nave_casco", "plata_maqueta", (0.73, 1.978, -0.99),
            (0.23, 0.035, 0.11)),
        box("nave_ala_izquierda", "plata_maqueta",
            (0.73, 1.969, -1.06), (0.08, 0.011, 0.11)),
        box("nave_ala_derecha", "plata_maqueta",
            (0.73, 1.969, -0.92), (0.08, 0.011, 0.11)),
    ])
    for indice, z in enumerate((-1.17, -1.11, -1.05, -0.99), start=1):
        figura_vitrina(f"soldado_pequeno_{indice}", 0.60, z, 1.903,
            "papel_manga", 0.085)
    for indice in range(13):
        libro_vitrina(f"manga_superior_{indice + 1}",
            -0.875 + indice * 0.021, 1.903, 0.218,
            "papel_manga", 0.019)
    figura_vitrina("futbolista_superior", 0.60, -0.635, 1.903,
        "azul_futbol", 0.245)
    vitrina.append(box("balon_superior", "papel_manga",
        (0.61, 1.922, -0.655), (0.042, 0.042, 0.042)))

    # Segunda balda: colección de Tolkien, figuras de fantasía y objetos verdes.
    for indice, z in enumerate((-1.175, -1.115, -1.055), start=1):
        libro_vitrina(f"tomo_fantasia_{indice}", z, 1.443,
            0.33 if indice == 2 else 0.29, "papel_manga", 0.052)
        vitrina.append(box(f"canto_dorado_tomo_{indice}", "oro_detalle",
            (0.81, 1.443 + (0.33 if indice == 2 else 0.29), z),
            (0.23, 0.011, 0.052)))
    figura_vitrina("guerrero_fantasia", 0.62, -1.16, 1.443,
        "negro_cajon", 0.19)
    figura_vitrina("criatura_fantasia", 0.66, -0.985, 1.443,
        "piedra_vitrina", 0.16)
    for indice, z in enumerate((-0.865, -0.81, -0.755), start=1):
        libro_vitrina(f"libro_verde_fantasia_{indice}", z, 1.443,
            0.255 + indice * 0.014, "libro_verde", 0.045)
    vitrina.extend([
        box("lamina_fantasia", "libro_crema", (0.91, 1.627, -0.675),
            (0.015, 0.33, 0.19)),
        box("castillo_fantasia", "piedra_vitrina",
            (0.65, 1.535, -0.655), (0.12, 0.18, 0.13)),
        box("torre_castillo", "plata_maqueta",
            (0.65, 1.665, -0.655), (0.047, 0.13, 0.055)),
        box("vaso_verde", "verde_vitrina",
            (0.61, 1.525, -0.785), (0.11, 0.16, 0.10)),
        box("emblema_vaso", "oro_detalle",
            (0.552, 1.54, -0.785), (0.007, 0.055, 0.065)),
    ])

    # Tercera balda: cartel, manga y figura turquesa; fútbol al otro lado.
    vitrina.extend([
        box("cartel_personaje", "libro_crema", (0.92, 1.197, -1.13),
            (0.018, 0.35, 0.20)),
        box("retrato_cartel", "libro_granate", (0.908, 1.19, -1.13),
            (0.007, 0.15, 0.15)),
        box("tomo_manga_naranja", "madera_clara",
            (0.84, 1.14, -1.17), (0.13, 0.27, 0.11)),
        box("sillon_figurita", "azul_turquesa",
            (0.63, 1.05, -1.055), (0.15, 0.12, 0.15)),
        box("respaldo_sillon", "azul_turquesa",
            (0.69, 1.12, -1.055), (0.035, 0.18, 0.15)),
        box("taza_amarilla", "figura_amarilla",
            (0.61, 1.046, -0.948), (0.10, 0.12, 0.05)),
    ])
    figura_vitrina("personaje_sillon", 0.61, -1.055, 1.09,
        "azul_futbol", 0.13)
    for indice, z in enumerate((-1.01, -0.975), start=1):
        libro_vitrina(f"libro_oscuro_tercero_{indice}", z, 0.983,
            0.29, "negro_mueble", 0.031)
    vitrina.extend([
        box("lamina_futbol", "azul_futbol", (0.92, 1.20, -0.77),
            (0.018, 0.33, 0.23)),
        box("franja_lamina_futbol", "figura_roja",
            (0.905, 1.09, -0.77), (0.008, 0.065, 0.23)),
        box("roca_decorativa", "piedra_vitrina",
            (0.63, 1.051, -0.70), (0.13, 0.13, 0.115)),
        box("objeto_madera_futbol", "madera_canteada",
            (0.63, 1.018, -0.64), (0.16, 0.07, 0.12)),
    ])
    for indice in range(4):
        libro_vitrina(f"manga_futbol_{indice + 1}",
            -0.67 + indice * 0.022, 0.983, 0.265,
            "papel_manga", 0.019)
    figura_vitrina("futbolista_rojo", 0.60, -0.85, 0.983,
        "figura_roja", 0.22)
    figura_vitrina("futbolista_azul", 0.65, -0.73, 0.983,
        "azul_futbol", 0.25)

    # Las dos baldas bajas mantienen libros, álbumes y cajas visibles.
    for fila, base in enumerate((0.523, 0.123), start=1):
        for indice in range(12):
            z = -1.20 + indice * 0.052
            color = ("negro_mueble", "libro_verde", "libro_crema",
                     "libro_azul", "libro_granate")[(fila + indice) % 5]
            libro_vitrina(f"libro_inferior_{fila}_{indice + 1}", z, base,
                0.27 + (indice % 3) * 0.025, color, 0.038)
    vitrina.extend([
        box("album_inferior", "libro_granate", (0.65, 0.55, -0.68),
            (0.18, 0.045, 0.18)),
        box("caja_inferior_vitrina", "papel_manga",
            (0.69, 0.17, -0.68), (0.24, 0.085, 0.17)),
    ])
    ajustar_ancho_en_pared(vitrina, INICIO_VITRINA, VITRINA_ANCHO)
    group("vitrina", vitrina)

    # Tablón de anuncios de 64 × 50 cm, junto a la vitrina.
    # El borde derecho queda a 2,5 cm de la vitrina y el superior coincide
    # con la coronación de esta (2,26 m).
    tablon_z_derecha = INICIO_VITRINA - TABLON_SEPARACION_VITRINA
    tablon_z = tablon_z_derecha - TABLON_ANCHO / 2
    tablon_y = 2.26 - TABLON_ALTO / 2
    tablon = [
        box("respaldo_tablon", "madera_canteada",
            (0.972, tablon_y, tablon_z),
            (0.028, TABLON_ALTO, TABLON_ANCHO)),
        box("superficie_corcho", "corcho_tablon",
            (0.955, tablon_y, tablon_z),
            (0.008, TABLON_ALTO - 0.035, TABLON_ANCHO - 0.035)),
        box("marco_superior_tablon", "madera_clara",
            (0.943, 2.247, tablon_z), (0.026, 0.026, TABLON_ANCHO)),
        box("marco_inferior_tablon", "madera_clara",
            (0.943, 1.773, tablon_z), (0.026, 0.026, TABLON_ANCHO)),
    ]
    for indice, z in enumerate((tablon_z - TABLON_ANCHO / 2 + 0.013,
                                tablon_z + TABLON_ANCHO / 2 - 0.013),
                               start=1):
        tablon.append(box(f"marco_lateral_tablon_{indice}", "madera_clara",
            (0.943, tablon_y, z), (0.026, TABLON_ALTO, 0.026)))
    # Franja con dos jugadores en la mitad inferior, como en la fotografía.
    tablon.extend([
        box("franja_negra_cartel_tablon", "negro_mueble",
            (0.946, 1.941, tablon_z), (0.008, 0.028, 0.594)),
        box("poster_jugadores", "papel_cartel",
            (0.943, 1.864, tablon_z), (0.010, 0.14, 0.594)),
        box("banda_inferior_poster", "negro_mueble",
            (0.935, 1.800, tablon_z), (0.008, 0.023, 0.594)),
    ])
    for indice, z in enumerate((tablon_z - 0.16, tablon_z + 0.16), start=1):
        tablon.extend([
            box(f"jugador_{indice}_camiseta", "negro_mueble",
                (0.933, 1.854, z), (0.009, 0.070, 0.073)),
            box(f"jugador_{indice}_cabeza", "piel_figura",
                (0.931, 1.910, z), (0.010, 0.033, 0.037)),
            box(f"jugador_{indice}_detalle", "figura_roja",
                (0.925, 1.833, z), (0.008, 0.030, 0.008)),
        ])
    # Notas, dorsal oscuro y dibujo sujetos al corcho superior.
    tablon.extend([
        box("dorsal_tablon", "negro_mueble",
            (0.944, 2.174, tablon_z_derecha - 0.095),
            (0.009, 0.115, 0.18)),
        box("detalle_rojo_dorsal", "figura_roja",
            (0.937, 2.159, tablon_z_derecha - 0.095),
            (0.006, 0.038, 0.067)),
        box("nota_clara_tablon", "papel_cartel",
            (0.944, 2.075, tablon_z - 0.11),
            (0.009, 0.075, 0.058)),
        box("nota_azul_tablon", "azul_turquesa",
            (0.943, 2.078, tablon_z + 0.115),
            (0.009, 0.070, 0.068)),
        box("dibujo_tablon", "papel_cartel",
            (0.942, 2.054, tablon_z_derecha - 0.085),
            (0.009, 0.105, 0.095)),
        box("trazo_dibujo_tablon", "negro_cajon",
            (0.935, 2.052, tablon_z_derecha - 0.085),
            (0.006, 0.036, 0.050)),
    ])
    group("tablon_anuncios", tablon)

    # Librería negra de juegos y figuras, junto a la vitrina.
    libreria = [
        box("trasera_libreria", "negro_mueble", (-1.005, 1.03, -0.39),
            (0.035, 2.06, 0.68)),
        box("lateral_libreria_1", "negro_mueble", (-0.77, 1.03, -0.72),
            (0.48, 2.06, 0.035)),
        box("lateral_libreria_2", "negro_mueble", (-0.77, 1.03, -0.06),
            (0.48, 2.06, 0.035)),
    ]
    for indice, y in enumerate((0.08, 0.46, 0.84, 1.22, 1.60, 1.99), start=1):
        libreria.append(box(f"balda_libreria_{indice}", "negro_mueble",
            (-0.77, y, -0.39), (0.48, 0.045, 0.68)))
    # Cada hueco de juegos tiene dos filas rectas, separadas por una repisa
    # fina. Todas las cajas están de pie y comparten altura dentro de su fila.
    libreria.extend([
        box("repisa_intermedia_ps4", "negro_mueble",
            (-0.77, 1.793, -0.39), (0.46, 0.014, 0.63)),
        box("repisa_intermedia_ps3", "negro_mueble",
            (-0.77, 1.398, -0.39), (0.46, 0.012, 0.63)),
    ])
    colores_caratulas = (
        "caratula_gris", "caratula_clara", "libro_granate",
        "caratula_violeta", "libro_azul", "caratula_gris",
        "libro_verde", "caratula_clara", "caratula_naranja",
        "negro_cajon", "caratula_clara", "libro_azul",
    )
    filas_juegos = (
        ("ps4", 1, 1.623, 0.162),
        ("ps4", 2, 1.801, 0.162),
        ("ps3", 1, 1.243, 0.148),
        ("ps3", 2, 1.404, 0.148),
    )
    for plataforma, fila, base, altura in filas_juegos:
        for indice in range(28):
            z = -0.681 + indice * 0.0215
            color = colores_caratulas[(indice * 5 + fila * 3 +
                (0 if plataforma == "ps4" else 7)) % len(colores_caratulas)]
            color_caja = "caja_ps4" if plataforma == "ps4" else "caja_ps3"
            libreria.extend([
                box(f"caja_{plataforma}_{fila}_{indice + 1}", color_caja,
                    (-0.705, base + altura / 2, z),
                    (0.24, altura, 0.019)),
                box(f"lomo_{plataforma}_{fila}_{indice + 1}", color,
                    (-0.579, base + altura / 2 - 0.011, z),
                    (0.008, altura - 0.034, 0.016)),
                box(f"cabecera_{plataforma}_{fila}_{indice + 1}",
                    color_caja if plataforma == "ps4" else "negro_mueble",
                    (-0.573, base + altura - 0.014, z),
                    (0.009, 0.028, 0.018)),
            ])

    # Figuras y objetos en los tres huecos inferiores.
    def figura(nombre, z, suelo, color):
        libreria.extend([
            box(f"{nombre}_base", "negro_cajon",
                (-0.69, suelo + 0.025, z), (0.13, 0.018, 0.11)),
            box(f"{nombre}_cuerpo", color,
                (-0.69, suelo + 0.105, z), (0.085, 0.135, 0.075)),
            box(f"{nombre}_cabeza", color,
                (-0.69, suelo + 0.217, z), (0.105, 0.09, 0.095)),
            box(f"{nombre}_ojos", "caratula_clara",
                (-0.633, suelo + 0.225, z), (0.012, 0.019, 0.057)),
        ])

    for nombre, z, color in (
            ("figura_verde_superior", -0.59, "figura_verde"),
            ("figura_amarilla_superior", -0.38, "figura_amarilla"),
            ("figura_roja_superior", -0.17, "figura_roja")):
        figura(nombre, z, 0.847, color)

    libreria.extend([
        box("tarro_verde_estante", "libro_verde",
            (-0.74, 0.585, -0.60), (0.16, 0.20, 0.12)),
        box("tablero_juego_estante", "madera_clara",
            (-0.70, 0.493, -0.40), (0.19, 0.025, 0.19)),
        box("caja_objetos_estante", "libro_crema",
            (-0.73, 0.535, -0.17), (0.19, 0.11, 0.15)),
    ])
    for fila in range(4):
        for columna in range(4):
            if (fila + columna) % 2 == 0:
                libreria.append(box(f"casilla_{fila}_{columna}",
                    "negro_mueble", (-0.78 + fila * 0.045, 0.509,
                    -0.47 + columna * 0.045), (0.041, 0.006, 0.041)))
    figura("figura_azul_central", -0.27, 0.447, "figura_azul")

    libreria.extend([
        box("caja_inferior_azul", "libro_azul",
            (-0.76, 0.19, -0.59), (0.22, 0.18, 0.18)),
        box("caja_inferior_clara", "libro_crema",
            (-0.75, 0.165, -0.35), (0.20, 0.13, 0.17)),
        box("objetos_inferiores", "libro_granate",
            (-0.73, 0.16, -0.15), (0.17, 0.12, 0.13)),
    ])
    reflejar_en_eje_x(libreria)
    ajustar_ancho_en_pared(libreria, INICIO_LIBRERIA, LIBRERIA_ANCHO)
    group("libreria", libreria)

    # Armario negro de 140 × 240 cm: dos huecos de 70 cm y hoja corredera.
    # La hoja empieza sobre el hueco derecho y puede deslizarse al izquierdo.
    fondo_armario_x = WIDTH / 2 - WALL / 2 - 0.025
    frente_armario_x = fondo_armario_x - 0.61
    panel_corredero_x = frente_armario_x - 0.035
    marco_corredero_x = panel_corredero_x - 0.016
    centro_armario_x = (fondo_armario_x + frente_armario_x) / 2
    centro_armario_z = (INICIO_ARMARIO + EXTREMO_MUEBLES) / 2
    centro_blancos_z = (INICIO_ARMARIO + centro_armario_z) / 2
    centro_negros_z = (centro_armario_z + EXTREMO_MUEBLES) / 2
    armario_abierto = [
        box("trasera_armario", "negro_mueble",
            (fondo_armario_x - 0.014, 1.20, centro_armario_z),
            (0.028, 2.40, ARMARIO_ANCHO)),
        box("lateral_armario_libreria", "negro_mueble",
            (centro_armario_x, 1.20, INICIO_ARMARIO + 0.018),
            (0.61, 2.40, 0.036)),
        box("lateral_armario_puerta", "negro_mueble",
            (centro_armario_x, 1.20, EXTREMO_MUEBLES - 0.018),
            (0.61, 2.40, 0.036)),
        box("separador_central_armario", "negro_mueble",
            (centro_armario_x, 1.20, centro_armario_z),
            (0.59, 2.36, 0.026)),
        box("techo_armario", "negro_mueble",
            (centro_armario_x, 2.38, centro_armario_z),
            (0.61, 0.04, ARMARIO_ANCHO)),
        box("base_armario", "negro_mueble",
            (centro_armario_x, 0.055, centro_armario_z),
            (0.61, 0.11, ARMARIO_ANCHO)),
        box("balda_superior_blancos", "negro_mueble",
            (centro_armario_x, 2.08, centro_blancos_z),
            (0.58, 0.035, 0.65)),
        box("balda_superior_negros", "negro_mueble",
            (centro_armario_x, 2.08, centro_negros_z),
            (0.58, 0.035, 0.65)),
        box("barra_ropa_blancos", "riel_armario",
            (centro_armario_x, 1.81, centro_blancos_z),
            (0.026, 0.026, 0.62)),
        box("barra_ropa_negros", "riel_armario",
            (centro_armario_x, 1.81, centro_negros_z),
            (0.026, 0.026, 0.62)),
        box("guia_superior_corredera", "riel_armario",
            (frente_armario_x - 0.02, 2.385, centro_armario_z),
            (0.035, 0.03, 1.38)),
        box("guia_inferior_corredera", "riel_armario",
            (frente_armario_x - 0.02, 0.035, centro_armario_z),
            (0.035, 0.025, 1.38)),
    ]
    for indice, y in enumerate((0.18, 0.34, 0.50, 0.66), start=1):
        armario_abierto.append(box(f"cajon_blanco_{indice}",
            "blanco_mueble", (frente_armario_x + 0.015, y, centro_blancos_z),
            (0.035, 0.145, 0.61)))
    for indice, y in enumerate((0.20, 0.40, 0.60), start=1):
        armario_abierto.append(box(f"cajon_negro_{indice}",
            "negro_cajon", (frente_armario_x + 0.015, y, centro_negros_z),
            (0.035, 0.18, 0.61)))
    for indice, (z, color) in enumerate((
            (centro_blancos_z - 0.18, "libro_crema"),
            (centro_blancos_z, "gris_silla"),
            (centro_blancos_z + 0.18, "blanco_mueble")), start=1):
        armario_abierto.append(box(f"ropa_colgada_blancos_{indice}", color,
            (centro_armario_x, 1.43, z), (0.30, 0.62, 0.13)))
    armario_abierto.append(box("ropa_colgada_negros", "negro_tela",
        (centro_armario_x, 1.46, centro_negros_z), (0.30, 0.56, 0.16)))

    hoja_corredera = [
        box("panel_opal_armario", "blanco_opal_armario",
            (panel_corredero_x, 1.20, centro_negros_z),
            (0.028, 2.33, 0.675)),
        box("marco_lateral_corredera_1", "negro_mueble",
            (marco_corredero_x, 1.20, centro_negros_z - 0.34),
            (0.014, 2.35, 0.018)),
        box("marco_lateral_corredera_2", "negro_mueble",
            (marco_corredero_x, 1.20, centro_negros_z + 0.34),
            (0.014, 2.35, 0.018)),
    ]
    for indice, y in enumerate((0.61, 1.19, 1.78), start=1):
        hoja_corredera.append(box(f"division_panel_corredera_{indice}",
            "negro_mueble", (marco_corredero_x, y, centro_negros_z),
            (0.014, 0.016, 0.69)))
    group("puerta_corredera_armario", hoja_corredera)
    armario_abierto.append(roots[-1])
    group("armario_abierto", armario_abierto)

    # Sofá negro separado de la entrada: base, asiento, respaldo y brazos.
    sofa = [
        box("base_sofa_hasta_suelo", "negro_tela", (0.63, 0.165, 0.87),
            (0.76, 0.33, 1.74)),
        box("asiento_sofa", "negro_tela", (0.63, 0.43, 0.87),
            (0.78, 0.24, 1.76)),
        box("respaldo_sofa", "negro_tela", (0.94, 0.82, 0.87),
            (0.19, 0.95, 1.76)),
        box("brazo_sofa_1", "negro_tela", (0.63, 0.63, 0.03),
            (0.80, 0.54, 0.15)),
        box("brazo_sofa_2", "negro_tela", (0.63, 0.63, 1.71),
            (0.80, 0.54, 0.15)),
        # Cojín 1: oscuro.
        box("cojin_sofa_oscuro", "gris_silla", (0.37, 0.65, 0.53),
            (0.46, 0.19, 0.48)),
        # Cojín 2: claro con dos franjas.
        box("cojin_sofa_claro", "cojin_claro", (0.37, 0.65, 1.20),
            (0.46, 0.19, 0.47)),
        box("franja_cojin_claro_1", "gris_cojin", (0.37, 0.751, 1.05),
            (0.44, 0.004, 0.035)),
        box("franja_cojin_claro_2", "gris_cojin", (0.37, 0.751, 1.35),
            (0.44, 0.004, 0.035)),
    ]
    reflejar_en_eje_x(sofa)
    desplazar_en_eje_z(sofa, -0.39)
    group("sofa", sofa)

    document = {
        "asset": {"version": "2.0", "generator": "Todo: habitación real, primera maqueta"},
        "scene": 0,
        "scenes": [{"nodes": roots}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "buffers": [{"byteLength": len(binary)}],
        "bufferViews": [
            {"buffer": 0, "byteOffset": 0, "byteLength": len(positions), "target": 34962},
            {"buffer": 0, "byteOffset": len(positions), "byteLength": len(normals), "target": 34962},
            {"buffer": 0, "byteOffset": len(positions) + len(normals),
             "byteLength": len(indices), "target": 34963},
        ],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": 24, "type": "VEC3",
             "min": [-0.5, -0.5, -0.5], "max": [0.5, 0.5, 0.5]},
            {"bufferView": 1, "componentType": 5126, "count": 24, "type": "VEC3"},
            {"bufferView": 2, "componentType": 5123, "count": 36, "type": "SCALAR"},
        ],
    }
    json_chunk = json.dumps(document, ensure_ascii=False,
                            separators=(",", ":")).encode("utf-8")
    json_chunk += b" " * (-len(json_chunk) % 4)
    binary += b"\0" * (-len(binary) % 4)
    total = 12 + 8 + len(json_chunk) + 8 + len(binary)
    glb = (
        struct.pack("<4sII", b"glTF", 2, total)
        + struct.pack("<I4s", len(json_chunk), b"JSON") + json_chunk
        + struct.pack("<I4s", len(binary), b"BIN\0") + binary
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(glb)
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--importar", action="store_true",
                        help="Actualizar la habitación en los datos locales")
    arguments = parser.parse_args()
    output = generate()
    print(output)
    if arguments.importar:
        sys.path.insert(0, str(REPO / "mcp_server"))
        from home_twin_repository import HomeTwinRepository

        repository = HomeTwinRepository(Path.home() / "Documents" / "Todo" / "household")
        result = repository.import_room({
            "room_id": "dormitorio",
            "name": "Habitación",
            "source_file": str(output),
            "floor": 0,
            "position": {"x": 0, "y": 0, "z": 0},
            "objects": [
                {"id": "luz_techo", "name": "Luz del techo", "node_name": "luz_techo", "kind": "luz"},
                {"id": "puerta", "name": "Puerta", "node_name": "puerta", "kind": "puerta"},
                {"id": "ventana", "name": "Ventana", "node_name": "ventana", "kind": "ventana"},
                {"id": "escritorio", "name": "Escritorio", "node_name": "escritorio", "kind": "mueble"},
                {"id": "ordenador", "name": "Ordenador", "node_name": "ordenador", "kind": "ordenador"},
                {"id": "silla", "name": "Silla de escritorio", "node_name": "silla", "kind": "mueble"},
                {"id": "estanteria", "name": "Baldas de madera", "node_name": "estanteria", "kind": "mueble"},
                {"id": "vitrina", "name": "Vitrina granate", "node_name": "vitrina", "kind": "mueble"},
                {"id": "libreria", "name": "Librería negra", "node_name": "libreria", "kind": "mueble"},
                {"id": "armario_abierto", "name": "Armario negro con puerta", "node_name": "armario_abierto", "kind": "mueble"},
                {"id": "sofa", "name": "Sofá", "node_name": "sofa", "kind": "mueble"},
            ],
        }, set())
        print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
