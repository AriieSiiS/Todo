import copy
import datetime as dt
import json
import os
import random
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


PROTOCOL_VERSION = "2025-03-26"
SERVER_INFO = {"name": "todo-mcp", "version": "0.2.0"}
REPO_ROOT = Path(__file__).resolve().parent.parent
MCP_DIR = REPO_ROOT / "mcp_server"


def load_env_file() -> None:
    env_path = MCP_DIR / ".env"
    if not env_path.exists():
        return
    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


load_env_file()


def documents_todo_dir() -> Path:
    home = os.environ.get("USERPROFILE") or os.environ.get("HOME") or str(Path.cwd())
    documents = Path(home) / "Documents"
    if documents.exists():
        return documents / "Todo"
    return Path(home)


RUNTIME_DIR = documents_todo_dir() / "runtime"
STATE_PATH = RUNTIME_DIR / "todo_state.json"
SUPABASE_URL = os.environ.get("SUPABASE_URL", "").rstrip("/")
SUPABASE_SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
SUPABASE_OWNER_EMAIL = os.environ.get("SUPABASE_OWNER_EMAIL", "")


def remote_enabled() -> bool:
    return bool(SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY and SUPABASE_OWNER_EMAIL)


def now_iso() -> str:
    return dt.datetime.now().astimezone().isoformat()


def default_state() -> dict[str, Any]:
    return {
        "tasks": [],
        "categories": [],
        "projects": [],
        "notes": [],
        "daySettings": {
            "dayEndsAtHour": 5,
            "nextDayVisibleAtHour": 10,
        },
        "notificationSettings": {
            "notificationsEnabled": True,
            "webPermissionGranted": False,
            "windowsPermissionGranted": True,
            "dayStartReminderEnabled": True,
            "dayEndReminderEnabled": True,
            "defaultMinutesBeforeTask": 30,
        },
        "calendarSettings": {
            "webClientId": "",
            "desktopClientId": "",
            "desktopClientSecret": "",
            "selectedCalendarId": "primary",
            "selectedCalendarName": "Primary",
            "connectedEmail": "",
            "connected": False,
            "lastError": "",
        },
        "section": "today",
        "todaySort": "manual",
        "updatedAt": now_iso(),
        "schemaVersion": 1,
        "lastModifiedBy": "mcp",
    }


def ensure_runtime_dir() -> None:
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)


def read_local_state() -> dict[str, Any]:
    ensure_runtime_dir()
    if not STATE_PATH.exists():
        state = default_state()
        write_local_state(state)
        return state
    raw = STATE_PATH.read_text(encoding="utf-8").strip()
    if not raw:
        state = default_state()
        write_local_state(state)
        return state
    return json.loads(raw)


def write_local_state(state: dict[str, Any]) -> None:
    ensure_runtime_dir()
    temp = STATE_PATH.with_suffix(".tmp")
    temp.write_text(json.dumps(state, indent=2, ensure_ascii=False), encoding="utf-8")
    temp.replace(STATE_PATH)


def remote_request(method: str, path: str, *, body: Any = None, prefer: str | None = None) -> Any:
    url = f"{SUPABASE_URL}{path}"
    payload = None
    headers = {
        "apikey": SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_ROLE_KEY}",
    }
    if body is not None:
        payload = json.dumps(body, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json"
    if prefer:
        headers["Prefer"] = prefer
    request = urllib.request.Request(url, data=payload, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            raw = response.read().decode("utf-8")
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Supabase devolvio {error.code}: {detail}") from error


def read_remote_state() -> dict[str, Any] | None:
    query = urllib.parse.quote(SUPABASE_OWNER_EMAIL, safe="")
    payload = remote_request(
        "GET",
        f"/rest/v1/todo_app_states?owner_email=eq.{query}&select=state",
    )
    if not payload:
        return None
    row = payload[0]
    state = row.get("state")
    if not isinstance(state, dict):
        return None
    return state


def write_remote_state(state: dict[str, Any]) -> None:
    remote_request(
        "POST",
        "/rest/v1/todo_app_states",
        body=[
            {
                "owner_email": SUPABASE_OWNER_EMAIL,
                "schema_version": int(state.get("schemaVersion", 1)),
                "updated_at": state.get("updatedAt") or now_iso(),
                "state": state,
            }
        ],
        prefer="resolution=merge-duplicates,return=representation",
    )


def load_state() -> dict[str, Any]:
    if remote_enabled():
        state = read_remote_state()
        if state is not None:
            write_local_state(state)
            return state
        local = read_local_state()
        write_remote_state(local)
        return local
    return read_local_state()


def save_state(state: dict[str, Any]) -> None:
    touch_state(state)
    write_local_state(state)
    if remote_enabled():
        write_remote_state(state)


def touch_state(state: dict[str, Any]) -> None:
    state["updatedAt"] = now_iso()
    state["schemaVersion"] = int(state.get("schemaVersion", 1) or 1)
    state["lastModifiedBy"] = "mcp"


def json_result(payload: Any) -> dict[str, Any]:
    return {
        "content": [
            {
                "type": "text",
                "text": json.dumps(payload, ensure_ascii=False, indent=2),
            }
        ]
    }


def tool_definitions() -> list[dict[str, Any]]:
    return [
        {
            "name": "get_app_state",
            "description": "Devuelve el estado completo compartido de la app Todo.",
            "inputSchema": {"type": "object", "properties": {}},
        },
        {
            "name": "get_today",
            "description": "Devuelve la fecha logica actual y las tareas activas de hoy.",
            "inputSchema": {"type": "object", "properties": {}},
        },
        {
            "name": "list_tasks",
            "description": "Lista tareas, con filtros opcionales por estado, proyecto, categoria o fecha.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "status": {"type": "string"},
                    "project_id": {"type": "string"},
                    "category_id": {"type": "string"},
                    "date": {"type": "string", "description": "Fecha YYYY-MM-DD o 'today'."},
                },
            },
        },
        {
            "name": "create_task",
            "description": "Crea una nueva tarea.",
            "inputSchema": {
                "type": "object",
                "required": ["title"],
                "properties": {
                    "title": {"type": "string"},
                    "description": {"type": "string"},
                    "scheduled_at": {"type": "string"},
                    "priority": {"type": "string"},
                    "category_ids": {"type": "array", "items": {"type": "string"}},
                    "project_ids": {"type": "array", "items": {"type": "string"}},
                    "materials": {"type": "array", "items": {"type": "string"}},
                    "checklist": {"type": "array", "items": {"type": "string"}},
                    "reminder_enabled": {"type": "boolean"},
                    "reminder_minutes_before": {"type": "integer"},
                    "recurrence_type": {"type": "string"},
                    "recurrence_interval": {"type": "integer"},
                },
            },
        },
        {
            "name": "update_task",
            "description": "Actualiza una tarea existente.",
            "inputSchema": {
                "type": "object",
                "required": ["task_id"],
                "properties": {
                    "task_id": {"type": "string"},
                    "title": {"type": "string"},
                    "description": {"type": "string"},
                    "scheduled_at": {"type": "string"},
                    "clear_scheduled_at": {"type": "boolean"},
                    "priority": {"type": "string"},
                    "status": {"type": "string"},
                    "category_ids": {"type": "array", "items": {"type": "string"}},
                    "project_ids": {"type": "array", "items": {"type": "string"}},
                    "materials": {"type": "array", "items": {"type": "string"}},
                    "checklist": {"type": "array", "items": {"type": "string"}},
                    "collapsed": {"type": "boolean"},
                    "reminder_enabled": {"type": "boolean"},
                    "reminder_minutes_before": {"type": "integer"},
                },
            },
        },
        {
            "name": "complete_task",
            "description": "Marca una tarea como completada.",
            "inputSchema": {
                "type": "object",
                "required": ["task_id"],
                "properties": {"task_id": {"type": "string"}},
            },
        },
        {
            "name": "move_task_to_day",
            "description": "Mueve una tarea a otro dia, conservando la hora si ya la tenia.",
            "inputSchema": {
                "type": "object",
                "required": ["task_id", "date"],
                "properties": {
                    "task_id": {"type": "string"},
                    "date": {"type": "string", "description": "Fecha YYYY-MM-DD"},
                },
            },
        },
        {
            "name": "list_projects",
            "description": "Lista proyectos existentes.",
            "inputSchema": {"type": "object", "properties": {}},
        },
        {
            "name": "create_project",
            "description": "Crea un nuevo proyecto.",
            "inputSchema": {
                "type": "object",
                "required": ["name"],
                "properties": {
                    "name": {"type": "string"},
                    "description": {"type": "string"},
                    "color_value": {"type": "integer"},
                    "category_ids": {"type": "array", "items": {"type": "string"}},
                },
            },
        },
        {
            "name": "export_state",
            "description": "Devuelve el estado completo en JSON.",
            "inputSchema": {"type": "object", "properties": {}},
        },
        {
            "name": "import_state",
            "description": "Sustituye el estado actual por un JSON completo.",
            "inputSchema": {
                "type": "object",
                "required": ["raw_json"],
                "properties": {"raw_json": {"type": "string"}},
            },
        },
        {
            "name": "reset_state",
            "description": "Reinicia el estado a una base vacia y segura para la app.",
            "inputSchema": {"type": "object", "properties": {}},
        },
    ]


def logical_today(state: dict[str, Any]) -> dt.date:
    now = dt.datetime.now()
    end_hour = int(state.get("daySettings", {}).get("dayEndsAtHour", 5))
    if now.hour < end_hour:
        now = now - dt.timedelta(days=1)
    return now.date()


def parse_datetime(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    try:
        return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def normalize_datetime(value: str | None) -> str | None:
    parsed = parse_datetime(value)
    if parsed is None:
        return None
    if parsed.tzinfo is None:
        return parsed.isoformat()
    return parsed.astimezone().isoformat()


def make_id(prefix: str) -> str:
    return f"{prefix}-{int(dt.datetime.now().timestamp() * 1000000)}-{random.randint(1000, 9999)}"


def task_matches_date(task: dict[str, Any], target: dt.date) -> bool:
    scheduled = parse_datetime(task.get("scheduledAt"))
    if scheduled is None:
        return True
    return scheduled.date() == target


def next_manual_order(tasks: list[dict[str, Any]], parent_task_id: str | None = None) -> float:
    relevant = [task.get("manualOrder", 0) for task in tasks if task.get("parentTaskId") == parent_task_id]
    if not relevant:
        return 0.0
    return float(max(relevant)) + 1.0


def create_task_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    tasks = state["tasks"]
    reminder_enabled = bool(arguments.get("reminder_enabled", False))
    reminder_minutes = int(
        arguments.get(
            "reminder_minutes_before",
            state["notificationSettings"].get("defaultMinutesBeforeTask", 30),
        )
    )
    task = {
        "id": make_id("task"),
        "title": arguments["title"].strip(),
        "description": arguments.get("description") or None,
        "categoryIds": arguments.get("category_ids", []),
        "projectIds": arguments.get("project_ids", []),
        "scheduledAt": normalize_datetime(arguments.get("scheduled_at")),
        "priority": arguments.get("priority", "medium"),
        "status": "active",
        "recurrence": {
            "type": arguments.get("recurrence_type", "none"),
            "interval": int(arguments.get("recurrence_interval", 1)),
            "weekdays": [],
        },
        "subtaskIds": [],
        "checklist": arguments.get("checklist", []),
        "materials": arguments.get("materials", []),
        "origin": "manual",
        "manualOrder": next_manual_order(tasks),
        "parentTaskId": None,
        "collapsed": False,
        "calendarLink": None,
        "reminderRule": {
            "triggerMode": "minutesBefore",
            "minutesBefore": reminder_minutes,
            "firesAtDayStart": False,
            "firesAtDayEnd": False,
            "enabled": reminder_enabled,
        }
        if reminder_enabled
        else None,
    }
    tasks.append(task)
    save_state(state)
    return {"created": task}


def find_task(state: dict[str, Any], task_id: str) -> tuple[int, dict[str, Any]]:
    for index, task in enumerate(state["tasks"]):
        if task.get("id") == task_id:
            return index, task
    raise ValueError(f"No existe la tarea '{task_id}'.")


def update_task_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    index, task = find_task(state, arguments["task_id"])
    updated = copy.deepcopy(task)

    if "title" in arguments:
        updated["title"] = arguments["title"].strip()
    if "description" in arguments:
        updated["description"] = arguments.get("description") or None
    if arguments.get("clear_scheduled_at"):
        updated["scheduledAt"] = None
    elif "scheduled_at" in arguments:
        updated["scheduledAt"] = normalize_datetime(arguments.get("scheduled_at"))
    if "priority" in arguments:
        updated["priority"] = arguments["priority"]
    if "status" in arguments:
        updated["status"] = arguments["status"]
    if "category_ids" in arguments:
        updated["categoryIds"] = arguments["category_ids"]
    if "project_ids" in arguments:
        updated["projectIds"] = arguments["project_ids"]
    if "materials" in arguments:
        updated["materials"] = arguments["materials"]
    if "checklist" in arguments:
        updated["checklist"] = arguments["checklist"]
    if "collapsed" in arguments:
        updated["collapsed"] = bool(arguments["collapsed"])
    if "reminder_enabled" in arguments:
        if arguments["reminder_enabled"]:
            current = updated.get("reminderRule") or {
                "triggerMode": "minutesBefore",
                "minutesBefore": state["notificationSettings"].get("defaultMinutesBeforeTask", 30),
                "firesAtDayStart": False,
                "firesAtDayEnd": False,
                "enabled": True,
            }
            current["enabled"] = True
            if "reminder_minutes_before" in arguments:
                current["minutesBefore"] = int(arguments["reminder_minutes_before"])
            updated["reminderRule"] = current
        else:
            updated["reminderRule"] = None
    elif "reminder_minutes_before" in arguments and updated.get("reminderRule"):
        updated["reminderRule"]["minutesBefore"] = int(arguments["reminder_minutes_before"])

    state["tasks"][index] = updated
    save_state(state)
    return {"updated": updated}


def complete_task_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    index, task = find_task(state, arguments["task_id"])
    updated = copy.deepcopy(task)
    updated["status"] = "completed"
    state["tasks"][index] = updated
    save_state(state)
    return {"completed": updated}


def move_task_to_day_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    index, task = find_task(state, arguments["task_id"])
    current = parse_datetime(task.get("scheduledAt")) or dt.datetime.combine(logical_today(state), dt.time(12, 0))
    target_date = dt.date.fromisoformat(arguments["date"])
    moved = copy.deepcopy(task)
    moved["scheduledAt"] = dt.datetime(
        target_date.year,
        target_date.month,
        target_date.day,
        current.hour,
        current.minute,
        current.second,
    ).isoformat()
    if moved.get("calendarLink"):
        moved["calendarLink"]["syncStatus"] = "pending"
    state["tasks"][index] = moved
    save_state(state)
    return {"moved": moved}


def list_tasks_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    target_date = None
    if "date" in arguments:
        target_date = logical_today(state) if arguments["date"] == "today" else dt.date.fromisoformat(arguments["date"])

    tasks = []
    for task in state["tasks"]:
        if "status" in arguments and task.get("status") != arguments["status"]:
            continue
        if "project_id" in arguments and arguments["project_id"] not in task.get("projectIds", []):
            continue
        if "category_id" in arguments and arguments["category_id"] not in task.get("categoryIds", []):
            continue
        if target_date is not None and not task_matches_date(task, target_date):
            continue
        tasks.append(task)
    return {"tasks": tasks, "count": len(tasks), "mode": "supabase" if remote_enabled() else "local"}


def get_today_impl() -> dict[str, Any]:
    state = load_state()
    today = logical_today(state)
    tasks = [
        task
        for task in state["tasks"]
        if task.get("status") == "active" and task_matches_date(task, today)
    ]
    return {
        "logical_date": today.isoformat(),
        "tasks": tasks,
        "count": len(tasks),
        "mode": "supabase" if remote_enabled() else "local",
    }


def list_projects_impl() -> dict[str, Any]:
    state = load_state()
    return {"projects": state["projects"], "count": len(state["projects"])}


def create_project_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    project = {
        "id": make_id("project"),
        "name": arguments["name"].strip(),
        "description": arguments.get("description", "").strip(),
        "colorValue": int(arguments.get("color_value", 0xFF607A5A)),
        "iconCodePoint": 983108,
        "status": "active",
        "categoryIds": arguments.get("category_ids", []),
    }
    state["projects"].append(project)
    save_state(state)
    return {"created": project}


def import_state_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = json.loads(arguments["raw_json"])
    save_state(state)
    return {"imported": True, "task_count": len(state.get("tasks", []))}


def reset_state_impl() -> dict[str, Any]:
    state = default_state()
    save_state(state)
    return {"reset": True, "mode": "supabase" if remote_enabled() else "local"}


def handle_tool_call(name: str, arguments: dict[str, Any]) -> dict[str, Any]:
    if name == "get_app_state":
        state = load_state()
        return json_result(state)
    if name == "get_today":
        return json_result(get_today_impl())
    if name == "list_tasks":
        return json_result(list_tasks_impl(arguments))
    if name == "create_task":
        return json_result(create_task_impl(arguments))
    if name == "update_task":
        return json_result(update_task_impl(arguments))
    if name == "complete_task":
        return json_result(complete_task_impl(arguments))
    if name == "move_task_to_day":
        return json_result(move_task_to_day_impl(arguments))
    if name == "list_projects":
        return json_result(list_projects_impl())
    if name == "create_project":
        return json_result(create_project_impl(arguments))
    if name == "export_state":
        return json_result(load_state())
    if name == "import_state":
        return json_result(import_state_impl(arguments))
    if name == "reset_state":
        return json_result(reset_state_impl())
    raise ValueError(f"Herramienta desconocida: {name}")


def send(message: dict[str, Any]) -> None:
    payload = json.dumps(message, ensure_ascii=False).encode("utf-8")
    sys.stdout.buffer.write(f"Content-Length: {len(payload)}\r\n\r\n".encode("ascii"))
    sys.stdout.buffer.write(payload)
    sys.stdout.buffer.flush()


def read_message() -> dict[str, Any] | None:
    headers: dict[str, str] = {}
    while True:
        line = sys.stdin.buffer.readline()
        if not line:
            return None
        if line in (b"\r\n", b"\n"):
            break
        key, value = line.decode("utf-8").split(":", 1)
        headers[key.strip().lower()] = value.strip()

    length = int(headers.get("content-length", "0"))
    if length <= 0:
        return None
    body = sys.stdin.buffer.read(length)
    if not body:
        return None
    return json.loads(body.decode("utf-8"))


def response_for(request: dict[str, Any]) -> dict[str, Any] | None:
    method = request.get("method")
    request_id = request.get("id")
    params = request.get("params", {})

    if method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": request_id,
            "result": {
                "protocolVersion": PROTOCOL_VERSION,
                "serverInfo": SERVER_INFO,
                "capabilities": {"tools": {}},
            },
        }

    if method == "notifications/initialized":
        return None

    if method == "tools/list":
        return {
            "jsonrpc": "2.0",
            "id": request_id,
            "result": {"tools": tool_definitions()},
        }

    if method == "tools/call":
        try:
            result = handle_tool_call(params["name"], params.get("arguments", {}))
            return {"jsonrpc": "2.0", "id": request_id, "result": result}
        except Exception as error:
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {"code": -32000, "message": str(error)},
            }

    return {
        "jsonrpc": "2.0",
        "id": request_id,
        "error": {"code": -32601, "message": f"Metodo no soportado: {method}"},
    }


def main() -> int:
    ensure_runtime_dir()
    while True:
        request = read_message()
        if request is None:
            return 0
        response = response_for(request)
        if response is not None:
            send(response)


if __name__ == "__main__":
    raise SystemExit(main())
