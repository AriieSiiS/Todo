"""Genera el dormitorio contiguo como un modelo independiente."""

import argparse
import json
import struct
import sys
from pathlib import Path

from generate_home_twin_demo import cube_geometry


REPO = Path(__file__).resolve().parents[1]
OUTPUT = REPO / "assets" / "home_twin_models" / "habitacion_vacia_base.glb"

# Las medidas interiores son idénticas a las del dormitorio, en metros.
WIDTH = 2.10
LENGTH = 4.10
HEIGHT = 3.10
WALL = 0.11
POSITION_X = WIDTH
# La ventana conserva 1,03 m de ancho y se acerca al tabique izquierdo.
# Su barra de persiana llega hasta el eje del muro compartido.
WINDOW_LEFT = -0.96
WINDOW_RIGHT = 0.07
WINDOW_SILL = 0.90
WINDOW_TOP = 2.27
# La entrada queda junto al extremo derecho de esta pared.
DOOR_LEFT = 0.13
DOOR_RIGHT = 0.95
DOOR_TOP = 2.18
VIGA_ENTRADA_ALTO = 0.25
VIGA_ENTRADA_FONDO = 0.11


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
        "cristal_puerta": (0.55, 0.67, 0.67, 0.48),
        "metal_puerta": (0.48, 0.48, 0.42, 1),
        "cristal_ventana": (0.11, 0.17, 0.19, 0.64),
        "persiana_clara": (0.74, 0.73, 0.69, 1),
    }
    materials = [{
        "name": name,
        "pbrMetallicRoughness": {
            "baseColorFactor": color,
            "metallicFactor": 0,
            "roughnessFactor": 0.9,
        },
        "doubleSided": True,
    } for name, color in palette.items()]
    materials[list(palette).index("cristal_puerta")]["alphaMode"] = "BLEND"
    materials[list(palette).index("cristal_ventana")]["alphaMode"] = "BLEND"
    material_index = {name: index for index, name in enumerate(palette)}
    nodes = []
    meshes = []
    roots = []

    def box(name, material, position, size):
        mesh_index = len(meshes)
        meshes.append({
            "name": name,
            "primitives": [{
                "attributes": {"POSITION": 0, "NORMAL": 1},
                "indices": 2,
                "material": material_index[material],
            }],
        })
        nodes.append({
            "name": name,
            "mesh": mesh_index,
            "translation": list(position),
            "scale": list(size),
        })
        roots.append(len(nodes) - 1)
        return len(nodes) - 1

    def group(name, children):
        for child in children:
            roots.remove(child)
        nodes.append({"name": name, "children": children})
        roots.append(len(nodes) - 1)

    # Suelo y baldosas del dormitorio; coordenadas y tamaños en metros.
    box("base_suelo_vacia", "suelo_oscuro", (0, -0.09, 0),
        (WIDTH + 0.18, 0.17, LENGTH + 0.18))
    for row in range(8):
        for column in range(4):
            x = -WIDTH / 2 + (column + 0.5) * WIDTH / 4
            z = -LENGTH / 2 + (row + 0.5) * LENGTH / 8
            tile = ("baldosa_a", "baldosa_b", "baldosa_c")[(row * 7 + column * 3) % 3]
            box(f"baldosa_vacia_{row + 1}_{column + 1}", tile,
                (x, 0.005, z),
                (WIDTH / 4 - 0.008, 0.02, LENGTH / 8 - 0.008))

    # Pared del fondo con el hueco de la ventana.
    back = -LENGTH / 2
    box("pared_fondo_izquierda_vacia", "pared_verde_salvia",
        ((-WIDTH / 2 + WINDOW_LEFT) / 2, HEIGHT / 2, back),
        (WINDOW_LEFT + WIDTH / 2, HEIGHT, WALL))
    box("pared_fondo_derecha_vacia", "pared_verde_salvia",
        ((WINDOW_RIGHT + WIDTH / 2) / 2, HEIGHT / 2, back),
        (WIDTH / 2 - WINDOW_RIGHT, HEIGHT, WALL))
    box("pared_bajo_ventana_vacia", "pared_verde_salvia",
        ((WINDOW_LEFT + WINDOW_RIGHT) / 2, WINDOW_SILL / 2, back),
        (WINDOW_RIGHT - WINDOW_LEFT, WINDOW_SILL, WALL))
    box("pared_sobre_ventana_vacia", "pared_verde_salvia",
        ((WINDOW_LEFT + WINDOW_RIGHT) / 2, (WINDOW_TOP + HEIGHT) / 2, back),
        (WINDOW_RIGHT - WINDOW_LEFT, HEIGHT - WINDOW_TOP, WALL))
    # Pared de entrada con el hueco de la puerta y la viga superior.
    front = LENGTH / 2
    box("pared_entrada_izquierda_vacia", "pared_verde_salvia",
        ((-WIDTH / 2 + DOOR_LEFT) / 2, HEIGHT / 2, front),
        (DOOR_LEFT + WIDTH / 2, HEIGHT, WALL))
    box("pared_entrada_derecha_vacia", "pared_verde_salvia",
        ((DOOR_RIGHT + WIDTH / 2) / 2, HEIGHT / 2, front),
        (WIDTH / 2 - DOOR_RIGHT, HEIGHT, WALL))
    box("pared_entrada_sobre_puerta_vacia", "pared_verde_salvia",
        ((DOOR_LEFT + DOOR_RIGHT) / 2, (DOOR_TOP + HEIGHT) / 2, front),
        (DOOR_RIGHT - DOOR_LEFT, HEIGHT - DOOR_TOP, WALL))
    box("pared_entrada_viga_superior_vacia", "pared_verde_salvia",
        (0, HEIGHT - VIGA_ENTRADA_ALTO / 2,
         front - WALL / 2 - VIGA_ENTRADA_FONDO / 2),
        (WIDTH, VIGA_ENTRADA_ALTO, VIGA_ENTRADA_FONDO))
    # Pared lateral derecha y división con el dormitorio.
    box("pared_larga_derecha_vacia", "pared_verde_salvia",
        (WIDTH / 2, HEIGHT / 2, 0), (WALL, HEIGHT, LENGTH))
    # Tabique entre ventanas: pilares y viga más finos para que ambas parezcan
    # tramos consecutivos. El paño lateral principal está en el dormitorio.
    box("pilar_divisorio_fondo", "pared_verde_salvia",
        (-WIDTH / 2, HEIGHT / 2, -LENGTH / 2),
        (0.10, HEIGHT, 0.11))
    box("pilar_divisorio_entrada", "pared_verde_salvia",
        (-WIDTH / 2, HEIGHT / 2, LENGTH / 2),
        (0.10, HEIGHT, 0.11))
    box("viga_superior_divisoria", "techo_blanco",
        (-WIDTH / 2, HEIGHT + 0.025, 0),
        (0.12, 0.08, LENGTH + 0.12))
    # Rodapiés, umbral y fragmentos de techo.
    box("rodapié_fondo_vacio", "rodapié_blanco",
        (0, 0.08, -LENGTH / 2 + 0.065), (WIDTH, 0.16, 0.03))
    box("rodapié_entrada_vacio", "rodapié_blanco",
        (0, 0.08, LENGTH / 2 - 0.065), (WIDTH, 0.16, 0.03))
    box("rodapié_derecho_vacio", "rodapié_blanco",
        (WIDTH / 2 - 0.065, 0.08, 0), (0.03, 0.16, LENGTH))
    box("rodapié_compartido_vacio", "rodapié_blanco",
        (-WIDTH / 2 + 0.065, 0.08, 0), (0.03, 0.16, LENGTH))
    box("umbral_puerta_vacia", "rodapié_blanco",
        ((DOOR_LEFT + DOOR_RIGHT) / 2, 0.015, front),
        (DOOR_RIGHT - DOOR_LEFT, 0.03, 0.15))
    box("techo_blanco_fondo_vacio", "techo_blanco",
        (0, HEIGHT + 0.025, -LENGTH / 2 + 0.11),
        (WIDTH + 0.12, 0.08, 0.32))
    box("techo_blanco_derecho_vacio", "techo_blanco",
        (WIDTH / 2 - 0.07, HEIGHT + 0.025, 0),
        (0.22, 0.08, LENGTH + 0.12))

    # Ventana: cristal, marco, alféizar y persiana.
    window = []
    window_center = (WINDOW_LEFT + WINDOW_RIGHT) / 2
    window_height = WINDOW_TOP - WINDOW_SILL
    window.extend([
        box("cristal_ventana_vacia", "cristal_ventana",
            (window_center, (WINDOW_SILL + WINDOW_TOP) / 2, back + 0.065),
            (WINDOW_RIGHT - WINDOW_LEFT - 0.07, window_height - 0.07, 0.025)),
        box("marco_ventana_izquierdo_vacia", "marco_blanco",
            (WINDOW_LEFT, (WINDOW_SILL + WINDOW_TOP) / 2, back + 0.11),
            (0.055, window_height + 0.10, 0.10)),
        box("marco_ventana_derecho_vacia", "marco_blanco",
            (WINDOW_RIGHT, (WINDOW_SILL + WINDOW_TOP) / 2, back + 0.11),
            (0.055, window_height + 0.10, 0.10)),
        box("marco_ventana_arriba_vacia", "marco_blanco",
            (window_center, WINDOW_TOP, back + 0.11),
            (WINDOW_RIGHT - WINDOW_LEFT + 0.11, 0.06, 0.10)),
        box("alféizar_ventana_vacia", "marco_blanco",
            (window_center, WINDOW_SILL - 0.015, back + 0.10),
            (WINDOW_RIGHT - WINDOW_LEFT + 0.11, 0.03, 0.10)),
        box("persiana_ventana_vacia", "persiana_clara",
            (window_center, (WINDOW_SILL + WINDOW_TOP) / 2, back + 0.13),
            (WINDOW_RIGHT - WINDOW_LEFT + 0.01, window_height + 0.01, 0.015)),
        box("borde_inferior_persiana_vacia", "marco_blanco",
            (window_center, WINDOW_SILL + 0.005, back + 0.15),
            (WINDOW_RIGHT - WINDOW_LEFT + 0.04, 0.018, 0.03)),
        box("barra_persiana_vacia", "marco_blanco",
            (window_center, WINDOW_TOP + 0.07, back + 0.17),
            (WINDOW_RIGHT - WINDOW_LEFT + 0.18, 0.065, 0.07)),
    ])
    group("ventana_vacia", window)

    door_center = (DOOR_LEFT + DOOR_RIGHT) / 2
    # Puerta: marco y hoja; la animación se añade en el visor.
    box("marco_puerta_izquierdo_vacia", "marco_blanco",
        (DOOR_LEFT, DOOR_TOP / 2, front - 0.02),
        (0.065, DOOR_TOP + 0.10, 0.12))
    box("marco_puerta_derecho_vacia", "marco_blanco",
        (DOOR_RIGHT, DOOR_TOP / 2, front - 0.02),
        (0.065, DOOR_TOP + 0.10, 0.12))
    box("marco_puerta_arriba_vacia", "marco_blanco",
        (door_center, DOOR_TOP, front - 0.02),
        (DOOR_RIGHT - DOOR_LEFT + 0.11, 0.07, 0.12))

    # Hoja abierta hacia el pasillo, igual que en la habitación principal.
    leaf_x = DOOR_LEFT + 0.02
    leaf_z = front + 0.43
    for side, z in (("izquierdo", leaf_z - 0.40),
                    ("derecho", leaf_z + 0.40)):
        box(f"hoja_puerta_vacia_{side}", "marco_blanco",
            (leaf_x, 1.08, z), (0.065, 2.16, 0.06))
    box("hoja_puerta_vacia_superior", "marco_blanco",
        (leaf_x, 2.13, leaf_z), (0.065, 0.06, 0.83))
    box("hoja_puerta_vacia_inferior", "marco_blanco",
        (leaf_x, 0.43, leaf_z), (0.065, 0.86, 0.83))
    box("cristales_puerta_vacia", "cristal_puerta",
        (leaf_x, 1.48, leaf_z), (0.025, 1.24, 0.73))
    for index in range(1, 4):
        box(f"travesaño_puerta_vacia_{index}", "marco_blanco",
            (leaf_x - 0.03, 0.88 + index * 0.32, leaf_z),
            (0.035, 0.045, 0.83))
    box("parteluz_puerta_vacia", "marco_blanco",
        (leaf_x - 0.03, 1.49, leaf_z), (0.035, 1.25, 0.045))
    box("tirador_puerta_vacia", "metal_puerta",
        (leaf_x - 0.07, 0.99, leaf_z - 0.30), (0.07, 0.04, 0.10))

    # Ancla seleccionable de la lámpara que se construye en el visor.
    box("ancla_luz_dormitorio", "marco_blanco", (0, 2.35, 0),
        (0.02, 0.02, 0.02))

    document = {
        "asset": {"version": "2.0", "generator": "Todo: dormitorio"},
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
            {"bufferView": 0, "componentType": 5126, "count": 24,
             "type": "VEC3", "min": [-0.5, -0.5, -0.5], "max": [0.5, 0.5, 0.5]},
            {"bufferView": 1, "componentType": 5126, "count": 24, "type": "VEC3"},
            {"bufferView": 2, "componentType": 5123, "count": 36, "type": "SCALAR"},
        ],
    }
    json_chunk = json.dumps(document, ensure_ascii=False,
                            separators=(",", ":")).encode("utf-8")
    json_chunk += b" " * (-len(json_chunk) % 4)
    binary += b"\0" * (-len(binary) % 4)
    glb = (
        struct.pack("<4sII", b"glTF", 2,
                    12 + 8 + len(json_chunk) + 8 + len(binary))
        + struct.pack("<I4s", len(json_chunk), b"JSON") + json_chunk
        + struct.pack("<I4s", len(binary), b"BIN\0") + binary
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(glb)
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--importar", action="store_true",
                        help="Añadir la habitación a los datos locales de Todo")
    arguments = parser.parse_args()
    output = generate()
    print(output)
    if arguments.importar:
        sys.path.insert(0, str(REPO / "mcp_server"))
        from home_twin_repository import HomeTwinRepository

        repository = HomeTwinRepository(Path.home() / "Documents" / "Todo" / "household")
        result = repository.import_room({
            "room_id": "habitacion_vacia",
            "name": "Dormitorio",
            "source_file": str(output),
            "floor": 0,
            "position": {"x": POSITION_X, "y": 0, "z": 0},
            "objects": [
                {"id": "ventana", "name": "Ventana", "node_name": "ventana_vacia", "kind": "ventana"},
                {"id": "luz_techo", "name": "Luz del techo", "node_name": "ancla_luz_dormitorio", "kind": "luz"},
            ],
        }, set())
        print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
