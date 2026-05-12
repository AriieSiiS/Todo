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


STATE_PATH_OVERRIDE = os.environ.get("TODO_MCP_STATE_PATH")
if STATE_PATH_OVERRIDE:
    STATE_PATH = Path(STATE_PATH_OVERRIDE)
    RUNTIME_DIR = STATE_PATH.parent
else:
    RUNTIME_DIR = documents_todo_dir() / "runtime"
    STATE_PATH = RUNTIME_DIR / "todo_state.json"
REPO_SUPABASE_URL = "https://hgdzwoieicreenpapese.supabase.co"
REPO_PUBLISHABLE_KEY = "sb_publishable_7QgBLNA353YvBgI2dPlnaw_R_tkfjtS"
REPO_OWNER_EMAIL = "ariesix20@gmail.com"
APP_PREFS_PATH = Path(
    os.environ.get(
        "TODO_MCP_PREFS_PATH",
        str(
            Path(os.environ.get("APPDATA", ""))
            / "com.example"
            / "todo"
            / "shared_preferences.json"
        ),
    )
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
    if os.environ.get("TODO_MCP_DISABLE_REMOTE") == "1":
        return False
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
        "navOrder": [
            "today",
            "projects",
            "categories",
            "expenses",
            "calendar",
            "library",
            "completed",
            "settings",
        ],
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


def write_app_snapshot(state: dict[str, Any]) -> None:
    if not APP_PREFS_PATH.exists():
        return
    try:
        prefs = json.loads(APP_PREFS_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return
    prefs["flutter.todo.snapshot.v1"] = json.dumps(state, ensure_ascii=False)
    temp = APP_PREFS_PATH.with_suffix(".tmp")
    temp.write_text(json.dumps(prefs, indent=2, ensure_ascii=False), encoding="utf-8")
    temp.replace(APP_PREFS_PATH)


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
            write_app_snapshot(state)
            return state
        local = read_local_state()
        write_remote_state(local)
        write_app_snapshot(local)
        return local
    return read_local_state()


def save_state(state: dict[str, Any]) -> None:
    touch_state(state)
    write_local_state(state)
    write_app_snapshot(state)
    if remote_enabled():
        write_remote_state(state)


def touch_state(state: dict[str, Any]) -> None:
    state["updatedAt"] = now_iso()
    state["schemaVersion"] = int(state.get("schemaVersion", 1) or 1)
    credentials = remote_credentials() if remote_enabled() else None
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
            "name": "list_expenses",
            "description": "Lista gastos, con filtros opcionales por ano, mes, categoria, metodo de pago o proyecto.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "year": {"type": "integer"},
                    "month": {"type": "integer"},
                    "category_id": {"type": "string"},
                    "payment_method_id": {"type": "string"},
                    "project_id": {"type": "string"},
                },
            },
        },
        {
            "name": "create_expense",
            "description": "Crea un gasto en Gastos y pagos.",
            "inputSchema": {
                "type": "object",
                "required": ["date", "concept", "amount", "category_id"],
                "properties": {
                    "date": {"type": "string", "description": "Fecha YYYY-MM-DD."},
                    "concept": {"type": "string"},
                    "amount": {"type": "number"},
                    "category_id": {"type": "string"},
                    "payment_method_id": {"type": "string"},
                    "project_ids": {"type": "array", "items": {"type": "string"}},
                    "note": {"type": "string"},
                    "is_recurring_instance": {"type": "boolean"},
                    "fixed_payment_id": {"type": "string"},
                },
            },
        },
        {
            "name": "update_expense",
            "description": "Actualiza un gasto existente.",
            "inputSchema": {
                "type": "object",
                "required": ["expense_id"],
                "properties": {
                    "expense_id": {"type": "string"},
                    "date": {"type": "string", "description": "Fecha YYYY-MM-DD."},
                    "concept": {"type": "string"},
                    "amount": {"type": "number"},
                    "category_id": {"type": "string"},
                    "payment_method_id": {"type": "string"},
                    "clear_payment_method_id": {"type": "boolean"},
                    "project_ids": {"type": "array", "items": {"type": "string"}},
                    "note": {"type": "string"},
                    "clear_note": {"type": "boolean"},
                    "is_recurring_instance": {"type": "boolean"},
                    "fixed_payment_id": {"type": "string"},
                    "clear_fixed_payment_id": {"type": "boolean"},
                },
            },
        },
        {
            "name": "delete_expense",
            "description": "Borra un gasto.",
            "inputSchema": {
                "type": "object",
                "required": ["expense_id"],
                "properties": {"expense_id": {"type": "string"}},
            },
        },
        {
            "name": "list_expense_categories",
            "description": "Lista categorias de gasto.",
            "inputSchema": {"type": "object", "properties": {"include_inactive": {"type": "boolean"}}},
        },
        {
            "name": "create_expense_category",
            "description": "Crea una categoria de gasto.",
            "inputSchema": {
                "type": "object",
                "required": ["name"],
                "properties": {
                    "name": {"type": "string"},
                    "color_value": {"type": "integer"},
                    "icon_code_point": {"type": "integer"},
                    "is_active": {"type": "boolean"},
                },
            },
        },
        {
            "name": "update_expense_category",
            "description": "Actualiza una categoria de gasto.",
            "inputSchema": {
                "type": "object",
                "required": ["category_id"],
                "properties": {
                    "category_id": {"type": "string"},
                    "name": {"type": "string"},
                    "color_value": {"type": "integer"},
                    "icon_code_point": {"type": "integer"},
                    "is_active": {"type": "boolean"},
                },
            },
        },
        {
            "name": "delete_expense_category",
            "description": "Borra o desactiva una categoria de gasto. Si hay gastos vinculados, usa replacement_category_id o deactivate=true.",
            "inputSchema": {
                "type": "object",
                "required": ["category_id"],
                "properties": {
                    "category_id": {"type": "string"},
                    "replacement_category_id": {"type": "string"},
                    "deactivate": {"type": "boolean"},
                },
            },
        },
        {
            "name": "list_payment_methods",
            "description": "Lista metodos de pago.",
            "inputSchema": {"type": "object", "properties": {"include_inactive": {"type": "boolean"}}},
        },
        {
            "name": "create_payment_method",
            "description": "Crea un metodo de pago.",
            "inputSchema": {
                "type": "object",
                "required": ["name"],
                "properties": {
                    "name": {"type": "string"},
                    "color_value": {"type": "integer"},
                    "icon_code_point": {"type": "integer"},
                    "is_active": {"type": "boolean"},
                },
            },
        },
        {
            "name": "update_payment_method",
            "description": "Actualiza un metodo de pago.",
            "inputSchema": {
                "type": "object",
                "required": ["payment_method_id"],
                "properties": {
                    "payment_method_id": {"type": "string"},
                    "name": {"type": "string"},
                    "color_value": {"type": "integer"},
                    "icon_code_point": {"type": "integer"},
                    "is_active": {"type": "boolean"},
                },
            },
        },
        {
            "name": "delete_payment_method",
            "description": "Borra o desactiva un metodo de pago. Si hay gastos o pagos fijos vinculados, usa replacement_payment_method_id o deactivate=true.",
            "inputSchema": {
                "type": "object",
                "required": ["payment_method_id"],
                "properties": {
                    "payment_method_id": {"type": "string"},
                    "replacement_payment_method_id": {"type": "string"},
                    "deactivate": {"type": "boolean"},
                },
            },
        },
        {
            "name": "list_fixed_payments",
            "description": "Lista pagos fijos.",
            "inputSchema": {"type": "object", "properties": {"include_inactive": {"type": "boolean"}}},
        },
        {
            "name": "create_fixed_payment",
            "description": "Crea un pago fijo.",
            "inputSchema": {
                "type": "object",
                "required": ["name", "amount", "category_id", "next_payment_date"],
                "properties": {
                    "name": {"type": "string"},
                    "amount": {"type": "number"},
                    "category_id": {"type": "string"},
                    "payment_method_id": {"type": "string"},
                    "frequency": {"type": "string", "description": "weekly, monthly, yearly o custom."},
                    "custom_interval": {"type": "string"},
                    "next_payment_date": {"type": "string", "description": "Fecha YYYY-MM-DD."},
                    "note": {"type": "string"},
                    "is_active": {"type": "boolean"},
                },
            },
        },
        {
            "name": "update_fixed_payment",
            "description": "Actualiza un pago fijo.",
            "inputSchema": {
                "type": "object",
                "required": ["fixed_payment_id"],
                "properties": {
                    "fixed_payment_id": {"type": "string"},
                    "name": {"type": "string"},
                    "amount": {"type": "number"},
                    "category_id": {"type": "string"},
                    "payment_method_id": {"type": "string"},
                    "clear_payment_method_id": {"type": "boolean"},
                    "frequency": {"type": "string"},
                    "custom_interval": {"type": "string"},
                    "clear_custom_interval": {"type": "boolean"},
                    "next_payment_date": {"type": "string"},
                    "note": {"type": "string"},
                    "clear_note": {"type": "boolean"},
                    "is_active": {"type": "boolean"},
                },
            },
        },
        {
            "name": "delete_fixed_payment",
            "description": "Borra un pago fijo.",
            "inputSchema": {
                "type": "object",
                "required": ["fixed_payment_id"],
                "properties": {"fixed_payment_id": {"type": "string"}},
            },
        },
        {
            "name": "create_expense_from_fixed_payment",
            "description": "Crea una instancia de gasto a partir de un pago fijo.",
            "inputSchema": {
                "type": "object",
                "required": ["fixed_payment_id"],
                "properties": {
                    "fixed_payment_id": {"type": "string"},
                    "date": {"type": "string", "description": "Fecha opcional YYYY-MM-DD; si se omite usa nextPaymentDate."},
                },
            },
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
            "name": "list_library_items",
            "description": "Lista elementos completados de Biblioteca, con filtros opcionales por ano y tipo.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "completed_year": {"type": "integer"},
                    "type": {
                        "type": "string",
                        "description": "game, book o movieSeries.",
                    },
                },
            },
        },
        {
            "name": "bulk_upsert_library_items",
            "description": "Crea o actualiza varios elementos completados de Biblioteca sin duplicarlos.",
            "inputSchema": {
                "type": "object",
                "required": ["items"],
                "properties": {
                    "items": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "required": ["type", "title"],
                            "properties": {
                                "type": {"type": "string"},
                                "title": {"type": "string"},
                                "completed_date": {
                                    "type": "string",
                                    "description": "Fecha YYYY-MM-DD. Si se omite, usa hoy.",
                                },
                                "cover_url": {"type": "string"},
                                "clear_cover_url": {"type": "boolean"},
                                "rating": {"type": "number"},
                                "clear_rating": {"type": "boolean"},
                                "note": {"type": "string"},
                                "clear_note": {"type": "boolean"},
                                "platform": {"type": "string"},
                                "clear_platform": {"type": "boolean"},
                                "developer": {"type": "string"},
                                "clear_developer": {"type": "boolean"},
                                "author": {"type": "string"},
                                "clear_author": {"type": "boolean"},
                                "media_type": {"type": "string"},
                                "clear_media_type": {"type": "boolean"},
                                "release_year": {"type": "integer"},
                                "clear_release_year": {"type": "boolean"},
                                "creator_or_director": {"type": "string"},
                                "clear_creator_or_director": {"type": "boolean"},
                                "genre": {"type": "string"},
                                "clear_genre": {"type": "boolean"},
                                "format": {"type": "string"},
                                "clear_format": {"type": "boolean"},
                                "duration": {"type": "string"},
                                "clear_duration": {"type": "boolean"},
                                "pages": {"type": "string"},
                                "clear_pages": {"type": "boolean"},
                                "country": {"type": "string"},
                                "clear_country": {"type": "boolean"},
                            },
                        },
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
                    "developer": {"type": "string"},
                    "author": {"type": "string"},
                    "media_type": {"type": "string"},
                    "release_year": {"type": "integer"},
                    "creator_or_director": {"type": "string"},
                    "genre": {"type": "string"},
                    "format": {"type": "string"},
                    "duration": {"type": "string"},
                    "pages": {"type": "string"},
                    "country": {"type": "string"},
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
                                "developer": {"type": "string"},
                                "author": {"type": "string"},
                                "media_type": {"type": "string"},
                                "release_year": {"type": "integer"},
                                "creator_or_director": {"type": "string"},
                                "genre": {"type": "string"},
                                "format": {"type": "string"},
                                "duration": {"type": "string"},
                                "pages": {"type": "string"},
                                "country": {"type": "string"},
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
                    "developer": {"type": "string"},
                    "clear_developer": {"type": "boolean"},
                    "author": {"type": "string"},
                    "clear_author": {"type": "boolean"},
                    "media_type": {"type": "string"},
                    "clear_media_type": {"type": "boolean"},
                    "release_year": {"type": "integer"},
                    "clear_release_year": {"type": "boolean"},
                    "creator_or_director": {"type": "string"},
                    "clear_creator_or_director": {"type": "boolean"},
                    "genre": {"type": "string"},
                    "clear_genre": {"type": "boolean"},
                    "format": {"type": "string"},
                    "clear_format": {"type": "boolean"},
                    "duration": {"type": "string"},
                    "clear_duration": {"type": "boolean"},
                    "pages": {"type": "string"},
                    "clear_pages": {"type": "boolean"},
                    "country": {"type": "string"},
                    "clear_country": {"type": "boolean"},
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
                                "developer": {"type": "string"},
                                "clear_developer": {"type": "boolean"},
                                "author": {"type": "string"},
                                "clear_author": {"type": "boolean"},
                                "media_type": {"type": "string"},
                                "clear_media_type": {"type": "boolean"},
                                "release_year": {"type": "integer"},
                                "clear_release_year": {"type": "boolean"},
                                "creator_or_director": {"type": "string"},
                                "clear_creator_or_director": {"type": "boolean"},
                                "genre": {"type": "string"},
                                "clear_genre": {"type": "boolean"},
                                "format": {"type": "string"},
                                "clear_format": {"type": "boolean"},
                                "duration": {"type": "string"},
                                "clear_duration": {"type": "boolean"},
                                "pages": {"type": "string"},
                                "clear_pages": {"type": "boolean"},
                                "country": {"type": "string"},
                                "clear_country": {"type": "boolean"},
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
    ] + extra_tool_definitions()


def extra_tool_definitions() -> list[dict[str, Any]]:
    string = {"type": "string"}
    integer = {"type": "integer"}
    number = {"type": "number"}
    boolean = {"type": "boolean"}
    strings = {"type": "array", "items": string}
    integers = {"type": "array", "items": integer}

    task_fields = {
        "task_id": string,
        "task_ids": strings,
        "title": string,
        "description": string,
        "scheduled_at": string,
        "date": string,
        "priority": string,
        "status": string,
        "category_ids": strings,
        "project_ids": strings,
        "materials": strings,
        "checklist": strings,
        "collapsed": boolean,
        "manual_order": number,
        "ordered_ids": strings,
        "recurrence_type": string,
        "recurrence_interval": integer,
        "recurrence_weekdays": integers,
        "reminder_enabled": boolean,
        "reminder_minutes_before": integer,
        "reminder_trigger_mode": string,
        "reminder_fires_at_day_start": boolean,
        "reminder_fires_at_day_end": boolean,
        "confirm": boolean,
    }
    library_fields = {
        "item_id": string,
        "goal_id": string,
        "type": string,
        "title": string,
        "target_year": integer,
        "completed_year": integer,
        "completed_date": string,
        "status": string,
        "is_favorite": boolean,
        "cover_url": string,
        "rating": number,
        "note": string,
        "platform": string,
        "developer": string,
        "author": string,
        "media_type": string,
        "release_year": integer,
        "creator_or_director": string,
        "genre": string,
        "format": string,
        "duration": string,
        "pages": string,
        "country": string,
        "confirm": boolean,
    }

    return [
        tool("delete_task", "Borra una tarea y limpia referencias de subtareas.", {"task_id": string}, ["task_id"]),
        tool("reopen_task", "Reabre una tarea completada.", {"task_id": string}, ["task_id"]),
        tool("bulk_complete_tasks", "Completa varias tareas.", {"task_ids": strings}, ["task_ids"]),
        tool("bulk_reopen_tasks", "Reabre varias tareas.", {"task_ids": strings}, ["task_ids"]),
        tool("bulk_delete_tasks", "Borra varias tareas.", {"task_ids": strings, "confirm": boolean}, ["task_ids", "confirm"]),
        tool("bulk_move_tasks_to_day", "Mueve varias tareas a un dia.", {"task_ids": strings, "date": string}, ["task_ids", "date"]),
        tool("reorder_tasks", "Actualiza el orden manual de una lista de tareas.", {"ordered_ids": strings}, ["ordered_ids"]),
        tool("create_subtask", "Crea una subtarea vinculada a una tarea padre.", {"parent_task_id": string, "title": string}, ["parent_task_id", "title"]),
        tool("set_task_reminder", "Configura el recordatorio de una tarea.", task_fields, ["task_id"]),
        tool("clear_task_reminder", "Elimina el recordatorio de una tarea.", {"task_id": string}, ["task_id"]),
        tool("update_project", "Actualiza un proyecto.", {"project_id": string, "name": string, "description": string, "color_value": integer, "icon_code_point": integer, "status": string, "category_ids": strings}, ["project_id"]),
        tool("set_project_status", "Cambia el estado de un proyecto.", {"project_id": string, "status": string}, ["project_id", "status"]),
        tool("complete_project", "Marca un proyecto como completado.", {"project_id": string}, ["project_id"]),
        tool("cancel_project", "Marca un proyecto como cancelado.", {"project_id": string}, ["project_id"]),
        tool("delete_project", "Borra un proyecto y limpia sus referencias en tareas.", {"project_id": string, "confirm": boolean}, ["project_id", "confirm"]),
        tool("update_category", "Actualiza una categoria.", {"category_id": string, "name": string, "description": string, "color_value": integer, "icon_code_point": integer, "active": boolean}, ["category_id"]),
        tool("toggle_category", "Activa o desactiva una categoria.", {"category_id": string}, ["category_id"]),
        tool("delete_category", "Borra una categoria y limpia sus referencias.", {"category_id": string, "confirm": boolean}, ["category_id", "confirm"]),
        tool("list_notes", "Lista notas de Entrada.", {"status": string}, []),
        tool("create_note", "Crea una nota rapida.", {"content": string, "scheduled_for": string}, ["content"]),
        tool("update_note", "Actualiza una nota.", {"note_id": string, "content": string, "scheduled_for": string, "clear_scheduled_for": boolean, "status": string}, ["note_id"]),
        tool("archive_note", "Archiva una nota.", {"note_id": string}, ["note_id"]),
        tool("convert_note_to_task", "Convierte una nota en tarea.", {"note_id": string, "title": string, "scheduled_at": string, "category_ids": strings, "project_ids": strings}, ["note_id"]),
        tool("convert_note_to_project", "Convierte una nota en proyecto.", {"note_id": string, "name": string, "category_ids": strings}, ["note_id"]),
        tool("convert_note_to_calendar_event", "Convierte una nota en evento local de calendario.", {"note_id": string, "title": string, "start_at": string, "end_at": string, "calendar_id": string}, ["note_id", "start_at", "end_at"]),
        tool("list_calendar_events", "Lista eventos de calendario por rango opcional.", {"from": string, "to": string}, []),
        tool("refresh_calendar_events", "Marca el refresco de calendario; requiere calendario conectado.", {}, []),
        tool("import_calendar_events_as_tasks", "Importa eventos locales de calendario como tareas.", {"from": string, "to": string}, []),
        tool("sync_task_to_calendar", "Marca/sincroniza una tarea con calendario conectado.", {"task_id": string}, ["task_id"]),
        tool("link_task_to_calendar_event", "Enlaza una tarea a un evento de calendario.", {"task_id": string, "calendar_id": string, "event_id": string, "sync_status": string}, ["task_id", "calendar_id", "event_id"]),
        tool("unlink_task_from_calendar_event", "Quita el enlace calendario de una tarea.", {"task_id": string}, ["task_id"]),
        tool("disconnect_calendar", "Desconecta calendario y limpia eventos/enlaces.", {"confirm": boolean}, ["confirm"]),
        tool("get_settings", "Devuelve ajustes de app, dia, notificaciones, calendario, navegacion y modo visual.", {}, []),
        tool("update_day_settings", "Actualiza ajustes de dia.", {"day_ends_at_hour": integer, "next_day_visible_at_hour": integer}, []),
        tool("update_notification_settings", "Actualiza ajustes de notificaciones.", {"notifications_enabled": boolean, "web_permission_granted": boolean, "windows_permission_granted": boolean, "day_start_reminder_enabled": boolean, "day_end_reminder_enabled": boolean, "default_minutes_before_task": integer}, []),
        tool("update_calendar_settings", "Actualiza ajustes de integracion de calendario.", {"web_client_id": string, "desktop_client_id": string, "desktop_client_secret": string, "selected_calendar_id": string, "selected_calendar_name": string, "connected_email": string, "connected": boolean, "last_error": string}, []),
        tool("set_today_sort", "Cambia el orden de Hoy.", {"today_sort": string}, ["today_sort"]),
        tool("set_visual_mode", "Cambia el modo visual.", {"visual_mode": string}, ["visual_mode"]),
        tool("reorder_navigation", "Actualiza el orden de navegacion lateral.", {"sections": strings}, ["sections"]),
        tool("sync_with_cloud", "Fuerza sincronizacion con nube si hay credenciales.", {}, []),
        tool("disconnect_cloud", "Desconecta la nube en el snapshot local.", {"confirm": boolean}, ["confirm"]),
        tool("duplicate_expense", "Duplica un gasto.", {"expense_id": string}, ["expense_id"]),
        tool("expense_totals", "Calcula totales de gastos.", {"year": integer, "month": integer, "group_by": string}, []),
        tool("export_financial_json", "Exporta datos financieros en JSON.", {}, []),
        tool("export_financial_csv", "Exporta gastos en CSV.", {}, []),
        tool("create_library_item", "Crea un item completado de Biblioteca.", library_fields, ["type", "title"]),
        tool("update_library_item", "Actualiza un item completado de Biblioteca.", library_fields, ["item_id"]),
        tool("delete_library_item", "Borra un item completado de Biblioteca.", {"item_id": string, "confirm": boolean}, ["item_id", "confirm"]),
        tool("delete_library_goal", "Borra un proposito de Biblioteca.", {"goal_id": string, "confirm": boolean}, ["goal_id", "confirm"]),
        tool("toggle_library_goal_completed", "Alterna pendiente/completado y sincroniza con Biblioteca.", {"goal_id": string}, ["goal_id"]),
        tool("toggle_library_goal_favorite", "Alterna favorito en un proposito.", {"goal_id": string}, ["goal_id"]),
    ]


def tool(name: str, description: str, properties: dict[str, Any], required: list[str]) -> dict[str, Any]:
    return {
        "name": name,
        "description": description,
        "inputSchema": {
            "type": "object",
            "properties": properties,
            **({"required": required} if required else {}),
        },
    }


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


def parse_date(value: str, field_name: str = "date") -> dt.date:
    try:
        return dt.date.fromisoformat(value.strip())
    except ValueError as error:
        raise ValueError(f"{field_name} debe usar formato YYYY-MM-DD.") from error


def date_iso(value: str, field_name: str = "date") -> str:
    parsed = parse_date(value, field_name)
    return dt.datetime.combine(parsed, dt.time()).isoformat()


def ensure_financial_lists(state: dict[str, Any]) -> None:
    state.setdefault("expenses", [])
    state.setdefault("expenseCategories", [])
    state.setdefault("paymentMethods", [])
    state.setdefault("fixedPayments", [])


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
    ensure_core_lists(state)
    ensure_task_refs(state, arguments.get("category_ids", []), arguments.get("project_ids", []))
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
        "priority": ensure_value(arguments.get("priority", "medium"), VALID_TASK_PRIORITIES, "priority"),
        "status": ensure_value(arguments.get("status", "active"), VALID_TASK_STATUSES, "status"),
        "recurrence": {
            "type": ensure_value(arguments.get("recurrence_type", "none"), VALID_RECURRENCE_TYPES, "recurrence_type"),
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
    ensure_core_lists(state)
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
        updated["priority"] = ensure_value(arguments["priority"], VALID_TASK_PRIORITIES, "priority")
    if "status" in arguments:
        updated["status"] = ensure_value(arguments["status"], VALID_TASK_STATUSES, "status")
        if updated["status"] == "completed":
            updated["completedAt"] = updated.get("completedAt") or now_iso()
        else:
            updated.pop("completedAt", None)
    if "category_ids" in arguments:
        ensure_task_refs(state, category_ids=arguments["category_ids"])
        updated["categoryIds"] = arguments["category_ids"]
    if "project_ids" in arguments:
        ensure_task_refs(state, project_ids=arguments["project_ids"])
        updated["projectIds"] = arguments["project_ids"]
    if "materials" in arguments:
        updated["materials"] = arguments["materials"]
    if "checklist" in arguments:
        updated["checklist"] = arguments["checklist"]
    if "collapsed" in arguments:
        updated["collapsed"] = bool(arguments["collapsed"])
    if "manual_order" in arguments:
        updated["manualOrder"] = float(arguments["manual_order"])
    if "recurrence_type" in arguments or "recurrence_interval" in arguments or "recurrence_weekdays" in arguments:
        recurrence = dict(updated.get("recurrence") or {"type": "none", "interval": 1, "weekdays": []})
        if "recurrence_type" in arguments:
            recurrence["type"] = ensure_value(arguments["recurrence_type"], VALID_RECURRENCE_TYPES, "recurrence_type")
        if "recurrence_interval" in arguments:
            recurrence["interval"] = int(arguments["recurrence_interval"])
        if "recurrence_weekdays" in arguments:
            recurrence["weekdays"] = arguments["recurrence_weekdays"]
        updated["recurrence"] = recurrence
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
    updated = task_with_completion(task, True)
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
    ensure_core_lists(state)
    ensure_task_refs(state, category_ids=arguments.get("category_ids", []))
    project = {
        "id": make_id("project"),
        "name": arguments["name"].strip(),
        "description": arguments.get("description", "").strip(),
        "colorValue": int(arguments.get("color_value", 0xFF607A5A)),
        "iconCodePoint": int(arguments.get("icon_code_point", 983108)),
        "status": ensure_value(arguments.get("status", "active"), VALID_PROJECT_STATUSES, "status"),
        "categoryIds": arguments.get("category_ids", []),
    }
    state["projects"].append(project)
    save_state(state)
    return {"created": project}


def find_by_id(items: list[dict[str, Any]], item_id: str, label: str) -> tuple[int, dict[str, Any]]:
    for index, item in enumerate(items):
        if item.get("id") == item_id:
            return index, item
    raise ValueError(f"No existe {label} '{item_id}'.")


def validate_expense_category(state: dict[str, Any], category_id: str) -> None:
    find_by_id(state["expenseCategories"], category_id, "la categoria de gasto")


def validate_payment_method(state: dict[str, Any], payment_method_id: str | None) -> None:
    if payment_method_id:
        find_by_id(state["paymentMethods"], payment_method_id, "el metodo de pago")


def normalize_frequency(value: str | None) -> str:
    if not value:
        return "monthly"
    normalized = value.strip()
    if normalized not in {"weekly", "monthly", "yearly", "custom"}:
        raise ValueError("frequency debe ser weekly, monthly, yearly o custom.")
    return normalized


def list_expenses_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_financial_lists(state)
    expenses = []
    for expense in state["expenses"]:
        parsed = parse_datetime(expense.get("date"))
        if "year" in arguments and (parsed is None or parsed.year != int(arguments["year"])):
            continue
        if "month" in arguments and (parsed is None or parsed.month != int(arguments["month"])):
            continue
        if "category_id" in arguments and expense.get("categoryId") != arguments["category_id"]:
            continue
        if "payment_method_id" in arguments and expense.get("paymentMethodId") != arguments["payment_method_id"]:
            continue
        if "project_id" in arguments and arguments["project_id"] not in expense.get("projectIds", []):
            continue
        expenses.append(expense)
    expenses.sort(key=lambda item: item.get("date", ""), reverse=True)
    return {"expenses": expenses, "count": len(expenses), "mode": "supabase" if remote_enabled() else "local"}


def create_expense_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_financial_lists(state)
    validate_expense_category(state, arguments["category_id"])
    validate_payment_method(state, arguments.get("payment_method_id"))
    now = now_iso()
    expense = {
        "id": make_id("expense"),
        "date": date_iso(arguments["date"]),
        "concept": arguments["concept"].strip() or "Gasto",
        "amount": float(arguments["amount"]),
        "categoryId": arguments["category_id"],
        "paymentMethodId": arguments.get("payment_method_id") or None,
        "projectIds": arguments.get("project_ids", []),
        "note": (arguments.get("note") or "").strip() or None,
        "isRecurringInstance": bool(arguments.get("is_recurring_instance", False)),
        "fixedPaymentId": arguments.get("fixed_payment_id") or None,
        "createdAt": now,
        "updatedAt": now,
    }
    state["expenses"].append(expense)
    save_state(state)
    return {"created": expense}


def update_expense_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_financial_lists(state)
    index, expense = find_by_id(state["expenses"], arguments["expense_id"], "el gasto")
    updated = copy.deepcopy(expense)
    if "date" in arguments:
        updated["date"] = date_iso(arguments["date"])
    if "concept" in arguments:
        updated["concept"] = arguments["concept"].strip() or "Gasto"
    if "amount" in arguments:
        updated["amount"] = float(arguments["amount"])
    if "category_id" in arguments:
        validate_expense_category(state, arguments["category_id"])
        updated["categoryId"] = arguments["category_id"]
    if arguments.get("clear_payment_method_id"):
        updated["paymentMethodId"] = None
    elif "payment_method_id" in arguments:
        validate_payment_method(state, arguments.get("payment_method_id"))
        updated["paymentMethodId"] = arguments.get("payment_method_id") or None
    if "project_ids" in arguments:
        updated["projectIds"] = arguments["project_ids"]
    if arguments.get("clear_note"):
        updated["note"] = None
    elif "note" in arguments:
        updated["note"] = (arguments.get("note") or "").strip() or None
    if "is_recurring_instance" in arguments:
        updated["isRecurringInstance"] = bool(arguments["is_recurring_instance"])
    if arguments.get("clear_fixed_payment_id"):
        updated["fixedPaymentId"] = None
    elif "fixed_payment_id" in arguments:
        updated["fixedPaymentId"] = arguments.get("fixed_payment_id") or None
    updated["updatedAt"] = now_iso()
    state["expenses"][index] = updated
    save_state(state)
    return {"updated": updated}


def delete_expense_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_financial_lists(state)
    index, expense = find_by_id(state["expenses"], arguments["expense_id"], "el gasto")
    del state["expenses"][index]
    save_state(state)
    return {"deleted": expense}


def list_expense_categories_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_financial_lists(state)
    include_inactive = bool(arguments.get("include_inactive", False))
    categories = [category for category in state["expenseCategories"] if include_inactive or category.get("isActive", True)]
    return {"expense_categories": categories, "count": len(categories)}


def create_expense_category_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_financial_lists(state)
    now = now_iso()
    category = {
        "id": make_id("expense-category"),
        "name": arguments["name"].strip(),
        "colorValue": int(arguments.get("color_value", 0xFF70835D)),
        "iconCodePoint": int(arguments.get("icon_code_point", 0xF0CA)),
        "isActive": bool(arguments.get("is_active", True)),
        "createdAt": now,
        "updatedAt": now,
    }
    state["expenseCategories"].append(category)
    save_state(state)
    return {"created": category}


def update_expense_category_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_financial_lists(state)
    index, category = find_by_id(state["expenseCategories"], arguments["category_id"], "la categoria de gasto")
    updated = copy.deepcopy(category)
    if "name" in arguments:
        updated["name"] = arguments["name"].strip()
    if "color_value" in arguments:
        updated["colorValue"] = int(arguments["color_value"])
    if "icon_code_point" in arguments:
        updated["iconCodePoint"] = int(arguments["icon_code_point"])
    if "is_active" in arguments:
        updated["isActive"] = bool(arguments["is_active"])
    updated["updatedAt"] = now_iso()
    state["expenseCategories"][index] = updated
    save_state(state)
    return {"updated": updated}


def delete_expense_category_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_financial_lists(state)
    category_id = arguments["category_id"]
    index, category = find_by_id(state["expenseCategories"], category_id, "la categoria de gasto")
    replacement_id = arguments.get("replacement_category_id")
    linked_expenses = [expense for expense in state["expenses"] if expense.get("categoryId") == category_id]
    linked_fixed = [payment for payment in state["fixedPayments"] if payment.get("categoryId") == category_id]
    if replacement_id:
        validate_expense_category(state, replacement_id)
        for expense in linked_expenses:
            expense["categoryId"] = replacement_id
            expense["updatedAt"] = now_iso()
        for payment in linked_fixed:
            payment["categoryId"] = replacement_id
            payment["updatedAt"] = now_iso()
    elif linked_expenses or linked_fixed:
        if arguments.get("deactivate", True):
            category["isActive"] = False
            category["updatedAt"] = now_iso()
            state["expenseCategories"][index] = category
            save_state(state)
            return {"deactivated": category, "linked_expenses": len(linked_expenses), "linked_fixed_payments": len(linked_fixed)}
        raise ValueError("La categoria tiene gastos o pagos fijos vinculados. Usa replacement_category_id o deactivate=true.")
    deleted = state["expenseCategories"].pop(index)
    save_state(state)
    return {"deleted": deleted}


def list_payment_methods_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_financial_lists(state)
    include_inactive = bool(arguments.get("include_inactive", False))
    methods = [method for method in state["paymentMethods"] if include_inactive or method.get("isActive", True)]
    return {"payment_methods": methods, "count": len(methods)}


def create_payment_method_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_financial_lists(state)
    now = now_iso()
    method = {
        "id": make_id("payment-method"),
        "name": arguments["name"].strip(),
        "iconCodePoint": int(arguments.get("icon_code_point", 0xE8A1)),
        "colorValue": int(arguments.get("color_value", 0xFF6C7B8E)),
        "isActive": bool(arguments.get("is_active", True)),
        "createdAt": now,
        "updatedAt": now,
    }
    state["paymentMethods"].append(method)
    save_state(state)
    return {"created": method}


def update_payment_method_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_financial_lists(state)
    index, method = find_by_id(state["paymentMethods"], arguments["payment_method_id"], "el metodo de pago")
    updated = copy.deepcopy(method)
    if "name" in arguments:
        updated["name"] = arguments["name"].strip()
    if "icon_code_point" in arguments:
        updated["iconCodePoint"] = int(arguments["icon_code_point"])
    if "color_value" in arguments:
        updated["colorValue"] = int(arguments["color_value"])
    if "is_active" in arguments:
        updated["isActive"] = bool(arguments["is_active"])
    updated["updatedAt"] = now_iso()
    state["paymentMethods"][index] = updated
    save_state(state)
    return {"updated": updated}


def delete_payment_method_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_financial_lists(state)
    method_id = arguments["payment_method_id"]
    index, method = find_by_id(state["paymentMethods"], method_id, "el metodo de pago")
    replacement_id = arguments.get("replacement_payment_method_id")
    linked_expenses = [expense for expense in state["expenses"] if expense.get("paymentMethodId") == method_id]
    linked_fixed = [payment for payment in state["fixedPayments"] if payment.get("paymentMethodId") == method_id]
    if replacement_id:
        validate_payment_method(state, replacement_id)
        for expense in linked_expenses:
            expense["paymentMethodId"] = replacement_id
            expense["updatedAt"] = now_iso()
        for payment in linked_fixed:
            payment["paymentMethodId"] = replacement_id
            payment["updatedAt"] = now_iso()
    elif linked_expenses or linked_fixed:
        if arguments.get("deactivate", True):
            method["isActive"] = False
            method["updatedAt"] = now_iso()
            state["paymentMethods"][index] = method
            save_state(state)
            return {"deactivated": method, "linked_expenses": len(linked_expenses), "linked_fixed_payments": len(linked_fixed)}
        raise ValueError("El metodo tiene gastos o pagos fijos vinculados. Usa replacement_payment_method_id o deactivate=true.")
    deleted = state["paymentMethods"].pop(index)
    save_state(state)
    return {"deleted": deleted}


def list_fixed_payments_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_financial_lists(state)
    include_inactive = bool(arguments.get("include_inactive", False))
    payments = [payment for payment in state["fixedPayments"] if include_inactive or payment.get("isActive", True)]
    payments.sort(key=lambda item: item.get("nextPaymentDate", ""))
    return {"fixed_payments": payments, "count": len(payments)}


def create_fixed_payment_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_financial_lists(state)
    validate_expense_category(state, arguments["category_id"])
    validate_payment_method(state, arguments.get("payment_method_id"))
    now = now_iso()
    payment = {
        "id": make_id("fixed-payment"),
        "name": arguments["name"].strip(),
        "amount": float(arguments["amount"]),
        "categoryId": arguments["category_id"],
        "paymentMethodId": arguments.get("payment_method_id") or None,
        "frequency": normalize_frequency(arguments.get("frequency")),
        "customInterval": (arguments.get("custom_interval") or "").strip() or None,
        "nextPaymentDate": date_iso(arguments["next_payment_date"], "next_payment_date"),
        "isActive": bool(arguments.get("is_active", True)),
        "note": (arguments.get("note") or "").strip() or None,
        "createdAt": now,
        "updatedAt": now,
    }
    state["fixedPayments"].append(payment)
    save_state(state)
    return {"created": payment}


def update_fixed_payment_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_financial_lists(state)
    index, payment = find_by_id(state["fixedPayments"], arguments["fixed_payment_id"], "el pago fijo")
    updated = copy.deepcopy(payment)
    if "name" in arguments:
        updated["name"] = arguments["name"].strip()
    if "amount" in arguments:
        updated["amount"] = float(arguments["amount"])
    if "category_id" in arguments:
        validate_expense_category(state, arguments["category_id"])
        updated["categoryId"] = arguments["category_id"]
    if arguments.get("clear_payment_method_id"):
        updated["paymentMethodId"] = None
    elif "payment_method_id" in arguments:
        validate_payment_method(state, arguments.get("payment_method_id"))
        updated["paymentMethodId"] = arguments.get("payment_method_id") or None
    if "frequency" in arguments:
        updated["frequency"] = normalize_frequency(arguments["frequency"])
    if arguments.get("clear_custom_interval"):
        updated["customInterval"] = None
    elif "custom_interval" in arguments:
        updated["customInterval"] = (arguments.get("custom_interval") or "").strip() or None
    if "next_payment_date" in arguments:
        updated["nextPaymentDate"] = date_iso(arguments["next_payment_date"], "next_payment_date")
    if "is_active" in arguments:
        updated["isActive"] = bool(arguments["is_active"])
    if arguments.get("clear_note"):
        updated["note"] = None
    elif "note" in arguments:
        updated["note"] = (arguments.get("note") or "").strip() or None
    updated["updatedAt"] = now_iso()
    state["fixedPayments"][index] = updated
    save_state(state)
    return {"updated": updated}


def delete_fixed_payment_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_financial_lists(state)
    index, payment = find_by_id(state["fixedPayments"], arguments["fixed_payment_id"], "el pago fijo")
    deleted = state["fixedPayments"].pop(index)
    for expense in state["expenses"]:
        if expense.get("fixedPaymentId") == deleted["id"]:
            expense["fixedPaymentId"] = None
            expense["updatedAt"] = now_iso()
    save_state(state)
    return {"deleted": deleted}


def create_expense_from_fixed_payment_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_financial_lists(state)
    _, payment = find_by_id(state["fixedPayments"], arguments["fixed_payment_id"], "el pago fijo")
    parsed_next = parse_datetime(payment["nextPaymentDate"]) or dt.datetime.now()
    expense_args = {
        "date": arguments.get("date") or parsed_next.date().isoformat(),
        "concept": payment["name"],
        "amount": payment["amount"],
        "category_id": payment["categoryId"],
        "payment_method_id": payment.get("paymentMethodId"),
        "note": payment.get("note"),
        "is_recurring_instance": True,
        "fixed_payment_id": payment["id"],
    }
    return create_expense_impl(expense_args)


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


def parse_completed_date(value: str | None) -> str:
    if not value:
        return now_iso()
    try:
        parsed = dt.date.fromisoformat(value.strip())
    except ValueError as error:
        raise ValueError("completed_date debe usar formato YYYY-MM-DD.") from error
    return dt.datetime.combine(parsed, dt.time(hour=12)).astimezone().isoformat()


def library_item_from_args(arguments: dict[str, Any]) -> dict[str, Any]:
    now = now_iso()
    return {
        "id": make_id("library"),
        "type": normalize_library_type(arguments["type"]),
        "title": arguments["title"].strip(),
        "completedDate": parse_completed_date(arguments.get("completed_date")),
        "coverUrl": (arguments.get("cover_url") or "").strip() or None,
        "rating": arguments.get("rating"),
        "note": (arguments.get("note") or "").strip() or None,
        "platform": (arguments.get("platform") or "").strip() or None,
        "developer": (arguments.get("developer") or "").strip() or None,
        "author": (arguments.get("author") or "").strip() or None,
        "mediaType": normalize_media_type(arguments.get("media_type")),
        "releaseYear": arguments.get("release_year"),
        "creatorOrDirector": (arguments.get("creator_or_director") or "").strip()
        or None,
        "genre": (arguments.get("genre") or "").strip() or None,
        "format": (arguments.get("format") or "").strip() or None,
        "duration": (arguments.get("duration") or "").strip() or None,
        "pages": (arguments.get("pages") or "").strip() or None,
        "country": (arguments.get("country") or "").strip() or None,
        "createdAt": now,
        "updatedAt": now,
    }


def apply_library_item_updates(item: dict[str, Any], arguments: dict[str, Any]) -> dict[str, Any]:
    updated = dict(item)
    if "completed_date" in arguments:
        updated["completedDate"] = parse_completed_date(arguments.get("completed_date"))
    if "cover_url" in arguments:
        updated["coverUrl"] = (arguments.get("cover_url") or "").strip() or None
    if arguments.get("clear_cover_url"):
        updated["coverUrl"] = None
    if "rating" in arguments:
        updated["rating"] = arguments.get("rating")
    if arguments.get("clear_rating"):
        updated["rating"] = None
    if "note" in arguments:
        updated["note"] = (arguments.get("note") or "").strip() or None
    if arguments.get("clear_note"):
        updated["note"] = None
    if "platform" in arguments:
        updated["platform"] = (arguments.get("platform") or "").strip() or None
    if arguments.get("clear_platform"):
        updated["platform"] = None
    if "developer" in arguments:
        updated["developer"] = (arguments.get("developer") or "").strip() or None
    if arguments.get("clear_developer"):
        updated["developer"] = None
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
    if "genre" in arguments:
        updated["genre"] = (arguments.get("genre") or "").strip() or None
    if arguments.get("clear_genre"):
        updated["genre"] = None
    if "format" in arguments:
        updated["format"] = (arguments.get("format") or "").strip() or None
    if arguments.get("clear_format"):
        updated["format"] = None
    if "duration" in arguments:
        updated["duration"] = (arguments.get("duration") or "").strip() or None
    if arguments.get("clear_duration"):
        updated["duration"] = None
    if "pages" in arguments:
        updated["pages"] = (arguments.get("pages") or "").strip() or None
    if arguments.get("clear_pages"):
        updated["pages"] = None
    if "country" in arguments:
        updated["country"] = (arguments.get("country") or "").strip() or None
    if arguments.get("clear_country"):
        updated["country"] = None
    updated["updatedAt"] = now_iso()
    return updated


def list_library_items_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_library_goal_lists(state)
    items = []
    for item in state["libraryItems"]:
        if "type" in arguments and item.get("type") != normalize_library_type(arguments["type"]):
            continue
        if "completed_year" in arguments:
            completed = dt.datetime.fromisoformat(item.get("completedDate", now_iso()))
            if completed.year != int(arguments["completed_year"]):
                continue
        items.append(item)
    return {"items": items, "count": len(items)}


def bulk_upsert_library_items_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_library_goal_lists(state)
    created = []
    updated = []
    for raw_item in arguments["items"]:
        item_type = normalize_library_type(raw_item["type"])
        title = raw_item["title"].strip().lower()
        match_index = None
        for index, existing in enumerate(state["libraryItems"]):
            if existing.get("type") != item_type:
                continue
            if str(existing.get("title", "")).strip().lower() != title:
                continue
            match_index = index
            break
        if match_index is None:
            item = library_item_from_args(raw_item)
            state["libraryItems"].append(item)
            created.append(item)
            continue
        item = apply_library_item_updates(state["libraryItems"][match_index], raw_item)
        state["libraryItems"][match_index] = item
        updated.append(item)
    save_state(state)
    return {
        "created": created,
        "updated": updated,
        "created_count": len(created),
        "updated_count": len(updated),
    }


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
        "developer": (arguments.get("developer") or "").strip() or None,
        "author": (arguments.get("author") or "").strip() or None,
        "mediaType": normalize_media_type(arguments.get("media_type")),
        "releaseYear": arguments.get("release_year"),
        "creatorOrDirector": (arguments.get("creator_or_director") or "").strip() or None,
        "genre": (arguments.get("genre") or "").strip() or None,
        "format": (arguments.get("format") or "").strip() or None,
        "duration": (arguments.get("duration") or "").strip() or None,
        "pages": (arguments.get("pages") or "").strip() or None,
        "country": (arguments.get("country") or "").strip() or None,
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
    synced_item = sync_completed_goal_to_item(state, goal)
    save_state(state)
    return {"created": goal, "synced_item": synced_item}


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
    if "developer" in arguments:
        updated["developer"] = (arguments.get("developer") or "").strip() or None
    if arguments.get("clear_developer"):
        updated["developer"] = None
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
    if "genre" in arguments:
        updated["genre"] = (arguments.get("genre") or "").strip() or None
    if arguments.get("clear_genre"):
        updated["genre"] = None
    if "format" in arguments:
        updated["format"] = (arguments.get("format") or "").strip() or None
    if arguments.get("clear_format"):
        updated["format"] = None
    if "duration" in arguments:
        updated["duration"] = (arguments.get("duration") or "").strip() or None
    if arguments.get("clear_duration"):
        updated["duration"] = None
    if "pages" in arguments:
        updated["pages"] = (arguments.get("pages") or "").strip() or None
    if arguments.get("clear_pages"):
        updated["pages"] = None
    if "country" in arguments:
        updated["country"] = (arguments.get("country") or "").strip() or None
    if arguments.get("clear_country"):
        updated["country"] = None

    updated["updatedAt"] = now_iso()
    return updated


def update_library_goal_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    index = find_library_goal_index(state, arguments)
    goal = apply_library_goal_updates(state["libraryGoals"][index], arguments)
    state["libraryGoals"][index] = goal
    synced_item = sync_completed_goal_to_item(state, goal)
    save_state(state)
    return {"updated": goal, "synced_item": synced_item}


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
    synced_items = [item for goal in created if (item := sync_completed_goal_to_item(state, goal)) is not None]
    save_state(state)
    return {"created": created, "count": len(created), "synced_items": synced_items}


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
            sync_completed_goal_to_item(state, goal)
            continue

        goal = apply_library_goal_updates(state["libraryGoals"][match_index], raw_goal)
        state["libraryGoals"][match_index] = goal
        updated.append(goal)
        sync_completed_goal_to_item(state, goal)

    save_state(state)
    return {
        "created": created,
        "updated": updated,
        "created_count": len(created),
        "updated_count": len(updated),
    }


def clear_library_goals_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    require_confirm(arguments, "clear_library_goals")
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


VALID_TASK_PRIORITIES = {"low", "medium", "high", "urgent"}
VALID_TASK_STATUSES = {"active", "completed", "archived"}
VALID_PROJECT_STATUSES = {"active", "paused", "completed", "cancelled"}
VALID_NOTE_STATUSES = {"inbox", "converted", "archived"}
VALID_RECURRENCE_TYPES = {"none", "daily", "everyXDays", "weekly", "yearly"}
VALID_TODAY_SORTS = {"manual", "category", "time", "project", "priority"}
VALID_VISUAL_MODES = {"classic", "phantom"}
VALID_SECTIONS = {"today", "projects", "inbox", "categories", "expenses", "calendar", "library", "completed", "settings"}


def require_confirm(arguments: dict[str, Any], action: str) -> None:
    if not arguments.get("confirm"):
        raise ValueError(f"{action} es una operacion peligrosa. Repite la llamada con confirm=true.")


def ensure_core_lists(state: dict[str, Any]) -> None:
    for key in (
        "tasks",
        "categories",
        "projects",
        "notes",
        "calendarEvents",
        "libraryItems",
        "libraryGoals",
    ):
        state.setdefault(key, [])
    state.setdefault("daySettings", {"dayEndsAtHour": 5, "nextDayVisibleAtHour": 10})
    state.setdefault("notificationSettings", default_state()["notificationSettings"])
    state.setdefault("calendarSettings", default_state()["calendarSettings"])


def ensure_value(value: str, valid: set[str], label: str) -> str:
    normalized = value.strip()
    if normalized not in valid:
        raise ValueError(f"{label} no valido. Usa uno de: {', '.join(sorted(valid))}.")
    return normalized


def ensure_task_refs(state: dict[str, Any], category_ids: list[str] | None = None, project_ids: list[str] | None = None) -> None:
    for category_id in category_ids or []:
        find_by_id(state["categories"], category_id, "la categoria")
    for project_id in project_ids or []:
        find_by_id(state["projects"], project_id, "el proyecto")


def task_with_completion(task: dict[str, Any], completed: bool) -> dict[str, Any]:
    updated = copy.deepcopy(task)
    updated["status"] = "completed" if completed else "active"
    if completed:
        updated["completedAt"] = now_iso()
    else:
        updated.pop("completedAt", None)
    if updated.get("calendarLink"):
        updated["calendarLink"]["syncStatus"] = "pending"
    return updated


def delete_task_from_state(state: dict[str, Any], task_id: str) -> dict[str, Any]:
    index, task = find_task(state, task_id)
    nested_ids = {task_id, *task.get("subtaskIds", [])}
    deleted = [item for item in state["tasks"] if item.get("id") in nested_ids or item.get("parentTaskId") == task_id]
    deleted_ids = {item["id"] for item in deleted}
    del state["tasks"][index]
    state["tasks"] = [item for item in state["tasks"] if item.get("id") not in deleted_ids]
    for item in state["tasks"]:
        item["subtaskIds"] = [sub_id for sub_id in item.get("subtaskIds", []) if sub_id not in deleted_ids]
    return {"deleted": deleted, "deleted_count": len(deleted)}


def delete_task_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_core_lists(state)
    result = delete_task_from_state(state, arguments["task_id"])
    save_state(state)
    return result


def reopen_task_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    index, task = find_task(state, arguments["task_id"])
    updated = task_with_completion(task, False)
    state["tasks"][index] = updated
    save_state(state)
    return {"reopened": updated}


def bulk_complete_tasks_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    completed = []
    for task_id in arguments["task_ids"]:
        index, task = find_task(state, task_id)
        updated = task_with_completion(task, True)
        state["tasks"][index] = updated
        completed.append(updated)
    save_state(state)
    return {"completed": completed, "count": len(completed)}


def bulk_reopen_tasks_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    reopened = []
    for task_id in arguments["task_ids"]:
        index, task = find_task(state, task_id)
        updated = task_with_completion(task, False)
        state["tasks"][index] = updated
        reopened.append(updated)
    save_state(state)
    return {"reopened": reopened, "count": len(reopened)}


def bulk_delete_tasks_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    require_confirm(arguments, "bulk_delete_tasks")
    state = load_state()
    deleted = []
    for task_id in arguments["task_ids"]:
        if any(task.get("id") == task_id for task in state["tasks"]):
            deleted.extend(delete_task_from_state(state, task_id)["deleted"])
    save_state(state)
    return {"deleted": deleted, "count": len(deleted)}


def bulk_move_tasks_to_day_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    moved = []
    for task_id in arguments["task_ids"]:
        moved.append(move_task_to_day_impl({"task_id": task_id, "date": arguments["date"]})["moved"])
    return {"moved": moved, "count": len(moved)}


def reorder_tasks_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    changed = []
    for order, task_id in enumerate(arguments["ordered_ids"]):
        index, task = find_task(state, task_id)
        updated = copy.deepcopy(task)
        updated["manualOrder"] = float(order)
        state["tasks"][index] = updated
        changed.append(updated)
    save_state(state)
    return {"updated": changed, "count": len(changed)}


def create_subtask_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    return create_task_impl(
        {
            "title": arguments["title"],
            "parent_task_id": arguments["parent_task_id"],
            "scheduled_at": arguments.get("scheduled_at"),
            "priority": arguments.get("priority", "medium"),
        }
    )


def set_task_reminder_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    index, task = find_task(state, arguments["task_id"])
    updated = copy.deepcopy(task)
    updated["reminderRule"] = {
        "triggerMode": arguments.get("reminder_trigger_mode", "minutesBefore"),
        "minutesBefore": int(arguments.get("reminder_minutes_before", state.get("notificationSettings", {}).get("defaultMinutesBeforeTask", 30))),
        "firesAtDayStart": bool(arguments.get("reminder_fires_at_day_start", False)),
        "firesAtDayEnd": bool(arguments.get("reminder_fires_at_day_end", False)),
        "enabled": bool(arguments.get("reminder_enabled", True)),
    }
    state["tasks"][index] = updated
    save_state(state)
    return {"updated": updated}


def clear_task_reminder_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    index, task = find_task(state, arguments["task_id"])
    updated = copy.deepcopy(task)
    updated["reminderRule"] = None
    state["tasks"][index] = updated
    save_state(state)
    return {"updated": updated}


def update_project_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    index, project = find_by_id(state["projects"], arguments["project_id"], "el proyecto")
    updated = copy.deepcopy(project)
    if "name" in arguments:
        updated["name"] = arguments["name"].strip()
    if "description" in arguments:
        updated["description"] = arguments.get("description", "").strip()
    if "color_value" in arguments:
        updated["colorValue"] = int(arguments["color_value"])
    if "icon_code_point" in arguments:
        updated["iconCodePoint"] = int(arguments["icon_code_point"])
    if "status" in arguments:
        updated["status"] = ensure_value(arguments["status"], VALID_PROJECT_STATUSES, "status")
    if "category_ids" in arguments:
        ensure_task_refs(state, category_ids=arguments["category_ids"])
        updated["categoryIds"] = arguments["category_ids"]
    state["projects"][index] = updated
    save_state(state)
    return {"updated": updated}


def set_project_status_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    return update_project_impl({"project_id": arguments["project_id"], "status": arguments["status"]})


def delete_project_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    require_confirm(arguments, "delete_project")
    state = load_state()
    index, project = find_by_id(state["projects"], arguments["project_id"], "el proyecto")
    deleted = state["projects"].pop(index)
    for task in state["tasks"]:
        task["projectIds"] = [project_id for project_id in task.get("projectIds", []) if project_id != project["id"]]
    save_state(state)
    return {"deleted": deleted}


def update_category_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    index, category = find_by_id(state["categories"], arguments["category_id"], "la categoria")
    updated = copy.deepcopy(category)
    if "name" in arguments:
        updated["name"] = arguments["name"].strip()
    if "description" in arguments:
        updated["description"] = arguments.get("description", "").strip()
    if "color_value" in arguments:
        updated["colorValue"] = int(arguments["color_value"])
    if "icon_code_point" in arguments:
        updated["iconCodePoint"] = int(arguments["icon_code_point"])
    if "active" in arguments:
        updated["active"] = bool(arguments["active"])
    state["categories"][index] = updated
    save_state(state)
    return {"updated": updated}


def toggle_category_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    index, category = find_by_id(state["categories"], arguments["category_id"], "la categoria")
    updated = copy.deepcopy(category)
    updated["active"] = not bool(updated.get("active", True))
    state["categories"][index] = updated
    save_state(state)
    return {"updated": updated}


def delete_category_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    require_confirm(arguments, "delete_category")
    state = load_state()
    index, category = find_by_id(state["categories"], arguments["category_id"], "la categoria")
    deleted = state["categories"].pop(index)
    for task in state["tasks"]:
        task["categoryIds"] = [category_id for category_id in task.get("categoryIds", []) if category_id != deleted["id"]]
    for project in state["projects"]:
        project["categoryIds"] = [category_id for category_id in project.get("categoryIds", []) if category_id != deleted["id"]]
    save_state(state)
    return {"deleted": deleted}


def list_notes_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    notes = state.get("notes", [])
    if "status" in arguments:
        status = ensure_value(arguments["status"], VALID_NOTE_STATUSES, "status")
        notes = [note for note in notes if note.get("status") == status]
    return {"notes": notes, "count": len(notes)}


def create_note_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    note = {
        "id": make_id("note"),
        "content": arguments["content"].strip(),
        "createdAt": now_iso(),
        "status": "inbox",
        "scheduledFor": normalize_datetime(arguments.get("scheduled_for")),
    }
    state.setdefault("notes", []).insert(0, note)
    save_state(state)
    return {"created": note}


def update_note_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    index, note = find_by_id(state["notes"], arguments["note_id"], "la nota")
    updated = copy.deepcopy(note)
    if "content" in arguments:
        updated["content"] = arguments["content"].strip()
    if arguments.get("clear_scheduled_for"):
        updated["scheduledFor"] = None
    elif "scheduled_for" in arguments:
        updated["scheduledFor"] = normalize_datetime(arguments.get("scheduled_for"))
    if "status" in arguments:
        updated["status"] = ensure_value(arguments["status"], VALID_NOTE_STATUSES, "status")
    state["notes"][index] = updated
    save_state(state)
    return {"updated": updated}


def archive_note_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    return update_note_impl({"note_id": arguments["note_id"], "status": "archived"})


def mark_note_converted(state: dict[str, Any], note_id: str) -> None:
    index, note = find_by_id(state["notes"], note_id, "la nota")
    updated = copy.deepcopy(note)
    updated["status"] = "converted"
    state["notes"][index] = updated


def convert_note_to_task_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    _index, note = find_by_id(state["notes"], arguments["note_id"], "la nota")
    create_args = {
        "title": arguments.get("title") or note.get("content", "Nota"),
        "description": note.get("content"),
        "scheduled_at": arguments.get("scheduled_at") or note.get("scheduledFor"),
        "category_ids": arguments.get("category_ids", []),
        "project_ids": arguments.get("project_ids", []),
        "origin": "note",
    }
    task = create_task_impl(create_args)["created"]
    state = load_state()
    mark_note_converted(state, arguments["note_id"])
    save_state(state)
    return {"created": task}


def convert_note_to_project_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    _index, note = find_by_id(state["notes"], arguments["note_id"], "la nota")
    project = create_project_impl(
        {
            "name": arguments.get("name") or note.get("content", "Proyecto"),
            "description": note.get("content", ""),
            "category_ids": arguments.get("category_ids", []),
        }
    )["created"]
    state = load_state()
    mark_note_converted(state, arguments["note_id"])
    save_state(state)
    return {"created": project}


def convert_note_to_calendar_event_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    _index, note = find_by_id(state["notes"], arguments["note_id"], "la nota")
    event = {
        "id": make_id("calendar-event"),
        "calendarId": arguments.get("calendar_id", "local"),
        "title": arguments.get("title") or note.get("content", "Evento"),
        "startAt": normalize_datetime(arguments["start_at"]),
        "endAt": normalize_datetime(arguments["end_at"]),
        "description": note.get("content"),
        "originTaskId": None,
    }
    state.setdefault("calendarEvents", []).append(event)
    mark_note_converted(state, arguments["note_id"])
    save_state(state)
    return {"created": event}


def list_calendar_events_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    events = state.get("calendarEvents", [])
    start = parse_datetime(arguments.get("from")) if arguments.get("from") else None
    end = parse_datetime(arguments.get("to")) if arguments.get("to") else None
    if start or end:
        filtered = []
        for event in events:
            event_start = parse_datetime(event.get("startAt"))
            if event_start is None:
                continue
            if start and event_start < start:
                continue
            if end and event_start > end:
                continue
            filtered.append(event)
        events = filtered
    return {"events": events, "count": len(events)}


def require_calendar_connected(state: dict[str, Any]) -> None:
    if not state.get("calendarSettings", {}).get("connected"):
        raise ValueError("El calendario no esta conectado.")


def refresh_calendar_events_impl() -> dict[str, Any]:
    state = load_state()
    require_calendar_connected(state)
    return {"refreshed": True, "events": state.get("calendarEvents", []), "count": len(state.get("calendarEvents", []))}


def import_calendar_events_as_tasks_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    created = []
    start = parse_datetime(arguments.get("from")) if arguments.get("from") else None
    end = parse_datetime(arguments.get("to")) if arguments.get("to") else None
    for event in state.get("calendarEvents", []):
        event_start = parse_datetime(event.get("startAt"))
        if event_start is None:
            continue
        if start and event_start < start:
            continue
        if end and event_start > end:
            continue
        if any(task.get("calendarLink", {}).get("eventId") == event.get("id") for task in state["tasks"] if task.get("calendarLink")):
            continue
        task = {
            "id": make_id("task"),
            "title": event.get("title", "Evento"),
            "description": event.get("description"),
            "categoryIds": [],
            "projectIds": [],
            "scheduledAt": event.get("startAt"),
            "priority": "medium",
            "status": "active",
            "recurrence": {"type": "none", "interval": 1, "weekdays": []},
            "subtaskIds": [],
            "checklist": [],
            "materials": [],
            "origin": "calendar",
            "manualOrder": next_manual_order(state["tasks"]),
            "parentTaskId": None,
            "collapsed": False,
            "calendarLink": {"provider": "google", "calendarId": event.get("calendarId", "local"), "eventId": event.get("id"), "syncStatus": "synced", "lastSyncedAt": now_iso()},
            "reminderRule": None,
        }
        state["tasks"].append(task)
        created.append(task)
    save_state(state)
    return {"created": created, "count": len(created)}


def sync_task_to_calendar_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    require_calendar_connected(state)
    index, task = find_task(state, arguments["task_id"])
    updated = copy.deepcopy(task)
    link = updated.get("calendarLink") or {
        "provider": "google",
        "calendarId": state.get("calendarSettings", {}).get("selectedCalendarId", "primary"),
        "eventId": make_id("event"),
        "syncStatus": "pending",
        "lastSyncedAt": None,
    }
    link["syncStatus"] = "synced"
    link["lastSyncedAt"] = now_iso()
    updated["calendarLink"] = link
    state["tasks"][index] = updated
    save_state(state)
    return {"synced": updated}


def link_task_to_calendar_event_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    index, task = find_task(state, arguments["task_id"])
    updated = copy.deepcopy(task)
    updated["calendarLink"] = {
        "provider": "google",
        "calendarId": arguments["calendar_id"],
        "eventId": arguments["event_id"],
        "syncStatus": arguments.get("sync_status", "synced"),
        "lastSyncedAt": now_iso(),
    }
    state["tasks"][index] = updated
    save_state(state)
    return {"linked": updated}


def unlink_task_from_calendar_event_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    index, task = find_task(state, arguments["task_id"])
    updated = copy.deepcopy(task)
    updated["calendarLink"] = None
    state["tasks"][index] = updated
    save_state(state)
    return {"unlinked": updated}


def disconnect_calendar_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    require_confirm(arguments, "disconnect_calendar")
    state = load_state()
    state["calendarEvents"] = []
    state["calendarSettings"] = {**default_state()["calendarSettings"], "connected": False}
    for task in state.get("tasks", []):
        task["calendarLink"] = None
    save_state(state)
    return {"disconnected": True}


def get_settings_impl() -> dict[str, Any]:
    state = load_state()
    return {
        "daySettings": state.get("daySettings", {}),
        "notificationSettings": state.get("notificationSettings", {}),
        "calendarSettings": state.get("calendarSettings", {}),
        "section": state.get("section", "today"),
        "todaySort": state.get("todaySort", "manual"),
        "visualMode": state.get("visualMode", "classic"),
        "navOrder": state.get("navOrder", []),
    }


def update_day_settings_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    settings = dict(state.get("daySettings", default_state()["daySettings"]))
    if "day_ends_at_hour" in arguments:
        settings["dayEndsAtHour"] = int(arguments["day_ends_at_hour"])
    if "next_day_visible_at_hour" in arguments:
        settings["nextDayVisibleAtHour"] = int(arguments["next_day_visible_at_hour"])
    state["daySettings"] = settings
    save_state(state)
    return {"updated": settings}


def update_notification_settings_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    settings = dict(state.get("notificationSettings", default_state()["notificationSettings"]))
    mapping = {
        "notifications_enabled": "notificationsEnabled",
        "web_permission_granted": "webPermissionGranted",
        "windows_permission_granted": "windowsPermissionGranted",
        "day_start_reminder_enabled": "dayStartReminderEnabled",
        "day_end_reminder_enabled": "dayEndReminderEnabled",
        "default_minutes_before_task": "defaultMinutesBeforeTask",
    }
    for source, target in mapping.items():
        if source in arguments:
            settings[target] = int(arguments[source]) if source == "default_minutes_before_task" else bool(arguments[source])
    state["notificationSettings"] = settings
    save_state(state)
    return {"updated": settings}


def update_calendar_settings_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    settings = dict(state.get("calendarSettings", default_state()["calendarSettings"]))
    mapping = {
        "web_client_id": "webClientId",
        "desktop_client_id": "desktopClientId",
        "desktop_client_secret": "desktopClientSecret",
        "selected_calendar_id": "selectedCalendarId",
        "selected_calendar_name": "selectedCalendarName",
        "connected_email": "connectedEmail",
        "connected": "connected",
        "last_error": "lastError",
    }
    for source, target in mapping.items():
        if source in arguments:
            settings[target] = bool(arguments[source]) if source == "connected" else arguments[source]
    state["calendarSettings"] = settings
    save_state(state)
    return {"updated": settings}


def set_today_sort_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    state["todaySort"] = ensure_value(arguments["today_sort"], VALID_TODAY_SORTS, "today_sort")
    save_state(state)
    return {"todaySort": state["todaySort"]}


def set_visual_mode_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    state["visualMode"] = ensure_value(arguments["visual_mode"], VALID_VISUAL_MODES, "visual_mode")
    save_state(state)
    return {"visualMode": state["visualMode"]}


def reorder_navigation_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    sections = [ensure_value(section, VALID_SECTIONS, "section") for section in arguments["sections"]]
    state = load_state()
    state["navOrder"] = sections
    save_state(state)
    return {"navOrder": sections}


def sync_with_cloud_impl() -> dict[str, Any]:
    if not remote_enabled():
        raise ValueError("No hay credenciales remotas configuradas.")
    state = load_state()
    write_remote_state(state)
    return {"synced": True, "mode": "supabase"}


def disconnect_cloud_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    require_confirm(arguments, "disconnect_cloud")
    state = load_state()
    state["lastModifiedBy"] = "mcp"
    write_local_state(state)
    write_app_snapshot(state)
    return {"disconnected": True}


def duplicate_expense_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_financial_lists(state)
    _index, expense = find_by_id(state["expenses"], arguments["expense_id"], "el gasto")
    clone = copy.deepcopy(expense)
    clone["id"] = make_id("expense")
    clone["createdAt"] = now_iso()
    clone["updatedAt"] = now_iso()
    state["expenses"].append(clone)
    save_state(state)
    return {"created": clone}


def expense_totals_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    expenses = list_expenses_impl(arguments)["expenses"]
    total = sum(float(expense.get("amount", 0)) for expense in expenses)
    group_by = arguments.get("group_by")
    grouped: dict[str, float] = {}
    if group_by:
        key_map = {
            "category": "categoryId",
            "payment_method": "paymentMethodId",
            "project": "projectIds",
            "month": "date",
            "year": "date",
        }
        field = key_map.get(group_by)
        if field is None:
            raise ValueError("group_by debe ser category, payment_method, project, month o year.")
        for expense in expenses:
            amount = float(expense.get("amount", 0))
            if field == "projectIds":
                ids = expense.get("projectIds") or ["sin_proyecto"]
                for project_id in ids:
                    grouped[project_id] = grouped.get(project_id, 0.0) + amount
            elif field == "date":
                parsed = parse_datetime(expense.get("date"))
                key = f"{parsed.year:04d}-{parsed.month:02d}" if group_by == "month" and parsed else str(parsed.year if parsed else "sin_fecha")
                grouped[key] = grouped.get(key, 0.0) + amount
            else:
                key = expense.get(field) or "sin_valor"
                grouped[key] = grouped.get(key, 0.0) + amount
    return {"total": total, "count": len(expenses), "grouped": grouped}


def export_financial_json_impl() -> dict[str, Any]:
    state = load_state()
    ensure_financial_lists(state)
    return {
        "expenses": state["expenses"],
        "expenseCategories": state["expenseCategories"],
        "paymentMethods": state["paymentMethods"],
        "fixedPayments": state["fixedPayments"],
    }


def export_financial_csv_impl() -> dict[str, Any]:
    state = load_state()
    ensure_financial_lists(state)
    rows = ["date,concept,amount,category_id,payment_method_id,project_ids,note"]
    for expense in state["expenses"]:
        values = [
            expense.get("date", ""),
            expense.get("concept", ""),
            str(expense.get("amount", "")),
            expense.get("categoryId", ""),
            expense.get("paymentMethodId", "") or "",
            "|".join(expense.get("projectIds", [])),
            (expense.get("note") or "").replace("\n", " "),
        ]
        rows.append(",".join(json.dumps(value, ensure_ascii=False) for value in values))
    return {"csv": "\n".join(rows)}


def create_library_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_library_goal_lists(state)
    item = library_item_from_args(arguments)
    state["libraryItems"].append(item)
    save_state(state)
    return {"created": item}


def find_library_item(state: dict[str, Any], item_id: str) -> tuple[int, dict[str, Any]]:
    return find_by_id(state["libraryItems"], item_id, "el item de biblioteca")


def update_library_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_library_goal_lists(state)
    index, item = find_library_item(state, arguments["item_id"])
    updated = apply_library_item_updates(item, arguments)
    state["libraryItems"][index] = updated
    save_state(state)
    return {"updated": updated}


def delete_library_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    require_confirm(arguments, "delete_library_item")
    state = load_state()
    ensure_library_goal_lists(state)
    index, item = find_library_item(state, arguments["item_id"])
    deleted = state["libraryItems"].pop(index)
    save_state(state)
    return {"deleted": deleted}


def library_item_from_goal(goal: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": make_id("library_item"),
        "type": goal.get("type"),
        "title": goal.get("title"),
        "completedDate": now_iso(),
        "coverUrl": goal.get("coverUrl"),
        "rating": None,
        "note": goal.get("note"),
        "platform": goal.get("platform"),
        "developer": goal.get("developer"),
        "author": goal.get("author"),
        "mediaType": goal.get("mediaType"),
        "releaseYear": goal.get("releaseYear"),
        "creatorOrDirector": goal.get("creatorOrDirector"),
        "genre": goal.get("genre"),
        "format": goal.get("format"),
        "duration": goal.get("duration"),
        "pages": goal.get("pages"),
        "country": goal.get("country"),
        "createdAt": now_iso(),
        "updatedAt": now_iso(),
    }


def sync_completed_goal_to_item(state: dict[str, Any], goal: dict[str, Any]) -> dict[str, Any] | None:
    if goal.get("status") != "completed":
        return None
    for item in state["libraryItems"]:
        if item.get("type") == goal.get("type") and item.get("title", "").strip().lower() == goal.get("title", "").strip().lower():
            return item
    item = library_item_from_goal(goal)
    state["libraryItems"].append(item)
    return item


def delete_library_goal_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    require_confirm(arguments, "delete_library_goal")
    state = load_state()
    ensure_library_goal_lists(state)
    index, goal = find_by_id(state["libraryGoals"], arguments["goal_id"], "el proposito")
    deleted = state["libraryGoals"].pop(index)
    save_state(state)
    return {"deleted": deleted}


def toggle_library_goal_completed_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_library_goal_lists(state)
    index, goal = find_by_id(state["libraryGoals"], arguments["goal_id"], "el proposito")
    updated = copy.deepcopy(goal)
    updated["status"] = "pending" if updated.get("status") == "completed" else "completed"
    updated["updatedAt"] = now_iso()
    state["libraryGoals"][index] = updated
    item = sync_completed_goal_to_item(state, updated)
    save_state(state)
    return {"updated": updated, "synced_item": item}


def toggle_library_goal_favorite_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_library_goal_lists(state)
    index, goal = find_by_id(state["libraryGoals"], arguments["goal_id"], "el proposito")
    updated = copy.deepcopy(goal)
    updated["isFavorite"] = not bool(updated.get("isFavorite", False))
    updated["updatedAt"] = now_iso()
    state["libraryGoals"][index] = updated
    save_state(state)
    return {"updated": updated}


def import_state_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    require_confirm(arguments, "import_state")
    state = json.loads(arguments["raw_json"])
    save_state(state)
    return {"imported": True, "task_count": len(state.get("tasks", []))}


def reset_state_impl(arguments: dict[str, Any] | None = None) -> dict[str, Any]:
    require_confirm(arguments or {}, "reset_state")
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
    if name == "delete_task":
        return json_result(delete_task_impl(arguments))
    if name == "reopen_task":
        return json_result(reopen_task_impl(arguments))
    if name == "bulk_complete_tasks":
        return json_result(bulk_complete_tasks_impl(arguments))
    if name == "bulk_reopen_tasks":
        return json_result(bulk_reopen_tasks_impl(arguments))
    if name == "bulk_delete_tasks":
        return json_result(bulk_delete_tasks_impl(arguments))
    if name == "bulk_move_tasks_to_day":
        return json_result(bulk_move_tasks_to_day_impl(arguments))
    if name == "reorder_tasks":
        return json_result(reorder_tasks_impl(arguments))
    if name == "create_subtask":
        return json_result(create_subtask_impl(arguments))
    if name == "set_task_reminder":
        return json_result(set_task_reminder_impl(arguments))
    if name == "clear_task_reminder":
        return json_result(clear_task_reminder_impl(arguments))
    if name == "list_projects":
        return json_result(list_projects_impl())
    if name == "update_project":
        return json_result(update_project_impl(arguments))
    if name == "set_project_status":
        return json_result(set_project_status_impl(arguments))
    if name == "complete_project":
        return json_result(set_project_status_impl({"project_id": arguments["project_id"], "status": "completed"}))
    if name == "cancel_project":
        return json_result(set_project_status_impl({"project_id": arguments["project_id"], "status": "cancelled"}))
    if name == "delete_project":
        return json_result(delete_project_impl(arguments))
    if name == "list_categories":
        return json_result(list_categories_impl())
    if name == "update_category":
        return json_result(update_category_impl(arguments))
    if name == "toggle_category":
        return json_result(toggle_category_impl(arguments))
    if name == "delete_category":
        return json_result(delete_category_impl(arguments))
    if name == "list_notes":
        return json_result(list_notes_impl(arguments))
    if name == "create_note":
        return json_result(create_note_impl(arguments))
    if name == "update_note":
        return json_result(update_note_impl(arguments))
    if name == "archive_note":
        return json_result(archive_note_impl(arguments))
    if name == "convert_note_to_task":
        return json_result(convert_note_to_task_impl(arguments))
    if name == "convert_note_to_project":
        return json_result(convert_note_to_project_impl(arguments))
    if name == "convert_note_to_calendar_event":
        return json_result(convert_note_to_calendar_event_impl(arguments))
    if name == "list_calendar_events":
        return json_result(list_calendar_events_impl(arguments))
    if name == "refresh_calendar_events":
        return json_result(refresh_calendar_events_impl())
    if name == "import_calendar_events_as_tasks":
        return json_result(import_calendar_events_as_tasks_impl(arguments))
    if name == "sync_task_to_calendar":
        return json_result(sync_task_to_calendar_impl(arguments))
    if name == "link_task_to_calendar_event":
        return json_result(link_task_to_calendar_event_impl(arguments))
    if name == "unlink_task_from_calendar_event":
        return json_result(unlink_task_from_calendar_event_impl(arguments))
    if name == "disconnect_calendar":
        return json_result(disconnect_calendar_impl(arguments))
    if name == "get_settings":
        return json_result(get_settings_impl())
    if name == "update_day_settings":
        return json_result(update_day_settings_impl(arguments))
    if name == "update_notification_settings":
        return json_result(update_notification_settings_impl(arguments))
    if name == "update_calendar_settings":
        return json_result(update_calendar_settings_impl(arguments))
    if name == "set_today_sort":
        return json_result(set_today_sort_impl(arguments))
    if name == "set_visual_mode":
        return json_result(set_visual_mode_impl(arguments))
    if name == "reorder_navigation":
        return json_result(reorder_navigation_impl(arguments))
    if name == "sync_with_cloud":
        return json_result(sync_with_cloud_impl())
    if name == "disconnect_cloud":
        return json_result(disconnect_cloud_impl(arguments))
    if name == "list_expenses":
        return json_result(list_expenses_impl(arguments))
    if name == "create_expense":
        return json_result(create_expense_impl(arguments))
    if name == "update_expense":
        return json_result(update_expense_impl(arguments))
    if name == "delete_expense":
        return json_result(delete_expense_impl(arguments))
    if name == "list_expense_categories":
        return json_result(list_expense_categories_impl(arguments))
    if name == "create_expense_category":
        return json_result(create_expense_category_impl(arguments))
    if name == "update_expense_category":
        return json_result(update_expense_category_impl(arguments))
    if name == "delete_expense_category":
        return json_result(delete_expense_category_impl(arguments))
    if name == "list_payment_methods":
        return json_result(list_payment_methods_impl(arguments))
    if name == "create_payment_method":
        return json_result(create_payment_method_impl(arguments))
    if name == "update_payment_method":
        return json_result(update_payment_method_impl(arguments))
    if name == "delete_payment_method":
        return json_result(delete_payment_method_impl(arguments))
    if name == "list_fixed_payments":
        return json_result(list_fixed_payments_impl(arguments))
    if name == "create_fixed_payment":
        return json_result(create_fixed_payment_impl(arguments))
    if name == "update_fixed_payment":
        return json_result(update_fixed_payment_impl(arguments))
    if name == "delete_fixed_payment":
        return json_result(delete_fixed_payment_impl(arguments))
    if name == "create_expense_from_fixed_payment":
        return json_result(create_expense_from_fixed_payment_impl(arguments))
    if name == "duplicate_expense":
        return json_result(duplicate_expense_impl(arguments))
    if name == "expense_totals":
        return json_result(expense_totals_impl(arguments))
    if name == "export_financial_json":
        return json_result(export_financial_json_impl())
    if name == "export_financial_csv":
        return json_result(export_financial_csv_impl())
    if name == "list_library_items":
        return json_result(list_library_items_impl(arguments))
    if name == "create_library_item":
        return json_result(create_library_item_impl(arguments))
    if name == "update_library_item":
        return json_result(update_library_item_impl(arguments))
    if name == "delete_library_item":
        return json_result(delete_library_item_impl(arguments))
    if name == "bulk_upsert_library_items":
        return json_result(bulk_upsert_library_items_impl(arguments))
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
    if name == "delete_library_goal":
        return json_result(delete_library_goal_impl(arguments))
    if name == "toggle_library_goal_completed":
        return json_result(toggle_library_goal_completed_impl(arguments))
    if name == "toggle_library_goal_favorite":
        return json_result(toggle_library_goal_favorite_impl(arguments))
    if name == "create_category":
        return json_result(create_category_impl(arguments))
    if name == "create_project":
        return json_result(create_project_impl(arguments))
    if name == "export_state":
        return json_result(load_state())
    if name == "import_state":
        return json_result(import_state_impl(arguments))
    if name == "reset_state":
        return json_result(reset_state_impl(arguments))
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
