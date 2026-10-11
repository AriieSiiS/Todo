part of 'app_shell.dart';

class _LibraryTypeListDialog extends StatelessWidget {
  const _LibraryTypeListDialog({
    required this.controller,
    required this.type,
    required this.items,
    required this.status,
    required this.showStatus,
  });

  final TodoWorkspace controller;
  final LibraryItemType type;
  final List<LibraryItem> items;
  final LibraryItemStatus? status;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final sorted = [...items]..sort((left, right) => _compareLibraryItems(
          left,
          right,
          status == LibraryItemStatus.completed
              ? LibrarySortOrder.newestFirst
              : LibrarySortOrder.titleAsc,
        ));
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 44, vertical: 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 18, 16),
              child: Row(
                children: [
                  Icon(_libraryIcon(type), color: _libraryColor(type)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _libraryTypePluralLabel(type),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                  ),
                  _miniBadge(
                    '${sorted.length} ${_libraryStatusCountLabel(status, sorted.length)}',
                    _libraryColor(type).withValues(alpha: 0.12),
                    _libraryColor(type),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: sorted.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Text(
                          _libraryEmptyStatusText(status),
                          style: TextStyle(color: context.visuals.textMuted),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: sorted.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = sorted[index];
                        return _LibraryItemRow(
                          item: item,
                          controller: controller,
                          showStatus: showStatus,
                          onTap: () async {
                            await _showLibraryItemDetails(
                              context,
                              controller,
                              items,
                              item,
                            );
                          },
                          onEdit: () => showDialog<void>(
                            context: context,
                            builder: (context) => _LibraryItemDialog(
                              controller: controller,
                              item: item,
                            ),
                          ),
                          onDelete: () => _deleteItem(context, item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteItem(BuildContext context, LibraryItem item) async {
    final confirmed = await _confirmLibraryDelete(
      context,
      title: 'Borrar de la biblioteca',
      message: _libraryDeleteMessage(controller, item),
    );
    if (confirmed) {
      controller.deleteLibraryItem(item.id);
    }
  }
}

class _LibrarySidePanel extends StatefulWidget {
  const _LibrarySidePanel({
    required this.controller,
    required this.items,
    required this.year,
  });

  final TodoWorkspace controller;
  final List<LibraryItem> items;
  final int year;

  @override
  State<_LibrarySidePanel> createState() => _LibrarySidePanelState();
}

class _LibrarySidePanelState extends State<_LibrarySidePanel> {
  bool _showAllRecent = false;
  bool _showAllYears = false;
  TodoWorkspace get controller => widget.controller;
  List<LibraryItem> get items => widget.items;
  int get year => widget.year;

  @override
  Widget build(BuildContext context) {
    final recent = [...items]..sort((left, right) =>
        (right.completedDate ?? right.updatedAt)
            .compareTo(left.completedDate ?? left.updatedAt));
    final yearCounts = <int, int>{};
    for (final item in items) {
      final itemYear = item.yearGroup;
      if (itemYear != null) {
        yearCounts[itemYear] = (yearCounts[itemYear] ?? 0) + 1;
      }
    }
    final years = yearCounts.keys.toList()..sort((a, b) => b.compareTo(a));
    final yearItems = items.where((item) => item.yearGroup == year).toList();

    return Column(
      children: [
        _SurfaceCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Recientes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (recent.isEmpty)
                Text(
                  'No hay elementos recientes.',
                  style: TextStyle(color: context.visuals.textMuted),
                )
              else
                for (final item
                    in recent.take(_showAllRecent ? recent.length : 4))
                  GestureDetector(
                    onSecondaryTapDown: (details) => _showLibraryContextMenu(
                      context: context,
                      position: details.globalPosition,
                      onPages: () =>
                          _openKnowledgeWorkspace(context, controller, item),
                      onEdit: () => _editItem(context, item),
                      onDelete: () => _deleteItem(context, item),
                    ),
                    child: InkWell(
                      onTap: () => _showLibraryItemDetails(
                        context,
                        controller,
                        items,
                        item,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _LibraryThumbnail(item: item, small: true),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Text(_libraryTypeSingularLabel(item),
                                          style: TextStyle(
                                              color: context.visuals.textMuted,
                                              fontSize: 12)),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: _libraryColor(item.type),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _libraryItemStatusMeta(item),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            color: context.visuals.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              if (recent.length > 4)
                _LibrarySideLink(
                  label: _showAllRecent
                      ? 'Ver menos recientes'
                      : 'Ver todos los recientes',
                  onTap: () => setState(() => _showAllRecent = !_showAllRecent),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SurfaceCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Años',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('Explora tu biblioteca por año',
                  style: TextStyle(color: context.visuals.textMuted)),
              const SizedBox(height: 8),
              if (years.isEmpty)
                Text(
                  'Aún no hay años registrados.',
                  style: TextStyle(color: context.visuals.textMuted),
                )
              else
                for (final value
                    in years.take(_showAllYears ? years.length : 3))
                  Container(
                    margin: const EdgeInsets.only(bottom: 5),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: value == year
                          ? const Color(0xFFE8F1DD)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text('$value')),
                        Text('${yearCounts[value]}'),
                      ],
                    ),
                  ),
              if (years.length > 3)
                _LibrarySideLink(
                  label:
                      _showAllYears ? 'Ver menos años' : 'Ver todos los años',
                  onTap: () => setState(() => _showAllYears = !_showAllYears),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _LibraryTotalsSideCard(items: yearItems, year: year),
      ],
    );
  }

  Future<void> _editItem(BuildContext context, LibraryItem item) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _LibraryItemDialog(
        controller: controller,
        item: item,
      ),
    );
  }

  Future<void> _deleteItem(BuildContext context, LibraryItem item) async {
    final confirmed = await _confirmLibraryDelete(
      context,
      title: 'Borrar de la biblioteca',
      message: _libraryDeleteMessage(controller, item),
    );
    if (confirmed) {
      controller.deleteLibraryItem(item.id);
    }
  }
}

class _LibraryTotalsSideCard extends StatelessWidget {
  const _LibraryTotalsSideCard({required this.items, required this.year});

  final List<LibraryItem> items;
  final int year;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Totales',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Resumen de completados en $year',
              style: TextStyle(color: context.visuals.textMuted)),
          const SizedBox(height: 10),
          _LibraryTotalRow(
            icon: Icons.bookmarks_outlined,
            color: const Color(0xFF7E9BB4),
            label: 'Total completados',
            value: items.length,
          ),
          const Divider(height: 12),
          for (final type in LibraryItemType.values)
            _LibraryTotalRow(
              icon: _libraryIcon(type),
              color: _libraryColor(type),
              label: _libraryTypePluralLabel(type),
              value: items.where((item) => item.type == type).length,
            ),
        ],
      ),
    );
  }
}

class _LibraryTotalRow extends StatelessWidget {
  const _LibraryTotalRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _LibrarySideLink extends StatelessWidget {
  const _LibrarySideLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(color: context.visuals.textMuted)),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

Future<void> _openKnowledgeWorkspace(
  BuildContext context,
  TodoWorkspace controller,
  LibraryItem item,
) {
  controller.openKnowledgeWorkspace(item);
  return Future<void>.value();
}

Future<void> _showLibraryContextMenu({
  required BuildContext context,
  required Offset position,
  VoidCallback? onPages,
  VoidCallback? onComplete,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) async {
  final overlay =
      Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
  if (overlay == null) {
    return;
  }
  final action = await showMenu<_LibraryContextAction>(
    context: context,
    position: RelativeRect.fromRect(
      position & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: [
      if (onPages != null)
        const PopupMenuItem(
          value: _LibraryContextAction.pages,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.description_outlined),
            title: Text('Abrir páginas'),
          ),
        ),
      if (onComplete != null)
        const PopupMenuItem(
          value: _LibraryContextAction.complete,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.check_circle_outline_rounded),
            title: Text('Marcar como completado'),
          ),
        ),
      const PopupMenuItem(
        value: _LibraryContextAction.edit,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.edit_outlined),
          title: Text('Editar'),
        ),
      ),
      const PopupMenuItem(
        value: _LibraryContextAction.delete,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.delete_outline_rounded),
          title: Text('Borrar'),
        ),
      ),
    ],
  );
  if (action == _LibraryContextAction.pages) {
    onPages?.call();
  } else if (action == _LibraryContextAction.complete) {
    onComplete?.call();
  } else if (action == _LibraryContextAction.edit) {
    onEdit();
  } else if (action == _LibraryContextAction.delete) {
    onDelete();
  }
}

Future<void> _showLibraryAddContextMenu({
  required BuildContext context,
  required Offset position,
  required TodoWorkspace controller,
  required LibraryItemType? selectedType,
  required LibraryItemStatus? status,
}) async {
  final overlay =
      Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
  if (overlay == null) {
    return;
  }
  final types = selectedType == null
      ? LibraryItemType.values
      : <LibraryItemType>[selectedType];
  final type = await showMenu<LibraryItemType>(
    context: context,
    position: RelativeRect.fromRect(
      position & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: [
      for (final type in types)
        PopupMenuItem(
          value: type,
          child: ListTile(
            dense: true,
            leading: Icon(_libraryIcon(type), color: _libraryColor(type)),
            title: Text(
                'Añadir ${_libraryTypeSingularLabelForType(type).toLowerCase()}'),
          ),
        ),
    ],
  );
  if (type == null || !context.mounted) {
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (context) => _LibraryItemDialog(
      controller: controller,
      initialType: type,
      initialStatus: status ?? LibraryItemStatus.pending,
    ),
  );
}

void _completeLibraryItem(
  BuildContext context,
  TodoWorkspace controller,
  LibraryItem item,
) {
  final previousStatus = item.status;
  if (previousStatus == LibraryItemStatus.completed) {
    return;
  }
  controller.updateLibraryItemStatus(item.id, LibraryItemStatus.completed);
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('“${item.title}” marcado como completado.'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => controller.updateLibraryItemStatus(
            item.id,
            previousStatus,
          ),
        ),
      ),
    );
}

Future<bool> _confirmLibraryDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8F3D35),
                foregroundColor: Colors.white,
              ),
              child: const Text('Borrar'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> _showLibraryItemDetails(
  BuildContext context,
  TodoWorkspace controller,
  List<LibraryItem> items,
  LibraryItem item,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => _LibraryItemDetailsDialog(
      controller: controller,
      items: items,
      item: item,
    ),
  );
}

class _LibraryItemDetailsDialog extends StatefulWidget {
  const _LibraryItemDetailsDialog({
    required this.controller,
    required this.items,
    required this.item,
  });

  final TodoWorkspace controller;
  final List<LibraryItem> items;
  final LibraryItem item;

  @override
  State<_LibraryItemDetailsDialog> createState() =>
      _LibraryItemDetailsDialogState();
}

class _LibraryItemDetailsDialogState extends State<_LibraryItemDetailsDialog> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.items.indexWhere((item) => item.id == widget.item.id);
    if (_index < 0) {
      _index = 0;
    }
  }

  LibraryItem get item {
    if (widget.items.isEmpty) {
      return widget.item;
    }
    final selected = widget.items[_index.clamp(0, widget.items.length - 1)];
    return widget.controller.libraryItems.firstWhere(
      (item) => item.id == selected.id,
      orElse: () => selected,
    );
  }

  bool get _hasPrevious => widget.items.isNotEmpty && _index > 0;
  bool get _hasNext =>
      widget.items.isNotEmpty && _index < widget.items.length - 1;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final item = this.item;
    final fields = _detailFields(item);
    final collectionLabels = _libraryCollectionLabels(widget.controller, item);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 22, 24, 18),
                child: Row(
                  children: [
                    Icon(_libraryIcon(item.type),
                        color: _libraryColor(item.type), size: 30),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 23, fontWeight: FontWeight.w800),
                          ),
                          if (collectionLabels != null) ...[
                            const SizedBox(height: 7),
                            _LibraryCollectionChips(
                              controller: widget.controller,
                              item: item,
                            ),
                          ],
                          const SizedBox(height: 3),
                          Text(_libraryTypeSingularLabel(item),
                              style: TextStyle(color: visuals.textMuted)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _LibraryDetailCover(item: item),
                      const SizedBox(width: 30),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_detailTitle(item.type),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 14),
                            for (final field in fields) ...[
                              _LibraryDetailLine(
                                  label: field.$1, value: field.$2),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 18),
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(100, 48),
                        backgroundColor: const Color(0xFFFFFCF8),
                        foregroundColor: visuals.textStrong,
                        side: const BorderSide(color: Color(0xFFE3D8CB)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cerrar'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        unawaited(_openKnowledgeWorkspace(
                          context,
                          widget.controller,
                          item,
                        ));
                      },
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('Abrir páginas'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(142, 48),
                        foregroundColor: visuals.textStrong,
                        side: const BorderSide(color: Color(0xFFE3D8CB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_hasPrevious) ...[
                      _LibraryNavigationButton(
                        label: 'Anterior',
                        icon: Icons.chevron_left_rounded,
                        onPressed: () => setState(() => _index--),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (_hasNext) ...[
                      _LibraryNavigationButton(
                        label: 'Siguiente',
                        trailingIcon: Icons.chevron_right_rounded,
                        onPressed: () => setState(() => _index++),
                      ),
                      const SizedBox(width: 10),
                    ],
                    FilledButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await showDialog<void>(
                          context: context,
                          builder: (context) => _LibraryItemDialog(
                            controller: widget.controller,
                            item: item,
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editar'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(124, 48),
                        backgroundColor: const Color(0xFF607A4D),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryDetailCover extends StatelessWidget {
  const _LibraryDetailCover({required this.item});

  final LibraryItem item;

  @override
  Widget build(BuildContext context) {
    final source = item.coverUrl?.trim();
    return SizedBox(
      key: const ValueKey('library-item-detail-cover'),
      width: 244,
      height: 416,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x260F1B0C),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE3D8CB)),
            ),
            child: _LibraryCoverImage(
              source: source,
              type: item.type,
              iconSize: 34,
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryNavigationButton extends StatelessWidget {
  const _LibraryNavigationButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (icon != null) ...[
        Icon(icon, size: 20),
        const SizedBox(width: 6),
      ],
      Text(label),
      if (trailingIcon != null) ...[
        const SizedBox(width: 6),
        Icon(trailingIcon, size: 20),
      ],
    ];
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(112, 48),
        backgroundColor: const Color(0xFFF5F8EF),
        foregroundColor: const Color(0xFF51693E),
        side: const BorderSide(color: Color(0xFFD7E4CC)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _LibraryDetailLine extends StatelessWidget {
  const _LibraryDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        border: Border.all(color: const Color(0xFFE3D8CB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_detailIcon(label), size: 17, color: const Color(0xFF607A4D)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: context.visuals.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.left,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _detailIcon(String label) {
  if (label.contains('Título')) return Icons.title_rounded;
  if (label.contains('Estado')) return Icons.check_circle_outline_rounded;
  if (label.contains('Valoración')) return Icons.star_outline_rounded;
  if (label.contains('Autor')) return Icons.person_outline_rounded;
  if (label.contains('Fecha')) return Icons.calendar_today_outlined;
  if (label.contains('Año')) return Icons.event_outlined;
  if (label.contains('Formato')) return Icons.menu_book_outlined;
  if (label.contains('Saga') || label.contains('colección')) {
    return Icons.collections_bookmark_outlined;
  }
  if (label.contains('Número')) return Icons.tag_rounded;
  if (label.contains('Mostrar')) return Icons.visibility_outlined;
  if (label.contains('Género')) return Icons.local_offer_outlined;
  if (label.contains('Páginas')) return Icons.article_outlined;
  if (label.contains('Plataforma')) return Icons.sports_esports_outlined;
  if (label.contains('Desarrollador')) return Icons.code_outlined;
  if (label.contains('Director') || label.contains('creador')) {
    return Icons.movie_filter_outlined;
  }
  if (label.contains('Duración') || label.contains('Horas')) {
    return Icons.schedule_outlined;
  }
  if (label.contains('País')) return Icons.public_outlined;
  if (label.contains('Notas')) return Icons.notes_outlined;
  return Icons.info_outline_rounded;
}

Future<void> _showLibraryGoalDetails(
  BuildContext context,
  TodoWorkspace controller,
  int year,
  List<LibraryGoal> goals,
  LibraryGoal goal,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => _LibraryGoalDetailsDialog(
      controller: controller,
      year: year,
      goals: goals,
      goal: goal,
    ),
  );
}
