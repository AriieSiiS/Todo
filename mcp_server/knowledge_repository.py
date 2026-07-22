"""Repositorio documental local compartido por Todo y su servidor MCP.

SQLite y los recursos gestionados son la fuente de verdad. Este módulo no
depende de Flutter ni de Supabase y todas las operaciones de escritura usan
transacciones inmediatas para convivir con la aplicación de escritorio.
"""

from __future__ import annotations

import datetime as dt
import hashlib
import ipaddress
import json
import mimetypes
import os
import shutil
import socket
import sqlite3
import tempfile
import urllib.parse
import urllib.request
import uuid
import zipfile
from contextlib import closing
from pathlib import Path
from typing import Any, Iterable


def _now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def _id(prefix: str) -> str:
    return f"{prefix}-{uuid.uuid4()}"


def _json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def _document(text: str = "") -> dict[str, Any]:
    return {
        "document": {
            "type": "page",
            "children": [
                {
                    "type": "paragraph",
                    "data": {
                        "knowledgeBlockId": _id("block"),
                        "delta": [{"insert": text}],
                    },
                }
            ],
        }
    }


class KnowledgeLockedError(ValueError):
    pass


class KnowledgeRepository:
    def __init__(self, root: Path):
        self.root = root
        self.assets = root / "assets"
        self.backups = root / "backups"
        self.database_path = root / "knowledge.sqlite"
        self.root.mkdir(parents=True, exist_ok=True)
        self.assets.mkdir(parents=True, exist_ok=True)
        self.backups.mkdir(parents=True, exist_ok=True)
        self._initialize()

    def connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.database_path, timeout=5)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        connection.execute("PRAGMA busy_timeout = 5000")
        return connection

    def _initialize(self) -> None:
        with closing(self.connect()) as db, db:
            db.execute("PRAGMA journal_mode = WAL")
            db.executescript(
                """
                CREATE TABLE IF NOT EXISTS knowledge_meta (
                  key TEXT PRIMARY KEY, value TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS knowledge_pages (
                  id TEXT PRIMARY KEY,
                  parent_id TEXT REFERENCES knowledge_pages(id),
                  title TEXT NOT NULL,
                  icon TEXT,
                  cover_asset_id TEXT,
                  document_json TEXT NOT NULL,
                  collection_id TEXT,
                  properties_json TEXT NOT NULL DEFAULT '{}',
                  canonical_source TEXT,
                  canonical_id TEXT,
                  sort_order INTEGER NOT NULL DEFAULT 0,
                  is_trashed INTEGER NOT NULL DEFAULT 0,
                  deleted_at TEXT,
                  revision INTEGER NOT NULL DEFAULT 1,
                  created_at TEXT NOT NULL,
                  updated_at TEXT NOT NULL
                );
                CREATE UNIQUE INDEX IF NOT EXISTS knowledge_canonical_identity
                  ON knowledge_pages(canonical_source, canonical_id)
                  WHERE canonical_source IS NOT NULL AND canonical_id IS NOT NULL;
                CREATE TABLE IF NOT EXISTS knowledge_owner_links (
                  owner_type TEXT NOT NULL,
                  owner_id TEXT NOT NULL,
                  page_id TEXT NOT NULL REFERENCES knowledge_pages(id) ON DELETE CASCADE,
                  PRIMARY KEY(owner_type, owner_id), UNIQUE(page_id)
                );
                CREATE TABLE IF NOT EXISTS knowledge_assets (
                  id TEXT PRIMARY KEY, kind TEXT NOT NULL, mime_type TEXT NOT NULL,
                  relative_path TEXT NOT NULL, size INTEGER NOT NULL,
                  source_url TEXT, source_page_url TEXT, author TEXT, alt_text TEXT,
                  remote_status TEXT NOT NULL DEFAULT 'local', created_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS knowledge_collections (
                  id TEXT PRIMARY KEY,
                  page_id TEXT NOT NULL REFERENCES knowledge_pages(id) ON DELETE CASCADE,
                  name TEXT NOT NULL, schema_json TEXT NOT NULL, views_json TEXT NOT NULL,
                  created_at TEXT NOT NULL, updated_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS knowledge_links (
                  source_page_id TEXT NOT NULL REFERENCES knowledge_pages(id) ON DELETE CASCADE,
                  source_block_id TEXT NOT NULL,
                  target_page_id TEXT NOT NULL,
                  target_block_id TEXT,
                  PRIMARY KEY(source_page_id, source_block_id, target_page_id, target_block_id)
                );
                CREATE TABLE IF NOT EXISTS knowledge_revisions (
                  id TEXT PRIMARY KEY,
                  page_id TEXT NOT NULL REFERENCES knowledge_pages(id) ON DELETE CASCADE,
                  title TEXT NOT NULL, document_json TEXT NOT NULL,
                  properties_json TEXT NOT NULL, reason TEXT NOT NULL,
                  created_at TEXT NOT NULL
                );
                CREATE INDEX IF NOT EXISTS knowledge_revisions_page
                  ON knowledge_revisions(page_id, created_at DESC);
                CREATE TABLE IF NOT EXISTS knowledge_leases (
                  page_id TEXT PRIMARY KEY REFERENCES knowledge_pages(id) ON DELETE CASCADE,
                  holder TEXT NOT NULL, process_id INTEGER NOT NULL, expires_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS knowledge_tabs (
                  position INTEGER PRIMARY KEY,
                  page_id TEXT NOT NULL REFERENCES knowledge_pages(id) ON DELETE CASCADE,
                  pinned INTEGER NOT NULL DEFAULT 0,
                  back_history_json TEXT NOT NULL DEFAULT '[]',
                  forward_history_json TEXT NOT NULL DEFAULT '[]'
                );
                CREATE TABLE IF NOT EXISTS knowledge_operations (
                  operation_id TEXT PRIMARY KEY, result_json TEXT NOT NULL,
                  applied_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS knowledge_sync_queue (
                  id TEXT PRIMARY KEY, entity_type TEXT NOT NULL, entity_id TEXT NOT NULL,
                  operation TEXT NOT NULL, payload_json TEXT NOT NULL,
                  attempts INTEGER NOT NULL DEFAULT 0, next_attempt_at TEXT,
                  last_error TEXT, created_at TEXT NOT NULL
                );
                CREATE VIRTUAL TABLE IF NOT EXISTS knowledge_fts USING fts5(
                  page_id UNINDEXED, title, body, properties
                );
                """
            )
            db.execute(
                "INSERT OR REPLACE INTO knowledge_meta(key,value) VALUES('schema_version','1')"
            )

    @staticmethod
    def contract() -> dict[str, Any]:
        return {
            "schemaVersion": 1,
            "sourceOfTruth": "SQLite local + recursos locales",
            "documentFormat": "AppFlowy JSON con UUID estable en data.knowledgeBlockId",
            "page": {
                "required": ["title"],
                "optional": [
                    "pageId", "parentId", "document", "properties", "icon",
                    "coverAssetId", "canonicalSource", "canonicalId", "externalKey",
                ],
            },
            "managedContent": {
                "fields": ["managedKey", "externalKey", "generationHash", "manualOverride"],
                "rule": "Los bloques manuales o modificados manualmente se conservan.",
            },
            "link": {
                "attributes": ["knowledgeTargetPageId", "knowledgeTargetBlockId"],
                "stableBy": ["pageId", "blockId"],
            },
            "asset": {
                "required": ["path o url"],
                "provenance": ["sourceUrl", "sourcePageUrl", "author", "altText"],
            },
            "imageBlock": {
                "types": ["image", "knowledgeMedia"],
                "requiredAttributes": ["knowledgeAssetId", "knowledgeKind"],
                "layoutAttributes": {
                    "knowledgeImageWidth": "ancho en píxeles lógicos",
                    "knowledgeImageAlignment": "start | center | end",
                    "knowledgeImageCropAspectRatio": "ancho / alto; null conserva el original",
                    "knowledgeImageCropZoom": "1.0 a 4.0",
                    "knowledgeImageCropX": "punto de enfoque horizontal entre -1 y 1",
                    "knowledgeImageCropY": "punto de enfoque vertical entre -1 y 1",
                },
                "rule": "El recorte es no destructivo y conserva el recurso original.",
            },
        }

    def _page(self, row: sqlite3.Row) -> dict[str, Any]:
        return {
            "id": row["id"],
            "parentId": row["parent_id"],
            "title": row["title"],
            "icon": row["icon"],
            "coverAssetId": row["cover_asset_id"],
            "document": json.loads(row["document_json"]),
            "collectionId": row["collection_id"],
            "properties": json.loads(row["properties_json"]),
            "canonicalSource": row["canonical_source"],
            "canonicalId": row["canonical_id"],
            "sortOrder": row["sort_order"],
            "isTrashed": bool(row["is_trashed"]),
            "deletedAt": row["deleted_at"],
            "revision": row["revision"],
            "createdAt": row["created_at"],
            "updatedAt": row["updated_at"],
        }

    def list_pages(self, arguments: dict[str, Any]) -> dict[str, Any]:
        where = ["1=1"]
        values: list[Any] = []
        if not arguments.get("include_trashed", False):
            where.append("p.is_trashed=0")
        if "parent_id" in arguments:
            if arguments["parent_id"] is None:
                where.append("p.parent_id IS NULL")
            else:
                where.append("p.parent_id=?")
                values.append(arguments["parent_id"])
        join = ""
        if arguments.get("owner_type") and arguments.get("owner_id"):
            join = " JOIN knowledge_owner_links o ON o.page_id=p.id "
            where.extend(["o.owner_type=?", "o.owner_id=?"])
            values.extend([arguments["owner_type"], arguments["owner_id"]])
        with closing(self.connect()) as db, db:
            rows = db.execute(
                f"SELECT p.* FROM knowledge_pages p {join} WHERE {' AND '.join(where)} "
                "ORDER BY p.parent_id, p.sort_order, lower(p.title)",
                values,
            ).fetchall()
        pages = [self._page(row) for row in rows]
        return {"pages": pages, "count": len(pages)}

    def get_page(self, page_id: str) -> dict[str, Any]:
        with closing(self.connect()) as db, db:
            row = db.execute("SELECT * FROM knowledge_pages WHERE id=?", (page_id,)).fetchone()
            if row is None:
                raise ValueError(f"No existe la página {page_id}.")
            page = self._page(row)
            children = [
                self._page(item)
                for item in db.execute(
                    "SELECT * FROM knowledge_pages WHERE parent_id=? ORDER BY sort_order,title",
                    (page_id,),
                ).fetchall()
            ]
            backlinks = [
                dict(item)
                for item in db.execute(
                    "SELECT l.source_page_id AS pageId,p.title,l.source_block_id AS blockId "
                    "FROM knowledge_links l JOIN knowledge_pages p ON p.id=l.source_page_id "
                    "WHERE l.target_page_id=?",
                    (page_id,),
                ).fetchall()
            ]
            outgoing = [
                dict(item)
                for item in db.execute(
                    "SELECT l.target_page_id AS pageId,p.title,l.source_block_id AS sourceBlockId,"
                    "l.target_block_id AS blockId FROM knowledge_links l "
                    "JOIN knowledge_pages p ON p.id=l.target_page_id WHERE l.source_page_id=?",
                    (page_id,),
                ).fetchall()
            ]
            collections = [
                self._collection(item)
                for item in db.execute(
                    "SELECT * FROM knowledge_collections WHERE page_id=?", (page_id,)
                ).fetchall()
            ]
        return {"page": page, "children": children, "backlinks": backlinks,
                "outgoingLinks": outgoing, "collections": collections}

    def search(self, query: str, limit: int = 50) -> dict[str, Any]:
        tokens = [token for token in query.strip().split() if token]
        if not tokens:
            return {"results": [], "count": 0}
        expression = " AND ".join('"' + token.replace('"', '""') + '"' for token in tokens)
        with closing(self.connect()) as db, db:
            rows = db.execute(
                "SELECT p.*,snippet(knowledge_fts,2,'<mark>','</mark>','…',18) snippet "
                "FROM knowledge_fts JOIN knowledge_pages p ON p.id=knowledge_fts.page_id "
                "WHERE knowledge_fts MATCH ? AND p.is_trashed=0 LIMIT ?",
                (expression, max(1, min(limit, 200))),
            ).fetchall()
        results = [{"page": self._page(row), "snippet": row["snippet"]} for row in rows]
        return {"results": results, "count": len(results)}

    def create_page(self, arguments: dict[str, Any], db: sqlite3.Connection | None = None) -> dict[str, Any]:
        own = db is None
        connection = db or self.connect()
        try:
            page_id = arguments.get("page_id") or arguments.get("pageId") or _id("page")
            parent_id = arguments.get("parent_id", arguments.get("parentId"))
            if parent_id and connection.execute(
                "SELECT 1 FROM knowledge_pages WHERE id=? AND is_trashed=0", (parent_id,)
            ).fetchone() is None:
                raise ValueError(f"No existe la página padre {parent_id}.")
            existing = connection.execute("SELECT * FROM knowledge_pages WHERE id=?", (page_id,)).fetchone()
            if existing is not None:
                return self._page(existing)
            canonical_source = arguments.get("canonical_source", arguments.get("canonicalSource"))
            canonical_id = arguments.get("canonical_id", arguments.get("canonicalId"))
            if arguments.get("externalKey") and not canonical_id:
                canonical_source, canonical_id = "mcp", arguments["externalKey"]
            if canonical_source and canonical_id:
                found = connection.execute(
                    "SELECT * FROM knowledge_pages WHERE canonical_source=? AND canonical_id=?",
                    (canonical_source, canonical_id),
                ).fetchone()
                if found is not None:
                    return self._page(found)
            title = str(arguments.get("title") or "Sin título").strip() or "Sin título"
            document = arguments.get("document") or _document()
            properties = arguments.get("properties") or {}
            stamp = _now()
            connection.execute(
                "INSERT INTO knowledge_pages(id,parent_id,title,icon,cover_asset_id,document_json,"
                "collection_id,properties_json,canonical_source,canonical_id,sort_order,is_trashed,"
                "revision,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,0,1,?,?)",
                (page_id, parent_id, title, arguments.get("icon"),
                 arguments.get("cover_asset_id", arguments.get("coverAssetId")), _json(document),
                 arguments.get("collection_id", arguments.get("collectionId")), _json(properties),
                 canonical_source, canonical_id, int(arguments.get("sort_order", 0)), stamp, stamp),
            )
            owner_type = arguments.get("owner_type")
            owner_id = arguments.get("owner_id")
            if owner_type and owner_id:
                connection.execute(
                    "INSERT OR REPLACE INTO knowledge_owner_links(owner_type,owner_id,page_id) VALUES(?,?,?)",
                    (owner_type, owner_id, page_id),
                )
            row = connection.execute("SELECT * FROM knowledge_pages WHERE id=?", (page_id,)).fetchone()
            assert row is not None
            page = self._page(row)
            self._reindex(connection, page)
            if own:
                connection.commit()
            return page
        except Exception:
            if own:
                connection.rollback()
            raise
        finally:
            if own:
                connection.close()

    def update_page(self, page_id: str, arguments: dict[str, Any], *,
                    reason: str = "mcp", db: sqlite3.Connection | None = None,
                    lease_holder: str | None = None) -> dict[str, Any]:
        own = db is None
        connection = db or self.connect()
        try:
            self._assert_unlocked(connection, page_id, lease_holder)
            row = connection.execute("SELECT * FROM knowledge_pages WHERE id=?", (page_id,)).fetchone()
            if row is None:
                raise ValueError(f"No existe la página {page_id}.")
            old = self._page(row)
            self._checkpoint(connection, old, reason)
            document = arguments.get("document", old["document"])
            if arguments.get("managed_update", False):
                document = self._merge_managed(old["document"], document)
            title = str(arguments.get("title", old["title"])).strip() or "Sin título"
            properties = arguments.get("properties", old["properties"])
            connection.execute(
                "UPDATE knowledge_pages SET title=?,icon=?,cover_asset_id=?,document_json=?,"
                "properties_json=?,revision=revision+1,updated_at=? WHERE id=?",
                (title, arguments.get("icon", old["icon"]),
                 arguments.get("cover_asset_id", arguments.get("coverAssetId", old["coverAssetId"])),
                 _json(document), _json(properties), _now(), page_id),
            )
            updated_row = connection.execute(
                "SELECT * FROM knowledge_pages WHERE id=?", (page_id,)
            ).fetchone()
            assert updated_row is not None
            page = self._page(updated_row)
            self._reindex(connection, page)
            if own:
                connection.commit()
            return page
        except Exception:
            if own:
                connection.rollback()
            raise
        finally:
            if own:
                connection.close()

    def move_page(self, page_id: str, parent_id: str | None) -> dict[str, Any]:
        with closing(self.connect()) as db, db:
            db.execute("BEGIN IMMEDIATE")
            self._assert_unlocked(db, page_id)
            if page_id == parent_id or (parent_id and self._is_descendant(db, parent_id, page_id)):
                raise ValueError("El movimiento crearía un ciclo en el árbol de páginas.")
            if parent_id and db.execute("SELECT 1 FROM knowledge_pages WHERE id=?", (parent_id,)).fetchone() is None:
                raise ValueError(f"No existe la página padre {parent_id}.")
            db.execute("UPDATE knowledge_pages SET parent_id=?,updated_at=? WHERE id=?",
                       (parent_id, _now(), page_id))
            row = db.execute("SELECT * FROM knowledge_pages WHERE id=?", (page_id,)).fetchone()
            if row is None:
                raise ValueError(f"No existe la página {page_id}.")
            return self._page(row)

    def set_trash(self, page_id: str, trashed: bool) -> dict[str, Any]:
        with closing(self.connect()) as db, db:
            db.execute("BEGIN IMMEDIATE")
            ids = self._tree_ids(db, page_id)
            if not ids:
                raise ValueError(f"No existe la página {page_id}.")
            for item in ids:
                self._assert_unlocked(db, item)
            placeholders = ",".join("?" for _ in ids)
            deleted_at = _now() if trashed else None
            db.execute(
                f"UPDATE knowledge_pages SET is_trashed=?,deleted_at=?,updated_at=? WHERE id IN ({placeholders})",
                (int(trashed), deleted_at, _now(), *ids),
            )
        return {"pageId": page_id, "affectedPageIds": ids, "isTrashed": trashed}

    def backlinks(self, page_id: str) -> dict[str, Any]:
        return {"pageId": page_id, **{
            key: value for key, value in self.get_page(page_id).items()
            if key in {"backlinks", "outgoingLinks"}
        }}

    def list_unlinked(self) -> dict[str, Any]:
        with closing(self.connect()) as db, db:
            rows = db.execute(
                "SELECT p.* FROM knowledge_pages p WHERE p.is_trashed=0 AND NOT EXISTS "
                "(SELECT 1 FROM knowledge_links l WHERE l.source_page_id=p.id OR l.target_page_id=p.id) "
                "ORDER BY lower(p.title)"
            ).fetchall()
        pages = [self._page(row) for row in rows]
        return {"pages": pages, "count": len(pages)}

    def import_asset(self, arguments: dict[str, Any]) -> dict[str, Any]:
        source = arguments.get("path") or arguments.get("url")
        if not source:
            raise ValueError("Debes indicar path o url.")
        temporary: Path | None = None
        try:
            if arguments.get("url"):
                temporary = self._download(arguments["url"])
                path = temporary
            else:
                path = Path(source).expanduser().resolve()
                if not path.is_file():
                    raise ValueError(f"No existe el recurso local {path}.")
            if path.stat().st_size > 250 * 1024 * 1024:
                raise ValueError("El recurso supera el límite local de 250 MB.")
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            mime = arguments.get("mime_type") or mimetypes.guess_type(path.name)[0] or "application/octet-stream"
            extension = mimetypes.guess_extension(mime) or path.suffix or ".bin"
            relative = f"{digest[:2]}/{digest}{extension.lower()}"
            destination = self.assets / Path(relative)
            destination.parent.mkdir(parents=True, exist_ok=True)
            with closing(self.connect()) as db, db:
                existing = db.execute(
                    "SELECT * FROM knowledge_assets WHERE relative_path=?", (relative.replace("\\", "/"),)
                ).fetchone()
                if existing is not None:
                    return {"asset": dict(existing), "deduplicated": True}
                if not destination.exists():
                    shutil.copy2(path, destination)
                asset_id = _id("asset")
                kind = self._asset_kind(mime)
                db.execute(
                    "INSERT INTO knowledge_assets(id,kind,mime_type,relative_path,size,source_url,"
                    "source_page_url,author,alt_text,remote_status,created_at) VALUES(?,?,?,?,?,?,?,?,?,'local',?)",
                    (asset_id, kind, mime, relative.replace("\\", "/"), path.stat().st_size,
                     arguments.get("url") or arguments.get("source_url"), arguments.get("source_page_url"),
                     arguments.get("author"), arguments.get("alt_text"), _now()),
                )
                row = db.execute("SELECT * FROM knowledge_assets WHERE id=?", (asset_id,)).fetchone()
                assert row is not None
                return {"asset": dict(row), "deduplicated": False}
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)

    def create_collection(self, arguments: dict[str, Any], db: sqlite3.Connection | None = None) -> dict[str, Any]:
        own = db is None
        connection = db or self.connect()
        try:
            page_id = arguments.get("page_id", arguments.get("pageId"))
            if not page_id:
                raise ValueError("page_id es obligatorio.")
            if connection.execute("SELECT 1 FROM knowledge_pages WHERE id=?", (page_id,)).fetchone() is None:
                raise ValueError(f"No existe la página {page_id}.")
            collection_id = arguments.get("collection_id", arguments.get("id")) or _id("collection")
            stamp = _now()
            connection.execute(
                "INSERT INTO knowledge_collections(id,page_id,name,schema_json,views_json,created_at,updated_at) "
                "VALUES(?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name,"
                "schema_json=excluded.schema_json,views_json=excluded.views_json,updated_at=excluded.updated_at",
                (collection_id, page_id, arguments.get("name") or "Colección",
                 _json(arguments.get("schema") or []), _json(arguments.get("views") or []), stamp, stamp),
            )
            row = connection.execute(
                "SELECT * FROM knowledge_collections WHERE id=?", (collection_id,)
            ).fetchone()
            assert row is not None
            if own:
                connection.commit()
            return self._collection(row)
        except Exception:
            if own:
                connection.rollback()
            raise
        finally:
            if own:
                connection.close()

    def list_collections(self, page_id: str | None = None) -> dict[str, Any]:
        with closing(self.connect()) as db, db:
            if page_id:
                rows = db.execute("SELECT * FROM knowledge_collections WHERE page_id=?", (page_id,)).fetchall()
            else:
                rows = db.execute("SELECT * FROM knowledge_collections ORDER BY lower(name)").fetchall()
        collections = [self._collection(row) for row in rows]
        return {"collections": collections, "count": len(collections)}

    def apply_manifest(self, manifest: dict[str, Any]) -> dict[str, Any]:
        operation_id = manifest.get("operationId") or manifest.get("operation_id")
        if not operation_id:
            raise ValueError("operationId es obligatorio para garantizar idempotencia.")
        pages = manifest.get("pages")
        if not isinstance(pages, list) or not pages:
            raise ValueError("El manifiesto debe contener una lista no vacía de pages.")
        external_keys = [page.get("externalKey") for page in pages if page.get("externalKey")]
        if len(external_keys) != len(set(external_keys)):
            raise ValueError("Hay externalKey duplicadas en el manifiesto.")
        for page in pages:
            if not isinstance(page, dict) or not str(page.get("title") or "").strip():
                raise ValueError("Cada página necesita un título.")
            document = page.get("document")
            if document is not None and not isinstance(document, dict):
                raise ValueError("document debe ser un objeto JSON.")

        with closing(self.connect()) as db, db:
            previous = db.execute(
                "SELECT result_json FROM knowledge_operations WHERE operation_id=?", (operation_id,)
            ).fetchone()
            if previous is not None:
                result = json.loads(previous["result_json"])
                result["idempotentReplay"] = True
                return result
            db.execute("BEGIN IMMEDIATE")
            db.execute("DELETE FROM knowledge_leases WHERE expires_at<=?", (_now(),))
            affected = self._manifest_existing_ids(db, pages)
            self._assert_many_unlocked(db, affected)
            lease_holder = f"MCP:{operation_id}"
            lease_expiry = (
                dt.datetime.now(dt.timezone.utc) + dt.timedelta(minutes=2)
            ).isoformat()
            for page_id in affected:
                db.execute(
                    "INSERT INTO knowledge_leases(page_id,holder,process_id,expires_at) VALUES(?,?,?,?)",
                    (page_id, lease_holder, os.getpid(), lease_expiry),
                )
            db.commit()
            db.execute("BEGIN IMMEDIATE")
            resolved: dict[str, str] = {}
            created: list[str] = []
            updated: list[str] = []

            for raw in pages:
                external_key = raw.get("externalKey")
                row = None
                if external_key:
                    row = db.execute(
                        "SELECT * FROM knowledge_pages WHERE canonical_source='mcp' AND canonical_id=?",
                        (external_key,),
                    ).fetchone()
                if row is None and raw.get("pageId"):
                    row = db.execute("SELECT * FROM knowledge_pages WHERE id=?", (raw["pageId"],)).fetchone()
                if row is None:
                    page = self.create_page({**raw, "canonicalSource": "mcp" if external_key else raw.get("canonicalSource"),
                                             "canonicalId": external_key or raw.get("canonicalId")}, db=db)
                    created.append(page["id"])
                else:
                    page = self.update_page(
                        row["id"], {**raw, "managed_update": True},
                        reason=f"mcp-before:{operation_id}", db=db,
                        lease_holder=lease_holder,
                    )
                    updated.append(page["id"])
                if external_key:
                    resolved[external_key] = page["id"]

            for raw in pages:
                page_id = resolved.get(raw.get("externalKey")) or raw.get("pageId")
                parent_key = raw.get("parentExternalKey")
                parent_id = resolved.get(parent_key) if parent_key else raw.get("parentId")
                if page_id and parent_id:
                    if page_id == parent_id or self._is_descendant(db, parent_id, page_id):
                        raise ValueError("El manifiesto crearía un ciclo en el árbol.")
                    db.execute("UPDATE knowledge_pages SET parent_id=? WHERE id=?", (parent_id, page_id))

            for raw in manifest.get("collections", []):
                page_id = raw.get("pageId") or resolved.get(raw.get("pageExternalKey"))
                self.create_collection({**raw, "pageId": page_id}, db=db)

            result = {
                "operationId": operation_id,
                "createdPageIds": created,
                "updatedPageIds": updated,
                "resolvedExternalKeys": resolved,
                "idempotentReplay": False,
            }
            db.execute(
                "INSERT INTO knowledge_operations(operation_id,result_json,applied_at) VALUES(?,?,?)",
                (operation_id, _json(result), _now()),
            )
            db.execute("DELETE FROM knowledge_leases WHERE holder=?", (lease_holder,))
            return result

    def export_archive(self) -> dict[str, Any]:
        stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
        destination = self.backups / f"todo-knowledge-{stamp}.zip"
        pages = self.list_pages({"include_trashed": True})["pages"]
        collections = self.list_collections()["collections"]
        with closing(self.connect()) as db, db:
            assets = [dict(row) for row in db.execute("SELECT * FROM knowledge_assets").fetchall()]
        manifest = {"schemaVersion": 1, "exportedAt": _now(), "pages": pages,
                    "collections": collections, "assets": assets}
        with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED) as archive:
            archive.writestr("manifest.json", json.dumps(manifest, ensure_ascii=False, indent=2))
            for page in pages:
                frontmatter = _json({"id": page["id"], "parentId": page["parentId"],
                                     "properties": page["properties"]})
                archive.writestr(f"pages/{page['id']}.md", f"---\n{frontmatter}\n---\n\n# {page['title']}\n\n{self._plain_text(page['document'])}\n")
            for asset in assets:
                path = self.assets / Path(asset["relative_path"])
                if path.is_file():
                    archive.write(path, f"assets/{asset['relative_path']}")
        return {"path": str(destination), "pageCount": len(pages), "assetCount": len(assets)}

    def _collection(self, row: sqlite3.Row) -> dict[str, Any]:
        return {"id": row["id"], "pageId": row["page_id"], "name": row["name"],
                "schema": json.loads(row["schema_json"]), "views": json.loads(row["views_json"]),
                "createdAt": row["created_at"], "updatedAt": row["updated_at"]}

    def _assert_unlocked(
        self, db: sqlite3.Connection, page_id: str, holder: str | None = None
    ) -> None:
        db.execute("DELETE FROM knowledge_leases WHERE expires_at<=?", (_now(),))
        lease = db.execute("SELECT holder FROM knowledge_leases WHERE page_id=?", (page_id,)).fetchone()
        if lease is not None and lease["holder"] != holder:
            raise KnowledgeLockedError(
                f"La página {page_id} está siendo editada por {lease['holder']}; no se modificó nada."
            )

    def _assert_many_unlocked(self, db: sqlite3.Connection, page_ids: Iterable[str]) -> None:
        for page_id in page_ids:
            self._assert_unlocked(db, page_id)

    def _checkpoint(self, db: sqlite3.Connection, page: dict[str, Any], reason: str) -> None:
        db.execute(
            "INSERT INTO knowledge_revisions(id,page_id,title,document_json,properties_json,reason,created_at) "
            "VALUES(?,?,?,?,?,?,?)",
            (_id("revision"), page["id"], page["title"], _json(page["document"]),
             _json(page["properties"]), reason, _now()),
        )
        rows = db.execute(
            "SELECT id FROM knowledge_revisions WHERE page_id=? ORDER BY created_at DESC", (page["id"],)
        ).fetchall()
        for row in rows[50:]:
            db.execute("DELETE FROM knowledge_revisions WHERE id=?", (row["id"],))

    def _reindex(self, db: sqlite3.Connection, page: dict[str, Any]) -> None:
        db.execute("DELETE FROM knowledge_fts WHERE page_id=?", (page["id"],))
        db.execute(
            "INSERT INTO knowledge_fts(page_id,title,body,properties) VALUES(?,?,?,?)",
            (page["id"], page["title"], self._plain_text(page["document"]), _json(page["properties"])),
        )
        db.execute("DELETE FROM knowledge_links WHERE source_page_id=?", (page["id"],))
        for block_id, target_page_id, target_block_id in self._links(page["document"]):
            db.execute(
                "INSERT OR IGNORE INTO knowledge_links(source_page_id,source_block_id,target_page_id,target_block_id) "
                "VALUES(?,?,?,?)", (page["id"], block_id, target_page_id, target_block_id or ""),
            )

    def _links(self, value: Any) -> Iterable[tuple[str, str, str | None]]:
        if isinstance(value, dict):
            target = value.get("knowledgeTargetPageId") or value.get("targetPageId")
            if target:
                yield (str(value.get("knowledgeBlockId") or value.get("blockId") or _id("block")),
                       str(target), value.get("knowledgeTargetBlockId") or value.get("targetBlockId"))
            for child in value.values():
                yield from self._links(child)
        elif isinstance(value, list):
            for child in value:
                yield from self._links(child)

    def _plain_text(self, value: Any) -> str:
        result: list[str] = []
        def visit(item: Any) -> None:
            if isinstance(item, dict):
                insert = item.get("insert")
                if isinstance(insert, str):
                    result.append(insert)
                for child in item.values():
                    visit(child)
            elif isinstance(item, list):
                for child in item:
                    visit(child)
        visit(value)
        return " ".join(result)

    def _is_descendant(self, db: sqlite3.Connection, candidate: str, ancestor: str) -> bool:
        current: str | None = candidate
        seen: set[str] = set()
        while current and current not in seen:
            if current == ancestor:
                return True
            seen.add(current)
            row = db.execute("SELECT parent_id FROM knowledge_pages WHERE id=?", (current,)).fetchone()
            current = row["parent_id"] if row else None
        return False

    def _tree_ids(self, db: sqlite3.Connection, page_id: str) -> list[str]:
        rows = db.execute(
            "WITH RECURSIVE tree(id) AS (SELECT id FROM knowledge_pages WHERE id=? "
            "UNION ALL SELECT p.id FROM knowledge_pages p JOIN tree t ON p.parent_id=t.id) SELECT id FROM tree",
            (page_id,),
        ).fetchall()
        return [row["id"] for row in rows]

    def _manifest_existing_ids(self, db: sqlite3.Connection, pages: list[dict[str, Any]]) -> list[str]:
        result: list[str] = []
        for page in pages:
            row = None
            if page.get("externalKey"):
                row = db.execute(
                    "SELECT id FROM knowledge_pages WHERE canonical_source='mcp' AND canonical_id=?",
                    (page["externalKey"],),
                ).fetchone()
            if row is None and page.get("pageId"):
                row = db.execute("SELECT id FROM knowledge_pages WHERE id=?", (page["pageId"],)).fetchone()
            if row is not None:
                result.append(row["id"])
        return result

    def _merge_managed(self, old: dict[str, Any], incoming: dict[str, Any]) -> dict[str, Any]:
        existing: dict[str, dict[str, Any]] = {}
        def collect(value: Any) -> None:
            if isinstance(value, dict):
                key = value.get("managedKey") or (value.get("data") or {}).get("managedKey") if isinstance(value.get("data"), dict) else value.get("managedKey")
                if key:
                    existing[str(key)] = value
                for child in value.values():
                    collect(child)
            elif isinstance(value, list):
                for child in value:
                    collect(child)
        collect(old)

        def merge(value: Any) -> Any:
            if isinstance(value, dict):
                data = value.get("data") if isinstance(value.get("data"), dict) else {}
                key = value.get("managedKey") or data.get("managedKey")
                previous = existing.get(str(key)) if key else None
                if previous is not None and self._manually_changed(previous):
                    return previous
                return {name: merge(child) for name, child in value.items()}
            if isinstance(value, list):
                return [merge(child) for child in value]
            return value
        return merge(incoming)

    def _manually_changed(self, block: dict[str, Any]) -> bool:
        data = block.get("data") if isinstance(block.get("data"), dict) else block
        if data.get("manualOverride") is True:
            return True
        generation_hash = data.get("generationHash")
        if not generation_hash:
            return True
        comparable = json.loads(json.dumps(block))
        target = comparable.get("data") if isinstance(comparable.get("data"), dict) else comparable
        target.pop("generationHash", None)
        actual = hashlib.sha256(_json(comparable).encode("utf-8")).hexdigest()
        return actual != generation_hash

    def _asset_kind(self, mime: str) -> str:
        if mime.startswith("image/"):
            return "image"
        if mime.startswith("audio/"):
            return "audio"
        if mime.startswith("video/"):
            return "video"
        if mime == "application/pdf":
            return "pdf"
        return "file"

    def _download(self, url: str) -> Path:
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme != "https" or not parsed.hostname:
            raise ValueError("Solo se admiten recursos HTTPS.")
        for info in socket.getaddrinfo(parsed.hostname, parsed.port or 443):
            address = ipaddress.ip_address(info[4][0])
            if address.is_private or address.is_loopback or address.is_link_local or address.is_reserved:
                raise ValueError("La URL apunta a una red privada o no segura.")
        request = urllib.request.Request(url, headers={"User-Agent": "Todo-MCP/1.0"})
        with urllib.request.urlopen(request, timeout=20) as response:
            length = int(response.headers.get("Content-Length") or 0)
            if length > 250 * 1024 * 1024:
                raise ValueError("El recurso supera el límite local de 250 MB.")
            handle, name = tempfile.mkstemp(prefix="todo-knowledge-")
            total = 0
            with os.fdopen(handle, "wb") as output:
                while True:
                    chunk = response.read(1024 * 1024)
                    if not chunk:
                        break
                    total += len(chunk)
                    if total > 250 * 1024 * 1024:
                        raise ValueError("El recurso supera el límite local de 250 MB.")
                    output.write(chunk)
        return Path(name)
