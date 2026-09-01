"""Audita la wiki local de Isaac después de una importación."""

from __future__ import annotations

import json
import sqlite3
import sys
from collections import Counter
from pathlib import Path
from typing import Any, Iterable

DATABASE = Path(r"C:\Users\aries\Documents\Todo\knowledge\knowledge.sqlite")
ASSET_ROOT = DATABASE.parent / "assets"
ROOT_ID = "page-e44dc74f-6166-4ecd-8bce-eb1579351eee"
GUIDE_ID = "page-861eea3d-96f6-4973-a89a-9403715fa8c0"
EXPECTED = {
    "character": 34,
    "collectible": 720,
    "trinket": 188,
    "pickup": 97,
    "challenge": 45,
    "achievement": 641,
    "boss": 132,
    "transformation": 16,
    "pool": 33,
}


def walk(value: Any) -> Iterable[dict[str, Any]]:
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk(child)


def main() -> None:
    failures: list[str] = []
    with sqlite3.connect(DATABASE) as db:
        db.row_factory = sqlite3.Row
        rows = db.execute(
            "SELECT * FROM knowledge_pages WHERE canonical_source='mcp' "
            "AND canonical_id LIKE 'isaac:%'"
        ).fetchall()
        ids = {row["id"] for row in rows}
        types: Counter[str] = Counter()
        relations = 0
        broken_page_refs: list[str] = []
        broken_asset_refs: list[str] = []
        missing_sources: list[str] = []
        backlinks: Counter[str] = Counter()
        raw_reference_tokens: Counter[str] = Counter()
        assets = {
            row["id"]: row
            for row in db.execute("SELECT * FROM knowledge_assets").fetchall()
        }

        for row in rows:
            properties = json.loads(row["properties_json"] or "{}")
            isaac_type = properties.get("isaacType")
            if isaac_type:
                types[isaac_type] += 1
                if not properties.get("sourceUrl"):
                    missing_sources.append(row["canonical_id"])
            if isaac_type == "pool":
                relations += len(properties.get("relations") or [])
            if row["id"] != ROOT_ID and row["parent_id"] not in ids:
                failures.append(f"Página huérfana: {row['canonical_id']}")
            cover_id = row["cover_asset_id"]
            if cover_id:
                asset = assets.get(cover_id)
                if asset is None or not (ASSET_ROOT / asset["relative_path"]).is_file():
                    broken_asset_refs.append(f"{row['canonical_id']} -> {cover_id}")
            document = json.loads(row["document_json"] or "{}")
            raw_document = row["document_json"] or ""
            for token in (
                "knowledgeTargetPageId",
                "rewardPageId",
                "knowledge://page/",
                "knowledgeTargetExternalKey",
            ):
                raw_reference_tokens[token] += raw_document.count(token)
            for node in walk(document):
                for key in ("knowledgeTargetPageId", "rewardPageId"):
                    target = node.get(key)
                    if target:
                        backlinks[str(target)] += 1
                        if target not in ids:
                            broken_page_refs.append(
                                f"{row['canonical_id']}:{key} -> {target}"
                            )
                asset_id = node.get("knowledgeAssetId")
                if asset_id:
                    asset = assets.get(str(asset_id))
                    if asset is None or not (ASSET_ROOT / asset["relative_path"]).is_file():
                        broken_asset_refs.append(
                            f"{row['canonical_id']}:knowledgeAssetId -> {asset_id}"
                        )

        if dict(types) != EXPECTED:
            failures.append(f"Conteos: {dict(types)}")
        if relations != 2276:
            failures.append(f"Relaciones de pools: {relations}")
        if broken_page_refs:
            failures.append(f"Enlaces internos rotos: {len(broken_page_refs)}")
        if broken_asset_refs:
            failures.append(f"Recursos rotos: {len(broken_asset_refs)}")
        if missing_sources:
            failures.append(f"Fichas sin fuente: {len(missing_sources)}")
        guide = db.execute(
            "SELECT canonical_id,document_json FROM knowledge_pages WHERE id=?", (GUIDE_ID,)
        ).fetchone()
        if guide is None or guide["canonical_id"] != "isaac:guide:optimal-order":
            failures.append("No se reutilizó la página original de la guía.")
        azazel_guide_progress: dict[str, Any] | None = None
        azazel_guide_matches: list[dict[str, Any]] = []
        if guide is not None:
            guide_document = json.loads(guide["document_json"] or "{}")
            azazel_guide_matches = [
                node
                for node in walk(guide_document)
                if "azazel" in str(node.get("knowledgeProgressLabel") or "").lower()
            ]
            azazel_guide_progress = next(
                (
                    node
                    for node in azazel_guide_matches
                    if "Desbloquea cuanto antes a Azazel"
                    in str(node.get("knowledgeProgressLabel") or "")
                ),
                None,
            )
        if azazel_guide_progress is None:
            failures.append("La ruta no contiene el paso comprobable de Azazel.")
        elif (
            azazel_guide_progress.get("knowledgeProgressKey")
            != "isaac.character.azazel.unlocked"
            or azazel_guide_progress.get("knowledgeProgressReadOnly") is not True
        ):
            failures.append("El paso de Azazel no está vinculado al guardado.")
        azazel_state = db.execute(
            "SELECT value_json,source FROM knowledge_progress "
            "WHERE root_page_id=? AND progress_key='isaac.character.azazel.unlocked'",
            (ROOT_ID,),
        ).fetchone()
        if azazel_state is None or json.loads(azazel_state["value_json"]) is not True:
            failures.append("El progreso derivado no reconoce a Azazel como desbloqueado.")
        mom_manual_state = db.execute(
            "SELECT progress_key,value_json,source FROM knowledge_progress "
            "WHERE root_page_id=? AND progress_key LIKE 'isaac.guide.fase-0-abrir-el-juego-sin-ensuciarlo.%' "
            "AND value_json='true' ORDER BY progress_key LIMIT 1",
            (ROOT_ID,),
        ).fetchone()
        if mom_manual_state is None or mom_manual_state["source"] != "manual":
            failures.append("La migración no conservó la marca manual de la fase 0.")

        character_profiles = 0
        samson_profile: dict[str, Any] | None = None
        for row in rows:
            properties = json.loads(row["properties_json"] or "{}")
            if properties.get("isaacType") != "character":
                continue
            if not row["cover_asset_id"]:
                failures.append(f"Personaje sin portada para el árbol: {row['canonical_id']}")
            document = json.loads(row["document_json"] or "{}")
            profile = next(
                (node.get("data") for node in walk(document) if node.get("type") == "knowledgeCharacter"),
                None,
            )
            if isinstance(profile, dict):
                character_profiles += 1
                style = str(profile.get("knowledgeCharacterStyle") or "")
                if style.startswith("Characters "):
                    failures.append(f"Navegación incrustada en {row['canonical_id']}")
                asset_id = profile.get("knowledgeAssetId")
                if not asset_id or asset_id not in assets:
                    failures.append(f"Ficha sin retrato: {row['canonical_id']}")
                if row["canonical_id"] == "isaac:character:samson":
                    samson_profile = profile
        if character_profiles != EXPECTED["character"]:
            failures.append(f"Fichas compactas de personaje: {character_profiles}")
        if samson_profile is None or not any(
            "Bloody Lust" in str(item)
            for item in samson_profile.get("knowledgeCharacterStartingItems", [])
        ):
            failures.append("La ficha de Samson no muestra Bloody Lust como objeto inicial.")
        isaac_leases = [
            dict(row)
            for row in db.execute(
                "SELECT * FROM knowledge_leases WHERE page_id IN "
                "(SELECT id FROM knowledge_pages WHERE canonical_source='mcp' "
                "AND canonical_id LIKE 'isaac:%')"
            ).fetchall()
        ]
        if isaac_leases:
            failures.append(f"Leases residuales de Isaac: {len(isaac_leases)}")

        report = {
            "pages": len(rows),
            "types": dict(types),
            "poolRelations": relations,
            "referencedPages": len(backlinks),
            "referenceTokens": dict(raw_reference_tokens),
            "assets": len(assets),
            "brokenPageReferences": broken_page_refs[:10],
            "brokenAssetReferences": broken_asset_refs[:10],
            "missingSources": missing_sources[:10],
            "characterProfiles": character_profiles,
            "azazelGuideProgress": azazel_guide_progress,
            "azazelSaveState": dict(azazel_state) if azazel_state else None,
            "preservedManualState": dict(mom_manual_state) if mom_manual_state else None,
            "isaacLeases": isaac_leases,
            "failures": failures,
        }
        print(json.dumps(report, ensure_ascii=False, indent=2))
    if failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
