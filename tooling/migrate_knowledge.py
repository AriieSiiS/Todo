"""Crea de forma idempotente las raíces documentales de Biblioteca.

Se usa durante el despliegue para migrar los datos reales sin abrir Todo.
Nunca modifica el snapshot ni las portadas originales.
"""

from __future__ import annotations

import argparse
import json
import sys
from contextlib import closing
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "mcp_server"))

from knowledge_repository import KnowledgeRepository  # noqa: E402


def initial_document(note: str | None) -> dict[str, Any]:
    children: list[dict[str, Any]] = []
    if note and note.strip():
        children.extend(
            [
                {
                    "type": "heading",
                    "data": {
                        "level": 2,
                        "knowledgeBlockId": "legacy-note-heading",
                        "delta": [{"insert": "Nota anterior"}],
                    },
                },
                {
                    "type": "paragraph",
                    "data": {
                        "knowledgeBlockId": "legacy-note-body",
                        "delta": [{"insert": note.strip()}],
                    },
                },
            ]
        )
    children.append(
        {
            "type": "paragraph",
            "data": {
                "knowledgeBlockId": "initial-empty-block",
                "delta": [{"insert": ""}],
            },
        }
    )
    return {"document": {"type": "page", "children": children}}


def migrate(snapshot_path: Path, knowledge_root: Path) -> dict[str, Any]:
    raw = json.loads(snapshot_path.read_text(encoding="utf-8"))
    items = raw.get("libraryItems")
    if not isinstance(items, list):
        raise ValueError("El snapshot no contiene libraryItems.")
    repository = KnowledgeRepository(knowledge_root)
    before = repository.list_pages({"include_trashed": True})["count"]
    created = 0
    imported_covers = 0

    for item in items:
        item_id = str(item.get("id") or "").strip()
        if not item_id:
            raise ValueError("Hay un elemento de Biblioteca sin id.")
        with closing(repository.connect()) as db, db:
            existing = db.execute(
                "SELECT page_id FROM knowledge_owner_links WHERE owner_type='libraryItem' AND owner_id=?",
                (item_id,),
            ).fetchone()
        if existing is not None:
            continue

        cover_asset_id = None
        cover = item.get("coverUrl")
        if isinstance(cover, str) and cover.strip():
            cover_path = Path(cover)
            if cover_path.is_file():
                imported = repository.import_asset(
                    {"path": str(cover_path), "alt_text": str(item.get("title") or "")}
                )
                cover_asset_id = imported["asset"]["id"]
                imported_covers += int(not imported["deduplicated"])

        repository.create_page(
            {
                "title": str(item.get("title") or "Sin título"),
                "document": initial_document(item.get("note")),
                "cover_asset_id": cover_asset_id,
                "owner_type": "libraryItem",
                "owner_id": item_id,
            }
        )
        created += 1

    after = repository.list_pages({"include_trashed": True})["count"]
    with closing(repository.connect()) as db, db:
        linked = db.execute(
            "SELECT count(*) amount FROM knowledge_owner_links WHERE owner_type='libraryItem'"
        ).fetchone()["amount"]
        seeded = db.execute(
            "SELECT value FROM knowledge_meta WHERE key='initial_backup_queue_seeded'"
        ).fetchone()
        queued = 0
        if seeded is None:
            for row in db.execute("SELECT * FROM knowledge_pages").fetchall():
                page = repository._page(row)
                db.execute(
                    "INSERT OR IGNORE INTO knowledge_sync_queue(id,entity_type,entity_id,operation,payload_json,created_at) "
                    "VALUES(?, 'page', ?, 'upsert', ?, ?)",
                    (
                        f"migration-page-{page['id']}",
                        page["id"],
                        json.dumps(page, ensure_ascii=False),
                        page["updatedAt"],
                    ),
                )
                queued += 1
            for asset in db.execute("SELECT * FROM knowledge_assets").fetchall():
                db.execute(
                    "INSERT OR IGNORE INTO knowledge_sync_queue(id,entity_type,entity_id,operation,payload_json,created_at) "
                    "VALUES(?, 'asset', ?, 'upsert', ?, ?)",
                    (
                        f"migration-asset-{asset['id']}",
                        asset["id"],
                        json.dumps({"id": asset["id"]}),
                        asset["created_at"],
                    ),
                )
                queued += 1
            db.execute(
                "INSERT INTO knowledge_meta(key,value) VALUES('initial_backup_queue_seeded','1')"
            )
    return {
        "schemaVersion": 1,
        "libraryItems": len(items),
        "pagesBefore": before,
        "pagesAfter": after,
        "created": created,
        "importedCovers": imported_covers,
        "linkedLibraryItems": linked,
        "queuedForOptionalBackup": queued,
        "idempotent": created == 0,
        "knowledgeRoot": str(knowledge_root.resolve()),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("snapshot", type=Path)
    parser.add_argument("knowledge_root", type=Path)
    arguments = parser.parse_args()
    if not arguments.snapshot.is_file():
        parser.error("No existe el snapshot indicado.")
    result = migrate(arguments.snapshot, arguments.knowledge_root)
    print(json.dumps(result, ensure_ascii=False))
    if result["linkedLibraryItems"] != result["libraryItems"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
