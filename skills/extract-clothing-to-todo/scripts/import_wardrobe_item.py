"""Entrada local directa para importar una prenda cuando el MCP no está cargado."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Inserta una prenda directamente en el armario de Todo.",
    )
    parser.add_argument("--source-file", required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--category", required=True)
    parser.add_argument("--request-id", required=True)
    parser.add_argument("--material", default="")
    parser.add_argument("--color", action="append", default=[])
    parser.add_argument("--season", action="append", default=[])
    parser.add_argument("--occasion", action="append", default=[])
    parser.add_argument("--tag", action="append", default=[])
    parser.add_argument("--price", type=float)
    parser.add_argument("--favorite", action="store_true")
    parser.add_argument(
        "--laundry-status",
        choices=("available", "toWash", "washing", "drying"),
        default="available",
    )
    return parser


def main() -> int:
    arguments = build_parser().parse_args()
    repo_root = Path(__file__).resolve().parents[3]
    mcp_directory = repo_root / "mcp_server"
    sys.path.insert(0, str(mcp_directory))

    import server  # type: ignore[import-not-found]  # Importación local del repo.

    result = server.import_wardrobe_item_impl(
        {
            "source_file": arguments.source_file,
            "name": arguments.name,
            "category": arguments.category,
            "request_id": arguments.request_id,
            "material": arguments.material,
            "colors": arguments.color,
            "seasons": arguments.season,
            "occasions": arguments.occasion,
            "tags": arguments.tag,
            "price": arguments.price,
            "favorite": arguments.favorite,
            "laundry_status": arguments.laundry_status,
        }
    )
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
