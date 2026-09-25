"""Importación local de habitaciones para el gemelo 3D de Hogar."""

import hashlib
import json
import math
import re
import struct
from pathlib import Path
from typing import Any


_SAFE_ID = re.compile(r"^[a-zA-Z0-9_-]+$")


class HomeTwinRepository:
    def __init__(self, household_root: Path):
        self.root = household_root / "twin"
        self.manifest = self.root / "house.json"

    def list_rooms(self) -> list[dict[str, Any]]:
        if not self.manifest.exists():
            return []
        document = json.loads(self.manifest.read_text(encoding="utf-8"))
        if document.get("schemaVersion") != 1 or not isinstance(document.get("rooms"), list):
            raise ValueError("El manifiesto del gemelo 3D no es válido.")
        return document["rooms"]

    def import_room(self, arguments: dict[str, Any], household_ids: set[str]) -> dict[str, Any]:
        room_id = str(arguments.get("room_id", "")).strip()
        name = str(arguments.get("name", "")).strip()
        if not _SAFE_ID.fullmatch(room_id) or not name:
            raise ValueError("La habitación necesita un identificador seguro y un nombre.")
        source = Path(str(arguments.get("source_file", ""))).expanduser().resolve()
        if source.suffix.lower() != ".glb" or not source.is_file():
            raise ValueError("El modelo debe ser un archivo GLB local.")
        if source.stat().st_size > 100_000_000:
            raise ValueError("El modelo supera el máximo de 100 MB.")
        data = source.read_bytes()
        node_names = self._glb_node_names(data)
        position = arguments.get("position", {"x": 0, "y": 0, "z": 0})
        if not isinstance(position, dict):
            raise ValueError("La posición debe contener x, y y z en metros.")
        coordinates = {axis: self._finite(position.get(axis, 0)) for axis in ("x", "y", "z")}
        rotation = self._finite(arguments.get("rotation_degrees", 0))
        floor = arguments.get("floor", 0)
        if type(floor) is not int:
            raise ValueError("La planta debe ser un número entero.")
        raw_objects = arguments.get("objects", [])
        if not isinstance(raw_objects, list):
            raise ValueError("Los objetos deben formar una lista.")
        objects: list[dict[str, Any]] = []
        object_ids: set[str] = set()
        for value in raw_objects:
            if not isinstance(value, dict):
                raise ValueError("Cada objeto debe ser un registro.")
            object_id = str(value.get("id", "")).strip()
            object_name = str(value.get("name", "")).strip()
            node_name = str(value.get("node_name", "")).strip()
            household_id = str(value.get("household_item_id") or "").strip()
            if not _SAFE_ID.fullmatch(object_id) or object_id in object_ids or not object_name:
                raise ValueError("Un objeto tiene un identificador o nombre inválido.")
            if node_name not in node_names:
                raise ValueError(f"El nodo {node_name} no está en el modelo GLB.")
            if household_id and household_id not in household_ids:
                raise ValueError(f"No existe el artículo de Hogar {household_id}.")
            object_ids.add(object_id)
            objects.append({
                "id": object_id,
                "name": object_name,
                "nodeName": node_name,
                "kind": str(value.get("kind") or "otro").strip(),
                "householdItemId": household_id or None,
            })

        digest = hashlib.sha256(data).hexdigest()
        filename = f"{room_id}-{digest[:16]}.glb"
        room = {
            "id": room_id,
            "name": name,
            "modelPath": f"models/{filename}",
            "position": coordinates,
            "floor": floor,
            "rotationDegrees": rotation,
            "objects": objects,
        }
        rooms = self.list_rooms()
        previous = next((item for item in rooms if item.get("id") == room_id), None)
        if previous == room:
            return {"savedLocally": True, "changed": False, "room": room}
        models = self.root / "models"
        models.mkdir(parents=True, exist_ok=True)
        destination = models / filename
        if not destination.exists():
            temporary_model = models / f"{filename}.tmp"
            temporary_model.write_bytes(data)
            temporary_model.replace(destination)
        updated = [room if item.get("id") == room_id else item for item in rooms]
        if previous is None:
            updated.append(room)
        document = {"schemaVersion": 1, "rooms": updated}
        temporary_manifest = self.root / "house.json.tmp"
        temporary_manifest.write_text(
            json.dumps(document, indent=2, ensure_ascii=False), encoding="utf-8"
        )
        temporary_manifest.replace(self.manifest)
        if previous:
            old_path = previous.get("modelPath", "")
            if old_path != room["modelPath"] and not any(
                item.get("modelPath") == old_path for item in updated
            ):
                old_file = self.root / old_path
                if old_file.parent == models:
                    old_file.unlink(missing_ok=True)
        return {"savedLocally": True, "changed": True, "room": room}

    @staticmethod
    def _finite(value: Any) -> float:
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
            raise ValueError("Las coordenadas y el giro deben ser números finitos.")
        return float(value)

    @staticmethod
    def _glb_node_names(data: bytes) -> set[str]:
        if len(data) < 20 or data[:4] != b"glTF":
            raise ValueError("El archivo no es un GLB válido.")
        version, size = struct.unpack_from("<II", data, 4)
        chunk_size, chunk_type = struct.unpack_from("<I4s", data, 12)
        if version != 2 or size != len(data) or chunk_type != b"JSON" or 20 + chunk_size > size:
            raise ValueError("El archivo GLB tiene una cabecera inválida.")
        try:
            document = json.loads(data[20:20 + chunk_size].decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise ValueError("El contenido del modelo GLB no es válido.") from error
        if document.get("asset", {}).get("version") != "2.0":
            raise ValueError("Solo se admiten modelos glTF 2.0.")
        return {
            node["name"] for node in document.get("nodes", [])
            if isinstance(node, dict) and isinstance(node.get("name"), str)
        }
