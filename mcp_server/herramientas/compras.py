"""Lista de compras."""

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


def list_shopping_items_impl(arguments: dict[str, Any]) -> list[dict[str, Any]]:
    items = server.load_state().get("shoppingItems", [])
    return [item for item in items
            if (arguments.get("include_archived") or not item.get("archived", False))
            and (not arguments.get("category") or item.get("category") == arguments["category"])
            and (not arguments.get("subcategory") or item.get("subcategory") == arguments["subcategory"])]


def _shopping_values(arguments: dict[str, Any]) -> dict[str, Any]:
    mapping = {"name": "name", "category": "category", "subcategory": "subcategory",
               "source_url": "sourceUrl", "retailer": "retailer", "notes": "notes",
               "research_notes": "researchNotes", "reference_price": "referencePrice",
               "target_price": "targetPrice", "priority": "priority", "status": "status",
               "archived": "archived"}
    values = {}
    for source, destination in mapping.items():
        if source not in arguments:
            continue
        value = arguments[source]
        if source in {"reference_price", "target_price"}:
            value = float(value)
            if not (0 <= value < float("inf")):
                raise ValueError("El precio debe ser un número finito y positivo o cero.")
        elif source in {"priority", "archived"}:
            if not isinstance(value, bool):
                raise ValueError("La prioridad y el archivado deben ser booleanos.")
        else:
            value = str(value).strip()
            if source in {"name", "category"} and not value:
                raise ValueError("El nombre y la categoría son obligatorios.")
            if source == "source_url" and value:
                parsed = urllib.parse.urlparse(value)
                if parsed.scheme not in {"http", "https"} or not parsed.netloc:
                    raise ValueError("El enlace debe ser una URL http o https válida.")
            if source == "status" and value not in {"saved", "comparing", "purchased"}:
                raise ValueError("Estado de compra no válido.")
        values[destination] = value
    for source, destination in (("clear_reference_price", "referencePrice"), ("clear_target_price", "targetPrice")):
        if arguments.get(source):
            values[destination] = None
    if "offers" in arguments:
        offers = arguments["offers"]
        if not isinstance(offers, list) or len(offers) > 25:
            raise ValueError("Una ficha admite como máximo 25 opciones.")
        normalized = []
        for offer in offers:
            if not isinstance(offer, dict) or not isinstance(offer.get("name"), str) or not offer["name"].strip():
                raise ValueError("Cada opción necesita un nombre.")
            url = offer.get("source_url")
            if not isinstance(url, str):
                raise ValueError("Cada opción necesita un enlace.")
            parsed = urllib.parse.urlparse(url.strip())
            if parsed.scheme not in {"http", "https"} or not parsed.netloc:
                raise ValueError("El enlace de la opción debe ser http o https.")
            normalized.append({"name": offer["name"].strip(), "sourceUrl": url.strip()})
        values["offers"] = normalized
        if normalized:
            values["sourceUrl"] = normalized[0]["sourceUrl"]
    return values


def create_shopping_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    values = _shopping_values(arguments)
    if not values.get("name") or not values.get("category"):
        raise ValueError("El nombre y la categoría son obligatorios.")
    state = server.load_state()
    instant = server.now_iso()
    item = {"id": server.make_id("shopping-item"), "name": "", "category": "",
            "subcategory": "", "sourceUrl": "", "retailer": "", "notes": "",
            "researchNotes": "", "imagePath": "", "thumbnailPath": "", "imageSha256": "",
            "referencePrice": None, "targetPrice": None, "priority": False,
            "status": "saved", "archived": False, "createdAt": instant, "updatedAt": instant}
    item.update(values)
    peers = [entry for entry in state.get("shoppingItems", [])
             if entry.get("category") == item["category"]
             and entry.get("subcategory", "").strip() == item["subcategory"]]
    item["grouped"] = not peers or any(entry.get("grouped", True) for entry in peers)
    state.setdefault("shoppingItems", []).append(item)
    server.save_state(state)
    return item


def update_shopping_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    values = _shopping_values(arguments)
    state = server.load_state()
    index, item = server.find_by_id(state.setdefault("shoppingItems", []), arguments["item_id"], "compra deseada")
    item.update(values)
    item["updatedAt"] = server.now_iso()
    state["shoppingItems"][index] = item
    server.save_state(state)
    return item


def _delete_shopping_asset(relative_path: str) -> None:
    if not relative_path:
        return
    root = server.shopping_directory().resolve()
    candidate = (root / relative_path).resolve()
    if root in candidate.parents:
        candidate.unlink(missing_ok=True)


def set_shopping_item_image_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    source = Path(str(arguments["source_file"])).resolve()
    if not source.is_file() or source.suffix.lower() != ".png":
        raise ValueError("La imagen de Compras debe ser un PNG local.")
    data = source.read_bytes()
    if len(data) < 33 or not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("La imagen no es un PNG válido.")
    width, height = struct.unpack(">II", data[16:24])
    if width < 400 or height < 400:
        raise ValueError("La imagen debe medir al menos 400 × 400 píxeles.")
    state = server.load_state()
    index, item = server.find_by_id(state.setdefault("shoppingItems", []), arguments["item_id"], "compra deseada")
    digest = hashlib.sha256(data).hexdigest()
    safe_id = re.sub(r"[^a-zA-Z0-9_-]", "-", str(item["id"]))
    file_name = f"{safe_id}-{digest[:12]}.png"
    root = server.shopping_directory()
    server._write_household_asset(root / "images", file_name, data)
    server._write_household_asset(root / "thumbnails", file_name, data)
    previous = {str(item.get(field) or "") for field in ("imagePath", "thumbnailPath")}
    item.update(imagePath=f"images/{file_name}", thumbnailPath=f"thumbnails/{file_name}",
                imageSha256=digest, updatedAt=server.now_iso())
    state["shoppingItems"][index] = item
    server.save_state(state)
    for path in previous - {item["imagePath"], item["thumbnailPath"]}:
        _delete_shopping_asset(path)
    return item


def delete_shopping_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    server.require_confirm(arguments, "delete_shopping_item")
    state = server.load_state()
    index, item = server.find_by_id(state.setdefault("shoppingItems", []), arguments["item_id"], "compra deseada")
    state["shoppingItems"].pop(index)
    server.save_state(state)
    for field in ("imagePath", "thumbnailPath"):
        _delete_shopping_asset(str(item.get(field) or ""))
    return {"deleted": True, "item_id": item["id"]}


def _recipe_shopping_labels(ingredient: dict[str, Any]) -> list[str]:
    text = str(ingredient.get("text", "")).strip()
    if not text:
        return []
    if ingredient.get("kind") == "condiment" or server._recipe_is_condiment(text):
        detected = server._detected_recipe_condiments(text)
        if detected:
            return detected
    return [text]


__all__ = [
    "list_shopping_items_impl",
    "_shopping_values",
    "create_shopping_item_impl",
    "update_shopping_item_impl",
    "_delete_shopping_asset",
    "set_shopping_item_image_impl",
    "delete_shopping_item_impl",
    "_recipe_shopping_labels",
]
