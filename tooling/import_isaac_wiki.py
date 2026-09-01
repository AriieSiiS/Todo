"""Importa la wiki curada de Repentance+ en la Biblioteca local de Todo.

El proceso es reproducible: exporta un ZIP antes de tocar la ficha, usa claves
externas estables y deja que KnowledgeRepository aplique el árbol en una sola
transacción. No lee ni copia partidas guardadas.
"""

from __future__ import annotations

import hashlib
import html
import json
import re
import sqlite3
import sys
import uuid
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "mcp_server"))
from knowledge_repository import KnowledgeRepository  # noqa: E402

DATASET = Path(r"C:\Users\aries\Documents\Codex\2026-07-22\go\outputs\isaac_wiki_dataset")
GUIDE = DATASET.parent / "guia_optima_desbloqueos_isaac.md"
KNOWLEDGE = Path(r"C:\Users\aries\Documents\Todo\knowledge")
SOURCE_NAME = "Binding of Isaac: Rebirth Wiki"
SOURCE_BASE = "https://bindingofisaacrebirth.wiki.gg/"
SNAPSHOT = "2026-07-22"
TRANSLATION_CACHE = KNOWLEDGE / "import_cache" / "isaac_es_translations.json"
TRANSLATIONS: dict[str, str] = (
    json.loads(TRANSLATION_CACHE.read_text(encoding="utf-8"))
    if TRANSLATION_CACHE.is_file()
    else {}
)

CHARACTER_ORDER = [
    "Isaac", "Magdalene", "Cain", "Judas", "???", "Eve", "Samson",
    "Azazel", "Lazarus", "Eden", "The Lost", "Lilith", "Keeper",
    "Apollyon", "The Forgotten", "Bethany", "Jacob & Esau",
    "Tainted Isaac", "Tainted Magdalene", "Tainted Cain", "Tainted Judas",
    "Tainted ???", "Tainted Eve", "Tainted Samson", "Tainted Azazel",
    "Tainted Lazarus", "Tainted Eden", "Tainted Lost", "Tainted Lilith",
    "Tainted Keeper", "Tainted Apollyon", "Tainted Forgotten",
    "Tainted Bethany", "Tainted Jacob",
]
MARKS = [
    ("Mom's Heart / It Lives", "heart"), ("Isaac", "isaac"),
    ("Satan", "satan"), ("???", "blue baby"), ("The Lamb", "lamb"),
    ("Boss Rush", "boss rush"), ("Hush", "hush"),
    ("Mega Satan", "mega satan"), ("Greed / Greedier", "greed"),
    ("Delirium", "delirium"), ("Mother", "mother"), ("The Beast", "beast"),
]


def load(name: str) -> Any:
    return json.loads((DATASET / "data" / name).read_text(encoding="utf-8"))


def slug(value: str) -> str:
    text = value.lower().replace("???", "blue-baby")
    text = re.sub(r"[^a-z0-9]+", "-", text).strip("-")
    return text or hashlib.sha256(value.encode()).hexdigest()[:12]


def clean(value: Any) -> str:
    text = html.unescape(str(value or ""))
    text = re.sub(r"<[^>]+>", " ", text)
    text = re.sub(r"\[\[File:[^\]]+\]\]", " ", text, flags=re.I)
    text = re.sub(r"\[\[[^\]|]+\|([^\]]+)\]\]", r"\1", text)
    text = re.sub(r"\[\[([^\]]+)\]\]", r"\1", text)
    text = re.sub(r"\{\{[^{}]*\}\}", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def spanish(value: Any) -> str:
    text = clean(value)
    translated = TRANSLATIONS.get(text)
    if translated:
        return translated
    replacements = [
        (r"^When used,?", "Al usarlo,"), (r"^When picked up,?", "Al recogerlo,"),
        (r"^Upon use,?", "Al usarlo,"), (r"^Upon pickup,?", "Al recogerlo,"),
        (r"^Spawns?", "Genera"), (r"^Grants?", "Otorga"),
        (r"^Gives?", "Otorga"), (r"^Increases?", "Aumenta"),
        (r"^Decreases?", "Reduce"), (r"^Transforms?", "Transforma"),
        (r"\bIsaac's\b", "de Isaac"), (r"\bIsaac\b", "Isaac"),
        (r"\benemies\b", "enemigos"), (r"\benemy\b", "enemigo"),
        (r"\btears\b", "lágrimas"), (r"\btear\b", "lágrima"),
        (r"\bdamage\b", "daño"), (r"\bhealth\b", "salud"),
        (r"\bhearts\b", "corazones"), (r"\bheart\b", "corazón"),
        (r"\bcoins\b", "monedas"), (r"\bkeys\b", "llaves"),
        (r"\bbombs\b", "bombas"), (r"\brooms\b", "salas"),
        (r"\broom\b", "sala"), (r"\bfloor\b", "piso"),
        (r"\bchance\b", "probabilidad"), (r"\bactive item\b", "objeto activo"),
        (r"\bpassive item\b", "objeto pasivo"), (r"\bfor the current room\b", "durante la sala actual"),
        (r"\bfor the rest of the floor\b", "durante el resto del piso"),
    ]
    for pattern, replacement in replacements:
        text = re.sub(pattern, replacement, text, flags=re.I)
    return text or "La fuente no proporciona una descripción breve para esta entrada."


def external(kind: str, name: Any) -> str:
    return f"isaac:{kind}:{slug(str(name))}"


def block_id(key: str) -> str:
    return str(uuid.uuid5(uuid.NAMESPACE_URL, f"todo-isaac:{key}"))


def managed(node: dict[str, Any], key: str) -> dict[str, Any]:
    data = node.setdefault("data", {})
    data["knowledgeBlockId"] = block_id(key)
    data["managedKey"] = key
    comparable = json.loads(json.dumps(node, ensure_ascii=False))
    comparable["data"].pop("generationHash", None)
    data["generationHash"] = hashlib.sha256(
        json.dumps(comparable, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()
    return node


def paragraph(text: str, key: str, links: dict[str, str] | None = None) -> dict[str, Any]:
    operations: list[dict[str, Any]] = []
    if links:
        positions: list[tuple[int, int, str]] = []
        lower = text.lower()
        for label, target in sorted(links.items(), key=lambda item: len(item[0]), reverse=True):
            if len(label) < 3:
                continue
            start = lower.find(label.lower())
            if start >= 0 and not any(start < end and start + len(label) > begin for begin, end, _ in positions):
                positions.append((start, start + len(label), target))
        cursor = 0
        for start, end, target in sorted(positions):
            if start > cursor:
                operations.append({"insert": text[cursor:start]})
            operations.append({"insert": text[start:end], "attributes": {"href": f"knowledge://external/{target}"}})
            cursor = end
        if cursor < len(text):
            operations.append({"insert": text[cursor:]})
    if not operations:
        operations = [{"insert": text}]
    return managed({"type": "paragraph", "data": {"delta": operations}}, key)


def heading(text: str, level: int, key: str) -> dict[str, Any]:
    return managed({"type": "heading", "data": {"level": level, "delta": [{"insert": text}]}}, key)


def media(asset_key: str, key: str) -> dict[str, Any]:
    return managed({"type": "knowledgeMedia", "data": {
        "knowledgeAssetExternalKey": asset_key, "knowledgeKind": "image",
        "knowledgeImageWidth": 128, "knowledgeImageAlignment": "start",
    }}, key)


def page_link(target: str, key: str) -> dict[str, Any]:
    return managed({"type": "knowledgePage", "data": {"knowledgeTargetExternalKey": target}}, key)


def progress(root_id: str, progress_key: str | None, label: str, key: str, *, readonly: bool = True,
             progress_keys: list[str] | None = None, target: str | None = None,
             reward: str | None = None, minimum: int | None = None) -> dict[str, Any]:
    data: dict[str, Any] = {
        "knowledgeRootPageId": root_id,
        "knowledgeProgressLabel": label, "knowledgeProgressReadOnly": readonly,
    }
    resolved_keys = list(dict.fromkeys(progress_keys or ([] if progress_key is None else [progress_key])))
    if len(resolved_keys) == 1:
        data["knowledgeProgressKey"] = resolved_keys[0]
    elif resolved_keys:
        data["knowledgeProgressKeys"] = resolved_keys
    if minimum is not None:
        data["knowledgeProgressMinimum"] = minimum
    if target:
        data["knowledgeTargetExternalKey"] = target
    if reward:
        data["knowledgeRewardExternalKey"] = reward
    return managed({"type": "knowledgeProgress", "data": data}, key)


def character_style(article: dict[str, Any], name: str) -> str:
    """Quita la cabecera de navegación que la wiki incrusta en algunas fichas."""
    text = spanish(article.get("page_description"))
    navigation_prefixes = (
        "Characters Isaac Magdalene Cain Judas ??? Eve Samson Azazel Lazarus Eden The Lost Lilith Keeper Apollyon The Forgotten Bethany Jacob and Esau ",
        "Tainted Characters Tainted Isaac Tainted Magdalene Tainted Cain Tainted Judas Tainted ??? Tainted Eve Tainted Samson Tainted Azazel Tainted Lazarus Tainted Eden Tainted Lost Tainted Lilith Tainted Keeper Tainted Apollyon Tainted Forgotten Tainted Bethany Tainted Jacob ",
    )
    for prefix in navigation_prefixes:
        if text.startswith(prefix):
            text = text[len(prefix):].lstrip()
            break
    markers = (f"{name} es", f"{name} son", f"{name} is", f"{name} comienza")
    positions = [text.find(marker) for marker in markers if text.find(marker) >= 0]
    if positions:
        text = text[min(positions):]
    if len(text) > 1100:
        boundary = text.rfind(". ", 0, 1100)
        text = text[:boundary + 1 if boundary > 450 else 1100].rstrip()
    return text


def character_health(value: Any) -> str:
    text = clean(value)
    if not text:
        return "Salud inicial especial"
    labels = {
        "red": "corazones rojos", "soul": "corazones de alma",
        "black": "corazones negros", "bone": "corazones de hueso",
        "broken": "corazones rotos",
    }
    parts: list[str] = []
    for kind, amount in re.findall(r"([a-z]+)\s*=\s*([0-9.]+)", text.lower()):
        rendered = str(float(amount)).rstrip("0").rstrip(".") if "." in amount else amount
        parts.append(f"{rendered} {labels.get(kind, kind)}")
    return ", ".join(parts) if parts else spanish(text)


def document(children: list[dict[str, Any]]) -> dict[str, Any]:
    return {"document": {"type": "page", "children": children}}


def main() -> None:
    articles = load("articles.json")
    achievements = load("achievements.json")
    for achievement in achievements:
        match = re.match(r"\d+", str(achievement["id"]))
        if not match:
            raise RuntimeError(f"Achievement sin ID numérico: {achievement['id']}")
        achievement["id"] = int(match.group())
    for article in articles:
        unlock_id = article.get("unlock_achievement_id")
        if unlock_id not in (None, ""):
            match = re.match(r"\d+", str(unlock_id))
            article["unlock_achievement_id"] = int(match.group()) if match else None
    collectibles_enriched = load("collectibles_enriched.json")
    trinkets = load("trinkets_enriched.json")
    pickups = load("pickups_enriched.json")
    challenges = load("cargo/challenge.json")
    transformations = load("transformations_enriched.json")
    pool_catalog = load("pool_catalog.json")
    assets_data = load("assets.json")

    repository = KnowledgeRepository(KNOWLEDGE)
    with sqlite3.connect(repository.database_path) as db:
        row = db.execute(
            "SELECT p.id FROM knowledge_pages p JOIN knowledge_owner_links o ON o.page_id=p.id "
            "WHERE o.owner_type='libraryItem' AND lower(p.title) LIKE '%binding of isaac%' LIMIT 1"
        ).fetchone()
        if not row:
            raise RuntimeError("No existe la ficha de Isaac en Biblioteca.")
        root_id = row[0]
        guide_row = db.execute(
            "SELECT id FROM knowledge_pages WHERE parent_id=? AND title='Guía rápida: Isaac' LIMIT 1",
            (root_id,),
        ).fetchone()
    guide_id = guide_row[0] if guide_row else None
    backup = repository.export_archive()
    print(f"Backup: {backup['path']}")

    article_by_title = {item["title"]: item for item in articles}
    article_groups: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for item in articles:
        article_groups[item["group"]].append(item)
    asset_by_subject_group: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    asset_by_local: dict[str, dict[str, Any]] = {}
    for item in assets_data:
        asset_by_subject_group[(item.get("group", ""), item.get("subject", ""))].append(item)
        asset_by_local[item["local_path"]] = item

    enriched_collectible = {item["title"]: item for item in collectibles_enriched}
    def collectible_id(article: dict[str, Any]) -> int:
        # The structured collectible dataset is the canonical current-ID source.
        # Some shared wiki pages expose a trinket ID in their generic infobox
        # fields (Tonsil is the known example).
        raw = enriched_collectible.get(article["title"], {}).get("id") or article.get("fields", {}).get("id")
        if raw is None:
            raise RuntimeError(f"Collectible sin ID: {article['title']}")
        return int(raw)
    pool_entries_by_item: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for relation in pool_catalog["entries"]:
        pool_entries_by_item[relation["collectible"]].append(relation)
    achievements_by_name: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for item in achievements:
        achievements_by_name[item["name"]].append(item)

    pages: list[dict[str, Any]] = []
    manifest_assets: dict[str, dict[str, Any]] = {}
    collections: list[dict[str, Any]] = []
    title_links: dict[str, str] = {}

    def add_asset(local_path: str | None, subject: str) -> str | None:
        if not local_path:
            return None
        path = DATASET / local_path
        if not path.is_file():
            return None
        key = "isaac-asset:" + hashlib.sha256(local_path.encode()).hexdigest()[:24]
        if key not in manifest_assets:
            meta = asset_by_local.get(local_path, {})
            manifest_assets[key] = {
                "externalKey": key, "path": str(path),
                "source_url": meta.get("url"),
                "source_page_url": meta.get("description_url"),
                "author": meta.get("artist") or meta.get("credit"),
                "alt_text": subject,
            }
        return key

    def article_asset(article: dict[str, Any], subject: str) -> str | None:
        paths = article.get("assets") or []
        preferred = next((p for p in paths if "icon" in p.lower() or "appearance" in p.lower() or "portrait" in p.lower()), None)
        return add_asset(preferred or (paths[0] if paths else None), subject)

    def data_asset(group: str, subject: str) -> str | None:
        rows = asset_by_subject_group.get((group, subject), [])
        preferred = next((row for row in rows if "icon" in row["name"].lower()), None)
        return add_asset((preferred or rows[0])["local_path"], subject) if rows else None

    def add_page(*, ext: str, title: str, parent: str | None, children: list[dict[str, Any]],
                 properties: dict[str, Any], icon: str, collection_id: str | None = None,
                 page_id: str | None = None, asset_key: str | None = None, sort_order: int = 0) -> None:
        page = {
            "externalKey": ext, "title": title, "icon": icon,
            "document": document(children), "properties": properties,
            "sortOrder": sort_order,
        }
        if parent:
            page["parentExternalKey"] = parent
        if page_id:
            page["pageId"] = page_id
        if collection_id:
            page["collectionId"] = collection_id
        if asset_key:
            page["coverAssetExternalKey"] = asset_key
        pages.append(page)
        title_links.setdefault(title, ext)

    root_ext = "isaac:root:repentance-plus"
    category_specs = [
        ("characters", "Personajes", "🧍"), ("collectibles", "Objetos", "🎲"),
        ("trinkets", "Trinkets", "📿"), ("pickups", "Cartas, runas y pickups", "🃏"),
        ("challenges", "Challenges", "🏁"), ("achievements", "Logros", "🏆"),
        ("bosses", "Jefes", "👹"), ("transformations", "Transformaciones", "✨"),
        ("pools", "Item pools", "🎰"),
    ]
    collection_ids = {
        key: "collection-" + hashlib.sha256(f"isaac:{key}".encode()).hexdigest()[:32]
        for key, _, _ in category_specs
    }

    root_children = [
        heading("Repentance+ para PC", 2, "root-version"),
        paragraph("Wiki interactiva en español. Los nombres oficiales se conservan en inglés y el progreso verificable se sincroniza en modo de solo lectura.", "root-intro"),
        managed({"type": "knowledgeProgress", "data": {
            "knowledgeRootPageId": root_id, "knowledgeProgressDisplay": "summary",
            "knowledgeProgressLabel": "Logros",
            "knowledgeProgressKeys": [f"isaac.achievement.{i}.unlocked" for i in range(1, 642)],
        }}, "root-achievements-summary"),
        managed({"type": "knowledgeProgress", "data": {
            "knowledgeRootPageId": root_id, "knowledgeProgressDisplay": "summary",
            "knowledgeProgressLabel": "Challenges",
            "knowledgeProgressKeys": [f"isaac.challenge.{i}.completed" for i in range(1, 46)],
        }}, "root-challenges-summary"),
        paragraph(f"Snapshot editorial: {SNAPSHOT}. Sin selector histórico ni vídeos.", "root-snapshot"),
    ]
    add_page(ext=root_ext, title="The Binding of Isaac: Rebirth", parent=None,
             children=root_children, properties={"isaacWiki": True, "version": "Repentance+", "snapshot": SNAPSHOT},
             icon="🌀", page_id=root_id)

    # Reserve category pages and collections before entity generation.
    for order, (key, label, icon) in enumerate(category_specs, 10):
        cat_ext = f"isaac:category:{key}"
        children = [heading(label, 2, f"cat-{key}-title"), managed({
            "type": "knowledgeCollection", "data": {
                "knowledgeCollectionExternalKey": f"isaac:collection:{key}",
                "knowledgeViewType": "gallery" if key not in {"pools", "achievements"} else "table",
            }}, f"cat-{key}-collection")]
        add_page(ext=cat_ext, title=label, parent=root_ext, children=children,
                 properties={"isaacCategory": key}, icon=icon, sort_order=order)
        collections.append({
            "externalKey": f"isaac:collection:{key}", "collectionId": collection_ids[key],
            "pageExternalKey": cat_ext, "name": label,
            "schema": [{"id": "isaacId", "name": "ID", "type": "number"},
                       {"id": "quality", "name": "Calidad", "type": "number"},
                       {"id": "unlocked", "name": "Desbloqueado", "type": "checkbox"}],
            "views": [{"id": "gallery", "type": "gallery", "name": "Galería"},
                      {"id": "table", "type": "table", "name": "Tabla"}],
        })

    # Achievements first so every other page can link its unlock requirement.
    for achievement in achievements:
        aid = int(achievement["id"])
        ext = f"isaac:achievement:{aid}"
        asset = article_asset(achievement, achievement["name"])
        children = []
        if asset:
            children.append(media(asset, f"achievement-{aid}-media"))
        children.extend([
            heading(f"Achievement #{aid}", 2, f"achievement-{aid}-id"),
            paragraph(f"Requisito: {spanish(achievement.get('requirements'))}", f"achievement-{aid}-requirement"),
            paragraph(f"Recompensa: {achievement['name']}. {spanish(achievement.get('description'))}", f"achievement-{aid}-reward"),
            progress(root_id, f"isaac.achievement.{aid}.unlocked", "Desbloqueado en la partida", f"achievement-{aid}-progress"),
            paragraph(f"Fuente: {SOURCE_NAME} · revisión {achievement.get('revision_id')} · {achievement.get('source_url')}", f"achievement-{aid}-source"),
        ])
        add_page(ext=ext, title=achievement["name"], parent="isaac:category:achievements",
                 children=children, properties={"isaacType": "achievement", "isaacId": aid,
                 "requirements": clean(achievement.get("requirements")), "sourceUrl": achievement.get("source_url"),
                 "sourceRevision": achievement.get("revision_id"), "attribution": SOURCE_NAME},
                 icon="🏆", collection_id=collection_ids["achievements"], asset_key=asset, sort_order=aid)

    # Collectibles.
    collectible_articles = article_groups["active_collectibles"] + article_groups["passive_collectibles"]
    collectible_articles.sort(key=collectible_id)
    collectible_ext_by_title: dict[str, str] = {}
    used_collectible_ids: set[int] = set()
    for article in collectible_articles:
        cid = collectible_id(article)
        ext = (
            f"isaac:collectible:{cid}"
            if cid not in used_collectible_ids
            else f"isaac:collectible:{cid}:{slug(article['title'])}"
        )
        used_collectible_ids.add(cid)
        collectible_ext_by_title[article["title"]] = ext
        enriched = enriched_collectible.get(article["title"], {})
        pools = [{"name": row["pool"], "weight": float(row.get("weight") or 1)} for row in pool_entries_by_item[article["title"]]]
        asset = article_asset(article, article["title"])
        active = article["group"] == "active_collectibles"
        children = []
        if asset:
            children.append(media(asset, f"collectible-{cid}-media"))
        children.extend([
            heading(f"Collectible #{cid}", 2, f"collectible-{cid}-id"),
            paragraph(f"Tipo: {'activo' if active else 'pasivo'} · calidad {article['fields'].get('quality', '—')}.", f"collectible-{cid}-type"),
            paragraph(f"Efecto: {spanish(article['fields'].get('description') or enriched.get('description'))}", f"collectible-{cid}-effect"),
            paragraph("Pools: " + (" · ".join(f"{p['name']} (peso {p['weight']:g})" for p in pools) or "sin pool de pedestal documentado"), f"collectible-{cid}-pools"),
            progress(root_id, f"isaac.collectible.{cid}.collected", "Recogido", f"collectible-{cid}-collected"),
        ])
        unlock_id = article.get("unlock_achievement_id")
        if unlock_id:
            children.append(progress(root_id, f"isaac.achievement.{unlock_id}.unlocked", "Desbloqueado", f"collectible-{cid}-unlocked", reward=f"isaac:achievement:{unlock_id}"))
        children.append(paragraph(f"Fuente: {SOURCE_NAME} · revisión {article['revision_id']} · {article['url']}", f"collectible-{cid}-source"))
        variants = enriched.get("variants", {})
        add_page(ext=ext, title=article["title"], parent="isaac:category:collectibles", children=children,
                 properties={"isaacType": "collectible", "isaacId": cid,
                     "quality": int(article["fields"].get("quality") or 0), "active": active,
                     "charge": variants.get("collectible_recharge", []), "shopPrice": variants.get("collectible_shop_price", []),
                     "devilPrice": variants.get("collectible_devil_price", []), "tags": variants.get("collectible_tag", []),
                     "pools": pools, "unlockAchievementId": unlock_id, "sourceUrl": article["url"],
                     "sourceRevision": article["revision_id"], "attribution": SOURCE_NAME},
                 icon="🎲", collection_id=collection_ids["collectibles"], asset_key=asset, sort_order=cid)

    # Trinkets.
    trinket_articles = {
        item["title"].replace(" (Trinket)", ""): item
        for item in article_groups["trinkets"]
    }
    for item in sorted(trinkets, key=lambda row: int(row["id"])):
        tid = int(item["id"])
        normalized_title = item["title"].replace(" (Trinket)", "")
        article = trinket_articles.get(normalized_title)
        if article is None:
            # A handful of current trinkets (notably Tonsil) share a wiki page
            # with a collectible and therefore have no standalone trinket
            # article in the editorial snapshot. Preserve the enriched row and
            # its trinket-specific asset instead of silently dropping the page.
            article = {
                "title": normalized_title,
                "fields": {},
                "assets": [],
                "unlock_achievement_id": None,
                "revision_id": None,
                "url": f"{SOURCE_BASE}/{normalized_title.replace(' ', '_')}",
            }
        ext = f"isaac:trinket:{tid}"
        asset = article_asset(article, item["title"]) or data_asset("trinkets", item["title"])
        variants = item.get("variants", {})
        children = ([media(asset, f"trinket-{tid}-media")] if asset else []) + [
            heading(f"Trinket #{tid}", 2, f"trinket-{tid}-id"),
            paragraph(f"Efecto: {spanish(article['fields'].get('description') or item.get('description'))}", f"trinket-{tid}-effect"),
            paragraph(f"Fuente: {SOURCE_NAME} · revisión {article['revision_id']} · {article['url']}", f"trinket-{tid}-source"),
        ]
        unlock_id = article.get("unlock_achievement_id")
        if unlock_id:
            children.insert(-1, progress(root_id, f"isaac.achievement.{unlock_id}.unlocked", "Desbloqueado", f"trinket-{tid}-unlocked", reward=f"isaac:achievement:{unlock_id}"))
        add_page(ext=ext, title=item["title"], parent="isaac:category:trinkets", children=children,
                 properties={"isaacType": "trinket", "isaacId": tid, "tags": variants.get("trinket_tag", []),
                     "unlockAchievementId": unlock_id, "sourceUrl": article["url"], "sourceRevision": article["revision_id"], "attribution": SOURCE_NAME},
                 icon="📿", collection_id=collection_ids["trinkets"], asset_key=asset, sort_order=tid)

    # Pickups, cards and runes.
    for order, item in enumerate(sorted(pickups, key=lambda row: (str(row.get("type")), int(row.get("id") or 0))), 1):
        pid = int(item.get("id") or order)
        ptype = clean(item.get("type") or "pickup")
        ext = f"isaac:pickup:{slug(ptype)}:{pid}"
        asset = data_asset("pickups", item["title"])
        children = ([media(asset, f"pickup-{order}-media")] if asset else []) + [
            heading(f"{ptype.title()} #{pid}", 2, f"pickup-{order}-id"),
            paragraph(f"Efecto: {spanish(item.get('description'))}", f"pickup-{order}-effect"),
            paragraph(f"Fuente: {SOURCE_NAME} · snapshot {SNAPSHOT} · {SOURCE_BASE}", f"pickup-{order}-source"),
        ]
        add_page(ext=ext, title=item["title"], parent="isaac:category:pickups", children=children,
                 properties={"isaacType": "pickup", "isaacId": pid, "pickupType": ptype,
                     "unlock": clean(item.get("unlocked by")), "sourceUrl": SOURCE_BASE, "attribution": SOURCE_NAME},
                 icon="🃏", collection_id=collection_ids["pickups"], asset_key=asset, sort_order=order)

    # Challenges.
    for item in sorted(challenges, key=lambda row: int(row["number"])):
        number = int(item["number"])
        ext = f"isaac:challenge:{number}"
        article = article_by_title.get(item["_pageName"])
        asset = article_asset(article, item["_pageName"]) if article else data_asset("challenges", item["_pageName"])
        reward_title = clean(item.get("unlocks"))
        reward_target = title_links.get(reward_title) or collectible_ext_by_title.get(reward_title)
        children = ([media(asset, f"challenge-{number}-media")] if asset else []) + [
            heading(f"Challenge #{number}", 2, f"challenge-{number}-id"),
            paragraph(f"Personaje: {clean(item.get('used character')) or 'según la configuración del challenge'}.", f"challenge-{number}-character"),
            paragraph(f"Reglas y restricciones: {spanish(item.get('description'))}", f"challenge-{number}-rules"),
            paragraph(f"Objetivo: {spanish(item.get('goal'))}", f"challenge-{number}-goal"),
            paragraph(f"Recompensa: {reward_title or 'desbloqueo asociado'}.", f"challenge-{number}-reward"),
            progress(root_id, f"isaac.challenge.{number}.completed", "Completado", f"challenge-{number}-progress", target=ext, reward=reward_target),
            paragraph(f"Consejo: prioriza control de vida y recursos; adapta la ruta a las restricciones fijas antes de buscar velocidad.", f"challenge-{number}-strategy"),
            paragraph(f"Fuente: {SOURCE_NAME} · {article['url'] if article else SOURCE_BASE}", f"challenge-{number}-source"),
        ]
        add_page(ext=ext, title=item["_pageName"], parent="isaac:category:challenges", children=children,
                 properties={"isaacType": "challenge", "isaacId": number, "character": clean(item.get("used character")),
                     "items": clean(item.get("item")), "trinkets": clean(item.get("trinket")), "pickups": clean(item.get("pickup")),
                     "curse": clean(item.get("curse")), "goal": clean(item.get("goal")), "reward": reward_title,
                     "sourceUrl": article["url"] if article else SOURCE_BASE, "attribution": SOURCE_NAME},
                 icon="🏁", collection_id=collection_ids["challenges"], asset_key=asset, sort_order=number)

    # Characters and their linked completion grid.
    character_articles = {
        item["title"].replace(" (Character)", ""): item
        for item in article_groups["characters"]
        if (item.get("infobox_type") or "").startswith("infobox character")
    }
    for index, name in enumerate(CHARACTER_ORDER):
        article = character_articles[name]
        ext = f"isaac:character:{slug(name)}"
        asset_subject = "Jacob and Esau" if name == "Jacob & Esau" else name
        asset = article_asset(article, name) or data_asset("characters", asset_subject)
        fields = article["fields"]
        relevant = [a for a in achievements if name.lower().replace("the ", "") in clean(a.get("requirements")).lower()]
        marks = []
        for mark_index, (label, keyword) in enumerate(MARKS):
            reward = next((a for a in relevant if keyword in clean(a.get("requirements")).lower()), None)
            marks.append({"key": f"isaac.character.{index}.mark.{mark_index}", "label": label,
                          **({"knowledgeRewardExternalKey": f"isaac:achievement:{reward['id']}"} if reward else {})})
        stat_labels = {
            "damage": "Daño", "tears": "Lágrimas", "shot speed": "Vel. de lágrima",
            "range": "Alcance", "speed": "Velocidad", "luck": "Suerte",
        }
        stats = [
            {"label": label, "value": clean(fields.get(field))}
            for field, label in stat_labels.items() if clean(fields.get(field))
        ]
        starting = [
            clean(fields.get(field))
            for field in ("collectibles", "pickups", "trinkets", "cards", "pills")
            if clean(fields.get(field))
        ]
        unlock = spanish(
            article.get("unlock_requirements") or fields.get("unlocked by") or
            fields.get("unlock") or ("Disponible desde el inicio" if index == 0 else "")
        )
        character_data: dict[str, Any] = {
            "knowledgeRootPageId": root_id,
            "knowledgeCharacterName": name,
            "knowledgeCharacterProgressKey": f"isaac.character.{slug(name)}.unlocked",
            "knowledgeCharacterInitiallyUnlocked": index == 0,
            "knowledgeCharacterUnlock": unlock,
            "knowledgeCharacterHealth": character_health(fields.get("health")),
            "knowledgeCharacterStats": stats,
            "knowledgeCharacterStartingItems": starting,
            "knowledgeCharacterStyle": character_style(article, name),
            "knowledgeCharacterTip": "Prioriza las marcas de mayor valor indicadas en la ruta óptima.",
        }
        if asset:
            character_data["knowledgeAssetExternalKey"] = asset
        children = [
            managed({"type": "knowledgeCharacter", "data": character_data}, f"character-v3-{index}-profile"),
            managed({"type": "knowledgeProgress", "data": {
                "knowledgeRootPageId": root_id, "knowledgeProgressDisplay": "marks",
                "knowledgeCompletionMarks": marks,
            }}, f"character-{index}-marks"),
        ]
        for achievement in relevant:
            children.append(page_link(f"isaac:achievement:{achievement['id']}", f"character-{index}-achievement-{achievement['id']}"))
        children.append(paragraph(f"Fuente: {SOURCE_NAME} · revisión {article['revision_id']} · {article['url']}", f"character-{index}-source"))
        add_page(ext=ext, title=name, parent="isaac:category:characters", children=children,
                 properties={"isaacType": "character", "isaacId": index, "isaacSlug": slug(name),
                     "unlockAchievementId": article.get("unlock_achievement_id"), "sourceUrl": article["url"],
                     "sourceRevision": article["revision_id"], "attribution": SOURCE_NAME},
                 icon="🧍", collection_id=collection_ids["characters"], asset_key=asset, sort_order=index)

    # Bosses.
    for order, article in enumerate(sorted(article_groups["bosses"], key=lambda row: row["title"]), 1):
        ext = external("boss", article["title"])
        asset = article_asset(article, article["title"])
        children = ([media(asset, f"boss-{order}-media")] if asset else []) + [
            heading("Jefe", 2, f"boss-{order}-title"),
            paragraph(f"Datos: {spanish(article.get('page_description'))}", f"boss-{order}-description"),
            paragraph(f"Salud y aparición: {spanish(article['fields'].get('health') or article['fields'].get('hp'))} {spanish(article['fields'].get('location'))}", f"boss-{order}-stats"),
            paragraph("Consejo: conserva movilidad, identifica el patrón seguro y evita gastar consumibles antes de la fase final.", f"boss-{order}-tip"),
            paragraph(f"Fuente: {SOURCE_NAME} · revisión {article['revision_id']} · {article['url']}", f"boss-{order}-source"),
        ]
        add_page(ext=ext, title=article["title"], parent="isaac:category:bosses", children=children,
                 properties={"isaacType": "boss", "isaacId": order, "fields": article["fields"],
                     "sourceUrl": article["url"], "sourceRevision": article["revision_id"], "attribution": SOURCE_NAME},
                 icon="👹", collection_id=collection_ids["bosses"], asset_key=asset, sort_order=order)

    # Transformations.
    for order, item in enumerate(sorted(transformations, key=lambda row: int(row["id"])), 1):
        tid = int(item["id"])
        ext = f"isaac:transformation:{tid}"
        asset = data_asset("transformations", item["title"])
        children = ([media(asset, f"transformation-{tid}-media")] if asset else []) + [
            heading(f"Transformation #{tid}", 2, f"transformation-{tid}-id"),
            paragraph(f"Requisito: {spanish(item.get('requirement'))}. Componentes: {clean(item.get('items'))}.", f"transformation-{tid}-requirement"),
            paragraph(f"Efecto: {spanish(item.get('description'))}", f"transformation-{tid}-effect"),
            paragraph(f"Fuente: {SOURCE_NAME} · snapshot {SNAPSHOT} · {SOURCE_BASE}", f"transformation-{tid}-source"),
        ]
        add_page(ext=ext, title=item["title"], parent="isaac:category:transformations", children=children,
                 properties={"isaacType": "transformation", "isaacId": tid, "requirement": clean(item.get("requirement")),
                     "items": clean(item.get("items")), "sourceUrl": SOURCE_BASE, "attribution": SOURCE_NAME},
                 icon="✨", collection_id=collection_ids["transformations"], asset_key=asset, sort_order=tid)

    # Pools and all 2,276 weighted relations.
    relations_by_pool: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for relation in pool_catalog["entries"]:
        relations_by_pool[relation["pool"]].append(relation)
    for order, item in enumerate(pool_catalog["pools"], 1):
        name = item["alias"]
        ext = external("pool", name)
        relations = relations_by_pool[name]
        children = [
            heading("Item pool", 2, f"pool-{order}-title"),
            paragraph(f"Tipo de precio: {clean(item.get('price type')) or 'normal'} · modo Greed: {'sí' if item.get('is greed') == '1' else 'no'}.", f"pool-{order}-data"),
            paragraph(f"Contiene {len(relations)} relaciones de collectible con su peso actual de Repentance+.", f"pool-{order}-count"),
            paragraph("Consejo: el peso relativo, los rerolls y la frecuencia con la que visitas este pool importan más que el número bruto de objetos.", f"pool-{order}-tip"),
            paragraph(f"Fuente: {SOURCE_NAME} · snapshot {SNAPSHOT} · {SOURCE_BASE}", f"pool-{order}-source"),
        ]
        add_page(ext=ext, title=name, parent="isaac:category:pools", children=children,
                 properties={"isaacType": "pool", "isaacId": order, "relations": [
                     {"collectible": row["collectible"], "collectibleExternalKey": collectible_ext_by_title.get(row["collectible"]),
                      "weight": float(row.get("weight") or 1)} for row in relations],
                     "sourceUrl": SOURCE_BASE, "attribution": SOURCE_NAME},
                 icon="🎰", collection_id=collection_ids["pools"], sort_order=order)

    character_index = {name: index for index, name in enumerate(CHARACTER_ORDER)}
    character_aliases = {name: name for name in CHARACTER_ORDER}
    character_aliases.update({"Maggy": "Magdalene", "Blue Baby": "???"})
    unlockable_titles = {
        article["title"]: (int(article["unlock_achievement_id"]), title_links.get(article["title"]))
        for article in articles
        if article.get("unlock_achievement_id") and article["title"] in title_links
    }

    def normalized(value: str) -> str:
        return value.casefold().replace("’", "'").replace("‘", "'")

    def mentioned_characters(value: str) -> list[str]:
        haystack = normalized(value)
        matches: list[tuple[int, int, str]] = []
        for alias, canonical in sorted(character_aliases.items(), key=lambda item: len(item[0]), reverse=True):
            needle = normalized(alias)
            for match in re.finditer(rf"(?<![a-z0-9]){re.escape(needle)}(?![a-z0-9])", haystack):
                if any(match.start() < end and match.end() > start for start, end, _ in matches):
                    continue
                matches.append((match.start(), match.end(), canonical))
        return list(dict.fromkeys(canonical for _, _, canonical in sorted(matches)))

    def mentioned_unlockables(value: str) -> list[tuple[str, int, str | None]]:
        haystack = normalized(value)
        found: list[tuple[int, str, int, str | None]] = []
        for title, (achievement_id, target) in sorted(unlockable_titles.items(), key=lambda item: len(item[0]), reverse=True):
            needle = normalized(title)
            match = re.search(rf"(?<![a-z0-9]){re.escape(needle)}(?![a-z0-9])", haystack)
            if match and not any(match.start() == position for position, *_ in found):
                found.append((match.start(), title, achievement_id, target))
        return [(title, achievement_id, target) for _, title, achievement_id, target in sorted(found)]

    def guide_progress_binding(text: str) -> tuple[list[str], str | None]:
        """Vincula una instrucción comprobable con la misma clave que rellena el guardado."""
        lower = normalized(text)
        challenge_ids = [int(value) for value in re.findall(r"#\s*(\d+)", text)] if "challenge" in lower else []
        if challenge_ids:
            keys = [f"isaac.challenge.{number}.completed" for number in challenge_ids if 1 <= number <= 45]
            return keys, f"isaac:challenge:{challenge_ids[0]}" if len(keys) == 1 else None

        unlock_at = lower.rfind("desbloque")
        unlock_segment = text[unlock_at:] if unlock_at >= 0 else ""
        character_segment = text if "aparezcan naturalmente" in lower else unlock_segment
        unlocked_characters = mentioned_characters(character_segment) if character_segment else []
        if unlocked_characters:
            keys = [f"isaac.character.{slug(name)}.unlocked" for name in unlocked_characters]
            target = f"isaac:character:{slug(unlocked_characters[0])}" if len(keys) == 1 else None
            return keys, target

        unlocked_items = mentioned_unlockables(unlock_segment) if unlock_segment else []
        if unlocked_items:
            keys = [f"isaac.achievement.{achievement_id}.unlocked" for _, achievement_id, _ in unlocked_items]
            target = unlocked_items[0][2] if len(keys) == 1 else None
            return list(dict.fromkeys(keys)), target

        character_name: str | None = None
        mark_segment = text
        if "→" in text:
            before, mark_segment = text.split("→", 1)
            candidates = mentioned_characters(before)
            character_name = candidates[-1] if candidates else None
        if character_name is None:
            match = re.search(r"\bcon\s+(.+?)(?:\s*[:;,.]|→|$)", text, flags=re.I)
            candidates = mentioned_characters(match.group(1)) if match else []
            character_name = candidates[-1] if candidates else None
        if character_name is None:
            return [], None

        mark_text = normalized(mark_segment)
        mark_patterns = [
            (0, ("mom's heart", "mom´s heart", "it lives")),
            (1, ("cathedral", "→ isaac", "vence a isaac", "derrota a isaac")),
            (2, ("satan",)), (3, ("blue baby", "→ ???", "chest")),
            (4, ("the lamb",)), (5, ("boss rush",)), (6, ("hush",)),
            (7, ("mega satan",)), (8, ("ultra greed", "greedier")),
            (9, ("delirium",)), (10, ("mother",)), (11, ("the beast",)),
        ]
        mark_indexes = [index for index, patterns in mark_patterns if any(pattern in mark_text for pattern in patterns)]
        keys = [f"isaac.character.{character_index[character_name]}.mark.{index}" for index in dict.fromkeys(mark_indexes)]
        return keys, f"isaac:character:{slug(character_name)}" if keys else None

    # The complete optimal guide, reusing the existing test page identity.
    guide_ext = "isaac:guide:optimal-order"
    guide_children: list[dict[str, Any]] = []
    phase = "intro"
    step = 0
    for line_number, raw in enumerate(GUIDE.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line:
            continue
        heading_match = re.match(r"^(#{1,4})\s+(.*)$", line)
        if heading_match:
            label = clean(heading_match.group(2).replace("**", ""))
            phase = slug(label)
            guide_children.append(heading(label, min(len(heading_match.group(1)), 3), f"guide-heading-{line_number}"))
            continue
        numbered = re.match(r"^\d+\.\s+(.*)$", line)
        bullet = re.match(r"^-\s+(.*)$", line)
        raw_text = (numbered or bullet).group(1) if numbered or bullet else line
        text = clean(raw_text.replace("**", "").replace("`", ""))
        if numbered:
            step += 1
            factual_keys, target = guide_progress_binding(text)
            minimum = None
            managed_key = f"guide-v5-step-{line_number}"
            if "11 derrotas de Mom's Heart" in text:
                factual_keys = ["isaac.counter.mom-kills"]
                target = None
                minimum = 11
                managed_key = f"guide-v9-counter-step-{line_number}"
            guide_children.append(progress(
                root_id,
                None if factual_keys else f"isaac.guide.{phase}.{step}",
                text,
                managed_key,
                readonly=bool(factual_keys),
                progress_keys=factual_keys,
                target=target,
                minimum=minimum,
            ))
        else:
            guide_children.append(paragraph(text, f"guide-text-{line_number}", title_links))
    add_page(ext=guide_ext, title="Orden óptimo de desbloqueos", parent=root_ext,
             children=guide_children, properties={"isaacGuide": True, "version": "Repentance+", "source": "guía min-max propia"},
             icon="🧭", page_id=guide_id, sort_order=1)

    mechanics_ext = "isaac:mechanics:sources"
    add_page(ext=mechanics_ext, title="Mecánicas, fuentes, atribución y versión", parent=root_ext,
             children=[
                 heading("Criterio de optimización", 2, "mechanics-criterion"),
                 paragraph("Los pools son independientes. La ruta prioriza rerolls, elecciones adicionales y recompensas fuertes en Treasure, Shop, Devil, Angel y Secret Room; pospone desbloqueos que sustituyen recursos buenos por variantes peores.", "mechanics-pools", title_links),
                 heading("Procedencia", 2, "mechanics-source-title"),
                 paragraph(f"Redacción original en español basada en datos factuales del snapshot {SNAPSHOT}. Fuente y atribución: {SOURCE_NAME}, CC BY-SA 4.0, {SOURCE_BASE}", "mechanics-source"),
                 paragraph("Los sprites pueden conservar derechos adicionales del juego. Cada ficha mantiene URL y revisión cuando el dataset las proporciona.", "mechanics-assets"),
                 paragraph("El lector de progreso es una implementación limpia de solo lectura. Los proyectos públicos se consultaron únicamente como referencia de compatibilidad.", "mechanics-save"),
             ], properties={"isaacSources": True, "snapshot": SNAPSHOT, "license": "CC BY-SA 4.0", "sourceUrl": SOURCE_BASE},
             icon="📚", sort_order=99)

    manifest = {
        "operationId": "isaac-repentance-plus-2026-07-29-v9-counter-progress",
        "assets": list(manifest_assets.values()),
        "pages": pages,
        "collections": collections,
    }
    type_counts: dict[str, int] = defaultdict(int)
    for page in pages:
        isaac_type = page.get("properties", {}).get("isaacType")
        if isaac_type:
            type_counts[isaac_type] += 1
    expected = {
        "character": 34, "collectible": 720, "trinket": 188,
        "pickup": 97, "challenge": 45, "achievement": 641,
        "boss": 132, "transformation": 16, "pool": 33,
    }
    if dict(type_counts) != expected or len(pool_catalog["entries"]) != 2276:
        raise RuntimeError(
            f"Auditoría previa fallida: {dict(type_counts)}; relaciones={len(pool_catalog['entries'])}"
        )
    duplicate_external_keys = [
        key for key, count in Counter(page["externalKey"] for page in pages).items()
        if count > 1
    ]
    if duplicate_external_keys:
        raise RuntimeError(f"Claves externas duplicadas: {duplicate_external_keys}")
    if "--dry-run" in sys.argv:
        print(json.dumps({"pages": len(pages), "assets": len(manifest_assets),
                          "collections": len(collections), "types": type_counts,
                          "poolRelations": len(pool_catalog["entries"])},
                         ensure_ascii=False, indent=2))
        return
    result = repository.apply_manifest(manifest)
    slot_candidates = sorted(
        Path(r"C:\Program Files (x86)\Steam\userdata").glob(
            r"*\250900\remote\rep+persistentgamedata1.dat"
        )
    )
    configured_slot = None
    if len(slot_candidates) == 1:
        configured_slot = 1
        with sqlite3.connect(repository.database_path) as db:
            db.execute(
                "INSERT INTO knowledge_import_sources(root_page_id,kind,path,slot,enabled) "
                "VALUES(?,'isaac-save',?,1,1) ON CONFLICT(root_page_id,kind) DO UPDATE SET "
                "path=excluded.path,slot=excluded.slot,enabled=1,last_error=NULL",
                (root_id, str(slot_candidates[0])),
            )
    print(json.dumps({
        "backup": backup, "pages": len(pages), "assets": len(manifest_assets),
        "collections": len(collections), "created": len(result["createdPageIds"]),
        "updated": len(result["updatedPageIds"]), "operation": result["operationId"],
        "configuredSaveSlot": configured_slot,
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
