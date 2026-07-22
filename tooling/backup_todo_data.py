"""Copia recuperable del snapshot, portadas y repositorio documental."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path
from typing import Any


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("snapshot", type=Path)
    parser.add_argument("knowledge_root", type=Path)
    parser.add_argument("destination", type=Path)
    arguments = parser.parse_args()
    if not arguments.snapshot.is_file():
        parser.error("No existe el snapshot.")
    if arguments.destination.exists() and any(arguments.destination.iterdir()):
        parser.error("La carpeta de destino ya existe y no está vacía.")

    arguments.destination.mkdir(parents=True, exist_ok=True)
    snapshot_copy = arguments.destination / "todo_state.json"
    shutil.copy2(arguments.snapshot, snapshot_copy)
    state = json.loads(arguments.snapshot.read_text(encoding="utf-8"))
    covers_directory = arguments.destination / "library_covers"
    covers_directory.mkdir(parents=True, exist_ok=True)
    cover_manifest: list[dict[str, Any]] = []
    copied_hashes: set[str] = set()
    for item in state.get("libraryItems", []):
        source_value = item.get("coverUrl")
        if not isinstance(source_value, str):
            continue
        source = Path(source_value)
        if not source.is_file():
            continue
        digest = sha256(source)
        suffix = source.suffix.lower() if len(source.suffix) <= 10 else ".bin"
        relative = Path("library_covers") / f"{digest}{suffix}"
        if digest not in copied_hashes:
            shutil.copy2(source, arguments.destination / relative)
            copied_hashes.add(digest)
        cover_manifest.append(
            {
                "libraryItemId": item.get("id"),
                "originalPath": str(source),
                "backupPath": relative.as_posix(),
                "sha256": digest,
                "size": source.stat().st_size,
            }
        )

    knowledge_copy = arguments.destination / "knowledge"
    knowledge_files: list[dict[str, Any]] = []
    if arguments.knowledge_root.is_dir():
        shutil.copytree(arguments.knowledge_root, knowledge_copy, dirs_exist_ok=True)
        for path in knowledge_copy.rglob("*"):
            if path.is_file():
                knowledge_files.append(
                    {
                        "path": path.relative_to(arguments.destination).as_posix(),
                        "sha256": sha256(path),
                        "size": path.stat().st_size,
                    }
                )

    manifest = {
        "snapshot": {
            "path": "todo_state.json",
            "sha256": sha256(snapshot_copy),
            "size": snapshot_copy.stat().st_size,
        },
        "libraryItems": len(state.get("libraryItems", [])),
        "coversReferenced": len(cover_manifest),
        "coversCopied": len(copied_hashes),
        "covers": cover_manifest,
        "knowledgeFiles": knowledge_files,
    }
    (arguments.destination / "backup_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps({key: manifest[key] for key in (
        "snapshot", "libraryItems", "coversReferenced", "coversCopied"
    )}, ensure_ascii=False))


if __name__ == "__main__":
    main()
