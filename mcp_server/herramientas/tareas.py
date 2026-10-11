"""Tareas, proyectos y categorías."""

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


def logical_today(state: dict[str, Any]) -> dt.date:
    now = dt.datetime.now()
    end_hour = int(state.get("daySettings", {}).get("dayEndsAtHour", 5))
    if now.hour < end_hour:
        now = now - dt.timedelta(days=1)
    return now.date()


def parse_datetime(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    try:
        return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def normalize_datetime(value: str | None) -> str | None:
    parsed = parse_datetime(value)
    if parsed is None:
        return None
    if parsed.tzinfo is None:
        return parsed.isoformat()
    return parsed.astimezone().isoformat()


def make_id(prefix: str) -> str:
    return f"{prefix}-{int(dt.datetime.now().timestamp() * 1000000)}-{random.randint(1000, 9999)}"


def parse_date(value: str, field_name: str = "date") -> dt.date:
    try:
        return dt.date.fromisoformat(value.strip())
    except ValueError as error:
        raise ValueError(f"{field_name} debe usar formato YYYY-MM-DD.") from error


def date_iso(value: str, field_name: str = "date") -> str:
    parsed = parse_date(value, field_name)
    return dt.datetime.combine(parsed, dt.time()).isoformat()


def task_matches_date(
    task: dict[str, Any],
    target: dt.date,
    *,
    include_overdue: bool = False,
) -> bool:
    scheduled = parse_datetime(task.get("scheduledAt"))
    if scheduled is None:
        return True
    if include_overdue and scheduled.date() < target:
        return True
    return scheduled.date() == target


def next_manual_order(tasks: list[dict[str, Any]], parent_task_id: str | None = None) -> float:
    relevant = [task.get("manualOrder", 0) for task in tasks if task.get("parentTaskId") == parent_task_id]
    if not relevant:
        return 0.0
    return float(max(relevant)) + 1.0


def find_category(state: dict[str, Any], category_id: str) -> tuple[int, dict[str, Any]]:
    for index, category in enumerate(state["categories"]):
        if category.get("id") == category_id:
            return index, category
    raise ValueError(f"No existe la categoría '{category_id}'.")


def task_reminder_rules(task: dict[str, Any]) -> list[dict[str, Any]]:
    raw_rules = task.get("reminderRules")
    if isinstance(raw_rules, list):
        return [
            copy.deepcopy(rule)
            for rule in raw_rules
            if isinstance(rule, dict) and bool(rule.get("enabled", True))
        ]
    legacy = task.get("reminderRule")
    if isinstance(legacy, dict) and bool(legacy.get("enabled", True)):
        return [copy.deepcopy(legacy)]
    return []


def reminder_rule_from_arguments(
    arguments: dict[str, Any],
    default_minutes: int,
) -> dict[str, Any]:
    delivery_mode = arguments.get("reminder_delivery_mode", "normal")
    if delivery_mode not in {"normal", "important"}:
        raise ValueError("reminder_delivery_mode debe ser 'normal' o 'important'.")
    return {
        "triggerMode": arguments.get("reminder_trigger_mode", "minutesBefore"),
        "minutesBefore": max(0, int(arguments.get("reminder_minutes_before", default_minutes))),
        "firesAtDayStart": bool(arguments.get("reminder_fires_at_day_start", False)),
        "firesAtDayEnd": bool(arguments.get("reminder_fires_at_day_end", False)),
        "deliveryMode": delivery_mode,
        "enabled": True,
    }


def reminder_rule_key(rule: dict[str, Any]) -> tuple[Any, ...]:
    return (
        rule.get("triggerMode", "minutesBefore"),
        int(rule.get("minutesBefore", 0)),
        bool(rule.get("firesAtDayStart", False)),
        bool(rule.get("firesAtDayEnd", False)),
    )


def write_task_reminder_rules(
    task: dict[str, Any],
    rules: list[dict[str, Any]],
) -> None:
    normalized: list[dict[str, Any]] = []
    seen: set[tuple[Any, ...]] = set()
    for source in rules:
        if not isinstance(source, dict) or not bool(source.get("enabled", True)):
            continue
        rule = {
            "triggerMode": source.get("triggerMode", "minutesBefore"),
            "minutesBefore": max(0, int(source.get("minutesBefore", 0))),
            "firesAtDayStart": bool(source.get("firesAtDayStart", False)),
            "firesAtDayEnd": bool(source.get("firesAtDayEnd", False)),
            "deliveryMode": (
                source.get("deliveryMode")
                if source.get("deliveryMode") in {"normal", "important"}
                else "normal"
            ),
            "enabled": True,
        }
        key = reminder_rule_key(rule)
        if key in seen:
            continue
        seen.add(key)
        normalized.append(rule)
    normalized.sort(key=lambda rule: int(rule.get("minutesBefore", 0)))
    task["reminderRules"] = normalized
    # Compatibilidad temporal con versiones que solo admiten un aviso.
    task["reminderRule"] = copy.deepcopy(normalized[0]) if normalized else None


def create_task_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_core_lists(state)
    ensure_task_refs(state, arguments.get("category_ids", []), arguments.get("project_ids", []))
    tasks = state["tasks"]
    parent_task_id = arguments.get("parent_task_id")
    if parent_task_id:
        parent_index, parent_task = find_task(state, parent_task_id)
    else:
        parent_index, parent_task = None, None
    default_reminder_minutes = int(
        state["notificationSettings"].get("defaultMinutesBeforeTask", 30)
    )
    reminder_values = arguments.get("reminder_minutes_before_values")
    reminder_enabled = bool(
        arguments.get("reminder_enabled", isinstance(reminder_values, list))
    )
    task = {
        "id": make_id("task"),
        "title": arguments["title"].strip(),
        "description": arguments.get("description") or None,
        "categoryIds": arguments.get("category_ids", []),
        "projectIds": arguments.get("project_ids", []),
        "scheduledAt": normalize_datetime(arguments.get("scheduled_at")),
        "priority": ensure_value(arguments.get("priority", "medium"), server.VALID_TASK_PRIORITIES, "priority"),
        "status": ensure_value(arguments.get("status", "active"), server.VALID_TASK_STATUSES, "status"),
        "recurrence": {
            "type": ensure_value(arguments.get("recurrence_type", "none"), server.VALID_RECURRENCE_TYPES, "recurrence_type"),
            "interval": int(arguments.get("recurrence_interval", 1)),
            "weekdays": arguments.get("recurrence_weekdays", []),
        },
        "subtaskIds": [],
        "checklist": arguments.get("checklist", []),
        "materials": arguments.get("materials", []),
        "origin": arguments.get("origin", "manual"),
        "manualOrder": float(arguments.get("manual_order", next_manual_order(tasks, parent_task_id))),
        "parentTaskId": parent_task_id,
        "collapsed": bool(arguments.get("collapsed", False)),
        "calendarLink": None,
    }
    reminder_rules: list[dict[str, Any]] = []
    if reminder_enabled:
        if isinstance(reminder_values, list):
            reminder_rules = [
                reminder_rule_from_arguments(
                    {**arguments, "reminder_minutes_before": minutes},
                    default_reminder_minutes,
                )
                for minutes in reminder_values
            ]
        else:
            reminder_rules = [
                reminder_rule_from_arguments(arguments, default_reminder_minutes)
            ]
    write_task_reminder_rules(task, reminder_rules)
    tasks.append(task)
    if parent_task is not None and parent_index is not None:
        updated_parent = copy.deepcopy(parent_task)
        updated_parent["subtaskIds"] = list(updated_parent.get("subtaskIds", [])) + [task["id"]]
        state["tasks"][parent_index] = updated_parent
    server.save_state(state)
    return {"created": task}


def find_task(state: dict[str, Any], task_id: str) -> tuple[int, dict[str, Any]]:
    for index, task in enumerate(state["tasks"]):
        if task.get("id") == task_id:
            return index, task
    raise ValueError(f"No existe la tarea '{task_id}'.")


def update_task_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_core_lists(state)
    index, task = find_task(state, arguments["task_id"])
    updated = copy.deepcopy(task)

    if "title" in arguments:
        updated["title"] = arguments["title"].strip()
    if "description" in arguments:
        updated["description"] = arguments.get("description") or None
    if arguments.get("clear_scheduled_at"):
        updated["scheduledAt"] = None
    elif "scheduled_at" in arguments:
        updated["scheduledAt"] = normalize_datetime(arguments.get("scheduled_at"))
    if "priority" in arguments:
        updated["priority"] = ensure_value(arguments["priority"], server.VALID_TASK_PRIORITIES, "priority")
    if "status" in arguments:
        updated["status"] = ensure_value(arguments["status"], server.VALID_TASK_STATUSES, "status")
        if updated["status"] == "completed":
            updated["completedAt"] = updated.get("completedAt") or server.now_iso()
        else:
            updated.pop("completedAt", None)
    if "category_ids" in arguments:
        ensure_task_refs(state, category_ids=arguments["category_ids"])
        updated["categoryIds"] = arguments["category_ids"]
    if "project_ids" in arguments:
        ensure_task_refs(state, project_ids=arguments["project_ids"])
        updated["projectIds"] = arguments["project_ids"]
    if "materials" in arguments:
        updated["materials"] = arguments["materials"]
    if "checklist" in arguments:
        updated["checklist"] = arguments["checklist"]
    if "collapsed" in arguments:
        updated["collapsed"] = bool(arguments["collapsed"])
    if "manual_order" in arguments:
        updated["manualOrder"] = float(arguments["manual_order"])
    if "recurrence_type" in arguments or "recurrence_interval" in arguments or "recurrence_weekdays" in arguments:
        recurrence = dict(updated.get("recurrence") or {"type": "none", "interval": 1, "weekdays": []})
        if "recurrence_type" in arguments:
            recurrence["type"] = ensure_value(arguments["recurrence_type"], server.VALID_RECURRENCE_TYPES, "recurrence_type")
        if "recurrence_interval" in arguments:
            recurrence["interval"] = int(arguments["recurrence_interval"])
        if "recurrence_weekdays" in arguments:
            recurrence["weekdays"] = arguments["recurrence_weekdays"]
        updated["recurrence"] = recurrence
    if "reminder_minutes_before_values" in arguments:
        values = arguments.get("reminder_minutes_before_values") or []
        rules = (
            []
            if arguments.get("reminder_enabled") is False
            else [
                reminder_rule_from_arguments(
                    {**arguments, "reminder_minutes_before": minutes},
                    int(state["notificationSettings"].get("defaultMinutesBeforeTask", 30)),
                )
                for minutes in values
            ]
        )
        write_task_reminder_rules(updated, rules)
    elif arguments.get("reminder_enabled") is False:
        write_task_reminder_rules(updated, [])
    elif arguments.get("reminder_enabled") is True or "reminder_minutes_before" in arguments:
        rules = task_reminder_rules(updated)
        rules.append(
            reminder_rule_from_arguments(
                arguments,
                int(state["notificationSettings"].get("defaultMinutesBeforeTask", 30)),
            )
        )
        write_task_reminder_rules(updated, rules)

    state["tasks"][index] = updated
    server.save_state(state)
    return {"updated": updated}


def complete_task_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    index, task = find_task(state, arguments["task_id"])
    updated = task_with_completion(task, True)
    state["tasks"][index] = updated
    server.save_state(state)
    return {"completed": updated}


def move_task_to_day_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    index, task = find_task(state, arguments["task_id"])
    current = parse_datetime(task.get("scheduledAt")) or dt.datetime.combine(logical_today(state), dt.time(12, 0))
    target_date = dt.date.fromisoformat(arguments["date"])
    moved = copy.deepcopy(task)
    moved["scheduledAt"] = dt.datetime(
        target_date.year,
        target_date.month,
        target_date.day,
        current.hour,
        current.minute,
        current.second,
    ).isoformat()
    if moved.get("calendarLink"):
        moved["calendarLink"]["syncStatus"] = "pending"
    state["tasks"][index] = moved
    server.save_state(state)
    return {"moved": moved}


def list_tasks_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    target_date = None
    include_overdue = False
    if "date" in arguments:
        if arguments["date"] == "today":
            target_date = logical_today(state)
            include_overdue = True
        else:
            target_date = dt.date.fromisoformat(arguments["date"])

    tasks = []
    for task in state["tasks"]:
        if "status" in arguments and task.get("status") != arguments["status"]:
            continue
        if "project_id" in arguments and arguments["project_id"] not in task.get("projectIds", []):
            continue
        if "category_id" in arguments and arguments["category_id"] not in task.get("categoryIds", []):
            continue
        if target_date is not None and not task_matches_date(
            task,
            target_date,
            include_overdue=include_overdue and task.get("status") == "active",
        ):
            continue
        tasks.append(task)
    return {"tasks": tasks, "count": len(tasks), "mode": "supabase" if server.remote_enabled() else "local"}


def get_today_impl() -> dict[str, Any]:
    state = server.load_state()
    today = logical_today(state)
    tasks = [
        task
        for task in state["tasks"]
        if task.get("status") == "active"
        and task_matches_date(task, today, include_overdue=True)
    ]
    return {
        "logical_date": today.isoformat(),
        "tasks": tasks,
        "count": len(tasks),
        "mode": "supabase" if server.remote_enabled() else "local",
    }


def list_projects_impl() -> dict[str, Any]:
    state = server.load_state()
    return {"projects": state["projects"], "count": len(state["projects"])}


def list_categories_impl() -> dict[str, Any]:
    state = server.load_state()
    return {"categories": state["categories"], "count": len(state["categories"])}


def create_category_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    category = {
        "id": make_id("cat"),
        "name": arguments["name"].strip(),
        "description": arguments.get("description", "").strip(),
        "colorValue": int(arguments.get("color_value", 0xFF607A5A)),
        "iconCodePoint": int(arguments.get("icon_code_point", 0xF624)),
        "active": bool(arguments.get("active", True)),
    }
    state["categories"].append(category)
    server.save_state(state)
    return {"created": category}


def create_project_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_core_lists(state)
    ensure_task_refs(state, category_ids=arguments.get("category_ids", []))
    project = {
        "id": make_id("project"),
        "name": arguments["name"].strip(),
        "description": arguments.get("description", "").strip(),
        "colorValue": int(arguments.get("color_value", 0xFF607A5A)),
        "iconCodePoint": int(arguments.get("icon_code_point", 983108)),
        "status": ensure_value(arguments.get("status", "active"), server.VALID_PROJECT_STATUSES, "status"),
        "categoryIds": arguments.get("category_ids", []),
    }
    state["projects"].append(project)
    server.save_state(state)
    return {"created": project}


def require_confirm(arguments: dict[str, Any], action: str) -> None:
    if not arguments.get("confirm"):
        raise ValueError(f"{action} es una operacion peligrosa. Repite la llamada con confirm=true.")


def ensure_core_lists(state: dict[str, Any]) -> None:
    for key in (
        "tasks",
        "categories",
        "projects",
        "notes",
        "calendarEvents",
        "plants",
        "libraryItems",
        "libraryGoals",
    ):
        state.setdefault(key, [])
    state.setdefault("daySettings", {"dayEndsAtHour": 5, "nextDayVisibleAtHour": 10})
    state.setdefault("notificationSettings", server.default_state()["notificationSettings"])
    state.setdefault("calendarSettings", server.default_state()["calendarSettings"])


def ensure_value(value: str, valid: set[str], label: str) -> str:
    normalized = value.strip()
    if normalized not in valid:
        raise ValueError(f"{label} no válido. Usa uno de: {', '.join(sorted(valid))}.")
    return normalized


def ensure_task_refs(state: dict[str, Any], category_ids: list[str] | None = None, project_ids: list[str] | None = None) -> None:
    for category_id in category_ids or []:
        server.find_by_id(state["categories"], category_id, "la categoría")
    for project_id in project_ids or []:
        server.find_by_id(state["projects"], project_id, "el proyecto")


def task_with_completion(task: dict[str, Any], completed: bool) -> dict[str, Any]:
    updated = copy.deepcopy(task)
    updated["status"] = "completed" if completed else "active"
    if completed:
        updated["completedAt"] = server.now_iso()
    else:
        updated.pop("completedAt", None)
    if updated.get("calendarLink"):
        updated["calendarLink"]["syncStatus"] = "pending"
    return updated


def delete_task_from_state(state: dict[str, Any], task_id: str) -> dict[str, Any]:
    index, task = find_task(state, task_id)
    nested_ids = {task_id, *task.get("subtaskIds", [])}
    deleted = [item for item in state["tasks"] if item.get("id") in nested_ids or item.get("parentTaskId") == task_id]
    deleted_ids = {item["id"] for item in deleted}
    del state["tasks"][index]
    state["tasks"] = [item for item in state["tasks"] if item.get("id") not in deleted_ids]
    for item in state["tasks"]:
        item["subtaskIds"] = [sub_id for sub_id in item.get("subtaskIds", []) if sub_id not in deleted_ids]
    return {"deleted": deleted, "deleted_count": len(deleted)}


def delete_task_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_core_lists(state)
    result = delete_task_from_state(state, arguments["task_id"])
    server.save_state(state)
    return result


def reopen_task_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    index, task = find_task(state, arguments["task_id"])
    updated = task_with_completion(task, False)
    state["tasks"][index] = updated
    server.save_state(state)
    return {"reopened": updated}


def bulk_complete_tasks_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    completed = []
    for task_id in arguments["task_ids"]:
        index, task = find_task(state, task_id)
        updated = task_with_completion(task, True)
        state["tasks"][index] = updated
        completed.append(updated)
    server.save_state(state)
    return {"completed": completed, "count": len(completed)}


def bulk_reopen_tasks_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    reopened = []
    for task_id in arguments["task_ids"]:
        index, task = find_task(state, task_id)
        updated = task_with_completion(task, False)
        state["tasks"][index] = updated
        reopened.append(updated)
    server.save_state(state)
    return {"reopened": reopened, "count": len(reopened)}


def bulk_delete_tasks_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    require_confirm(arguments, "bulk_delete_tasks")
    state = server.load_state()
    deleted = []
    for task_id in arguments["task_ids"]:
        if any(task.get("id") == task_id for task in state["tasks"]):
            deleted.extend(delete_task_from_state(state, task_id)["deleted"])
    server.save_state(state)
    return {"deleted": deleted, "count": len(deleted)}


def bulk_move_tasks_to_day_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    moved = []
    for task_id in arguments["task_ids"]:
        moved.append(move_task_to_day_impl({"task_id": task_id, "date": arguments["date"]})["moved"])
    return {"moved": moved, "count": len(moved)}


def reorder_tasks_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    changed = []
    for order, task_id in enumerate(arguments["ordered_ids"]):
        index, task = find_task(state, task_id)
        updated = copy.deepcopy(task)
        updated["manualOrder"] = float(order)
        state["tasks"][index] = updated
        changed.append(updated)
    server.save_state(state)
    return {"updated": changed, "count": len(changed)}


def create_subtask_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    return create_task_impl(
        {
            "title": arguments["title"],
            "parent_task_id": arguments["parent_task_id"],
            "scheduled_at": arguments.get("scheduled_at"),
            "priority": arguments.get("priority", "medium"),
        }
    )


def set_task_reminder_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    index, task = find_task(state, arguments["task_id"])
    updated = copy.deepcopy(task)
    rules = task_reminder_rules(updated)
    new_rule = reminder_rule_from_arguments(
        arguments,
        int(state.get("notificationSettings", {}).get("defaultMinutesBeforeTask", 30)),
    )
    if arguments.get("reminder_enabled", True):
        key = reminder_rule_key(new_rule)
        rules = [rule for rule in rules if reminder_rule_key(rule) != key]
        rules.append(new_rule)
    else:
        key = reminder_rule_key(new_rule)
        rules = [rule for rule in rules if reminder_rule_key(rule) != key]
    write_task_reminder_rules(updated, rules)
    state["tasks"][index] = updated
    server.save_state(state)
    return {"updated": updated}


def clear_task_reminder_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    index, task = find_task(state, arguments["task_id"])
    updated = copy.deepcopy(task)
    selector_fields = {
        "reminder_minutes_before",
        "reminder_trigger_mode",
        "reminder_fires_at_day_start",
        "reminder_fires_at_day_end",
        "reminder_delivery_mode",
    }
    if selector_fields.intersection(arguments):
        selected = reminder_rule_from_arguments(arguments, 0)
        selected_key = reminder_rule_key(selected)
        rules = [
            rule
            for rule in task_reminder_rules(updated)
            if reminder_rule_key(rule) != selected_key
        ]
    else:
        rules = []
    write_task_reminder_rules(updated, rules)
    state["tasks"][index] = updated
    server.save_state(state)
    return {"updated": updated}


def update_project_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    index, project = server.find_by_id(state["projects"], arguments["project_id"], "el proyecto")
    updated = copy.deepcopy(project)
    if "name" in arguments:
        updated["name"] = arguments["name"].strip()
    if "description" in arguments:
        updated["description"] = arguments.get("description", "").strip()
    if "color_value" in arguments:
        updated["colorValue"] = int(arguments["color_value"])
    if "icon_code_point" in arguments:
        updated["iconCodePoint"] = int(arguments["icon_code_point"])
    if "status" in arguments:
        updated["status"] = ensure_value(arguments["status"], server.VALID_PROJECT_STATUSES, "status")
    if "category_ids" in arguments:
        ensure_task_refs(state, category_ids=arguments["category_ids"])
        updated["categoryIds"] = arguments["category_ids"]
    state["projects"][index] = updated
    server.save_state(state)
    return {"updated": updated}


def set_project_status_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    return update_project_impl({"project_id": arguments["project_id"], "status": arguments["status"]})


def delete_project_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    require_confirm(arguments, "delete_project")
    state = server.load_state()
    index, project = server.find_by_id(state["projects"], arguments["project_id"], "el proyecto")
    deleted = state["projects"].pop(index)
    for task in state["tasks"]:
        task["projectIds"] = [project_id for project_id in task.get("projectIds", []) if project_id != project["id"]]
    server.save_state(state)
    return {"deleted": deleted}


def update_category_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    index, category = server.find_by_id(state["categories"], arguments["category_id"], "la categoría")
    updated = copy.deepcopy(category)
    if "name" in arguments:
        updated["name"] = arguments["name"].strip()
    if "description" in arguments:
        updated["description"] = arguments.get("description", "").strip()
    if "color_value" in arguments:
        updated["colorValue"] = int(arguments["color_value"])
    if "icon_code_point" in arguments:
        updated["iconCodePoint"] = int(arguments["icon_code_point"])
    if "active" in arguments:
        updated["active"] = bool(arguments["active"])
    state["categories"][index] = updated
    server.save_state(state)
    return {"updated": updated}


def toggle_category_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    index, category = server.find_by_id(state["categories"], arguments["category_id"], "la categoría")
    updated = copy.deepcopy(category)
    updated["active"] = not bool(updated.get("active", True))
    state["categories"][index] = updated
    server.save_state(state)
    return {"updated": updated}


def delete_category_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    require_confirm(arguments, "delete_category")
    state = server.load_state()
    index, category = server.find_by_id(state["categories"], arguments["category_id"], "la categoría")
    deleted = state["categories"].pop(index)
    for task in state["tasks"]:
        task["categoryIds"] = [category_id for category_id in task.get("categoryIds", []) if category_id != deleted["id"]]
    for project in state["projects"]:
        project["categoryIds"] = [category_id for category_id in project.get("categoryIds", []) if category_id != deleted["id"]]
    server.save_state(state)
    return {"deleted": deleted}


__all__ = [
    "logical_today",
    "parse_datetime",
    "normalize_datetime",
    "make_id",
    "parse_date",
    "date_iso",
    "task_matches_date",
    "next_manual_order",
    "find_category",
    "task_reminder_rules",
    "reminder_rule_from_arguments",
    "reminder_rule_key",
    "write_task_reminder_rules",
    "create_task_impl",
    "find_task",
    "update_task_impl",
    "complete_task_impl",
    "move_task_to_day_impl",
    "list_tasks_impl",
    "get_today_impl",
    "list_projects_impl",
    "list_categories_impl",
    "create_category_impl",
    "create_project_impl",
    "require_confirm",
    "ensure_core_lists",
    "ensure_value",
    "ensure_task_refs",
    "task_with_completion",
    "delete_task_from_state",
    "delete_task_impl",
    "reopen_task_impl",
    "bulk_complete_tasks_impl",
    "bulk_reopen_tasks_impl",
    "bulk_delete_tasks_impl",
    "bulk_move_tasks_to_day_impl",
    "reorder_tasks_impl",
    "create_subtask_impl",
    "set_task_reminder_impl",
    "clear_task_reminder_impl",
    "update_project_impl",
    "set_project_status_impl",
    "delete_project_impl",
    "update_category_impl",
    "toggle_category_impl",
    "delete_category_impl",
]
