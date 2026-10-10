"""Añade las secuelas de ¡Goool! como pendientes por el MCP local."""

import json
import os
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
server = subprocess.Popen(
    [sys.executable, str(root / "mcp_server" / "server.py")],
    cwd=root,
    env={**os.environ, "TODO_MCP_DISABLE_REMOTE": "1"},
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
)


def send(message):
    data = json.dumps(message, ensure_ascii=False).encode("utf-8")
    server.stdin.write(f"Content-Length: {len(data)}\r\n\r\n".encode("ascii") + data)
    server.stdin.flush()


def receive():
    headers = {}
    while True:
        line = server.stdout.readline()
        if line in (b"\r\n", b"\n", b""):
            break
        key, value = line.decode("utf-8").split(":", 1)
        headers[key.lower()] = value.strip()
    return json.loads(server.stdout.read(int(headers["content-length"])).decode("utf-8"))


def call(identifier, name, arguments):
    send({"jsonrpc": "2.0", "id": identifier, "method": "tools/call", "params": {"name": name, "arguments": arguments}})
    response = receive()
    if "error" in response:
        raise RuntimeError(response["error"]["message"])
    return json.loads(response["result"]["content"][0]["text"])


try:
    send({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-03-26", "capabilities": {}, "clientInfo": {"name": "codex", "version": "1"}}})
    receive()
    send({"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}})
    items = call(2, "list_library_items", {"type": "movieSeries"})["items"]
    originals = {
        "¡Goool! La película": {"collection_name": "¡Goool!", "collection_number": 1, "show_collection_number": True},
        "¡Goool 2! Viviendo el sueño": {"collection_name": "¡Goool!", "collection_number": 2, "show_collection_number": True},
        "¡Goool! 3: El juego final": {"collection_name": "¡Goool!", "collection_number": 3, "show_collection_number": True},
    }
    # Corrige el título y orden de la ficha de la primera parte si ya existe.
    first = next((item for item in items if item.get("title", "").casefold() in {"¡goool! la película", "goal!", "goal"}), None)
    if first:
        call(3, "update_library_item", {
            "item_id": first["id"],
            "title": "¡Goool! La película",
            "collection_name": "¡Goool!",
            "collection_number": 1,
            "show_collection_number": True,
        })

    sequels = [
        {
            "type": "movieSeries",
            "title": "¡Goool 2! Viviendo el sueño",
            "status": "pending",
            "media_type": "movie",
            "creator_or_director": "Jaume Collet-Serra",
            "release_year": 2007,
            "genre": "Drama deportivo, fútbol y comedia dramática",
            "format": "Película",
            "duration": "1 h 55 min",
            "country": "Reino Unido, España y Alemania",
            "collection_name": "¡Goool!",
            "collection_number": 2,
            "show_collection_number": True,
            "note": "Título original: Goal II: Living the Dream. Continuación de la historia de Santiago Muñez, que ficha por el Real Madrid.",
        },
        {
            "type": "movieSeries",
            "title": "¡Goool! 3: El juego final",
            "status": "pending",
            "media_type": "movie",
            "creator_or_director": "Andrew Morahan",
            "release_year": 2009,
            "genre": "Drama deportivo y fútbol",
            "format": "Película",
            "duration": "1 h 32 min",
            "country": "Reino Unido",
            "collection_name": "¡Goool!",
            "collection_number": 3,
            "show_collection_number": True,
            "note": "Título original: Goal III: Taking on the World. Tercera y última película de la trilogía; estrenada directamente en vídeo.",
        },
    ]
    result = call(4, "bulk_upsert_library_items", {"items": sequels})
    current = call(5, "list_library_items", {"type": "movieSeries"})["items"]
    for title in originals:
        item = next((entry for entry in current if entry.get("title") == title), None)
        if item is None:
            raise RuntimeError(f"No se verificó la entrada {title}.")
        if item.get("collectionName") != "¡Goool!" or not item.get("showCollectionNumber"):
            call(6, "update_library_item", {
                "item_id": item["id"],
                "collection_name": "¡Goool!",
                "collection_number": originals[title]["collection_number"],
                "show_collection_number": True,
            })
    verified = call(7, "list_library_items", {"type": "movieSeries", "status": "pending"})["items"]
    expected = ["¡Goool 2! Viviendo el sueño", "¡Goool! 3: El juego final"]
    saved = {title: next((item for item in verified if item.get("title") == title and item.get("collectionName") == "¡Goool!"), None) for title in expected}
    if any(item is None for item in saved.values()):
        raise RuntimeError("No se verificaron las dos secuelas en pendientes.")
    sys.stdout.buffer.write(json.dumps({"result": result, "sequels": saved}, ensure_ascii=False).encode("utf-8") + b"\n")
finally:
    server.stdin.close()
    server.wait(timeout=10)
