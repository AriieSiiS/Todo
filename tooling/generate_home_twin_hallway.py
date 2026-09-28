"""Genera el pasillo con las distancias medidas junto a la tercera puerta."""

import argparse
import json
import sys
from pathlib import Path

from generate_home_twin_empty_room import (
    DOOR_LEFT as DORMITORIO_PUERTA_LOCAL_IZQUIERDA,
    DOOR_RIGHT as DORMITORIO_PUERTA_LOCAL_DERECHA,
    POSITION_X as DORMITORIO_CENTRO_X,
)
from home_twin_simple_geometry import SimpleModel, import_room


REPO = Path(__file__).resolve().parents[1]
OUTPUT = REPO / "assets" / "home_twin_models" / "pasillo_base.glb"

# Desde el extremo cercano hasta la jamba: 3,60 m. Desde la otra
# jamba hasta la pared del fondo: 0,90 m. La hoja conserva 0,87 m.
X_SUR = -1.05
PUERTA_TERCERA_IZQUIERDA = X_SUR + 0.90
PUERTA_TERCERA_DERECHA = PUERTA_TERCERA_IZQUIERDA + 0.87
X_NORTE = PUERTA_TERCERA_DERECHA + 3.60
PASILLO_DERECHA = PUERTA_TERCERA_IZQUIERDA - 0.10
# Un metro libre entre las caras visibles del muro revestido del pasillo
# (10 cm, adelantado 1,2 cm) y el muro de Trastero (11 cm).
Z_OESTE = 2.05
PASILLO_FONDO_LIBRE = 1.00
Z_ESTE = Z_OESTE + 0.012 + 0.10 / 2 + PASILLO_FONDO_LIBRE + 0.11 / 2
ALTURA = 3.10


def generate(output=OUTPUT):
    model = SimpleModel({
        "pared": (0.72, 0.67, 0.57, 1),
        "suelo": (0.043, 0.049, 0.050, 1),
        "baldosa_a": (0.075, 0.079, 0.078, 1),
        "baldosa_b": (0.095, 0.097, 0.091, 1),
        "marco": (0.80, 0.77, 0.69, 1),
        "cristal": (0.69, 0.75, 0.72, 0.45),
        "rodapie": (0.42, 0.32, 0.27, 1),
    }, "Todo: pasillo con medidas reales junto a la tercera puerta")
    box = model.box

    def muro_z(nombre, z, left, right, material="pared", y=1.55, high=ALTURA):
        if right > left:
            # El revestimiento del pasillo cubre la cara verde de los dormitorios.
            # Sus paredes son 1 cm más gruesas y antes asomaban como una franja.
            box(nombre, material, ((left + right) / 2, y, z + 0.012),
                (right - left, high, 0.10))

    def marco_z(nombre, z, left, right):
        for side, x in (("izquierdo", left), ("derecho", right)):
            box(f"marco_{nombre}_{side}", "marco", (x, 1.10, z),
                (0.05, 2.20, 0.12))
        box(f"marco_{nombre}_superior", "marco",
            ((left + right) / 2, 2.20, z),
            (right - left + 0.10, 0.05, 0.12))

    # Suelo y baldosas del pasillo; coordenadas y tamaños en metros.
    box("base_suelo_pasillo", "suelo",
        ((X_SUR + X_NORTE) / 2, -0.08, (Z_OESTE + Z_ESTE) / 2),
        (X_NORTE - X_SUR, 0.16, Z_ESTE - Z_OESTE))
    columns = 13
    tile_width = (X_NORTE - X_SUR) / columns
    for column in range(columns):
        for row in range(3):
            x = X_SUR + (column + 0.5) * tile_width
            z = Z_OESTE + (row + 0.5) * (Z_ESTE - Z_OESTE) / 3
            material = "baldosa_a" if (column + row) % 2 else "baldosa_b"
            box(f"baldosa_pasillo_{column}_{row}", material,
                (x, 0.005, z),
                (tile_width - 0.012, 0.018,
                 (Z_ESTE - Z_OESTE) / 3 - 0.014))

    # Puertas / huecos de dormitorio 1 y dormitorio 2, en la pared occidental.
    openings = [
        (-0.88, -0.06),
        (DORMITORIO_CENTRO_X + DORMITORIO_PUERTA_LOCAL_IZQUIERDA,
         DORMITORIO_CENTRO_X + DORMITORIO_PUERTA_LOCAL_DERECHA),
    ]
    cursor = X_SUR
    for index, (left, right) in enumerate(openings, start=1):
        muro_z(f"pared_fondo_pasillo_tramo_{index}", Z_OESTE, cursor, left)
        muro_z(f"pared_fondo_pasillo_dintel_{index}", Z_OESTE,
               left, right, y=2.65, high=0.90)
        marco_z(f"dormitorio_{index}", Z_OESTE, left, right)
        cursor = right
    muro_z("pared_fondo_pasillo_extremo", Z_OESTE, cursor, X_NORTE)

    # El tramo sur queda completamente abierto para continuar hasta el baño.
    # La única puerta de esta fachada vuelve a su posición original, hacia H.
    door_left = PUERTA_TERCERA_IZQUIERDA
    door_right = PUERTA_TERCERA_DERECHA
    # El pequeño tramo entre corredor y marco dejaba una franja visible.
    muro_z("pared_entrada_pasillo_dintel", Z_ESTE,
           door_left, door_right, y=2.65, high=0.90)
    # Cierra los 10 cm entre la jamba y el tabique sin tapar la continuación.
    muro_z("pared_entrada_pasillo_junto_tabique", Z_ESTE,
           PASILLO_DERECHA, door_left)
    muro_z("pared_entrada_pasillo_norte", Z_ESTE, door_right, X_NORTE)

    # Termina junto a la habitación principal: no baja hasta el antiguo baño.
    box("pared_larga_izquierda_pasillo_sur", "pared",
        (X_SUR, 1.55, (Z_OESTE + Z_ESTE) / 2),
        (0.10, ALTURA, Z_ESTE - Z_OESTE))
    box("pared_larga_derecha_pasillo_norte", "pared",
        (X_NORTE, 1.55, (Z_OESTE + Z_ESTE) / 2),
        (0.10, ALTURA, Z_ESTE - Z_OESTE))
    box("rodapie_este_pasillo", "rodapie",
        ((door_right + X_NORTE) / 2, 0.075, Z_ESTE - 0.04),
        (X_NORTE - door_right, 0.15, 0.025))
    # Ancla del control: la lámpara detallada se dibuja en el visor.
    box("ancla_luz_pasillo", "marco",
        (-0.10, 2.54, (Z_OESTE + Z_ESTE) / 2),
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
        print(json.dumps(import_room(output, "pasillo", "Pasillo", (0, 0),
                                     objects=[{
                                         "id": "luz_pasillo",
                                         "name": "Luz del pasillo",
                                         "node_name": "ancla_luz_pasillo",
                                         "kind": "luz",
                                     }]),
                         ensure_ascii=False))


if __name__ == "__main__":
    main()
