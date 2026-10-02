"""Superficie privada de Todo: lectura local y escritura de prueba en memoria."""

import copy
import datetime as dt
import json
import os
import threading
from contextlib import contextmanager
from pathlib import Path
from typing import Any

os.environ["TODO_MCP_DISABLE_REMOTE"] = "1"
os.environ["TODO_MCP_SKIP_ENV_FILE"] = "1"

import server as core


READ_TOOLS = {
    "get_today": ("Ver tareas de hoy", "Devuelve la fecha lógica y las tareas activas de hoy, incluidas las vencidas."),
    "list_tasks": ("Buscar tareas", "Lista tareas y sus identificadores, con filtros de estado, proyecto, categoría o fecha."),
    "get_task": ("Consultar una tarea", "Consulta una tarea por su identificador antes de proponer cambios."),
    "list_projects": ("Ver proyectos", "Lista los proyectos y sus identificadores para filtrar tareas."),
    "list_categories": ("Ver categorías", "Lista las categorías y sus identificadores para filtrar tareas."),
}
WRITE_TOOLS = {
    "create_task": ("Crear tarea de prueba", "Crea una tarea en la sesión de prueba en memoria."),
    "update_task": ("Editar tarea de prueba", "Actualiza una tarea de la sesión de prueba; consulta primero su identificador."),
    "complete_task": ("Completar tarea de prueba", "Completa una tarea de la sesión de prueba en memoria."),
    "move_task_to_day": ("Mover tarea de prueba", "Mueve una tarea de prueba a otra fecha, conservando su hora."),
}
_CORE_LOCK = threading.RLock()


def tool_definitions(sandbox: bool = False) -> list[dict[str, Any]]:
    definitions = {item["name"]: item for item in core.tool_definitions()}
    definitions["get_task"] = {
        "name": "get_task",
        "inputSchema": {
            "type": "object",
            "required": ["task_id"],
            "properties": {"task_id": {"type": "string", "minLength": 1}},
        },
    }
    exposed = {**READ_TOOLS, **(WRITE_TOOLS if sandbox else {})}
    result = []
    for name, (title, description) in exposed.items():
        definition = copy.deepcopy(definitions[name])
        definition.update(title=title, description=description)
        schema = definition["inputSchema"]
        schema["additionalProperties"] = False
        properties = schema["properties"]
        for field in ("title", "task_id", "project_id", "category_id"):
            if field in properties:
                properties[field]["minLength"] = 1
        if "status" in properties:
            properties["status"]["enum"] = sorted(core.VALID_TASK_STATUSES)
        if "priority" in properties:
            properties["priority"]["enum"] = sorted(core.VALID_TASK_PRIORITIES)
        if "recurrence_type" in properties:
            properties["recurrence_type"]["enum"] = sorted(core.VALID_RECURRENCE_TYPES)
        if "recurrence_interval" in properties:
            properties["recurrence_interval"]["minimum"] = 1
        if "recurrence_weekdays" in properties:
            properties["recurrence_weekdays"]["items"].update(minimum=1, maximum=7)
        definition["annotations"] = {
            "readOnlyHint": name in READ_TOOLS,
            "destructiveHint": False,
            "idempotentHint": name in READ_TOOLS,
            "openWorldHint": False,
        }
        result.append(definition)
    return result


class LocalBackend:
    def __init__(self, state_path: Path, *, sandbox: bool = False) -> None:
        self.state_path = state_path
        self.sandbox = sandbox
        self._sandbox_state = core.default_state() if sandbox else None

    def _read(self) -> dict[str, Any]:
        if self.sandbox:
            return copy.deepcopy(self._sandbox_state)
        try:
            state = json.loads(self.state_path.read_text(encoding="utf-8"))
        except OSError as error:
            raise ValueError("No se pudo leer el snapshot local de Todo. No se ha creado ni modificado ningún archivo.") from error
        except (json.JSONDecodeError, UnicodeError) as error:
            raise ValueError("El snapshot local no contiene JSON UTF-8 válido. No se ha modificado.") from error
        if not isinstance(state, dict):
            raise ValueError("El snapshot local debe ser un objeto JSON.")
        for field in ("tasks", "projects", "categories"):
            if not isinstance(state.get(field), list) or any(not isinstance(item, dict) for item in state[field]):
                raise ValueError("El snapshot local no contiene listas válidas de tareas, proyectos y categorías.")
        return state

    def _save(self, state: dict[str, Any]) -> None:
        if not self.sandbox:
            raise ValueError("La escritura sobre datos reales aún no está habilitada.")
        core.touch_state(state)
        self._sandbox_state = copy.deepcopy(state)

    @contextmanager
    def _local_context(self, state: dict[str, Any]):
        # Los manejadores antiguos se reutilizan sin sus escrituras de lectura,
        # preferencias ni conexiones remotas. El bloqueo protege su contexto.
        with _CORE_LOCK:
            original_load = core.load_state
            original_save = core.save_state
            original_remote = core.remote_enabled
            core.load_state = lambda: copy.deepcopy(state)
            core.save_state = self._save
            core.remote_enabled = lambda: False
            try:
                yield
            finally:
                core.load_state = original_load
                core.save_state = original_save
                core.remote_enabled = original_remote

    def call(self, name: str, arguments: dict[str, Any]) -> dict[str, Any]:
        allowed = set(READ_TOOLS) | (set(WRITE_TOOLS) if self.sandbox else set())
        if name not in allowed:
            raise ValueError("La herramienta solicitada no está habilitada en este adaptador.")
        if "title" in arguments and not arguments["title"].strip():
            raise ValueError("El título de la tarea no puede estar vacío.")
        if "date" in arguments and arguments["date"] != "today":
            try:
                parsed_date = dt.date.fromisoformat(arguments["date"])
                if parsed_date.isoformat() != arguments["date"]:
                    raise ValueError
            except ValueError as error:
                raise ValueError("La fecha debe tener el formato YYYY-MM-DD.") from error
        if name == "move_task_to_day" and arguments["date"] == "today":
            raise ValueError("La fecha de destino debe tener el formato YYYY-MM-DD.")
        if arguments.get("scheduled_at"):
            try:
                if core.parse_datetime(arguments["scheduled_at"]) is None:
                    raise ValueError
            except ValueError as error:
                raise ValueError("La fecha y hora deben tener un formato ISO 8601 válido.") from error
        with _CORE_LOCK:
            state = self._read()
            with self._local_context(state):
                if name == "get_task":
                    return {"task": copy.deepcopy(core.find_task(state, arguments["task_id"])[1])}
                result = core.handle_tool_call(name, arguments)
                return json.loads(result["content"][0]["text"])
