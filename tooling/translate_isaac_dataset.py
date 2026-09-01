"""Genera y conserva la traducción editorial española usada por la wiki.

Los nombres oficiales se protegen antes de traducir y el resultado se guarda
solo en la caché local de Biblioteca. El dataset de auditoría no se modifica.
"""

from __future__ import annotations

import json
import re
import time
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

from tooling.import_isaac_wiki import (
    DATASET,
    KNOWLEDGE,
    TRANSLATION_CACHE,
    clean,
)

SEPARATOR = "ZXQ9876543210QXZ"


def load(name: str) -> Any:
    return json.loads((DATASET / "data" / name).read_text(encoding="utf-8"))


def add(candidates: set[str], value: Any) -> None:
    text = clean(value)
    if text:
        candidates.add(text)


def candidates_and_names() -> tuple[list[str], list[str]]:
    articles = load("articles.json")
    achievements = load("achievements.json")
    collectibles = load("collectibles_enriched.json")
    trinkets = load("trinkets_enriched.json")
    pickups = load("pickups_enriched.json")
    challenges = load("cargo/challenge.json")
    transformations = load("transformations_enriched.json")
    pools = load("pool_catalog.json")
    candidates: set[str] = set()
    names: set[str] = set()

    for item in achievements:
        names.add(str(item.get("name") or ""))
        add(candidates, item.get("requirements"))
        add(candidates, item.get("description"))
    for article in articles:
        names.add(str(article.get("title") or ""))
        fields = article.get("fields") or {}
        for key in (
            "description",
            "unlock",
            "stats",
            "health",
            "items",
            "starting items",
            "hp",
            "location",
        ):
            add(candidates, fields.get(key))
        add(candidates, article.get("unlock_requirements"))
        add(candidates, article.get("page_description"))
    for group in (collectibles, trinkets, pickups):
        for item in group:
            names.add(str(item.get("title") or ""))
            add(candidates, item.get("description"))
    for item in challenges:
        names.add(str(item.get("name") or ""))
        add(candidates, item.get("description"))
        add(candidates, item.get("goal"))
    for item in transformations:
        names.add(str(item.get("title") or item.get("name") or ""))
        add(candidates, item.get("requirement"))
        add(candidates, item.get("description"))
    for item in pools.get("pools", []):
        names.add(str(item.get("name") or ""))
    names.update(("Isaac", "Repentance", "Repentance+", "Steam"))
    return sorted(candidates), sorted(
        (name for name in names if len(name) >= 3), key=len, reverse=True
    )


def protect(text: str, official_names: list[str]) -> tuple[str, dict[str, str]]:
    replacements: dict[str, str] = {}
    protected = text
    for name in official_names:
        if name not in protected:
            continue
        token = f"ZXNAME{len(replacements):04d}ZX"
        protected = protected.replace(name, token)
        replacements[token] = name
    return protected, replacements


def translate_batch(texts: list[str], official_names: list[str]) -> list[str]:
    protected: list[str] = []
    replacements: list[dict[str, str]] = []
    for text in texts:
        value, mapping = protect(text, official_names)
        protected.append(value)
        replacements.append(mapping)
    joined = f"\n{SEPARATOR}\n".join(protected)
    query = urllib.parse.urlencode(
        {
            "client": "gtx",
            "sl": "en",
            "tl": "es",
            "dt": "t",
            "q": joined,
        }
    )
    request = urllib.request.Request(
        f"https://translate.googleapis.com/translate_a/single?{query}",
        headers={"User-Agent": "Todo-Isaac-Wiki/1.0"},
    )
    with urllib.request.urlopen(request, timeout=45) as response:
        payload = json.loads(response.read())
    translated = "".join(part[0] or "" for part in payload[0])
    parts = re.split(rf"\s*{SEPARATOR}\s*", translated)
    if len(parts) != len(texts):
        raise RuntimeError(
            f"La traducción devolvió {len(parts)} segmentos para {len(texts)} textos."
        )
    result: list[str] = []
    for part, mapping in zip(parts, replacements, strict=True):
        restored = part.strip()
        for token, name in mapping.items():
            restored = restored.replace(token, name)
        result.append(restored)
    return result


def main() -> None:
    texts, official_names = candidates_and_names()
    cache: dict[str, str] = (
        json.loads(TRANSLATION_CACHE.read_text(encoding="utf-8"))
        if TRANSLATION_CACHE.is_file()
        else {}
    )
    pending = [text for text in texts if text not in cache]
    batches: list[list[str]] = []
    current: list[str] = []
    size = 0
    for text in pending:
        if current and size + len(text) > 2800:
            batches.append(current)
            current = []
            size = 0
        current.append(text)
        size += len(text) + len(SEPARATOR) + 2
    if current:
        batches.append(current)

    TRANSLATION_CACHE.parent.mkdir(parents=True, exist_ok=True)
    for index, batch in enumerate(batches, 1):
        for attempt in range(4):
            try:
                translated = translate_batch(batch, official_names)
                cache.update(zip(batch, translated, strict=True))
                TRANSLATION_CACHE.write_text(
                    json.dumps(cache, ensure_ascii=False, indent=2, sort_keys=True),
                    encoding="utf-8",
                )
                print(f"Lote {index}/{len(batches)} · {len(cache)}/{len(texts)}")
                break
            except Exception:
                if attempt == 3:
                    raise
                time.sleep(2**attempt)
        time.sleep(0.12)
    print(f"Caché: {TRANSLATION_CACHE} ({len(cache)} textos)")


if __name__ == "__main__":
    main()
