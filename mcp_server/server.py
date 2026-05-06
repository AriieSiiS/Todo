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
REPO_SUPABASE_URL = "https://hgdzwoieicreenpapese.supabase.co"
REPO_PUBLISHABLE_KEY = "sb_publishable_7QgBLNA353YvBgI2dPlnaw_R_tkfjtS"
REPO_OWNER_EMAIL = "ariesix20@gmail.com"
APP_PREFS_PATH = (
    Path(os.environ.get("APPDATA", ""))
    / "com.example"
    / "todo"
    / "shared_preferences.json"
)
SUPABASE_URL = os.environ.get("SUPABASE_URL", REPO_SUPABASE_URL).rstrip("/")
SUPABASE_SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
SUPABASE_OWNER_EMAIL = os.environ.get("SUPABASE_OWNER_EMAIL", REPO_OWNER_EMAIL)


def app_session_credentials() -> tuple[str, str] | None:
    if not APP_PREFS_PATH.exists():
        return None
    try:
        prefs = json.loads(APP_PREFS_PATH.read_text(encoding="utf-8"))
        raw_session = prefs.get("flutter.sb-hgdzwoieicreenpapese-auth-token")
        if not raw_session:
            return None
        session = json.loads(raw_session)
    except (OSError, json.JSONDecodeError, TypeError):
        return None

    access_token = (
        session.get("access_token")
        or session.get("currentSession", {}).get("access_token")
        or session.get("session", {}).get("access_token")
    )
    email = (
        session.get("user", {}).get("email")
        or session.get("currentSession", {}).get("user", {}).get("email")
        or SUPABASE_OWNER_EMAIL
    )
    if not access_token or not email:
        return None
    return access_token, email


def remote_credentials() -> tuple[str, str, str] | None:
    if SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY and SUPABASE_OWNER_EMAIL:
        return SUPABASE_SERVICE_ROLE_KEY, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_OWNER_EMAIL
    app_session = app_session_credentials()
    if SUPABASE_URL and app_session is not None:
        access_token, email = app_session
        return REPO_PUBLISHABLE_KEY, access_token, email
    return None


def remote_enabled() -> bool:
    return remote_credentials() is not None


def now_iso() -> str:
    return dt.datetime.now().astimezone().isoformat()


def default_state() -> dict[str, Any]:
    return {
        "tasks": [],
        "categories": [],
        "projects": [],
        "notes": [],
        "expenses": [],
        "expenseCategories": [],
        "paymentMethods": [],
        "fixedPayments": [],
        "libraryItems": [],
        "libraryGoals": [],
        "calendarEvents": [],
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
        "visualMode": "classic",
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
    credentials = remote_credentials()
    if credentials is None:
        raise RuntimeError("No hay credenciales remotas configuradas para el MCP.")
    api_key, bearer_token, _owner_email = credentials
    url = f"{SUPABASE_URL}{path}"
    payload = None
    headers = {
        "apikey": api_key,
        "Authorization": f"Bearer {bearer_token}",
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
    credentials = remote_credentials()
    if credentials is None:
        return None
    _api_key, _bearer_token, owner_email = credentials
    query = urllib.parse.quote(owner_email, safe="")
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
    credentials = remote_credentials()
    if credentials is None:
        return
    _api_key, _bearer_token, owner_email = credentials
    remote_request(
        "POST",
        "/rest/v1/todo_app_states",
        body=[
            {
                "owner_email": owner_email,
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
    credentials = remote_credentials()
    state["lastModifiedBy"] = credentials[2] if credentials is not None else "mcp"


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
                    "recurrence_weekdays": {"type": "array", "items": {"type": "integer"}},
                    "status": {"type": "string"},
                    "origin": {"type": "string"},
                    "collapsed": {"type": "boolean"},
                    "parent_task_id": {"type": "string"},
                    "manual_order": {"type": "number"},
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
            "name": "list_categories",
            "description": "Lista categorias existentes.",
            "inputSchema": {"type": "object", "properties": {}},
        },
        {
            "name": "list_library_goals",
            "description": "Lista propositos de Biblioteca, con filtros opcionales por ano y tipo.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "target_year": {"type": "integer"},
                    "type": {
                        "type": "string",
                        "description": "game, book o movieSeries.",
                    },
                },
            },
        },
        {
            "name": "create_library_goal",
            "description": "Crea un proposito anual dentro de Biblioteca.",
            "inputSchema": {
                "type": "object",
                "required": ["type", "title", "target_year"],
                "properties": {
                    "type": {"type": "string"},
                    "title": {"type": "string"},
                    "target_year": {"type": "integer"},
                    "is_favorite": {"type": "boolean"},
                    "cover_url": {"type": "string"},
                    "note": {"type": "string"},
                    "platform": {"type": "string"},
                    "author": {"type": "string"},
                    "media_type": {"type": "string"},
                    "release_year": {"type": "integer"},
                    "creator_or_director": {"type": "string"},
                },
            },
        },
        {
            "name": "bulk_create_library_goals",
            "description": "Crea varios propositos de Biblioteca de una vez.",
            "inputSchema": {
                "type": "object",
                "required": ["goals"],
                "properties": {
                    "replace_year": {
                        "type": "integer",
                        "description": "Si se informa, borra antes los propositos de ese ano.",
                    },
                    "goals": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "required": ["type", "title", "target_year"],
                            "properties": {
                                "type": {"type": "string"},
                                "title": {"type": "string"},
                                "target_year": {"type": "integer"},
                                "is_favorite": {"type": "boolean"},
                                "cover_url": {"type": "string"},
                                "note": {"type": "string"},
                                "platform": {"type": "string"},
                                "author": {"type": "string"},
                                "media_type": {"type": "string"},
                                "release_year": {"type": "integer"},
                                "creator_or_director": {"type": "string"},
                            },
                        },
                    },
                },
            },
        },
        {
            "name": "update_library_goal",
            "description": "Actualiza un proposito de Biblioteca existente.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "goal_id": {"type": "string"},
                    "title": {
                        "type": "string",
                        "description": "Titulo actual usado para localizar el proposito.",
                    },
                    "target_year": {
                        "type": "integer",
                        "description": "Ano actual usado para localizar el proposito.",
                    },
                    "type": {
                        "type": "string",
                        "description": "Tipo actual usado para localizar el proposito.",
                    },
                    "new_title": {"type": "string"},
                    "new_target_year": {"type": "integer"},
                    "new_type": {"type": "string"},
                    "status": {"type": "string"},
                    "is_favorite": {"type": "boolean"},
                    "cover_url": {"type": "string"},
                    "clear_cover_url": {"type": "boolean"},
                    "note": {"type": "string"},
                    "clear_note": {"type": "boolean"},
                    "platform": {"type": "string"},
                    "clear_platform": {"type": "boolean"},
                    "author": {"type": "string"},
                    "clear_author": {"type": "boolean"},
                    "media_type": {"type": "string"},
                    "clear_media_type": {"type": "boolean"},
                    "release_year": {"type": "integer"},
                    "clear_release_year": {"type": "boolean"},
                    "creator_or_director": {"type": "string"},
                    "clear_creator_or_director": {"type": "boolean"},
                },
            },
        },
        {
            "name": "bulk_upsert_library_goals",
            "description": "Crea o actualiza varios propositos de Biblioteca sin duplicarlos.",
            "inputSchema": {
                "type": "object",
                "required": ["goals"],
                "properties": {
                    "goals": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "required": ["type", "title", "target_year"],
                            "properties": {
                                "type": {"type": "string"},
                                "title": {"type": "string"},
                                "target_year": {"type": "integer"},
                                "status": {"type": "string"},
                                "is_favorite": {"type": "boolean"},
                                "cover_url": {"type": "string"},
                                "clear_cover_url": {"type": "boolean"},
                                "note": {"type": "string"},
                                "clear_note": {"type": "boolean"},
                                "platform": {"type": "string"},
                                "clear_platform": {"type": "boolean"},
                                "author": {"type": "string"},
                                "clear_author": {"type": "boolean"},
                                "media_type": {"type": "string"},
                                "clear_media_type": {"type": "boolean"},
                                "release_year": {"type": "integer"},
                                "clear_release_year": {"type": "boolean"},
                                "creator_or_director": {"type": "string"},
                                "clear_creator_or_director": {"type": "boolean"},
                            },
                        },
                    },
                },
            },
        },
        {
            "name": "clear_library_goals",
            "description": "Borra propositos de Biblioteca, opcionalmente solo de un ano.",
            "inputSchema": {
                "type": "object",
                "properties": {"target_year": {"type": "integer"}},
            },
        },
        {
            "name": "create_category",
            "description": "Crea una nueva categoria.",
            "inputSchema": {
                "type": "object",
                "required": ["name"],
                "properties": {
                    "name": {"type": "string"},
                    "description": {"type": "string"},
                    "color_value": {"type": "integer"},
                    "icon_code_point": {"type": "integer"},
                    "active": {"type": "boolean"},
                },
            },
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
                    "icon_code_point": {"type": "integer"},
                    "status": {"type": "string"},
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


def find_category(state: dict[str, Any], category_id: str) -> tuple[int, dict[str, Any]]:
    for index, category in enumerate(state["categories"]):
        if category.get("id") == category_id:
            return index, category
    raise ValueError(f"No existe la categoria '{category_id}'.")


def create_task_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    tasks = state["tasks"]
    parent_task_id = arguments.get("parent_task_id")
    if parent_task_id:
        parent_index, parent_task = find_task(state, parent_task_id)
    else:
        parent_index, parent_task = None, None
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
        "status": arguments.get("status", "active"),
        "recurrence": {
            "type": arguments.get("recurrence_type", "none"),
            "interval": int(arguments.get("recurrence_interval", 1)),
            "weekdays": arguments.get("recurrence_weekdays", []),
        },
        "subtaskIds": [],
        "checklist": arguments.get("checklist", []),
        "materials": arguments.get("materials", []),
        "origin": arguments.get("origin", "manual"),
        "manualOrder": float(arguments.get("manual_order", next_manual_order(tasks, parent_task_id))),
        "parentTaskId": parent_task_id,
        "collapsed": bool(arguments.get("collapsed", False)),
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
    if parent_task is not None and parent_index is not None:
        updated_parent = copy.deepcopy(parent_task)
        updated_parent["subtaskIds"] = list(updated_parent.get("subtaskIds", [])) + [task["id"]]
        state["tasks"][parent_index] = updated_parent
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


def list_categories_impl() -> dict[str, Any]:
    state = load_state()
    return {"categories": state["categories"], "count": len(state["categories"])}


def create_category_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    category = {
        "id": make_id("cat"),
        "name": arguments["name"].strip(),
        "description": arguments.get("description", "").strip(),
        "colorValue": int(arguments.get("color_value", 0xFF607A5A)),
        "iconCodePoint": int(arguments.get("icon_code_point", 0xF624)),
        "active": bool(arguments.get("active", True)),
    }
    state["categories"].append(category)
    save_state(state)
    return {"created": category}


def create_project_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    project = {
        "id": make_id("project"),
        "name": arguments["name"].strip(),
        "description": arguments.get("description", "").strip(),
        "colorValue": int(arguments.get("color_value", 0xFF607A5A)),
        "iconCodePoint": int(arguments.get("icon_code_point", 983108)),
        "status": arguments.get("status", "active"),
        "categoryIds": arguments.get("category_ids", []),
    }
    state["projects"].append(project)
    save_state(state)
    return {"created": project}


def ensure_library_goal_lists(state: dict[str, Any]) -> None:
    state.setdefault("libraryItems", [])
    state.setdefault("libraryGoals", [])


def normalize_library_type(value: str) -> str:
    aliases = {
        "game": "game",
        "juego": "game",
        "book": "book",
        "libro": "book",
        "movie": "movieSeries",
        "pelicula": "movieSeries",
        "película": "movieSeries",
        "series": "movieSeries",
        "movieSeries": "movieSeries",
        "movie_series": "movieSeries",
    }
    normalized = aliases.get(value.strip())
    if normalized is None:
        raise ValueError("Tipo de biblioteca no valido. Usa game, book o movieSeries.")
    return normalized


def normalize_media_type(value: str | None) -> str | None:
    if not value:
        return None
    aliases = {
        "movie": "movie",
        "pelicula": "movie",
        "película": "movie",
        "film": "movie",
        "series": "series",
        "serie": "series",
    }
    normalized = aliases.get(value.strip())
    if normalized is None:
        raise ValueError("Tipo de medio no valido. Usa movie o series.")
    return normalized


def normalize_goal_status(value: str | None) -> str:
    if not value:
        return "pending"
    aliases = {
        "pending": "pending",
        "pendiente": "pending",
        "completed": "completed",
        "complete": "completed",
        "completado": "completed",
        "terminado": "completed",
    }
    normalized = aliases.get(value.strip())
    if normalized is None:
        raise ValueError("Estado de proposito no valido. Usa pending o completed.")
    return normalized


def library_goal_from_args(arguments: dict[str, Any]) -> dict[str, Any]:
    now = now_iso()
    goal_type = normalize_library_type(arguments["type"])
    return {
        "id": make_id("library_goal"),
        "type": goal_type,
        "title": arguments["title"].strip(),
        "targetYear": int(arguments["target_year"]),
        "status": normalize_goal_status(arguments.get("status")),
        "isFavorite": bool(arguments.get("is_favorite", False)),
        "coverUrl": (arguments.get("cover_url") or "").strip() or None,
        "note": (arguments.get("note") or "").strip() or None,
        "platform": (arguments.get("platform") or "").strip() or None,
        "author": (arguments.get("author") or "").strip() or None,
        "mediaType": normalize_media_type(arguments.get("media_type")),
        "releaseYear": arguments.get("release_year"),
        "creatorOrDirector": (arguments.get("creator_or_director") or "").strip() or None,
        "createdAt": now,
        "updatedAt": now,
    }


def list_library_goals_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_library_goal_lists(state)
    goals = []
    for goal in state["libraryGoals"]:
        if "target_year" in arguments and int(goal.get("targetYear", 0)) != int(arguments["target_year"]):
            continue
        if "type" in arguments and goal.get("type") != normalize_library_type(arguments["type"]):
            continue
        goals.append(goal)
    return {"goals": goals, "count": len(goals)}


def find_library_goal_index(state: dict[str, Any], arguments: dict[str, Any]) -> int:
    ensure_library_goal_lists(state)
    goal_id = (arguments.get("goal_id") or "").strip()
    title = (arguments.get("title") or "").strip().lower()
    target_year = arguments.get("target_year")
    goal_type = normalize_library_type(arguments["type"]) if arguments.get("type") else None

    matches = []
    for index, goal in enumerate(state["libraryGoals"]):
        if goal_id and goal.get("id") != goal_id:
            continue
        if title and str(goal.get("title", "")).strip().lower() != title:
            continue
        if target_year is not None and int(goal.get("targetYear", 0)) != int(target_year):
            continue
        if goal_type is not None and goal.get("type") != goal_type:
            continue
        matches.append(index)

    if not matches:
        raise ValueError("No se encontro ningun proposito con esos filtros.")
    if len(matches) > 1:
        raise ValueError("Los filtros coinciden con varios propositos; usa goal_id.")
    return matches[0]


def create_library_goal_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_library_goal_lists(state)
    goal = library_goal_from_args(arguments)
    state["libraryGoals"].append(goal)
    save_state(state)
    return {"created": goal}


def apply_library_goal_updates(goal: dict[str, Any], arguments: dict[str, Any]) -> dict[str, Any]:
    updated = dict(goal)

    if "new_title" in arguments:
        updated["title"] = arguments["new_title"].strip()
    if "new_target_year" in arguments:
        updated["targetYear"] = int(arguments["new_target_year"])
    if "new_type" in arguments:
        updated["type"] = normalize_library_type(arguments["new_type"])
    if "status" in arguments:
        updated["status"] = normalize_goal_status(arguments.get("status"))
    if "is_favorite" in arguments:
        updated["isFavorite"] = bool(arguments["is_favorite"])
    if "cover_url" in arguments:
        updated["coverUrl"] = (arguments.get("cover_url") or "").strip() or None
    if arguments.get("clear_cover_url"):
        updated["coverUrl"] = None
    if "note" in arguments:
        updated["note"] = (arguments.get("note") or "").strip() or None
    if arguments.get("clear_note"):
        updated["note"] = None
    if "platform" in arguments:
        updated["platform"] = (arguments.get("platform") or "").strip() or None
    if arguments.get("clear_platform"):
        updated["platform"] = None
    if "author" in arguments:
        updated["author"] = (arguments.get("author") or "").strip() or None
    if arguments.get("clear_author"):
        updated["author"] = None
    if "media_type" in arguments:
        updated["mediaType"] = normalize_media_type(arguments.get("media_type"))
    if arguments.get("clear_media_type"):
        updated["mediaType"] = None
    if "release_year" in arguments:
        updated["releaseYear"] = int(arguments["release_year"])
    if arguments.get("clear_release_year"):
        updated["releaseYear"] = None
    if "creator_or_director" in arguments:
        updated["creatorOrDirector"] = (
            arguments.get("creator_or_director") or ""
        ).strip() or None
    if arguments.get("clear_creator_or_director"):
        updated["creatorOrDirector"] = None

    updated["updatedAt"] = now_iso()
    return updated


def update_library_goal_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    index = find_library_goal_index(state, arguments)
    goal = apply_library_goal_updates(state["libraryGoals"][index], arguments)
    state["libraryGoals"][index] = goal
    save_state(state)
    return {"updated": goal}


def bulk_create_library_goals_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_library_goal_lists(state)
    replace_year = arguments.get("replace_year")
    if replace_year is not None:
        state["libraryGoals"] = [
            goal
            for goal in state["libraryGoals"]
            if int(goal.get("targetYear", 0)) != int(replace_year)
        ]
    created = [library_goal_from_args(goal) for goal in arguments["goals"]]
    state["libraryGoals"].extend(created)
    save_state(state)
    return {"created": created, "count": len(created)}


def bulk_upsert_library_goals_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_library_goal_lists(state)
    created = []
    updated = []

    for raw_goal in arguments["goals"]:
        goal_type = normalize_library_type(raw_goal["type"])
        title = raw_goal["title"].strip().lower()
        target_year = int(raw_goal["target_year"])
        match_index = None
        for index, existing in enumerate(state["libraryGoals"]):
            if existing.get("type") != goal_type:
                continue
            if str(existing.get("title", "")).strip().lower() != title:
                continue
            if int(existing.get("targetYear", 0)) != target_year:
                continue
            match_index = index
            break

        if match_index is None:
            goal = library_goal_from_args(raw_goal)
            state["libraryGoals"].append(goal)
            created.append(goal)
            continue

        goal = apply_library_goal_updates(state["libraryGoals"][match_index], raw_goal)
        state["libraryGoals"][match_index] = goal
        updated.append(goal)

    save_state(state)
    return {
        "created": created,
        "updated": updated,
        "created_count": len(created),
        "updated_count": len(updated),
    }


def clear_library_goals_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_library_goal_lists(state)
    before = len(state["libraryGoals"])
    if "target_year" in arguments:
        target_year = int(arguments["target_year"])
        state["libraryGoals"] = [
            goal
            for goal in state["libraryGoals"]
            if int(goal.get("targetYear", 0)) != target_year
        ]
    else:
        state["libraryGoals"] = []
    save_state(state)
    return {"deleted": before - len(state["libraryGoals"])}


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
    if name == "list_categories":
        return json_result(list_categories_impl())
    if name == "list_library_goals":
        return json_result(list_library_goals_impl(arguments))
    if name == "create_library_goal":
        return json_result(create_library_goal_impl(arguments))
    if name == "bulk_create_library_goals":
        return json_result(bulk_create_library_goals_impl(arguments))
    if name == "update_library_goal":
        return json_result(update_library_goal_impl(arguments))
    if name == "bulk_upsert_library_goals":
        return json_result(bulk_upsert_library_goals_impl(arguments))
    if name == "clear_library_goals":
        return json_result(clear_library_goals_impl(arguments))
    if name == "create_category":
        return json_result(create_category_impl(arguments))
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
