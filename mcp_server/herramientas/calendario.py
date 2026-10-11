"""Calendario y eventos vinculados."""

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


def convert_note_to_calendar_event_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    _index, note = server.find_by_id(state["notes"], arguments["note_id"], "la nota")
    event = {
        "id": server.make_id("calendar-event"),
        "calendarId": arguments.get("calendar_id", "local"),
        "title": arguments.get("title") or note.get("content", "Evento"),
        "startAt": server.normalize_datetime(arguments["start_at"]),
        "endAt": server.normalize_datetime(arguments["end_at"]),
        "description": note.get("content"),
        "originTaskId": None,
    }
    state.setdefault("calendarEvents", []).append(event)
    server.mark_note_converted(state, arguments["note_id"])
    server.save_state(state)
    return {"created": event}


def list_calendar_events_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    events = state.get("calendarEvents", [])
    start = server.parse_datetime(arguments.get("from")) if arguments.get("from") else None
    end = server.parse_datetime(arguments.get("to")) if arguments.get("to") else None
    if start or end:
        filtered = []
        for event in events:
            event_start = server.parse_datetime(event.get("startAt"))
            if event_start is None:
                continue
            if start and event_start < start:
                continue
            if end and event_start > end:
                continue
            filtered.append(event)
        events = filtered
    return {"events": events, "count": len(events)}


def require_calendar_connected(state: dict[str, Any]) -> None:
    if not state.get("calendarSettings", {}).get("connected"):
        raise ValueError("El calendario no esta conectado.")


def refresh_calendar_events_impl() -> dict[str, Any]:
    state = server.load_state()
    require_calendar_connected(state)
    return {"refreshed": True, "events": state.get("calendarEvents", []), "count": len(state.get("calendarEvents", []))}


def import_calendar_events_as_tasks_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    created = []
    start = server.parse_datetime(arguments.get("from")) if arguments.get("from") else None
    end = server.parse_datetime(arguments.get("to")) if arguments.get("to") else None
    for event in state.get("calendarEvents", []):
        event_start = server.parse_datetime(event.get("startAt"))
        if event_start is None:
            continue
        if start and event_start < start:
            continue
        if end and event_start > end:
            continue
        if any(task.get("calendarLink", {}).get("eventId") == event.get("id") for task in state["tasks"] if task.get("calendarLink")):
            continue
        task = {
            "id": server.make_id("task"),
            "title": event.get("title", "Evento"),
            "description": event.get("description"),
            "categoryIds": [],
            "projectIds": [],
            "scheduledAt": event.get("startAt"),
            "priority": "medium",
            "status": "active",
            "recurrence": {"type": "none", "interval": 1, "weekdays": []},
            "subtaskIds": [],
            "checklist": [],
            "materials": [],
            "origin": "calendar",
            "manualOrder": server.next_manual_order(state["tasks"]),
            "parentTaskId": None,
            "collapsed": False,
            "calendarLink": {"provider": "google", "calendarId": event.get("calendarId", "local"), "eventId": event.get("id"), "syncStatus": "synced", "lastSyncedAt": server.now_iso()},
            "reminderRules": [],
            "reminderRule": None,
        }
        state["tasks"].append(task)
        created.append(task)
    server.save_state(state)
    return {"created": created, "count": len(created)}


def sync_task_to_calendar_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    require_calendar_connected(state)
    index, task = server.find_task(state, arguments["task_id"])
    updated = copy.deepcopy(task)
    link = updated.get("calendarLink") or {
        "provider": "google",
        "calendarId": state.get("calendarSettings", {}).get("selectedCalendarId", "primary"),
        "eventId": server.make_id("event"),
        "syncStatus": "pending",
        "lastSyncedAt": None,
    }
    link["syncStatus"] = "synced"
    link["lastSyncedAt"] = server.now_iso()
    updated["calendarLink"] = link
    state["tasks"][index] = updated
    server.save_state(state)
    return {"synced": updated}


def link_task_to_calendar_event_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    index, task = server.find_task(state, arguments["task_id"])
    updated = copy.deepcopy(task)
    updated["calendarLink"] = {
        "provider": "google",
        "calendarId": arguments["calendar_id"],
        "eventId": arguments["event_id"],
        "syncStatus": arguments.get("sync_status", "synced"),
        "lastSyncedAt": server.now_iso(),
    }
    state["tasks"][index] = updated
    server.save_state(state)
    return {"linked": updated}


def unlink_task_from_calendar_event_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    index, task = server.find_task(state, arguments["task_id"])
    updated = copy.deepcopy(task)
    updated["calendarLink"] = None
    state["tasks"][index] = updated
    server.save_state(state)
    return {"unlinked": updated}


def disconnect_calendar_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    server.require_confirm(arguments, "disconnect_calendar")
    state = server.load_state()
    state["calendarEvents"] = []
    state["calendarSettings"] = {**server.default_state()["calendarSettings"], "connected": False}
    for task in state.get("tasks", []):
        task["calendarLink"] = None
    server.save_state(state)
    return {"disconnected": True}


def update_calendar_settings_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    settings = dict(state.get("calendarSettings", server.default_state()["calendarSettings"]))
    mapping = {
        "web_client_id": "webClientId",
        "desktop_client_id": "desktopClientId",
        "desktop_client_secret": "desktopClientSecret",
        "selected_calendar_id": "selectedCalendarId",
        "selected_calendar_name": "selectedCalendarName",
        "connected_email": "connectedEmail",
        "connected": "connected",
        "last_error": "lastError",
    }
    for source, target in mapping.items():
        if source in arguments:
            settings[target] = bool(arguments[source]) if source == "connected" else arguments[source]
    state["calendarSettings"] = settings
    server.save_state(state)
    return {"updated": settings}


__all__ = [
    "convert_note_to_calendar_event_impl",
    "list_calendar_events_impl",
    "require_calendar_connected",
    "refresh_calendar_events_impl",
    "import_calendar_events_as_tasks_impl",
    "sync_task_to_calendar_impl",
    "link_task_to_calendar_event_impl",
    "unlink_task_from_calendar_event_impl",
    "disconnect_calendar_impl",
    "update_calendar_settings_impl",
]
