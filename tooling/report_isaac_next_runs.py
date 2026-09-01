"""Resume el progreso local de Isaac para personalizar las próximas runs."""

from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import Any, Iterable

DATABASE = Path(r"C:\Users\aries\Documents\Todo\knowledge\knowledge.sqlite")
MARKS = (
    "Mom's Heart / It Lives",
    "Isaac",
    "Satan",
    "???",
    "The Lamb",
    "Boss Rush",
    "Hush",
    "Mega Satan",
    "Greed / Greedier",
    "Delirium",
    "Mother",
    "The Beast",
)
PRIORITY_CHALLENGES = (6, 32, 23, 12, 33, 37, 15, 18, 2, 39, 14, 17, 29, 8, 40)


def walk(value: Any) -> Iterable[dict[str, Any]]:
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk(child)


def complete(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value > 0
    return value not in (None, "", False)


def main() -> None:
    with sqlite3.connect(DATABASE) as database:
        database.row_factory = sqlite3.Row
        root = database.execute(
            "SELECT id FROM knowledge_pages "
            "WHERE canonical_id='isaac:root:repentance-plus' LIMIT 1"
        ).fetchone()
        if root is None:
            raise SystemExit("No se encontró la guía de Isaac.")
        root_id = root["id"]
        progress = {
            row["progress_key"]: json.loads(row["value_json"])
            for row in database.execute(
                "SELECT progress_key,value_json FROM knowledge_progress "
                "WHERE root_page_id=?",
                (root_id,),
            )
        }
        characters: list[dict[str, Any]] = []
        character_rows = database.execute(
            "SELECT title,properties_json FROM knowledge_pages "
            "WHERE canonical_id LIKE 'isaac:character:%'"
        ).fetchall()
        for row in character_rows:
            properties = json.loads(row["properties_json"] or "{}")
            if properties.get("isaacType") != "character":
                continue
            index = int(properties["isaacId"])
            slug = str(properties["isaacSlug"])
            marks = {
                MARKS[mark]: int(progress.get(f"isaac.character.{index}.mark.{mark}", 0))
                for mark in range(len(MARKS))
                if complete(progress.get(f"isaac.character.{index}.mark.{mark}", 0))
            }
            characters.append(
                {
                    "name": row["title"],
                    "index": index,
                    "unlocked": complete(
                        progress.get(f"isaac.character.{slug}.unlocked", False)
                    ),
                    "marks": marks,
                }
            )
        characters.sort(key=lambda item: item["index"])

        guide = database.execute(
            "SELECT document_json FROM knowledge_pages "
            "WHERE canonical_id='isaac:guide:optimal-order' LIMIT 1"
        ).fetchone()
        pending_steps: list[dict[str, Any]] = []
        if guide:
            document = json.loads(guide["document_json"] or "{}")
            for node in walk(document):
                if node.get("type") != "knowledgeProgress":
                    continue
                data = node.get("data") or {}
                if data.get("knowledgeProgressDisplay"):
                    continue
                keys = [
                    str(key)
                    for key in data.get("knowledgeProgressKeys", [])
                    if str(key)
                ]
                single = str(data.get("knowledgeProgressKey") or "")
                if single:
                    keys.insert(0, single)
                if keys and not all(complete(progress.get(key)) for key in keys):
                    pending_steps.append(
                        {
                            "label": data.get("knowledgeProgressLabel"),
                            "keys": list(dict.fromkeys(keys)),
                            "automatic": data.get("knowledgeProgressReadOnly") is True,
                        }
                    )

        achievement_ids_by_title = {
            row["title"]: int(json.loads(row["properties_json"])["isaacId"])
            for row in database.execute(
                "SELECT title,properties_json FROM knowledge_pages "
                "WHERE canonical_id LIKE 'isaac:achievement:%'"
            )
        }
        challenge_rows = database.execute(
            "SELECT title,properties_json FROM knowledge_pages "
            "WHERE canonical_id LIKE 'isaac:challenge:%'"
        ).fetchall()
        priority_challenges: list[dict[str, Any]] = []
        for row in challenge_rows:
            properties = json.loads(row["properties_json"] or "{}")
            number = int(properties.get("isaacId") or 0)
            if number not in PRIORITY_CHALLENGES:
                continue
            unlock_id = achievement_ids_by_title.get(row["title"])
            available = unlock_id is None or complete(
                progress.get(f"isaac.achievement.{unlock_id}.unlocked")
            )
            priority_challenges.append(
                {
                    "number": number,
                    "name": row["title"],
                    "reward": properties.get("reward"),
                    "available": available,
                }
            )
        priority_challenges.sort(
            key=lambda item: PRIORITY_CHALLENGES.index(item["number"])
        )

        report = {
            "unlockedCharacters": [
                item["name"] for item in characters if item["unlocked"]
            ],
            "lockedCharacters": [
                item["name"] for item in characters if not item["unlocked"]
            ],
            "characterMarks": [
                item for item in characters if item["unlocked"] and item["marks"]
            ],
            "counters": {
                key.removeprefix("isaac.counter."): value
                for key, value in progress.items()
                if key.startswith("isaac.counter.")
            },
            "pendingGuideSteps": pending_steps,
            "priorityChallenges": priority_challenges,
            "completedChallenges": [
                number
                for number in range(1, 46)
                if complete(progress.get(f"isaac.challenge.{number}.completed"))
            ],
            "keyAchievements": {
                str(achievement_id): complete(
                    progress.get(f"isaac.achievement.{achievement_id}.unlocked")
                )
                for achievement_id in (29, 57, 78, 90, 94, 103, 104, 198, 407)
            },
        }
        print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
