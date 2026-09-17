"""Sustitución local y atómica de la imagen de una prenda de Todo."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Sustituye la imagen de una prenda sin modificar su ficha.",
    )
    parser.add_argument("--item-id", required=True)
    parser.add_argument("--source-file", required=True)
    parser.add_argument("--request-id", required=True)
    return parser


def main() -> int:
    arguments = build_parser().parse_args()
    repo_root = Path(__file__).resolve().parents[3]
    mcp_directory = repo_root / "mcp_server"
    sys.path.insert(0, str(mcp_directory))

    import server  # type: ignore[import-not-found]  # Importación local del repo.

    result = server.set_wardrobe_item_image_impl(
        {
            "item_id": arguments.item_id,
            "source_file": arguments.source_file,
            "request_id": arguments.request_id,
        }
    )
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
