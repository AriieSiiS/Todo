"""Plantas y rutinas de cuidados."""

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


PLANT_CAT_SAFETY = {"nonToxic", "caution", "toxic", "unknown"}


PLANT_CARE_TYPES = {
    "watering", "fertilizing", "inspection", "repotting",
    "pruning", "cleaning", "misting", "custom",
}


def get_plant_contract_impl() -> dict[str, Any]:
    return {
        "version": 1,
        "category": "Plantas",
        "cat_safety_values": sorted(PLANT_CAT_SAFETY),
        "care_types": sorted(PLANT_CARE_TYPES),
        "recurrence_types": sorted(server.VALID_RECURRENCE_TYPES - {"none"}),
        "routine_shape": {
            "id": "identificador estable opcional",
            "type": "watering | fertilizing | inspection | repotting | pruning | cleaning | misting | custom",
            "title": "título visible de la tarea",
            "instructions": "instrucciones accionables",
            "firstDueDate": "YYYY-MM-DD",
            "recurrence": {
                "type": "daily | everyXDays | weekly | monthly | yearly",
                "interval": 1,
                "weekdays": [],
                "activeMonths": [],
            },
            "enabled": True,
        },
        "image": {"format": "PNG", "minimum": "400 × 400 píxeles"},
        "rules": [
            "Las tareas se crean sin hora ni avisos.",
            "La toxicidad genérica nunca se infiere: usa unknown si no hay una fuente veterinaria fiable.",
            "Cada fuente usa title y url.",
        ],
    }


def list_plants_impl(arguments: dict[str, Any]) -> list[dict[str, Any]]:
    plants = server.load_state().setdefault("plants", [])
    if bool(arguments.get("include_archived", False)):
        return plants
    return [plant for plant in plants if not plant.get("archived", False)]


def _normalize_plant_sources(value: Any) -> list[dict[str, str]]:
    if not isinstance(value, list):
        return []
    result: list[dict[str, str]] = []
    for source in value:
        if not isinstance(source, dict):
            continue
        title = str(source.get("title") or "").strip()
        url = str(source.get("url") or "").strip()
        if url:
            result.append({"title": title or url, "url": url})
    return result


def _normalize_plant_routine(value: Any) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ValueError("Cada rutina debe ser un objeto.")
    care_type = str(value.get("type") or "custom")
    if care_type not in PLANT_CARE_TYPES:
        raise ValueError(f"Tipo de cuidado no compatible: {care_type}.")
    recurrence = value.get("recurrence") or {}
    if not isinstance(recurrence, dict):
        raise ValueError("recurrence debe ser un objeto.")
    recurrence_type = server.ensure_value(
        str(recurrence.get("type") or "everyXDays"),
        server.VALID_RECURRENCE_TYPES - {"none"},
        "recurrence.type",
    )
    months: list[int] = []
    for month in recurrence.get("activeMonths", []):
        try:
            parsed_month = int(month)
        except (TypeError, ValueError):
            continue
        if 1 <= parsed_month <= 12 and parsed_month not in months:
            months.append(parsed_month)
    months.sort()
    due_value = str(value.get("firstDueDate") or dt.date.today().isoformat())
    return {
        "id": str(value.get("id") or server.make_id("plant-care")),
        "type": care_type,
        "title": str(value.get("title") or "Cuidado de la planta").strip(),
        "instructions": str(value.get("instructions") or "").strip(),
        "firstDueDate": server.date_iso(due_value, "firstDueDate"),
        "recurrence": {
            "type": recurrence_type,
            "interval": max(1, int(recurrence.get("interval", 1))),
            "weekdays": [int(day) for day in recurrence.get("weekdays", [])],
            "activeMonths": months,
        },
        "enabled": bool(value.get("enabled", True)),
    }


def _plant_values(arguments: dict[str, Any]) -> dict[str, Any]:
    mapping = {
        "name": "name", "common_name": "commonName",
        "scientific_name": "scientificName", "cultivar": "cultivar",
        "location": "location", "acquired_at": "acquiredAt",
        "description": "description", "light": "light",
        "watering": "watering", "humidity": "humidity",
        "temperature": "temperature", "substrate": "substrate",
        "fertilizing": "fertilizing", "pruning": "pruning",
        "propagation": "propagation", "repotting": "repotting",
        "common_problems": "commonProblems", "cat_safety": "catSafety",
        "cat_safety_notes": "catSafetyNotes", "sources": "sources",
        "routines": "routines", "tags": "tags", "notes": "notes",
        "archived": "archived",
    }
    values: dict[str, Any] = {}
    for source, destination in mapping.items():
        if source not in arguments:
            continue
        value = arguments[source]
        if source == "acquired_at":
            value = server.date_iso(str(value), "acquired_at") if value else None
        elif source == "cat_safety":
            value = server.ensure_value(str(value), PLANT_CAT_SAFETY, "cat_safety")
        elif source == "sources":
            value = _normalize_plant_sources(value)
        elif source == "routines":
            value = [_normalize_plant_routine(routine) for routine in value]
        elif source == "tags":
            value = list(dict.fromkeys(
                str(tag).strip() for tag in value if str(tag).strip()
            ))
        elif source != "archived":
            value = str(value or "").strip()
        values[destination] = value
    return values


def _ensure_plants_category(state: dict[str, Any]) -> dict[str, Any]:
    for category in state.setdefault("categories", []):
        if str(category.get("name") or "").strip().casefold() == "plantas":
            return category
    category = {
        "id": "category-plants",
        "name": "Plantas",
        "description": "Cuidados y mantenimiento de las plantas.",
        "colorValue": 0xFF4F7A4A,
        "iconCodePoint": 0xE545,
        "active": True,
    }
    state["categories"].append(category)
    return category


def _sync_plant_tasks(state: dict[str, Any], plant: dict[str, Any]) -> None:
    category = _ensure_plants_category(state)
    tasks = state.setdefault("tasks", [])
    routine_ids = {routine["id"] for routine in plant.get("routines", [])}
    for routine in plant.get("routines", []):
        existing = next((task for task in tasks
            if task.get("sourcePlantId") == plant["id"]
            and task.get("sourcePlantCareRoutineId") == routine["id"]), None)
        title = routine["title"]
        if str(plant["name"]).casefold() not in title.casefold():
            title = f"{title} · {plant['name']}"
        status = "active" if routine.get("enabled", True) and not plant.get("archived", False) else "archived"
        if existing is None:
            existing = {
                "id": server.make_id("task"), "title": title,
                "description": routine.get("instructions") or None,
                "categoryIds": [category["id"]], "projectIds": [],
                "scheduledAt": routine["firstDueDate"], "priority": "medium",
                "status": status, "recurrence": copy.deepcopy(routine["recurrence"]),
                "subtaskIds": [], "checklist": [], "materials": [],
                "origin": "plant", "manualOrder": server.next_manual_order(tasks),
                "parentTaskId": None, "collapsed": False, "calendarLink": None,
                "reminderRules": [], "reminderRule": None, "completedAt": None,
                "recurrenceCompletions": {}, "sourcePlantId": plant["id"],
                "sourcePlantCareRoutineId": routine["id"],
            }
            tasks.append(existing)
            continue
        current = server.parse_datetime(existing.get("scheduledAt"))
        due = server.parse_datetime(routine["firstDueDate"]) or dt.datetime.now()
        if current is not None:
            due = due.replace(hour=current.hour, minute=current.minute)
        existing.update({
            "title": title,
            "description": routine.get("instructions") or None,
            "categoryIds": [category["id"]], "scheduledAt": due.isoformat(),
            "status": status, "recurrence": copy.deepcopy(routine["recurrence"]),
            "origin": "plant", "sourcePlantId": plant["id"],
            "sourcePlantCareRoutineId": routine["id"],
        })
    for task in tasks:
        if (task.get("sourcePlantId") == plant["id"]
                and task.get("sourcePlantCareRoutineId") not in routine_ids):
            task["status"] = "archived"


def create_plant_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    request_id = str(arguments["request_id"]).strip()
    for plant in state.setdefault("plants", []):
        if plant.get("requestId") == request_id:
            return {"plant": plant, "savedLocally": True, "syncPending": True}
    instant = server.now_iso()
    plant = {
        "id": server.make_id("plant"), "requestId": request_id,
        "name": str(arguments["name"]).strip() or "Planta sin nombre",
        "commonName": "", "scientificName": str(arguments["scientific_name"]).strip(),
        "cultivar": "", "location": "", "acquiredAt": None,
        "description": "", "light": "", "watering": "", "humidity": "",
        "temperature": "", "substrate": "", "fertilizing": "",
        "pruning": "", "propagation": "", "repotting": "",
        "commonProblems": "", "catSafety": "unknown", "catSafetyNotes": "",
        "sources": [], "routines": [], "tags": [], "notes": "",
        "imagePath": "", "thumbnailPath": "", "imageSha256": "",
        "archived": False, "createdAt": instant, "updatedAt": instant,
    }
    plant.update(_plant_values(arguments))
    state["plants"].append(plant)
    _sync_plant_tasks(state, plant)
    server.save_state(state)
    return {"plant": plant, "savedLocally": True, "syncPending": True}


def update_plant_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    index, plant = server.find_by_id(
        state.setdefault("plants", []), arguments["plant_id"], "planta"
    )
    plant.update(_plant_values(arguments))
    plant["updatedAt"] = server.now_iso()
    state["plants"][index] = plant
    _sync_plant_tasks(state, plant)
    server.save_state(state)
    return {"plant": plant, "savedLocally": True, "syncPending": True}


def _delete_plant_asset(relative_path: str) -> None:
    if not relative_path:
        return
    root = server.plants_directory().resolve()
    candidate = (root / relative_path).resolve()
    if root in candidate.parents:
        candidate.unlink(missing_ok=True)


def set_plant_image_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    source = Path(str(arguments["source_file"])).expanduser().resolve()
    if not source.is_file() or source.suffix.lower() != ".png":
        raise ValueError("La imagen de la planta debe ser un archivo PNG local.")
    data = source.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n") or len(data) < 33:
        raise ValueError("La imagen de la planta no es un PNG válido.")
    width, height = struct.unpack(">II", data[16:24])
    if width < 400 or height < 400:
        raise ValueError("La imagen debe medir al menos 400 × 400 píxeles.")
    state = server.load_state()
    index, plant = server.find_by_id(
        state.setdefault("plants", []), arguments["plant_id"], "planta"
    )
    request_id = str(arguments["request_id"]).strip()
    if plant.get("imageRequestId") == request_id:
        return {"plant": plant, "savedLocally": True, "syncPending": True}
    digest = hashlib.sha256(data).hexdigest()
    safe_id = re.sub(r"[^a-zA-Z0-9_-]", "-", str(plant["id"]))
    file_name = f"{safe_id}-{digest[:12]}.png"
    root = server.plants_directory()
    server._write_household_asset(root / "images", file_name, data)
    server._write_household_asset(root / "thumbnails", file_name, data)
    previous = [str(plant.get("imagePath") or ""), str(plant.get("thumbnailPath") or "")]
    plant.update({
        "imagePath": f"images/{file_name}",
        "thumbnailPath": f"thumbnails/{file_name}",
        "imageSha256": digest, "imageRequestId": request_id,
        "updatedAt": server.now_iso(),
    })
    state["plants"][index] = plant
    try:
        server.save_state(state)
    except Exception:
        _delete_plant_asset(plant["imagePath"])
        _delete_plant_asset(plant["thumbnailPath"])
        raise
    for old_path in previous:
        if old_path not in {plant["imagePath"], plant["thumbnailPath"]}:
            _delete_plant_asset(old_path)
    return {"plant": plant, "savedLocally": True, "syncPending": True}


def delete_plant_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    server.require_confirm(arguments, "delete_plant")
    state = server.load_state()
    index, plant = server.find_by_id(
        state.setdefault("plants", []), arguments["plant_id"], "planta"
    )
    state["plants"].pop(index)
    state["tasks"] = [
        task for task in state.setdefault("tasks", [])
        if task.get("sourcePlantId") != plant["id"]
    ]
    server.save_state(state)
    _delete_plant_asset(str(plant.get("imagePath") or ""))
    _delete_plant_asset(str(plant.get("thumbnailPath") or ""))
    return {
        "deleted": True,
        "plant_id": arguments["plant_id"],
        "savedLocally": True,
        "syncPending": server.remote_enabled(),
    }


__all__ = [
    "PLANT_CAT_SAFETY",
    "PLANT_CARE_TYPES",
    "get_plant_contract_impl",
    "list_plants_impl",
    "_normalize_plant_sources",
    "_normalize_plant_routine",
    "_plant_values",
    "_ensure_plants_category",
    "_sync_plant_tasks",
    "create_plant_impl",
    "update_plant_impl",
    "_delete_plant_asset",
    "set_plant_image_impl",
    "delete_plant_impl",
]
