"""Genera el baño B junto a la habitación del pasillo en la nueva planta."""

import argparse
import json
import sys
from pathlib import Path

from generate_home_twin_third_room import (
    FONDO_Z as TRASTERO_FONDO_Z,
    POSITION as TRASTERO_POSITION,
    PUERTA_BANO_DERECHA,
    PUERTA_BANO_IZQUIERDA,
)
from home_twin_simple_geometry import SimpleModel, import_room


REPO = Path(__file__).resolve().parents[1]
OUTPUT = REPO / "assets" / "home_twin_models" / "bano_base.glb"
ANCHO_X = 2.50
FONDO_Z = 2.25
POSITION = (0.20, TRASTERO_POSITION[1] + TRASTERO_FONDO_Z / 2 + FONDO_Z / 2)
ALTURA = 3.10


def generate(output=OUTPUT):
    model = SimpleModel({
        "pared": (0.70, 0.70, 0.65, 1),
        "pared_clara": (0.80, 0.79, 0.72, 1),
        "suelo": (0.54, 0.51, 0.45, 1),
        "baldosa_a": (0.71, 0.67, 0.58, 1),
        "baldosa_b": (0.79, 0.75, 0.66, 1),
        "marco": (0.30, 0.13, 0.07, 1),
        "moldura": (0.46, 0.23, 0.11, 1),
        "panel_madera": (0.37, 0.17, 0.08, 1),
        "veta_madera": (0.43, 0.21, 0.10, 1),
        "sanitario": (0.91, 0.92, 0.89, 1),
        "hueco": (0.77, 0.79, 0.76, 1),
        "mueble": (0.39, 0.22, 0.15, 1),
        "espejo": (0.59, 0.69, 0.70, 1),
        "puerta": (0.40, 0.19, 0.09, 1),
        "tirador": (0.47, 0.34, 0.16, 1),
    }, "Todo: baño provisional en la planta corregida")
    box = model.box
    south = -ANCHO_X / 2
    north = ANCHO_X / 2
    west = -FONDO_Z / 2
    east = FONDO_Z / 2
    door_south = PUERTA_BANO_IZQUIERDA - POSITION[0]
    door_north = PUERTA_BANO_DERECHA - POSITION[0]
    ancho_hoja = door_north - door_south - 0.02
    ancho_panel = ancho_hoja - 0.12

    # Suelo y baldosas del baño; coordenadas y tamaños en metros.
    box("base_suelo_bano", "suelo", (0, -0.08, 0),
        (ANCHO_X, 0.16, FONDO_Z))
    for column in range(5):
        for row in range(5):
            x = south + (column + 0.5) * ANCHO_X / 5
            z = west + (row + 0.5) * FONDO_Z / 5
            material = "baldosa_a" if (column + row) % 2 else "baldosa_b"
            box(f"baldosa_bano_{column}_{row}", material,
                (x, 0.005, z), (0.49, 0.018, 0.44))

    # Paredes laterales y pared exterior del baño.
    box("pared_larga_izquierda_bano", "pared_clara",
        (south, ALTURA / 2, 0), (0.10, ALTURA, FONDO_Z))
    box("pared_larga_derecha_bano", "pared_clara",
        (north, ALTURA / 2, 0), (0.10, ALTURA, FONDO_Z))
    box("pared_entrada_bano_exterior", "pared", (0, ALTURA / 2, east),
        (ANCHO_X, ALTURA, 0.10))
    # Puerta del baño: bisagras junto al pilar y tirador en el lado opuesto.
    for name, start, end in (("sur", south, door_south),
                             ("norte", door_north, north)):
        box(f"pared_fondo_bano_{name}", "pared", ((start + end) / 2, ALTURA / 2, west),
            (end - start, ALTURA, 0.10))
    box("pared_fondo_bano_dintel", "pared",
        ((door_south + door_north) / 2, 2.65, west),
        (door_north - door_south, 0.90, 0.10))
    for name, x in (("sur", door_south), ("norte", door_north)):
        box(f"marco_entrada_bano_{name}", "marco", (x, 1.10, west),
            (0.055, 2.20, 0.12))
    box("marco_entrada_bano_superior", "marco",
        ((door_south + door_north) / 2, 2.20, west),
        (door_north - door_south + 0.11, 0.055, 0.12))
    box("hoja_puerta_bano", "puerta",
        ((door_south + door_north) / 2, 1.08, west),
        (ancho_hoja, 2.16, 0.045))
    center_x = (door_south + door_north) / 2
    front_face = west - 0.028
    # Dos paneles embutidos y molduras finas reproducen los rebajes de la foto.
    for panel_name, center_y, panel_height in (
            ("superior", 1.79, 0.46), ("central", 0.91, 1.18)):
        box(f"panel_{panel_name}_puerta_bano", "panel_madera",
            (center_x, center_y, front_face),
            (ancho_panel, panel_height, 0.007))
        for side, x in (("izquierda", center_x - ancho_panel / 2 - 0.01),
                        ("derecha", center_x + ancho_panel / 2 + 0.01)):
            box(f"moldura_{panel_name}_{side}_puerta_bano", "moldura",
                (x, center_y, west - 0.035), (0.018, panel_height + 0.025, 0.012))
        for side, y in (("arriba", center_y + panel_height / 2),
                        ("abajo", center_y - panel_height / 2)):
            box(f"moldura_{panel_name}_{side}_puerta_bano", "moldura",
                (center_x, y, west - 0.035),
                (ancho_panel + 0.03, 0.018, 0.012))
    # Vetas discretas dentro del panel principal, visibles sin textura externa.
    for index, fraction in enumerate((0.18, 0.36, 0.63, 0.82), start=1):
        x = center_x - ancho_panel / 2 + 0.025 + fraction * (ancho_panel - 0.05)
        box(f"veta_vertical_{index}_puerta_bano", "veta_madera",
            (x, 0.90, west - 0.033), (0.003, 0.92, 0.002))
    box("placa_tirador_puerta_bano", "marco",
        (door_north - 0.095, 1.01, west - 0.044),
        (0.055, 0.22, 0.014))
    box("tirador_puerta_bano", "tirador",
        (door_north - 0.14, 1.00, west - 0.066),
        (0.13, 0.025, 0.027))
    for index, y in enumerate((0.40, 1.80), start=1):
        box(f"bisagra_{index}_puerta_bano", "tirador",
            (door_south + 0.02, y, west - 0.03),
            (0.015, 0.085, 0.027))

    # Los sanitarios son solo volúmenes orientativos hasta medir el baño.
    # Ducha: plato e interior.
    box("plato_ducha", "sanitario", (0.75, 0.05, 0.55),
        (0.82, 0.10, 0.84))
    box("interior_plato_ducha", "hueco", (0.75, 0.106, 0.55),
        (0.68, 0.006, 0.70))
    # Inodoro: base, taza y cisterna.
    box("base_inodoro", "sanitario", (-0.76, 0.25, 0.45),
        (0.40, 0.48, 0.52))
    box("taza_inodoro", "sanitario", (-0.76, 0.54, 0.45),
        (0.46, 0.13, 0.54))
    box("cisterna_inodoro", "sanitario", (-0.76, 0.84, 0.77),
        (0.40, 0.46, 0.18))
    # Lavabo: mueble, pila y espejo.
    box("mueble_lavabo", "mueble", (0.72, 0.39, -0.56),
        (0.82, 0.76, 0.42))
    box("pila_lavabo", "sanitario", (0.72, 0.80, -0.56),
        (0.70, 0.06, 0.38))
    box("espejo_bano", "espejo", (0.72, 1.64, -1.068),
        (0.70, 0.75, 0.02))
    return model.write(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--importar", action="store_true")
    arguments = parser.parse_args()
    output = generate()
    print(output)
    if arguments.importar:
        sys.path.insert(0, str(REPO / "mcp_server"))
        print(json.dumps(import_room(output, "bano", "Baño", POSITION),
                         ensure_ascii=False))


if __name__ == "__main__":
    main()
