"""Diario, viajes, sesiones de enfoque y resumen semanal."""

import datetime as dt
from typing import Any

import server

MESES = [
    "enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
    "agosto", "septiembre", "octubre", "noviembre", "diciembre",
]
TIPOS_RESERVA = {"flight", "lodging", "transport", "activity", "other"}


def ensure_life_lists(state: dict[str, Any]) -> None:
    state.setdefault("journalEntries", [])
    state.setdefault("trips", [])
    state.setdefault("focusSessions", [])


def _day(value: str | None, field: str) -> dt.date:
    return server.parse_date(value or "", field)


def _logical_today(state: dict[str, Any]) -> dt.date:
    """Día lógico: antes de la hora de cierre sigue contando el día anterior."""
    ends_at = int((state.get("daySettings") or {}).get("dayEndsAtHour", 5))
    return (dt.datetime.now() - dt.timedelta(hours=ends_at)).date()


# --- Diario -----------------------------------------------------------------


def list_journal_entries_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_life_lists(state)
    entries = []
    for entry in state["journalEntries"]:
        parsed = server.parse_datetime(entry.get("date"))
        if "year" in arguments and (parsed is None or parsed.year != int(arguments["year"])):
            continue
        if "month" in arguments and (parsed is None or parsed.month != int(arguments["month"])):
            continue
        entries.append(entry)
    entries.sort(key=lambda item: item.get("date", ""), reverse=True)
    limit = int(arguments.get("limit", 60))
    return {"entries": entries[:limit], "count": len(entries)}


def save_journal_entry_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    """Crea la entrada del día o actualiza la existente: solo hay una por día."""
    state = server.load_state()
    ensure_life_lists(state)
    day = _day(arguments.get("date") or _logical_today(state).isoformat(), "date")
    date_value = dt.datetime.combine(day, dt.time()).isoformat()
    mood = int(arguments.get("mood", 0))
    if not 0 <= mood <= 5:
        raise ValueError("mood debe estar entre 0 y 5.")
    now = server.now_iso()
    for entry in state["journalEntries"]:
        parsed = server.parse_datetime(entry.get("date"))
        if parsed is not None and parsed.date() == day:
            if "text" in arguments:
                entry["text"] = str(arguments["text"]).strip()
            if "mood" in arguments:
                entry["mood"] = mood
            entry["updatedAt"] = now
            server.save_state(state)
            return {"updated": entry}
    entry = {
        "id": server.make_id("journal"),
        "date": date_value,
        "text": str(arguments.get("text", "")).strip(),
        "mood": mood,
        "imagePath": "",
        "thumbnailPath": "",
        "imageSha256": "",
        "createdAt": now,
        "updatedAt": now,
    }
    state["journalEntries"].append(entry)
    server.save_state(state)
    return {"created": entry}


# --- Viajes -----------------------------------------------------------------


def list_trips_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_life_lists(state)
    trips = [
        trip for trip in state["trips"]
        if arguments.get("include_archived") or not trip.get("archived")
    ]
    trips.sort(key=lambda item: item.get("startDate", ""))
    return {"trips": trips, "count": len(trips)}


def create_trip_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_life_lists(state)
    start = _day(arguments.get("start_date"), "start_date")
    end = _day(arguments.get("end_date") or arguments.get("start_date"), "end_date")
    if end < start:
        end = start
    packing_list_id = None
    if arguments.get("create_packing_list"):
        state.setdefault("wardrobePackingLists", [])
        packing_list_id = server.make_id("wardrobe-packing")
        state["wardrobePackingLists"].append({
            "id": packing_list_id,
            "name": arguments["name"].strip() or "Nuevo viaje",
            "startDate": dt.datetime.combine(start, dt.time()).isoformat(),
            "endDate": dt.datetime.combine(end, dt.time()).isoformat(),
            "entries": [],
            "discardedItemIds": [],
        })
    now = server.now_iso()
    trip = {
        "id": server.make_id("trip"),
        "name": arguments["name"].strip() or "Viaje sin nombre",
        "destination": (arguments.get("destination") or "").strip(),
        "startDate": dt.datetime.combine(start, dt.time()).isoformat(),
        "endDate": dt.datetime.combine(end, dt.time()).isoformat(),
        "notes": (arguments.get("notes") or "").strip(),
        "packingListId": packing_list_id,
        "reservations": [],
        "documents": [],
        "archived": False,
        "createdAt": now,
        "updatedAt": now,
    }
    state["trips"].append(trip)
    server.save_state(state)
    return {"created": trip}


def add_trip_reservation_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_life_lists(state)
    _, trip = server.find_by_id(state["trips"], arguments["trip_id"], "el viaje")
    kind = arguments.get("kind", "activity")
    if kind not in TIPOS_RESERVA:
        raise ValueError(f"kind debe ser uno de: {', '.join(sorted(TIPOS_RESERVA))}.")
    date_value = None
    if arguments.get("date"):
        raw = str(arguments["date"])
        date_value = server.normalize_datetime(raw) if "T" in raw else server.date_iso(raw, "date")
    reservation = {
        "id": server.make_id("trip-reservation"),
        "title": arguments["title"].strip() or kind,
        "kind": kind,
        "date": date_value,
        "confirmation": (arguments.get("confirmation") or "").strip(),
        "note": (arguments.get("note") or "").strip(),
    }
    trip.setdefault("reservations", []).append(reservation)
    trip["updatedAt"] = server.now_iso()
    server.save_state(state)
    return {"created": reservation, "trip_id": trip["id"]}


def delete_trip_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_life_lists(state)
    index, trip = server.find_by_id(state["trips"], arguments["trip_id"], "el viaje")
    del state["trips"][index]
    server.save_state(state)
    return {"deleted": trip["id"]}


# --- Enfoque ----------------------------------------------------------------


def list_focus_sessions_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_life_lists(state)
    start = _day(arguments["from"], "from") if arguments.get("from") else None
    end = _day(arguments["to"], "to") if arguments.get("to") else None
    sessions = []
    for session in state["focusSessions"]:
        parsed = server.parse_datetime(session.get("startedAt"))
        if parsed is None:
            continue
        if start and parsed.date() < start:
            continue
        if end and parsed.date() > end:
            continue
        sessions.append(session)
    sessions.sort(key=lambda item: item.get("startedAt", ""), reverse=True)
    total = sum(int(item.get("actualSeconds", 0)) for item in sessions)
    return {"sessions": sessions, "count": len(sessions), "total_seconds": total}


# --- Resumen semanal --------------------------------------------------------


def _fecha_texto(day: dt.date) -> str:
    return f"{day.day} de {MESES[day.month - 1]}"


def _dinero(value: float) -> str:
    return f"{value:.2f}".replace(".", ",") + " €"


def _duracion(segundos: int) -> str:
    minutos = segundos // 60
    if minutos < 60:
        return f"{minutos} min"
    return f"{minutos // 60} h {minutos % 60:02d} min"


def _en_semana(value: str | None, start: dt.date, end: dt.date) -> bool:
    parsed = server.parse_datetime(value)
    return parsed is not None and start <= parsed.date() < end


def build_weekly_summary(state: dict[str, Any], week_start: dt.date) -> str:
    ensure_life_lists(state)
    start = week_start
    end = start + dt.timedelta(days=7)
    last = end - dt.timedelta(days=1)
    lines = [
        "# Resumen de la semana",
        f"{_fecha_texto(start)} – {_fecha_texto(last)} de {last.year}",
        "",
    ]

    completed = []
    for task in state.get("tasks", []):
        if task.get("parentTaskId"):
            continue
        recurrence = (task.get("recurrence") or {}).get("type", "none")
        if recurrence != "none":
            for done in (task.get("recurrenceCompletions") or {}).values():
                if _en_semana(done, start, end):
                    completed.append(task.get("title", ""))
        elif task.get("status") == "completed" and _en_semana(task.get("completedAt"), start, end):
            completed.append(task.get("title", ""))
    lines.append("## Tareas")
    if not completed:
        lines.append("No hay tareas completadas esta semana.")
    else:
        lines.append(f"Has completado {len(completed)}.")
        lines.extend(f"- {title}" for title in completed[:10])
        if len(completed) > 10:
            lines.append(f"- … y {len(completed) - 10} más")
    plant_tasks = [
        task for task in state.get("tasks", [])
        if task.get("sourcePlantId")
        and task.get("status") == "completed"
        and _en_semana(task.get("completedAt"), start, end)
    ]
    if plant_tasks:
        lines.append(f"Cuidados de plantas hechos: {len(plant_tasks)}.")
    lines.append("")

    library = [
        item for item in state.get("libraryItems", [])
        if item.get("status", "completed") == "completed"
        and _en_semana(item.get("completedDate"), start, end)
    ]
    lines.append("## Biblioteca")
    if not library:
        lines.append("No has terminado nada esta semana.")
    for item in library:
        rating = item.get("rating")
        suffix = f" ({str(rating).replace('.', ',')})" if rating is not None else ""
        lines.append(f"- {item.get('title', '')}{suffix}")
    lines.append("")

    expenses = [e for e in state.get("expenses", []) if _en_semana(e.get("date"), start, end)]
    lines.append("## Gastos")
    if not expenses:
        lines.append("No hay gastos registrados.")
    else:
        total = sum(float(e.get("amount", 0)) for e in expenses)
        lines.append(f"Total: {_dinero(total)} en {len(expenses)} gastos.")
        names = {c["id"]: c.get("name", "") for c in state.get("expenseCategories", [])}
        by_category: dict[str, float] = {}
        for expense in expenses:
            name = names.get(expense.get("categoryId"), "Sin categoría")
            by_category[name] = by_category.get(name, 0.0) + float(expense.get("amount", 0))
        for name, value in sorted(by_category.items(), key=lambda pair: -pair[1])[:3]:
            lines.append(f"- {name}: {_dinero(value)}")
    next_end = end + dt.timedelta(days=7)
    upcoming = [
        p for p in state.get("fixedPayments", [])
        if p.get("isActive", True) and _en_semana(p.get("nextPaymentDate"), end, next_end)
    ]
    if upcoming:
        lines.append("Cobros de la semana próxima:")
        for payment in sorted(upcoming, key=lambda p: p.get("nextPaymentDate", "")):
            day = server.parse_datetime(payment["nextPaymentDate"]).date()
            lines.append(f"- {payment.get('name', '')}: {_dinero(float(payment.get('amount', 0)))} ({_fecha_texto(day)})")
    lines.append("")

    sessions = [s for s in state["focusSessions"] if _en_semana(s.get("startedAt"), start, end)]
    lines.append("## Enfoque")
    if not sessions:
        lines.append("No has registrado sesiones.")
    else:
        seconds = sum(int(s.get("actualSeconds", 0)) for s in sessions)
        lines.append(f"{_duracion(seconds)} repartidos en {len(sessions)} sesiones.")
    lines.append("")

    entries = [e for e in state["journalEntries"] if _en_semana(e.get("date"), start, end)]
    moods = [int(e.get("mood", 0)) for e in entries if int(e.get("mood", 0)) > 0]
    lines.append("## Diario")
    if not entries:
        lines.append("No has escrito entradas.")
    else:
        text = f"Entradas: {len(entries)} de 7 días."
        if moods:
            text += f" Ánimo medio: {sum(moods) / len(moods):.1f}".replace(".", ",") + " de 5."
        lines.append(text)

    trips = []
    for trip in state["trips"]:
        if trip.get("archived"):
            continue
        trip_start = server.parse_datetime(trip.get("startDate"))
        trip_end = server.parse_datetime(trip.get("endDate"))
        if trip_start and trip_end and trip_start.date() <= next_end and trip_end.date() >= start:
            trips.append((trip, trip_start.date(), trip_end.date()))
    if trips:
        lines.extend(["", "## Viajes"])
        for trip, trip_start, trip_end in trips:
            destino = f" ({trip['destination']})" if trip.get("destination") else ""
            lines.append(f"- {trip.get('name', '')}{destino}: {_fecha_texto(trip_start)} – {_fecha_texto(trip_end)}")
    return "\n".join(lines).rstrip()


def generate_weekly_summary_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    """Genera el resumen solo cuando se pide; no guarda nada."""
    state = server.load_state()
    ensure_life_lists(state)
    if arguments.get("week_start"):
        reference = _day(arguments["week_start"], "week_start")
    else:
        reference = _logical_today(state)
    week_start = reference - dt.timedelta(days=reference.weekday())
    return {
        "week_start": week_start.isoformat(),
        "summary": build_weekly_summary(state, week_start),
    }
