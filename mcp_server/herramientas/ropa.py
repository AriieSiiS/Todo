"""Armario, conjuntos, lavandería y maletas."""

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


def wardrobe_import_contract_impl() -> dict[str, Any]:
    return {
        "version": 2,
        "direct_tool": "import_wardrobe_item",
        "replace_image_tool": "set_wardrobe_item_image",
        "categories": WARDROBE_CATEGORIES,
        "colors": WARDROBE_COLORS,
        "seasons": WARDROBE_SEASONS,
        "occasions": WARDROBE_OCCASIONS,
        "manifest": "manifest.json",
        "image_format": "PNG RGBA con al menos un píxel transparente",
        "catalog_presets": {
            "Calzado": {
                "name": "calzado-perfil",
                "canvas": [1200, 1200],
                "visibleWidth": 1032,
                "visibleAspectRatio": [1.85, 2.70],
                "orientation": "una pieza en perfil lateral elevado con la puntera hacia la izquierda",
            },
        },
        "shape": {
            "version": 1,
            "batchId": "identificador-opcional",
            "name": "Nombre del lote",
            "items": [{
                "id": "identificador-estable",
                "file": "prenda.png",
                "name": "Nombre visible",
                "category": "Categoría",
                "colors": ["color"],
                "material": "material",
                "seasons": ["temporada"],
                "occasions": ["ocasión"],
                "tags": ["etiqueta"],
                "confidence": "alta|media|baja",
                "sourceReferences": ["foto-origen.jpg"],
            }],
        },
    }


def _png_has_transparency(path: Path) -> bool:
    data = path.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        return False
    offset = 8
    width = height = bit_depth = color_type = interlace = 0
    compressed = bytearray()
    while offset + 12 <= len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        chunk = data[offset + 8:offset + 8 + length]
        offset += 12 + length
        if kind == b"IHDR":
            width, height, bit_depth, color_type, _compression, _filter, interlace = struct.unpack(">IIBBBBB", chunk)
        elif kind == b"IDAT":
            compressed.extend(chunk)
        elif kind == b"IEND":
            break
    if bit_depth != 8 or color_type not in (4, 6) or interlace != 0 or not compressed:
        return False
    channels = 2 if color_type == 4 else 4
    stride = width * channels
    raw = zlib.decompress(bytes(compressed))
    previous = bytearray(stride)
    cursor = 0
    for _row in range(height):
        filter_type = raw[cursor]
        cursor += 1
        encoded = raw[cursor:cursor + stride]
        cursor += stride
        decoded = bytearray(stride)
        for index, value in enumerate(encoded):
            left = decoded[index - channels] if index >= channels else 0
            up = previous[index]
            upper_left = previous[index - channels] if index >= channels else 0
            if filter_type == 0:
                result = value
            elif filter_type == 1:
                result = value + left
            elif filter_type == 2:
                result = value + up
            elif filter_type == 3:
                result = value + ((left + up) // 2)
            elif filter_type == 4:
                estimate = left + up - upper_left
                distances = (abs(estimate - left), abs(estimate - up), abs(estimate - upper_left))
                predictor = left if distances[0] <= distances[1] and distances[0] <= distances[2] else up if distances[1] <= distances[2] else upper_left
                result = value + predictor
            else:
                return False
            decoded[index] = result & 0xFF
        if any(decoded[index] < 255 for index in range(channels - 1, stride, channels)):
            return True
        previous = decoded
    return False


def stage_wardrobe_batch_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    source = Path(str(arguments["source_directory"])).expanduser().resolve()
    if not source.is_dir():
        raise ValueError("La carpeta de origen no existe.")
    manifest = Path(str(arguments.get("manifest_path") or source / "manifest.json")).expanduser().resolve()
    if manifest.parent != source or not manifest.is_file():
        raise ValueError("manifest_path debe ser manifest.json dentro de la carpeta de origen.")
    payload = json.loads(manifest.read_text(encoding="utf-8"))
    if int(payload.get("version", 0)) != 1:
        raise ValueError("La versión del manifiesto no es compatible.")
    raw_items = payload.get("items")
    if not isinstance(raw_items, list) or not raw_items:
        raise ValueError("El manifiesto no contiene prendas.")
    batch_id = re.sub(r"[^a-zA-Z0-9_-]", "-", str(payload.get("batchId") or server.make_id("ropa")))
    destination = server.wardrobe_directory() / "imports" / batch_id
    if destination.exists():
        raise ValueError("Ya existe un lote con ese identificador.")
    destination.mkdir(parents=True)
    state = server.load_state()
    existing = {item.get("imageSha256"): item.get("id") for item in state.get("wardrobeItems", []) if item.get("imageSha256")}
    staged: list[dict[str, Any]] = []
    try:
        for index, raw in enumerate(raw_items):
            if not isinstance(raw, dict):
                raise ValueError("Todos los elementos del manifiesto deben ser objetos.")
            file_name = str(raw.get("file") or "")
            if not file_name or Path(file_name).name != file_name or not file_name.lower().endswith(".png"):
                raise ValueError("Cada prenda debe usar un nombre PNG simple, sin rutas.")
            source_file = source / file_name
            errors: list[str] = []
            digest = ""
            if not source_file.is_file():
                errors.append("No se encuentra el archivo PNG.")
            else:
                digest = hashlib.sha256(source_file.read_bytes()).hexdigest()
                if not _png_has_transparency(source_file):
                    errors.append("El PNG no contiene transparencia válida.")
                else:
                    shutil.copy2(source_file, destination / file_name)
            staged.append({
                "id": str(raw.get("id") or f"import-{index}"),
                "fileName": file_name,
                "name": str(raw.get("name") or f"Prenda {index + 1}"),
                "category": str(raw.get("category") or "Sin categoría"),
                "imageSha256": digest,
                "colors": [str(value) for value in raw.get("colors", [])],
                "material": str(raw.get("material") or ""),
                "seasons": [str(value) for value in raw.get("seasons", [])],
                "occasions": [str(value) for value in raw.get("occasions", [])],
                "tags": [str(value) for value in raw.get("tags", [])],
                "confidence": str(raw.get("confidence") or "media"),
                "sourceReferences": [str(value) for value in raw.get("sourceReferences", [])],
                "errors": errors,
                "duplicateItemId": existing.get(digest),
            })
        shutil.copy2(manifest, destination / "manifest.json")
        batch = {
            "id": batch_id,
            "name": str(payload.get("name") or "Importación de ropa"),
            "createdAt": server.now_iso(),
            "status": "pending",
            "items": staged,
            "errorMessage": "",
        }
        state.setdefault("wardrobeImportBatches", []).append(batch)
        server.save_state(state)
        return batch
    except Exception:
        shutil.rmtree(destination, ignore_errors=True)
        raise


def list_wardrobe_batches_impl(arguments: dict[str, Any]) -> list[dict[str, Any]]:
    batches = server.load_state().get("wardrobeImportBatches", [])
    status = str(arguments.get("status") or "")
    return [batch for batch in batches if not status or batch.get("status") == status]


def get_wardrobe_batch_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    _index, batch = server.find_by_id(server.load_state().get("wardrobeImportBatches", []), arguments["batch_id"], "lote")
    return batch


def list_wardrobe_items_impl(arguments: dict[str, Any]) -> list[dict[str, Any]]:
    items = server.load_state().get("wardrobeItems", [])
    return items if arguments.get("include_archived") else [item for item in items if not item.get("archived", False)]


def create_wardrobe_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    instant = server.now_iso()
    item = {
        "id": server.make_id("wardrobe-item"), "name": str(arguments["name"]).strip(),
        "category": str(arguments["category"]).strip(), "imagePath": "", "thumbnailPath": "",
        "imageSha256": "", "colors": arguments.get("colors", []), "material": arguments.get("material", ""),
        "seasons": arguments.get("seasons", []), "occasions": arguments.get("occasions", []), "tags": arguments.get("tags", []),
        "favorite": bool(arguments.get("favorite", False)), "archived": bool(arguments.get("archived", False)),
        "laundryStatus": arguments.get("laundry_status", "available"), "useCount": 0, "lastUsedAt": None,
        "price": arguments.get("price"), "createdAt": instant, "updatedAt": instant,
    }
    state.setdefault("wardrobeItems", []).append(item)
    server.save_state(state)
    return item


def update_wardrobe_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    index, item = server.find_by_id(state.setdefault("wardrobeItems", []), arguments["item_id"], "prenda")
    mapping = {"name": "name", "category": "category", "colors": "colors", "material": "material", "seasons": "seasons",
               "occasions": "occasions", "tags": "tags", "price": "price", "favorite": "favorite", "archived": "archived",
               "laundry_status": "laundryStatus"}
    for source, target in mapping.items():
        if source in arguments:
            item[target] = arguments[source]
    item["updatedAt"] = server.now_iso()
    state["wardrobeItems"][index] = item
    server.save_state(state)
    return item


def delete_wardrobe_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    server.require_confirm(arguments, "delete_wardrobe_item")
    state = server.load_state()
    item_id = arguments["item_id"]
    index, item = server.find_by_id(state.setdefault("wardrobeItems", []), item_id, "prenda")
    state["wardrobeItems"].pop(index)
    for outfit in state.setdefault("wardrobeOutfits", []):
        outfit["itemIds"] = [value for value in outfit.get("itemIds", []) if value != item_id]
    state["wardrobePlanEntries"] = [entry for entry in state.setdefault("wardrobePlanEntries", []) if entry.get("itemIds") != [item_id]]
    for packing in state.setdefault("wardrobePackingLists", []):
        packing["entries"] = [entry for entry in packing.get("entries", []) if entry.get("itemId") != item_id]
    server.save_state(state)
    return item


def create_wardrobe_outfit_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    valid = {item.get("id") for item in state.setdefault("wardrobeItems", [])}
    outfit = {"id": server.make_id("wardrobe-outfit"), "name": str(arguments["name"]).strip(),
              "itemIds": list(dict.fromkeys(value for value in arguments["item_ids"] if value in valid)),
              "occasion": arguments.get("occasion", ""), "tags": arguments.get("tags", []),
              "renderImagePath": "", "createdAt": server.now_iso()}
    state.setdefault("wardrobeOutfits", []).append(outfit)
    server.save_state(state)
    return outfit


def list_wardrobe_outfits_impl(_arguments: dict[str, Any]) -> list[dict[str, Any]]:
    return server.load_state().setdefault("wardrobeOutfits", [])


def update_wardrobe_outfit_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    index, outfit = server.find_by_id(
        state.setdefault("wardrobeOutfits", []), arguments["outfit_id"], "conjunto"
    )
    if "name" in arguments:
        outfit["name"] = str(arguments["name"]).strip() or "Conjunto sin nombre"
    if "occasion" in arguments:
        outfit["occasion"] = str(arguments["occasion"]).strip()
    if "tags" in arguments:
        outfit["tags"] = list(dict.fromkeys(str(value).strip() for value in arguments["tags"] if str(value).strip()))
    previous_render = ""
    if "item_ids" in arguments:
        valid = {item.get("id") for item in state.setdefault("wardrobeItems", [])}
        item_ids = list(dict.fromkeys(value for value in arguments["item_ids"] if value in valid))
        if not item_ids:
            raise ValueError("Un conjunto debe contener al menos una prenda.")
        if set(item_ids) != set(outfit.get("itemIds", [])):
            previous_render = str(outfit.get("renderImagePath") or "")
            outfit["renderImagePath"] = ""
        outfit["itemIds"] = item_ids
    state["wardrobeOutfits"][index] = outfit
    server.save_state(state)
    if previous_render:
        directory = (server.wardrobe_directory() / "outfits").resolve()
        old_path = (server.wardrobe_directory() / previous_render).resolve()
        if old_path.parent == directory:
            old_path.unlink(missing_ok=True)
    return outfit


def set_wardrobe_outfit_render_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    source = Path(str(arguments["source_file"])).expanduser().resolve()
    if not source.is_file() or source.suffix.lower() != ".png":
        raise ValueError("El render debe ser un archivo PNG local.")
    data = source.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n") or len(data) < 33:
        raise ValueError("El render no es un PNG válido.")
    width, height = struct.unpack(">II", data[16:24])
    if width < 600 or height < 600:
        raise ValueError("El render debe medir al menos 600 × 600 píxeles.")
    state = server.load_state()
    index, outfit = server.find_by_id(
        state.setdefault("wardrobeOutfits", []), arguments["outfit_id"], "conjunto"
    )
    digest = hashlib.sha256(data).hexdigest()
    directory = server.wardrobe_directory() / "outfits"
    directory.mkdir(parents=True, exist_ok=True)
    file_name = f"{re.sub(r'[^a-zA-Z0-9_-]', '-', str(outfit['id']))}-{digest[:12]}.png"
    destination = directory / file_name
    if not destination.exists():
        temporary = destination.with_suffix(".tmp")
        try:
            temporary.write_bytes(data)
            temporary.replace(destination)
        except Exception:
            temporary.unlink(missing_ok=True)
            raise
    previous = str(outfit.get("renderImagePath") or "")
    outfit["renderImagePath"] = f"outfits/{file_name}"
    state["wardrobeOutfits"][index] = outfit
    try:
        server.save_state(state)
    except Exception:
        if previous != outfit["renderImagePath"]:
            destination.unlink(missing_ok=True)
        raise
    if previous and previous != outfit["renderImagePath"]:
        old_path = (server.wardrobe_directory() / previous).resolve()
        if old_path.parent == directory.resolve():
            old_path.unlink(missing_ok=True)
    return outfit


def record_wardrobe_wear_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    item_ids = list(dict.fromkeys(arguments["item_ids"]))
    log = {"id": server.make_id("wardrobe-wear"), "date": server.parse_datetime(arguments["date"]).isoformat(),
           "itemIds": item_ids, "outfitId": arguments.get("outfit_id"), "label": arguments.get("label", "")}
    state.setdefault("wardrobeWearLogs", []).append(log)
    for item in state.setdefault("wardrobeItems", []):
        if item.get("id") in item_ids:
            item["useCount"] = int(item.get("useCount", 0)) + 1
            item["lastUsedAt"] = log["date"]
            item["updatedAt"] = server.now_iso()
    server.save_state(state)
    return log


def set_wardrobe_laundry_status_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    status = arguments["status"]
    if status not in {"available", "toWash", "washing", "drying"}:
        raise ValueError("Estado de lavandería no válido.")
    state = server.load_state()
    ids = set(arguments["item_ids"])
    changed = 0
    for item in state.setdefault("wardrobeItems", []):
        if item.get("id") in ids:
            item["laundryStatus"] = status
            item["updatedAt"] = server.now_iso()
            changed += 1
    server.save_state(state)
    return {"updated": changed, "status": status}


def set_wardrobe_plan_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    date = server.parse_datetime(arguments["date"])
    date_key = date.date().isoformat()
    state["wardrobePlanEntries"] = [entry for entry in state.setdefault("wardrobePlanEntries", []) if not str(entry.get("date", "")).startswith(date_key)]
    entry = {"id": server.make_id("wardrobe-plan"), "date": date.isoformat(), "itemIds": arguments["item_ids"],
             "outfitId": arguments.get("outfit_id"), "weather": arguments.get("weather", "mild"), "occasion": arguments.get("occasion", "")}
    state["wardrobePlanEntries"].append(entry)
    server.save_state(state)
    return entry


def create_wardrobe_packing_list_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    packing = {"id": server.make_id("wardrobe-packing"), "name": arguments["name"],
               "startDate": server.parse_datetime(arguments["start_date"]).isoformat(),
               "endDate": server.parse_datetime(arguments["end_date"]).isoformat(), "entries": []}
    state.setdefault("wardrobePackingLists", []).append(packing)
    server.save_state(state)
    return packing


def add_wardrobe_packing_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    index, packing = server.find_by_id(state.setdefault("wardrobePackingLists", []), arguments["packing_list_id"], "maleta")
    item_id = arguments["item_id"]
    server.find_by_id(state.setdefault("wardrobeItems", []), item_id, "prenda")
    packing["entries"] = [entry for entry in packing.get("entries", []) if entry.get("itemId") != item_id]
    packing["entries"].append({"itemId": item_id, "quantity": max(1, int(arguments.get("quantity", 1))), "packed": False})
    state["wardrobePackingLists"][index] = packing
    server.save_state(state)
    return packing


WARDROBE_CATEGORIES = [
    "Camisetas", "Camisas", "Pantalones", "Vaqueros", "Pantalones cortos",
    "Calzado", "Sudaderas", "Jerséis y cárdigans", "Chaquetas", "Abrigos",
    "Polos", "Vestidos", "Faldas", "Ropa interior", "Pijamas", "Bañadores",
    "Trajes y americanas", "Chalecos", "Monos", "Accesorios", "Otros",
]


WARDROBE_COLORS = [
    "negro", "blanco", "gris", "azul", "azul marino", "celeste", "verde",
    "verde oliva", "rojo", "granate", "rosa", "morado", "lila", "amarillo",
    "naranja", "beige", "crema", "marrón", "dorado", "plateado", "multicolor",
]


WARDROBE_SEASONS = ["todo el año", "primavera", "verano", "otoño", "invierno"]


WARDROBE_OCCASIONS = [
    "diario", "informal", "trabajo", "formal", "fiesta", "deporte", "casa",
    "viaje", "playa",
]


WARDROBE_CATEGORY_ALIASES = {
    "camiseta": "Camisetas", "t-shirt": "Camisetas", "t-shirts": "Camisetas",
    "tee": "Camisetas", "camisa": "Camisas", "pantalón": "Pantalones",
    "jean": "Vaqueros", "jeans": "Vaqueros", "vaquero": "Vaqueros",
    "bermuda": "Pantalones cortos", "bermudas": "Pantalones cortos",
    "short": "Pantalones cortos", "shorts": "Pantalones cortos",
    "zapatilla": "Calzado", "zapatillas": "Calzado", "zapato": "Calzado",
    "zapatos": "Calzado", "bota": "Calzado", "botas": "Calzado",
    "sudadera": "Sudaderas", "hoodie": "Sudaderas",
    "jersey": "Jerséis y cárdigans", "jerseys": "Jerséis y cárdigans",
    "suéter": "Jerséis y cárdigans", "cárdigan": "Jerséis y cárdigans",
    "chaqueta": "Chaquetas", "jacket": "Chaquetas", "jackets": "Chaquetas",
    "cazadora": "Chaquetas", "bomber": "Chaquetas", "abrigo": "Abrigos",
    "parka": "Abrigos", "polo": "Polos", "vestido": "Vestidos",
    "falda": "Faldas", "pijama": "Pijamas", "bañador": "Bañadores",
    "traje": "Trajes y americanas", "americana": "Trajes y americanas",
    "chaleco": "Chalecos", "mono": "Monos", "accesorio": "Accesorios",
    "otro": "Otros",
}


WARDROBE_COLOR_ALIASES = {
    "burdeos": "granate", "borgoña": "granate", "lavanda": "lila",
    "oliva": "verde oliva", "gris carbón": "gris", "gris carbon": "gris",
    "caramelo": "marrón", "taupe": "marrón",
}


def _wardrobe_key(value: Any) -> str:
    return str(value or "").strip().lower()


def _canonical_wardrobe_category(value: Any) -> str:
    key = _wardrobe_key(value)
    for category in WARDROBE_CATEGORIES:
        if _wardrobe_key(category) == key:
            return category
    singular = WARDROBE_CATEGORY_ALIASES.get(key)
    if singular:
        return singular
    if key.endswith("s"):
        singular = WARDROBE_CATEGORY_ALIASES.get(key[:-1])
        if singular:
            return singular
    raise ValueError(
        f"Categoría no reconocida: {value}. Usa una categoría canónica o 'Otros'."
    )


def _canonical_wardrobe_values(
    values: Any,
    allowed: list[str],
    aliases: dict[str, str] | None = None,
) -> list[str]:
    result: list[str] = []
    seen: set[str] = set()
    for raw in values or []:
        key = _wardrobe_key(raw)
        canonical = (aliases or {}).get(key)
        if canonical is None:
            canonical = next((item for item in allowed if _wardrobe_key(item) == key), None)
        if canonical is None:
            raise ValueError(f"Valor de clasificación no reconocido: {raw}.")
        if canonical not in seen:
            seen.add(canonical)
            result.append(canonical)
    return result


def _wardrobe_catalog_target(category: str) -> tuple[float, float]:
    if category == "Calzado":
        return 0.86, 0.52
    if category == "Pantalones cortos":
        return 0.92, 0.72
    if category in {"Pantalones", "Vaqueros", "Faldas"}:
        return 0.76, 0.86
    if category == "Accesorios":
        return 0.68, 0.62
    return 0.90, 0.80


def _prepare_direct_wardrobe_asset(
    source: Path,
    item_id: str,
    category: str,
) -> tuple[str, str, str, list[Path]]:
    if not source.is_file() or source.suffix.lower() not in {".png", ".jpg", ".jpeg", ".webp"}:
        raise ValueError("La imagen debe ser PNG, JPG, JPEG o WebP.")
    if server.Image is None or server.ImageOps is None:
        if source.suffix.lower() != ".png" or not _png_has_transparency(source):
            raise RuntimeError("Esta instalación necesita Pillow para procesar la imagen.")
        image_bytes = source.read_bytes()
        thumbnail_bytes = image_bytes
    else:
        with server.Image.open(source) as opened:
            prepared = server.ImageOps.exif_transpose(opened).convert("RGBA")
        alpha = prepared.getchannel("A")
        if alpha.getextrema()[0] < 255:
            visible = alpha.point(lambda value: 255 if value > 8 else 0)
            bounds = visible.getbbox()
            if bounds is None:
                raise ValueError("La imagen no contiene píxeles visibles.")
            prepared = prepared.crop(bounds)
            target_width, target_height = _wardrobe_catalog_target(category)
            scale = min(1200 * target_width / prepared.width, 1200 * target_height / prepared.height)
            size = (max(1, round(prepared.width * scale)), max(1, round(prepared.height * scale)))
            prepared = prepared.resize(size, server.Image.Resampling.LANCZOS)
            canvas = server.Image.new("RGBA", (1200, 1200), (0, 0, 0, 0))
            canvas.alpha_composite(prepared, ((1200 - size[0]) // 2, (1200 - size[1]) // 2))
            prepared = canvas
        else:
            longest = max(prepared.size)
            if longest > 2000:
                scale = 2000 / longest
                prepared = prepared.resize(
                    (max(1, round(prepared.width * scale)), max(1, round(prepared.height * scale))),
                    server.Image.Resampling.LANCZOS,
                )
        image_buffer = io.BytesIO()
        prepared.save(image_buffer, format="PNG", compress_level=6)
        image_bytes = image_buffer.getvalue()
        thumbnail = prepared.copy()
        thumbnail.thumbnail((420, 420), server.Image.Resampling.LANCZOS)
        thumbnail_buffer = io.BytesIO()
        thumbnail.save(thumbnail_buffer, format="PNG", compress_level=6)
        thumbnail_bytes = thumbnail_buffer.getvalue()

    digest = hashlib.sha256(image_bytes).hexdigest()
    safe_id = re.sub(r"[^a-zA-Z0-9_-]", "-", item_id)
    stem = f"{safe_id}-{digest[:12]}"
    root = server.wardrobe_directory()
    items = root / "items"
    thumbnails = root / "thumbnails"
    items.mkdir(parents=True, exist_ok=True)
    thumbnails.mkdir(parents=True, exist_ok=True)
    image_file = items / f"{stem}.png"
    thumbnail_file = thumbnails / f"{stem}.png"
    created: list[Path] = []
    for destination, contents in ((image_file, image_bytes), (thumbnail_file, thumbnail_bytes)):
        temporary = destination.with_suffix(".tmp")
        temporary.write_bytes(contents)
        temporary.replace(destination)
        created.append(destination)
    return f"items/{stem}.png", f"thumbnails/{stem}.png", digest, created


def import_wardrobe_item_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    request_id = re.sub(r"[^a-zA-Z0-9_-]", "-", str(arguments["request_id"]).strip())
    if not request_id:
        raise ValueError("request_id no puede estar vacío.")
    receipts = server.RUNTIME_DIR / "wardrobe_import_receipts"
    receipts.mkdir(parents=True, exist_ok=True)
    receipt_path = receipts / f"{request_id}.json"
    if receipt_path.exists():
        return json.loads(receipt_path.read_text(encoding="utf-8"))

    initial_state = server.read_local_state()
    repeated = next(
        (
            item
            for item in initial_state.get("wardrobeItems", [])
            if item.get("importRequestId") == request_id
        ),
        None,
    )
    if repeated is not None:
        return {
            "requestId": request_id,
            "created": False,
            "item": repeated,
            "savedLocally": True,
            "syncPending": True,
        }

    category = _canonical_wardrobe_category(arguments["category"])
    colors = _canonical_wardrobe_values(
        arguments.get("colors", []), WARDROBE_COLORS, WARDROBE_COLOR_ALIASES
    )
    seasons = _canonical_wardrobe_values(arguments.get("seasons", []), WARDROBE_SEASONS)
    occasions = _canonical_wardrobe_values(arguments.get("occasions", []), WARDROBE_OCCASIONS)
    source = Path(str(arguments["source_file"])).expanduser().resolve()
    item_id = server.make_id("wardrobe-item")
    created_files: list[Path] = []
    state_saved = False
    try:
        image_path, thumbnail_path, digest, created_files = _prepare_direct_wardrobe_asset(
            source, item_id, category
        )
        state = server.read_local_state()
        instant = server.now_iso()
        item = {
            "id": item_id,
            "name": str(arguments["name"]).strip() or "Prenda sin nombre",
            "category": category,
            "imagePath": image_path,
            "thumbnailPath": thumbnail_path,
            "imageSha256": digest,
            "colors": colors,
            "material": str(arguments.get("material") or "").strip(),
            "seasons": seasons,
            "occasions": occasions,
            "tags": list(dict.fromkeys(str(value).strip() for value in arguments.get("tags", []) if str(value).strip())),
            "favorite": bool(arguments.get("favorite", False)),
            "archived": False,
            "laundryStatus": str(arguments.get("laundry_status") or "available"),
            "useCount": 0,
            "lastUsedAt": None,
            "price": arguments.get("price"),
            "createdAt": instant,
            "updatedAt": instant,
            "importRequestId": request_id,
        }
        state.setdefault("wardrobeItems", []).append(item)
        server.touch_state(state)
        if server.STATE_PATH.exists():
            shutil.copy2(server.STATE_PATH, server.STATE_PATH.with_suffix(".previous"))
        server.write_local_state(state)
        state_saved = True
        server.write_app_snapshot(state)
        server._mark_mcp_changes_pending()
        receipt = {
            "requestId": request_id,
            "created": True,
            "item": item,
            "savedLocally": True,
            "syncPending": True,
        }
        temporary_receipt = receipt_path.with_suffix(".tmp")
        temporary_receipt.write_text(
            json.dumps(receipt, indent=2, ensure_ascii=False), encoding="utf-8"
        )
        temporary_receipt.replace(receipt_path)
        return receipt
    except Exception:
        if not state_saved:
            for path in created_files:
                path.unlink(missing_ok=True)
        raise


def _delete_wardrobe_asset(relative_path: str) -> None:
    if not relative_path:
        return
    root = server.wardrobe_directory().resolve()
    candidate = (root / relative_path).resolve()
    if root not in candidate.parents:
        return
    try:
        candidate.unlink(missing_ok=True)
    except OSError:
        pass


def set_wardrobe_item_image_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    request_id = re.sub(
        r"[^a-zA-Z0-9_-]", "-", str(arguments["request_id"]).strip()
    )
    if not request_id:
        raise ValueError("request_id no puede estar vacío.")
    item_id = str(arguments["item_id"]).strip()
    receipts = server.RUNTIME_DIR / "wardrobe_image_update_receipts"
    receipts.mkdir(parents=True, exist_ok=True)
    receipt_path = receipts / f"{request_id}.json"
    if receipt_path.exists():
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
        if receipt.get("item", {}).get("id") != item_id:
            raise ValueError("request_id ya pertenece a otra prenda.")
        return receipt

    initial_state = server.read_local_state()
    _initial_index, initial_item = server.find_by_id(
        initial_state.setdefault("wardrobeItems", []), item_id, "prenda"
    )
    previous_paths = {
        str(initial_item.get("imagePath") or ""),
        str(initial_item.get("thumbnailPath") or ""),
    }
    previous_files = {
        (server.wardrobe_directory() / path).resolve()
        for path in previous_paths
        if path
    }
    source = Path(str(arguments["source_file"])).expanduser().resolve()
    created_files: list[Path] = []
    state_saved = False
    try:
        image_path, thumbnail_path, digest, created_files = (
            _prepare_direct_wardrobe_asset(
                source,
                item_id,
                _canonical_wardrobe_category(initial_item.get("category", "Otros")),
            )
        )
        state = server.read_local_state()
        index, item = server.find_by_id(
            state.setdefault("wardrobeItems", []), item_id, "prenda"
        )
        item = copy.deepcopy(item)
        item["imagePath"] = image_path
        item["thumbnailPath"] = thumbnail_path
        item["imageSha256"] = digest
        item["updatedAt"] = server.now_iso()
        state["wardrobeItems"][index] = item
        server.touch_state(state)
        if server.STATE_PATH.exists():
            shutil.copy2(server.STATE_PATH, server.STATE_PATH.with_suffix(".previous"))
        server.write_local_state(state)
        state_saved = True
        server.write_app_snapshot(state)
        server._mark_mcp_changes_pending()
        receipt = {
            "requestId": request_id,
            "item": item,
            "savedLocally": True,
            "syncPending": True,
        }
        temporary_receipt = receipt_path.with_suffix(".tmp")
        temporary_receipt.write_text(
            json.dumps(receipt, indent=2, ensure_ascii=False), encoding="utf-8"
        )
        temporary_receipt.replace(receipt_path)
        for previous_path in previous_paths:
            if previous_path not in {image_path, thumbnail_path}:
                _delete_wardrobe_asset(previous_path)
        return receipt
    except Exception:
        if not state_saved:
            for path in created_files:
                if path.resolve() not in previous_files:
                    path.unlink(missing_ok=True)
        raise


__all__ = [
    "wardrobe_import_contract_impl",
    "_png_has_transparency",
    "stage_wardrobe_batch_impl",
    "list_wardrobe_batches_impl",
    "get_wardrobe_batch_impl",
    "list_wardrobe_items_impl",
    "create_wardrobe_item_impl",
    "update_wardrobe_item_impl",
    "delete_wardrobe_item_impl",
    "create_wardrobe_outfit_impl",
    "list_wardrobe_outfits_impl",
    "update_wardrobe_outfit_impl",
    "set_wardrobe_outfit_render_impl",
    "record_wardrobe_wear_impl",
    "set_wardrobe_laundry_status_impl",
    "set_wardrobe_plan_impl",
    "create_wardrobe_packing_list_impl",
    "add_wardrobe_packing_item_impl",
    "WARDROBE_CATEGORIES",
    "WARDROBE_COLORS",
    "WARDROBE_SEASONS",
    "WARDROBE_OCCASIONS",
    "WARDROBE_CATEGORY_ALIASES",
    "WARDROBE_COLOR_ALIASES",
    "_wardrobe_key",
    "_canonical_wardrobe_category",
    "_canonical_wardrobe_values",
    "_wardrobe_catalog_target",
    "_prepare_direct_wardrobe_asset",
    "import_wardrobe_item_impl",
    "_delete_wardrobe_asset",
    "set_wardrobe_item_image_impl",
]
