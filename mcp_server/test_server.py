import importlib
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path


class McpServerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        root = Path(self.temp_dir.name)
        os.environ["TODO_MCP_STATE_PATH"] = str(root / "state.json")
        os.environ["TODO_MCP_PREFS_PATH"] = str(root / "prefs.json")
        os.environ["TODO_MCP_DISABLE_REMOTE"] = "1"
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
            "set_visual_mode",
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
        }
        self.assertTrue(expected.issubset(names), expected - names)

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
        self.call("set_visual_mode", {"visual_mode": "phantom"})
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
        item = self.call("create_library_item", {"type": "game", "title": "Prey", "platform": "PC"})["created"]
        self.call("update_library_item", {"item_id": item["id"], "rating": 9})

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


if __name__ == "__main__":
    unittest.main()
