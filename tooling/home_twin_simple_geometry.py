"""Piezas geométricas sencillas para las estancias provisionales del gemelo."""

import json
import math
import struct
from pathlib import Path

from generate_home_twin_demo import cube_geometry


class SimpleModel:
    def __init__(self, palette, generator):
        positions, normals, indices = cube_geometry()
        self.binary = positions + normals + indices
        self.lengths = (len(positions), len(normals), len(indices))
        self.material_index = {}
        self.materials = []
        for name, color in palette.items():
            self.material_index[name] = len(self.materials)
            material = {
                "name": name,
                "pbrMetallicRoughness": {
                    "baseColorFactor": color,
                    "metallicFactor": 0,
                    "roughnessFactor": 0.86,
                },
                "doubleSided": True,
            }
            if color[3] < 1:
                material["alphaMode"] = "BLEND"
            self.materials.append(material)
        self.generator = generator
        self.nodes = []
        self.meshes = []

    def box(self, name, material, position, size, yaw=0):
        mesh_index = len(self.meshes)
        self.meshes.append({
            "name": name,
            "primitives": [{
                "attributes": {"POSITION": 0, "NORMAL": 1},
                "indices": 2,
                "material": self.material_index[material],
            }],
        })
        node = {
            "name": name,
            "mesh": mesh_index,
            "translation": list(position),
            "scale": list(size),
        }
        if yaw:
            node["rotation"] = [0, math.sin(yaw / 2), 0, math.cos(yaw / 2)]
        self.nodes.append(node)

    def write(self, output: Path):
        positions, normals, indices = self.lengths
        document = {
            "asset": {"version": "2.0", "generator": self.generator},
            "scene": 0,
            "scenes": [{"nodes": list(range(len(self.nodes)))}],
            "nodes": self.nodes,
            "meshes": self.meshes,
            "materials": self.materials,
            "buffers": [{"byteLength": len(self.binary)}],
            "bufferViews": [
                {"buffer": 0, "byteOffset": 0, "byteLength": positions, "target": 34962},
                {"buffer": 0, "byteOffset": positions, "byteLength": normals, "target": 34962},
                {"buffer": 0, "byteOffset": positions + normals,
                 "byteLength": indices, "target": 34963},
            ],
            "accessors": [
                {"bufferView": 0, "componentType": 5126, "count": 24,
                 "type": "VEC3", "min": [-0.5, -0.5, -0.5],
                 "max": [0.5, 0.5, 0.5]},
                {"bufferView": 1, "componentType": 5126, "count": 24, "type": "VEC3"},
                {"bufferView": 2, "componentType": 5123, "count": 36,
                 "type": "SCALAR"},
            ],
        }
        json_chunk = json.dumps(document, ensure_ascii=False,
                                separators=(",", ":")).encode("utf-8")
        json_chunk += b" " * (-len(json_chunk) % 4)
        binary = self.binary + b"\0" * (-len(self.binary) % 4)
        data = (
            struct.pack("<4sII", b"glTF", 2,
                        12 + 8 + len(json_chunk) + 8 + len(binary))
            + struct.pack("<I4s", len(json_chunk), b"JSON") + json_chunk
            + struct.pack("<I4s", len(binary), b"BIN\0") + binary
        )
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(data)
        return output


def import_room(output, room_id, name, position, objects=None):
    from home_twin_repository import HomeTwinRepository

    repository = HomeTwinRepository(Path.home() / "Documents" / "Todo" / "household")
    return repository.import_room({
        "room_id": room_id,
        "name": name,
        "source_file": str(output),
        "floor": 0,
        "position": {"x": position[0], "y": 0, "z": position[1]},
        "objects": objects or [],
    }, set())
