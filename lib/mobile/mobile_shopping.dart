class MobileShoppingProgress {
  MobileShoppingProgress([Map<String, dynamic>? source])
      : _data = source == null ? <String, dynamic>{} : _copy(source);

  final Map<String, dynamic> _data;

  factory MobileShoppingProgress.fromJson(Map<String, dynamic> json) =>
      MobileShoppingProgress(json);

  Map<String, dynamic> toJson() => _copy(_data);

  bool isBought(String listId, String itemId) =>
      _item(listId, itemId)['bought'] == true;

  int? priceCents(String listId, String itemId) =>
      (_item(listId, itemId)['priceCents'] as num?)?.toInt();

  int? receiptTotalCents(String listId) =>
      (_list(listId)['receiptTotalCents'] as num?)?.toInt();

  int totalCents(String listId, Iterable<String> itemIds) =>
      itemIds.fold(0, (sum, itemId) => sum + (priceCents(listId, itemId) ?? 0));

  MobileShoppingProgress withBought(String listId, String itemId, bool bought) {
    final next = toJson();
    final list = _mutableList(next, listId);
    final item = _mutableItem(list, itemId);
    item['bought'] = bought;
    return MobileShoppingProgress(next);
  }

  MobileShoppingProgress withPrice(String listId, String itemId, int? cents) {
    if (cents != null && cents < 0) throw ArgumentError.value(cents);
    final next = toJson();
    final item = _mutableItem(_mutableList(next, listId), itemId);
    if (cents == null) {
      item.remove('priceCents');
    } else {
      item['priceCents'] = cents;
    }
    return MobileShoppingProgress(next);
  }

  MobileShoppingProgress withReceiptTotal(String listId, int? cents) {
    if (cents != null && cents < 0) throw ArgumentError.value(cents);
    final next = toJson();
    final list = _mutableList(next, listId);
    if (cents == null) {
      list.remove('receiptTotalCents');
    } else {
      list['receiptTotalCents'] = cents;
    }
    return MobileShoppingProgress(next);
  }

  MobileShoppingProgress retainItems(String listId, Iterable<String> itemIds) {
    final next = toJson();
    final list = _mutableList(next, listId);
    final valid = itemIds.toSet();
    list.removeWhere(
        (key, _) => key != 'receiptTotalCents' && !valid.contains(key));
    return MobileShoppingProgress(next);
  }

  Map<String, dynamic> _list(String id) =>
      (_data[id] as Map?)?.cast<String, dynamic>() ?? const {};

  Map<String, dynamic> _item(String listId, String itemId) =>
      (_list(listId)[itemId] as Map?)?.cast<String, dynamic>() ?? const {};

  static Map<String, dynamic> _mutableList(
          Map<String, dynamic> data, String id) =>
      (data.putIfAbsent(id, () => <String, dynamic>{}) as Map)
          .cast<String, dynamic>();

  static Map<String, dynamic> _mutableItem(
          Map<String, dynamic> list, String id) =>
      (list.putIfAbsent(id, () => <String, dynamic>{}) as Map)
          .cast<String, dynamic>();

  static Map<String, dynamic> _copy(Map<String, dynamic> source) => {
        for (final entry in source.entries)
          entry.key: entry.value is Map
              ? _copy((entry.value as Map).cast<String, dynamic>())
              : entry.value,
      };
}
