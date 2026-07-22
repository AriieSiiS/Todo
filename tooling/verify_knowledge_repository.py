"""Audita la migración documental sin modificar los datos instalados."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from contextlib import closing
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "mcp_server"))

from knowledge_repository import KnowledgeRepository  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("snapshot", type=Path)
    parser.add_argument("knowledge_root", type=Path)
    parser.add_argument("--export", action="store_true")
    arguments = parser.parse_args()
    state = json.loads(arguments.snapshot.read_text(encoding="utf-8"))
    items = state.get("libraryItems", [])
    repository = KnowledgeRepository(arguments.knowledge_root)
    missing_assets: list[str] = []
    invalid_assets: list[str] = []
    missing_notes: list[str] = []
    missing_note_details: list[dict[str, str]] = []
    with closing(repository.connect()) as db, db:
        integrity = db.execute("PRAGMA integrity_check").fetchone()[0]
        journal_mode = db.execute("PRAGMA journal_mode").fetchone()[0]
        schema_version = db.execute(
            "SELECT value FROM knowledge_meta WHERE key='schema_version'"
        ).fetchone()[0]
        page_count = db.execute("SELECT count(*) FROM knowledge_pages").fetchone()[0]
        link_count = db.execute(
            "SELECT count(*) FROM knowledge_owner_links WHERE owner_type='libraryItem'"
        ).fetchone()[0]
        fts_count = db.execute("SELECT count(*) FROM knowledge_fts").fetchone()[0]
        assets = db.execute("SELECT * FROM knowledge_assets").fetchall()
        for asset in assets:
            path = arguments.knowledge_root / "assets" / asset["relative_path"]
            if not path.is_file():
                missing_assets.append(asset["id"])
                continue
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            if digest not in path.name:
                invalid_assets.append(asset["id"])
        for item in items:
            note = item.get("note")
            if not isinstance(note, str) or not note.strip():
                continue
            row = db.execute(
                "SELECT p.document_json FROM knowledge_pages p "
                "JOIN knowledge_owner_links o ON o.page_id=p.id "
                "WHERE o.owner_type='libraryItem' AND o.owner_id=?",
                (item["id"],),
            ).fetchone()
            document = None if row is None else json.loads(row["document_json"])
            document_text = "" if document is None else repository._plain_text(document)
            if note.strip() not in document_text:
                missing_notes.append(item["id"])
                missing_note_details.append(
                    {
                        "id": item["id"],
                        "expected": note.strip(),
                        "document": "" if row is None else row["document_json"],
                    }
                )

    result = {
        "integrity": integrity,
        "journalMode": journal_mode,
        "schemaVersion": schema_version,
        "libraryItems": len(items),
        "pages": page_count,
        "ownerLinks": link_count,
        "ftsRows": fts_count,
        "assets": len(assets),
        "missingAssets": missing_assets,
        "invalidAssetHashes": invalid_assets,
        "missingLegacyNotes": missing_notes,
        "missingLegacyNoteDetails": missing_note_details,
    }
    if arguments.export:
        result["export"] = repository.export_archive()
    print(json.dumps(result, ensure_ascii=False))
    valid = (
        integrity == "ok"
        and str(journal_mode).lower() == "wal"
        and str(schema_version) == "1"
        and page_count == len(items)
        and link_count == len(items)
        and fts_count == page_count
        and not missing_assets
        and not invalid_assets
        and not missing_notes
    )
    if not valid:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
