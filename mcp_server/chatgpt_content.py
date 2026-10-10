"""Búsqueda de fichas locales con resultados acotados y sin acceso a archivos."""
import copy
import hashlib
import json
import unicodedata

SECTIONS = {
    'notas': ('notes', 'Notas'),
    'ropa': ('wardrobeItems', 'Ropa'),
    'conjuntos': ('wardrobeOutfits', 'Conjuntos'),
    'usos_ropa': ('wardrobeWearLogs', 'Usos de ropa'),
    'planes_ropa': ('wardrobePlanEntries', 'Planes de ropa'),
    'maletas': ('wardrobePackingLists', 'Maletas'),
    'recetas': ('recipes', 'Recetas'),
    'menus': ('weeklyMenus', 'Menús'),
    'hogar': ('householdItems', 'Hogar'),
    'compras': ('shoppingItems', 'Compras'),
    'biblioteca': ('libraryItems', 'Biblioteca'),
    'objetivos_biblioteca': ('libraryGoals', 'Objetivos de Biblioteca'),
}


def note_version(note):
    raw = {k: v for k, v in note.items() if k != 'note_version'}
    return hashlib.sha256(json.dumps(raw, sort_keys=True, ensure_ascii=False, separators=(',', ':')).encode('utf-8')).hexdigest()


def clean_content(value):
    if isinstance(value, dict):
        return {k: clean_content(v) for k, v in value.items()
                if not k.lower().endswith(('path', 'paths')) and not any(word in k.lower() for word in ('secret', 'token', 'credential'))}
    if isinstance(value, list):
        return [clean_content(v) for v in value]
    if isinstance(value, str) and (value.startswith(('file:', '/', '\\\\')) or (len(value) > 2 and value[1:3] in (':/', ':\\'))):
        return None
    return value


def normalized(value):
    return ''.join(c for c in unicodedata.normalize('NFD', value.casefold()) if not unicodedata.combining(c))


def values_text(value):
    if isinstance(value, dict):
        return ' '.join(values_text(v) for v in value.values())
    if isinstance(value, list):
        return ' '.join(values_text(v) for v in value)
    return str(value or '')


def browse(items, arguments, *, section, source):
    limit, offset = arguments.get('limit', 40), arguments.get('offset', 0)
    if type(limit) is not int or not 1 <= limit <= 100 or type(offset) is not int or offset < 0:
        raise ValueError('La página debe tener entre 1 y 100 fichas y un desplazamiento no negativo.')
    tokens = normalized(arguments.get('query', '')).split()
    selected = []
    for raw in items:
        item = clean_content(copy.deepcopy(raw))
        if section == 'notas':
            item['note_version'] = raw.get('note_version') or note_version(raw)
        if not arguments.get('include_archived', False) and (item.get('archived') or item.get('status') == 'archived'):
            continue
        if arguments.get('status') and item.get('status') != arguments['status']:
            continue
        if arguments.get('type') and item.get('type') != arguments['type']:
            continue
        if not all(token in normalized(values_text(item)) for token in tokens):
            continue
        selected.append(item)
    fields = ('id', 'name', 'title', 'content', 'note_version', 'type', 'status', 'category', 'subcategory', 'colors', 'tags', 'date', 'completedDate', 'rating', 'platform', 'targetYear', 'itemIds', 'outfitId', 'laundryStatus')
    summaries = [{key: (item[key][:240] if key == 'content' else item[key]) for key in fields if key in item} for item in selected[offset:offset + limit]]
    return {'section': section, 'items': summaries, 'total': len(selected), 'offset': offset,
            'next_offset': offset + limit if offset + limit < len(selected) else None, 'source': source}


def detail(items, item_id, *, section, source):
    for raw in items:
        if raw.get('id') == item_id:
            item = clean_content(copy.deepcopy(raw))
            if section == 'notas':
                item['note_version'] = raw.get('note_version') or note_version(raw)
            return {'section': section, 'item': item, 'source': source}
    raise ValueError('La ficha no existe en la colección indicada.')
