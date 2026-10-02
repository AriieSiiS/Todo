"""Empaqueta Todo con una conexión ya registrada, sin incluir datos ni claves."""

import argparse
import json
import re
import zipfile
from pathlib import Path


def package_plugin(connection_id: str, output: Path) -> Path:
    # El prefijo plugin_ pertenece al enlace de ChatGPT, no al identificador MCP.
    app_id = connection_id.removeprefix("plugin_")
    if not re.fullmatch(r"asdk_app_[a-f0-9]{32}", app_id):
        raise ValueError("Se necesita el identificador real asdk_app de la conexión registrada en ChatGPT.")
    manifest = {
        "$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",
        "name": "todo-personal",
        "version": "0.2.0",
        "description": "Consulta y organiza las tareas locales de Todo mediante una conexión privada.",
        "extensions": {"com.openai": {
            "apps": "./.app.json",
            "interface": {
                "displayName": "Todo", "shortDescription": "Tus tareas locales, también en ChatGPT.",
                "longDescription": "Consulta Hoy y crea, edita, mueve o completa tareas con Todo abierto en tu PC.",
                "developerName": "Todo personal", "category": "Productivity",
                "capabilities": ["Read", "Write"],
                "defaultPrompt": ["Muéstrame mis tareas de hoy en Todo.", "Ayúdame a organizar mis tareas pendientes."],
            },
        }},
    }
    output.mkdir(parents=True, exist_ok=True)
    archive = output / "todo-personal.zip"
    # Lista cerrada de archivos: nunca se recorre el repositorio ni Documents/Todo.
    files = {
        "plugin.json": json.dumps(manifest, ensure_ascii=False, indent=2),
        ".app.json": json.dumps({"apps": {"todo": {"id": app_id}}}, ensure_ascii=False, indent=2),
        "README.md": (
            "# Todo personal\n\nPlugin privado para una conexión MCP ya registrada.\n\n"
            "La app Todo y el túnel deben estar encendidos para modificar tareas. "
            "El paquete contiene solo metadatos y la referencia a la conexión. "
            "No incluye tareas, credenciales ni una copia de la aplicación.\n"
        ),
    }
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
        for name, content in files.items():
            bundle.writestr(name, content.encode("utf-8"))
    return archive


def main():
    parser = argparse.ArgumentParser(description="Empaquetar el plugin privado de Todo con su conexión registrada.")
    parser.add_argument("--connection-id", required=True, help="Identificador asdk_app o plugin_asdk_app de la conexión real.")
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / "output" / "chatgpt")
    options = parser.parse_args()
    print(package_plugin(options.connection_id, options.output))


if __name__ == "__main__":
    main()
