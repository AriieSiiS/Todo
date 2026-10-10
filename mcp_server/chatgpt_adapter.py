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
from chatgpt_content import SECTIONS, browse, detail, note_version

os.environ["TODO_MCP_DISABLE_REMOTE"] = "1"
os.environ["TODO_MCP_SKIP_ENV_FILE"] = "1"

import server as core


READ_TOOLS = {
    "get_today": ("Consultar tareas de hoy", "Consulta las tareas activas de hoy, incluidas las vencidas, respetando el día lógico. Para una consulta simple, responde solo con los títulos en una lista de texto, sin paneles, casillas, resúmenes ni propuestas. Los detalles se muestran únicamente si se solicitan."),
    "list_tasks": ("Buscar tareas", "Lista tareas y sus identificadores, con filtros de estado, proyecto, categoría o fecha."),
    "get_task": ("Consultar una tarea", "Consulta una tarea por su identificador antes de proponer cambios."),
    "list_projects": ("Ver proyectos", "Lista los proyectos y sus identificadores para filtrar tareas."),
    "list_categories": ("Ver categorías", "Lista las categorías y sus identificadores para filtrar tareas."),
    "list_content_sections": ("Ver colecciones", "Lista las colecciones de contenido disponibles y sus tamaños para navegar por Todo. No abre paneles."),
    "browse_content": ("Buscar en el contenido", "Busca fichas por palabras, estado y tipo en Ropa, conjuntos, usos, planes, maletas, Recetas, menús, Hogar, Compras, Biblioteca, objetivos y notas. Devuelve una página de resúmenes con next_offset; sigue las páginas necesarias antes de afirmar que no hay resultados. Responde solo a lo pedido y consulta get_content_item para detalles."),
    "get_content_item": ("Consultar ficha", "Consulta todos los datos registrados de una ficha por colección e identificador. Permite responder sobre una camisa, receta, aparato, compra, libro o juego y sus fechas o valoraciones. No lee imágenes ni documentos; no confunde objetivos pendientes con juegos completados."),
    "list_notes": ("Buscar notas", "Busca y lista notas de Entrada con filtros y páginas. Usa get_note para leer una nota completa antes de modificarla."),
    "get_note": ("Consultar nota", "Lee una nota completa y su note_version antes de editarla, archivarla o borrarla."),
}
WRITE_TOOLS = {
    "create_task": ("Crear tarea de prueba", "Crea una tarea en la sesión de prueba en memoria."),
    "update_task": ("Editar tarea de prueba", "Actualiza una tarea de la sesión de prueba; consulta primero su identificador."),
    "complete_task": ("Completar tarea de prueba", "Completa una tarea de la sesión de prueba en memoria."),
    "move_task_to_day": ("Mover tarea de prueba", "Mueve una tarea de prueba a otra fecha, conservando su hora."),
    "delete_task": ("Borrar tarea", "Borra una tarea y todas sus subtareas solo ante una petición explícita de borrar. Consulta antes su versión y comunica el alcance si tiene subtareas; requiere confirm: true. El borrado es permanente."),
    "create_note": ("Crear nota", "Crea una nota local en Entrada con su contenido y opciones indicadas."),
    "update_note": ("Editar nota", "Edita los campos indicados de una nota local y conserva los demás. Consulta primero note_version."),
    "archive_note": ("Archivar nota", "Archiva una nota local, conservando su contenido. Consulta primero note_version."),
    "delete_note": ("Borrar nota", "Borra permanentemente una nota solo ante una petición explícita de borrar. Consulta primero note_version y usa confirm: true."),
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
    string = {"type": "string", "minLength": 1}
    page = {"query": {"type": "string"}, "status": string, "type": string,
            "include_archived": {"type": "boolean"}, "limit": {"type": "integer", "minimum": 1, "maximum": 100}, "offset": {"type": "integer", "minimum": 0}}
    section = {"type": "string", "enum": list(SECTIONS)}
    custom = {
        "list_content_sections": ({}, []),
        "browse_content": ({**page, "section": section}, ["section"]),
        "get_content_item": ({"section": section, "item_id": string}, ["section", "item_id"]),
        "list_notes": (page, []),
        "get_note": ({"note_id": string}, ["note_id"]),
        "create_note": ({"content": string, "scheduled_for": string, "emoji": {"type": "string"}, "is_pinned": {"type": "boolean"}, "category_ids": {"type": "array", "items": string}}, ["content"]),
        "update_note": ({"note_id": string, "content": string, "scheduled_for": string, "clear_scheduled_for": {"type": "boolean"}, "emoji": {"type": "string"}, "is_pinned": {"type": "boolean"}, "category_ids": {"type": "array", "items": string}, "status": {"type": "string", "enum": ["inbox", "archived"]}}, ["note_id"]),
        "archive_note": ({"note_id": string}, ["note_id"]),
        "delete_note": ({"note_id": string, "confirm": {"type": "boolean", "const": True}}, ["note_id", "confirm"]),
        "delete_task": ({"task_id": string, "confirm": {"type": "boolean", "const": True}}, ["task_id", "confirm"]),
    }
    for name, (properties, required) in custom.items():
        definitions[name] = {"name": name, "inputSchema": {"type": "object", "properties": properties, "required": required}}
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
            }.get(name, set(properties))
            properties = {key: value for key, value in properties.items() if key in supported}
            schema["properties"] = properties
            properties["request_id"] = {
                "type": "string", "pattern": "^[A-Za-z0-9_-]{8,128}$",
                "description": "Identificador único de esta operación. Reutiliza el mismo valor y argumentos al reintentar; usa otro para una operación nueva.",
            }
            schema["required"].append("request_id")
            if name not in {"create_task", "create_note"}:
                properties["expected_version"] = {
                    "type": "string", "pattern": "^[a-f0-9]{64}$",
                    "description": "task_version o note_version devuelto al consultar. Si cambió, vuelve a consultar antes de modificar.",
                }
                schema["required"].append("expected_version")
            definition["title"] = title.replace(" de prueba", "")
            definition["description"] = {
                "create_task": "Crea y guarda una tarea en Todo abierto. Usa un request_id único y consérvalo para reintentos.",
                "update_task": "Edita los campos indicados de una tarea local. Requiere la versión consultada para evitar sobrescribir cambios recientes.",
                "complete_task": "Completa una tarea o la ocurrencia del día lógico de una rutina, sin volver a abrirla si se repite la petición.",
                "move_task_to_day": "Mueve una tarea local a otra fecha conservando su hora. Requiere su versión consultada.",
            }.get(name, description)
        for field in ("title", "task_id", "project_id", "category_id"):
            if field in properties:
                properties[field]["minLength"] = 1
        if name == "list_tasks" and "status" in properties:
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
            "destructiveHint": name in {"delete_task", "delete_note"},
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
        if name in {"list_content_sections", "browse_content", "get_content_item", "list_notes", "get_note"}:
            return self._content_call(name, arguments)
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
            if name in {"create_note", "update_note", "archive_note", "delete_note", "delete_task"}:
                return self._sandbox_content_write(name, arguments, state)
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

    def _content_call(self, name, arguments):
        if name == 'list_content_sections':
            live = self._bridge_call(name, {}, read_only=True) if self.live else None
            if live is not None:
                return live
            state = self._read()
            return {'sections': [{'section': section, 'title': title, 'count': len(state.get(key, []))} for section, (key, title) in SECTIONS.items()],
                    'source': 'sandbox' if self.sandbox else 'snapshot'}
        section = 'notas' if name in {'list_notes', 'get_note'} else arguments['section']
        if section not in SECTIONS:
            raise ValueError('La colección no está disponible en esta conexión.')
        live = self._bridge_call('read_content', {'section': section}, read_only=True) if self.live else None
        items = live['items'] if live is not None else self._read().get(SECTIONS[section][0], [])
        if not isinstance(items, list) or any(not isinstance(item, dict) for item in items):
            raise ValueError('La colección no contiene fichas válidas.')
        existing = {
            'notas': ('list_notes', 'notes'), 'ropa': ('list_wardrobe_items', None),
            'conjuntos': ('list_wardrobe_outfits', None), 'recetas': ('list_recipes', None),
            'menus': ('list_weekly_menus', None), 'hogar': ('list_household_items', None),
            'compras': ('list_shopping_items', None), 'biblioteca': ('list_library_items', 'items'),
            'objetivos_biblioteca': ('list_library_goals', 'goals'),
        }.get(section)
        if existing:
            with self._local_context({SECTIONS[section][0]: items}):
                response = core.handle_tool_call(existing[0], {'include_archived': True})
                payload = json.loads(response['content'][0]['text'])
                items = payload[existing[1]] if existing[1] else payload
        source = 'app' if live is not None else 'sandbox' if self.sandbox else 'snapshot'
        if name in {'get_content_item', 'get_note'}:
            result = detail(items, arguments.get('note_id') if name == 'get_note' else arguments['item_id'], section=section, source=source)
            if name == 'get_note':
                result['note'] = result.pop('item')
            return result
        result = browse(items, arguments, section=section, source=source)
        if name == 'list_notes':
            result['notes'] = result.pop('items')
        return result

    def _sandbox_content_write(self, name, arguments, state):
        if not self.sandbox:
            raise ValueError('Abre la instalación actualizada de Todo antes de modificar datos.')
        if name == 'delete_task':
            if arguments.get('confirm') is not True:
                raise ValueError('Confirma el borrado de la tarea.')
            core.find_task(state, arguments['task_id'])
            ids = {arguments['task_id']}
            while True:
                children = {t['id'] for t in state['tasks'] if t.get('parentTaskId') in ids}
                if children <= ids:
                    break
                ids |= children
            state['tasks'] = [t for t in state['tasks'] if t['id'] not in ids]
            for task in state['tasks']:
                task['subtaskIds'] = [i for i in task.get('subtaskIds', []) if i not in ids]
            result = {'deleted_ids': sorted(ids)}
        else:
            notes = state.setdefault('notes', [])
            note = next((n for n in notes if n['id'] == arguments.get('note_id')), None)
            if name == 'create_note':
                note = {'id': core.make_id('note'), 'content': '', 'status': 'inbox', 'createdAt': dt.datetime.now().isoformat(), 'categoryIds': []}
                notes.insert(0, note)
            elif note is None:
                raise ValueError('La nota no existe.')
            if name == 'delete_note':
                if arguments.get('confirm') is not True:
                    raise ValueError('Confirma el borrado de la nota.')
                notes.remove(note)
                result = {'deleted_ids': [note['id']]}
            else:
                for field, target in {'content': 'content', 'scheduled_for': 'scheduledFor', 'emoji': 'emoji', 'is_pinned': 'isPinned', 'category_ids': 'categoryIds', 'status': 'status'}.items():
                    if field in arguments:
                        note[target] = copy.deepcopy(arguments[field])
                if not str(note['content']).strip():
                    raise ValueError('La nota necesita contenido.')
                if arguments.get('clear_scheduled_for'):
                    note['scheduledFor'] = None
                if name == 'archive_note':
                    note['status'] = 'archived'
                note['updatedAt'] = dt.datetime.now().isoformat()
                result = {'created' if name == 'create_note' else 'note': {**note, 'note_version': note_version(note)}}
        self._save(state)
        return {**result, 'source': 'sandbox', 'savedLocally': False, 'persistent': False}

    def _bridge_call(self, name: str, arguments: dict[str, Any], *, read_only=False) -> dict[str, Any] | None:
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
            if read_only or name in READ_TOOLS:
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
