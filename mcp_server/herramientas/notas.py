"""Notas."""

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


def list_notes_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    notes = state.get("notes", [])
    if "status" in arguments:
        status = server.ensure_value(arguments["status"], server.VALID_NOTE_STATUSES, "status")
        notes = [note for note in notes if note.get("status") == status]
    return {"notes": notes, "count": len(notes)}


def create_note_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    note = {
        "id": server.make_id("note"),
        "content": arguments["content"].strip(),
        "createdAt": server.now_iso(),
        "status": "inbox",
        "scheduledFor": server.normalize_datetime(arguments.get("scheduled_for")),
    }
    state.setdefault("notes", []).insert(0, note)
    server.save_state(state)
    return {"created": note}


def update_note_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    index, note = server.find_by_id(state["notes"], arguments["note_id"], "la nota")
    updated = copy.deepcopy(note)
    if "content" in arguments:
        updated["content"] = arguments["content"].strip()
    if arguments.get("clear_scheduled_for"):
        updated["scheduledFor"] = None
    elif "scheduled_for" in arguments:
        updated["scheduledFor"] = server.normalize_datetime(arguments.get("scheduled_for"))
    if "status" in arguments:
        updated["status"] = server.ensure_value(arguments["status"], server.VALID_NOTE_STATUSES, "status")
    state["notes"][index] = updated
    server.save_state(state)
    return {"updated": updated}


def archive_note_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    return update_note_impl({"note_id": arguments["note_id"], "status": "archived"})


def mark_note_converted(state: dict[str, Any], note_id: str) -> None:
    index, note = server.find_by_id(state["notes"], note_id, "la nota")
    updated = copy.deepcopy(note)
    updated["status"] = "converted"
    state["notes"][index] = updated


def convert_note_to_task_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    _index, note = server.find_by_id(state["notes"], arguments["note_id"], "la nota")
    create_args = {
        "title": arguments.get("title") or note.get("content", "Nota"),
        "description": note.get("content"),
        "scheduled_at": arguments.get("scheduled_at") or note.get("scheduledFor"),
        "category_ids": arguments.get("category_ids", []),
        "project_ids": arguments.get("project_ids", []),
        "origin": "note",
    }
    task = server.create_task_impl(create_args)["created"]
    state = server.load_state()
    mark_note_converted(state, arguments["note_id"])
    server.save_state(state)
    return {"created": task}


def convert_note_to_project_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    _index, note = server.find_by_id(state["notes"], arguments["note_id"], "la nota")
    project = server.create_project_impl(
        {
            "name": arguments.get("name") or note.get("content", "Proyecto"),
            "description": note.get("content", ""),
            "category_ids": arguments.get("category_ids", []),
        }
    )["created"]
    state = server.load_state()
    mark_note_converted(state, arguments["note_id"])
    server.save_state(state)
    return {"created": project}


__all__ = [
    "list_notes_impl",
    "create_note_impl",
    "update_note_impl",
    "archive_note_impl",
    "mark_note_converted",
    "convert_note_to_task_impl",
    "convert_note_to_project_impl",
]
