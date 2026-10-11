import contextlib
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
from home_twin_repository import HomeTwinRepository


if __name__ == "__main__":
    # Al ejecutarse como script, las herramientas importan este mismo módulo.
    sys.modules.setdefault("server", sys.modules[__name__])


PROTOCOL_VERSION = "2025-03-26"
SERVER_INFO = {"name": "todo-mcp", "version": "0.4.0"}
REPO_ROOT = Path(__file__).resolve().parent.parent
MCP_DIR = REPO_ROOT / "mcp_server"


def load_env_file() -> None:
    # El adaptador privado usa solo datos locales y omite las credenciales.
    if os.environ.get("TODO_MCP_SKIP_ENV_FILE") == "1":
        return
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
        "shoppingItems": [],
        "plants": [],
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
        "navOrder": [
            "today",
            "projects",
            "categories",
            "expenses",
            "calendar",
            "library",
            "wardrobe",
            "household",
            "plants",
            "recipes",
            "completed",
            "settings",
        ],
        "updatedAt": now_iso(),
        "schemaVersion": 11,
        "lastModifiedBy": "mcp",
    }


def ensure_runtime_dir() -> None:
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)


def read_local_state() -> dict[str, Any]:
    global _base_signature
    ensure_runtime_dir()
    if not STATE_PATH.exists():
        state = default_state()
        write_local_state(state)
        return state
    content = STATE_PATH.read_bytes()
    _base_signature = hashlib.sha256(content).hexdigest()
    raw = content.decode("utf-8").strip()
    if not raw:
        state = default_state()
        write_local_state(state)
        return state
    return json.loads(raw)


class StateConflict(RuntimeError):
    """El archivo de estado cambió (por ejemplo, lo guardó la app) tras leerlo."""


# Huella del archivo de estado tal como se leyó o se escribió por última vez.
# Sirve para no pisar los cambios que la app guarde mientras una herramienta
# modifica su copia en memoria.
_base_signature: str | None = None


def _file_signature() -> str | None:
    try:
        return hashlib.sha256(STATE_PATH.read_bytes()).hexdigest()
    except FileNotFoundError:
        return None


@contextlib.contextmanager
def _state_write_lock():
    """Bloqueo entre procesos para que la comprobación y el reemplazo sean atómicos."""
    ensure_runtime_dir()
    with open(STATE_PATH.with_name(STATE_PATH.name + ".lock"), "a+b") as handle:
        handle.seek(0)
        if os.name == "nt":
            import msvcrt

            while True:
                try:
                    msvcrt.locking(handle.fileno(), msvcrt.LK_LOCK, 1)
                    break
                except OSError:
                    continue
            try:
                yield
            finally:
                handle.seek(0)
                msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
        else:
            import fcntl

            fcntl.flock(handle, fcntl.LOCK_EX)
            try:
                yield
            finally:
                fcntl.flock(handle, fcntl.LOCK_UN)


def write_local_state(state: dict[str, Any], *, check_conflict: bool = False) -> None:
    global _base_signature
    ensure_runtime_dir()
    with _state_write_lock():
        if check_conflict and _file_signature() != _base_signature:
            raise StateConflict(
                "El estado cambió mientras se procesaba la operación; se reintentará."
            )
        temp = STATE_PATH.with_suffix(".tmp")
        temp.write_text(json.dumps(state, indent=2, ensure_ascii=False), encoding="utf-8")
        temp.replace(STATE_PATH)
        _base_signature = _file_signature()


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
    migrated = migrate_task_reminders(state) or migrated
    migrated = migrate_removed_visual_mode(state) or migrated
    migrated = migrate_plants_feature(state) or migrated
    if migrated:
        touch_state(state)
    if migrated or from_remote:
        # Leer no debe reescribir el archivo: podría pisar un guardado de la app.
        write_local_state(state)
        write_app_snapshot(state)
    if remote_enabled() and (migrated or not from_remote):
        write_remote_state(state)
    return state


def save_state(state: dict[str, Any]) -> None:
    touch_state(state)
    write_local_state(state, check_conflict=True)
    write_app_snapshot(state)
    if remote_enabled():
        write_remote_state(state)


def touch_state(state: dict[str, Any]) -> None:
    state["updatedAt"] = now_iso()
    state["schemaVersion"] = max(11, int(state.get("schemaVersion", 1) or 1))
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


def migrate_task_reminders(state: dict[str, Any]) -> bool:
    changed = False
    for task in state.get("tasks", []):
        rules = task_reminder_rules(task)
        expected_legacy = copy.deepcopy(rules[0]) if rules else None
        requires_delivery_migration = any(
            rule.get("deliveryMode") not in {"normal", "important"}
            for rule in rules
        )
        if (
            task.get("reminderRules") != rules
            or task.get("reminderRule") != expected_legacy
            or requires_delivery_migration
        ):
            write_task_reminder_rules(task, rules)
            changed = True
    if int(state.get("schemaVersion", 1) or 1) < 9:
        state["schemaVersion"] = 9
        changed = True
    return changed


def migrate_removed_visual_mode(state: dict[str, Any]) -> bool:
    changed = state.pop("visualMode", None) is not None
    if int(state.get("schemaVersion", 1) or 1) < 8:
        state["schemaVersion"] = 8
        changed = True
    return changed


def migrate_plants_feature(state: dict[str, Any]) -> bool:
    ensure_core_lists(state)
    changed = int(state.get("schemaVersion", 1) or 1) < 11
    sample_id = "plant-example-spider"
    samples = [plant for plant in state["plants"] if plant.get("id") == sample_id]
    if samples:
        state["plants"] = [
            plant for plant in state["plants"] if plant.get("id") != sample_id
        ]
        changed = True
    task_count = len(state["tasks"])
    state["tasks"] = [
        task for task in state["tasks"] if task.get("sourcePlantId") != sample_id
    ]
    changed = changed or len(state["tasks"]) != task_count
    had_category = any(
        str(category.get("name") or "").strip().casefold() == "plantas"
        for category in state["categories"]
    )
    _ensure_plants_category(state)
    changed = changed or not had_category
    for sample in samples:
        _delete_plant_asset(str(sample.get("imagePath") or ""))
        _delete_plant_asset(str(sample.get("thumbnailPath") or ""))
    state["schemaVersion"] = max(11, int(state.get("schemaVersion", 1) or 1))
    return changed


def find_by_id(items: list[dict[str, Any]], item_id: str, label: str) -> tuple[int, dict[str, Any]]:
    for index, item in enumerate(items):
        if item.get("id") == item_id:
            return index, item
    raise ValueError(f"No existe {label} '{item_id}'.")


def normalize_frequency(value: str | None) -> str:
    if not value:
        return "monthly"
    normalized = value.strip()
    if normalized not in {"weekly", "monthly", "yearly", "custom"}:
        raise ValueError("frequency debe ser weekly, monthly, yearly o custom.")
    return normalized


VALID_TASK_PRIORITIES = {"low", "medium", "high", "urgent"}
VALID_TASK_STATUSES = {"active", "completed", "archived"}
VALID_PROJECT_STATUSES = {"active", "paused", "completed", "cancelled"}
VALID_NOTE_STATUSES = {"inbox", "converted", "archived"}
VALID_RECURRENCE_TYPES = {"none", "daily", "everyXDays", "weekly", "monthly", "yearly"}
VALID_TODAY_SORTS = {"manual", "category", "time", "project", "priority"}
VALID_SECTIONS = {"today", "projects", "inbox", "categories", "expenses", "calendar", "library", "wardrobe", "household", "plants", "recipes", "completed", "settings"}


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


def household_directory() -> Path:
    override = os.environ.get("TODO_MCP_HOUSEHOLD_PATH")
    directory = Path(override) if override else documents_todo_dir() / "household"
    directory.mkdir(parents=True, exist_ok=True)
    return directory


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


def shopping_directory() -> Path:
    override = os.environ.get("TODO_MCP_SHOPPING_DIR")
    directory = Path(override) if override else documents_todo_dir() / "shopping"
    directory.mkdir(parents=True, exist_ok=True)
    return directory


def plants_directory() -> Path:
    override = os.environ.get("TODO_MCP_PLANTS_PATH")
    directory = Path(override) if override else documents_todo_dir() / "plants"
    directory.mkdir(parents=True, exist_ok=True)
    return directory


def recipe_directory() -> Path:
    override = os.environ.get("TODO_MCP_RECIPE_PATH")
    directory = Path(override) if override else documents_todo_dir() / "recipes"
    directory.mkdir(parents=True, exist_ok=True)
    return directory


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


from herramientas.ajustes import *  # noqa: F401,F403
from herramientas.biblioteca import *  # noqa: F401,F403
from herramientas.calendario import *  # noqa: F401,F403
from herramientas.compras import *  # noqa: F401,F403
from herramientas.definiciones import *  # noqa: F401,F403
from herramientas.gastos import *  # noqa: F401,F403
from herramientas.hogar import *  # noqa: F401,F403
from herramientas.notas import *  # noqa: F401,F403
from herramientas.plantas import *  # noqa: F401,F403
from herramientas.recetas import *  # noqa: F401,F403
from herramientas.ropa import *  # noqa: F401,F403
from herramientas.tareas import *  # noqa: F401,F403


def handle_tool_call(name: str, arguments: dict[str, Any]) -> dict[str, Any]:
    """Ejecuta la herramienta y la repite sobre el estado nuevo si la app guardó antes."""
    for attempt in range(5):
        try:
            return _handle_tool_call_once(name, arguments)
        except StateConflict:
            if attempt == 4:
                raise RuntimeError(
                    "No se pudo guardar: la app modificó el estado varias veces "
                    "seguidas. Vuelve a intentarlo."
                )
    raise AssertionError("inalcanzable")


def _handle_tool_call_once(name: str, arguments: dict[str, Any]) -> dict[str, Any]:
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
    if name == "set_wardrobe_item_image":
        return json_result(set_wardrobe_item_image_impl(arguments))
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
    if name == "list_shopping_items":
        return json_result(list_shopping_items_impl(arguments))
    if name == "create_shopping_item":
        return json_result(create_shopping_item_impl(arguments))
    if name == "update_shopping_item":
        return json_result(update_shopping_item_impl(arguments))
    if name == "set_shopping_item_image":
        return json_result(set_shopping_item_image_impl(arguments))
    if name == "delete_shopping_item":
        return json_result(delete_shopping_item_impl(arguments))
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
    if name == "list_home_twin_rooms":
        return json_result(HomeTwinRepository(household_directory()).list_rooms())
    if name == "import_home_twin_room":
        household_ids = {
            str(item.get("id"))
            for item in read_local_state().get("householdItems", [])
            if isinstance(item, dict)
        }
        return json_result(HomeTwinRepository(household_directory()).import_room(
            arguments, household_ids,
        ))
    if name == "get_plant_contract":
        return json_result(get_plant_contract_impl())
    if name == "list_plants":
        return json_result(list_plants_impl(arguments))
    if name == "create_plant":
        return json_result(create_plant_impl(arguments))
    if name == "update_plant":
        return json_result(update_plant_impl(arguments))
    if name == "set_plant_image":
        return json_result(set_plant_image_impl(arguments))
    if name == "delete_plant":
        return json_result(delete_plant_impl(arguments))
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
