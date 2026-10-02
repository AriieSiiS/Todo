"""Pruebas de aislamiento y conexión real por stdio con el SDK oficial."""

from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
os.environ["TODO_MCP_DISABLE_REMOTE"] = "1"

try:
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client
    MCP_AVAILABLE = True
except ModuleNotFoundError as error:
    if error.name != "mcp":
        raise
    MCP_AVAILABLE = False

from chatgpt_adapter import LocalBackend, tool_definitions
import server as core


class BackendTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="todo-chatgpt-")
        self.root = Path(self.temporary.name)
        self.state_path = self.root / "datos con espacio" / "estado.json"
        self.state_path.parent.mkdir()
        state = core.default_state()
        state["tasks"] = [{"id": "task-ejemplo", "title": "Revisar el balcón", "status": "active", "scheduledAt": "2026-01-01T12:00:00", "categoryIds": [], "projectIds": []}]
        state["calendarSettings"]["desktopClientSecret"] = "secreto-de-prueba"
        self.state_path.write_text(json.dumps(state, ensure_ascii=False), encoding="utf-8")
        self.backend = LocalBackend(self.state_path)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_reads_leave_snapshot_preferences_and_core_unchanged(self) -> None:
        before = self.state_path.read_bytes()
        modified = self.state_path.stat().st_mtime_ns
        original_load = core.load_state
        preferences = self.root / "preferencias.json"
        preferences.write_text('{"ajuste": "conservar"}', encoding="utf-8")
        with patch.object(core, "APP_PREFS_PATH", preferences), patch.object(core, "write_local_state", side_effect=AssertionError("Escritura no permitida")), patch.object(core, "write_app_snapshot", side_effect=AssertionError("Preferencias no permitidas")), patch.object(core, "remote_request", side_effect=AssertionError("Red no permitida")):
            for name in ("get_today", "list_tasks", "list_projects", "list_categories"):
                payload = self.backend.call(name, {})
                self.assertNotIn("secreto-de-prueba", json.dumps(payload))
            task = self.backend.call("get_task", {"task_id": "task-ejemplo"})
            self.assertEqual(task["task"]["title"], "Revisar el balcón")
        self.assertEqual(self.state_path.read_bytes(), before)
        self.assertEqual(self.state_path.stat().st_mtime_ns, modified)
        self.assertEqual(preferences.read_text(encoding="utf-8"), '{"ajuste": "conservar"}')
        self.assertIs(core.load_state, original_load)

    def test_missing_empty_and_invalid_snapshots_never_get_reset(self) -> None:
        missing = self.root / "ausente" / "estado.json"
        with self.assertRaises(ValueError):
            LocalBackend(missing).call("list_tasks", {})
        self.assertFalse(missing.parent.exists())
        for content in (b"", b"{", b"[]", b'{}', b'{"tasks": [1], "projects": [], "categories": []}', b"\xff"):
            with self.subTest(content=content):
                self.state_path.write_bytes(content)
                with self.assertRaises(ValueError):
                    self.backend.call("list_tasks", {})
                self.assertEqual(self.state_path.read_bytes(), content)

    def test_real_writes_and_unlisted_tools_are_blocked(self) -> None:
        before = self.state_path.read_bytes()
        for name in ("create_task", "update_task", "complete_task", "reset_state", "export_state", "get_app_state", "sync_with_cloud"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                self.backend.call(name, {"title": "No guardar"})
        self.assertEqual(self.state_path.read_bytes(), before)

    def test_sandbox_writes_do_not_read_or_modify_real_files(self) -> None:
        before = self.state_path.read_bytes()
        backend = LocalBackend(self.state_path, sandbox=True)
        with patch.object(Path, "read_text", side_effect=AssertionError("Lectura no permitida")), patch.object(core, "remote_request", side_effect=AssertionError("Red no permitida")):
            created = backend.call("create_task", {"title": "Añadir café", "scheduled_at": "2026-10-03T12:00:00"})["created"]
            task_id = created["id"]
            backend.call("update_task", {"task_id": task_id, "title": "Añadir té"})
            backend.call("move_task_to_day", {"task_id": task_id, "date": "2026-10-04"})
            backend.call("complete_task", {"task_id": task_id})
            task = backend.call("get_task", {"task_id": task_id})["task"]
            self.assertEqual(task["title"], "Añadir té")
            self.assertEqual(task["status"], "completed")
            self.assertTrue(task["scheduledAt"].startswith("2026-10-04"))
        self.assertEqual(self.state_path.read_bytes(), before)
        self.assertEqual(LocalBackend(self.state_path, sandbox=True).call("list_tasks", {})["count"], 0)

    def test_failed_sandbox_update_preserves_previous_state_and_restores_core(self) -> None:
        backend = LocalBackend(self.state_path, sandbox=True)
        task = backend.call("create_task", {"title": "Conservar"})["created"]
        original_load = core.load_state
        with self.assertRaises(ValueError):
            backend.call("update_task", {"task_id": task["id"], "category_ids": ["ausente"]})
        self.assertEqual(backend.call("get_task", {"task_id": task["id"]})["task"], task)
        self.assertIs(core.load_state, original_load)

    def test_tools_describe_actual_read_only_and_sandbox_behavior(self) -> None:
        live = tool_definitions()
        self.assertEqual(len(live), 5)
        self.assertTrue(all(tool["annotations"]["readOnlyHint"] for tool in live))
        sandbox = tool_definitions(True)
        self.assertEqual(len(sandbox), 9)
        create = next(tool for tool in sandbox if tool["name"] == "create_task")
        self.assertFalse(create["annotations"]["readOnlyHint"])
        self.assertFalse(create["annotations"]["idempotentHint"])
        self.assertFalse(create["inputSchema"]["additionalProperties"])

    def test_adapter_does_not_load_legacy_credentials(self) -> None:
        with patch.dict(os.environ, {"TODO_MCP_SKIP_ENV_FILE": "1"}), patch.object(Path, "read_text", side_effect=AssertionError("Credenciales no permitidas")):
            core.load_env_file()


@unittest.skipUnless(MCP_AVAILABLE, "Instala requirements-chatgpt.txt para probar el transporte del SDK.")
class StdioTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="todo-chatgpt-stdio-")
        self.state_path = Path(self.temporary.name) / "estado con espacio.json"
        self.state_path.write_text(json.dumps(core.default_state()), encoding="utf-8")

    async def asyncTearDown(self) -> None:
        self.temporary.cleanup()

    def parameters(self, *, sandbox: bool = False, launcher: bool = False) -> StdioServerParameters:
        root = Path(__file__).resolve().parent
        if launcher:
            command = str(Path(os.environ["SYSTEMROOT"]) / "System32" / "WindowsPowerShell" / "v1.0" / "powershell.exe")
            args = ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(root / "start_chatgpt_mcp.ps1"), "-StatePath", str(self.state_path)]
            if sandbox:
                args.append("-Sandbox")
        else:
            command = sys.executable
            args = ["-u", str(root / "chatgpt_server.py"), "--state-path", str(self.state_path)]
            if sandbox:
                args.append("--sandbox")
        return StdioServerParameters(command=command, args=args, env={"TODO_MCP_DISABLE_REMOTE": "0", "PYTHONUTF8": "1"})

    async def test_real_stdio_initialization_ping_read_and_blocked_write(self) -> None:
        before = self.state_path.read_bytes()
        async with stdio_client(self.parameters()) as (read, write):
            async with ClientSession(read, write) as session:
                initialized = await session.initialize()
                self.assertEqual(initialized.serverInfo.name, "todo-chatgpt-local")
                await session.send_ping()
                listed = await session.list_tools()
                self.assertEqual(len(listed.tools), 5)
                result = await session.call_tool("list_tasks", {})
                self.assertFalse(result.isError)
                self.assertEqual(result.structuredContent["mode"], "local_read_only")
                blocked = await session.call_tool("create_task", {"title": "No guardar"})
                self.assertTrue(blocked.isError)
        self.assertEqual(self.state_path.read_bytes(), before)

    async def test_real_stdio_sandbox_validates_inputs_and_completes_task(self) -> None:
        before = self.state_path.read_bytes()
        async with stdio_client(self.parameters(sandbox=True)) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()
                for args in (
                    {},
                    {"title": " "},
                    {"title": 42},
                    {"title": "Ejemplo", "unexpected": True},
                    {"title": "Ejemplo", "recurrence_interval": 0},
                    {"title": "Ejemplo", "priority": "invalid"},
                    {"title": "Ejemplo", "scheduled_at": "sin fecha"},
                ):
                    with self.subTest(arguments=args):
                        result = await session.call_tool("create_task", args)
                        self.assertTrue(result.isError)
                created = await session.call_tool("create_task", {"title": "Comprar piñones"})
                self.assertFalse(created.isError)
                self.assertEqual(created.structuredContent["mode"], "sandbox")
                self.assertFalse(created.structuredContent["persistent"])
                task_id = created.structuredContent["created"]["id"]
                for invalid_date in ("2026-02-30", "20261004"):
                    moved = await session.call_tool("move_task_to_day", {"task_id": task_id, "date": invalid_date})
                    self.assertTrue(moved.isError)
                completed = await session.call_tool("complete_task", {"task_id": task_id})
                self.assertFalse(completed.isError)
                queried = await session.call_tool("get_task", {"task_id": task_id})
                self.assertEqual(queried.structuredContent["task"]["title"], "Comprar piñones")
                self.assertEqual(queried.structuredContent["task"]["status"], "completed")
                tasks = await session.call_tool("list_tasks", {})
                self.assertEqual(tasks.structuredContent["count"], 1)
        self.assertEqual(self.state_path.read_bytes(), before)

    async def test_windows_launcher_keeps_stdout_as_utf8_mcp(self) -> None:
        async with stdio_client(self.parameters(sandbox=True, launcher=True)) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()
                result = await session.call_tool("create_task", {"title": "Revisar iluminación"})
                self.assertFalse(result.isError)
                self.assertEqual(result.structuredContent["created"]["title"], "Revisar iluminación")


if __name__ == "__main__":
    unittest.main()
