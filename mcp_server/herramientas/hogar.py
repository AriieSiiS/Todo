"""Inventario del hogar."""

import contextlib
import copy
import datetime as dt
import hashlib
import io
import json
import os
import random
import re
import shutil
import struct
import sys
import unicodedata
import zlib
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

try:
    from PIL import Image, ImageOps
except ImportError:  # La importación PNG básica sigue disponible sin Pillow.
    Image = None
    ImageOps = None


import server


def list_household_items_impl(arguments: dict[str, Any]) -> list[dict[str, Any]]:
    items = server.load_state().setdefault("householdItems", [])
    if bool(arguments.get("include_archived", False)):
        return items
    return [item for item in items if not item.get("archived", False)]


def _household_values(arguments: dict[str, Any]) -> dict[str, Any]:
    mapping = {
        "name": "name",
        "category": "category",
        "brand": "brand",
        "model": "model",
        "serial_number": "serialNumber",
        "location": "location",
        "notes": "notes",
        "manual_source_url": "manualSourceUrl",
        "retailer": "retailer",
        "purchase_date": "purchaseDate",
        "warranty_until": "warrantyUntil",
        "price": "price",
        "tags": "tags",
        "archived": "archived",
    }
    values: dict[str, Any] = {}
    for source, destination in mapping.items():
        if source not in arguments:
            continue
        value = arguments[source]
        if source == "tags":
            value = list(dict.fromkeys(
                str(tag).strip() for tag in value if str(tag).strip()
            ))
        elif source in {"purchase_date", "warranty_until"}:
            value = server.parse_datetime(str(value)).isoformat() if value else None
        elif source not in {"price", "archived"}:
            value = str(value).strip()
        values[destination] = value
    return values


def create_household_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    instant = server.now_iso()
    item = {
        "id": server.make_id("household-item"),
        "name": str(arguments["name"]).strip() or "Artículo sin nombre",
        "category": str(arguments["category"]).strip() or "Sin categoría",
        "brand": "",
        "model": "",
        "serialNumber": "",
        "location": "",
        "notes": "",
        "imagePath": "",
        "thumbnailPath": "",
        "imageSha256": "",
        "manualPath": "",
        "manualSourceUrl": "",
        "invoicePath": "",
        "retailer": "",
        "purchaseDate": None,
        "warrantyUntil": None,
        "price": None,
        "tags": [],
        "archived": False,
        "createdAt": instant,
        "updatedAt": instant,
    }
    item.update(_household_values(arguments))
    state.setdefault("householdItems", []).append(item)
    server.save_state(state)
    return item


def update_household_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    index, item = server.find_by_id(
        state.setdefault("householdItems", []),
        arguments["item_id"],
        "artículo del hogar",
    )
    item.update(_household_values(arguments))
    item["updatedAt"] = server.now_iso()
    state["householdItems"][index] = item
    server.save_state(state)
    return item


def _write_household_asset(directory: Path, file_name: str, data: bytes) -> Path:
    directory.mkdir(parents=True, exist_ok=True)
    destination = directory / file_name
    if destination.exists():
        return destination
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    try:
        temporary.write_bytes(data)
        temporary.replace(destination)
    except Exception:
        temporary.unlink(missing_ok=True)
        raise
    return destination


def _delete_household_asset(relative_path: str) -> None:
    if not relative_path:
        return
    root = server.household_directory().resolve()
    candidate = (root / relative_path).resolve()
    if root not in candidate.parents:
        return
    candidate.unlink(missing_ok=True)


def set_household_item_image_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    source = Path(str(arguments["source_file"])).expanduser().resolve()
    if not source.is_file() or source.suffix.lower() != ".png":
        raise ValueError("La imagen de Hogar debe ser un archivo PNG local.")
    data = source.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n") or len(data) < 33:
        raise ValueError("La imagen de Hogar no es un PNG válido.")
    width, height = struct.unpack(">II", data[16:24])
    if width < 400 or height < 400:
        raise ValueError("La imagen debe medir al menos 400 × 400 píxeles.")
    state = server.load_state()
    index, item = server.find_by_id(
        state.setdefault("householdItems", []),
        arguments["item_id"],
        "artículo del hogar",
    )
    digest = hashlib.sha256(data).hexdigest()
    safe_id = re.sub(r"[^a-zA-Z0-9_-]", "-", str(item["id"]))
    file_name = f"{safe_id}-{digest[:12]}.png"
    root = server.household_directory()
    _write_household_asset(root / "images", file_name, data)
    _write_household_asset(root / "thumbnails", file_name, data)
    previous = [str(item.get("imagePath") or ""), str(item.get("thumbnailPath") or "")]
    item["imagePath"] = f"images/{file_name}"
    item["thumbnailPath"] = f"thumbnails/{file_name}"
    item["imageSha256"] = digest
    item["updatedAt"] = server.now_iso()
    state["householdItems"][index] = item
    try:
        server.save_state(state)
    except Exception:
        _delete_household_asset(item["imagePath"])
        _delete_household_asset(item["thumbnailPath"])
        raise
    for old_path in previous:
        if old_path not in {item["imagePath"], item["thumbnailPath"]}:
            _delete_household_asset(old_path)
    return item


def set_household_item_document_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    kind = str(arguments["kind"]).strip().lower()
    if kind not in {"manual", "invoice"}:
        raise ValueError("kind debe ser manual o invoice.")
    source = Path(str(arguments["source_file"])).expanduser().resolve()
    if not source.is_file() or source.suffix.lower() != ".pdf":
        raise ValueError("El documento debe ser un archivo PDF local.")
    data = source.read_bytes()
    if not data.startswith(b"%PDF-"):
        raise ValueError("El documento no es un PDF válido.")
    state = server.load_state()
    index, item = server.find_by_id(
        state.setdefault("householdItems", []),
        arguments["item_id"],
        "artículo del hogar",
    )
    digest = hashlib.sha256(data).hexdigest()
    safe_id = re.sub(r"[^a-zA-Z0-9_-]", "-", str(item["id"]))
    file_name = f"{safe_id}-{digest[:12]}.pdf"
    directory_name = "manuals" if kind == "manual" else "invoices"
    relative_path = f"{directory_name}/{file_name}"
    _write_household_asset(server.household_directory() / directory_name, file_name, data)
    field = "manualPath" if kind == "manual" else "invoicePath"
    previous = str(item.get(field) or "")
    item[field] = relative_path
    if kind == "manual" and arguments.get("source_url"):
        item["manualSourceUrl"] = str(arguments["source_url"]).strip()
    item["updatedAt"] = server.now_iso()
    state["householdItems"][index] = item
    try:
        server.save_state(state)
    except Exception:
        _delete_household_asset(relative_path)
        raise
    if previous != relative_path:
        _delete_household_asset(previous)
    return item


def delete_household_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    server.require_confirm(arguments, "delete_household_item")
    state = server.load_state()
    index, item = server.find_by_id(
        state.setdefault("householdItems", []),
        arguments["item_id"],
        "artículo del hogar",
    )
    state["householdItems"].pop(index)
    server.save_state(state)
    for field in ("imagePath", "thumbnailPath", "manualPath", "invoicePath"):
        _delete_household_asset(str(item.get(field) or ""))
    return {"deleted": True, "item_id": arguments["item_id"]}


__all__ = [
    "list_household_items_impl",
    "_household_values",
    "create_household_item_impl",
    "update_household_item_impl",
    "_write_household_asset",
    "_delete_household_asset",
    "set_household_item_image_impl",
    "set_household_item_document_impl",
    "delete_household_item_impl",
]
