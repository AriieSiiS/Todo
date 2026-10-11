"""Ajustes, navegación y sincronización con la nube."""

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


def get_settings_impl() -> dict[str, Any]:
    state = server.load_state()
    return {
        "daySettings": state.get("daySettings", {}),
        "notificationSettings": state.get("notificationSettings", {}),
        "calendarSettings": state.get("calendarSettings", {}),
        "section": state.get("section", "today"),
        "todaySort": state.get("todaySort", "manual"),
        "navOrder": state.get("navOrder", []),
    }


def update_day_settings_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    settings = dict(state.get("daySettings", server.default_state()["daySettings"]))
    if "day_ends_at_hour" in arguments:
        settings["dayEndsAtHour"] = int(arguments["day_ends_at_hour"])
    if "next_day_visible_at_hour" in arguments:
        settings["nextDayVisibleAtHour"] = int(arguments["next_day_visible_at_hour"])
    state["daySettings"] = settings
    server.save_state(state)
    return {"updated": settings}


def update_notification_settings_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    settings = dict(state.get("notificationSettings", server.default_state()["notificationSettings"]))
    mapping = {
        "notifications_enabled": "notificationsEnabled",
        "web_permission_granted": "webPermissionGranted",
        "windows_permission_granted": "windowsPermissionGranted",
        "day_start_reminder_enabled": "dayStartReminderEnabled",
        "day_end_reminder_enabled": "dayEndReminderEnabled",
        "default_minutes_before_task": "defaultMinutesBeforeTask",
    }
    for source, target in mapping.items():
        if source in arguments:
            settings[target] = int(arguments[source]) if source == "default_minutes_before_task" else bool(arguments[source])
    state["notificationSettings"] = settings
    server.save_state(state)
    return {"updated": settings}


def set_today_sort_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    state["todaySort"] = server.ensure_value(arguments["today_sort"], server.VALID_TODAY_SORTS, "today_sort")
    server.save_state(state)
    return {"todaySort": state["todaySort"]}


def reorder_navigation_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    sections = [server.ensure_value(section, server.VALID_SECTIONS, "section") for section in arguments["sections"]]
    state = server.load_state()
    state["navOrder"] = sections
    server.save_state(state)
    return {"navOrder": sections}


def sync_with_cloud_impl() -> dict[str, Any]:
    if not server.remote_enabled():
        raise ValueError("No hay credenciales remotas configuradas.")
    state = server.load_state()
    server.write_remote_state(state)
    return {"synced": True, "mode": "supabase"}


def disconnect_cloud_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    server.require_confirm(arguments, "disconnect_cloud")
    state = server.load_state()
    state["lastModifiedBy"] = "mcp"
    server.write_local_state(state)
    server.write_app_snapshot(state)
    return {"disconnected": True}


__all__ = [
    "get_settings_impl",
    "update_day_settings_impl",
    "update_notification_settings_impl",
    "set_today_sort_impl",
    "reorder_navigation_impl",
    "sync_with_cloud_impl",
    "disconnect_cloud_impl",
]
