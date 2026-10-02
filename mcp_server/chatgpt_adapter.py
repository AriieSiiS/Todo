"""Superficie privada de Todo: lectura local y escritura de prueba en memoria."""

import copy
import calendar
import datetime as dt
import json
import http.client
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


class BridgeError(ValueError):
    def __init__(self, message: str, *, retryable: bool):
        super().__init__(message)
        self.retryable = retryable


def tool_definitions(sandbox: bool = False, live: bool = False) -> list[dict[str, Any]]:
    definitions = {item["name"]: item for item in core.tool_definitions()}
    definitions["get_task"] = {
        "name": "get_task",
        "inputSchema": {
            "type": "object",
            "required": ["task_id"],
            "properties": {"task_id": {"type": "string", "minLength": 1}},
        },
    }
    exposed = {**READ_TOOLS, **(WRITE_TOOLS if sandbox or live else {})}
    result = []
    for name, (title, description) in exposed.items():
        definition = copy.deepcopy(definitions[name])
        definition.update(title=title, description=description)
        schema = definition["inputSchema"]
        schema["additionalProperties"] = False
        properties = schema["properties"]
        if live and name in WRITE_TOOLS:
            supported = {
                "create_task": {"title", "description", "scheduled_at", "priority", "category_ids", "project_ids", "recurrence_type", "recurrence_interval", "recurrence_weekdays"},
                "update_task": {"task_id", "title", "description", "scheduled_at", "clear_scheduled_at", "priority", "category_ids", "project_ids"},
                "complete_task": {"task_id"},
                "move_task_to_day": {"task_id", "date"},
            }[name]
            properties = {key: value for key, value in properties.items() if key in supported}
            schema["properties"] = properties
            properties["request_id"] = {
                "type": "string", "pattern": "^[A-Za-z0-9_-]{8,128}$",
                "description": "Identificador único de esta operación. Reutiliza el mismo valor y argumentos al reintentar; usa otro para una operación nueva.",
            }
            schema["required"].append("request_id")
            if name != "create_task":
                properties["expected_version"] = {
                    "type": "string", "pattern": "^[a-f0-9]{64}$",
                    "description": "task_version devuelto al consultar la tarea. Si cambió, vuelve a consultar antes de editar.",
                }
                schema["required"].append("expected_version")
            definition["title"] = title.replace(" de prueba", "")
            definition["description"] = {
                "create_task": "Crea y guarda una tarea en Todo abierto. Usa un request_id único y consérvalo para reintentos.",
                "update_task": "Edita los campos indicados de una tarea local. Requiere la versión consultada para evitar sobrescribir cambios recientes.",
                "complete_task": "Completa una tarea o la ocurrencia del día lógico de una rutina, sin volver a abrirla si se repite la petición.",
                "move_task_to_day": "Mueve una tarea local a otra fecha conservando su hora. Requiere su versión consultada.",
            }[name]
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
            if live:
                properties["recurrence_interval"]["maximum"] = 3650
        if "recurrence_weekdays" in properties:
            properties["recurrence_weekdays"]["items"].update(minimum=1, maximum=7)
        definition["annotations"] = {
            "readOnlyHint": name in READ_TOOLS,
            "destructiveHint": False,
            "idempotentHint": name in READ_TOOLS or live,
            "openWorldHint": False,
        }
        result.append(definition)
    return result


class LocalBackend:
    def __init__(self, state_path: Path, *, sandbox: bool = False, live: bool = False) -> None:
        if sandbox and live:
            raise ValueError("Los modos de prueba y de escritura real son excluyentes.")
        self.state_path = state_path
        self.sandbox = sandbox
        self.live = live
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
        allowed = set(READ_TOOLS) | (set(WRITE_TOOLS) if self.sandbox or self.live else set())
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
        if self.live:
            result = self._bridge_call(name, arguments)
            if result is not None:
                return result
        with _CORE_LOCK:
            state = self._read()
            if name == "get_today":
                today = self._logical_date(state)
                tasks = [copy.deepcopy(task) for task in state["tasks"]
                    if task.get("status", "active") == "active" and not task.get("parentTaskId")
                    and self._matches_date(task, today, today, overdue=True)]
                self._sort_today(tasks, state)
                return {"date": today.isoformat(), "logical_date": today.isoformat(), "tasks": tasks,
                    "count": len(tasks), "source": "sandbox" if self.sandbox else "snapshot"}
            if name == "list_tasks" and "date" in arguments:
                today = self._logical_date(state)
                target = today if arguments["date"] == "today" else dt.date.fromisoformat(arguments["date"])
                tasks = [copy.deepcopy(task) for task in state["tasks"]
                    if ("status" not in arguments or task.get("status") == arguments["status"])
                    and ("project_id" not in arguments or arguments["project_id"] in task.get("projectIds", []))
                    and ("category_id" not in arguments or arguments["category_id"] in task.get("categoryIds", []))
                    and self._matches_date(task, target, today, overdue=arguments["date"] == "today")]
                return {"tasks": tasks, "count": len(tasks), "source": "sandbox" if self.sandbox else "snapshot"}
            with self._local_context(state):
                if name == "get_task":
                    payload = {"task": copy.deepcopy(core.find_task(state, arguments["task_id"])[1])}
                    if self.live:
                        payload.update(source="snapshot", writes_available=False)
                    return payload
                result = core.handle_tool_call(name, arguments)
                payload = json.loads(result["content"][0]["text"])
                if self.live:
                    payload["source"] = "snapshot"
                    payload["writes_available"] = False
                return payload

    def _bridge_call(self, name: str, arguments: dict[str, Any]) -> dict[str, Any] | None:
        connection = None
        try:
            session_path = self.state_path.parent / "agent_bridge_session.json"
            if session_path.stat().st_size > 4096:
                raise ValueError("La sesión local del puente no es válida.")
            session = json.loads(session_path.read_text(encoding="utf-8"))
            port, token = session.get("port"), session.get("token")
            if (session.get("version") != 1 or type(port) is not int or not 1 <= port <= 65535
                    or not isinstance(token, str) or len(token) != 44):
                raise ValueError("La sesión local del puente no es válida.")
            # Conexión directa a loopback: sin proxies, redirecciones ni URLs de entrada.
            connection = http.client.HTTPConnection("127.0.0.1", port, timeout=15)
            body = json.dumps({"name": name, "arguments": arguments}, ensure_ascii=False).encode("utf-8")
            connection.request("POST", "/command", body=body, headers={
                "Authorization": f"Bearer {token}", "Content-Type": "application/json",
            })
            response = connection.getresponse()
            data = json.loads(response.read(4 * 1024 * 1024).decode("utf-8"))
            if response.status != 200:
                raise BridgeError(data.get("error", "No se pudo completar la operación en Todo."), retryable=response.status >= 500)
            if not isinstance(data, dict):
                raise BridgeError("La respuesta del puente no es válida. Reintenta la misma operación.", retryable=name in WRITE_TOOLS)
            return data
        except (OSError, http.client.HTTPException) as error:
            if name in READ_TOOLS:
                return None
            raise BridgeError("Abre la instalación actualizada de Todo antes de modificar tareas. Si una petición quedó sin respuesta, reintenta con el mismo request_id y argumentos.", retryable=True) from error
        except (json.JSONDecodeError, UnicodeError, AttributeError) as error:
            raise BridgeError("La sesión o la respuesta del puente no contiene JSON válido. Reintenta la misma operación.", retryable=name in WRITE_TOOLS) from error
        finally:
            if connection is not None:
                connection.close()

    @staticmethod
    def _local_datetime(value):
        parsed = core.parse_datetime(value)
        return parsed.astimezone().replace(tzinfo=None) if parsed and parsed.tzinfo else parsed

    @classmethod
    def _logical_date(cls, state):
        now = dt.datetime.now()
        natural = (now - dt.timedelta(days=1) if now.hour < state.get("daySettings", {}).get("dayEndsAtHour", 5) else now).date()
        manual = cls._local_datetime(state.get("manualLogicalDate"))
        started = cls._local_datetime(state.get("manualLogicalDateStartedAt"))
        return manual.date() if manual and started and now >= started and manual.date() != natural else natural

    @classmethod
    def _matches_date(cls, task, target, today, *, overdue):
        scheduled = cls._local_datetime(task.get("scheduledAt"))
        rule = task.get("recurrence") or {}
        kind = rule.get("type", "none")
        if kind == "none":
            return scheduled is None or scheduled.date() == target or (
                overdue and task.get("status", "active") == "active" and scheduled.date() < target)
        key = target.isoformat()
        if task.get("status", "active") == "active" and (key in task.get("recurrenceCompletions", {}) or key in task.get("skippedRecurrenceOccurrences", [])):
            return False
        if kind == "daily" and target != today:
            return False
        start = scheduled.date() if scheduled else target
        interval = max(1, int(rule.get("interval", 1)))
        if target < start or (rule.get("activeMonths") and target.month not in rule["activeMonths"]):
            return False
        days = (target - start).days
        if kind in ("daily", "everyXDays"):
            return days % interval == 0
        if kind == "weekly":
            return days % (7 * interval) == 0
        if kind == "monthly":
            months = (target.year - start.year) * 12 + target.month - start.month
            return months % interval == 0 and target.day == min(start.day, calendar.monthrange(target.year, target.month)[1])
        if kind == "yearly":
            return target.month == start.month and target.day == start.day and (target.year - start.year) % interval == 0
        return False

    @classmethod
    def _sort_today(cls, tasks, state):
        kind = state.get("todaySort", "manual")
        if kind in ("category", "project"):
            field = "categoryIds" if kind == "category" else "projectIds"
            entities = state["categories" if kind == "category" else "projects"]
            names = {}
            for entity in entities:
                names.setdefault(entity["id"], entity.get("name", ""))
            tasks.sort(key=lambda task: names.get((task.get(field) or [None])[0], "zzz"))
        elif kind == "priority":
            tasks.sort(key=lambda task: ["low", "medium", "high", "urgent"].index(task.get("priority", "medium")), reverse=True)
        elif kind == "time":
            tasks.sort(key=lambda task: cls._local_datetime(task.get("scheduledAt")) or dt.datetime.combine(cls._logical_date(state), dt.time()))
        else:
            tasks.sort(key=lambda task: task.get("manualOrder", 0))
