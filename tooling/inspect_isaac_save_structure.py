"""Inspecciona solo la estructura de un guardado de Isaac, sin modificarlo."""

from __future__ import annotations

import json
import struct
import sys
from pathlib import Path

ENTRY_BYTES = (1, 4, 4, 1, 1, 1, 1, 4, 4, 1, 583)


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Uso: inspect_isaac_save_structure.py <guardado.dat>")
    path = Path(sys.argv[1]).resolve()
    data = path.read_bytes()
    cursor = 0x14
    sections: list[dict[str, int]] = []
    for index, default_width in enumerate(ENTRY_BYTES):
        section_id, declared_size, count = struct.unpack_from("<III", data, cursor)
        cursor += 12
        width = default_width
        if index == len(ENTRY_BYTES) - 1 and count:
            remaining = len(data) - 4 - cursor
            width, remainder = divmod(remaining, count)
        else:
            remainder = 0
        sections.append(
            {
                "id": section_id,
                "declaredSize": declared_size,
                "count": count,
                "entryBytes": width,
                "remainder": remainder,
                "offset": cursor,
            }
        )
        cursor += count * width
    print(
        json.dumps(
            {
                "path": str(path),
                "size": len(data),
                "header": data[:16].decode("ascii", errors="replace"),
                "sections": sections,
                "computedEnd": cursor,
                "expectedEnd": len(data) - 4,
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
