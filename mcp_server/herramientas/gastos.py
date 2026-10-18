"""Gastos, métodos de pago y pagos fijos."""

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


def ensure_financial_lists(state: dict[str, Any]) -> None:
    state.setdefault("expenses", [])
    state.setdefault("expenseCategories", [])
    state.setdefault("paymentMethods", [])
    state.setdefault("fixedPayments", [])


def validate_expense_category(state: dict[str, Any], category_id: str) -> None:
    server.find_by_id(state["expenseCategories"], category_id, "la categoría de gasto")


def validate_payment_method(state: dict[str, Any], payment_method_id: str | None) -> None:
    if payment_method_id:
        server.find_by_id(state["paymentMethods"], payment_method_id, "el método de pago")


def list_expenses_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_financial_lists(state)
    expenses = []
    for expense in state["expenses"]:
        parsed = server.parse_datetime(expense.get("date"))
        if "year" in arguments and (parsed is None or parsed.year != int(arguments["year"])):
            continue
        if "month" in arguments and (parsed is None or parsed.month != int(arguments["month"])):
            continue
        if "category_id" in arguments and expense.get("categoryId") != arguments["category_id"]:
            continue
        if "payment_method_id" in arguments and expense.get("paymentMethodId") != arguments["payment_method_id"]:
            continue
        if "project_id" in arguments and arguments["project_id"] not in expense.get("projectIds", []):
            continue
        expenses.append(expense)
    expenses.sort(key=lambda item: item.get("date", ""), reverse=True)
    return {"expenses": expenses, "count": len(expenses), "mode": "supabase" if server.remote_enabled() else "local"}


def create_expense_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_financial_lists(state)
    validate_expense_category(state, arguments["category_id"])
    validate_payment_method(state, arguments.get("payment_method_id"))
    now = server.now_iso()
    expense = {
        "id": server.make_id("expense"),
        "date": server.date_iso(arguments["date"]),
        "concept": arguments["concept"].strip() or "Gasto",
        "amount": float(arguments["amount"]),
        "categoryId": arguments["category_id"],
        "paymentMethodId": arguments.get("payment_method_id") or None,
        "projectIds": arguments.get("project_ids", []),
        "note": (arguments.get("note") or "").strip() or None,
        "isRecurringInstance": bool(arguments.get("is_recurring_instance", False)),
        "fixedPaymentId": arguments.get("fixed_payment_id") or None,
        "createdAt": now,
        "updatedAt": now,
    }
    state["expenses"].append(expense)
    server.save_state(state)
    return {"created": expense}


def update_expense_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_financial_lists(state)
    index, expense = server.find_by_id(state["expenses"], arguments["expense_id"], "el gasto")
    updated = copy.deepcopy(expense)
    if "date" in arguments:
        updated["date"] = server.date_iso(arguments["date"])
    if "concept" in arguments:
        updated["concept"] = arguments["concept"].strip() or "Gasto"
    if "amount" in arguments:
        updated["amount"] = float(arguments["amount"])
    if "category_id" in arguments:
        validate_expense_category(state, arguments["category_id"])
        updated["categoryId"] = arguments["category_id"]
    if arguments.get("clear_payment_method_id"):
        updated["paymentMethodId"] = None
    elif "payment_method_id" in arguments:
        validate_payment_method(state, arguments.get("payment_method_id"))
        updated["paymentMethodId"] = arguments.get("payment_method_id") or None
    if "project_ids" in arguments:
        updated["projectIds"] = arguments["project_ids"]
    if arguments.get("clear_note"):
        updated["note"] = None
    elif "note" in arguments:
        updated["note"] = (arguments.get("note") or "").strip() or None
    if "is_recurring_instance" in arguments:
        updated["isRecurringInstance"] = bool(arguments["is_recurring_instance"])
    if arguments.get("clear_fixed_payment_id"):
        updated["fixedPaymentId"] = None
    elif "fixed_payment_id" in arguments:
        updated["fixedPaymentId"] = arguments.get("fixed_payment_id") or None
    updated["updatedAt"] = server.now_iso()
    state["expenses"][index] = updated
    server.save_state(state)
    return {"updated": updated}


def delete_expense_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_financial_lists(state)
    index, expense = server.find_by_id(state["expenses"], arguments["expense_id"], "el gasto")
    del state["expenses"][index]
    server.save_state(state)
    return {"deleted": expense}


def list_expense_categories_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_financial_lists(state)
    include_inactive = bool(arguments.get("include_inactive", False))
    categories = [category for category in state["expenseCategories"] if include_inactive or category.get("isActive", True)]
    return {"expense_categories": categories, "count": len(categories)}


def create_expense_category_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_financial_lists(state)
    now = server.now_iso()
    category = {
        "id": server.make_id("expense-category"),
        "name": arguments["name"].strip(),
        "colorValue": int(arguments.get("color_value", 0xFF70835D)),
        "iconCodePoint": int(arguments.get("icon_code_point", 0xF0CA)),
        "isActive": bool(arguments.get("is_active", True)),
        "createdAt": now,
        "updatedAt": now,
    }
    state["expenseCategories"].append(category)
    server.save_state(state)
    return {"created": category}


def update_expense_category_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_financial_lists(state)
    index, category = server.find_by_id(state["expenseCategories"], arguments["category_id"], "la categoría de gasto")
    updated = copy.deepcopy(category)
    if "name" in arguments:
        updated["name"] = arguments["name"].strip()
    if "color_value" in arguments:
        updated["colorValue"] = int(arguments["color_value"])
    if "icon_code_point" in arguments:
        updated["iconCodePoint"] = int(arguments["icon_code_point"])
    if "is_active" in arguments:
        updated["isActive"] = bool(arguments["is_active"])
    updated["updatedAt"] = server.now_iso()
    state["expenseCategories"][index] = updated
    server.save_state(state)
    return {"updated": updated}


def delete_expense_category_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_financial_lists(state)
    category_id = arguments["category_id"]
    index, category = server.find_by_id(state["expenseCategories"], category_id, "la categoría de gasto")
    replacement_id = arguments.get("replacement_category_id")
    linked_expenses = [expense for expense in state["expenses"] if expense.get("categoryId") == category_id]
    linked_fixed = [payment for payment in state["fixedPayments"] if payment.get("categoryId") == category_id]
    if replacement_id:
        validate_expense_category(state, replacement_id)
        for expense in linked_expenses:
            expense["categoryId"] = replacement_id
            expense["updatedAt"] = server.now_iso()
        for payment in linked_fixed:
            payment["categoryId"] = replacement_id
            payment["updatedAt"] = server.now_iso()
    elif linked_expenses or linked_fixed:
        if arguments.get("deactivate", True):
            category["isActive"] = False
            category["updatedAt"] = server.now_iso()
            state["expenseCategories"][index] = category
            server.save_state(state)
            return {"deactivated": category, "linked_expenses": len(linked_expenses), "linked_fixed_payments": len(linked_fixed)}
        raise ValueError("La categoría tiene gastos o pagos fijos vinculados. Usa replacement_category_id o deactivate=true.")
    deleted = state["expenseCategories"].pop(index)
    server.save_state(state)
    return {"deleted": deleted}


def list_payment_methods_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_financial_lists(state)
    include_inactive = bool(arguments.get("include_inactive", False))
    methods = [method for method in state["paymentMethods"] if include_inactive or method.get("isActive", True)]
    return {"payment_methods": methods, "count": len(methods)}


def create_payment_method_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_financial_lists(state)
    now = server.now_iso()
    method = {
        "id": server.make_id("payment-method"),
        "name": arguments["name"].strip(),
        "iconCodePoint": int(arguments.get("icon_code_point", 0xE8A1)),
        "colorValue": int(arguments.get("color_value", 0xFF6C7B8E)),
        "isActive": bool(arguments.get("is_active", True)),
        "createdAt": now,
        "updatedAt": now,
    }
    state["paymentMethods"].append(method)
    server.save_state(state)
    return {"created": method}


def update_payment_method_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_financial_lists(state)
    index, method = server.find_by_id(state["paymentMethods"], arguments["payment_method_id"], "el método de pago")
    updated = copy.deepcopy(method)
    if "name" in arguments:
        updated["name"] = arguments["name"].strip()
    if "icon_code_point" in arguments:
        updated["iconCodePoint"] = int(arguments["icon_code_point"])
    if "color_value" in arguments:
        updated["colorValue"] = int(arguments["color_value"])
    if "is_active" in arguments:
        updated["isActive"] = bool(arguments["is_active"])
    updated["updatedAt"] = server.now_iso()
    state["paymentMethods"][index] = updated
    server.save_state(state)
    return {"updated": updated}


def delete_payment_method_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_financial_lists(state)
    method_id = arguments["payment_method_id"]
    index, method = server.find_by_id(state["paymentMethods"], method_id, "el método de pago")
    replacement_id = arguments.get("replacement_payment_method_id")
    linked_expenses = [expense for expense in state["expenses"] if expense.get("paymentMethodId") == method_id]
    linked_fixed = [payment for payment in state["fixedPayments"] if payment.get("paymentMethodId") == method_id]
    if replacement_id:
        validate_payment_method(state, replacement_id)
        for expense in linked_expenses:
            expense["paymentMethodId"] = replacement_id
            expense["updatedAt"] = server.now_iso()
        for payment in linked_fixed:
            payment["paymentMethodId"] = replacement_id
            payment["updatedAt"] = server.now_iso()
    elif linked_expenses or linked_fixed:
        if arguments.get("deactivate", True):
            method["isActive"] = False
            method["updatedAt"] = server.now_iso()
            state["paymentMethods"][index] = method
            server.save_state(state)
            return {"deactivated": method, "linked_expenses": len(linked_expenses), "linked_fixed_payments": len(linked_fixed)}
        raise ValueError("El método tiene gastos o pagos fijos vinculados. Usa replacement_payment_method_id o deactivate=true.")
    deleted = state["paymentMethods"].pop(index)
    server.save_state(state)
    return {"deleted": deleted}


def list_fixed_payments_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_financial_lists(state)
    include_inactive = bool(arguments.get("include_inactive", False))
    payments = [payment for payment in state["fixedPayments"] if include_inactive or payment.get("isActive", True)]
    payments.sort(key=lambda item: item.get("nextPaymentDate", ""))
    return {"fixed_payments": payments, "count": len(payments)}


def create_fixed_payment_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_financial_lists(state)
    validate_expense_category(state, arguments["category_id"])
    validate_payment_method(state, arguments.get("payment_method_id"))
    now = server.now_iso()
    payment = {
        "id": server.make_id("fixed-payment"),
        "name": arguments["name"].strip(),
        "amount": float(arguments["amount"]),
        "categoryId": arguments["category_id"],
        "paymentMethodId": arguments.get("payment_method_id") or None,
        "frequency": server.normalize_frequency(arguments.get("frequency")),
        "customInterval": (arguments.get("custom_interval") or "").strip() or None,
        "nextPaymentDate": server.date_iso(arguments["next_payment_date"], "next_payment_date"),
        "isActive": bool(arguments.get("is_active", True)),
        "note": (arguments.get("note") or "").strip() or None,
        "reminderDaysBefore": max(0, min(60, int(arguments.get("reminder_days_before", 3)))),
        "createdAt": now,
        "updatedAt": now,
    }
    state["fixedPayments"].append(payment)
    server.save_state(state)
    return {"created": payment}


def update_fixed_payment_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_financial_lists(state)
    index, payment = server.find_by_id(state["fixedPayments"], arguments["fixed_payment_id"], "el pago fijo")
    updated = copy.deepcopy(payment)
    if "name" in arguments:
        updated["name"] = arguments["name"].strip()
    if "amount" in arguments:
        updated["amount"] = float(arguments["amount"])
    if "category_id" in arguments:
        validate_expense_category(state, arguments["category_id"])
        updated["categoryId"] = arguments["category_id"]
    if arguments.get("clear_payment_method_id"):
        updated["paymentMethodId"] = None
    elif "payment_method_id" in arguments:
        validate_payment_method(state, arguments.get("payment_method_id"))
        updated["paymentMethodId"] = arguments.get("payment_method_id") or None
    if "frequency" in arguments:
        updated["frequency"] = server.normalize_frequency(arguments["frequency"])
    if arguments.get("clear_custom_interval"):
        updated["customInterval"] = None
    elif "custom_interval" in arguments:
        updated["customInterval"] = (arguments.get("custom_interval") or "").strip() or None
    if "next_payment_date" in arguments:
        updated["nextPaymentDate"] = server.date_iso(arguments["next_payment_date"], "next_payment_date")
    if "is_active" in arguments:
        updated["isActive"] = bool(arguments["is_active"])
    if arguments.get("clear_note"):
        updated["note"] = None
    elif "note" in arguments:
        updated["note"] = (arguments.get("note") or "").strip() or None
    if "reminder_days_before" in arguments:
        updated["reminderDaysBefore"] = max(0, min(60, int(arguments["reminder_days_before"])))
    updated["updatedAt"] = server.now_iso()
    state["fixedPayments"][index] = updated
    server.save_state(state)
    return {"updated": updated}


def delete_fixed_payment_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_financial_lists(state)
    index, payment = server.find_by_id(state["fixedPayments"], arguments["fixed_payment_id"], "el pago fijo")
    deleted = state["fixedPayments"].pop(index)
    for expense in state["expenses"]:
        if expense.get("fixedPaymentId") == deleted["id"]:
            expense["fixedPaymentId"] = None
            expense["updatedAt"] = server.now_iso()
    server.save_state(state)
    return {"deleted": deleted}


def create_expense_from_fixed_payment_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_financial_lists(state)
    _, payment = server.find_by_id(state["fixedPayments"], arguments["fixed_payment_id"], "el pago fijo")
    parsed_next = server.parse_datetime(payment["nextPaymentDate"]) or dt.datetime.now()
    expense_args = {
        "date": arguments.get("date") or parsed_next.date().isoformat(),
        "concept": payment["name"],
        "amount": payment["amount"],
        "category_id": payment["categoryId"],
        "payment_method_id": payment.get("paymentMethodId"),
        "note": payment.get("note"),
        "is_recurring_instance": True,
        "fixed_payment_id": payment["id"],
    }
    return create_expense_impl(expense_args)


def duplicate_expense_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    state = server.load_state()
    ensure_financial_lists(state)
    _index, expense = server.find_by_id(state["expenses"], arguments["expense_id"], "el gasto")
    clone = copy.deepcopy(expense)
    clone["id"] = server.make_id("expense")
    clone["createdAt"] = server.now_iso()
    clone["updatedAt"] = server.now_iso()
    state["expenses"].append(clone)
    server.save_state(state)
    return {"created": clone}


def expense_totals_impl(arguments: dict[str, Any]) -> dict[str, Any]:
    expenses = list_expenses_impl(arguments)["expenses"]
    total = sum(float(expense.get("amount", 0)) for expense in expenses)
    group_by = arguments.get("group_by")
    grouped: dict[str, float] = {}
    if group_by:
        key_map = {
            "category": "categoryId",
            "payment_method": "paymentMethodId",
            "project": "projectIds",
            "month": "date",
            "year": "date",
        }
        field = key_map.get(group_by)
        if field is None:
            raise ValueError("group_by debe ser category, payment_method, project, month o year.")
        for expense in expenses:
            amount = float(expense.get("amount", 0))
            if field == "projectIds":
                ids = expense.get("projectIds") or ["sin_proyecto"]
                for project_id in ids:
                    grouped[project_id] = grouped.get(project_id, 0.0) + amount
            elif field == "date":
                parsed = server.parse_datetime(expense.get("date"))
                key = f"{parsed.year:04d}-{parsed.month:02d}" if group_by == "month" and parsed else str(parsed.year if parsed else "sin_fecha")
                grouped[key] = grouped.get(key, 0.0) + amount
            else:
                key = expense.get(field) or "sin_valor"
                grouped[key] = grouped.get(key, 0.0) + amount
    return {"total": total, "count": len(expenses), "grouped": grouped}


def export_financial_json_impl() -> dict[str, Any]:
    state = server.load_state()
    ensure_financial_lists(state)
    return {
        "expenses": state["expenses"],
        "expenseCategories": state["expenseCategories"],
        "paymentMethods": state["paymentMethods"],
        "fixedPayments": state["fixedPayments"],
    }


def export_financial_csv_impl() -> dict[str, Any]:
    state = server.load_state()
    ensure_financial_lists(state)
    rows = ["date,concept,amount,category_id,payment_method_id,project_ids,note"]
    for expense in state["expenses"]:
        values = [
            expense.get("date", ""),
            expense.get("concept", ""),
            str(expense.get("amount", "")),
            expense.get("categoryId", ""),
            expense.get("paymentMethodId", "") or "",
            "|".join(expense.get("projectIds", [])),
            (expense.get("note") or "").replace("\n", " "),
        ]
        rows.append(",".join(json.dumps(value, ensure_ascii=False) for value in values))
    return {"csv": "\n".join(rows)}


__all__ = [
    "ensure_financial_lists",
    "validate_expense_category",
    "validate_payment_method",
    "list_expenses_impl",
    "create_expense_impl",
    "update_expense_impl",
    "delete_expense_impl",
    "list_expense_categories_impl",
    "create_expense_category_impl",
    "update_expense_category_impl",
    "delete_expense_category_impl",
    "list_payment_methods_impl",
    "create_payment_method_impl",
    "update_payment_method_impl",
    "delete_payment_method_impl",
    "list_fixed_payments_impl",
    "create_fixed_payment_impl",
    "update_fixed_payment_impl",
    "delete_fixed_payment_impl",
    "create_expense_from_fixed_payment_impl",
    "duplicate_expense_impl",
    "expense_totals_impl",
    "export_financial_json_impl",
    "export_financial_csv_impl",
]
