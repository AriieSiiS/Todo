"""Biblioteca: elementos y propósitos."""

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


def _entero_positivo(valor: Any) -> int | None:
    """Convierte a entero mayor que cero; cualquier otra cosa queda en nulo."""
    if valor is None:
        return None
    numero = int(valor)
    return numero if numero > 0 else None


def _entero_no_negativo(valor: Any) -> int | None:
    """Convierte a entero igual o mayor que cero; si no, nulo."""
    if valor is None:
        return None
    numero = int(valor)
    return numero if numero >= 0 else None


def ensure_library_goal_lists(state: dict[str, Any]) -> None:
    state.setdefault("libraryItems", [])
    state.setdefault("libraryGoals", [])


def library_title_key(value: str | None) -> str:
    return re.sub(r"[^a-z0-9áéíóúüñ]+", "", (value or "").strip().lower())


def normalize_library_type(value: str) -> str:
    aliases = {
        "game": "game",
        "juego": "game",
        "book": "book",
        "libro": "book",
        "movie": "movieSeries",
        "pelicula": "movieSeries",
        "película": "movieSeries",
        "series": "movieSeries",
        "movieSeries": "movieSeries",
        "movie_series": "movieSeries",
    }
    normalized = aliases.get(value.strip())
    if normalized is None:
        raise ValueError("Tipo de biblioteca no válido. Usa game, book o movieSeries.")
    return normalized


def normalize_media_type(value: str | None) -> str | None:
    if not value:
        return None
    aliases = {
        "movie": "movie",
        "pelicula": "movie",
        "película": "movie",
        "film": "movie",
        "series": "series",
        "serie": "series",
    }
    normalized = aliases.get(value.strip())
    if normalized is None:
        raise ValueError("Tipo de medio no válido. Usa movie o series.")
    return normalized


def normalize_goal_status(value: str | None) -> str:
    if not value:
        return "pending"
    aliases = {
        "pending": "pending",
        "pendiente": "pending",
        "completed": "completed",
        "complete": "completed",
        "completado": "completed",
        "terminado": "completed",
    }
    normalized = aliases.get(value.strip())
    if normalized is None:
        raise ValueError("Estado de propósito no válido. Usa pending o completed.")
    return normalized


def normalize_library_item_status(value: str | None) -> str:
    if not value:
        return "completed"
    aliases = {
        "pending": "pending",
        "pendiente": "pending",
        "inProgress": "inProgress",
        "in_progress": "inProgress",
        "en curso": "inProgress",
        "encurso": "inProgress",
        "completed": "completed",
        "complete": "completed",
        "completado": "completed",
        "terminado": "completed",
    }
    normalized = aliases.get(value.strip())
    if normalized is None:
        raise ValueError(
            "Estado de biblioteca no válido. Usa pending, inProgress o completed."
        )
    return normalized


def parse_completed_date(value: str | None) -> str:
    if not value:
        return server.now_iso()
    try:
        parsed = dt.date.fromisoformat(value.strip())
    except ValueError as error:
        raise ValueError("completed_date debe usar formato YYYY-MM-DD.") from error
    return dt.datetime.combine(parsed, dt.time(hour=12)).astimezone().isoformat()


def normalize_external_url(value: str | None) -> str | None:
    """Devuelve un enlace http(s) válido a Goodreads o Letterboxd, o None si va vacío."""
    text = (value or "").strip()
    if not text:
        return None
    parsed = urllib.parse.urlparse(text if "://" in text else f"https://{text}")
    if parsed.scheme not in ("http", "https") or "." not in parsed.netloc:
        raise ValueError(f"Enlace externo no válido: {value}")
    return parsed.geturl()


def library_item_from_args(arguments: dict[str, Any]) -> dict[str, Any]:
    now = server.now_iso()
    status = normalize_library_item_status(arguments.get("status"))
    return {
        "id": server.make_id("library"),
        "type": normalize_library_type(arguments["type"]),
        "title": arguments["title"].strip(),
        "status": status,
        "completedDate": (
            parse_completed_date(arguments.get("completed_date"))
            if status == "completed"
            else None
        ),
        "coverUrl": (arguments.get("cover_url") or "").strip() or None,
        "externalUrl": normalize_external_url(arguments.get("external_url")),
        "rating": arguments.get("rating"),
        "note": (arguments.get("note") or "").strip() or None,
        "platform": (arguments.get("platform") or "").strip() or None,
        "developer": (arguments.get("developer") or "").strip() or None,
        "author": (arguments.get("author") or "").strip() or None,
        "mediaType": normalize_media_type(arguments.get("media_type")),
        "releaseYear": arguments.get("release_year"),
        "creatorOrDirector": (arguments.get("creator_or_director") or "").strip()
        or None,
        "genre": (arguments.get("genre") or "").strip() or None,
        "format": (arguments.get("format") or "").strip() or None,
        "duration": (arguments.get("duration") or "").strip() or None,
        "pages": (arguments.get("pages") or "").strip() or None,
        "country": (arguments.get("country") or "").strip() or None,
        "universeName": (arguments.get("universe_name") or "").strip() or None,
        "collectionName": (arguments.get("collection_name") or "").strip()
        or None,
        "collectionNumber": (
            int(arguments["collection_number"])
            if arguments.get("collection_number") is not None
            and int(arguments["collection_number"]) > 0
            else None
        ),
        "showCollectionNumber": bool(arguments.get("show_collection_number", False))
        and bool((arguments.get("collection_name") or "").strip())
        and arguments.get("collection_number") is not None
        and int(arguments["collection_number"]) > 0,
        "rewatchCount": max(1, int(arguments.get("rewatch_count", 1))),
        "seasonCount": (
            int(arguments["season_count"])
            if arguments.get("season_count") is not None
            and int(arguments["season_count"]) > 0
            else None
        ),
        "nextSeasonConfirmed": bool(arguments.get("next_season_confirmed", False)),
        "progressCurrent": _entero_no_negativo(arguments.get("progress_current")),
        "progressTotal": _entero_positivo(arguments.get("progress_total")),
        "progressSeason": _entero_positivo(arguments.get("progress_season")),
        "publicationStatus": (arguments.get("publication_status") or "").strip()
        or None,
        "linkedGoalId": arguments.get("linked_goal_id") or None,
        "createdAt": now,
        "updatedAt": now,
    }


def apply_library_item_updates(item: dict[str, Any], arguments: dict[str, Any]) -> dict[str, Any]:
    updated = dict(item)
    status = normalize_library_item_status(
        arguments.get("status", updated.get("status", "completed"))
    )
    updated["status"] = status
    if "type" in arguments:
        updated["type"] = normalize_library_type(arguments["type"])
    if "title" in arguments:
        updated["title"] = arguments["title"].strip()
    if status == "completed" and "completed_date" in arguments:
        updated["completedDate"] = parse_completed_date(arguments.get("completed_date"))
    elif status == "completed" and not updated.get("completedDate"):
        updated["completedDate"] = server.now_iso()
    elif status != "completed":
        updated["completedDate"] = None
    if "cover_url" in arguments:
        updated["coverUrl"] = (arguments.get("cover_url") or "").strip() or None
    if arguments.get("clear_cover_url"):
        updated["coverUrl"] = None
    if "external_url" in arguments:
        updated["externalUrl"] = normalize_external_url(arguments.get("external_url"))
    if arguments.get("clear_external_url"):
        updated["externalUrl"] = None
    if "rating" in arguments:
        updated["rating"] = arguments.get("rating")
    if arguments.get("clear_rating"):
        updated["rating"] = None
    if "note" in arguments:
        updated["note"] = (arguments.get("note") or "").strip() or None
    if arguments.get("clear_note"):
        updated["note"] = None
    if "platform" in arguments:
        updated["platform"] = (arguments.get("platform") or "").strip() or None
    if arguments.get("clear_platform"):
        updated["platform"] = None
    if "developer" in arguments:
        updated["developer"] = (arguments.get("developer") or "").strip() or None
    if arguments.get("clear_developer"):
        updated["developer"] = None
    if "author" in arguments:
        updated["author"] = (arguments.get("author") or "").strip() or None
    if arguments.get("clear_author"):
        updated["author"] = None
    if "media_type" in arguments:
        updated["mediaType"] = normalize_media_type(arguments.get("media_type"))
    if arguments.get("clear_media_type"):
        updated["mediaType"] = None
    if "release_year" in arguments:
        updated["releaseYear"] = int(arguments["release_year"])
    if arguments.get("clear_release_year"):
        updated["releaseYear"] = None
    if "creator_or_director" in arguments:
        updated["creatorOrDirector"] = (
            arguments.get("creator_or_director") or ""
        ).strip() or None
    if arguments.get("clear_creator_or_director"):
        updated["creatorOrDirector"] = None
    if "genre" in arguments:
        updated["genre"] = (arguments.get("genre") or "").strip() or None
    if arguments.get("clear_genre"):
        updated["genre"] = None
    if "format" in arguments:
        updated["format"] = (arguments.get("format") or "").strip() or None
    if arguments.get("clear_format"):
        updated["format"] = None
    if "duration" in arguments:
        updated["duration"] = (arguments.get("duration") or "").strip() or None
    if arguments.get("clear_duration"):
        updated["duration"] = None
    if "pages" in arguments:
        updated["pages"] = (arguments.get("pages") or "").strip() or None
    if arguments.get("clear_pages"):
        updated["pages"] = None
    if "country" in arguments:
        updated["country"] = (arguments.get("country") or "").strip() or None
    if arguments.get("clear_country"):
        updated["country"] = None
    if "universe_name" in arguments:
        updated["universeName"] = (
            arguments.get("universe_name") or ""
        ).strip() or None
    if arguments.get("clear_universe_name"):
        updated["universeName"] = None
    if "collection_name" in arguments:
        updated["collectionName"] = (
            arguments.get("collection_name") or ""
        ).strip() or None
    if arguments.get("clear_collection_name"):
        updated["collectionName"] = None
    if "collection_number" in arguments:
        value = arguments.get("collection_number")
        updated["collectionNumber"] = int(value) if value is not None and int(value) > 0 else None
    if arguments.get("clear_collection_number"):
        updated["collectionNumber"] = None
    if "show_collection_number" in arguments:
        updated["showCollectionNumber"] = bool(arguments["show_collection_number"])
    if not updated.get("collectionName") or not updated.get("collectionNumber"):
        updated["showCollectionNumber"] = False
    if "rewatch_count" in arguments:
        updated["rewatchCount"] = max(1, int(arguments["rewatch_count"]))
    if "season_count" in arguments:
        value = arguments.get("season_count")
        updated["seasonCount"] = int(value) if value is not None and int(value) > 0 else None
    if arguments.get("clear_season_count"):
        updated["seasonCount"] = None
    if "progress_current" in arguments:
        updated["progressCurrent"] = _entero_no_negativo(arguments.get("progress_current"))
    if "progress_total" in arguments:
        updated["progressTotal"] = _entero_positivo(arguments.get("progress_total"))
    if "progress_season" in arguments:
        updated["progressSeason"] = _entero_positivo(arguments.get("progress_season"))
    if "next_season_confirmed" in arguments:
        updated["nextSeasonConfirmed"] = bool(arguments["next_season_confirmed"])
    if "publication_status" in arguments:
        updated["publicationStatus"] = (
            arguments.get("publication_status") or ""
        ).strip() or None
    if arguments.get("clear_publication_status"):
        updated["publicationStatus"] = None
    if "linked_goal_id" in arguments:
        updated["linkedGoalId"] = arguments.get("linked_goal_id") or None
    if arguments.get("clear_linked_goal_id"):
        updated["linkedGoalId"] = None
    updated["updatedAt"] = server.now_iso()
    return updated


def list_library_items_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_library_goal_lists(state)
    items = []
    for item in state["libraryItems"]:
        if "type" in arguments and item.get("type") != normalize_library_type(arguments["type"]):
            continue
        if "completed_year" in arguments:
            if not item.get("completedDate"):
                continue
            completed = dt.datetime.fromisoformat(item["completedDate"])
            if completed.year != int(arguments["completed_year"]):
                continue
        if "status" in arguments and item.get("status", "completed") != normalize_library_item_status(arguments["status"]):
            continue
        items.append(item)
    return {"items": items, "count": len(items)}


def bulk_upsert_library_items_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_library_goal_lists(state)
    created = []
    updated = []
    for raw_item in arguments["items"]:
        item_type = normalize_library_type(raw_item["type"])
        title = library_title_key(raw_item["title"])
        item_status = normalize_library_item_status(raw_item.get("status"))
        item_date = (
            server.parse_datetime(parse_completed_date(raw_item.get("completed_date")))
            if item_status == "completed"
            else None
        )
        match_index = None
        for index, existing in enumerate(state["libraryItems"]):
            if existing.get("type") != item_type:
                continue
            if library_title_key(existing.get("title")) != title:
                continue
            existing_status = existing.get("status", "completed")
            if item_status == "completed" or existing_status == "completed":
                existing_date = server.parse_datetime(existing.get("completedDate"))
                if not (
                    item_status == "completed"
                    and existing_status == "completed"
                    and existing_date is not None
                    and item_date is not None
                    and existing_date.year == item_date.year
                ):
                    continue
            match_index = index
            break
        if match_index is None:
            item = library_item_from_args(raw_item)
            state["libraryItems"].append(item)
            sync_goal_from_library_item(state, item)
            created.append(item)
            continue
        item = apply_library_item_updates(state["libraryItems"][match_index], raw_item)
        state["libraryItems"][match_index] = item
        sync_goal_from_library_item(state, item)
        updated.append(item)
    server.save_state(state)
    return {
        "created": created,
        "updated": updated,
        "created_count": len(created),
        "updated_count": len(updated),
    }


def library_goal_from_args(arguments: dict[str, Any]) -> dict[str, Any]:
    now = server.now_iso()
    goal_type = normalize_library_type(arguments["type"])
    return {
        "id": server.make_id("library_goal"),
        "type": goal_type,
        "title": arguments["title"].strip(),
        "targetYear": int(arguments["target_year"]),
        "status": normalize_goal_status(arguments.get("status")),
        "isFavorite": bool(arguments.get("is_favorite", False)),
        "coverUrl": (arguments.get("cover_url") or "").strip() or None,
        "note": (arguments.get("note") or "").strip() or None,
        "platform": (arguments.get("platform") or "").strip() or None,
        "developer": (arguments.get("developer") or "").strip() or None,
        "author": (arguments.get("author") or "").strip() or None,
        "mediaType": normalize_media_type(arguments.get("media_type")),
        "releaseYear": arguments.get("release_year"),
        "creatorOrDirector": (arguments.get("creator_or_director") or "").strip() or None,
        "genre": (arguments.get("genre") or "").strip() or None,
        "format": (arguments.get("format") or "").strip() or None,
        "duration": (arguments.get("duration") or "").strip() or None,
        "pages": (arguments.get("pages") or "").strip() or None,
        "country": (arguments.get("country") or "").strip() or None,
        "linkedLibraryItemId": arguments.get("linked_library_item_id") or None,
        "createdAt": now,
        "updatedAt": now,
    }


def list_library_goals_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_library_goal_lists(state)
    goals = []
    for goal in state["libraryGoals"]:
        if "target_year" in arguments and int(goal.get("targetYear", 0)) != int(arguments["target_year"]):
            continue
        if "type" in arguments and goal.get("type") != normalize_library_type(arguments["type"]):
            continue
        goals.append(goal)
    return {"goals": goals, "count": len(goals)}


def find_library_goal_index(state: dict[str, Any], arguments: dict[str, Any]) -> int:
    ensure_library_goal_lists(state)
    goal_id = (arguments.get("goal_id") or "").strip()
    title = library_title_key(arguments.get("title"))
    target_year = arguments.get("target_year")
    goal_type = normalize_library_type(arguments["type"]) if arguments.get("type") else None

    matches = []
    for index, goal in enumerate(state["libraryGoals"]):
        if goal_id and goal.get("id") != goal_id:
            continue
        if title and library_title_key(goal.get("title")) != title:
            continue
        if target_year is not None and int(goal.get("targetYear", 0)) != int(target_year):
            continue
        if goal_type is not None and goal.get("type") != goal_type:
            continue
        matches.append(index)

    if not matches:
        raise ValueError("No se encontró ningún propósito con esos filtros.")
    if len(matches) > 1:
        raise ValueError("Los filtros coinciden con varios propósitos; usa goal_id.")
    return matches[0]


def create_library_goal_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_library_goal_lists(state)
    goal = library_goal_from_args(arguments)
    state["libraryGoals"].append(goal)
    synced_item = sync_completed_goal_to_item(state, goal)
    server.save_state(state)
    return {"created": goal, "synced_item": synced_item}


def apply_library_goal_updates(goal: dict[str, Any], arguments: dict[str, Any]) -> dict[str, Any]:
    updated = dict(goal)

    if "new_title" in arguments:
        updated["title"] = arguments["new_title"].strip()
    if "new_target_year" in arguments:
        updated["targetYear"] = int(arguments["new_target_year"])
    if "new_type" in arguments:
        updated["type"] = normalize_library_type(arguments["new_type"])
    if "status" in arguments:
        updated["status"] = normalize_goal_status(arguments.get("status"))
    if "is_favorite" in arguments:
        updated["isFavorite"] = bool(arguments["is_favorite"])
    if "cover_url" in arguments:
        updated["coverUrl"] = (arguments.get("cover_url") or "").strip() or None
    if arguments.get("clear_cover_url"):
        updated["coverUrl"] = None
    if "note" in arguments:
        updated["note"] = (arguments.get("note") or "").strip() or None
    if arguments.get("clear_note"):
        updated["note"] = None
    if "platform" in arguments:
        updated["platform"] = (arguments.get("platform") or "").strip() or None
    if arguments.get("clear_platform"):
        updated["platform"] = None
    if "developer" in arguments:
        updated["developer"] = (arguments.get("developer") or "").strip() or None
    if arguments.get("clear_developer"):
        updated["developer"] = None
    if "author" in arguments:
        updated["author"] = (arguments.get("author") or "").strip() or None
    if arguments.get("clear_author"):
        updated["author"] = None
    if "media_type" in arguments:
        updated["mediaType"] = normalize_media_type(arguments.get("media_type"))
    if arguments.get("clear_media_type"):
        updated["mediaType"] = None
    if "release_year" in arguments:
        updated["releaseYear"] = int(arguments["release_year"])
    if arguments.get("clear_release_year"):
        updated["releaseYear"] = None
    if "creator_or_director" in arguments:
        updated["creatorOrDirector"] = (
            arguments.get("creator_or_director") or ""
        ).strip() or None
    if arguments.get("clear_creator_or_director"):
        updated["creatorOrDirector"] = None
    if "genre" in arguments:
        updated["genre"] = (arguments.get("genre") or "").strip() or None
    if arguments.get("clear_genre"):
        updated["genre"] = None
    if "format" in arguments:
        updated["format"] = (arguments.get("format") or "").strip() or None
    if arguments.get("clear_format"):
        updated["format"] = None
    if "duration" in arguments:
        updated["duration"] = (arguments.get("duration") or "").strip() or None
    if arguments.get("clear_duration"):
        updated["duration"] = None
    if "pages" in arguments:
        updated["pages"] = (arguments.get("pages") or "").strip() or None
    if arguments.get("clear_pages"):
        updated["pages"] = None
    if "country" in arguments:
        updated["country"] = (arguments.get("country") or "").strip() or None
    if arguments.get("clear_country"):
        updated["country"] = None
    if "linked_library_item_id" in arguments:
        updated["linkedLibraryItemId"] = arguments.get("linked_library_item_id") or None
    if arguments.get("clear_linked_library_item_id"):
        updated["linkedLibraryItemId"] = None

    updated["updatedAt"] = server.now_iso()
    return updated


def update_library_goal_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    index = find_library_goal_index(state, arguments)
    goal = apply_library_goal_updates(state["libraryGoals"][index], arguments)
    state["libraryGoals"][index] = goal
    synced_item = sync_completed_goal_to_item(state, goal)
    server.save_state(state)
    return {"updated": goal, "synced_item": synced_item}


def bulk_create_library_goals_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_library_goal_lists(state)
    replace_year = arguments.get("replace_year")
    if replace_year is not None:
        removed_ids = {
            goal.get("id")
            for goal in state["libraryGoals"]
            if int(goal.get("targetYear", 0)) == int(replace_year)
        }
        state["libraryGoals"] = [
            goal
            for goal in state["libraryGoals"]
            if int(goal.get("targetYear", 0)) != int(replace_year)
        ]
        for item in state["libraryItems"]:
            if item.get("linkedGoalId") in removed_ids:
                item["linkedGoalId"] = None
                item["updatedAt"] = server.now_iso()
    created = [library_goal_from_args(goal) for goal in arguments["goals"]]
    state["libraryGoals"].extend(created)
    synced_items = [item for goal in created if (item := sync_completed_goal_to_item(state, goal)) is not None]
    server.save_state(state)
    return {"created": created, "count": len(created), "synced_items": synced_items}


def bulk_upsert_library_goals_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_library_goal_lists(state)
    created = []
    updated = []

    for raw_goal in arguments["goals"]:
        goal_type = normalize_library_type(raw_goal["type"])
        title = library_title_key(raw_goal["title"])
        target_year = int(raw_goal["target_year"])
        match_index = None
        for index, existing in enumerate(state["libraryGoals"]):
            if existing.get("type") != goal_type:
                continue
            if library_title_key(existing.get("title")) != title:
                continue
            if int(existing.get("targetYear", 0)) != target_year:
                continue
            match_index = index
            break

        if match_index is None:
            goal = library_goal_from_args(raw_goal)
            state["libraryGoals"].append(goal)
            created.append(goal)
            sync_completed_goal_to_item(state, goal)
            continue

        goal = apply_library_goal_updates(state["libraryGoals"][match_index], raw_goal)
        state["libraryGoals"][match_index] = goal
        updated.append(goal)
        sync_completed_goal_to_item(state, goal)

    server.save_state(state)
    return {
        "created": created,
        "updated": updated,
        "created_count": len(created),
        "updated_count": len(updated),
    }


def clear_library_goals_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    server.require_confirm(arguments, "clear_library_goals")
    state = server.load_state()
    ensure_library_goal_lists(state)
    before = len(state["libraryGoals"])
    removed_goal_ids: set[str] = set()
    if "target_year" in arguments:
        target_year = int(arguments["target_year"])
        for goal in state["libraryGoals"]:
            if int(goal.get("targetYear", 0)) == target_year:
                removed_goal_ids.add(goal.get("id"))
        state["libraryGoals"] = [
            goal
            for goal in state["libraryGoals"]
            if int(goal.get("targetYear", 0)) != target_year
        ]
    else:
        removed_goal_ids = {goal.get("id") for goal in state["libraryGoals"]}
        state["libraryGoals"] = []
    for item in state["libraryItems"]:
        if item.get("linkedGoalId") in removed_goal_ids:
            item["linkedGoalId"] = None
            item["updatedAt"] = server.now_iso()
    server.save_state(state)
    return {"deleted": before - len(state["libraryGoals"])}


def create_library_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_library_goal_lists(state)
    item = library_item_from_args(arguments)
    item_year = (
        server.parse_datetime(item.get("completedDate")).year
        if item.get("completedDate")
        else None
    )
    for index, existing in enumerate(state["libraryItems"]):
        if existing.get("type") != item.get("type") or library_title_key(
            existing.get("title")
        ) != library_title_key(item.get("title")):
            continue
        existing_status = existing.get("status", "completed")
        existing_year = (
            server.parse_datetime(existing.get("completedDate")).year
            if existing.get("completedDate")
            else None
        )
        same_cycle = (
            existing_status == "completed"
            and item["status"] == "completed"
            and existing_year == item_year
        ) or (existing_status != "completed" and item["status"] != "completed")
        if not same_cycle and item["status"] == "completed" and existing_status != "completed":
            linked_goal = next(
                (
                    goal
                    for goal in state["libraryGoals"]
                    if goal.get("id") == existing.get("linkedGoalId")
                ),
                None,
            )
            same_cycle = bool(
                linked_goal and int(linked_goal.get("targetYear", 0)) == item_year
            )
        if same_cycle:
            merged = merge_library_items(existing, item)
            state["libraryItems"][index] = merged
            synced_goal = sync_goal_from_library_item(state, merged)
            server.save_state(state)
            return {"created": merged, "synced_goal": synced_goal, "merged": True}
    state["libraryItems"].append(item)
    synced_goal = sync_goal_from_library_item(state, item)
    server.save_state(state)
    return {"created": item, "synced_goal": synced_goal}


def find_library_item(state: dict[str, Any], item_id: str) -> tuple[int, dict[str, Any]]:
    return server.find_by_id(state["libraryItems"], item_id, "el item de biblioteca")


def update_library_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_library_goal_lists(state)
    index, item = find_library_item(state, arguments["item_id"])
    updated = apply_library_item_updates(item, arguments)
    state["libraryItems"][index] = updated
    synced_goal = sync_goal_from_library_item(state, updated)
    server.save_state(state)
    return {"updated": updated, "synced_goal": synced_goal}


def delete_library_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    server.require_confirm(arguments, "delete_library_item")
    state = server.load_state()
    ensure_library_goal_lists(state)
    index, item = find_library_item(state, arguments["item_id"])
    deleted = state["libraryItems"].pop(index)
    replacement = None
    for goal in state["libraryGoals"]:
        if goal.get("linkedLibraryItemId") == deleted.get("id") or goal.get("id") == deleted.get("linkedGoalId"):
            goal["linkedLibraryItemId"] = None
            goal["status"] = "pending"
            goal["updatedAt"] = server.now_iso()
            replacement = library_item_from_goal(goal, status="pending")
            replacement["rating"] = deleted.get("rating")
            state["libraryItems"].append(replacement)
            goal["linkedLibraryItemId"] = replacement["id"]
            break
    server.save_state(state)
    return {"deleted": deleted, "replacement": replacement}


def library_item_from_goal(
    goal: dict[str, Any], *, status: str | None = None
) -> dict[str, Any]:
    item_status = status or (
        "completed" if goal.get("status") == "completed" else "pending"
    )
    return {
        "id": server.make_id("library_item"),
        "type": goal.get("type"),
        "title": goal.get("title"),
        "status": item_status,
        "completedDate": server.now_iso() if item_status == "completed" else None,
        "coverUrl": goal.get("coverUrl"),
        "rating": None,
        "note": goal.get("note"),
        "platform": goal.get("platform"),
        "developer": goal.get("developer"),
        "author": goal.get("author"),
        "mediaType": goal.get("mediaType"),
        "releaseYear": goal.get("releaseYear"),
        "creatorOrDirector": goal.get("creatorOrDirector"),
        "genre": goal.get("genre"),
        "format": goal.get("format"),
        "duration": goal.get("duration"),
        "pages": goal.get("pages"),
        "country": goal.get("country"),
        "linkedGoalId": goal.get("id"),
        "createdAt": server.now_iso(),
        "updatedAt": server.now_iso(),
    }


def update_library_item_from_goal(item: dict[str, Any], goal: dict[str, Any]) -> dict[str, Any]:
    updated = dict(item)
    for key in (
        "type",
        "title",
        "coverUrl",
        "note",
        "platform",
        "developer",
        "author",
        "mediaType",
        "releaseYear",
        "creatorOrDirector",
        "genre",
        "format",
        "duration",
        "pages",
        "country",
    ):
        updated[key] = goal.get(key)
    updated["linkedGoalId"] = goal.get("id")
    updated["updatedAt"] = server.now_iso()
    return updated


def merge_library_items(keeper: dict[str, Any], incoming: dict[str, Any]) -> dict[str, Any]:
    primary = incoming if incoming.get("linkedGoalId") else keeper
    secondary = keeper if primary is incoming else incoming
    merged = dict(primary)
    merged["id"] = keeper.get("id")
    incoming_status = incoming.get("status", "completed")
    primary_status = primary.get("status", "completed")
    secondary_status = secondary.get("status", "completed")
    if incoming_status == "completed":
        merged["status"] = "completed"
    elif "inProgress" in (primary_status, secondary_status):
        merged["status"] = "inProgress"
    else:
        merged["status"] = primary_status
    if merged["status"] == "completed":
        dates = [
            value
            for value in (keeper.get("completedDate"), incoming.get("completedDate"))
            if value
        ]
        merged["completedDate"] = min(dates) if dates else server.now_iso()
    else:
        merged["completedDate"] = None
    for key in (
        "coverUrl",
        "externalUrl",
        "rating",
        "note",
        "platform",
        "developer",
        "author",
        "mediaType",
        "releaseYear",
        "creatorOrDirector",
        "genre",
        "format",
        "duration",
        "pages",
        "country",
        "universeName",
        "collectionName",
        "collectionNumber",
        "showCollectionNumber",
        "rewatchCount",
        "seasonCount",
        "nextSeasonConfirmed",
        "progressCurrent",
        "progressTotal",
        "progressSeason",
        "publicationStatus",
        "linkedGoalId",
    ):
        merged[key] = primary.get(key) or secondary.get(key)
    merged["createdAt"] = min(
        keeper.get("createdAt", server.now_iso()),
        incoming.get("createdAt", server.now_iso()),
    )
    merged["updatedAt"] = server.now_iso()
    return merged


def sync_completed_goal_to_item(
    state: dict[str, Any],
    goal: dict[str, Any],
    *,
    reopen_as_pending: bool = False,
) -> dict[str, Any] | None:
    linked_item_id = goal.get("linkedLibraryItemId")
    for index, item in enumerate(state["libraryItems"]):
        if linked_item_id and item.get("id") == linked_item_id:
            if (
                goal.get("status") != "completed"
                and item.get("status", "completed") == "completed"
                and not reopen_as_pending
            ):
                item["linkedGoalId"] = None
                item["updatedAt"] = server.now_iso()
                goal["linkedLibraryItemId"] = None
                break
            updated = update_library_item_from_goal(item, goal)
            if goal.get("status") == "completed":
                updated["status"] = "completed"
                updated["completedDate"] = updated.get("completedDate") or server.now_iso()
            else:
                updated["status"] = (
                    "pending"
                    if reopen_as_pending or item.get("status") != "inProgress"
                    else "inProgress"
                )
                updated["completedDate"] = None
            state["libraryItems"][index] = updated
            goal["linkedLibraryItemId"] = updated["id"]
            return updated
    for index, item in enumerate(state["libraryItems"]):
        if item.get("type") != goal.get("type") or library_title_key(
            item.get("title")
        ) != library_title_key(goal.get("title")) or item.get("linkedGoalId"):
            continue
        item_status = item.get("status", "completed")
        if goal.get("status") == "completed":
            completed = server.parse_datetime(item.get("completedDate"))
            matches = (
                item_status == "completed"
                and completed is not None
                and completed.year == int(goal.get("targetYear", dt.datetime.now().year))
            )
        else:
            matches = item_status != "completed"
        if matches:
            updated = update_library_item_from_goal(item, goal)
            if goal.get("status") == "completed":
                updated["status"] = "completed"
                updated["completedDate"] = updated.get("completedDate") or server.now_iso()
            else:
                updated["status"] = (
                    "pending"
                    if reopen_as_pending or item_status != "inProgress"
                    else "inProgress"
                )
                updated["completedDate"] = None
            state["libraryItems"][index] = updated
            goal["linkedLibraryItemId"] = updated["id"]
            return updated
    item = library_item_from_goal(goal)
    state["libraryItems"].append(item)
    goal["linkedLibraryItemId"] = item["id"]
    return item


def sync_goal_from_library_item(state: dict[str, Any], item: dict[str, Any]) -> dict[str, Any] | None:
    linked_goal_id = item.get("linkedGoalId")
    completed = server.parse_datetime(item.get("completedDate"))
    item_year = completed.year if completed else None
    for index, goal in enumerate(state["libraryGoals"]):
        if linked_goal_id and goal.get("id") == linked_goal_id:
            return update_goal_from_library_item(state, index, item)
    for index, goal in enumerate(state["libraryGoals"]):
        if (
            goal.get("type") == item.get("type")
            and library_title_key(goal.get("title"))
            == library_title_key(item.get("title"))
            and goal.get("linkedLibraryItemId") in (None, item.get("id"))
            and (
                item.get("status", "completed") != "completed"
                or int(goal.get("targetYear", item_year or 0)) == item_year
            )
        ):
            return update_goal_from_library_item(state, index, item)
    return None


def update_goal_from_library_item(state: dict[str, Any], index: int, item: dict[str, Any]) -> dict[str, Any]:
    goal = dict(state["libraryGoals"][index])
    for key in (
        "type",
        "title",
        "coverUrl",
        "note",
        "platform",
        "developer",
        "author",
        "mediaType",
        "releaseYear",
        "creatorOrDirector",
        "genre",
        "format",
        "duration",
        "pages",
        "country",
    ):
        goal[key] = item.get(key)
    item_status = item.get("status", "completed")
    goal["status"] = "completed" if item_status == "completed" else "pending"
    completed = server.parse_datetime(item.get("completedDate"))
    if item_status == "completed" and completed is not None:
        goal["targetYear"] = completed.year
    goal["linkedLibraryItemId"] = item.get("id")
    goal["updatedAt"] = server.now_iso()
    state["libraryGoals"][index] = goal
    item["linkedGoalId"] = goal.get("id")
    return goal


def delete_library_goal_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    server.require_confirm(arguments, "delete_library_goal")
    state = server.load_state()
    ensure_library_goal_lists(state)
    index, goal = server.find_by_id(state["libraryGoals"], arguments["goal_id"], "el propósito")
    deleted = state["libraryGoals"].pop(index)
    linked_item_id = deleted.get("linkedLibraryItemId")
    for item in state["libraryItems"]:
        if item.get("linkedGoalId") == deleted.get("id") or item.get("id") == linked_item_id:
            item["linkedGoalId"] = None
            item["updatedAt"] = server.now_iso()
    server.save_state(state)
    return {"deleted": deleted}


def toggle_library_goal_completed_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_library_goal_lists(state)
    index, goal = server.find_by_id(state["libraryGoals"], arguments["goal_id"], "el propósito")
    updated = copy.deepcopy(goal)
    updated["status"] = "pending" if updated.get("status") == "completed" else "completed"
    updated["updatedAt"] = server.now_iso()
    state["libraryGoals"][index] = updated
    item = sync_completed_goal_to_item(
        state,
        updated,
        reopen_as_pending=updated.get("status") == "pending",
    )
    server.save_state(state)
    return {"updated": updated, "synced_item": item}


def toggle_library_goal_favorite_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_library_goal_lists(state)
    index, goal = server.find_by_id(state["libraryGoals"], arguments["goal_id"], "el propósito")
    updated = copy.deepcopy(goal)
    updated["isFavorite"] = not bool(updated.get("isFavorite", False))
    updated["updatedAt"] = server.now_iso()
    state["libraryGoals"][index] = updated
    server.save_state(state)
    return {"updated": updated}


__all__ = [
    "ensure_library_goal_lists",
    "library_title_key",
    "normalize_library_type",
    "normalize_media_type",
    "normalize_goal_status",
    "normalize_library_item_status",
    "parse_completed_date",
    "library_item_from_args",
    "apply_library_item_updates",
    "list_library_items_impl",
    "bulk_upsert_library_items_impl",
    "library_goal_from_args",
    "list_library_goals_impl",
    "find_library_goal_index",
    "create_library_goal_impl",
    "apply_library_goal_updates",
    "update_library_goal_impl",
    "bulk_create_library_goals_impl",
    "bulk_upsert_library_goals_impl",
    "clear_library_goals_impl",
    "create_library_item_impl",
    "find_library_item",
    "update_library_item_impl",
    "delete_library_item_impl",
    "library_item_from_goal",
    "update_library_item_from_goal",
    "merge_library_items",
    "sync_completed_goal_to_item",
    "sync_goal_from_library_item",
    "update_goal_from_library_item",
    "delete_library_goal_impl",
    "toggle_library_goal_completed_impl",
    "toggle_library_goal_favorite_impl",
]
