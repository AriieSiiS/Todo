"""Adaptador stdio estándar para conectar Todo mediante Secure MCP Tunnel."""

import argparse
import asyncio
import json
import os
from pathlib import Path

# El modo remoto se desactiva antes de cargar la configuración del MCP antiguo.
os.environ["TODO_MCP_DISABLE_REMOTE"] = "1"

from jsonschema import Draft202012Validator, ValidationError
from mcp import types
from mcp.server.lowlevel import Server
from mcp.server.stdio import stdio_server

from chatgpt_adapter import LocalBackend, tool_definitions
import server as core


def create_server(backend: LocalBackend) -> Server:
    mode = "prueba en memoria" if backend.sandbox else "solo lectura local"
    app = Server(
        "todo-chatgpt-local",
        version="0.1.0",
        instructions=(
            f"Todo funciona en modo {mode}. Consulta tareas, proyectos y categorías por sus identificadores. "
            "La fecha de get_today respeta el día lógico de Todo. "
            "Las modificaciones solo están disponibles en la sesión de prueba y no alteran datos reales."
        ),
    )
    definitions = {item["name"]: item for item in tool_definitions(backend.sandbox)}

    @app.list_tools()
    async def list_tools() -> list[types.Tool]:
        return [types.Tool.model_validate(item) for item in definitions.values()]

    # Se valida aquí para devolver los errores propios en castellano.
    @app.call_tool(validate_input=False)
    async def call_tool(name: str, arguments: dict) -> types.CallToolResult:
        try:
            if name not in definitions:
                raise ValueError("La herramienta solicitada no está habilitada en este adaptador.")
            Draft202012Validator(definitions[name]["inputSchema"]).validate(arguments)
            payload = backend.call(name, arguments)
            payload["mode"] = "sandbox" if backend.sandbox else "local_read_only"
            if backend.sandbox:
                payload["persistent"] = False
            return types.CallToolResult(
                content=[types.TextContent(type="text", text=json.dumps(payload, ensure_ascii=False))],
                structuredContent=payload,
                isError=False,
            )
        except ValidationError:
            message = "Los argumentos no cumplen el esquema de la herramienta. Revisa los campos obligatorios, los tipos y los valores permitidos."
        except ValueError as error:
            message = str(error)
        except Exception:
            # Evita devolver rutas, preferencias o detalles internos al cliente.
            message = "No se pudo completar la operación local de Todo."
        return types.CallToolResult(
            content=[types.TextContent(type="text", text=message)],
            isError=True,
        )

    return app


async def run(backend: LocalBackend) -> None:
    app = create_server(backend)
    async with stdio_server() as (read_stream, write_stream):
        await app.run(read_stream, write_stream, app.create_initialization_options())


def main() -> None:
    parser = argparse.ArgumentParser(description="Conexión privada de Todo con ChatGPT por stdio.")
    parser.add_argument("--sandbox", action="store_true", help="Usa un estado vacío en memoria; permite probar cambios sin tocar archivos.")
    parser.add_argument("--state-path", type=Path, default=core.STATE_PATH, help="Snapshot que se consulta en modo de solo lectura.")
    options = parser.parse_args()
    asyncio.run(run(LocalBackend(options.state_path, sandbox=options.sandbox)))


if __name__ == "__main__":
    main()
