import copy
import datetime as dt
import hashlib
import io
import json
import os
import random
import re
import shutil
import struct
import sys
import unicodedata
import zlib
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

try:
    from PIL import Image, ImageOps
except ImportError:  # La importación PNG básica sigue disponible sin Pillow.
    Image = None
    ImageOps = None

from knowledge_repository import KnowledgeRepository


PROTOCOL_VERSION = "2025-03-26"
SERVER_INFO = {"name": "todo-mcp", "version": "0.3.0"}
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
KNOWLEDGE_PATH_OVERRIDE = os.environ.get("TODO_MCP_KNOWLEDGE_PATH")
if KNOWLEDGE_PATH_OVERRIDE:
    KNOWLEDGE_DIR = Path(KNOWLEDGE_PATH_OVERRIDE)
elif RUNTIME_DIR.name.lower() == "runtime":
    KNOWLEDGE_DIR = RUNTIME_DIR.parent / "knowledge"
else:
    KNOWLEDGE_DIR = RUNTIME_DIR / "knowledge"
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
        "libraryStatusView": "pending",
        "wardrobeItems": [],
        "wardrobeOutfits": [],
        "wardrobeWearLogs": [],
        "wardrobePlanEntries": [],
        "wardrobePackingLists": [],
        "wardrobeImportBatches": [],
        "householdItems": [],
        "recipes": [],
        "weeklyMenus": [],
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
            "wardrobe",
            "household",
            "recipes",
            "completed",
            "settings",
        ],
        "updatedAt": now_iso(),
        "schemaVersion": 3,
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
    from_remote = False
    if remote_enabled():
        state = read_remote_state()
        if state is not None:
            from_remote = True
        else:
            state = read_local_state()
    else:
        state = read_local_state()
    migrated = migrate_library_state(state)
    if migrated:
        touch_state(state)
    write_local_state(state)
    write_app_snapshot(state)
    if remote_enabled() and (migrated or not from_remote):
        write_remote_state(state)
    return state


def save_state(state: dict[str, Any]) -> None:
    touch_state(state)
    write_local_state(state)
    write_app_snapshot(state)
    if remote_enabled():
        write_remote_state(state)


def touch_state(state: dict[str, Any]) -> None:
    state["updatedAt"] = now_iso()
    state["schemaVersion"] = max(3, int(state.get("schemaVersion", 1) or 1))
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
            "description": "Lista tareas, con filtros opcionales por estado, proyecto, categoría o fecha.",
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
            "description": "Mueve una tarea a otro día, conservando la hora si ya la tenia.",
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
            "description": "Lista categorías existentes.",
            "inputSchema": {"type": "object", "properties": {}},
        },
        {
            "name": "list_expenses",
            "description": "Lista gastos, con filtros opcionales por año, mes, categoría, método de pago o proyecto.",
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
            "description": "Lista categorías de gasto.",
            "inputSchema": {"type": "object", "properties": {"include_inactive": {"type": "boolean"}}},
        },
        {
            "name": "create_expense_category",
            "description": "Crea una categoría de gasto.",
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
            "description": "Actualiza una categoría de gasto.",
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
            "description": "Borra o desactiva una categoría de gasto. Si hay gastos vinculados, usa replacement_category_id o deactivate=true.",
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
            "description": "Lista métodos de pago.",
            "inputSchema": {"type": "object", "properties": {"include_inactive": {"type": "boolean"}}},
        },
        {
            "name": "create_payment_method",
            "description": "Crea un método de pago.",
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
            "description": "Actualiza un método de pago.",
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
            "description": "Borra o desactiva un método de pago. Si hay gastos o pagos fijos vinculados, usa replacement_payment_method_id o deactivate=true.",
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
            "description": "Lista propósitos de Biblioteca, con filtros opcionales por año y tipo.",
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
            "description": "Lista elementos de Biblioteca, con filtros opcionales por estado, año completado y tipo.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "completed_year": {"type": "integer"},
                    "status": {
                        "type": "string",
                        "description": "pending, inProgress o completed.",
                    },
                    "type": {
                        "type": "string",
                        "description": "game, book o movieSeries.",
                    },
                },
            },
        },
        {
            "name": "bulk_upsert_library_items",
            "description": "Crea o actualiza varios elementos de Biblioteca sin duplicarlos.",
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
                                "status": {
                                    "type": "string",
                                    "description": "pending, inProgress o completed. Si se omite, usa completed por compatibilidad.",
                                },
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
            "description": "Crea un propósito anual dentro de Biblioteca.",
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
            "description": "Crea varios propósitos de Biblioteca de una vez.",
            "inputSchema": {
                "type": "object",
                "required": ["goals"],
                "properties": {
                    "replace_year": {
                        "type": "integer",
                        "description": "Si se informa, borra antes los propósitos de ese año.",
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
            "description": "Actualiza un propósito de Biblioteca existente.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "goal_id": {"type": "string"},
                    "title": {
                        "type": "string",
                        "description": "Título actual usado para localizar el propósito.",
                    },
                    "target_year": {
                        "type": "integer",
                        "description": "Año actual usado para localizar el propósito.",
                    },
                    "type": {
                        "type": "string",
                        "description": "Tipo actual usado para localizar el propósito.",
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
            "description": "Crea o actualiza varios propósitos de Biblioteca sin duplicarlos.",
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
            "description": "Borra propósitos de Biblioteca, opcionalmente solo de un año.",
            "inputSchema": {
                "type": "object",
                "properties": {"target_year": {"type": "integer"}},
            },
        },
        {
            "name": "create_category",
            "description": "Crea una nueva categoría.",
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
    ] + extra_tool_definitions() + knowledge_tool_definitions()


def knowledge_tool_definitions() -> list[dict[str, Any]]:
    string = {"type": "string"}
    boolean = {"type": "boolean"}
    integer = {"type": "integer"}
    object_schema = {"type": "object"}
    return [
        tool(
            "get_knowledge_contract",
            "Devuelve el contrato estable de páginas, bloques, enlaces y contenido gestionado por IA.",
            {},
            [],
        ),
        tool(
            "list_knowledge_pages",
            "Lista páginas locales, raíces, hijos o la página asociada a una entidad de la aplicación.",
            {
                "parent_id": {"type": ["string", "null"]},
                "owner_type": string,
                "owner_id": string,
                "include_trashed": boolean,
            },
            [],
        ),
        tool("get_knowledge_page", "Lee una página con hijos, backlinks, enlaces y colecciones.", {"page_id": string}, ["page_id"]),
        tool("search_knowledge", "Busca localmente en títulos, texto y propiedades mediante FTS5.", {"query": string, "limit": integer}, ["query"]),
        tool(
            "create_knowledge_page",
            "Crea una página o la reutiliza por identidad canónica estable.",
            {
                "page_id": string, "parent_id": string, "title": string,
                "icon": string, "cover_asset_id": string, "document": object_schema,
                "properties": object_schema, "canonical_source": string,
                "canonical_id": string, "externalKey": string,
                "owner_type": string, "owner_id": string,
            },
            ["title"],
        ),
        tool(
            "update_knowledge_page",
            "Actualiza una página con checkpoint previo y conserva bloques manuales en actualizaciones gestionadas.",
            {"page_id": string, "title": string, "icon": string,
             "cover_asset_id": string, "document": object_schema,
             "properties": object_schema, "managed_update": boolean},
            ["page_id"],
        ),
        tool("move_knowledge_page", "Mueve una página impidiendo ciclos.",
             {"page_id": string, "parent_id": {"type": ["string", "null"]}}, ["page_id"]),
        tool("trash_knowledge_page", "Envía una página y todos sus descendientes a la papelera.",
             {"page_id": string}, ["page_id"]),
        tool("restore_knowledge_page", "Restaura una página y todos sus descendientes.",
             {"page_id": string}, ["page_id"]),
        tool("list_knowledge_backlinks", "Lista enlaces entrantes y salientes de una página.",
             {"page_id": string}, ["page_id"]),
        tool("list_unlinked_knowledge_pages", "Lista páginas que no tienen enlaces entrantes ni salientes.", {}, []),
        tool(
            "import_knowledge_asset",
            "Incorpora y deduplica un recurso local o HTTPS conservando su procedencia.",
            {"path": string, "url": string, "mime_type": string,
             "source_url": string, "source_page_url": string,
             "author": string, "alt_text": string},
            [],
        ),
        tool(
            "import_knowledge_assets",
            "Importa recursos por lotes y devuelve la resolución estable de cada externalKey.",
            {"assets": {"type": "array", "items": object_schema}},
            ["assets"],
        ),
        tool(
            "list_knowledge_progress",
            "Lee progreso global del juego por raíz, prefijo o fuente.",
            {"root_page_id": string, "prefix": string, "source": string},
            ["root_page_id"],
        ),
        tool(
            "set_knowledge_progress",
            "Escribe una entrada de progreso manual o derivada.",
            {"root_page_id": string, "key": string, "value": {}, "source": string},
            ["root_page_id", "key"],
        ),
        tool(
            "replace_knowledge_progress",
            "Reemplaza transaccionalmente todo el progreso de una fuente sin tocar otras fuentes.",
            {"root_page_id": string, "source": string,
             "entries": {"type": "array", "items": object_schema}},
            ["root_page_id", "source", "entries"],
        ),
        tool(
            "create_knowledge_collection",
            "Crea o actualiza una colección con propiedades y vistas.",
            {"collection_id": string, "page_id": string, "name": string,
             "schema": {"type": "array"}, "views": {"type": "array"}},
            ["page_id", "name"],
        ),
        tool("list_knowledge_collections", "Lista colecciones locales.", {"page_id": string}, []),
        tool(
            "apply_knowledge_manifest",
            "Valida y aplica atómicamente un árbol documental idempotente, sin cambios parciales.",
            {"manifest": object_schema},
            ["manifest"],
        ),
        tool(
            "import_knowledge_repository",
            "Importa un manifiesto JSON con fidelidad estructural usando la misma transacción idempotente.",
            {"manifest": object_schema},
            ["manifest"],
        ),
        tool("export_knowledge_repository", "Exporta páginas, Markdown y recursos a un ZIP local recuperable.", {}, []),
    ]


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
        "collection_name": string,
        "collection_number": integer,
        "show_collection_number": boolean,
        "clear_collection_name": boolean,
        "clear_collection_number": boolean,
        "confirm": boolean,
    }
    wardrobe_fields = {
        "item_id": string,
        "name": string,
        "category": string,
        "colors": strings,
        "material": string,
        "seasons": strings,
        "occasions": strings,
        "tags": strings,
        "price": number,
        "favorite": boolean,
        "archived": boolean,
        "laundry_status": string,
    }
    wardrobe_import_fields = {
        **wardrobe_fields,
        "source_file": string,
        "request_id": string,
    }
    household_fields = {
        "item_id": string,
        "name": string,
        "category": string,
        "brand": string,
        "model": string,
        "serial_number": string,
        "location": string,
        "notes": string,
        "manual_source_url": string,
        "retailer": string,
        "purchase_date": string,
        "warranty_until": string,
        "price": number,
        "tags": strings,
        "archived": boolean,
    }
    recipe_fields = {
        "recipe_id": string,
        "title": string,
        "description": string,
        "category": string,
        "cuisine": string,
        "servings": integer,
        "prep_minutes": integer,
        "cook_minutes": integer,
        "ingredients": strings,
        "instructions": strings,
        "tags": strings,
        "source_url": string,
        "image_source_url": string,
        "favorite": boolean,
        "archived": boolean,
    }

    return [
        tool("delete_task", "Borra una tarea y limpia referencias de subtareas.", {"task_id": string}, ["task_id"]),
        tool("reopen_task", "Reabre una tarea completada.", {"task_id": string}, ["task_id"]),
        tool("bulk_complete_tasks", "Completa varias tareas.", {"task_ids": strings}, ["task_ids"]),
        tool("bulk_reopen_tasks", "Reabre varias tareas.", {"task_ids": strings}, ["task_ids"]),
        tool("bulk_delete_tasks", "Borra varias tareas.", {"task_ids": strings, "confirm": boolean}, ["task_ids", "confirm"]),
        tool("bulk_move_tasks_to_day", "Mueve varias tareas a un día.", {"task_ids": strings, "date": string}, ["task_ids", "date"]),
        tool("reorder_tasks", "Actualiza el orden manual de una lista de tareas.", {"ordered_ids": strings}, ["ordered_ids"]),
        tool("create_subtask", "Crea una subtarea vinculada a una tarea padre.", {"parent_task_id": string, "title": string}, ["parent_task_id", "title"]),
        tool("set_task_reminder", "Configura el recordatorio de una tarea.", task_fields, ["task_id"]),
        tool("clear_task_reminder", "Elimina el recordatorio de una tarea.", {"task_id": string}, ["task_id"]),
        tool("update_project", "Actualiza un proyecto.", {"project_id": string, "name": string, "description": string, "color_value": integer, "icon_code_point": integer, "status": string, "category_ids": strings}, ["project_id"]),
        tool("set_project_status", "Cambia el estado de un proyecto.", {"project_id": string, "status": string}, ["project_id", "status"]),
        tool("complete_project", "Marca un proyecto como completado.", {"project_id": string}, ["project_id"]),
        tool("cancel_project", "Marca un proyecto como cancelado.", {"project_id": string}, ["project_id"]),
        tool("delete_project", "Borra un proyecto y limpia sus referencias en tareas.", {"project_id": string, "confirm": boolean}, ["project_id", "confirm"]),
        tool("update_category", "Actualiza una categoría.", {"category_id": string, "name": string, "description": string, "color_value": integer, "icon_code_point": integer, "active": boolean}, ["category_id"]),
        tool("toggle_category", "Activa o desactiva una categoría.", {"category_id": string}, ["category_id"]),
        tool("delete_category", "Borra una categoría y limpia sus referencias.", {"category_id": string, "confirm": boolean}, ["category_id", "confirm"]),
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
        tool("get_settings", "Devuelve ajustes de app, día, notificaciones, calendario, navegación y modo visual.", {}, []),
        tool("update_day_settings", "Actualiza ajustes de día.", {"day_ends_at_hour": integer, "next_day_visible_at_hour": integer}, []),
        tool("update_notification_settings", "Actualiza ajustes de notificaciones.", {"notifications_enabled": boolean, "web_permission_granted": boolean, "windows_permission_granted": boolean, "day_start_reminder_enabled": boolean, "day_end_reminder_enabled": boolean, "default_minutes_before_task": integer}, []),
        tool("update_calendar_settings", "Actualiza ajustes de integracion de calendario.", {"web_client_id": string, "desktop_client_id": string, "desktop_client_secret": string, "selected_calendar_id": string, "selected_calendar_name": string, "connected_email": string, "connected": boolean, "last_error": string}, []),
        tool("set_today_sort", "Cambia el orden de Hoy.", {"today_sort": string}, ["today_sort"]),
        tool("set_visual_mode", "Cambia el modo visual.", {"visual_mode": string}, ["visual_mode"]),
        tool("reorder_navigation", "Actualiza el orden de navegación lateral.", {"sections": strings}, ["sections"]),
        tool("sync_with_cloud", "Fuerza sincronización con nube si hay credenciales.", {}, []),
        tool("disconnect_cloud", "Desconecta la nube en el snapshot local.", {"confirm": boolean}, ["confirm"]),
        tool("duplicate_expense", "Duplica un gasto.", {"expense_id": string}, ["expense_id"]),
        tool("expense_totals", "Calcula totales de gastos.", {"year": integer, "month": integer, "group_by": string}, []),
        tool("export_financial_json", "Exporta datos financieros en JSON.", {}, []),
        tool("export_financial_csv", "Exporta gastos en CSV.", {}, []),
        tool("create_library_item", "Crea un elemento de Biblioteca. Si se omite status, se crea completado por compatibilidad.", library_fields, ["type", "title"]),
        tool("update_library_item", "Actualiza datos o estado de un elemento de Biblioteca.", library_fields, ["item_id"]),
        tool("delete_library_item", "Borra un elemento de Biblioteca; si tiene propósito, lo conserva y recrea una entrada pendiente.", {"item_id": string, "confirm": boolean}, ["item_id", "confirm"]),
        tool("delete_library_goal", "Borra un propósito de Biblioteca.", {"goal_id": string, "confirm": boolean}, ["goal_id", "confirm"]),
        tool("toggle_library_goal_completed", "Alterna pendiente/completado y sincroniza con Biblioteca.", {"goal_id": string}, ["goal_id"]),
        tool("toggle_library_goal_favorite", "Alterna favorito en un propósito.", {"goal_id": string}, ["goal_id"]),
        tool("get_wardrobe_import_contract", "Devuelve el contrato de lotes de Ropa para Codex.", {}, []),
        tool("stage_wardrobe_batch", "Valida y prepara un lote local de PNG transparentes para revisarlo en Todo.", {"source_directory": string, "manifest_path": string}, ["source_directory"]),
        tool("list_wardrobe_batches", "Lista las importaciones de Ropa.", {"status": string}, []),
        tool("get_wardrobe_batch", "Devuelve una importación de Ropa.", {"batch_id": string}, ["batch_id"]),
        tool("list_wardrobe_items", "Lista las prendas del armario.", {"include_archived": boolean}, []),
        tool("import_wardrobe_item", "Añade directamente una prenda con su imagen, sin lote ni aprobación manual.", wardrobe_import_fields, ["source_file", "request_id", "name", "category"]),
        tool("create_wardrobe_item", "Crea una prenda manual.", wardrobe_fields, ["name", "category"]),
        tool("update_wardrobe_item", "Actualiza los metadatos de una prenda.", wardrobe_fields, ["item_id"]),
        tool("delete_wardrobe_item", "Elimina una prenda y limpia sus referencias activas.", {"item_id": string, "confirm": boolean}, ["item_id", "confirm"]),
        tool("list_wardrobe_outfits", "Lista los conjuntos y sus renders disponibles.", {}, []),
        tool("create_wardrobe_outfit", "Crea un conjunto de prendas.", {"name": string, "item_ids": strings, "occasion": string, "tags": strings}, ["name", "item_ids"]),
        tool("update_wardrobe_outfit", "Edita el nombre, la ocasión, las etiquetas o las prendas de un conjunto.", {"outfit_id": string, "name": string, "item_ids": strings, "occasion": string, "tags": strings}, ["outfit_id"]),
        tool("set_wardrobe_outfit_render", "Asocia a un conjunto un render PNG generado por Codex.", {"outfit_id": string, "source_file": string}, ["outfit_id", "source_file"]),
        tool("record_wardrobe_wear", "Registra el uso de prendas o de un conjunto.", {"date": string, "item_ids": strings, "outfit_id": string, "label": string}, ["date", "item_ids"]),
        tool("set_wardrobe_laundry_status", "Cambia el estado de lavandería de varias prendas.", {"item_ids": strings, "status": string}, ["item_ids", "status"]),
        tool("set_wardrobe_plan", "Planifica prendas para un día.", {"date": string, "item_ids": strings, "outfit_id": string, "weather": string, "occasion": string}, ["date", "item_ids"]),
        tool("create_wardrobe_packing_list", "Crea una maleta de viaje.", {"name": string, "start_date": string, "end_date": string}, ["name", "start_date", "end_date"]),
        tool("add_wardrobe_packing_item", "Añade una prenda a una maleta.", {"packing_list_id": string, "item_id": string, "quantity": integer}, ["packing_list_id", "item_id"]),
        tool("list_household_items", "Lista las compras y aparatos del inventario visual de Hogar.", {"include_archived": boolean}, []),
        tool("create_household_item", "Crea una ficha de Hogar con marca, modelo, serie, compra y garantía.", household_fields, ["name", "category"]),
        tool("update_household_item", "Actualiza la información de una ficha de Hogar.", household_fields, ["item_id"]),
        tool("set_household_item_image", "Asocia a una ficha una imagen PNG de catálogo generada o preparada por Codex.", {"item_id": string, "source_file": string}, ["item_id", "source_file"]),
        tool("set_household_item_document", "Guarda un manual o una factura PDF dentro de la ficha de Hogar.", {"item_id": string, "kind": string, "source_file": string, "source_url": string}, ["item_id", "kind", "source_file"]),
        tool("delete_household_item", "Elimina una ficha de Hogar y sus recursos locales.", {"item_id": string, "confirm": boolean}, ["item_id", "confirm"]),
        tool("list_recipes", "Lista las recetas del recetario visual.", {"include_archived": boolean, "favorites_only": boolean}, []),
        tool("create_recipe", "Crea una receta con tiempos, raciones, ingredientes y pasos.", recipe_fields, ["title"]),
        tool("update_recipe", "Actualiza una receta existente.", recipe_fields, ["recipe_id"]),
        tool("set_recipe_image", "Asocia a una receta una imagen PNG preparada por Codex.", {"recipe_id": string, "source_file": string}, ["recipe_id", "source_file"]),
        tool("create_recipe_task", "Convierte ingredientes o pasos de una receta en una tarea con subtareas.", {"recipe_id": string, "kind": string, "scheduled_at": string}, ["recipe_id", "kind"]),
        tool("delete_recipe", "Elimina una receta y sus imágenes locales.", {"recipe_id": string, "confirm": boolean}, ["recipe_id", "confirm"]),
        tool("list_weekly_menus", "Lista los menús semanales, sus recetas y su compra planificada.", {"include_archived": boolean}, []),
        tool("create_weekly_menu_task", "Convierte la semana completa o una selección de comidas de un menú en una tarea de compra.", {"menu_id": string, "entry_ids": strings, "scheduled_at": string}, ["menu_id"]),
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


def task_matches_date(
    task: dict[str, Any],
    target: dt.date,
    *,
    include_overdue: bool = False,
) -> bool:
    scheduled = parse_datetime(task.get("scheduledAt"))
    if scheduled is None:
        return True
    if include_overdue and scheduled.date() < target:
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
    raise ValueError(f"No existe la categoría '{category_id}'.")


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
    include_overdue = False
    if "date" in arguments:
        if arguments["date"] == "today":
            target_date = logical_today(state)
            include_overdue = True
        else:
            target_date = dt.date.fromisoformat(arguments["date"])

    tasks = []
    for task in state["tasks"]:
        if "status" in arguments and task.get("status") != arguments["status"]:
            continue
        if "project_id" in arguments and arguments["project_id"] not in task.get("projectIds", []):
            continue
        if "category_id" in arguments and arguments["category_id"] not in task.get("categoryIds", []):
            continue
        if target_date is not None and not task_matches_date(
            task,
            target_date,
            include_overdue=include_overdue and task.get("status") == "active",
        ):
            continue
        tasks.append(task)
    return {"tasks": tasks, "count": len(tasks), "mode": "supabase" if remote_enabled() else "local"}


def get_today_impl() -> dict[str, Any]:
    state = load_state()
    today = logical_today(state)
    tasks = [
        task
        for task in state["tasks"]
        if task.get("status") == "active"
        and task_matches_date(task, today, include_overdue=True)
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
    find_by_id(state["expenseCategories"], category_id, "la categoría de gasto")


def validate_payment_method(state: dict[str, Any], payment_method_id: str | None) -> None:
    if payment_method_id:
        find_by_id(state["paymentMethods"], payment_method_id, "el método de pago")


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
    index, category = find_by_id(state["expenseCategories"], arguments["category_id"], "la categoría de gasto")
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
    index, category = find_by_id(state["expenseCategories"], category_id, "la categoría de gasto")
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
        raise ValueError("La categoría tiene gastos o pagos fijos vinculados. Usa replacement_category_id o deactivate=true.")
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
    index, method = find_by_id(state["paymentMethods"], arguments["payment_method_id"], "el método de pago")
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
    index, method = find_by_id(state["paymentMethods"], method_id, "el método de pago")
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
        raise ValueError("El método tiene gastos o pagos fijos vinculados. Usa replacement_payment_method_id o deactivate=true.")
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


def library_title_key(value: str | None) -> str:
    return re.sub(r"[^a-z0-9áéíóúüñ]+", "", (value or "").strip().lower())


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
        raise ValueError("Tipo de biblioteca no válido. Usa game, book o movieSeries.")
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
        raise ValueError("Tipo de medio no válido. Usa movie o series.")
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
        raise ValueError("Estado de propósito no válido. Usa pending o completed.")
    return normalized


def normalize_library_item_status(value: str | None) -> str:
    if not value:
        return "completed"
    aliases = {
        "pending": "pending",
        "pendiente": "pending",
        "inProgress": "inProgress",
        "in_progress": "inProgress",
        "en curso": "inProgress",
        "encurso": "inProgress",
        "completed": "completed",
        "complete": "completed",
        "completado": "completed",
        "terminado": "completed",
    }
    normalized = aliases.get(value.strip())
    if normalized is None:
        raise ValueError(
            "Estado de biblioteca no válido. Usa pending, inProgress o completed."
        )
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
    status = normalize_library_item_status(arguments.get("status"))
    return {
        "id": make_id("library"),
        "type": normalize_library_type(arguments["type"]),
        "title": arguments["title"].strip(),
        "status": status,
        "completedDate": (
            parse_completed_date(arguments.get("completed_date"))
            if status == "completed"
            else None
        ),
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
        "collectionName": (arguments.get("collection_name") or "").strip()
        or None,
        "collectionNumber": (
            int(arguments["collection_number"])
            if arguments.get("collection_number") is not None
            and int(arguments["collection_number"]) > 0
            else None
        ),
        "showCollectionNumber": bool(arguments.get("show_collection_number", False))
        and bool((arguments.get("collection_name") or "").strip())
        and arguments.get("collection_number") is not None
        and int(arguments["collection_number"]) > 0,
        "linkedGoalId": arguments.get("linked_goal_id") or None,
        "createdAt": now,
        "updatedAt": now,
    }


def apply_library_item_updates(item: dict[str, Any], arguments: dict[str, Any]) -> dict[str, Any]:
    updated = dict(item)
    status = normalize_library_item_status(
        arguments.get("status", updated.get("status", "completed"))
    )
    updated["status"] = status
    if "type" in arguments:
        updated["type"] = normalize_library_type(arguments["type"])
    if "title" in arguments:
        updated["title"] = arguments["title"].strip()
    if status == "completed" and "completed_date" in arguments:
        updated["completedDate"] = parse_completed_date(arguments.get("completed_date"))
    elif status == "completed" and not updated.get("completedDate"):
        updated["completedDate"] = now_iso()
    elif status != "completed":
        updated["completedDate"] = None
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
    if "collection_name" in arguments:
        updated["collectionName"] = (
            arguments.get("collection_name") or ""
        ).strip() or None
    if arguments.get("clear_collection_name"):
        updated["collectionName"] = None
    if "collection_number" in arguments:
        value = arguments.get("collection_number")
        updated["collectionNumber"] = int(value) if value is not None and int(value) > 0 else None
    if arguments.get("clear_collection_number"):
        updated["collectionNumber"] = None
    if "show_collection_number" in arguments:
        updated["showCollectionNumber"] = bool(arguments["show_collection_number"])
    if not updated.get("collectionName") or not updated.get("collectionNumber"):
        updated["showCollectionNumber"] = False
    if "linked_goal_id" in arguments:
        updated["linkedGoalId"] = arguments.get("linked_goal_id") or None
    if arguments.get("clear_linked_goal_id"):
        updated["linkedGoalId"] = None
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
            if not item.get("completedDate"):
                continue
            completed = dt.datetime.fromisoformat(item["completedDate"])
            if completed.year != int(arguments["completed_year"]):
                continue
        if "status" in arguments and item.get("status", "completed") != normalize_library_item_status(arguments["status"]):
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
        title = library_title_key(raw_item["title"])
        item_status = normalize_library_item_status(raw_item.get("status"))
        item_date = (
            parse_datetime(parse_completed_date(raw_item.get("completed_date")))
            if item_status == "completed"
            else None
        )
        match_index = None
        for index, existing in enumerate(state["libraryItems"]):
            if existing.get("type") != item_type:
                continue
            if library_title_key(existing.get("title")) != title:
                continue
            existing_status = existing.get("status", "completed")
            if item_status == "completed" or existing_status == "completed":
                existing_date = parse_datetime(existing.get("completedDate"))
                if not (
                    item_status == "completed"
                    and existing_status == "completed"
                    and existing_date is not None
                    and item_date is not None
                    and existing_date.year == item_date.year
                ):
                    continue
            match_index = index
            break
        if match_index is None:
            item = library_item_from_args(raw_item)
            state["libraryItems"].append(item)
            sync_goal_from_library_item(state, item)
            created.append(item)
            continue
        item = apply_library_item_updates(state["libraryItems"][match_index], raw_item)
        state["libraryItems"][match_index] = item
        sync_goal_from_library_item(state, item)
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
        "linkedLibraryItemId": arguments.get("linked_library_item_id") or None,
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
    title = library_title_key(arguments.get("title"))
    target_year = arguments.get("target_year")
    goal_type = normalize_library_type(arguments["type"]) if arguments.get("type") else None

    matches = []
    for index, goal in enumerate(state["libraryGoals"]):
        if goal_id and goal.get("id") != goal_id:
            continue
        if title and library_title_key(goal.get("title")) != title:
            continue
        if target_year is not None and int(goal.get("targetYear", 0)) != int(target_year):
            continue
        if goal_type is not None and goal.get("type") != goal_type:
            continue
        matches.append(index)

    if not matches:
        raise ValueError("No se encontró ningún propósito con esos filtros.")
    if len(matches) > 1:
        raise ValueError("Los filtros coinciden con varios propósitos; usa goal_id.")
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
    if "linked_library_item_id" in arguments:
        updated["linkedLibraryItemId"] = arguments.get("linked_library_item_id") or None
    if arguments.get("clear_linked_library_item_id"):
        updated["linkedLibraryItemId"] = None

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
        removed_ids = {
            goal.get("id")
            for goal in state["libraryGoals"]
            if int(goal.get("targetYear", 0)) == int(replace_year)
        }
        state["libraryGoals"] = [
            goal
            for goal in state["libraryGoals"]
            if int(goal.get("targetYear", 0)) != int(replace_year)
        ]
        for item in state["libraryItems"]:
            if item.get("linkedGoalId") in removed_ids:
                item["linkedGoalId"] = None
                item["updatedAt"] = now_iso()
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
        title = library_title_key(raw_goal["title"])
        target_year = int(raw_goal["target_year"])
        match_index = None
        for index, existing in enumerate(state["libraryGoals"]):
            if existing.get("type") != goal_type:
                continue
            if library_title_key(existing.get("title")) != title:
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
    removed_goal_ids: set[str] = set()
    if "target_year" in arguments:
        target_year = int(arguments["target_year"])
        for goal in state["libraryGoals"]:
            if int(goal.get("targetYear", 0)) == target_year:
                removed_goal_ids.add(goal.get("id"))
        state["libraryGoals"] = [
            goal
            for goal in state["libraryGoals"]
            if int(goal.get("targetYear", 0)) != target_year
        ]
    else:
        removed_goal_ids = {goal.get("id") for goal in state["libraryGoals"]}
        state["libraryGoals"] = []
    for item in state["libraryItems"]:
        if item.get("linkedGoalId") in removed_goal_ids:
            item["linkedGoalId"] = None
            item["updatedAt"] = now_iso()
    save_state(state)
    return {"deleted": before - len(state["libraryGoals"])}


VALID_TASK_PRIORITIES = {"low", "medium", "high", "urgent"}
VALID_TASK_STATUSES = {"active", "completed", "archived"}
VALID_PROJECT_STATUSES = {"active", "paused", "completed", "cancelled"}
VALID_NOTE_STATUSES = {"inbox", "converted", "archived"}
VALID_RECURRENCE_TYPES = {"none", "daily", "everyXDays", "weekly", "yearly"}
VALID_TODAY_SORTS = {"manual", "category", "time", "project", "priority"}
VALID_VISUAL_MODES = {"classic", "phantom"}
VALID_SECTIONS = {"today", "projects", "inbox", "categories", "expenses", "calendar", "library", "wardrobe", "household", "recipes", "completed", "settings"}


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
        raise ValueError(f"{label} no válido. Usa uno de: {', '.join(sorted(valid))}.")
    return normalized


def ensure_task_refs(state: dict[str, Any], category_ids: list[str] | None = None, project_ids: list[str] | None = None) -> None:
    for category_id in category_ids or []:
        find_by_id(state["categories"], category_id, "la categoría")
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
    index, category = find_by_id(state["categories"], arguments["category_id"], "la categoría")
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
    index, category = find_by_id(state["categories"], arguments["category_id"], "la categoría")
    updated = copy.deepcopy(category)
    updated["active"] = not bool(updated.get("active", True))
    state["categories"][index] = updated
    save_state(state)
    return {"updated": updated}


def delete_category_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    require_confirm(arguments, "delete_category")
    state = load_state()
    index, category = find_by_id(state["categories"], arguments["category_id"], "la categoría")
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
    item_year = (
        parse_datetime(item.get("completedDate")).year
        if item.get("completedDate")
        else None
    )
    for index, existing in enumerate(state["libraryItems"]):
        if existing.get("type") != item.get("type") or library_title_key(
            existing.get("title")
        ) != library_title_key(item.get("title")):
            continue
        existing_status = existing.get("status", "completed")
        existing_year = (
            parse_datetime(existing.get("completedDate")).year
            if existing.get("completedDate")
            else None
        )
        same_cycle = (
            existing_status == "completed"
            and item["status"] == "completed"
            and existing_year == item_year
        ) or (existing_status != "completed" and item["status"] != "completed")
        if not same_cycle and item["status"] == "completed" and existing_status != "completed":
            linked_goal = next(
                (
                    goal
                    for goal in state["libraryGoals"]
                    if goal.get("id") == existing.get("linkedGoalId")
                ),
                None,
            )
            same_cycle = bool(
                linked_goal and int(linked_goal.get("targetYear", 0)) == item_year
            )
        if same_cycle:
            merged = merge_library_items(existing, item)
            state["libraryItems"][index] = merged
            synced_goal = sync_goal_from_library_item(state, merged)
            save_state(state)
            return {"created": merged, "synced_goal": synced_goal, "merged": True}
    state["libraryItems"].append(item)
    synced_goal = sync_goal_from_library_item(state, item)
    save_state(state)
    return {"created": item, "synced_goal": synced_goal}


def find_library_item(state: dict[str, Any], item_id: str) -> tuple[int, dict[str, Any]]:
    return find_by_id(state["libraryItems"], item_id, "el item de biblioteca")


def update_library_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_library_goal_lists(state)
    index, item = find_library_item(state, arguments["item_id"])
    updated = apply_library_item_updates(item, arguments)
    state["libraryItems"][index] = updated
    synced_goal = sync_goal_from_library_item(state, updated)
    save_state(state)
    return {"updated": updated, "synced_goal": synced_goal}


def delete_library_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    require_confirm(arguments, "delete_library_item")
    state = load_state()
    ensure_library_goal_lists(state)
    index, item = find_library_item(state, arguments["item_id"])
    deleted = state["libraryItems"].pop(index)
    replacement = None
    for goal in state["libraryGoals"]:
        if goal.get("linkedLibraryItemId") == deleted.get("id") or goal.get("id") == deleted.get("linkedGoalId"):
            goal["linkedLibraryItemId"] = None
            goal["status"] = "pending"
            goal["updatedAt"] = now_iso()
            replacement = library_item_from_goal(goal, status="pending")
            replacement["rating"] = deleted.get("rating")
            state["libraryItems"].append(replacement)
            goal["linkedLibraryItemId"] = replacement["id"]
            break
    save_state(state)
    return {"deleted": deleted, "replacement": replacement}


def library_item_from_goal(
    goal: dict[str, Any], *, status: str | None = None
) -> dict[str, Any]:
    item_status = status or (
        "completed" if goal.get("status") == "completed" else "pending"
    )
    return {
        "id": make_id("library_item"),
        "type": goal.get("type"),
        "title": goal.get("title"),
        "status": item_status,
        "completedDate": now_iso() if item_status == "completed" else None,
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
        "linkedGoalId": goal.get("id"),
        "createdAt": now_iso(),
        "updatedAt": now_iso(),
    }


def update_library_item_from_goal(item: dict[str, Any], goal: dict[str, Any]) -> dict[str, Any]:
    updated = dict(item)
    for key in (
        "type",
        "title",
        "coverUrl",
        "note",
        "platform",
        "developer",
        "author",
        "mediaType",
        "releaseYear",
        "creatorOrDirector",
        "genre",
        "format",
        "duration",
        "pages",
        "country",
    ):
        updated[key] = goal.get(key)
    updated["linkedGoalId"] = goal.get("id")
    updated["updatedAt"] = now_iso()
    return updated


def merge_library_items(keeper: dict[str, Any], incoming: dict[str, Any]) -> dict[str, Any]:
    primary = incoming if incoming.get("linkedGoalId") else keeper
    secondary = keeper if primary is incoming else incoming
    merged = dict(primary)
    merged["id"] = keeper.get("id")
    incoming_status = incoming.get("status", "completed")
    primary_status = primary.get("status", "completed")
    secondary_status = secondary.get("status", "completed")
    if incoming_status == "completed":
        merged["status"] = "completed"
    elif "inProgress" in (primary_status, secondary_status):
        merged["status"] = "inProgress"
    else:
        merged["status"] = primary_status
    if merged["status"] == "completed":
        dates = [
            value
            for value in (keeper.get("completedDate"), incoming.get("completedDate"))
            if value
        ]
        merged["completedDate"] = min(dates) if dates else now_iso()
    else:
        merged["completedDate"] = None
    for key in (
        "coverUrl",
        "rating",
        "note",
        "platform",
        "developer",
        "author",
        "mediaType",
        "releaseYear",
        "creatorOrDirector",
        "genre",
        "format",
        "duration",
        "pages",
        "country",
        "collectionName",
        "collectionNumber",
        "showCollectionNumber",
        "linkedGoalId",
    ):
        merged[key] = primary.get(key) or secondary.get(key)
    merged["createdAt"] = min(
        keeper.get("createdAt", now_iso()),
        incoming.get("createdAt", now_iso()),
    )
    merged["updatedAt"] = now_iso()
    return merged


def sync_completed_goal_to_item(
    state: dict[str, Any],
    goal: dict[str, Any],
    *,
    reopen_as_pending: bool = False,
) -> dict[str, Any] | None:
    linked_item_id = goal.get("linkedLibraryItemId")
    for index, item in enumerate(state["libraryItems"]):
        if linked_item_id and item.get("id") == linked_item_id:
            if (
                goal.get("status") != "completed"
                and item.get("status", "completed") == "completed"
                and not reopen_as_pending
            ):
                item["linkedGoalId"] = None
                item["updatedAt"] = now_iso()
                goal["linkedLibraryItemId"] = None
                break
            updated = update_library_item_from_goal(item, goal)
            if goal.get("status") == "completed":
                updated["status"] = "completed"
                updated["completedDate"] = updated.get("completedDate") or now_iso()
            else:
                updated["status"] = (
                    "pending"
                    if reopen_as_pending or item.get("status") != "inProgress"
                    else "inProgress"
                )
                updated["completedDate"] = None
            state["libraryItems"][index] = updated
            goal["linkedLibraryItemId"] = updated["id"]
            return updated
    for index, item in enumerate(state["libraryItems"]):
        if item.get("type") != goal.get("type") or library_title_key(
            item.get("title")
        ) != library_title_key(goal.get("title")) or item.get("linkedGoalId"):
            continue
        item_status = item.get("status", "completed")
        if goal.get("status") == "completed":
            completed = parse_datetime(item.get("completedDate"))
            matches = (
                item_status == "completed"
                and completed is not None
                and completed.year == int(goal.get("targetYear", dt.datetime.now().year))
            )
        else:
            matches = item_status != "completed"
        if matches:
            updated = update_library_item_from_goal(item, goal)
            if goal.get("status") == "completed":
                updated["status"] = "completed"
                updated["completedDate"] = updated.get("completedDate") or now_iso()
            else:
                updated["status"] = (
                    "pending"
                    if reopen_as_pending or item_status != "inProgress"
                    else "inProgress"
                )
                updated["completedDate"] = None
            state["libraryItems"][index] = updated
            goal["linkedLibraryItemId"] = updated["id"]
            return updated
    item = library_item_from_goal(goal)
    state["libraryItems"].append(item)
    goal["linkedLibraryItemId"] = item["id"]
    return item


def sync_goal_from_library_item(state: dict[str, Any], item: dict[str, Any]) -> dict[str, Any] | None:
    linked_goal_id = item.get("linkedGoalId")
    completed = parse_datetime(item.get("completedDate"))
    item_year = completed.year if completed else None
    for index, goal in enumerate(state["libraryGoals"]):
        if linked_goal_id and goal.get("id") == linked_goal_id:
            return update_goal_from_library_item(state, index, item)
    for index, goal in enumerate(state["libraryGoals"]):
        if (
            goal.get("type") == item.get("type")
            and library_title_key(goal.get("title"))
            == library_title_key(item.get("title"))
            and goal.get("linkedLibraryItemId") in (None, item.get("id"))
            and (
                item.get("status", "completed") != "completed"
                or int(goal.get("targetYear", item_year or 0)) == item_year
            )
        ):
            return update_goal_from_library_item(state, index, item)
    return None


def update_goal_from_library_item(state: dict[str, Any], index: int, item: dict[str, Any]) -> dict[str, Any]:
    goal = dict(state["libraryGoals"][index])
    for key in (
        "type",
        "title",
        "coverUrl",
        "note",
        "platform",
        "developer",
        "author",
        "mediaType",
        "releaseYear",
        "creatorOrDirector",
        "genre",
        "format",
        "duration",
        "pages",
        "country",
    ):
        goal[key] = item.get(key)
    item_status = item.get("status", "completed")
    goal["status"] = "completed" if item_status == "completed" else "pending"
    completed = parse_datetime(item.get("completedDate"))
    if item_status == "completed" and completed is not None:
        goal["targetYear"] = completed.year
    goal["linkedLibraryItemId"] = item.get("id")
    goal["updatedAt"] = now_iso()
    state["libraryGoals"][index] = goal
    item["linkedGoalId"] = goal.get("id")
    return goal


def delete_library_goal_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    require_confirm(arguments, "delete_library_goal")
    state = load_state()
    ensure_library_goal_lists(state)
    index, goal = find_by_id(state["libraryGoals"], arguments["goal_id"], "el propósito")
    deleted = state["libraryGoals"].pop(index)
    linked_item_id = deleted.get("linkedLibraryItemId")
    for item in state["libraryItems"]:
        if item.get("linkedGoalId") == deleted.get("id") or item.get("id") == linked_item_id:
            item["linkedGoalId"] = None
            item["updatedAt"] = now_iso()
    save_state(state)
    return {"deleted": deleted}


def toggle_library_goal_completed_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_library_goal_lists(state)
    index, goal = find_by_id(state["libraryGoals"], arguments["goal_id"], "el propósito")
    updated = copy.deepcopy(goal)
    updated["status"] = "pending" if updated.get("status") == "completed" else "completed"
    updated["updatedAt"] = now_iso()
    state["libraryGoals"][index] = updated
    item = sync_completed_goal_to_item(
        state,
        updated,
        reopen_as_pending=updated.get("status") == "pending",
    )
    save_state(state)
    return {"updated": updated, "synced_item": item}


def toggle_library_goal_favorite_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    ensure_library_goal_lists(state)
    index, goal = find_by_id(state["libraryGoals"], arguments["goal_id"], "el propósito")
    updated = copy.deepcopy(goal)
    updated["isFavorite"] = not bool(updated.get("isFavorite", False))
    updated["updatedAt"] = now_iso()
    state["libraryGoals"][index] = updated
    save_state(state)
    return {"updated": updated}


def migrate_library_state(state: dict[str, Any]) -> bool:
    changed = False
    state.setdefault("libraryItems", [])
    state.setdefault("libraryGoals", [])
    if "libraryStatusView" not in state:
        state["libraryStatusView"] = "pending"
        changed = True
    for item in state["libraryItems"]:
        if "status" not in item:
            item["status"] = "completed"
            changed = True
        status = normalize_library_item_status(item.get("status"))
        if item.get("status") != status:
            item["status"] = status
            changed = True
        if status != "completed" and item.get("completedDate") is not None:
            item["completedDate"] = None
            changed = True
        if status == "completed" and not item.get("completedDate"):
            item["completedDate"] = item.get("updatedAt") or now_iso()
            changed = True
    for goal in list(state["libraryGoals"]):
        linked = next(
            (
                item
                for item in state["libraryItems"]
                if item.get("id") == goal.get("linkedLibraryItemId")
            ),
            None,
        )
        expected_status = "completed" if goal.get("status") == "completed" else None
        needs_sync = (
            linked is None
            or linked.get("linkedGoalId") != goal.get("id")
            or (expected_status == "completed" and linked.get("status") != "completed")
            or (expected_status is None and linked.get("status") == "completed")
        )
        if needs_sync:
            sync_completed_goal_to_item(state, goal)
            changed = True
    if int(state.get("schemaVersion", 1) or 1) < 3:
        state["schemaVersion"] = 3
        changed = True
    return changed


def wardrobe_directory() -> Path:
    override = os.environ.get("TODO_MCP_WARDROBE_PATH")
    directory = Path(override) if override else documents_todo_dir() / "wardrobe"
    directory.mkdir(parents=True, exist_ok=True)
    return directory


def wardrobe_import_contract_impl() -> dict[str, Any]:
    return {
        "version": 1,
        "direct_tool": "import_wardrobe_item",
        "categories": WARDROBE_CATEGORIES,
        "colors": WARDROBE_COLORS,
        "seasons": WARDROBE_SEASONS,
        "occasions": WARDROBE_OCCASIONS,
        "manifest": "manifest.json",
        "image_format": "PNG RGBA con al menos un píxel transparente",
        "shape": {
            "version": 1,
            "batchId": "identificador-opcional",
            "name": "Nombre del lote",
            "items": [{
                "id": "identificador-estable",
                "file": "prenda.png",
                "name": "Nombre visible",
                "category": "Categoría",
                "colors": ["color"],
                "material": "material",
                "seasons": ["temporada"],
                "occasions": ["ocasión"],
                "tags": ["etiqueta"],
                "confidence": "alta|media|baja",
                "sourceReferences": ["foto-origen.jpg"],
            }],
        },
    }


def _png_has_transparency(path: Path) -> bool:
    data = path.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        return False
    offset = 8
    width = height = bit_depth = color_type = interlace = 0
    compressed = bytearray()
    while offset + 12 <= len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        chunk = data[offset + 8:offset + 8 + length]
        offset += 12 + length
        if kind == b"IHDR":
            width, height, bit_depth, color_type, _compression, _filter, interlace = struct.unpack(">IIBBBBB", chunk)
        elif kind == b"IDAT":
            compressed.extend(chunk)
        elif kind == b"IEND":
            break
    if bit_depth != 8 or color_type not in (4, 6) or interlace != 0 or not compressed:
        return False
    channels = 2 if color_type == 4 else 4
    stride = width * channels
    raw = zlib.decompress(bytes(compressed))
    previous = bytearray(stride)
    cursor = 0
    for _row in range(height):
        filter_type = raw[cursor]
        cursor += 1
        encoded = raw[cursor:cursor + stride]
        cursor += stride
        decoded = bytearray(stride)
        for index, value in enumerate(encoded):
            left = decoded[index - channels] if index >= channels else 0
            up = previous[index]
            upper_left = previous[index - channels] if index >= channels else 0
            if filter_type == 0:
                result = value
            elif filter_type == 1:
                result = value + left
            elif filter_type == 2:
                result = value + up
            elif filter_type == 3:
                result = value + ((left + up) // 2)
            elif filter_type == 4:
                estimate = left + up - upper_left
                distances = (abs(estimate - left), abs(estimate - up), abs(estimate - upper_left))
                predictor = left if distances[0] <= distances[1] and distances[0] <= distances[2] else up if distances[1] <= distances[2] else upper_left
                result = value + predictor
            else:
                return False
            decoded[index] = result & 0xFF
        if any(decoded[index] < 255 for index in range(channels - 1, stride, channels)):
            return True
        previous = decoded
    return False


def stage_wardrobe_batch_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    source = Path(str(arguments["source_directory"])).expanduser().resolve()
    if not source.is_dir():
        raise ValueError("La carpeta de origen no existe.")
    manifest = Path(str(arguments.get("manifest_path") or source / "manifest.json")).expanduser().resolve()
    if manifest.parent != source or not manifest.is_file():
        raise ValueError("manifest_path debe ser manifest.json dentro de la carpeta de origen.")
    payload = json.loads(manifest.read_text(encoding="utf-8"))
    if int(payload.get("version", 0)) != 1:
        raise ValueError("La versión del manifiesto no es compatible.")
    raw_items = payload.get("items")
    if not isinstance(raw_items, list) or not raw_items:
        raise ValueError("El manifiesto no contiene prendas.")
    batch_id = re.sub(r"[^a-zA-Z0-9_-]", "-", str(payload.get("batchId") or make_id("ropa")))
    destination = wardrobe_directory() / "imports" / batch_id
    if destination.exists():
        raise ValueError("Ya existe un lote con ese identificador.")
    destination.mkdir(parents=True)
    state = load_state()
    existing = {item.get("imageSha256"): item.get("id") for item in state.get("wardrobeItems", []) if item.get("imageSha256")}
    staged: list[dict[str, Any]] = []
    try:
        for index, raw in enumerate(raw_items):
            if not isinstance(raw, dict):
                raise ValueError("Todos los elementos del manifiesto deben ser objetos.")
            file_name = str(raw.get("file") or "")
            if not file_name or Path(file_name).name != file_name or not file_name.lower().endswith(".png"):
                raise ValueError("Cada prenda debe usar un nombre PNG simple, sin rutas.")
            source_file = source / file_name
            errors: list[str] = []
            digest = ""
            if not source_file.is_file():
                errors.append("No se encuentra el archivo PNG.")
            else:
                digest = hashlib.sha256(source_file.read_bytes()).hexdigest()
                if not _png_has_transparency(source_file):
                    errors.append("El PNG no contiene transparencia válida.")
                else:
                    shutil.copy2(source_file, destination / file_name)
            staged.append({
                "id": str(raw.get("id") or f"import-{index}"),
                "fileName": file_name,
                "name": str(raw.get("name") or f"Prenda {index + 1}"),
                "category": str(raw.get("category") or "Sin categoría"),
                "imageSha256": digest,
                "colors": [str(value) for value in raw.get("colors", [])],
                "material": str(raw.get("material") or ""),
                "seasons": [str(value) for value in raw.get("seasons", [])],
                "occasions": [str(value) for value in raw.get("occasions", [])],
                "tags": [str(value) for value in raw.get("tags", [])],
                "confidence": str(raw.get("confidence") or "media"),
                "sourceReferences": [str(value) for value in raw.get("sourceReferences", [])],
                "errors": errors,
                "duplicateItemId": existing.get(digest),
            })
        shutil.copy2(manifest, destination / "manifest.json")
        batch = {
            "id": batch_id,
            "name": str(payload.get("name") or "Importación de ropa"),
            "createdAt": now_iso(),
            "status": "pending",
            "items": staged,
            "errorMessage": "",
        }
        state.setdefault("wardrobeImportBatches", []).append(batch)
        save_state(state)
        return batch
    except Exception:
        shutil.rmtree(destination, ignore_errors=True)
        raise


def list_wardrobe_batches_impl(arguments: dict[str, Any]) -> list[dict[str, Any]]:
    batches = load_state().get("wardrobeImportBatches", [])
    status = str(arguments.get("status") or "")
    return [batch for batch in batches if not status or batch.get("status") == status]


def get_wardrobe_batch_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    _index, batch = find_by_id(load_state().get("wardrobeImportBatches", []), arguments["batch_id"], "lote")
    return batch


def list_wardrobe_items_impl(arguments: dict[str, Any]) -> list[dict[str, Any]]:
    items = load_state().get("wardrobeItems", [])
    return items if arguments.get("include_archived") else [item for item in items if not item.get("archived", False)]


def create_wardrobe_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    instant = now_iso()
    item = {
        "id": make_id("wardrobe-item"), "name": str(arguments["name"]).strip(),
        "category": str(arguments["category"]).strip(), "imagePath": "", "thumbnailPath": "",
        "imageSha256": "", "colors": arguments.get("colors", []), "material": arguments.get("material", ""),
        "seasons": arguments.get("seasons", []), "occasions": arguments.get("occasions", []), "tags": arguments.get("tags", []),
        "favorite": bool(arguments.get("favorite", False)), "archived": bool(arguments.get("archived", False)),
        "laundryStatus": arguments.get("laundry_status", "available"), "useCount": 0, "lastUsedAt": None,
        "price": arguments.get("price"), "createdAt": instant, "updatedAt": instant,
    }
    state.setdefault("wardrobeItems", []).append(item)
    save_state(state)
    return item


def update_wardrobe_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    index, item = find_by_id(state.setdefault("wardrobeItems", []), arguments["item_id"], "prenda")
    mapping = {"name": "name", "category": "category", "colors": "colors", "material": "material", "seasons": "seasons",
               "occasions": "occasions", "tags": "tags", "price": "price", "favorite": "favorite", "archived": "archived",
               "laundry_status": "laundryStatus"}
    for source, target in mapping.items():
        if source in arguments:
            item[target] = arguments[source]
    item["updatedAt"] = now_iso()
    state["wardrobeItems"][index] = item
    save_state(state)
    return item


def delete_wardrobe_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    require_confirm(arguments, "delete_wardrobe_item")
    state = load_state()
    item_id = arguments["item_id"]
    index, item = find_by_id(state.setdefault("wardrobeItems", []), item_id, "prenda")
    state["wardrobeItems"].pop(index)
    for outfit in state.setdefault("wardrobeOutfits", []):
        outfit["itemIds"] = [value for value in outfit.get("itemIds", []) if value != item_id]
    state["wardrobePlanEntries"] = [entry for entry in state.setdefault("wardrobePlanEntries", []) if entry.get("itemIds") != [item_id]]
    for packing in state.setdefault("wardrobePackingLists", []):
        packing["entries"] = [entry for entry in packing.get("entries", []) if entry.get("itemId") != item_id]
    save_state(state)
    return item


def create_wardrobe_outfit_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    valid = {item.get("id") for item in state.setdefault("wardrobeItems", [])}
    outfit = {"id": make_id("wardrobe-outfit"), "name": str(arguments["name"]).strip(),
              "itemIds": list(dict.fromkeys(value for value in arguments["item_ids"] if value in valid)),
              "occasion": arguments.get("occasion", ""), "tags": arguments.get("tags", []),
              "renderImagePath": "", "createdAt": now_iso()}
    state.setdefault("wardrobeOutfits", []).append(outfit)
    save_state(state)
    return outfit


def list_wardrobe_outfits_impl(_arguments: dict[str, Any]) -> list[dict[str, Any]]:
    return load_state().setdefault("wardrobeOutfits", [])


def update_wardrobe_outfit_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    index, outfit = find_by_id(
        state.setdefault("wardrobeOutfits", []), arguments["outfit_id"], "conjunto"
    )
    if "name" in arguments:
        outfit["name"] = str(arguments["name"]).strip() or "Conjunto sin nombre"
    if "occasion" in arguments:
        outfit["occasion"] = str(arguments["occasion"]).strip()
    if "tags" in arguments:
        outfit["tags"] = list(dict.fromkeys(str(value).strip() for value in arguments["tags"] if str(value).strip()))
    previous_render = ""
    if "item_ids" in arguments:
        valid = {item.get("id") for item in state.setdefault("wardrobeItems", [])}
        item_ids = list(dict.fromkeys(value for value in arguments["item_ids"] if value in valid))
        if not item_ids:
            raise ValueError("Un conjunto debe contener al menos una prenda.")
        if set(item_ids) != set(outfit.get("itemIds", [])):
            previous_render = str(outfit.get("renderImagePath") or "")
            outfit["renderImagePath"] = ""
        outfit["itemIds"] = item_ids
    state["wardrobeOutfits"][index] = outfit
    save_state(state)
    if previous_render:
        directory = (wardrobe_directory() / "outfits").resolve()
        old_path = (wardrobe_directory() / previous_render).resolve()
        if old_path.parent == directory:
            old_path.unlink(missing_ok=True)
    return outfit


def set_wardrobe_outfit_render_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    source = Path(str(arguments["source_file"])).expanduser().resolve()
    if not source.is_file() or source.suffix.lower() != ".png":
        raise ValueError("El render debe ser un archivo PNG local.")
    data = source.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n") or len(data) < 33:
        raise ValueError("El render no es un PNG válido.")
    width, height = struct.unpack(">II", data[16:24])
    if width < 600 or height < 600:
        raise ValueError("El render debe medir al menos 600 × 600 píxeles.")
    state = load_state()
    index, outfit = find_by_id(
        state.setdefault("wardrobeOutfits", []), arguments["outfit_id"], "conjunto"
    )
    digest = hashlib.sha256(data).hexdigest()
    directory = wardrobe_directory() / "outfits"
    directory.mkdir(parents=True, exist_ok=True)
    file_name = f"{re.sub(r'[^a-zA-Z0-9_-]', '-', str(outfit['id']))}-{digest[:12]}.png"
    destination = directory / file_name
    if not destination.exists():
        temporary = destination.with_suffix(".tmp")
        try:
            temporary.write_bytes(data)
            temporary.replace(destination)
        except Exception:
            temporary.unlink(missing_ok=True)
            raise
    previous = str(outfit.get("renderImagePath") or "")
    outfit["renderImagePath"] = f"outfits/{file_name}"
    state["wardrobeOutfits"][index] = outfit
    try:
        save_state(state)
    except Exception:
        if previous != outfit["renderImagePath"]:
            destination.unlink(missing_ok=True)
        raise
    if previous and previous != outfit["renderImagePath"]:
        old_path = (wardrobe_directory() / previous).resolve()
        if old_path.parent == directory.resolve():
            old_path.unlink(missing_ok=True)
    return outfit


def record_wardrobe_wear_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    item_ids = list(dict.fromkeys(arguments["item_ids"]))
    log = {"id": make_id("wardrobe-wear"), "date": parse_datetime(arguments["date"]).isoformat(),
           "itemIds": item_ids, "outfitId": arguments.get("outfit_id"), "label": arguments.get("label", "")}
    state.setdefault("wardrobeWearLogs", []).append(log)
    for item in state.setdefault("wardrobeItems", []):
        if item.get("id") in item_ids:
            item["useCount"] = int(item.get("useCount", 0)) + 1
            item["lastUsedAt"] = log["date"]
            item["updatedAt"] = now_iso()
    save_state(state)
    return log


def set_wardrobe_laundry_status_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    status = arguments["status"]
    if status not in {"available", "toWash", "washing", "drying"}:
        raise ValueError("Estado de lavandería no válido.")
    state = load_state()
    ids = set(arguments["item_ids"])
    changed = 0
    for item in state.setdefault("wardrobeItems", []):
        if item.get("id") in ids:
            item["laundryStatus"] = status
            item["updatedAt"] = now_iso()
            changed += 1
    save_state(state)
    return {"updated": changed, "status": status}


def set_wardrobe_plan_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    date = parse_datetime(arguments["date"])
    date_key = date.date().isoformat()
    state["wardrobePlanEntries"] = [entry for entry in state.setdefault("wardrobePlanEntries", []) if not str(entry.get("date", "")).startswith(date_key)]
    entry = {"id": make_id("wardrobe-plan"), "date": date.isoformat(), "itemIds": arguments["item_ids"],
             "outfitId": arguments.get("outfit_id"), "weather": arguments.get("weather", "mild"), "occasion": arguments.get("occasion", "")}
    state["wardrobePlanEntries"].append(entry)
    save_state(state)
    return entry


def create_wardrobe_packing_list_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    packing = {"id": make_id("wardrobe-packing"), "name": arguments["name"],
               "startDate": parse_datetime(arguments["start_date"]).isoformat(),
               "endDate": parse_datetime(arguments["end_date"]).isoformat(), "entries": []}
    state.setdefault("wardrobePackingLists", []).append(packing)
    save_state(state)
    return packing


def add_wardrobe_packing_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    index, packing = find_by_id(state.setdefault("wardrobePackingLists", []), arguments["packing_list_id"], "maleta")
    item_id = arguments["item_id"]
    find_by_id(state.setdefault("wardrobeItems", []), item_id, "prenda")
    packing["entries"] = [entry for entry in packing.get("entries", []) if entry.get("itemId") != item_id]
    packing["entries"].append({"itemId": item_id, "quantity": max(1, int(arguments.get("quantity", 1))), "packed": False})
    state["wardrobePackingLists"][index] = packing
    save_state(state)
    return packing


def household_directory() -> Path:
    override = os.environ.get("TODO_MCP_HOUSEHOLD_PATH")
    directory = Path(override) if override else documents_todo_dir() / "household"
    directory.mkdir(parents=True, exist_ok=True)
    return directory


WARDROBE_CATEGORIES = [
    "Camisetas", "Camisas", "Pantalones", "Vaqueros", "Pantalones cortos",
    "Calzado", "Sudaderas", "Jerséis y cárdigans", "Chaquetas", "Abrigos",
    "Polos", "Vestidos", "Faldas", "Ropa interior", "Pijamas", "Bañadores",
    "Trajes y americanas", "Chalecos", "Monos", "Accesorios", "Otros",
]
WARDROBE_COLORS = [
    "negro", "blanco", "gris", "azul", "azul marino", "celeste", "verde",
    "verde oliva", "rojo", "granate", "rosa", "morado", "lila", "amarillo",
    "naranja", "beige", "crema", "marrón", "dorado", "plateado", "multicolor",
]
WARDROBE_SEASONS = ["todo el año", "primavera", "verano", "otoño", "invierno"]
WARDROBE_OCCASIONS = [
    "diario", "informal", "trabajo", "formal", "fiesta", "deporte", "casa",
    "viaje", "playa",
]
WARDROBE_CATEGORY_ALIASES = {
    "camiseta": "Camisetas", "t-shirt": "Camisetas", "t-shirts": "Camisetas",
    "tee": "Camisetas", "camisa": "Camisas", "pantalón": "Pantalones",
    "jean": "Vaqueros", "jeans": "Vaqueros", "vaquero": "Vaqueros",
    "bermuda": "Pantalones cortos", "bermudas": "Pantalones cortos",
    "short": "Pantalones cortos", "shorts": "Pantalones cortos",
    "zapatilla": "Calzado", "zapatillas": "Calzado", "zapato": "Calzado",
    "zapatos": "Calzado", "bota": "Calzado", "botas": "Calzado",
    "sudadera": "Sudaderas", "hoodie": "Sudaderas",
    "jersey": "Jerséis y cárdigans", "jerseys": "Jerséis y cárdigans",
    "suéter": "Jerséis y cárdigans", "cárdigan": "Jerséis y cárdigans",
    "chaqueta": "Chaquetas", "jacket": "Chaquetas", "jackets": "Chaquetas",
    "cazadora": "Chaquetas", "bomber": "Chaquetas", "abrigo": "Abrigos",
    "parka": "Abrigos", "polo": "Polos", "vestido": "Vestidos",
    "falda": "Faldas", "pijama": "Pijamas", "bañador": "Bañadores",
    "traje": "Trajes y americanas", "americana": "Trajes y americanas",
    "chaleco": "Chalecos", "mono": "Monos", "accesorio": "Accesorios",
    "otro": "Otros",
}
WARDROBE_COLOR_ALIASES = {
    "burdeos": "granate", "borgoña": "granate", "lavanda": "lila",
    "oliva": "verde oliva", "gris carbón": "gris", "gris carbon": "gris",
    "caramelo": "marrón", "taupe": "marrón",
}


def _wardrobe_key(value: Any) -> str:
    return str(value or "").strip().lower()


def _canonical_wardrobe_category(value: Any) -> str:
    key = _wardrobe_key(value)
    for category in WARDROBE_CATEGORIES:
        if _wardrobe_key(category) == key:
            return category
    singular = WARDROBE_CATEGORY_ALIASES.get(key)
    if singular:
        return singular
    if key.endswith("s"):
        singular = WARDROBE_CATEGORY_ALIASES.get(key[:-1])
        if singular:
            return singular
    raise ValueError(
        f"Categoría no reconocida: {value}. Usa una categoría canónica o 'Otros'."
    )


def _canonical_wardrobe_values(
    values: Any,
    allowed: list[str],
    aliases: dict[str, str] | None = None,
) -> list[str]:
    result: list[str] = []
    seen: set[str] = set()
    for raw in values or []:
        key = _wardrobe_key(raw)
        canonical = (aliases or {}).get(key)
        if canonical is None:
            canonical = next((item for item in allowed if _wardrobe_key(item) == key), None)
        if canonical is None:
            raise ValueError(f"Valor de clasificación no reconocido: {raw}.")
        if canonical not in seen:
            seen.add(canonical)
            result.append(canonical)
    return result


def _wardrobe_catalog_target(category: str) -> tuple[float, float]:
    if category == "Calzado":
        return 0.86, 0.52
    if category == "Pantalones cortos":
        return 0.92, 0.72
    if category in {"Pantalones", "Vaqueros", "Faldas"}:
        return 0.76, 0.86
    if category == "Accesorios":
        return 0.68, 0.62
    return 0.90, 0.80


def _prepare_direct_wardrobe_asset(
    source: Path,
    item_id: str,
    category: str,
) -> tuple[str, str, str, list[Path]]:
    if not source.is_file() or source.suffix.lower() not in {".png", ".jpg", ".jpeg", ".webp"}:
        raise ValueError("La imagen debe ser PNG, JPG, JPEG o WebP.")
    if Image is None or ImageOps is None:
        if source.suffix.lower() != ".png" or not _png_has_transparency(source):
            raise RuntimeError("Esta instalación necesita Pillow para procesar la imagen.")
        image_bytes = source.read_bytes()
        thumbnail_bytes = image_bytes
    else:
        with Image.open(source) as opened:
            prepared = ImageOps.exif_transpose(opened).convert("RGBA")
        alpha = prepared.getchannel("A")
        if alpha.getextrema()[0] < 255:
            visible = alpha.point(lambda value: 255 if value > 8 else 0)
            bounds = visible.getbbox()
            if bounds is None:
                raise ValueError("La imagen no contiene píxeles visibles.")
            prepared = prepared.crop(bounds)
            target_width, target_height = _wardrobe_catalog_target(category)
            scale = min(1200 * target_width / prepared.width, 1200 * target_height / prepared.height)
            size = (max(1, round(prepared.width * scale)), max(1, round(prepared.height * scale)))
            prepared = prepared.resize(size, Image.Resampling.LANCZOS)
            canvas = Image.new("RGBA", (1200, 1200), (0, 0, 0, 0))
            canvas.alpha_composite(prepared, ((1200 - size[0]) // 2, (1200 - size[1]) // 2))
            prepared = canvas
        else:
            longest = max(prepared.size)
            if longest > 2000:
                scale = 2000 / longest
                prepared = prepared.resize(
                    (max(1, round(prepared.width * scale)), max(1, round(prepared.height * scale))),
                    Image.Resampling.LANCZOS,
                )
        image_buffer = io.BytesIO()
        prepared.save(image_buffer, format="PNG", compress_level=6)
        image_bytes = image_buffer.getvalue()
        thumbnail = prepared.copy()
        thumbnail.thumbnail((420, 420), Image.Resampling.LANCZOS)
        thumbnail_buffer = io.BytesIO()
        thumbnail.save(thumbnail_buffer, format="PNG", compress_level=6)
        thumbnail_bytes = thumbnail_buffer.getvalue()

    digest = hashlib.sha256(image_bytes).hexdigest()
    safe_id = re.sub(r"[^a-zA-Z0-9_-]", "-", item_id)
    stem = f"{safe_id}-{digest[:12]}"
    root = wardrobe_directory()
    items = root / "items"
    thumbnails = root / "thumbnails"
    items.mkdir(parents=True, exist_ok=True)
    thumbnails.mkdir(parents=True, exist_ok=True)
    image_file = items / f"{stem}.png"
    thumbnail_file = thumbnails / f"{stem}.png"
    created: list[Path] = []
    for destination, contents in ((image_file, image_bytes), (thumbnail_file, thumbnail_bytes)):
        temporary = destination.with_suffix(".tmp")
        temporary.write_bytes(contents)
        temporary.replace(destination)
        created.append(destination)
    return f"items/{stem}.png", f"thumbnails/{stem}.png", digest, created


def _mark_mcp_changes_pending() -> None:
    path = RUNTIME_DIR / "sync_metadata.json"
    try:
        metadata = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    except (OSError, json.JSONDecodeError):
        metadata = {}
    metadata.setdefault("deviceId", "")
    metadata.setdefault("lastSeenCloudRevision", 0)
    metadata.setdefault("lastCloudHash", "")
    metadata["pendingLocalChanges"] = True
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(metadata, indent=2, ensure_ascii=False), encoding="utf-8")
    temporary.replace(path)


def import_wardrobe_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    request_id = re.sub(r"[^a-zA-Z0-9_-]", "-", str(arguments["request_id"]).strip())
    if not request_id:
        raise ValueError("request_id no puede estar vacío.")
    receipts = RUNTIME_DIR / "wardrobe_import_receipts"
    receipts.mkdir(parents=True, exist_ok=True)
    receipt_path = receipts / f"{request_id}.json"
    if receipt_path.exists():
        return json.loads(receipt_path.read_text(encoding="utf-8"))

    initial_state = read_local_state()
    repeated = next(
        (
            item
            for item in initial_state.get("wardrobeItems", [])
            if item.get("importRequestId") == request_id
        ),
        None,
    )
    if repeated is not None:
        return {
            "requestId": request_id,
            "created": False,
            "item": repeated,
            "savedLocally": True,
            "syncPending": True,
        }

    category = _canonical_wardrobe_category(arguments["category"])
    colors = _canonical_wardrobe_values(
        arguments.get("colors", []), WARDROBE_COLORS, WARDROBE_COLOR_ALIASES
    )
    seasons = _canonical_wardrobe_values(arguments.get("seasons", []), WARDROBE_SEASONS)
    occasions = _canonical_wardrobe_values(arguments.get("occasions", []), WARDROBE_OCCASIONS)
    source = Path(str(arguments["source_file"])).expanduser().resolve()
    item_id = make_id("wardrobe-item")
    created_files: list[Path] = []
    state_saved = False
    try:
        image_path, thumbnail_path, digest, created_files = _prepare_direct_wardrobe_asset(
            source, item_id, category
        )
        state = read_local_state()
        instant = now_iso()
        item = {
            "id": item_id,
            "name": str(arguments["name"]).strip() or "Prenda sin nombre",
            "category": category,
            "imagePath": image_path,
            "thumbnailPath": thumbnail_path,
            "imageSha256": digest,
            "colors": colors,
            "material": str(arguments.get("material") or "").strip(),
            "seasons": seasons,
            "occasions": occasions,
            "tags": list(dict.fromkeys(str(value).strip() for value in arguments.get("tags", []) if str(value).strip())),
            "favorite": bool(arguments.get("favorite", False)),
            "archived": False,
            "laundryStatus": str(arguments.get("laundry_status") or "available"),
            "useCount": 0,
            "lastUsedAt": None,
            "price": arguments.get("price"),
            "createdAt": instant,
            "updatedAt": instant,
            "importRequestId": request_id,
        }
        state.setdefault("wardrobeItems", []).append(item)
        touch_state(state)
        if STATE_PATH.exists():
            shutil.copy2(STATE_PATH, STATE_PATH.with_suffix(".previous"))
        write_local_state(state)
        state_saved = True
        write_app_snapshot(state)
        _mark_mcp_changes_pending()
        receipt = {
            "requestId": request_id,
            "created": True,
            "item": item,
            "savedLocally": True,
            "syncPending": True,
        }
        temporary_receipt = receipt_path.with_suffix(".tmp")
        temporary_receipt.write_text(
            json.dumps(receipt, indent=2, ensure_ascii=False), encoding="utf-8"
        )
        temporary_receipt.replace(receipt_path)
        return receipt
    except Exception:
        if not state_saved:
            for path in created_files:
                path.unlink(missing_ok=True)
        raise


def list_household_items_impl(arguments: dict[str, Any]) -> list[dict[str, Any]]:
    items = load_state().setdefault("householdItems", [])
    if bool(arguments.get("include_archived", False)):
        return items
    return [item for item in items if not item.get("archived", False)]


def _household_values(arguments: dict[str, Any]) -> dict[str, Any]:
    mapping = {
        "name": "name",
        "category": "category",
        "brand": "brand",
        "model": "model",
        "serial_number": "serialNumber",
        "location": "location",
        "notes": "notes",
        "manual_source_url": "manualSourceUrl",
        "retailer": "retailer",
        "purchase_date": "purchaseDate",
        "warranty_until": "warrantyUntil",
        "price": "price",
        "tags": "tags",
        "archived": "archived",
    }
    values: dict[str, Any] = {}
    for source, destination in mapping.items():
        if source not in arguments:
            continue
        value = arguments[source]
        if source == "tags":
            value = list(dict.fromkeys(
                str(tag).strip() for tag in value if str(tag).strip()
            ))
        elif source in {"purchase_date", "warranty_until"}:
            value = parse_datetime(str(value)).isoformat() if value else None
        elif source not in {"price", "archived"}:
            value = str(value).strip()
        values[destination] = value
    return values


def create_household_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    instant = now_iso()
    item = {
        "id": make_id("household-item"),
        "name": str(arguments["name"]).strip() or "Artículo sin nombre",
        "category": str(arguments["category"]).strip() or "Sin categoría",
        "brand": "",
        "model": "",
        "serialNumber": "",
        "location": "",
        "notes": "",
        "imagePath": "",
        "thumbnailPath": "",
        "imageSha256": "",
        "manualPath": "",
        "manualSourceUrl": "",
        "invoicePath": "",
        "retailer": "",
        "purchaseDate": None,
        "warrantyUntil": None,
        "price": None,
        "tags": [],
        "archived": False,
        "createdAt": instant,
        "updatedAt": instant,
    }
    item.update(_household_values(arguments))
    state.setdefault("householdItems", []).append(item)
    save_state(state)
    return item


def update_household_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    index, item = find_by_id(
        state.setdefault("householdItems", []),
        arguments["item_id"],
        "artículo del hogar",
    )
    item.update(_household_values(arguments))
    item["updatedAt"] = now_iso()
    state["householdItems"][index] = item
    save_state(state)
    return item


def _write_household_asset(directory: Path, file_name: str, data: bytes) -> Path:
    directory.mkdir(parents=True, exist_ok=True)
    destination = directory / file_name
    if destination.exists():
        return destination
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    try:
        temporary.write_bytes(data)
        temporary.replace(destination)
    except Exception:
        temporary.unlink(missing_ok=True)
        raise
    return destination


def _delete_household_asset(relative_path: str) -> None:
    if not relative_path:
        return
    root = household_directory().resolve()
    candidate = (root / relative_path).resolve()
    if root not in candidate.parents:
        return
    candidate.unlink(missing_ok=True)


def set_household_item_image_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    source = Path(str(arguments["source_file"])).expanduser().resolve()
    if not source.is_file() or source.suffix.lower() != ".png":
        raise ValueError("La imagen de Hogar debe ser un archivo PNG local.")
    data = source.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n") or len(data) < 33:
        raise ValueError("La imagen de Hogar no es un PNG válido.")
    width, height = struct.unpack(">II", data[16:24])
    if width < 400 or height < 400:
        raise ValueError("La imagen debe medir al menos 400 × 400 píxeles.")
    state = load_state()
    index, item = find_by_id(
        state.setdefault("householdItems", []),
        arguments["item_id"],
        "artículo del hogar",
    )
    digest = hashlib.sha256(data).hexdigest()
    safe_id = re.sub(r"[^a-zA-Z0-9_-]", "-", str(item["id"]))
    file_name = f"{safe_id}-{digest[:12]}.png"
    root = household_directory()
    _write_household_asset(root / "images", file_name, data)
    _write_household_asset(root / "thumbnails", file_name, data)
    previous = [str(item.get("imagePath") or ""), str(item.get("thumbnailPath") or "")]
    item["imagePath"] = f"images/{file_name}"
    item["thumbnailPath"] = f"thumbnails/{file_name}"
    item["imageSha256"] = digest
    item["updatedAt"] = now_iso()
    state["householdItems"][index] = item
    try:
        save_state(state)
    except Exception:
        _delete_household_asset(item["imagePath"])
        _delete_household_asset(item["thumbnailPath"])
        raise
    for old_path in previous:
        if old_path not in {item["imagePath"], item["thumbnailPath"]}:
            _delete_household_asset(old_path)
    return item


def set_household_item_document_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    kind = str(arguments["kind"]).strip().lower()
    if kind not in {"manual", "invoice"}:
        raise ValueError("kind debe ser manual o invoice.")
    source = Path(str(arguments["source_file"])).expanduser().resolve()
    if not source.is_file() or source.suffix.lower() != ".pdf":
        raise ValueError("El documento debe ser un archivo PDF local.")
    data = source.read_bytes()
    if not data.startswith(b"%PDF-"):
        raise ValueError("El documento no es un PDF válido.")
    state = load_state()
    index, item = find_by_id(
        state.setdefault("householdItems", []),
        arguments["item_id"],
        "artículo del hogar",
    )
    digest = hashlib.sha256(data).hexdigest()
    safe_id = re.sub(r"[^a-zA-Z0-9_-]", "-", str(item["id"]))
    file_name = f"{safe_id}-{digest[:12]}.pdf"
    directory_name = "manuals" if kind == "manual" else "invoices"
    relative_path = f"{directory_name}/{file_name}"
    _write_household_asset(household_directory() / directory_name, file_name, data)
    field = "manualPath" if kind == "manual" else "invoicePath"
    previous = str(item.get(field) or "")
    item[field] = relative_path
    if kind == "manual" and arguments.get("source_url"):
        item["manualSourceUrl"] = str(arguments["source_url"]).strip()
    item["updatedAt"] = now_iso()
    state["householdItems"][index] = item
    try:
        save_state(state)
    except Exception:
        _delete_household_asset(relative_path)
        raise
    if previous != relative_path:
        _delete_household_asset(previous)
    return item


def delete_household_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    require_confirm(arguments, "delete_household_item")
    state = load_state()
    index, item = find_by_id(
        state.setdefault("householdItems", []),
        arguments["item_id"],
        "artículo del hogar",
    )
    state["householdItems"].pop(index)
    save_state(state)
    for field in ("imagePath", "thumbnailPath", "manualPath", "invoicePath"):
        _delete_household_asset(str(item.get(field) or ""))
    return {"deleted": True, "item_id": arguments["item_id"]}


def recipe_directory() -> Path:
    override = os.environ.get("TODO_MCP_RECIPE_PATH")
    directory = Path(override) if override else documents_todo_dir() / "recipes"
    directory.mkdir(parents=True, exist_ok=True)
    return directory


def list_recipes_impl(arguments: dict[str, Any]) -> list[dict[str, Any]]:
    recipes = load_state().setdefault("recipes", [])
    if not bool(arguments.get("include_archived", False)):
        recipes = [recipe for recipe in recipes if not recipe.get("archived", False)]
    if bool(arguments.get("favorites_only", False)):
        recipes = [recipe for recipe in recipes if recipe.get("favorite", False)]
    return recipes


RECIPE_CONDIMENTS: tuple[tuple[str, tuple[str, ...]], ...] = (
    ("Sal", ("flor de sal", "escamas de sal", "sal marina", "sal gruesa", "sal fina", "sal")),
    ("Pimienta negra", ("pimienta negra",)),
    ("Pimienta blanca", ("pimienta blanca",)),
    ("Pimienta", ("pimienta",)),
    ("Comino", ("comino en polvo", "comino")),
    ("Jengibre", ("jengibre",)),
    ("Cúrcuma", ("curcuma",)),
    ("Pimentón", ("pimenton de la vera", "pimenton dulce", "pimenton picante", "pimenton", "paprika")),
    ("Orégano", ("oregano",)),
    ("Tomillo", ("tomillo",)),
    ("Romero", ("romero",)),
    ("Albahaca", ("albahaca",)),
    ("Perejil", ("perejil",)),
    ("Cilantro", ("cilantro",)),
    ("Eneldo", ("eneldo",)),
    ("Laurel", ("hoja de laurel", "laurel")),
    ("Canela", ("canela",)),
    ("Nuez moscada", ("nuez moscada",)),
    ("Clavo", ("clavos de olor", "clavo de olor")),
    ("Cardamomo", ("cardamomo",)),
    ("Curry", ("curry en polvo", "curry")),
    ("Garam masala", ("garam masala",)),
    ("Ras el hanout", ("ras el hanout",)),
    ("Chile", ("copos de chile", "chile en polvo", "chili flakes", "guindilla", "chile")),
    ("Cayena", ("pimienta de cayena", "cayena")),
    ("Ajo en polvo", ("ajo en polvo",)),
    ("Cebolla en polvo", ("cebolla en polvo",)),
    ("Aceite de oliva", ("aceite de oliva virgen extra", "aceite de oliva", "aove")),
    ("Aceite de sésamo", ("aceite de sesamo",)),
    ("Aceite de girasol", ("aceite de girasol",)),
    ("Aceite de coco", ("aceite de coco",)),
    ("Vinagre de manzana", ("vinagre de manzana",)),
    ("Vinagre balsámico", ("vinagre balsamico", "aceto balsamico")),
    ("Vinagre de arroz", ("vinagre de arroz",)),
    ("Vinagre", ("vinagre de vino", "vinagre")),
    ("Mostaza", ("mostaza dijon", "mostaza",)),
    ("Salsa de soja", ("salsa de soja", "soja")),
    ("Tamari", ("tamari",)),
    ("Sriracha", ("sriracha",)),
    ("Tabasco", ("tabasco",)),
    ("Salsa Worcestershire", ("salsa worcestershire", "salsa perrins")),
    ("Salsa de pescado", ("salsa de pescado",)),
    ("Tahini", ("tahini",)),
    ("Crema de cacahuete", ("mantequilla de cacahuete", "crema de cacahuete")),
    ("Miel", ("miel",)),
    ("Sirope de arce", ("sirope de arce",)),
    ("Esencia de vainilla", ("extracto de vainilla", "esencia de vainilla")),
    ("Levadura química", ("polvo de hornear", "levadura quimica")),
    ("Bicarbonato", ("bicarbonato sodico", "bicarbonato")),
)

RECIPE_MEASUREMENT_NOISE = {
    "a", "al", "aprox", "aproximadamente", "cda", "cdas", "cds", "cdta",
    "cdtas", "chorrito", "chorritos", "cocinar", "cucharada", "cucharadas",
    "cucharadita", "cucharaditas", "cuatro", "de", "decorar", "del", "dos",
    "el", "en", "fina", "fino", "fresca", "fresco", "g", "gr", "gramo",
    "gramos", "gruesa", "grueso", "gusto", "hoja", "hojas", "kg", "la",
    "las", "l", "litro", "litros", "los", "manojo", "manojos", "media",
    "medio", "ml", "molida", "molido", "o", "para", "pellizco", "pellizcos",
    "picada", "picado", "pizca", "pizcas", "polvo", "rallada", "rallado",
    "rama", "ramas", "ramita", "ramitas", "seca", "seco", "servir", "taza",
    "tazas", "tres", "trocito", "trocitos", "un", "una", "unas", "unos", "y",
}


def _normalize_recipe_ingredient(value: str) -> str:
    normalized = unicodedata.normalize("NFD", value.casefold())
    return "".join(character for character in normalized if unicodedata.category(character) != "Mn")


def _recipe_alias_pattern(alias: str) -> re.Pattern[str]:
    return re.compile(rf"\b{re.escape(_normalize_recipe_ingredient(alias))}\b", re.IGNORECASE)


def _detected_recipe_condiments(value: str) -> list[str]:
    normalized = _normalize_recipe_ingredient(value)
    detected = [
        name
        for name, aliases in RECIPE_CONDIMENTS
        if any(_recipe_alias_pattern(alias).search(normalized) for alias in aliases)
    ]
    if any(name in detected for name in ("Pimienta negra", "Pimienta blanca", "Cayena")):
        detected = [name for name in detected if name != "Pimienta"]
    if any(name.startswith("Vinagre de") or name == "Vinagre balsámico" for name in detected):
        detected = [name for name in detected if name != "Vinagre"]
    return detected


def _recipe_is_condiment(value: str) -> bool:
    if not _detected_recipe_condiments(value):
        return False
    remainder = _normalize_recipe_ingredient(value)
    for _name, aliases in RECIPE_CONDIMENTS:
        for alias in sorted(aliases, key=len, reverse=True):
            remainder = _recipe_alias_pattern(alias).sub(" ", remainder)
    remainder = re.sub(r"\d+(?:[\.,/]\d+)?", " ", remainder)
    remainder = re.sub(r"[¼½¾⅓⅔⅛⅜⅝⅞]", " ", remainder)
    words = re.sub(r"[^a-z]+", " ", remainder).split()
    return not any(word not in RECIPE_MEASUREMENT_NOISE for word in words)


def _recipe_shopping_labels(ingredient: dict[str, Any]) -> list[str]:
    text = str(ingredient.get("text", "")).strip()
    if not text:
        return []
    if ingredient.get("kind") == "condiment" or _recipe_is_condiment(text):
        detected = _detected_recipe_condiments(text)
        if detected:
            return detected
    return [text]


def _recipe_values(arguments: dict[str, Any]) -> dict[str, Any]:
    mapping = {
        "title": "title",
        "description": "description",
        "category": "category",
        "cuisine": "cuisine",
        "servings": "servings",
        "prep_minutes": "prepMinutes",
        "cook_minutes": "cookMinutes",
        "ingredients": "ingredients",
        "instructions": "instructions",
        "tags": "tags",
        "source_url": "sourceUrl",
        "image_source_url": "imageSourceUrl",
        "favorite": "favorite",
        "archived": "archived",
    }
    values: dict[str, Any] = {}
    for source, destination in mapping.items():
        if source not in arguments:
            continue
        value = arguments[source]
        if source == "ingredients":
            value = [
                {
                    "text": str(item).strip(),
                    "group": "",
                    "kind": (
                        "condiment"
                        if _recipe_is_condiment(str(item).strip())
                        else "ingredient"
                    ),
                }
                for item in value
                if str(item).strip()
            ]
        elif source in {"instructions", "tags"}:
            value = list(dict.fromkeys(
                str(item).strip() for item in value if str(item).strip()
            ))
        elif source in {"servings", "prep_minutes", "cook_minutes"}:
            minimum = 1 if source == "servings" else 0
            value = max(minimum, int(value))
        elif source not in {"favorite", "archived"}:
            value = str(value).strip()
        values[destination] = value
    return values


def create_recipe_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    instant = now_iso()
    recipe = {
        "id": make_id("recipe"),
        "title": str(arguments["title"]).strip() or "Receta sin nombre",
        "description": "",
        "category": "Sin categoría",
        "cuisine": "",
        "servings": 1,
        "prepMinutes": 0,
        "cookMinutes": 0,
        "ingredients": [],
        "instructions": [],
        "tags": [],
        "sourceUrl": "",
        "imageSourceUrl": "",
        "imagePath": "",
        "thumbnailPath": "",
        "imageSha256": "",
        "favorite": False,
        "archived": False,
        "createdAt": instant,
        "updatedAt": instant,
    }
    recipe.update(_recipe_values(arguments))
    state.setdefault("recipes", []).append(recipe)
    save_state(state)
    return recipe


def update_recipe_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    index, recipe = find_by_id(
        state.setdefault("recipes", []), arguments["recipe_id"], "receta"
    )
    recipe.update(_recipe_values(arguments))
    recipe["updatedAt"] = now_iso()
    state["recipes"][index] = recipe
    save_state(state)
    return recipe


def _delete_recipe_asset(relative_path: str) -> None:
    if not relative_path:
        return
    root = recipe_directory().resolve()
    candidate = (root / relative_path).resolve()
    if root not in candidate.parents:
        return
    candidate.unlink(missing_ok=True)


def set_recipe_image_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    source = Path(str(arguments["source_file"])).expanduser().resolve()
    if not source.is_file() or source.suffix.lower() != ".png":
        raise ValueError("La imagen de la receta debe ser un archivo PNG local.")
    data = source.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n") or len(data) < 33:
        raise ValueError("La imagen de la receta no es un PNG válido.")
    width, height = struct.unpack(">II", data[16:24])
    if width < 300 or height < 200:
        raise ValueError("La imagen debe medir al menos 300 × 200 píxeles.")
    state = load_state()
    index, recipe = find_by_id(
        state.setdefault("recipes", []), arguments["recipe_id"], "receta"
    )
    digest = hashlib.sha256(data).hexdigest()
    safe_id = re.sub(r"[^a-zA-Z0-9_-]", "-", str(recipe["id"]))
    file_name = f"{safe_id}-{digest[:12]}.png"
    root = recipe_directory()
    _write_household_asset(root / "images", file_name, data)
    _write_household_asset(root / "thumbnails", file_name, data)
    previous = [str(recipe.get("imagePath") or ""), str(recipe.get("thumbnailPath") or "")]
    recipe["imagePath"] = f"images/{file_name}"
    recipe["thumbnailPath"] = f"thumbnails/{file_name}"
    recipe["imageSha256"] = digest
    recipe["updatedAt"] = now_iso()
    state["recipes"][index] = recipe
    try:
        save_state(state)
    except Exception:
        _delete_recipe_asset(recipe["imagePath"])
        _delete_recipe_asset(recipe["thumbnailPath"])
        raise
    for old_path in previous:
        if old_path not in {recipe["imagePath"], recipe["thumbnailPath"]}:
            _delete_recipe_asset(old_path)
    return recipe


def _recipe_task_category(name: str) -> dict[str, Any]:
    state = load_state()
    for category in state.setdefault("categories", []):
        if str(category.get("name", "")).casefold() == name.casefold():
            return category
    category = {
        "id": make_id("cat"),
        "name": name,
        "description": "Creada automáticamente desde Recetas.",
        "colorValue": 0xFFDBA62D if name == "Compras" else 0xFFC7744E,
        "iconCodePoint": 0xE59C,
        "active": True,
    }
    state["categories"].append(category)
    save_state(state)
    return category


def create_recipe_task_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    kind = str(arguments["kind"]).strip().lower()
    if kind not in {"shopping", "cooking"}:
        raise ValueError("kind debe ser shopping o cooking.")
    state = load_state()
    _index, recipe = find_by_id(
        state.setdefault("recipes", []), arguments["recipe_id"], "receta"
    )
    shopping = kind == "shopping"
    if shopping:
        entries = list(dict.fromkeys(
            label
            for ingredient in recipe.get("ingredients", [])
            for label in _recipe_shopping_labels(ingredient)
        ))
    else:
        entries = [str(item).strip() for item in recipe.get("instructions", [])]
        entries = [entry for entry in entries if entry]
    if shopping and not entries:
        raise ValueError("La receta no tiene ingredientes.")
    category = _recipe_task_category("Compras" if shopping else "Cocina")
    title = (
        f"Comprar ingredientes para {recipe['title']}"
        if shopping
        else f"Preparar {recipe['title']}"
    )
    parent_result = create_task_impl({
        "title": title,
        "description": f"Tarea generada desde Recetas · {recipe.get('servings', 1)} raciones.",
        "category_ids": [category["id"]],
        "scheduled_at": arguments.get("scheduled_at"),
    })
    parent_id = parent_result["created"]["id"]
    subtasks = []
    for index, entry in enumerate(entries):
        result = create_task_impl({
            "title": entry if shopping else f"{index + 1}. {entry}",
            "category_ids": [category["id"]],
            "parent_task_id": parent_id,
            "scheduled_at": arguments.get("scheduled_at"),
        })
        subtasks.append(result["created"])
    final_state = load_state()
    _parent_index, parent = find_task(final_state, parent_id)
    return {"task": parent, "subtasks": subtasks}


def delete_recipe_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    require_confirm(arguments, "delete_recipe")
    state = load_state()
    index, recipe = find_by_id(
        state.setdefault("recipes", []), arguments["recipe_id"], "receta"
    )
    state["recipes"].pop(index)
    save_state(state)
    _delete_recipe_asset(str(recipe.get("imagePath") or ""))
    _delete_recipe_asset(str(recipe.get("thumbnailPath") or ""))
    return {"deleted": True, "recipe_id": arguments["recipe_id"]}


def list_weekly_menus_impl(arguments: dict[str, Any]) -> list[dict[str, Any]]:
    menus = load_state().setdefault("weeklyMenus", [])
    if not bool(arguments.get("include_archived", False)):
        menus = [menu for menu in menus if not menu.get("archived", False)]
    return menus


def create_weekly_menu_task_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = load_state()
    _index, menu = find_by_id(
        state.setdefault("weeklyMenus", []), arguments["menu_id"], "menú semanal"
    )
    recipe_ids = [str(value) for value in menu.get("recipeIds", [])]
    meal_entries = list(menu.get("mealEntries") or [])
    if not meal_entries:
        days = ("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday")
        meal_entries = [
            {
                "id": f"legacy-{index + 1}",
                "day": days[index % len(days)],
                "mealType": "lunch",
                "recipeId": recipe_id,
            }
            for index, recipe_id in enumerate(recipe_ids)
        ]
    requested_ids = {
        str(value) for value in (arguments.get("entry_ids") or []) if str(value)
    }
    selected_entries = (
        [entry for entry in meal_entries if str(entry.get("id")) in requested_ids]
        if requested_ids
        else meal_entries
    )
    if not selected_entries:
        raise ValueError("Selecciona al menos una comida del menú.")
    complete_menu = len(selected_entries) == len(meal_entries)
    selected_recipe_list = [
        str(entry.get("recipeId", "")) for entry in selected_entries
    ]
    selected_recipe_set = set(selected_recipe_list)
    curated_recipe_set = {
        str(value)
        for value in (menu.get("shoppingListRecipeIds") or recipe_ids)
        if str(value)
    }
    curated_selection = (
        bool(menu.get("shoppingItems"))
        and len(selected_recipe_list) == len(selected_recipe_set)
        and selected_recipe_set == curated_recipe_set
    )
    if curated_selection:
        shopping_items = [
            item
            for item in menu.get("shoppingItems", [])
            if str(item.get("name", "")).strip()
        ]
    else:
        shopping_items = []
        seen_labels: set[str] = set()
        selected_recipe_ids = {
            str(entry.get("recipeId", "")) for entry in selected_entries
        }
        for recipe in state.setdefault("recipes", []):
            if str(recipe.get("id", "")) not in selected_recipe_ids:
                continue
            for ingredient in recipe.get("ingredients", []):
                for label in _recipe_shopping_labels(ingredient):
                    if label.casefold() in seen_labels:
                        continue
                    seen_labels.add(label.casefold())
                    shopping_items.append({
                        "name": label,
                        "group": str(recipe.get("title", "")),
                        "priceCents": 0,
                    })
    if not shopping_items:
        raise ValueError("El menú no tiene lista de la compra.")
    category = _recipe_task_category("Compras")
    people = max(1, int(menu.get("people", 1)))
    total_cents = max(0, int(menu.get("totalPriceCents", 0)))
    price = (
        f" · Presupuesto aproximado: {total_cents / 100:.2f} €".replace(".", ",")
        if total_cents and curated_selection
        else ""
    )
    selected_days = {str(entry.get("day", "")) for entry in selected_entries}
    scope = (
        "semana completa"
        if complete_menu
        else f"{len(selected_entries)} comidas · {len(selected_days)} días"
    )
    parent_result = create_task_impl({
        "title": (
            f"Comprar {menu['title']}"
            if complete_menu
            else f"Comprar selección de {menu['title']}"
        ),
        "description": (
            f"Lista de compra del menú para {people} "
            f"{'persona' if people == 1 else 'personas'} · {scope}{price}."
        ),
        "category_ids": [category["id"]],
        "scheduled_at": arguments.get("scheduled_at"),
    })
    parent_id = parent_result["created"]["id"]
    subtasks = []
    seen: set[str] = set()
    for item in shopping_items:
        name = str(item["name"]).strip()
        if name.casefold() in seen:
            continue
        seen.add(name.casefold())
        group = str(item.get("group", "")).strip()
        item_cents = max(0, int(item.get("priceCents", 0)))
        description = " · ".join(filter(None, [
            group,
            (
                f"Precio orientativo: {item_cents / 100:.2f} €".replace(".", ",")
                if item_cents
                else ""
            ),
        ]))
        result = create_task_impl({
            "title": name,
            "description": description,
            "category_ids": [category["id"]],
            "parent_task_id": parent_id,
            "scheduled_at": arguments.get("scheduled_at"),
        })
        subtasks.append(result["created"])
    final_state = load_state()
    _parent_index, parent = find_task(final_state, parent_id)
    return {"task": parent, "subtasks": subtasks}


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


def knowledge_repository() -> KnowledgeRepository:
    return KnowledgeRepository(KNOWLEDGE_DIR)


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
    if name == "get_knowledge_contract":
        return json_result(knowledge_repository().contract())
    if name == "list_knowledge_pages":
        return json_result(knowledge_repository().list_pages(arguments))
    if name == "get_knowledge_page":
        return json_result(knowledge_repository().get_page(arguments["page_id"]))
    if name == "search_knowledge":
        return json_result(
            knowledge_repository().search(
                arguments["query"], int(arguments.get("limit", 50))
            )
        )
    if name == "create_knowledge_page":
        return json_result({"page": knowledge_repository().create_page(arguments)})
    if name == "update_knowledge_page":
        return json_result(
            {"page": knowledge_repository().update_page(arguments["page_id"], arguments)}
        )
    if name == "move_knowledge_page":
        return json_result(
            {"page": knowledge_repository().move_page(arguments["page_id"], arguments.get("parent_id"))}
        )
    if name == "trash_knowledge_page":
        return json_result(knowledge_repository().set_trash(arguments["page_id"], True))
    if name == "restore_knowledge_page":
        return json_result(knowledge_repository().set_trash(arguments["page_id"], False))
    if name == "list_knowledge_backlinks":
        return json_result(knowledge_repository().backlinks(arguments["page_id"]))
    if name == "list_unlinked_knowledge_pages":
        return json_result(knowledge_repository().list_unlinked())
    if name == "import_knowledge_asset":
        return json_result(knowledge_repository().import_asset(arguments))
    if name == "import_knowledge_assets":
        return json_result(knowledge_repository().import_assets(arguments))
    if name == "list_knowledge_progress":
        return json_result(knowledge_repository().list_progress(arguments))
    if name == "set_knowledge_progress":
        return json_result(knowledge_repository().set_progress(arguments))
    if name == "replace_knowledge_progress":
        return json_result(knowledge_repository().replace_progress(arguments))
    if name == "create_knowledge_collection":
        return json_result({"collection": knowledge_repository().create_collection(arguments)})
    if name == "list_knowledge_collections":
        return json_result(knowledge_repository().list_collections(arguments.get("page_id")))
    if name in {"apply_knowledge_manifest", "import_knowledge_repository"}:
        return json_result(knowledge_repository().apply_manifest(arguments["manifest"]))
    if name == "export_knowledge_repository":
        return json_result(knowledge_repository().export_archive())
    if name == "get_wardrobe_import_contract":
        return json_result(wardrobe_import_contract_impl())
    if name == "stage_wardrobe_batch":
        return json_result(stage_wardrobe_batch_impl(arguments))
    if name == "list_wardrobe_batches":
        return json_result(list_wardrobe_batches_impl(arguments))
    if name == "get_wardrobe_batch":
        return json_result(get_wardrobe_batch_impl(arguments))
    if name == "list_wardrobe_items":
        return json_result(list_wardrobe_items_impl(arguments))
    if name == "import_wardrobe_item":
        return json_result(import_wardrobe_item_impl(arguments))
    if name == "create_wardrobe_item":
        return json_result(create_wardrobe_item_impl(arguments))
    if name == "update_wardrobe_item":
        return json_result(update_wardrobe_item_impl(arguments))
    if name == "delete_wardrobe_item":
        return json_result(delete_wardrobe_item_impl(arguments))
    if name == "list_wardrobe_outfits":
        return json_result(list_wardrobe_outfits_impl(arguments))
    if name == "create_wardrobe_outfit":
        return json_result(create_wardrobe_outfit_impl(arguments))
    if name == "update_wardrobe_outfit":
        return json_result(update_wardrobe_outfit_impl(arguments))
    if name == "set_wardrobe_outfit_render":
        return json_result(set_wardrobe_outfit_render_impl(arguments))
    if name == "record_wardrobe_wear":
        return json_result(record_wardrobe_wear_impl(arguments))
    if name == "set_wardrobe_laundry_status":
        return json_result(set_wardrobe_laundry_status_impl(arguments))
    if name == "set_wardrobe_plan":
        return json_result(set_wardrobe_plan_impl(arguments))
    if name == "create_wardrobe_packing_list":
        return json_result(create_wardrobe_packing_list_impl(arguments))
    if name == "add_wardrobe_packing_item":
        return json_result(add_wardrobe_packing_item_impl(arguments))
    if name == "list_household_items":
        return json_result(list_household_items_impl(arguments))
    if name == "create_household_item":
        return json_result(create_household_item_impl(arguments))
    if name == "update_household_item":
        return json_result(update_household_item_impl(arguments))
    if name == "set_household_item_image":
        return json_result(set_household_item_image_impl(arguments))
    if name == "set_household_item_document":
        return json_result(set_household_item_document_impl(arguments))
    if name == "delete_household_item":
        return json_result(delete_household_item_impl(arguments))
    if name == "list_recipes":
        return json_result(list_recipes_impl(arguments))
    if name == "create_recipe":
        return json_result(create_recipe_impl(arguments))
    if name == "update_recipe":
        return json_result(update_recipe_impl(arguments))
    if name == "set_recipe_image":
        return json_result(set_recipe_image_impl(arguments))
    if name == "create_recipe_task":
        return json_result(create_recipe_task_impl(arguments))
    if name == "delete_recipe":
        return json_result(delete_recipe_impl(arguments))
    if name == "list_weekly_menus":
        return json_result(list_weekly_menus_impl(arguments))
    if name == "create_weekly_menu_task":
        return json_result(create_weekly_menu_task_impl(arguments))
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
