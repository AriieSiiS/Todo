"""Genera la habitación H a la derecha del pasillo, según la nueva planta."""

import argparse
import json
import sys
from pathlib import Path

from generate_home_twin_hallway import (
    PASILLO_DERECHA,
    PUERTA_TERCERA_DERECHA,
    PUERTA_TERCERA_IZQUIERDA,
    X_NORTE,
    X_SUR,
    Z_ESTE,
)
from home_twin_simple_geometry import SimpleModel, import_room


REPO = Path(__file__).resolve().parents[1]
OUTPUT = REPO / "assets" / "home_twin_models" / "habitacion_pasillo_base.glb"
# La habitación comparte los extremos medidos del pasillo largo.
ANCHO_X = X_NORTE - X_SUR
# Entre las caras interiores de los muros de 11 cm quedan 3,20 m.
FONDO_Z = 3.20 + 0.11
POSITION = ((X_SUR + X_NORTE) / 2, Z_ESTE + FONDO_Z / 2)
ALTURA = 3.10
# El pilar junto a la puerta del baño ocupa 10 cm de hueco y sobresale
# 25 cm hacia el pasillo; el paño anterior conserva sus 2 cm de margen.
PILAR_BANO_ANCHO = 0.10
PILAR_BANO_FONDO = 0.25
# La altura del tramo horizontal es aproximada a partir de la foto.
SALIENTE_BANO_ALTO = 0.25
PUERTA_BANO_IZQUIERDA = X_SUR + 0.03 + PILAR_BANO_ANCHO
PUERTA_BANO_DERECHA = PASILLO_DERECHA - 0.02


def generate(output=OUTPUT):
    model = SimpleModel({
        "pared": (0.30, 0.43, 0.41, 1),
        "suelo": (0.055, 0.064, 0.062, 1),
        "baldosa_a": (0.074, 0.082, 0.078, 1),
        "baldosa_b": (0.060, 0.069, 0.068, 1),
        "baldosa_pasillo_a": (0.075, 0.079, 0.078, 1),
        "baldosa_pasillo_b": (0.095, 0.097, 0.091, 1),
        "marco": (0.79, 0.76, 0.68, 1),
        "puerta": (0.69, 0.67, 0.60, 1),
        "tirador": (0.39, 0.38, 0.34, 1),
        "laton_lampara": (0.47, 0.34, 0.20, 1),
    }, "Todo: habitación del pasillo en la planta corregida")
    box = model.box
    west = -FONDO_Z / 2
    east = FONDO_Z / 2
    south = -ANCHO_X / 2
    north = ANCHO_X / 2

    def wall_segment(name, z, start, end):
        if end > start:
            box(name, "pared", ((start + end) / 2, ALTURA / 2, z),
                (end - start, ALTURA, 0.11))

    def doorway(name, z, start, end):
        wall_segment(f"pared_{name}_sur", z, south, start)
        wall_segment(f"pared_{name}_norte", z, end, north)
        box(f"pared_{name}_dintel", "pared", ((start + end) / 2, 2.65, z),
            (end - start, 0.90, 0.11))
        for side, x in (("sur", start), ("norte", end)):
            box(f"marco_{name}_{side}", "marco", (x, 1.10, z),
                (0.055, 2.20, 0.12))
        box(f"marco_{name}_superior", "marco",
            ((start + end) / 2, 2.20, z),
            (end - start + 0.11, 0.055, 0.12))

    # Suelo de la habitación del pasillo; coordenadas y tamaños en metros.
    box("base_suelo_habitacion_pasillo", "suelo", (0, -0.08, 0),
        (ANCHO_X, 0.16, FONDO_Z))
    # Una franja independiente continúa el pasillo hasta la puerta del baño.
    ancho_pasillo = PASILLO_DERECHA - (POSITION[0] - ANCHO_X / 2)
    for column in range(2):
        for row in range(6):
            x = south + (column + 0.5) * ancho_pasillo / 2
            z = west + (row + 0.5) * FONDO_Z / 6
            material = "baldosa_pasillo_a" if (column + row) % 2 else "baldosa_pasillo_b"
            box(f"baldosa_continuacion_pasillo_{column}_{row}", material,
                (x, 0.005, z),
                (ancho_pasillo / 2 - 0.01, 0.018, FONDO_Z / 6 - 0.02))
    ancho_habitacion = ANCHO_X - ancho_pasillo
    # Más columnas conservan el tamaño aproximado de las baldosas anteriores.
    for column in range(10):
        for row in range(6):
            x = south + ancho_pasillo + (column + 0.5) * ancho_habitacion / 10
            z = west + (row + 0.5) * FONDO_Z / 6
            material = "baldosa_a" if (column + row) % 2 else "baldosa_b"
            box(f"baldosa_cuarto_pasillo_{column}_{row}", material,
                (x, 0.005, z),
                (ancho_habitacion / 10 - 0.01, 0.018,
                 FONDO_Z / 6 - 0.02))

    # Paredes laterales de la habitación y del pasillo continuo.
    box("pared_larga_izquierda_habitacion_pasillo", "pared",
        (south, ALTURA / 2, 0), (0.11, ALTURA, FONDO_Z))
    box("pared_larga_derecha_habitacion_pasillo", "pared",
        (north, ALTURA / 2, 0), (0.11, ALTURA, FONDO_Z))

    # El pasillo pasa por el extremo sur sin marco ni hoja que lo interrumpan.
    # Puerta de la habitación: vuelve al hueco original de la fachada occidental.
    divider_x = PASILLO_DERECHA - POSITION[0]
    door_left = PUERTA_TERCERA_IZQUIERDA - POSITION[0]
    door_right = PUERTA_TERCERA_DERECHA - POSITION[0]
    wall_segment("pared_fondo_habitacion_pasillo_norte",
                 west, door_right, north)
    wall_segment("pared_fondo_habitacion_pasillo_junto_tabique",
                 west, divider_x + 0.055, door_left)
    box("pared_fondo_habitacion_pasillo_dintel", "pared",
        ((door_left + door_right) / 2, 2.65, west),
        (door_right - door_left, 0.90, 0.11))
    for name, x in (("izquierdo", door_left), ("derecho", door_right)):
        box(f"marco_puerta_habitacion_pasillo_{name}", "marco",
            (x, 1.10, west), (0.055, 2.20, 0.12))
    box("marco_puerta_habitacion_pasillo_superior", "marco",
        ((door_left + door_right) / 2, 2.20, west),
        (door_right - door_left + 0.11, 0.055, 0.12))
    box("hoja_puerta_habitacion_pasillo", "puerta",
        ((door_left + door_right) / 2, 1.08, west),
        (door_right - door_left - 0.02, 2.16, 0.045))
    box("tirador_puerta_habitacion_pasillo", "tirador",
        (door_right - 0.09, 1.00, west - 0.04),
        (0.025, 0.07, 0.025))

    # En el extremo del pasillo queda la puerta del baño.
    doorway("entrada_bano_habitacion_pasillo", east,
            PUERTA_BANO_IZQUIERDA - POSITION[0],
            PUERTA_BANO_DERECHA - POSITION[0])

    pilar_fin = PUERTA_BANO_IZQUIERDA - POSITION[0]
    box("pilar_derecho_visto_desde_pasillo_bano", "pared",
        (pilar_fin - PILAR_BANO_ANCHO / 2, ALTURA / 2,
         east - PILAR_BANO_FONDO / 2),
        (PILAR_BANO_ANCHO, ALTURA, PILAR_BANO_FONDO))
    saliente_izquierda = X_SUR - POSITION[0]
    saliente_derecha = PUERTA_BANO_DERECHA - POSITION[0]
    box("saliente_superior_entrada_bano", "pared",
        ((saliente_izquierda + saliente_derecha) / 2,
         ALTURA - SALIENTE_BANO_ALTO / 2,
         east - PILAR_BANO_FONDO / 2),
        (saliente_derecha - saliente_izquierda,
         SALIENTE_BANO_ALTO, PILAR_BANO_FONDO))

    # Esta pared separa la habitación del pasillo sin abrir otra puerta.
    inicio_divisoria = west + 0.07
    fin_divisoria = east - 0.05
    box("pared_divisoria_habitacion_pasillo", "pared",
        (divider_x, ALTURA / 2, (inicio_divisoria + fin_divisoria) / 2),
        (0.11, ALTURA, fin_divisoria - inicio_divisoria))
    # Punto de anclaje estable de la lámpara para su futura integración domótica.
    box("luz_colgante_pasillo", "laton_lampara",
        ((south + divider_x) / 2, ALTURA - 0.015, 0.42),
        (0.02, 0.02, 0.02))
    return model.write(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--importar", action="store_true")
    arguments = parser.parse_args()
    output = generate()
    print(output)
    if arguments.importar:
        sys.path.insert(0, str(REPO / "mcp_server"))
        print(json.dumps(import_room(output, "cuarto_pasillo",
                                     "Trastero", POSITION),
                         ensure_ascii=False))


if __name__ == "__main__":
    main()
