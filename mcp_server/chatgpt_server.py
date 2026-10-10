"""Adaptador stdio estándar para conectar Todo mediante Secure MCP Tunnel."""

import argparse
import asyncio
import copy
import json
import os
from pathlib import Path

# El modo remoto se desactiva antes de cargar la configuración del MCP antiguo.
os.environ["TODO_MCP_DISABLE_REMOTE"] = "1"

from jsonschema import Draft202012Validator, ValidationError
from mcp import types
from mcp.server.lowlevel import Server
from mcp.server.lowlevel.helper_types import ReadResourceContents
from mcp.server.stdio import stdio_server

from chatgpt_adapter import BridgeError, LocalBackend, tool_definitions
import server as core

UI_URI = "ui://todo/hoy.html"
UI_MIME = "text/html;profile=mcp-app"


def create_server(backend: LocalBackend) -> Server:
    mode = "prueba en memoria" if backend.sandbox else "escritura mediante Todo abierto" if backend.live else "solo lectura local"
    app = Server(
        "todo-chatgpt-local",
        version="0.3.0",
        instructions=(
            f"Todo funciona en modo {mode}. Consulta tareas, proyectos y categorías por sus identificadores. "
            "La fecha de get_today respeta el día lógico de Todo. "
            "Cuando el usuario pida las tareas de hoy, usa get_today y responde únicamente con los títulos, "
            "sin introducción, resumen, sugerencias ni casillas de seguimiento. "
            "Usa open_today_panel solo cuando solicite expresamente abrir el panel de Hoy. "
            "Para otras colecciones usa browse_content y get_content_item; responde solo a lo solicitado. "
            "Distingue lo completado en Biblioteca de los objetivos pendientes, y no inventes fechas, usos o datos ausentes. "
            "source=snapshot indica los últimos datos guardados, no el estado en memoria. "
            "Antes de borrar, comprueba la ficha y el alcance; solo usa confirm=true ante una petición explícita de borrar. "
            "En modo real, cada modificación necesita request_id único; conserva identificador y argumentos al reintentar. "
            "Consulta task_version o note_version antes de modificar o borrar. Las tareas del calendario se editan desde Todo. "
            "Nunca confirmes que se guardó una tarea sin savedLocally: true. El modo de prueba no altera datos reales."
        ),
    )
    definitions = {item["name"]: item for item in tool_definitions(backend.sandbox, backend.live)}
    panel_tool = copy.deepcopy(definitions["get_today"])
    panel_tool.update(
        name="open_today_panel",
        title="Abrir panel de Hoy",
        description="Abre el panel interactivo Hoy en Todo únicamente cuando el usuario pida expresamente abrir el panel. Para consultar o mostrar las tareas en texto, usa get_today. No dupliques el panel con otra lista ni con casillas ajenas a Todo.",
    )
    definitions["open_today_panel"] = panel_tool
    panel_tool["_meta"] = {
        "ui": {"resourceUri": UI_URI},
        "openai/ui": {"entrypoints": [{"type": "global"}, {"type": "thread"}]},
    }

    @app.list_resources()
    async def list_resources() -> list[types.Resource]:
        return [types.Resource(uri=UI_URI, name="todo-hoy", title="Hoy en Todo", mimeType=UI_MIME)]

    @app.read_resource()
    async def read_resource(uri) -> list[ReadResourceContents]:
        if str(uri) != UI_URI:
            raise ValueError("El recurso solicitado no existe.")
        return [ReadResourceContents(
            content=Path(__file__).with_name("ui").joinpath("hoy.html").read_text(encoding="utf-8"),
            mime_type=UI_MIME,
            meta={
                "ui": {"prefersBorder": True, "csp": {"connectDomains": [], "resourceDomains": []}},
                "openai/widgetDescription": "Panel de las tareas de hoy con acciones reales en Todo. Ya muestra la lista; evita repetirla en texto o añadir casillas de seguimiento ajenas a Todo.",
            },
        )]

    @app.list_tools()
    async def list_tools() -> list[types.Tool]:
        return [types.Tool.model_validate(item) for item in definitions.values()]

    # Se valida aquí para devolver los errores propios en castellano.
    @app.call_tool(validate_input=False)
    async def call_tool(name: str, arguments: dict) -> types.CallToolResult:
        retryable = False
        try:
            if name not in definitions:
                raise ValueError("La herramienta solicitada no está habilitada en este adaptador.")
            Draft202012Validator(definitions[name]["inputSchema"]).validate(arguments)
            backend_name = "get_today" if name == "open_today_panel" else name
            payload = await asyncio.to_thread(backend.call, backend_name, arguments)
            payload["mode"] = "sandbox" if backend.sandbox else "local_app" if backend.live else "local_read_only"
            payload["writes_available"] = backend.sandbox or (backend.live and payload.get("source") == "app")
            if backend.sandbox:
                payload["persistent"] = False
            return types.CallToolResult(
                content=[types.TextContent(type="text", text=json.dumps(payload, ensure_ascii=False))],
                structuredContent=payload,
                isError=False,
            )
        except ValidationError:
            message = "Los argumentos no cumplen el esquema de la herramienta. Revisa los campos obligatorios, los tipos y los valores permitidos."
        except BridgeError as error:
            message = str(error)
            retryable = error.retryable
        except ValueError as error:
            message = str(error)
        except Exception:
            # Evita devolver rutas, preferencias o detalles internos al cliente.
            message = "No se pudo completar la operación local de Todo."
            retryable = name not in definitions or not definitions[name]["annotations"]["readOnlyHint"]
        return types.CallToolResult(
            content=[types.TextContent(type="text", text=message)],
            structuredContent={"error": message, "retryable": retryable},
            isError=True,
        )

    return app


async def run(backend: LocalBackend) -> None:
    app = create_server(backend)
    async with stdio_server() as (read_stream, write_stream):
        await app.run(read_stream, write_stream, app.create_initialization_options())


def main() -> None:
    parser = argparse.ArgumentParser(description="Conexión privada de Todo con ChatGPT por stdio.")
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--sandbox", action="store_true", help="Usa un estado vacío en memoria; permite probar cambios sin tocar archivos.")
    modes.add_argument("--live", action="store_true", help="Solicita escrituras al puente de Todo abierto; nunca escribe directamente el snapshot.")
    parser.add_argument("--state-path", type=Path, default=core.STATE_PATH, help="Snapshot que se consulta en modo de solo lectura.")
    options = parser.parse_args()
    asyncio.run(run(LocalBackend(options.state_path, sandbox=options.sandbox, live=options.live)))


if __name__ == "__main__":
    main()
