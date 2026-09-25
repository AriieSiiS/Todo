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

# Metros. La ventana y la puerta aún no tienen medidas aportadas por el usuario.
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
VITRINA_ANCHO = 0.80
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
        "madera_canteada": (0.48, 0.34, 0.24, 1),
        "granate_vitrina": (0.28, 0.065, 0.055, 1),
        "cristal_vitrina": (0.075, 0.085, 0.095, 0.45),
        "negro_mueble": (0.035, 0.037, 0.040, 1),
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
        if name in ("cristal", "cristal_vitrina"):
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

    def ampliar_altura_armario(children):
        for child in children:
            node = nodes[child]
            node["translation"][1] *= 1.05
            node["scale"][1] *= 1.05

    # La planta conserva las medidas reales. Las baldosas oscuras son una
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

    # Pared del fondo: ventana desplazada hacia la derecha en el croquis.
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

    # La pared derecha permanece visible detrás de los armarios. La
    # izquierda queda recortada para enseñar el sofá y el resto del interior.
    box("pared_larga_derecha", "pared_verde_salvia",
        (WIDTH / 2, HEIGHT / 2, 0), (WALL, HEIGHT, LENGTH))
    box("pared_larga_izquierda_recortada", "pared_verde_salvia",
        (-WIDTH / 2, 0.18, 0), (WALL, 0.36, LENGTH))

    # En el extremo opuesto, el umbral y los laterales marcan la puerta sin
    # levantar un muro que tape la vista isométrica de la estancia.
    front = LENGTH / 2
    box("pared_entrada_izquierda_recortada", "pared_verde_salvia",
        ((-WIDTH / 2 + DOOR_LEFT) / 2, 0.18, front),
        (DOOR_LEFT + WIDTH / 2, 0.36, WALL))
    box("pared_entrada_derecha_recortada", "pared_verde_salvia",
        ((DOOR_RIGHT + WIDTH / 2) / 2, 0.18, front),
        (WIDTH / 2 - DOOR_RIGHT, 0.36, WALL))
    box("umbral_puerta", "rodapié_blanco",
        ((DOOR_LEFT + DOOR_RIGHT) / 2, 0.015, front),
        (DOOR_RIGHT - DOOR_LEFT, 0.03, 0.15))

    box("rodapié_fondo", "rodapié_blanco", (0, 0.08, back + 0.065),
        (WIDTH, 0.16, 0.03))
    box("rodapié_izquierdo", "rodapié_blanco",
        (-WIDTH / 2 + 0.065, 0.08, 0), (0.03, 0.16, LENGTH))
    box("rodapié_derecho", "rodapié_blanco",
        (WIDTH / 2 - 0.065, 0.08, 0), (0.03, 0.16, LENGTH))

    # Fragmentos de techo blanco: el resto está recortado para ver el suelo.
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
            (window_center, WINDOW_SILL, back + 0.18),
            (WINDOW_RIGHT - WINDOW_LEFT + 0.15, 0.06, 0.25)),
        box("persiana_ventana", "persiana_clara",
            (window_center - 0.055, (WINDOW_SILL + WINDOW_TOP) / 2,
             back + 0.13),
            (WINDOW_RIGHT - WINDOW_LEFT - 0.17, window_height - 0.05, 0.015)),
        box("barra_persiana", "marco_blanco",
            (window_center, WINDOW_TOP + 0.07, back + 0.17),
            (WINDOW_RIGHT - WINDOW_LEFT + 0.18, 0.065, 0.07)),
    ])
    group("ventana", window)

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
    # Hoja abierta hacia el pasillo, con cristales divididos como en la foto.
    leaf_x = DOOR_RIGHT - 0.02
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
            (leaf_x + 0.03, 0.88 + index * 0.32, leaf_z),
            (0.035, 0.045, 0.83)))
    door.append(box("parteluz_puerta", "marco_blanco",
        (leaf_x + 0.03, 1.49, leaf_z), (0.035, 1.25, 0.045)))
    door.append(box("tirador_puerta", "metal",
        (leaf_x + 0.07, 0.99, leaf_z - 0.30), (0.07, 0.04, 0.10)))
    group("puerta", door)

    # El escritorio queda frente a la ventana. Las medidas de los muebles
    # son estimaciones derivadas de las fotos, separadas de la planta medida.
    escritorio = [
        box("tablero_escritorio", "madera_clara", (0.02, 0.74, -1.55),
            (1.64, 0.055, 0.72)),
        box("canto_escritorio", "madera_canteada", (0.02, 0.705, -1.19),
            (1.64, 0.035, 0.025)),
    ]
    for x in (-0.70, 0.74):
        for z in (-1.81, -1.29):
            escritorio.append(box(f"pata_escritorio_{x}_{z}",
                "blanco_mueble", (x, 0.36, z), (0.055, 0.72, 0.055)))
    group("escritorio", escritorio)

    ordenador = []
    for indice, x in enumerate((-0.38, 0.24), start=1):
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
    ordenador.extend([
        box("caja_ordenador", "blanco_mueble", (0.73, 1.045, -1.58),
            (0.25, 0.54, 0.42)),
        box("lateral_cristal_ordenador", "cristal_vitrina",
            (0.587, 1.045, -1.58), (0.007, 0.48, 0.37)),
        box("teclado", "negro_mueble", (-0.06, 0.782, -1.37),
            (0.45, 0.022, 0.16)),
        box("ratón", "negro_mueble", (0.29, 0.79, -1.36),
            (0.07, 0.03, 0.10)),
    ])
    for indice, y in enumerate((0.90, 1.05, 1.20), start=1):
        ordenador.append(box(f"ventilador_ordenador_{indice}",
            "luz_violeta" if indice != 2 else "luz_cian",
            (0.73, y, -1.365), (0.13, 0.11, 0.008)))
    group("ordenador", ordenador)

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

    # Baldas compactas junto al sofá, en la pared izquierda. Los libros
    # quedan agrupados en cuatro niveles y una planta ocupa la balda superior.
    estanteria = [
        box("montante_estanteria_fondo", "madera_clara",
            (-0.99, 0.84, -0.83), (0.045, 1.68, 0.04)),
        box("montante_estanteria_sofa", "madera_clara",
            (-0.99, 0.84, -0.43), (0.045, 1.68, 0.04)),
    ]
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

    # Los tres muebles de la pared derecha ocupan sus medidas reales desde
    # la esquina de la puerta: armario, librería y vitrina hacia la ventana.
    vitrina = [
        box("lateral_vitrina_1", "cristal_vitrina", (0.77, 1.12, -1.25),
            (0.44, 2.15, 0.012)),
        box("lateral_vitrina_2", "cristal_vitrina", (0.77, 1.12, -0.56),
            (0.44, 2.15, 0.012)),
        box("trasera_vitrina", "cristal_vitrina", (1.00, 1.12, -0.905),
            (0.012, 2.20, 0.68)),
        box("corona_vitrina", "granate_vitrina", (0.77, 2.23, -0.905),
            (0.49, 0.06, 0.74)),
        box("base_vitrina", "granate_vitrina", (0.77, 0.06, -0.905),
            (0.49, 0.12, 0.74)),
        box("cristal_vitrina", "cristal_vitrina", (0.525, 1.26, -0.905),
            (0.012, 1.82, 0.62)),
        box("marco_central_vitrina", "granate_vitrina",
            (0.51, 1.26, -0.905), (0.032, 1.84, 0.035)),
    ]
    for x in (0.53, 1.00):
        for z in (-1.25, -0.56):
            vitrina.append(box(f"poste_vitrina_{x}_{z}",
                "granate_vitrina", (x, 1.12, z),
                (0.035, 2.24, 0.035)))
    for indice, y in enumerate((0.50, 0.96, 1.42, 1.88), start=1):
        vitrina.append(box(f"balda_vitrina_{indice}", "granate_vitrina",
            (0.77, y, -0.905), (0.46, 0.045, 0.70)))
    ajustar_ancho_en_pared(vitrina, INICIO_VITRINA, VITRINA_ANCHO)
    group("vitrina", vitrina)

    # Librería negra situada a continuación de la vitrina en la pared derecha.
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
    colores_libros = ("libro_azul", "libro_granate", "libro_crema", "libro_verde")
    for fila, y in enumerate((0.60, 0.98, 1.36, 1.74), start=1):
        for columna in range(7):
            z = -0.66 + columna * 0.082
            libreria.append(box(f"libro_{fila}_{columna + 1}",
                colores_libros[(fila + columna) % len(colores_libros)],
                (-0.70, y, z), (0.24, 0.29, 0.06)))
    reflejar_en_eje_x(libreria)
    ajustar_ancho_en_pared(libreria, INICIO_LIBRERIA, LIBRERIA_ANCHO)
    group("libreria", libreria)

    # Un solo armario negro con perchero, cajones y puerta corredera blanca.
    # Conserva el identificador anterior para sus posibles vínculos de Hogar.
    armario_abierto = [
        box("trasera_armario_abierto", "negro_mueble",
            (-1.01, 1.19, 0.35), (0.035, 2.38, 0.73)),
        box("lateral_armario_abierto_1", "negro_mueble",
            (-0.72, 1.19, 0.00), (0.58, 2.38, 0.045)),
        box("lateral_armario_abierto_2", "negro_mueble",
            (-0.72, 1.19, 0.70), (0.58, 2.38, 0.045)),
        box("techo_armario_abierto", "negro_mueble",
            (-0.72, 2.36, 0.35), (0.58, 0.045, 0.73)),
        box("base_armario_abierto", "negro_mueble",
            (-0.72, 0.065, 0.35), (0.58, 0.13, 0.73)),
        box("zócalo_armario_abierto", "negro_mueble",
            (-0.43, 0.065, 0.35), (0.035, 0.13, 0.70)),
        box("barra_perchero", "metal", (-0.68, 1.86, 0.35),
            (0.03, 0.03, 0.63)),
        box("puerta_blanca_armario", "blanco_mueble",
            (-0.39, 1.19, 0.53), (0.035, 2.38, 0.35)),
        box("tirador_armario", "metal",
            (-0.365, 1.18, 0.38), (0.015, 0.24, 0.025)),
    ]
    for indice, y in enumerate((0.20, 0.45, 0.70), start=1):
        armario_abierto.append(box(f"cajon_blanco_{indice}",
            "blanco_mueble", (-0.43, y, 0.35), (0.05, 0.22, 0.65)))
    for indice, (z, color) in enumerate(((0.18, "libro_crema"),
                                          (0.36, "gris_cojin"),
                                          (0.54, "blanco_mueble")), start=1):
        armario_abierto.append(box(f"ropa_colgada_{indice}", color,
            (-0.66, 1.35, z), (0.35, 0.62, 0.12)))
    reflejar_en_eje_x(armario_abierto)
    ampliar_altura_armario(armario_abierto)
    ajustar_ancho_en_pared(armario_abierto, INICIO_ARMARIO, ARMARIO_ANCHO)
    group("armario_abierto", armario_abierto)

    # Sofá negro separado de la entrada: sin ropa, bolsas ni otros objetos.
    sofa = [
        box("asiento_sofa", "negro_tela", (0.63, 0.43, 0.87),
            (0.78, 0.24, 1.76)),
        box("respaldo_sofa", "negro_tela", (0.94, 0.82, 0.87),
            (0.19, 0.95, 1.76)),
        box("brazo_sofa_1", "negro_tela", (0.63, 0.63, 0.03),
            (0.80, 0.54, 0.15)),
        box("brazo_sofa_2", "negro_tela", (0.63, 0.63, 1.71),
            (0.80, 0.54, 0.15)),
        box("cojin_sofa_oscuro", "gris_silla", (0.37, 0.65, 0.53),
            (0.46, 0.19, 0.48)),
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
            "name": "Mi habitación",
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
