"""Arranca el cliente oficial con argumentos Windows y verifica su disponibilidad."""

import argparse
import json
import re
import subprocess
import sys
import time
from pathlib import Path


def health_flags(value):
    if isinstance(value, dict):
        if all(field in value for field in ("process_running", "healthy", "ready")):
            return all(value[field] is True for field in ("process_running", "healthy", "ready"))
        return any(health_flags(child) for child in value.values())
    if isinstance(value, list):
        return any(health_flags(child) for child in value)
    return False


def main():
    parser = argparse.ArgumentParser(description="Conectar y verificar el túnel privado de Todo.")
    parser.add_argument("--tunnel-id", required=True)
    parser.add_argument("--key-file", type=Path, required=True)
    options = parser.parse_args()
    if not re.fullmatch(r"tunnel_[A-Za-z0-9_-]+", options.tunnel_id):
        parser.error("El identificador del túnel no es válido.")
    root = Path(__file__).resolve().parent
    key = options.key_file.resolve(strict=True)
    if key.is_relative_to(root.parent):
        parser.error("La clave debe guardarse fuera del repositorio.")
    binary = root / ".tunnel-client" / "tunnel-client.exe"
    # Python construye la línea nativa de argumentos; las comillas del comando
    # MCP no pasan por la interpretación de PowerShell ni por otra shell.
    command = f'"{Path(sys.executable).as_posix()}" -u "{(root / "chatgpt_server.py").as_posix()}" --live'
    subprocess.run([str(binary), "runtimes", "connect", "--alias", "todo-local",
        "--profile", "todo-local", "--tunnel-id", options.tunnel_id,
        "--mcp-command", command, "--runtime-api-key", "file:" + key.as_posix()], check=True)
    deadline = time.monotonic() + 30
    while True:
        status = subprocess.run([str(binary), "runtimes", "status", "todo-local", "--json"],
            check=True, capture_output=True, text=True, encoding="utf-8")
        if health_flags(json.loads(status.stdout)):
            print(status.stdout.strip())
            return
        if time.monotonic() >= deadline:
            print(status.stdout.strip())
            raise RuntimeError("El proceso del túnel no está confirmado como activo, saludable y disponible.")
        time.sleep(2)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError, ValueError):
        print("No se ha confirmado la conexión del túnel. Revisa sus permisos y el estado del cliente oficial.", file=sys.stderr)
        sys.exit(1)
