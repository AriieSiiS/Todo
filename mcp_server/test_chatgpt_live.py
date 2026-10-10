"""Pruebas del puente autenticado y del SDK contra una instancia Flutter temporal."""

import json
import os
import sys
import tempfile
import threading
import unittest
import zipfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from chatgpt_adapter import LocalBackend, tool_definitions
import server as core
from package_chatgpt_plugin import package_plugin
from chatgpt_tunnel import health_flags

try:
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client
except ModuleNotFoundError:
    ClientSession = None


class LiveBackendTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="todo-puente-python-")
        self.root = Path(self.temporary.name)
        self.state_path = self.root / "todo_state.json"
        self.state_path.write_text(json.dumps(core.default_state()), encoding="utf-8")
        self.backend = LocalBackend(self.state_path, live=True)
        self.requests = []
        self.status = 200
        self.payload = {"tasks": [{"id": "memoria", "title": "Edición sin guardar"}], "source": "app"}
        owner = self

        class Handler(BaseHTTPRequestHandler):
            def do_POST(self):
                owner.requests.append((self.path, self.headers.get("Authorization"),
                    json.loads(self.rfile.read(int(self.headers["Content-Length"])))))
                self.send_response(owner.status)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps(owner.payload, ensure_ascii=False).encode("utf-8"))

            def log_message(self, *_):
                pass

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.session_file = self.root / "agent_bridge_session.json"
        self.session_file.write_text(json.dumps({"version": 1, "port": self.server.server_port, "token": "x" * 44}), encoding="utf-8")

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.temporary.cleanup()

    def test_live_uses_authenticated_loopback_without_snapshot_writes(self):
        before = self.state_path.read_bytes()
        self.assertEqual(self.backend.call("get_today", {})["source"], "app")
        arguments = {"request_id": "crear-001", "title": "Café"}
        self.payload = {"savedLocally": True, "created": {"id": "temporal", "title": "Café"}}
        self.assertTrue(self.backend.call("create_task", arguments)["savedLocally"])
        self.assertEqual(self.requests[-1], ("/command", "Bearer " + "x" * 44,
            {"name": "create_task", "arguments": arguments}))
        self.assertEqual(self.state_path.read_bytes(), before)

    def test_missing_bridge_allows_reads_but_never_offline_writes(self):
        self.session_file.unlink()
        self.assertEqual(self.backend.call("list_tasks", {})["source"], "snapshot")
        with self.assertRaisesRegex(ValueError, "Abre la instalación"):
            self.backend.call("create_task", {"request_id": "crear-002", "title": "No guardar"})
        self.assertEqual(json.loads(self.state_path.read_text())["tasks"], [])
        self.assertEqual(self.requests, [])

    def test_rejection_never_falls_back_to_legacy_writes(self):
        self.status = 400
        self.payload = {"error": "La tarea cambió desde la consulta."}
        with self.assertRaisesRegex(ValueError, "La tarea cambió"):
            self.backend.call("update_task", {"task_id": "ejemplo", "request_id": "editar-001"})
        self.assertEqual(json.loads(self.state_path.read_text())["tasks"], [])

    def test_schema_requires_retry_identity_and_task_version(self):
        tools = {tool["name"]: tool for tool in tool_definitions(live=True)}
        self.assertEqual(len(tools), 19)
        self.assertIn("request_id", tools["create_task"]["inputSchema"]["required"])
        self.assertIn("expected_version", tools["complete_task"]["inputSchema"]["required"])
        self.assertNotIn("status", tools["update_task"]["inputSchema"]["properties"])
        self.assertNotIn("checklist", tools["create_task"]["inputSchema"]["properties"])
        self.assertTrue(tools["create_task"]["annotations"]["idempotentHint"])
        with self.assertRaises(ValueError):
            LocalBackend(self.state_path, live=True, sandbox=True)

    def test_offline_today_respects_manual_day_completed_and_skipped_routines(self):
        self.session_file.unlink()
        state = core.default_state()
        state.update(manualLogicalDate="2026-10-02T00:00:00", manualLogicalDateStartedAt="2020-01-01T00:00:00")
        state["tasks"] = [
            {"id": "normal", "title": "Café", "status": "active", "scheduledAt": "2026-10-01T09:00:00"},
            {"id": "rutina", "title": "Rutina activa", "status": "active", "recurrence": {"type": "daily"}},
            {"id": "hecha", "title": "Rutina completada", "status": "active", "recurrence": {"type": "daily"}, "recurrenceCompletions": {"2026-10-02": "2026-10-02T10:00:00"}},
            {"id": "saltada", "title": "Rutina saltada", "status": "active", "recurrence": {"type": "daily"}, "skippedRecurrenceOccurrences": ["2026-10-02"]},
            {"id": "subtarea", "title": "Subtarea", "status": "active", "parentTaskId": "normal"},
        ]
        self.state_path.write_text(json.dumps(state), encoding="utf-8")
        today = self.backend.call("get_today", {})
        self.assertEqual(today["date"], "2026-10-02")
        self.assertEqual({task["id"] for task in today["tasks"]}, {"normal", "rutina"})

    def test_package_uses_supplied_id_and_contains_only_metadata(self):
        with self.assertRaises(ValueError):
            package_plugin("pendiente", self.root / "paquete")
        app_id = "asdk_app_" + "0" * 32
        archive = package_plugin("plugin_" + app_id, self.root / "paquete")
        with zipfile.ZipFile(archive) as bundle:
            self.assertEqual(set(bundle.namelist()), {"plugin.json", ".app.json", "README.md"})
            self.assertEqual(json.loads(bundle.read(".app.json"))["apps"]["todo"]["id"], app_id)
            self.assertIn("conexión privada", bundle.read("plugin.json").decode("utf-8"))

    def test_tunnel_status_needs_running_healthy_and_ready(self):
        self.assertFalse(health_flags({"runtime": {"process_running": True, "healthy": False, "ready": False}}))
        self.assertFalse(health_flags({"runtime_state": "running"}))
        self.assertTrue(health_flags({"runtime": {"process_running": True, "healthy": True, "ready": True}}))


@unittest.skipUnless(ClientSession and os.environ.get("TODO_TEST_BRIDGE_PATH"),
                     "La prueba integral se ejecuta desde test/agent_bridge_test.dart.")
class BridgeSDKTest(unittest.IsolatedAsyncioTestCase):
    async def test_stdio_reaches_flutter_and_persists_tasks(self):
        state_path = Path(os.environ["TODO_TEST_BRIDGE_PATH"])
        parameters = StdioServerParameters(command=sys.executable,
            args=["-u", str(Path(__file__).with_name("chatgpt_server.py")), "--live", "--state-path", str(state_path)],
            env={"PYTHONUTF8": "1"})
        async with stdio_client(parameters) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()
                self.assertEqual(len((await session.list_tools()).tools), 20)
                today = await session.call_tool("get_today", {})
                self.assertEqual(today.structuredContent["date"], "2026-10-02")
                self.assertEqual(today.structuredContent["source"], "app")
                args = {"title": "Café desde stdio", "request_id": "stdio-crear-001"}
                created = await session.call_tool("create_task", args)
                self.assertFalse(created.isError)
                task = created.structuredContent["created"]
                repeated = await session.call_tool("create_task", args)
                self.assertEqual(repeated.structuredContent["created"]["id"], task["id"])
                updated = await session.call_tool("update_task", {"task_id": task["id"],
                    "expected_version": task["task_version"], "request_id": "stdio-editar-001", "title": "Té desde stdio"})
                self.assertFalse(updated.isError)
                stale = await session.call_tool("complete_task", {"task_id": task["id"],
                    "expected_version": task["task_version"], "request_id": "stdio-completar-001"})
                self.assertTrue(stale.isError)
                completed = await session.call_tool("complete_task", {"task_id": task["id"],
                    "expected_version": updated.structuredContent["task"]["task_version"], "request_id": "stdio-completar-001"})
                self.assertTrue(completed.structuredContent["savedLocally"])
                note = (await session.call_tool('create_note', {'content': 'Idea desde ChatGPT', 'emoji': '💡', 'request_id': 'stdio-nota-001'})).structuredContent['created']
                read_note = await session.call_tool('get_note', {'note_id': note['id']})
                self.assertEqual(read_note.structuredContent['note']['note_version'], note['note_version'])
                listing = await session.call_tool('browse_content', {'section': 'notas', 'query': 'idea'})
                self.assertEqual(listing.structuredContent['items'][0]['id'], note['id'])
                changed = await session.call_tool('update_note', {'note_id': note['id'], 'expected_version': note['note_version'], 'request_id': 'stdio-nota-002', 'content': 'Idea corregida'})
                self.assertEqual(changed.structuredContent['note']['emoji'], '💡')
                delete_note = {'note_id': note['id'], 'expected_version': changed.structuredContent['note']['note_version'], 'request_id': 'stdio-nota-003', 'confirm': True}
                removed = await session.call_tool('delete_note', delete_note)
                self.assertTrue(removed.structuredContent['savedLocally'])
                self.assertEqual((await session.call_tool('delete_note', delete_note)).structuredContent, removed.structuredContent)
                doomed = (await session.call_tool('create_task', {'title': 'Borrar esta prueba', 'request_id': 'stdio-crear-002'})).structuredContent['created']
                deletion = await session.call_tool('delete_task', {'task_id': doomed['id'], 'expected_version': doomed['task_version'], 'request_id': 'stdio-borrar-001', 'confirm': True})
                self.assertTrue(deletion.structuredContent['savedLocally'])
                self.assertTrue((await session.call_tool('get_task', {'task_id': doomed['id']})).isError)
        saved = json.loads(state_path.read_text(encoding="utf-8"))
        matching = [task for task in saved["tasks"] if task["title"] == "Té desde stdio"]
        self.assertEqual(len(matching), 1)
        self.assertEqual(matching[0]["status"], "completed")


if __name__ == "__main__":
    unittest.main()
