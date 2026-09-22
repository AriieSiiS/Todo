import importlib
import json
import os
import struct
import sys
import tempfile
import unittest
import zlib
import binascii
from contextlib import closing
from pathlib import Path
from unittest.mock import patch


def transparent_png() -> bytes:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(
            ">I", binascii.crc32(kind + data) & 0xFFFFFFFF
        )

    header = struct.pack(">IIBBBBB", 2, 1, 8, 6, 0, 0, 0)
    pixels = bytes([0, 255, 0, 0, 255, 0, 0, 255, 0])
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(pixels))
        + chunk(b"IEND", b"")
    )


def opaque_png(width: int = 600, height: int = 700) -> bytes:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(
            ">I", binascii.crc32(kind + data) & 0xFFFFFFFF
        )

    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    row = bytes([0]) + bytes([40, 50, 60, 255]) * width
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(row * height))
        + chunk(b"IEND", b"")
    )


class McpServerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        root = Path(self.temp_dir.name)
        os.environ["TODO_MCP_STATE_PATH"] = str(root / "state.json")
        os.environ["TODO_MCP_PREFS_PATH"] = str(root / "prefs.json")
        os.environ["TODO_MCP_DISABLE_REMOTE"] = "1"
        os.environ["TODO_MCP_WARDROBE_PATH"] = str(root / "wardrobe")
        os.environ["TODO_MCP_HOUSEHOLD_PATH"] = str(root / "household")
        os.environ["TODO_MCP_RECIPE_PATH"] = str(root / "recipes")
        os.environ["TODO_MCP_PLANTS_PATH"] = str(root / "plants")
        os.environ["TODO_MCP_KNOWLEDGE_PATH"] = str(root / "knowledge")
        sys.path.insert(0, str(Path(__file__).resolve().parent))

        import server

        self.server = importlib.reload(server)

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def call(self, name: str, arguments: dict | None = None) -> dict:
        result = self.server.handle_tool_call(name, arguments or {})
        return json.loads(result["content"][0]["text"])

    def test_tool_list_contains_full_surface(self) -> None:
        names = {tool["name"] for tool in self.server.tool_definitions()}
        expected = {
            "delete_task",
            "reopen_task",
            "bulk_complete_tasks",
            "bulk_reopen_tasks",
            "bulk_delete_tasks",
            "bulk_move_tasks_to_day",
            "reorder_tasks",
            "create_subtask",
            "set_task_reminder",
            "clear_task_reminder",
            "update_project",
            "set_project_status",
            "complete_project",
            "cancel_project",
            "delete_project",
            "update_category",
            "toggle_category",
            "delete_category",
            "list_notes",
            "create_note",
            "update_note",
            "archive_note",
            "convert_note_to_task",
            "convert_note_to_project",
            "convert_note_to_calendar_event",
            "list_calendar_events",
            "refresh_calendar_events",
            "import_calendar_events_as_tasks",
            "sync_task_to_calendar",
            "link_task_to_calendar_event",
            "unlink_task_from_calendar_event",
            "disconnect_calendar",
            "get_settings",
            "update_day_settings",
            "update_notification_settings",
            "update_calendar_settings",
            "set_today_sort",
            "reorder_navigation",
            "sync_with_cloud",
            "disconnect_cloud",
            "duplicate_expense",
            "expense_totals",
            "export_financial_json",
            "export_financial_csv",
            "create_library_item",
            "update_library_item",
            "delete_library_item",
            "delete_library_goal",
            "toggle_library_goal_completed",
            "toggle_library_goal_favorite",
            "get_wardrobe_import_contract",
            "stage_wardrobe_batch",
            "list_wardrobe_batches",
            "get_wardrobe_batch",
            "list_wardrobe_items",
            "import_wardrobe_item",
            "set_wardrobe_item_image",
            "create_wardrobe_item",
            "update_wardrobe_item",
            "delete_wardrobe_item",
            "list_wardrobe_outfits",
            "create_wardrobe_outfit",
            "update_wardrobe_outfit",
            "set_wardrobe_outfit_render",
            "record_wardrobe_wear",
            "set_wardrobe_laundry_status",
            "set_wardrobe_plan",
            "create_wardrobe_packing_list",
            "add_wardrobe_packing_item",
            "list_household_items",
            "create_household_item",
            "update_household_item",
            "set_household_item_image",
            "set_household_item_document",
            "delete_household_item",
            "get_plant_contract",
            "list_plants",
            "create_plant",
            "update_plant",
            "set_plant_image",
            "delete_plant",
            "list_recipes",
            "create_recipe",
            "update_recipe",
            "set_recipe_image",
            "create_recipe_task",
            "delete_recipe",
            "list_weekly_menus",
            "create_weekly_menu_task",
            "get_knowledge_contract",
            "list_knowledge_pages",
            "get_knowledge_page",
            "search_knowledge",
            "create_knowledge_page",
            "update_knowledge_page",
            "move_knowledge_page",
            "trash_knowledge_page",
            "restore_knowledge_page",
            "list_knowledge_backlinks",
            "import_knowledge_asset",
            "create_knowledge_collection",
            "apply_knowledge_manifest",
            "export_knowledge_repository",
        }
        self.assertTrue(expected.issubset(names), expected - names)

    def test_legacy_visual_field_is_removed_from_local_state(self) -> None:
        state = self.server.default_state()
        state["schemaVersion"] = 7
        state["visualMode"] = "phantom"
        self.server.STATE_PATH.write_text(
            json.dumps(state, ensure_ascii=False),
            encoding="utf-8",
        )

        loaded = self.call("get_app_state")
        persisted = json.loads(self.server.STATE_PATH.read_text(encoding="utf-8"))

        self.assertEqual(loaded["schemaVersion"], 11)
        self.assertNotIn("visualMode", loaded)
        self.assertNotIn("visualMode", persisted)

    def test_task_reminders_accumulate_and_can_be_removed_individually(self) -> None:
        task = self.call(
            "create_task",
            {
                "title": "Fisio",
                "scheduled_at": "2026-09-14T18:55:00",
                "reminder_minutes_before_values": [0, 5, 15],
            },
        )["created"]
        self.assertEqual(
            [rule["minutesBefore"] for rule in task["reminderRules"]],
            [0, 5, 15],
        )
        self.assertTrue(
            all(rule["deliveryMode"] == "normal" for rule in task["reminderRules"])
        )

        updated = self.call(
            "set_task_reminder",
            {"task_id": task["id"], "reminder_minutes_before": 30},
        )["updated"]
        self.assertEqual(
            [rule["minutesBefore"] for rule in updated["reminderRules"]],
            [0, 5, 15, 30],
        )

        deduplicated = self.call(
            "set_task_reminder",
            {"task_id": task["id"], "reminder_minutes_before": 5},
        )["updated"]
        self.assertEqual(
            [rule["minutesBefore"] for rule in deduplicated["reminderRules"]],
            [0, 5, 15, 30],
        )

        important = self.call(
            "set_task_reminder",
            {
                "task_id": task["id"],
                "reminder_minutes_before": 5,
                "reminder_delivery_mode": "important",
            },
        )["updated"]
        five_minute_rules = [
            rule for rule in important["reminderRules"] if rule["minutesBefore"] == 5
        ]
        self.assertEqual(len(five_minute_rules), 1)
        self.assertEqual(five_minute_rules[0]["deliveryMode"], "important")

        without_five = self.call(
            "clear_task_reminder",
            {"task_id": task["id"], "reminder_minutes_before": 5},
        )["updated"]
        self.assertEqual(
            [rule["minutesBefore"] for rule in without_five["reminderRules"]],
            [0, 15, 30],
        )

        cleared = self.call("clear_task_reminder", {"task_id": task["id"]})[
            "updated"
        ]
        self.assertEqual(cleared["reminderRules"], [])
        self.assertIsNone(cleared["reminderRule"])

    def test_version_8_reminders_migrate_to_delivery_modes(self) -> None:
        state = self.server.default_state()
        state["schemaVersion"] = 8
        state["tasks"] = [
            {
                "id": "horno",
                "title": "Horno",
                "reminderRules": [
                    {"minutesBefore": 5, "enabled": True},
                    {
                        "minutesBefore": 0,
                        "enabled": True,
                        "deliveryMode": "important",
                    },
                ],
                "reminderRule": {"minutesBefore": 5, "enabled": True},
            }
        ]
        self.server.STATE_PATH.write_text(json.dumps(state), encoding="utf-8")

        loaded = self.call("get_app_state")
        rules = loaded["tasks"][0]["reminderRules"]
        self.assertEqual(loaded["schemaVersion"], 11)
        self.assertEqual(
            {rule["minutesBefore"]: rule["deliveryMode"] for rule in rules},
            {0: "important", 5: "normal"},
        )

    def test_local_knowledge_pages_search_links_collections_and_trash(self) -> None:
        contract = self.call("get_knowledge_contract")
        self.assertEqual(contract["schemaVersion"], 3)
        self.assertIn("image", contract["imageBlock"]["types"])
        self.assertIn(
            "knowledgeImageCropAspectRatio",
            contract["imageBlock"]["layoutAttributes"],
        )
        root = self.call(
            "create_knowledge_page",
            {"title": "Película", "externalKey": "film:1"},
        )["page"]
        child = self.call(
            "create_knowledge_page",
            {"title": "Actores", "parent_id": root["id"]},
        )["page"]
        self.call(
            "update_knowledge_page",
            {
                "page_id": root["id"],
                "document": {
                    "document": {
                        "type": "page",
                        "children": [
                            {
                                "type": "paragraph",
                                "data": {
                                    "knowledgeBlockId": "block-link",
                                    "targetPageId": child["id"],
                                    "delta": [{"insert": "Reparto principal"}],
                                },
                            }
                        ],
                    }
                },
            },
        )
        search = self.call("search_knowledge", {"query": "Reparto"})
        self.assertEqual(search["count"], 1)
        links = self.call("list_knowledge_backlinks", {"page_id": child["id"]})
        self.assertEqual(links["backlinks"][0]["pageId"], root["id"])
        collection = self.call(
            "create_knowledge_collection",
            {
                "page_id": child["id"],
                "name": "Actores",
                "schema": [{"key": "papel", "type": "text"}],
                "views": [{"type": "gallery", "name": "Galería"}],
            },
        )["collection"]
        self.assertEqual(collection["name"], "Actores")
        with self.assertRaises(ValueError):
            self.call(
                "move_knowledge_page",
                {"page_id": root["id"], "parent_id": child["id"]},
            )
        trashed = self.call("trash_knowledge_page", {"page_id": root["id"]})
        self.assertEqual(len(trashed["affectedPageIds"]), 2)
        self.call("restore_knowledge_page", {"page_id": root["id"]})
        self.assertEqual(self.call("list_knowledge_pages")["count"], 2)

    def test_knowledge_manifest_is_atomic_locked_and_idempotent(self) -> None:
        root = self.call(
            "create_knowledge_page",
            {"title": "Juego", "externalKey": "game:root"},
        )["page"]
        repository = self.server.knowledge_repository()
        with closing(repository.connect()) as db, db:
            db.execute(
                "INSERT INTO knowledge_leases(page_id,holder,process_id,expires_at) VALUES(?,?,?,?)",
                (root["id"], "Flutter-test", 1, "2999-01-01T00:00:00+00:00"),
            )
        manifest = {
            "operationId": "guide-1",
            "pages": [
                {"externalKey": "game:root", "title": "Guía de logros"},
                {
                    "externalKey": "achievement:one",
                    "parentExternalKey": "game:root",
                    "title": "Primer logro",
                },
            ],
        }
        with self.assertRaises(ValueError):
            self.call("apply_knowledge_manifest", {"manifest": manifest})
        self.assertEqual(self.call("list_knowledge_pages")["count"], 1)
        with closing(repository.connect()) as db, db:
            db.execute("DELETE FROM knowledge_leases")
        first = self.call("apply_knowledge_manifest", {"manifest": manifest})
        second = self.call("apply_knowledge_manifest", {"manifest": manifest})
        self.assertFalse(first["idempotentReplay"])
        self.assertTrue(second["idempotentReplay"])
        self.assertEqual(self.call("list_knowledge_pages")["count"], 2)
        exported = self.call("export_knowledge_repository")
        self.assertTrue(Path(exported["path"]).is_file())
        self.assertEqual(Path(exported["path"]).name, "conocimiento-actual.zip")
        self.call("export_knowledge_repository")
        backups = list((Path(self.temp_dir.name) / "knowledge" / "backups").glob("*.zip"))
        self.assertEqual(len(backups), 1)

    def test_dangerous_operations_require_confirmation(self) -> None:
        with self.assertRaises(ValueError):
            self.call("reset_state")
        with self.assertRaises(ValueError):
            self.call("import_state", {"raw_json": "{}"})

    def test_tasks_projects_categories_and_notes_flow(self) -> None:
        self.call("reset_state", {"confirm": True})
        category = self.call("create_category", {"name": "Casa"})["created"]
        project = self.call("create_project", {"name": "Mudanza", "category_ids": [category["id"]]})["created"]
        task = self.call(
            "create_task",
            {
                "title": "Ordenar cajas",
                "category_ids": [category["id"]],
                "project_ids": [project["id"]],
                "scheduled_at": "2026-05-09T10:00:00",
            },
        )["created"]
        subtask = self.call("create_subtask", {"parent_task_id": task["id"], "title": "Libros"})["created"]
        self.call("set_task_reminder", {"task_id": task["id"], "reminder_minutes_before": 15})
        self.call("bulk_complete_tasks", {"task_ids": [task["id"], subtask["id"]]})
        self.call("bulk_reopen_tasks", {"task_ids": [task["id"]]})
        self.call("reorder_tasks", {"ordered_ids": [task["id"], subtask["id"]]})
        self.call("update_project", {"project_id": project["id"], "status": "paused"})
        self.call("toggle_category", {"category_id": category["id"]})

        note = self.call("create_note", {"content": "Comprar cinta"})["created"]
        converted = self.call("convert_note_to_task", {"note_id": note["id"]})["created"]
        self.assertEqual(converted["origin"], "note")
        self.assertEqual(self.call("list_notes", {"status": "converted"})["count"], 1)

    def test_expenses_library_calendar_and_settings_flow(self) -> None:
        self.call("reset_state", {"confirm": True})
        self.call("update_day_settings", {"day_ends_at_hour": 4, "next_day_visible_at_hour": 9})
        self.call("update_notification_settings", {"default_minutes_before_task": 20})
        self.call("set_today_sort", {"today_sort": "priority"})
        self.call("reorder_navigation", {"sections": ["today", "library", "expenses"]})

        expense_category = self.call("create_expense_category", {"name": "Casa"})["created"]
        payment_method = self.call("create_payment_method", {"name": "Tarjeta"})["created"]
        expense = self.call(
            "create_expense",
            {
                "date": "2026-05-09",
                "concept": "Compra",
                "amount": 12.5,
                "category_id": expense_category["id"],
                "payment_method_id": payment_method["id"],
            },
        )["created"]
        self.call("duplicate_expense", {"expense_id": expense["id"]})
        self.assertEqual(self.call("expense_totals")["count"], 2)
        self.assertIn("expenses", self.call("export_financial_json"))
        self.assertIn("csv", self.call("export_financial_csv"))

        goal = self.call(
            "create_library_goal",
            {"type": "book", "title": "Circe", "target_year": 2026, "author": "Madeline Miller"},
        )["created"]
        toggled = self.call("toggle_library_goal_completed", {"goal_id": goal["id"]})
        self.assertIsNotNone(toggled["synced_item"])
        item_from_goal = toggled["synced_item"]
        updated_item = self.call(
            "update_library_item",
            {"item_id": item_from_goal["id"], "title": "Circe editado", "author": "M. Miller"},
        )
        self.assertEqual(updated_item["synced_goal"]["title"], "Circe editado")
        updated_goal = self.call(
            "update_library_goal",
            {"goal_id": goal["id"], "new_title": "Circe final", "author": "Madeline Miller"},
        )
        self.assertEqual(updated_goal["synced_item"]["title"], "Circe final")
        item = self.call("create_library_item", {"type": "game", "title": "Prey", "platform": "PC"})["created"]
        self.call("update_library_item", {"item_id": item["id"], "rating": 9})

        collection_item = self.call(
            "create_library_item",
            {
                "type": "book",
                "title": "Carl el mazmorrero",
                "collection_name": "Carl el mazmorrero",
                "collection_number": 1,
                "show_collection_number": True,
            },
        )["created"]
        self.assertEqual(collection_item["collectionName"], "Carl el mazmorrero")
        self.assertEqual(collection_item["collectionNumber"], 1)
        self.assertTrue(collection_item["showCollectionNumber"])
        collection_item = self.call(
            "update_library_item",
            {"item_id": collection_item["id"], "clear_collection_number": True},
        )["updated"]
        self.assertIsNone(collection_item["collectionNumber"])
        self.assertFalse(collection_item["showCollectionNumber"])

        note = self.call("create_note", {"content": "Evento"})["created"]
        event = self.call(
            "convert_note_to_calendar_event",
            {
                "note_id": note["id"],
                "start_at": "2026-05-09T12:00:00",
                "end_at": "2026-05-09T13:00:00",
            },
        )["created"]
        self.assertEqual(self.call("list_calendar_events")["count"], 1)
        self.call("import_calendar_events_as_tasks", {"from": "2026-05-09T00:00:00", "to": "2026-05-10T00:00:00"})
        task = self.call("create_task", {"title": "Sync me"})["created"]
        self.call("update_calendar_settings", {"connected": True, "selected_calendar_id": "primary"})
        self.call("sync_task_to_calendar", {"task_id": task["id"]})
        self.call("link_task_to_calendar_event", {"task_id": task["id"], "calendar_id": "primary", "event_id": event["id"]})
        self.call("unlink_task_from_calendar_event", {"task_id": task["id"]})

    def test_library_statuses_and_goal_links(self) -> None:
        self.call("reset_state", {"confirm": True})

        pending = self.call(
            "create_library_item",
            {"type": "game", "title": "Control", "status": "pending"},
        )["created"]
        self.assertEqual(pending["status"], "pending")
        self.assertIsNone(pending["completedDate"])
        self.assertEqual(
            self.call("list_library_items", {"status": "pending"})["count"],
            1,
        )

        in_progress = self.call(
            "update_library_item",
            {"item_id": pending["id"], "status": "inProgress"},
        )["updated"]
        self.assertEqual(in_progress["status"], "inProgress")
        self.assertIsNone(in_progress["completedDate"])

        goal_result = self.call(
            "create_library_goal",
            {"type": "book", "title": "Piranesi", "target_year": 2026},
        )
        goal = goal_result["created"]
        goal_item = goal_result["synced_item"]
        self.assertEqual(goal_item["status"], "pending")
        self.assertEqual(goal["linkedLibraryItemId"], goal_item["id"])

        completed = self.call(
            "toggle_library_goal_completed", {"goal_id": goal["id"]}
        )["synced_item"]
        self.assertEqual(completed["id"], goal_item["id"])
        self.assertEqual(completed["status"], "completed")
        self.assertIsNotNone(completed["completedDate"])

        reopened = self.call(
            "toggle_library_goal_completed", {"goal_id": goal["id"]}
        )["synced_item"]
        self.assertEqual(reopened["id"], goal_item["id"])
        self.assertEqual(reopened["status"], "pending")
        self.assertIsNone(reopened["completedDate"])

        self.call("delete_library_goal", {"goal_id": goal["id"], "confirm": True})
        kept = self.call("list_library_items", {"type": "book"})["items"]
        self.assertEqual(len(kept), 1)
        self.assertIsNone(kept[0]["linkedGoalId"])

        linked = self.call(
            "create_library_goal",
            {"type": "book", "title": "Circe", "target_year": 2026},
        )
        deleted = self.call(
            "delete_library_item",
            {"item_id": linked["synced_item"]["id"], "confirm": True},
        )
        self.assertEqual(deleted["replacement"]["status"], "pending")
        self.assertNotEqual(
            deleted["replacement"]["id"], linked["synced_item"]["id"]
        )

    def test_wardrobe_crud_and_management_flow(self) -> None:
        self.call("reset_state", {"confirm": True})
        shirt = self.call("create_wardrobe_item", {"name": "Camisa", "category": "Camisas"})
        trousers = self.call("create_wardrobe_item", {"name": "Pantalón", "category": "Pantalones"})
        outfit = self.call("create_wardrobe_outfit", {
            "name": "Oficina", "item_ids": [shirt["id"], trousers["id"]], "occasion": "trabajo"
        })
        render = Path(self.temp_dir.name) / "outfit.png"
        render.write_bytes(opaque_png())
        outfit = self.call("set_wardrobe_outfit_render", {
            "outfit_id": outfit["id"], "source_file": str(render)
        })
        render_path = outfit["renderImagePath"]
        outfit = self.call("update_wardrobe_outfit", {
            "outfit_id": outfit["id"], "name": "Oficina informal",
            "occasion": "oficina", "tags": ["cómodo"]
        })
        self.call("record_wardrobe_wear", {
            "date": "2026-07-15", "item_ids": outfit["itemIds"], "outfit_id": outfit["id"]
        })
        self.call("set_wardrobe_laundry_status", {"item_ids": [shirt["id"]], "status": "toWash"})
        self.call("set_wardrobe_plan", {"date": "2026-07-16", "item_ids": outfit["itemIds"], "weather": "mild"})
        packing = self.call("create_wardrobe_packing_list", {
            "name": "Viaje", "start_date": "2026-07-18", "end_date": "2026-07-20"
        })
        packing = self.call("add_wardrobe_packing_item", {
            "packing_list_id": packing["id"], "item_id": trousers["id"], "quantity": 2
        })

        items = self.call("list_wardrobe_items")
        outfits = self.call("list_wardrobe_outfits")
        self.assertEqual(len(items), 2)
        self.assertEqual(outfit["name"], "Oficina informal")
        self.assertEqual(outfit["renderImagePath"], render_path)
        self.assertEqual(outfits[0]["renderImagePath"], outfit["renderImagePath"])
        self.assertTrue((Path(self.temp_dir.name) / "wardrobe" / outfit["renderImagePath"]).is_file())
        self.assertEqual(next(item for item in items if item["id"] == shirt["id"])["useCount"], 1)
        self.assertEqual(packing["entries"][0]["quantity"], 2)

    def test_stage_wardrobe_batch_validates_transparency_and_paths(self) -> None:
        self.call("reset_state", {"confirm": True})
        source = Path(self.temp_dir.name) / "batch"
        source.mkdir()
        (source / "camisa.png").write_bytes(transparent_png())
        (source / "manifest.json").write_text(json.dumps({
            "version": 1,
            "batchId": "lote-test",
            "name": "Lote de prueba",
            "items": [{
                "id": "camisa", "file": "camisa.png", "name": "Camisa azul", "category": "Camisas"
            }],
        }), encoding="utf-8")

        batch = self.call("stage_wardrobe_batch", {"source_directory": str(source)})

        self.assertEqual(batch["status"], "pending")
        self.assertEqual(batch["items"][0]["errors"], [])
        self.assertEqual(len(self.call("list_wardrobe_batches", {"status": "pending"})), 1)
        with self.assertRaises(ValueError):
            self.call("stage_wardrobe_batch", {
                "source_directory": str(source),
                "manifest_path": str(Path(self.temp_dir.name) / "outside.json"),
            })

    def test_import_wardrobe_item_is_direct_canonical_and_idempotent(self) -> None:
        self.call("reset_state", {"confirm": True})
        image = Path(self.temp_dir.name) / "camiseta.png"
        image.write_bytes(transparent_png())
        arguments = {
            "request_id": "peticion-camiseta-1",
            "source_file": str(image),
            "name": "Camiseta de prueba",
            "category": "t-shirt",
            "colors": ["burdeos", "azul marino"],
            "seasons": ["verano"],
            "occasions": ["diario"],
            "tags": ["retro"],
        }

        first = self.call("import_wardrobe_item", arguments)
        second = self.call("import_wardrobe_item", arguments)

        self.assertTrue(first["savedLocally"])
        self.assertEqual(first["item"]["category"], "Camisetas")
        self.assertEqual(first["item"]["colors"], ["granate", "azul marino"])
        self.assertEqual(second["item"]["id"], first["item"]["id"])
        self.assertEqual(len(self.server.read_local_state()["wardrobeItems"]), 1)
        root = Path(self.temp_dir.name) / "wardrobe"
        self.assertTrue((root / first["item"]["imagePath"]).is_file())
        self.assertTrue((root / first["item"]["thumbnailPath"]).is_file())
        metadata = json.loads(
            (Path(self.temp_dir.name) / "sync_metadata.json").read_text(encoding="utf-8")
        )
        self.assertTrue(metadata["pendingLocalChanges"])

    def test_set_wardrobe_item_image_preserves_the_complete_record(self) -> None:
        self.call("reset_state", {"confirm": True})
        item = self.call("create_wardrobe_item", {
            "name": "Zapatos de prueba",
            "category": "Calzado",
            "colors": ["negro"],
            "material": "Cuero",
            "seasons": ["todo el año"],
            "occasions": ["trabajo"],
            "tags": ["cordones"],
            "favorite": True,
        })
        root = Path(self.temp_dir.name) / "wardrobe"
        old_image = root / "items" / "anterior.png"
        old_thumbnail = root / "thumbnails" / "anterior.png"
        old_image.parent.mkdir(parents=True, exist_ok=True)
        old_thumbnail.parent.mkdir(parents=True, exist_ok=True)
        old_image.write_bytes(transparent_png())
        old_thumbnail.write_bytes(transparent_png())
        state = self.server.read_local_state()
        state["wardrobeItems"][0].update({
            "imagePath": "items/anterior.png",
            "thumbnailPath": "thumbnails/anterior.png",
            "imageSha256": "anterior",
            "useCount": 7,
            "lastUsedAt": "2026-09-14T18:00:00+00:00",
        })
        state["wardrobeOutfits"] = [{
            "id": "conjunto-1",
            "name": "Trabajo",
            "itemIds": [item["id"]],
            "occasion": "trabajo",
            "tags": [],
            "renderImagePath": "",
            "createdAt": "2026-09-14T18:00:00+00:00",
        }]
        self.server.write_local_state(state)
        replacement = Path(self.temp_dir.name) / "reemplazo.png"
        replacement.write_bytes(transparent_png())
        arguments = {
            "item_id": item["id"],
            "source_file": str(replacement),
            "request_id": "reemplazo-calzado-1",
        }

        first = self.call("set_wardrobe_item_image", arguments)
        second = self.call("set_wardrobe_item_image", arguments)

        self.assertTrue(first["savedLocally"])
        self.assertEqual(second, first)
        stored = self.server.read_local_state()["wardrobeItems"][0]
        self.assertEqual(stored["id"], item["id"])
        self.assertEqual(stored["name"], "Zapatos de prueba")
        self.assertEqual(stored["colors"], ["negro"])
        self.assertEqual(stored["material"], "Cuero")
        self.assertEqual(stored["useCount"], 7)
        self.assertEqual(stored["lastUsedAt"], "2026-09-14T18:00:00+00:00")
        self.assertEqual(
            self.server.read_local_state()["wardrobeOutfits"][0]["itemIds"],
            [item["id"]],
        )
        self.assertTrue((root / stored["imagePath"]).is_file())
        self.assertTrue((root / stored["thumbnailPath"]).is_file())
        self.assertFalse(old_image.exists())
        self.assertFalse(old_thumbnail.exists())

    def test_set_wardrobe_item_image_rolls_back_new_assets_on_save_failure(self) -> None:
        self.call("reset_state", {"confirm": True})
        item = self.call("create_wardrobe_item", {
            "name": "Zapatos de prueba",
            "category": "Calzado",
        })
        root = Path(self.temp_dir.name) / "wardrobe"
        old_image = root / "items" / "anterior.png"
        old_thumbnail = root / "thumbnails" / "anterior.png"
        old_image.parent.mkdir(parents=True, exist_ok=True)
        old_thumbnail.parent.mkdir(parents=True, exist_ok=True)
        old_image.write_bytes(transparent_png())
        old_thumbnail.write_bytes(transparent_png())
        state = self.server.read_local_state()
        state["wardrobeItems"][0].update({
            "imagePath": "items/anterior.png",
            "thumbnailPath": "thumbnails/anterior.png",
            "imageSha256": "anterior",
        })
        self.server.write_local_state(state)
        replacement = Path(self.temp_dir.name) / "reemplazo.png"
        replacement.write_bytes(transparent_png())

        with patch.object(
            self.server,
            "write_local_state",
            side_effect=OSError("fallo simulado"),
        ):
            with self.assertRaises(OSError):
                self.call("set_wardrobe_item_image", {
                    "item_id": item["id"],
                    "source_file": str(replacement),
                    "request_id": "reemplazo-calzado-fallido",
                })

        self.assertTrue(old_image.is_file())
        self.assertTrue(old_thumbnail.is_file())
        self.assertEqual(
            sorted(path.name for path in (root / "items").iterdir()),
            ["anterior.png"],
        )

    def test_household_crud_saves_catalog_image_manual_and_invoice(self) -> None:
        self.call("reset_state", {"confirm": True})
        item = self.call("create_household_item", {
            "name": "Lavadora",
            "category": "Electrodomésticos",
            "brand": "Bosch",
            "model": "WGG244Z0ES",
            "serial_number": "FD-1234",
            "purchase_date": "2026-08-30",
            "warranty_until": "2029-08-30",
            "price": 699.0,
        })
        image = Path(self.temp_dir.name) / "lavadora.png"
        manual = Path(self.temp_dir.name) / "manual.pdf"
        invoice = Path(self.temp_dir.name) / "factura.pdf"
        image.write_bytes(opaque_png(700, 700))
        manual.write_bytes(b"%PDF-1.4\nmanual oficial")
        invoice.write_bytes(b"%PDF-1.4\nfactura")

        item = self.call("set_household_item_image", {
            "item_id": item["id"], "source_file": str(image)
        })
        item = self.call("set_household_item_document", {
            "item_id": item["id"], "kind": "manual",
            "source_file": str(manual),
            "source_url": "https://example.com/manual.pdf",
        })
        item = self.call("set_household_item_document", {
            "item_id": item["id"], "kind": "invoice",
            "source_file": str(invoice),
        })

        stored = self.call("list_household_items")[0]
        root = Path(self.temp_dir.name) / "household"
        self.assertEqual(stored["model"], "WGG244Z0ES")
        self.assertEqual(stored["manualSourceUrl"], "https://example.com/manual.pdf")
        self.assertTrue((root / item["imagePath"]).is_file())
        self.assertTrue((root / item["thumbnailPath"]).is_file())
        self.assertTrue((root / item["manualPath"]).is_file())
        self.assertTrue((root / item["invoicePath"]).is_file())

    def test_plant_crud_is_idempotent_and_preserves_personal_task_settings(self) -> None:
        self.call("reset_state", {"confirm": True})
        routine = {
            "id": "care-calathea-water",
            "type": "watering",
            "title": "Comprobar el sustrato y regar Calatea",
            "instructions": "Regar solo cuando se seque la capa superior.",
            "firstDueDate": "2026-09-22",
            "recurrence": {
                "type": "everyXDays",
                "interval": 7,
                "weekdays": [],
                "activeMonths": [],
            },
            "enabled": True,
        }
        arguments = {
            "request_id": "plant-calathea-01",
            "name": "Calatea del salón",
            "scientific_name": "Goeppertia orbifolia",
            "location": "Salón",
            "cat_safety": "nonToxic",
            "cat_safety_notes": "No tóxica para gatos según ASPCA.",
            "sources": [{"title": "ASPCA", "url": "https://example.com/aspca"}],
            "routines": [routine],
        }
        first = self.call("create_plant", arguments)
        repeated = self.call("create_plant", arguments)

        self.assertTrue(first["savedLocally"])
        self.assertEqual(first["plant"]["id"], repeated["plant"]["id"])
        state = self.server.load_state()
        self.assertEqual(len(state["plants"]), 1)
        self.assertEqual(
            len([category for category in state["categories"]
                 if category["name"].casefold() == "plantas"]),
            1,
        )
        self.assertEqual(len(state["tasks"]), 1)

        task_id = state["tasks"][0]["id"]
        state["tasks"][0]["scheduledAt"] = "2026-09-22T18:30:00"
        state["tasks"][0]["reminderRules"] = [
            {"minutesBefore": 15, "enabled": True, "deliveryMode": "normal"}
        ]
        self.server.save_state(state)
        updated_routine = dict(routine)
        updated_routine["instructions"] = "Comprobar la humedad antes de regar."
        updated_routine["recurrence"] = {
            "type": "monthly", "interval": 2, "weekdays": [],
            "activeMonths": [4, 5, 6, 7, 8, 9],
        }
        self.call("update_plant", {
            "plant_id": first["plant"]["id"],
            "routines": [updated_routine],
        })
        task = self.server.load_state()["tasks"][0]
        self.assertEqual(task["id"], task_id)
        self.assertEqual(task["scheduledAt"], "2026-09-22T18:30:00")
        self.assertEqual(task["reminderRules"][0]["minutesBefore"], 15)
        self.assertEqual(task["recurrence"]["type"], "monthly")
        self.assertEqual(task["recurrence"]["activeMonths"], [4, 5, 6, 7, 8, 9])

        image = Path(self.temp_dir.name) / "calatea.png"
        image.write_bytes(opaque_png(640, 640))
        with_image = self.call("set_plant_image", {
            "plant_id": first["plant"]["id"],
            "source_file": str(image),
            "request_id": "plant-calathea-image-01",
        })
        self.assertTrue(with_image["savedLocally"])
        self.assertTrue(
            (Path(self.temp_dir.name) / "plants" / with_image["plant"]["imagePath"]).is_file()
        )

        self.call("update_plant", {
            "plant_id": first["plant"]["id"], "archived": True,
        })
        self.assertEqual(self.server.load_state()["tasks"][0]["status"], "archived")
        deleted = self.call("delete_plant", {
            "plant_id": first["plant"]["id"], "confirm": True,
        })
        self.assertTrue(deleted["deleted"])
        self.assertTrue(deleted["savedLocally"])
        final_state = self.server.load_state()
        self.assertEqual(final_state["plants"], [])
        self.assertEqual(final_state["tasks"], [])

    def test_plant_migration_removes_only_the_reserved_example(self) -> None:
        state = self.server.default_state()
        state["schemaVersion"] = 10
        state["plants"] = [
            {"id": "plant-example-spider", "name": "Cinta de ejemplo"},
            {"id": "plant-real", "name": "Planta real"},
        ]
        state["tasks"] = [
            {"id": "task-example", "sourcePlantId": "plant-example-spider"},
            {"id": "task-real", "sourcePlantId": "plant-real"},
        ]
        self.server.write_local_state(state)

        migrated = self.call("get_app_state")

        self.assertEqual(migrated["schemaVersion"], 11)
        self.assertEqual([plant["id"] for plant in migrated["plants"]], ["plant-real"])
        self.assertEqual([task["id"] for task in migrated["tasks"]], ["task-real"])
        self.assertEqual(
            len([category for category in migrated["categories"]
                 if category["name"].casefold() == "plantas"]),
            1,
        )

    def test_recipe_crud_image_and_task_integration(self) -> None:
        self.call("reset_state", {"confirm": True})
        recipe = self.call("create_recipe", {
            "title": "Ropa vieja canaria",
            "category": "Plato principal",
            "cuisine": "Canaria",
            "servings": 4,
            "prep_minutes": 20,
            "cook_minutes": 45,
            "ingredients": [
                "500 g de garbanzos",
                "300 g de carne",
                "1/2 cucharadita de comino",
                "Un trocito de jengibre y cúrcuma",
                "Sal y pimienta al gusto",
            ],
            "instructions": ["Prepara el sofrito.", "Añade el resto y cocina."],
            "tags": ["tradicional"],
        })
        image = Path(self.temp_dir.name) / "ropa-vieja.png"
        image.write_bytes(opaque_png(800, 500))

        recipe = self.call("set_recipe_image", {
            "recipe_id": recipe["id"], "source_file": str(image)
        })
        task = self.call("create_recipe_task", {
            "recipe_id": recipe["id"], "kind": "shopping"
        })

        stored = self.call("list_recipes")[0]
        root = Path(self.temp_dir.name) / "recipes"
        self.assertEqual(stored["cuisine"], "Canaria")
        self.assertEqual(len(stored["ingredients"]), 5)
        self.assertEqual(stored["ingredients"][0]["kind"], "ingredient")
        self.assertEqual(stored["ingredients"][2]["kind"], "condiment")
        self.assertTrue((root / recipe["imagePath"]).is_file())
        self.assertTrue((root / recipe["thumbnailPath"]).is_file())
        self.assertEqual(
            [subtask["title"] for subtask in task["subtasks"]],
            [
                "500 g de garbanzos",
                "300 g de carne",
                "Comino",
                "Jengibre",
                "Cúrcuma",
                "Sal",
                "Pimienta",
            ],
        )
        self.assertEqual(task["task"]["title"], "Comprar ingredientes para Ropa vieja canaria")

    def test_weekly_menu_list_and_shopping_task(self) -> None:
        self.call("reset_state", {"confirm": True})
        state = self.server.load_state()
        state["recipes"] = [
            {
                "id": "recipe-salmon",
                "title": "Bowl de salmón",
                "ingredients": [
                    {"text": "500 g de salmón", "group": "", "kind": "ingredient"},
                    {"text": "1/2 cucharadita de sal", "group": "", "kind": "condiment"},
                ],
            },
            {
                "id": "recipe-aguacate",
                "title": "Ensalada de aguacate",
                "ingredients": [
                    {"text": "2 aguacates", "group": "", "kind": "ingredient"},
                ],
            },
        ]
        state["weeklyMenus"] = [{
            "id": "weekly-menu-01",
            "title": "Menú semanal 01",
            "people": 1,
            "totalPriceCents": 2200,
            "recipeIds": ["recipe-salmon", "recipe-aguacate"],
            "mealEntries": [
                {"id": "meal-1", "day": "monday", "mealType": "lunch", "recipeId": "recipe-salmon"},
                {"id": "meal-2", "day": "tuesday", "mealType": "dinner", "recipeId": "recipe-aguacate"},
            ],
            "shoppingItems": [
                {"name": "Salmón", "group": "Proteínas", "priceCents": 540},
                {"name": "Aguacate", "group": "Frutas y verduras", "priceCents": 88},
            ],
            "archived": False,
        }]
        self.server.save_state(state)

        menus = self.call("list_weekly_menus")
        task = self.call("create_weekly_menu_task", {"menu_id": "weekly-menu-01"})
        partial = self.call("create_weekly_menu_task", {
            "menu_id": "weekly-menu-01", "entry_ids": ["meal-1"]
        })

        self.assertEqual(len(menus), 1)
        self.assertEqual(task["task"]["title"], "Comprar Menú semanal 01")
        self.assertEqual(
            [subtask["title"] for subtask in task["subtasks"]],
            ["Salmón", "Aguacate"],
        )
        self.assertEqual(partial["task"]["title"], "Comprar selección de Menú semanal 01")
        self.assertEqual(
            [subtask["title"] for subtask in partial["subtasks"]],
            ["500 g de salmón", "Sal"],
        )


if __name__ == "__main__":
    unittest.main()
