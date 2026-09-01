"""Pruebas de contrato del MCP de Biblioteca sin depender de Flutter."""

from __future__ import annotations

import base64
import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from mcp_server.knowledge_repository import KnowledgeRepository


def managed_paragraph(text: str, key: str, **extra: object) -> dict[str, object]:
    node: dict[str, object] = {
        "type": "paragraph",
        "data": {
            "delta": [{"insert": text}],
            "managedKey": key,
            **extra,
        },
    }
    comparable = json.loads(json.dumps(node))
    data = comparable["data"]
    data.pop("generationHash", None)
    node["data"]["generationHash"] = hashlib.sha256(
        json.dumps(
            comparable,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
    ).hexdigest()
    return node


def document(*children: dict[str, object]) -> dict[str, object]:
    return {"document": {"type": "page", "children": list(children)}}


class KnowledgeRepositoryContractTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="todo-knowledge-mcp-")
        self.root = Path(self.temporary.name)
        self.repository = KnowledgeRepository(self.root)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_manifest_links_assets_collections_and_idempotency(self) -> None:
        png = self.root / "source.png"
        png.write_bytes(
            base64.b64decode(
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
            )
        )
        manifest = {
            "operationId": "contract-v1",
            "assets": [{"externalKey": "asset:icon", "path": str(png)}],
            "pages": [
                {
                    "externalKey": "page:root",
                    "title": "Raíz",
                    "document": document(
                        managed_paragraph(
                            "Abrir ficha",
                            "root-link",
                            knowledgeTargetExternalKey="page:child",
                            knowledgeAssetExternalKey="asset:icon",
                        )
                    ),
                    "coverAssetExternalKey": "asset:icon",
                },
                {
                    "externalKey": "page:child",
                    "title": "Ficha",
                    "parentExternalKey": "page:root",
                    "document": document(managed_paragraph("Contenido", "child")),
                },
            ],
            "collections": [
                {
                    "externalKey": "collection:cards",
                    "pageExternalKey": "page:root",
                    "name": "Fichas",
                }
            ],
        }
        first = self.repository.apply_manifest(manifest)
        replay = self.repository.apply_manifest(manifest)
        root_id = first["resolvedExternalKeys"]["page:root"]
        root = self.repository.get_page(root_id)["page"]
        raw = json.dumps(root["document"])

        self.assertIn("knowledgeTargetPageId", raw)
        self.assertIn("knowledgeAssetId", raw)
        self.assertNotIn("knowledgeTargetExternalKey", raw)
        self.assertEqual(root["coverAssetId"], first["resolvedAssetExternalKeys"]["asset:icon"])
        self.assertTrue(replay["idempotentReplay"])
        self.assertEqual(self.repository.list_collections()["count"], 1)

    def test_exact_progress_replacement_preserves_manual_entries(self) -> None:
        page = self.repository.create_page({"title": "Isaac"})
        root_id = page["id"]
        self.repository.set_progress(
            {"rootPageId": root_id, "key": "manual.step", "value": True}
        )
        self.repository.replace_progress(
            {
                "rootPageId": root_id,
                "source": "isaac-save",
                "entries": [
                    {"key": "achievement.1", "value": True},
                    {"key": "challenge.1", "value": True},
                ],
            }
        )
        self.repository.replace_progress(
            {
                "rootPageId": root_id,
                "source": "isaac-save",
                "entries": [{"key": "achievement.1", "value": False}],
            }
        )
        entries = self.repository.list_progress({"rootPageId": root_id})["entries"]
        values = {entry["key"]: entry["value"] for entry in entries}
        self.assertEqual(values, {"achievement.1": False, "manual.step": True})

    def test_manual_block_survives_regeneration_and_failure_rolls_back(self) -> None:
        initial = {
            "operationId": "manual-v1",
            "pages": [
                {
                    "externalKey": "page:managed",
                    "title": "Gestionada",
                    "document": document(managed_paragraph("Editorial", "body")),
                }
            ],
        }
        result = self.repository.apply_manifest(initial)
        page_id = result["resolvedExternalKeys"]["page:managed"]
        page = self.repository.get_page(page_id)["page"]
        page["document"]["document"]["children"][0]["data"]["delta"] = [
            {"insert": "Cambio manual"}
        ]
        self.repository.update_page(page_id, {"document": page["document"]})
        self.assertIn(
            "Cambio manual",
            json.dumps(self.repository.get_page(page_id)["page"]["document"]),
        )
        manual_block = self.repository.get_page(page_id)["page"]["document"][
            "document"
        ]["children"][0]
        self.assertTrue(self.repository._manually_changed(manual_block))

        regenerated = {
            "operationId": "manual-v2",
            "pages": [
                {
                    "externalKey": "page:managed",
                    "title": "Gestionada",
                    "document": document(managed_paragraph("Editorial nueva", "body")),
                }
            ],
        }
        merged = self.repository._merge_managed(
            self.repository.get_page(page_id)["page"]["document"],
            regenerated["pages"][0]["document"],
        )
        self.assertIn("Cambio manual", json.dumps(merged))
        self.assertEqual(
            merged["document"]["children"][0]["type"],
            "paragraph",
        )
        self.repository.apply_manifest(regenerated)
        updated = self.repository.get_page(page_id)["page"]
        self.assertIn("Cambio manual", json.dumps(updated["document"]))
        self.assertEqual(
            updated["document"]["document"]["children"][0]["type"],
            "paragraph",
        )

        count_before = self.repository.list_pages({})["count"]
        with self.assertRaises(ValueError):
            self.repository.apply_manifest(
                {
                    "operationId": "rollback-v1",
                    "pages": [
                        {
                            "externalKey": "page:must-rollback",
                            "title": "No persistir",
                            "document": document(
                                managed_paragraph(
                                    "Roto",
                                    "broken",
                                    knowledgeTargetExternalKey="page:missing",
                                )
                            ),
                        }
                    ],
                }
            )
        self.assertEqual(self.repository.list_pages({})["count"], count_before)


if __name__ == "__main__":
    unittest.main()
