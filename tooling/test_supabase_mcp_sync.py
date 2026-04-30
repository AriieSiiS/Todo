import json
import os
import subprocess
import sys
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
PYTHON = (
    Path.home()
    / ".cache"
    / "codex-runtimes"
    / "codex-primary-runtime"
    / "dependencies"
    / "python"
    / "python.exe"
)
SERVER = ROOT / "mcp_server" / "server.py"
ENV_PATH = ROOT / "mcp_server" / ".env"


def load_env() -> dict[str, str]:
    values: dict[str, str] = {}
    for line in ENV_PATH.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key] = value
    return values


def send(proc: subprocess.Popen[bytes], message: dict) -> None:
    payload = json.dumps(message).encode("utf-8")
    proc.stdin.write(f"Content-Length: {len(payload)}\r\n\r\n".encode("ascii"))
    proc.stdin.write(payload)
    proc.stdin.flush()


def read(proc: subprocess.Popen[bytes]) -> dict:
    headers: dict[str, str] = {}
    while True:
        line = proc.stdout.readline()
        if not line:
            raise RuntimeError("El servidor MCP se cerro antes de responder.")
        if line in (b"\r\n", b"\n"):
            break
        key, value = line.decode("utf-8").split(":", 1)
        headers[key.strip().lower()] = value.strip()
    length = int(headers["content-length"])
    body = proc.stdout.read(length)
    return json.loads(body.decode("utf-8"))


def read_remote_state(env: dict[str, str]) -> dict:
    request = urllib.request.Request(
        f"{env['SUPABASE_URL']}/rest/v1/todo_app_states?owner_email=eq.{env['SUPABASE_OWNER_EMAIL']}&select=state",
        headers={
            "apikey": env["SUPABASE_SERVICE_ROLE_KEY"],
            "Authorization": f"Bearer {env['SUPABASE_SERVICE_ROLE_KEY']}",
        },
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        rows = json.loads(response.read().decode("utf-8"))
    return rows[0]["state"] if rows else {}


def main() -> int:
    env = load_env()
    proc = subprocess.Popen([str(PYTHON), str(SERVER)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, cwd=str(ROOT))
    try:
        send(proc, {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}})
        read(proc)
        send(
            proc,
            {
                "jsonrpc": "2.0",
                "id": 2,
                "method": "tools/call",
                "params": {
                    "name": "create_task",
                    "arguments": {
                        "title": "Prueba MCP Supabase",
                        "priority": "high",
                        "scheduled_at": "2026-04-29T10:00:00",
                        "reminder_enabled": True,
                        "reminder_minutes_before": 15,
                    },
                },
            },
        )
        create_reply = read(proc)
        remote_after_create = read_remote_state(env)
        send(proc, {"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "reset_state", "arguments": {}}})
        read(proc)
        remote_after_reset = read_remote_state(env)
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()

    created_payload = json.loads(create_reply["result"]["content"][0]["text"])
    created = created_payload["created"]
    task_titles_after_create = [task["title"] for task in remote_after_create.get("tasks", [])]
    task_titles_after_reset = [task["title"] for task in remote_after_reset.get("tasks", [])]

    print(
        json.dumps(
            {
                "created_task": created["title"],
                "remote_task_count_after_create": len(remote_after_create.get("tasks", [])),
                "remote_titles_after_create": task_titles_after_create,
                "remote_task_count_after_reset": len(remote_after_reset.get("tasks", [])),
                "remote_titles_after_reset": task_titles_after_reset,
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
