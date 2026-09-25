"""Genera una habitación vacía para revisar el visor 3D de Hogar."""

import argparse
import json
import struct
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
OUTPUT = REPO / "assets" / "home_twin_demo" / "habitacion_generica.glb"


def cube_geometry():
    faces = [
        ((0, 0, 1), ((-0.5, -0.5, 0.5), (0.5, -0.5, 0.5), (0.5, 0.5, 0.5), (-0.5, 0.5, 0.5))),
        ((0, 0, -1), ((0.5, -0.5, -0.5), (-0.5, -0.5, -0.5), (-0.5, 0.5, -0.5), (0.5, 0.5, -0.5))),
        ((1, 0, 0), ((0.5, -0.5, 0.5), (0.5, -0.5, -0.5), (0.5, 0.5, -0.5), (0.5, 0.5, 0.5))),
        ((-1, 0, 0), ((-0.5, -0.5, -0.5), (-0.5, -0.5, 0.5), (-0.5, 0.5, 0.5), (-0.5, 0.5, -0.5))),
        ((0, 1, 0), ((-0.5, 0.5, 0.5), (0.5, 0.5, 0.5), (0.5, 0.5, -0.5), (-0.5, 0.5, -0.5))),
        ((0, -1, 0), ((-0.5, -0.5, -0.5), (0.5, -0.5, -0.5), (0.5, -0.5, 0.5), (-0.5, -0.5, 0.5))),
    ]
    positions = []
    normals = []
    indices = []
    for normal, corners in faces:
        first = len(positions) // 3
        for corner in corners:
            positions.extend(corner)
            normals.extend(normal)
        indices.extend((first, first + 1, first + 2, first, first + 2, first + 3))
    position_bytes = struct.pack(f"<{len(positions)}f", *positions)
    normal_bytes = struct.pack(f"<{len(normals)}f", *normals)
    index_bytes = struct.pack(f"<{len(indices)}H", *indices)
    return position_bytes, normal_bytes, index_bytes


def generate(output: Path = OUTPUT) -> Path:
    positions, normals, indices = cube_geometry()
    binary = positions + normals + indices
    palette = {
        "muro": (0.83, 0.84, 0.78, 1),
        "muro_claro": (0.93, 0.92, 0.85, 1),
        "canto": (0.70, 0.73, 0.64, 1),
        "suelo": (0.65, 0.48, 0.34, 1),
        "tabla": (0.77, 0.59, 0.42, 1),
        "junta": (0.58, 0.43, 0.32, 1),
        "marco": (0.96, 0.93, 0.81, 1),
        "puerta": (0.46, 0.57, 0.49, 1),
        "tirador": (0.75, 0.57, 0.31, 1),
        "cristal": (0.53, 0.72, 0.75, 0.6),
        "exterior": (0.57, 0.68, 0.59, 1),
    }
    materials = []
    meshes = []
    nodes = []
    material_index = {}
    for name, color in palette.items():
        material_index[name] = len(materials)
        material = {
            "name": name,
            "pbrMetallicRoughness": {
                "baseColorFactor": color,
                "metallicFactor": 0,
                "roughnessFactor": 0.88,
            },
            "doubleSided": True,
        }
        if name == "cristal":
            material["alphaMode"] = "BLEND"
        materials.append(material)

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

    box("base_suelo", "suelo", (0, -0.095, 0), (4.16, 0.17, 3.16))
    for row in range(10):
        z = -1.35 + row * 0.3
        box(f"tabla_suelo_{row + 1}", "tabla", (0, 0, z), (4.0, 0.025, 0.293))
        if row < 9:
            box(f"junta_suelo_{row + 1}", "junta", (0, 0.015, z + 0.15), (4.0, 0.002, 0.006))

    # Dos muros recortados dejan ver la estancia desde la cámara isométrica.
    box("muro_fondo_izquierdo", "muro_claro", (-0.925, 1.3, -1.5), (2.15, 2.6, 0.13))
    box("muro_fondo_derecho", "muro_claro", (1.675, 1.3, -1.5), (0.65, 2.6, 0.13))
    box("muro_bajo_ventana", "muro_claro", (0.75, 0.5, -1.5), (1.2, 1, 0.13))
    box("muro_sobre_ventana", "muro_claro", (0.75, 2.375, -1.5), (1.2, 0.45, 0.13))
    box("muro_izquierdo_fondo", "muro", (-2, 1.3, -0.675), (0.13, 2.6, 1.65))
    box("muro_izquierdo_frente", "muro", (-2, 1.3, 1.225), (0.13, 2.6, 0.55))
    box("muro_sobre_puerta", "muro", (-2, 2.35, 0.55), (0.13, 0.5, 0.8))
    box("canto_superior_fondo", "canto", (0, 2.61, -1.5), (4.15, 0.05, 0.17))
    box("canto_superior_izquierdo", "canto", (-2, 2.61, 0), (0.17, 0.05, 3.1))
    box("rodapie_fondo_izquierdo", "marco", (-0.925, 0.085, -1.415), (2.15, 0.17, 0.035))
    box("rodapie_fondo_derecho", "marco", (1.675, 0.085, -1.415), (0.65, 0.17, 0.035))
    box("rodapie_izquierdo", "marco", (-1.915, 0.085, -0.675), (0.035, 0.17, 1.65))

    # La puerta y la ventana tienen nombres estables para su futura ficha.
    box("puerta", "puerta", (-1.91, 1.045, 0.55), (0.07, 2.09, 0.77))
    box("marco_puerta_superior", "marco", (-1.86, 2.11, 0.55), (0.1, 0.07, 0.9))
    box("marco_puerta_lado_1", "marco", (-1.86, 1.05, 0.13), (0.1, 2.1, 0.065))
    box("marco_puerta_lado_2", "marco", (-1.86, 1.05, 0.97), (0.1, 2.1, 0.065))
    box("tirador_puerta", "tirador", (-1.845, 1.0, 0.85), (0.04, 0.05, 0.11))
    box("ventana", "cristal", (0.75, 1.575, -1.47), (1.16, 1.11, 0.015))
    box("marco_ventana_arriba", "marco", (0.75, 2.16, -1.41), (1.27, 0.07, 0.10))
    box("marco_ventana_abajo", "marco", (0.75, 0.99, -1.41), (1.27, 0.07, 0.12))
    box("marco_ventana_izquierda", "marco", (0.15, 1.575, -1.41), (0.07, 1.2, 0.10))
    box("marco_ventana_derecha", "marco", (1.35, 1.575, -1.41), (0.07, 1.2, 0.10))
    box("parteluz_ventana", "marco", (0.75, 1.575, -1.39), (0.045, 1.16, 0.05))
    box("alféizar", "marco", (0.75, 0.965, -1.33), (1.34, 0.055, 0.26))

    document = {
        "asset": {"version": "2.0", "generator": "Todo: habitación de ejemplo"},
        "scene": 0,
        "scenes": [{"nodes": list(range(len(nodes)))}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "buffers": [{"byteLength": len(binary)}],
        "bufferViews": [
            {"buffer": 0, "byteOffset": 0, "byteLength": len(positions), "target": 34962},
            {"buffer": 0, "byteOffset": len(positions), "byteLength": len(normals), "target": 34962},
            {"buffer": 0, "byteOffset": len(positions) + len(normals), "byteLength": len(indices), "target": 34963},
        ],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": 24, "type": "VEC3", "min": [-0.5, -0.5, -0.5], "max": [0.5, 0.5, 0.5]},
            {"bufferView": 1, "componentType": 5126, "count": 24, "type": "VEC3"},
            {"bufferView": 2, "componentType": 5123, "count": 36, "type": "SCALAR"},
        ],
    }
    json_chunk = json.dumps(document, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
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
    parser.add_argument("--importar", action="store_true", help="Añadir la habitación a los datos locales de Todo")
    arguments = parser.parse_args()
    output = generate()
    print(output)
    if arguments.importar:
        import sys
        sys.path.insert(0, str(REPO / "mcp_server"))
        from home_twin_repository import HomeTwinRepository

        repository = HomeTwinRepository(Path.home() / "Documents" / "Todo" / "household")
        result = repository.import_room({
            "room_id": "dormitorio",
            "name": "Habitación de ejemplo",
            "source_file": str(output),
            "floor": 0,
            "position": {"x": 0, "y": 0, "z": 0},
            "objects": [
                {"id": "puerta", "name": "Puerta de ejemplo", "node_name": "puerta", "kind": "puerta"},
                {"id": "ventana", "name": "Ventana de ejemplo", "node_name": "ventana", "kind": "ventana"},
            ],
        }, set())
        print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
