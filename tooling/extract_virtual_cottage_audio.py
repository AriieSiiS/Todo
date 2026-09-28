"""Extrae el audio de la instalación local de Virtual Cottage para Todo."""

from __future__ import annotations

import json
from pathlib import Path
import re
import struct
import subprocess


PROJECT = Path(__file__).resolve().parents[1]
PACK = Path(r"C:\Program Files (x86)\Steam\steamapps\common\Virtual Cottage\Virtual Cottage_WINDOWS.pck")
DESTINATION = PROJECT / "assets" / "home_twin_web" / "audio"


def read_index():
    with PACK.open("rb") as source:
        def uint32():
            return struct.unpack("<I", source.read(4))[0]

        def uint64():
            return struct.unpack("<Q", source.read(8))[0]

        if source.read(4) != b"GDPC":
            raise ValueError("El paquete no tiene un encabezado Godot válido.")
        version = tuple(uint32() for _ in range(4))
        if version[:3] != (1, 3, 5):
            raise ValueError(f"Versión de paquete inesperada: {version}")
        source.read(64)
        count = uint32()
        for _ in range(count):
            length = uint32()
            name = source.read(length).decode("utf-8").rstrip("\0")
            offset, size = uint64(), uint64()
            source.read(16)
            yield name, offset, size


def friendly_name(value: str) -> str:
    return value.replace("--", " · ").replace("_", " ").replace("-", " ").strip().title()


def main():
    entries = list(read_index())
    imported = {}
    for name, offset, size in entries:
        if not name.startswith("res://.import/") or not name.endswith(".oggstr"):
            continue
        match = re.match(r"(.+\.ogg)-[0-9a-f]{32}\.oggstr$", Path(name).name)
        if match:
            imported[match.group(1)] = (offset, size)

    manifest = {"ambientes": [], "efectos": [], "musica": []}
    seen = set()
    with PACK.open("rb") as source:
        for name, _, _ in entries:
            if not name.endswith(".ogg.import") or not name.startswith("res://data/"):
                continue
            filename = Path(name).name.removesuffix(".import")
            if filename not in imported or filename in seen:
                raise ValueError(f"Archivo de audio ausente o duplicado: {filename}")
            seen.add(filename)
            offset, size = imported[filename]
            source.seek(offset)
            packed = source.read(size)
            start = packed.find(b"OggS")
            if start < 0:
                raise ValueError(f"No se encontró el audio Ogg: {filename}")
            if "/music/" in name:
                group = name.split("/music/", 1)[1].split("/", 1)[0]
                folder = DESTINATION / "musica" / group
                collection = "musica"
            else:
                group = ""
                folder = DESTINATION / "sonidos"
                collection = "ambientes" if "Loop" in filename or "loop" in filename else "efectos"
            folder.mkdir(parents=True, exist_ok=True)
            target = folder / filename
            target.write_bytes(packed[start:])
            probe = subprocess.run(
                ["ffprobe", "-v", "error", "-show_entries", "stream=codec_name", "-of", "default=noprint_wrappers=1:nokey=1", str(target)],
                capture_output=True, text=True, check=True,
            )
            if "vorbis" not in probe.stdout:
                raise ValueError(f"El audio extraído no se pudo verificar: {filename}")
            manifest[collection].append({
                "id": target.stem,
                "nombre": friendly_name(target.stem),
                "grupo": group,
                "ruta": "/audio/" + target.relative_to(DESTINATION).as_posix(),
            })

    for collection in manifest.values():
        collection.sort(key=lambda item: (item["grupo"], item["nombre"]))
    (DESTINATION / "catalogo.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print({key: len(value) for key, value in manifest.items()})


if __name__ == "__main__":
    main()
