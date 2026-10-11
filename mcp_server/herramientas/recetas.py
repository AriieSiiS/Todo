"""Recetas y menús semanales."""

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


def list_recipes_impl(arguments: dict[str, Any]) -> list[dict[str, Any]]:
    recipes = server.load_state().setdefault("recipes", [])
    if not bool(arguments.get("include_archived", False)):
        recipes = [recipe for recipe in recipes if not recipe.get("archived", False)]
    if bool(arguments.get("favorites_only", False)):
        recipes = [recipe for recipe in recipes if recipe.get("favorite", False)]
    return recipes


RECIPE_CONDIMENTS: tuple[tuple[str, tuple[str, ...]], ...] = (
    ("Sal", ("flor de sal", "escamas de sal", "sal marina", "sal gruesa", "sal fina", "sal")),
    ("Pimienta negra", ("pimienta negra",)),
    ("Pimienta blanca", ("pimienta blanca",)),
    ("Pimienta", ("pimienta",)),
    ("Comino", ("comino en polvo", "comino")),
    ("Jengibre", ("jengibre",)),
    ("Cúrcuma", ("curcuma",)),
    ("Pimentón", ("pimenton de la vera", "pimenton dulce", "pimenton picante", "pimenton", "paprika")),
    ("Orégano", ("oregano",)),
    ("Tomillo", ("tomillo",)),
    ("Romero", ("romero",)),
    ("Albahaca", ("albahaca",)),
    ("Perejil", ("perejil",)),
    ("Cilantro", ("cilantro",)),
    ("Eneldo", ("eneldo",)),
    ("Laurel", ("hoja de laurel", "laurel")),
    ("Canela", ("canela",)),
    ("Nuez moscada", ("nuez moscada",)),
    ("Clavo", ("clavos de olor", "clavo de olor")),
    ("Cardamomo", ("cardamomo",)),
    ("Curry", ("curry en polvo", "curry")),
    ("Garam masala", ("garam masala",)),
    ("Ras el hanout", ("ras el hanout",)),
    ("Chile", ("copos de chile", "chile en polvo", "chili flakes", "guindilla", "chile")),
    ("Cayena", ("pimienta de cayena", "cayena")),
    ("Ajo en polvo", ("ajo en polvo",)),
    ("Cebolla en polvo", ("cebolla en polvo",)),
    ("Aceite de oliva", ("aceite de oliva virgen extra", "aceite de oliva", "aove")),
    ("Aceite de sésamo", ("aceite de sesamo",)),
    ("Aceite de girasol", ("aceite de girasol",)),
    ("Aceite de coco", ("aceite de coco",)),
    ("Vinagre de manzana", ("vinagre de manzana",)),
    ("Vinagre balsámico", ("vinagre balsamico", "aceto balsamico")),
    ("Vinagre de arroz", ("vinagre de arroz",)),
    ("Vinagre", ("vinagre de vino", "vinagre")),
    ("Mostaza", ("mostaza dijon", "mostaza",)),
    ("Salsa de soja", ("salsa de soja", "soja")),
    ("Tamari", ("tamari",)),
    ("Sriracha", ("sriracha",)),
    ("Tabasco", ("tabasco",)),
    ("Salsa Worcestershire", ("salsa worcestershire", "salsa perrins")),
    ("Salsa de pescado", ("salsa de pescado",)),
    ("Tahini", ("tahini",)),
    ("Crema de cacahuete", ("mantequilla de cacahuete", "crema de cacahuete")),
    ("Miel", ("miel",)),
    ("Sirope de arce", ("sirope de arce",)),
    ("Esencia de vainilla", ("extracto de vainilla", "esencia de vainilla")),
    ("Levadura química", ("polvo de hornear", "levadura quimica")),
    ("Bicarbonato", ("bicarbonato sodico", "bicarbonato")),
)


RECIPE_MEASUREMENT_NOISE = {
    "a", "al", "aprox", "aproximadamente", "cda", "cdas", "cds", "cdta",
    "cdtas", "chorrito", "chorritos", "cocinar", "cucharada", "cucharadas",
    "cucharadita", "cucharaditas", "cuatro", "de", "decorar", "del", "dos",
    "el", "en", "fina", "fino", "fresca", "fresco", "g", "gr", "gramo",
    "gramos", "gruesa", "grueso", "gusto", "hoja", "hojas", "kg", "la",
    "las", "l", "litro", "litros", "los", "manojo", "manojos", "media",
    "medio", "ml", "molida", "molido", "o", "para", "pellizco", "pellizcos",
    "picada", "picado", "pizca", "pizcas", "polvo", "rallada", "rallado",
    "rama", "ramas", "ramita", "ramitas", "seca", "seco", "servir", "taza",
    "tazas", "tres", "trocito", "trocitos", "un", "una", "unas", "unos", "y",
}


def _normalize_recipe_ingredient(value: str) -> str:
    normalized = unicodedata.normalize("NFD", value.casefold())
    return "".join(character for character in normalized if unicodedata.category(character) != "Mn")


def _recipe_alias_pattern(alias: str) -> re.Pattern[str]:
    return re.compile(rf"\b{re.escape(_normalize_recipe_ingredient(alias))}\b", re.IGNORECASE)


def _detected_recipe_condiments(value: str) -> list[str]:
    normalized = _normalize_recipe_ingredient(value)
    detected = [
        name
        for name, aliases in RECIPE_CONDIMENTS
        if any(_recipe_alias_pattern(alias).search(normalized) for alias in aliases)
    ]
    if any(name in detected for name in ("Pimienta negra", "Pimienta blanca", "Cayena")):
        detected = [name for name in detected if name != "Pimienta"]
    if any(name.startswith("Vinagre de") or name == "Vinagre balsámico" for name in detected):
        detected = [name for name in detected if name != "Vinagre"]
    return detected


def _recipe_is_condiment(value: str) -> bool:
    if not _detected_recipe_condiments(value):
        return False
    remainder = _normalize_recipe_ingredient(value)
    for _name, aliases in RECIPE_CONDIMENTS:
        for alias in sorted(aliases, key=len, reverse=True):
            remainder = _recipe_alias_pattern(alias).sub(" ", remainder)
    remainder = re.sub(r"\d+(?:[\.,/]\d+)?", " ", remainder)
    remainder = re.sub(r"[¼½¾⅓⅔⅛⅜⅝⅞]", " ", remainder)
    words = re.sub(r"[^a-z]+", " ", remainder).split()
    return not any(word not in RECIPE_MEASUREMENT_NOISE for word in words)


def _recipe_values(arguments: dict[str, Any]) -> dict[str, Any]:
    mapping = {
        "title": "title",
        "description": "description",
        "category": "category",
        "cuisine": "cuisine",
        "servings": "servings",
        "prep_minutes": "prepMinutes",
        "cook_minutes": "cookMinutes",
        "ingredients": "ingredients",
        "instructions": "instructions",
        "tags": "tags",
        "source_url": "sourceUrl",
        "image_source_url": "imageSourceUrl",
        "favorite": "favorite",
        "archived": "archived",
    }
    values: dict[str, Any] = {}
    for source, destination in mapping.items():
        if source not in arguments:
            continue
        value = arguments[source]
        if source == "ingredients":
            value = [
                {
                    "text": str(item).strip(),
                    "group": "",
                    "kind": (
                        "condiment"
                        if _recipe_is_condiment(str(item).strip())
                        else "ingredient"
                    ),
                }
                for item in value
                if str(item).strip()
            ]
        elif source in {"instructions", "tags"}:
            value = list(dict.fromkeys(
                str(item).strip() for item in value if str(item).strip()
            ))
        elif source in {"servings", "prep_minutes", "cook_minutes"}:
            minimum = 1 if source == "servings" else 0
            value = max(minimum, int(value))
        elif source not in {"favorite", "archived"}:
            value = str(value).strip()
        values[destination] = value
    return values


def create_recipe_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    instant = server.now_iso()
    recipe = {
        "id": server.make_id("recipe"),
        "title": str(arguments["title"]).strip() or "Receta sin nombre",
        "description": "",
        "category": "Sin categoría",
        "cuisine": "",
        "servings": 1,
        "prepMinutes": 0,
        "cookMinutes": 0,
        "ingredients": [],
        "instructions": [],
        "tags": [],
        "sourceUrl": "",
        "imageSourceUrl": "",
        "imagePath": "",
        "thumbnailPath": "",
        "imageSha256": "",
        "favorite": False,
        "archived": False,
        "createdAt": instant,
        "updatedAt": instant,
    }
    recipe.update(_recipe_values(arguments))
    state.setdefault("recipes", []).append(recipe)
    server.save_state(state)
    return recipe


def update_recipe_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    index, recipe = server.find_by_id(
        state.setdefault("recipes", []), arguments["recipe_id"], "receta"
    )
    recipe.update(_recipe_values(arguments))
    recipe["updatedAt"] = server.now_iso()
    state["recipes"][index] = recipe
    server.save_state(state)
    return recipe


def _delete_recipe_asset(relative_path: str) -> None:
    if not relative_path:
        return
    root = server.recipe_directory().resolve()
    candidate = (root / relative_path).resolve()
    if root not in candidate.parents:
        return
    candidate.unlink(missing_ok=True)


def set_recipe_image_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    source = Path(str(arguments["source_file"])).expanduser().resolve()
    if not source.is_file() or source.suffix.lower() != ".png":
        raise ValueError("La imagen de la receta debe ser un archivo PNG local.")
    data = source.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n") or len(data) < 33:
        raise ValueError("La imagen de la receta no es un PNG válido.")
    width, height = struct.unpack(">II", data[16:24])
    if width < 300 or height < 200:
        raise ValueError("La imagen debe medir al menos 300 × 200 píxeles.")
    state = server.load_state()
    index, recipe = server.find_by_id(
        state.setdefault("recipes", []), arguments["recipe_id"], "receta"
    )
    digest = hashlib.sha256(data).hexdigest()
    safe_id = re.sub(r"[^a-zA-Z0-9_-]", "-", str(recipe["id"]))
    file_name = f"{safe_id}-{digest[:12]}.png"
    root = server.recipe_directory()
    server._write_household_asset(root / "images", file_name, data)
    server._write_household_asset(root / "thumbnails", file_name, data)
    previous = [str(recipe.get("imagePath") or ""), str(recipe.get("thumbnailPath") or "")]
    recipe["imagePath"] = f"images/{file_name}"
    recipe["thumbnailPath"] = f"thumbnails/{file_name}"
    recipe["imageSha256"] = digest
    recipe["updatedAt"] = server.now_iso()
    state["recipes"][index] = recipe
    try:
        server.save_state(state)
    except Exception:
        _delete_recipe_asset(recipe["imagePath"])
        _delete_recipe_asset(recipe["thumbnailPath"])
        raise
    for old_path in previous:
        if old_path not in {recipe["imagePath"], recipe["thumbnailPath"]}:
            _delete_recipe_asset(old_path)
    return recipe


def _recipe_task_category(name: str) -> dict[str, Any]:
    state = server.load_state()
    for category in state.setdefault("categories", []):
        if str(category.get("name", "")).casefold() == name.casefold():
            return category
    category = {
        "id": server.make_id("cat"),
        "name": name,
        "description": "Creada automáticamente desde Recetas.",
        "colorValue": 0xFFDBA62D if name == "Compras" else 0xFFC7744E,
        "iconCodePoint": 0xE59C,
        "active": True,
    }
    state["categories"].append(category)
    server.save_state(state)
    return category


def create_recipe_task_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    kind = str(arguments["kind"]).strip().lower()
    if kind not in {"shopping", "cooking"}:
        raise ValueError("kind debe ser shopping o cooking.")
    state = server.load_state()
    _index, recipe = server.find_by_id(
        state.setdefault("recipes", []), arguments["recipe_id"], "receta"
    )
    shopping = kind == "shopping"
    if shopping:
        entries = list(dict.fromkeys(
            label
            for ingredient in recipe.get("ingredients", [])
            for label in server._recipe_shopping_labels(ingredient)
        ))
    else:
        entries = [str(item).strip() for item in recipe.get("instructions", [])]
        entries = [entry for entry in entries if entry]
    if shopping and not entries:
        raise ValueError("La receta no tiene ingredientes.")
    category = _recipe_task_category("Compras" if shopping else "Cocina")
    title = (
        f"Comprar ingredientes para {recipe['title']}"
        if shopping
        else f"Preparar {recipe['title']}"
    )
    parent_result = server.create_task_impl({
        "title": title,
        "description": f"Tarea generada desde Recetas · {recipe.get('servings', 1)} raciones.",
        "category_ids": [category["id"]],
        "scheduled_at": arguments.get("scheduled_at"),
    })
    parent_id = parent_result["created"]["id"]
    subtasks = []
    for index, entry in enumerate(entries):
        result = server.create_task_impl({
            "title": entry if shopping else f"{index + 1}. {entry}",
            "category_ids": [category["id"]],
            "parent_task_id": parent_id,
            "scheduled_at": arguments.get("scheduled_at"),
        })
        subtasks.append(result["created"])
    final_state = server.load_state()
    _parent_index, parent = server.find_task(final_state, parent_id)
    return {"task": parent, "subtasks": subtasks}


def delete_recipe_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    server.require_confirm(arguments, "delete_recipe")
    state = server.load_state()
    index, recipe = server.find_by_id(
        state.setdefault("recipes", []), arguments["recipe_id"], "receta"
    )
    state["recipes"].pop(index)
    server.save_state(state)
    _delete_recipe_asset(str(recipe.get("imagePath") or ""))
    _delete_recipe_asset(str(recipe.get("thumbnailPath") or ""))
    return {"deleted": True, "recipe_id": arguments["recipe_id"]}


def list_weekly_menus_impl(arguments: dict[str, Any]) -> list[dict[str, Any]]:
    menus = server.load_state().setdefault("weeklyMenus", [])
    if not bool(arguments.get("include_archived", False)):
        menus = [menu for menu in menus if not menu.get("archived", False)]
    return menus


def create_weekly_menu_task_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    _index, menu = server.find_by_id(
        state.setdefault("weeklyMenus", []), arguments["menu_id"], "menú semanal"
    )
    recipe_ids = [str(value) for value in menu.get("recipeIds", [])]
    meal_entries = list(menu.get("mealEntries") or [])
    if not meal_entries:
        days = ("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday")
        meal_entries = [
            {
                "id": f"legacy-{index + 1}",
                "day": days[index % len(days)],
                "mealType": "lunch",
                "recipeId": recipe_id,
            }
            for index, recipe_id in enumerate(recipe_ids)
        ]
    requested_ids = {
        str(value) for value in (arguments.get("entry_ids") or []) if str(value)
    }
    selected_entries = (
        [entry for entry in meal_entries if str(entry.get("id")) in requested_ids]
        if requested_ids
        else meal_entries
    )
    if not selected_entries:
        raise ValueError("Selecciona al menos una comida del menú.")
    complete_menu = len(selected_entries) == len(meal_entries)
    selected_recipe_list = [
        str(entry.get("recipeId", "")) for entry in selected_entries
    ]
    selected_recipe_set = set(selected_recipe_list)
    curated_recipe_set = {
        str(value)
        for value in (menu.get("shoppingListRecipeIds") or recipe_ids)
        if str(value)
    }
    curated_selection = (
        bool(menu.get("shoppingItems"))
        and len(selected_recipe_list) == len(selected_recipe_set)
        and selected_recipe_set == curated_recipe_set
    )
    if curated_selection:
        shopping_items = [
            item
            for item in menu.get("shoppingItems", [])
            if str(item.get("name", "")).strip()
        ]
    else:
        shopping_items = []
        seen_labels: set[str] = set()
        selected_recipe_ids = {
            str(entry.get("recipeId", "")) for entry in selected_entries
        }
        for recipe in state.setdefault("recipes", []):
            if str(recipe.get("id", "")) not in selected_recipe_ids:
                continue
            for ingredient in recipe.get("ingredients", []):
                for label in server._recipe_shopping_labels(ingredient):
                    if label.casefold() in seen_labels:
                        continue
                    seen_labels.add(label.casefold())
                    shopping_items.append({
                        "name": label,
                        "group": str(recipe.get("title", "")),
                        "priceCents": 0,
                    })
    if not shopping_items:
        raise ValueError("El menú no tiene lista de la compra.")
    category = _recipe_task_category("Compras")
    people = max(1, int(menu.get("people", 1)))
    total_cents = max(0, int(menu.get("totalPriceCents", 0)))
    price = (
        f" · Presupuesto aproximado: {total_cents / 100:.2f} €".replace(".", ",")
        if total_cents and curated_selection
        else ""
    )
    selected_days = {str(entry.get("day", "")) for entry in selected_entries}
    scope = (
        "semana completa"
        if complete_menu
        else f"{len(selected_entries)} comidas · {len(selected_days)} días"
    )
    parent_result = server.create_task_impl({
        "title": (
            f"Comprar {menu['title']}"
            if complete_menu
            else f"Comprar selección de {menu['title']}"
        ),
        "description": (
            f"Lista de compra del menú para {people} "
            f"{'persona' if people == 1 else 'personas'} · {scope}{price}."
        ),
        "category_ids": [category["id"]],
        "scheduled_at": arguments.get("scheduled_at"),
    })
    parent_id = parent_result["created"]["id"]
    subtasks = []
    seen: set[str] = set()
    for item in shopping_items:
        name = str(item["name"]).strip()
        if name.casefold() in seen:
            continue
        seen.add(name.casefold())
        group = str(item.get("group", "")).strip()
        item_cents = max(0, int(item.get("priceCents", 0)))
        description = " · ".join(filter(None, [
            group,
            (
                f"Precio orientativo: {item_cents / 100:.2f} €".replace(".", ",")
                if item_cents
                else ""
            ),
        ]))
        result = server.create_task_impl({
            "title": name,
            "description": description,
            "category_ids": [category["id"]],
            "parent_task_id": parent_id,
            "scheduled_at": arguments.get("scheduled_at"),
        })
        subtasks.append(result["created"])
    final_state = server.load_state()
    _parent_index, parent = server.find_task(final_state, parent_id)
    return {"task": parent, "subtasks": subtasks}


__all__ = [
    "list_recipes_impl",
    "RECIPE_CONDIMENTS",
    "RECIPE_MEASUREMENT_NOISE",
    "_normalize_recipe_ingredient",
    "_recipe_alias_pattern",
    "_detected_recipe_condiments",
    "_recipe_is_condiment",
    "_recipe_values",
    "create_recipe_impl",
    "update_recipe_impl",
    "_delete_recipe_asset",
    "set_recipe_image_impl",
    "_recipe_task_category",
    "create_recipe_task_impl",
    "delete_recipe_impl",
    "list_weekly_menus_impl",
    "create_weekly_menu_task_impl",
]
