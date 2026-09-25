"""Pruebas de importación local del gemelo 3D."""

import json
import struct
import tempfile
import unittest
from pathlib import Path

from home_twin_repository import HomeTwinRepository


def sample_glb() -> bytes:
    geometry = struct.pack(
        "<9f", -0.5, 0.0, 0.0, 0.5, 0.0, 0.0, 0.0, 1.0, 0.0
    )
    document = {
        "asset": {"version": "2.0"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": "lampara", "mesh": 0}],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0}}]}],
        "buffers": [{"byteLength": len(geometry)}],
        "bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": len(geometry)}],
        "accessors": [{
            "bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3",
            "min": [-0.5, 0.0, 0.0], "max": [0.5, 1.0, 0.0],
        }],
    }
    body = json.dumps(document, separators=(",", ":")).encode("utf-8")
    body += b" " * (-len(body) % 4)
    total = 12 + 8 + len(body) + 8 + len(geometry)
    return (
        struct.pack("<4sII", b"glTF", 2, total)
        + struct.pack("<I4s", len(body), b"JSON") + body
        + struct.pack("<I4s", len(geometry), b"BIN\x00") + geometry
    )


class HomeTwinRepositoryTest(unittest.TestCase):
    def test_importa_dos_habitaciones_y_reintenta_sin_duplicar(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "estancia.glb"
            source.write_bytes(sample_glb())
            repository = HomeTwinRepository(root)
            first = {
                "room_id": "dormitorio", "name": "Dormitorio",
                "source_file": str(source), "position": {"x": 0, "y": 0, "z": 0},
                "objects": [{
                    "id": "luz", "name": "Luz", "node_name": "lampara",
                    "kind": "luz", "household_item_id": "articulo-1",
                }],
            }
            result = repository.import_room(first, {"articulo-1"})
            self.assertTrue(result["savedLocally"])
            self.assertTrue(result["changed"])
            self.assertFalse(repository.import_room(first, {"articulo-1"})["changed"])
            second = dict(first, room_id="salon", name="Salón",
                          position={"x": 4, "y": 0, "z": 0}, objects=[])
            repository.import_room(second, {"articulo-1"})
            rooms = repository.list_rooms()
            self.assertEqual([room["id"] for room in rooms], ["dormitorio", "salon"])
            self.assertTrue((repository.root / rooms[0]["modelPath"]).exists())

    def test_rechaza_nodos_y_referencias_inexistentes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "estancia.glb"
            source.write_bytes(sample_glb())
            repository = HomeTwinRepository(root)
            values = {
                "room_id": "dormitorio", "name": "Dormitorio",
                "source_file": str(source),
                "objects": [{"id": "luz", "name": "Luz", "node_name": "otro"}],
            }
            with self.assertRaisesRegex(ValueError, "no está en el modelo"):
                repository.import_room(values, set())
            values["objects"][0]["node_name"] = "lampara"
            values["objects"][0]["household_item_id"] = "desconocido"
            with self.assertRaisesRegex(ValueError, "No existe el artículo"):
                repository.import_room(values, set())
            self.assertEqual(repository.list_rooms(), [])


if __name__ == "__main__":
    unittest.main()
