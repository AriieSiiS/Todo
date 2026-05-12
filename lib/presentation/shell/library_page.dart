part of 'app_shell.dart';

enum _LibraryTab { library, goals }

enum _LibraryContextAction { edit, delete }

class LibraryPage extends StatefulWidget {
  const LibraryPage({required this.controller, super.key});

  final TodoWorkspace controller;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  _LibraryTab _tab = _LibraryTab.library;
  LibraryItemType? _typeFilter;
  int _year = 2026;
  double? _minRating;

  TodoWorkspace get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final items = _sortedItems(_filteredItems(controller.libraryItems));
    final yearItems = controller.libraryItems
        .where((item) => item.yearGroup == _year)
        .toList();
    final wide = MediaQuery.sizeOf(context).width >= 1320;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LibraryHeader(
            year: _year,
            isGoals: _tab == _LibraryTab.goals,
            onYearChanged: _selectYear,
            onAdd:
                _tab == _LibraryTab.goals ? _showAddGoalDialog : _showAddDialog,
          ),
          const SizedBox(height: 18),
          _LibraryTabs(
            tab: _tab,
            onChanged: (tab) => setState(() => _tab = tab),
          ),
          if (_tab == _LibraryTab.library) ...[
            const SizedBox(height: 14),
            _LibraryTypeFilters(
              selected: _typeFilter,
              onChanged: (type) => setState(() => _typeFilter = type),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: _tab == _LibraryTab.goals
                ? _LibraryGoalsView(
                    controller: controller,
                    year: _year,
                    onPreviousYear: () => setState(() => _year--),
                    onNextYear: () => setState(() => _year++),
                    onSelectYear: _selectYear,
                    onAdd: _showAddGoalDialog,
                  )
                : wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _LibraryMainContent(
                              controller: controller,
                              items: items,
                              yearItems: yearItems,
                              year: _year,
                              selectedType: _typeFilter,
                              fillAvailableHeight: true,
                            ),
                          ),
                          const SizedBox(width: 18),
                          SizedBox(
                            width: 330,
                            child: _LibrarySidePanel(
                              controller: controller,
                              items: controller.libraryItems,
                              year: _year,
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        children: [
                          _LibraryMainContent(
                            controller: controller,
                            items: items,
                            yearItems: yearItems,
                            year: _year,
                            selectedType: _typeFilter,
                            scrollColumns: false,
                          ),
                          const SizedBox(height: 16),
                          _LibrarySidePanel(
                            controller: controller,
                            items: controller.libraryItems,
                            year: _year,
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  List<LibraryItem> _filteredItems(List<LibraryItem> source) {
    return source
        .where((item) => item.yearGroup == _year)
        .where(
            (item) => _minRating == null || (item.rating ?? -1) >= _minRating!)
        .toList();
  }

  List<LibraryItem> _sortedItems(List<LibraryItem> source) {
    final sorted = [...source];
    sorted.sort((left, right) =>
        _compareLibraryItems(left, right, LibrarySortOrder.newestFirst));
    return sorted;
  }

  Future<void> _selectYear() async {
    final selected = await showMenu<int>(
      context: context,
      position: const RelativeRect.fromLTRB(0, 110, 24, 0),
      items: const [
        PopupMenuItem(value: 2026, child: Text('2026')),
        PopupMenuItem(value: 2025, child: Text('2025')),
        PopupMenuItem(value: 2024, child: Text('2024')),
      ],
    );
    if (selected != null && mounted) {
      setState(() => _year = selected);
    }
  }

  Future<void> _showAddDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _LibraryItemDialog(controller: controller),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showAddGoalDialog([LibraryItemType? type]) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _LibraryGoalDialog(
        controller: controller,
        year: _year,
        initialType: type,
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    required this.year,
    required this.isGoals,
    required this.onYearChanged,
    required this.onAdd,
  });

  final int year;
  final bool isGoals;
  final VoidCallback onYearChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Biblioteca',
                  style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 6),
              Text(
                'AquÃ­ se guardan los juegos, libros y pelÃ­culas/series que ya has completado.',
                style: TextStyle(
                  color: context.visuals.textMuted,
                  fontSize: 15,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.end,
          children: [
            if (isGoals)
              _HeaderSecondaryButton(
                label: '$year',
                icon: Icons.calendar_today_outlined,
                onPressed: onYearChanged,
              ),
            _HeaderActionButton(
              label: isGoals ? 'AÃ±adir propÃ³sito' : 'AÃ±adir completado',
              icon: Icons.add_rounded,
              onPressed: onAdd,
            ),
          ],
        ),
      ],
    );
  }
}

class _LibraryTabs extends StatelessWidget {
  const _LibraryTabs({required this.tab, required this.onChanged});

  final _LibraryTab tab;
  final ValueChanged<_LibraryTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LibraryTabButton(
          label: 'Biblioteca',
          active: tab == _LibraryTab.library,
          onTap: () => onChanged(_LibraryTab.library),
        ),
        const SizedBox(width: 24),
        _LibraryTabButton(
          label: 'PropÃ³sitos',
          active: tab == _LibraryTab.goals,
          onTap: () => onChanged(_LibraryTab.goals),
        ),
      ],
    );
  }
}

class _LibraryTabButton extends StatelessWidget {
  const _LibraryTabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? const Color(0xFF70835D) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF51693E) : context.visuals.textMuted,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _LibraryTypeFilters extends StatelessWidget {
  const _LibraryTypeFilters({required this.selected, required this.onChanged});

  final LibraryItemType? selected;
  final ValueChanged<LibraryItemType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _LibraryFilterChip(
          label: 'Todas',
          icon: Icons.inventory_2_outlined,
          active: selected == null,
          onTap: () => onChanged(null),
        ),
        for (final type in LibraryItemType.values)
          _LibraryFilterChip(
            label: _libraryTypePluralLabel(type),
            icon: _libraryIcon(type),
            active: selected == type,
            onTap: () => onChanged(type),
          ),
      ],
    );
  }
}

class _LibraryFilterChip extends StatelessWidget {
  const _LibraryFilterChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE8F1DD) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE4D7C7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF61764C)),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _LibraryMainContent extends StatelessWidget {
  const _LibraryMainContent({
    required this.controller,
    required this.items,
    required this.yearItems,
    required this.year,
    required this.selectedType,
    this.scrollColumns = true,
    this.fillAvailableHeight = false,
  });

  final TodoWorkspace controller;
  final List<LibraryItem> items;
  final List<LibraryItem> yearItems;
  final int year;
  final LibraryItemType? selectedType;
  final bool scrollColumns;
  final bool fillAvailableHeight;

  @override
  Widget build(BuildContext context) {
    if (selectedType != null) {
      final selectedItems =
          items.where((item) => item.type == selectedType).toList();
      final selectedYearItems =
          yearItems.where((item) => item.type == selectedType).toList();
      final single = _LibraryFilteredTypePanel(
        controller: controller,
        type: selectedType!,
        items: selectedItems,
        totalCount: selectedYearItems.length,
      );
      final content = fillAvailableHeight
          ? LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                height: constraints.maxHeight,
                child: single,
              ),
            )
          : single;
      return fillAvailableHeight
          ? content
          : scrollColumns
              ? SingleChildScrollView(child: content)
              : content;
    }

    final cards = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final type in LibraryItemType.values) ...[
          Expanded(
            child: _LibraryTypeCard(
              controller: controller,
              type: type,
              items: items.where((item) => item.type == type).toList(),
              allItems: yearItems.where((item) => item.type == type).toList(),
              totalCount: yearItems.where((item) => item.type == type).length,
            ),
          ),
          if (type != LibraryItemType.values.last) const SizedBox(width: 14),
        ],
      ],
    );
    final content = fillAvailableHeight
        ? LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                height: max(320.0, constraints.maxHeight),
                child: cards,
              );
            },
          )
        : SizedBox(height: 420, child: cards);
    if (fillAvailableHeight) {
      return content;
    }
    if (!scrollColumns) {
      return content;
    }
    return SingleChildScrollView(child: content);
  }
}

class _LibraryTypeCard extends StatelessWidget {
  const _LibraryTypeCard({
    required this.controller,
    required this.type,
    required this.items,
    required this.allItems,
    required this.totalCount,
  });

  final TodoWorkspace controller;
  final LibraryItemType type;
  final List<LibraryItem> items;
  final List<LibraryItem> allItems;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _libraryColor(type).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_libraryIcon(type), color: _libraryColor(type)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _libraryTypePluralLabel(type),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                _miniBadge(
                  '$totalCount completados',
                  _libraryColor(type).withValues(alpha: 0.12),
                  _libraryColor(type),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(18),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Text(
                        'No hay completados para este filtro.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.visuals.textMuted),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final item in items.take(5))
                          Column(
                            children: [
                              _LibraryItemRow(
                                item: item,
                                onTap: () => _showEditDialog(context, item),
                                onDelete: () => _deleteItem(context, item),
                              ),
                              if (item != items.take(5).last)
                                const Divider(height: 1),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
          InkWell(
            onTap: () => _showLibraryTypeList(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _librarySeeAllLabel(type, totalCount),
                      style: TextStyle(color: context.visuals.textMuted),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, LibraryItem item) async {
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
      message: 'Â¿Quieres borrar "${item.title}" de la biblioteca?',
    );
    if (confirmed) {
      controller.deleteLibraryItem(item.id);
    }
  }

  Future<void> _showLibraryTypeList(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _LibraryTypeListDialog(
        controller: controller,
        type: type,
        items: allItems,
      ),
    );
  }
}

class _LibraryFilteredTypePanel extends StatefulWidget {
  const _LibraryFilteredTypePanel({
    required this.controller,
    required this.type,
    required this.items,
    required this.totalCount,
  });

  final TodoWorkspace controller;
  final LibraryItemType type;
  final List<LibraryItem> items;
  final int totalCount;

  @override
  State<_LibraryFilteredTypePanel> createState() =>
      _LibraryFilteredTypePanelState();
}

class _LibraryFilteredTypePanelState extends State<_LibraryFilteredTypePanel> {
  LibrarySortOrder _sortOrder = LibrarySortOrder.newestFirst;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems(widget.items);
    final sorted = _sortedItems(filtered);
    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _libraryColor(widget.type).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _libraryIcon(widget.type),
                    color: _libraryColor(widget.type),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _libraryTypePluralLabel(widget.type),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                _miniBadge(
                  '${widget.totalCount} completados',
                  _libraryColor(widget.type).withValues(alpha: 0.12),
                  _libraryColor(widget.type),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 250,
                  child: _CompactLibrarySearchField(
                    controller: _searchController,
                    onChanged: () => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                _LibrarySortButton(
                  label: _sortLabelForType(_sortOrder, widget.type),
                  type: widget.type,
                  onSelected: (order) => setState(() => _sortOrder = order),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: Text(
                      'No hay completados para este filtro.',
                      style: TextStyle(color: context.visuals.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: sorted.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = sorted[index];
                      return _LibraryDetailedItemRow(
                        item: item,
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (context) => _LibraryItemDialog(
                            controller: widget.controller,
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
    );
  }

  List<LibraryItem> _filteredItems(List<LibraryItem> source) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return source;
    }
    return source
        .where((item) => _searchableText(item).toLowerCase().contains(query))
        .toList();
  }

  List<LibraryItem> _sortedItems(List<LibraryItem> source) {
    final sorted = [...source];
    sorted.sort((left, right) => _compareLibraryItems(left, right, _sortOrder));
    return sorted;
  }

  Future<void> _deleteItem(BuildContext context, LibraryItem item) async {
    final confirmed = await _confirmLibraryDelete(
      context,
      title: 'Borrar de la biblioteca',
      message: 'Â¿Quieres borrar "${item.title}" de la biblioteca?',
    );
    if (confirmed) {
      widget.controller.deleteLibraryItem(item.id);
    }
  }
}

class _CompactLibrarySearchField extends StatelessWidget {
  const _CompactLibrarySearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: controller.text.trim().isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Limpiar bÃºsqueda',
                  onPressed: () {
                    controller.clear();
                    onChanged();
                  },
                ),
        ),
      ),
    );
  }
}

class _LibrarySortButton extends StatelessWidget {
  const _LibrarySortButton({
    required this.label,
    required this.type,
    required this.onSelected,
  });

  final String label;
  final LibraryItemType type;
  final ValueChanged<LibrarySortOrder> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<LibrarySortOrder>(
      tooltip: 'Ordenar',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final order in _sortOptionsForType(type))
          PopupMenuItem(
            value: order,
            child: Text(_sortLabelForType(order, type)),
          ),
      ],
      child: IgnorePointer(
        child: _HeaderSecondaryButton(
          label: label,
          icon: Icons.expand_more_rounded,
          onPressed: () {},
        ),
      ),
    );
  }
}

class _LibraryDetailedItemRow extends StatelessWidget {
  const _LibraryDetailedItemRow({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final LibraryItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) => _showLibraryContextMenu(
        context: context,
        position: details.globalPosition,
        onEdit: onTap,
        onDelete: onDelete,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          child: Row(
            children: [
              _LibraryThumbnail(item: item),
              const SizedBox(width: 14),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(_libraryItemSubtitle(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.visuals.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                flex: 2,
                child: Text.rich(
                  TextSpan(
                    text: 'Completado el\n',
                    style: TextStyle(
                        color: context.visuals.textMuted, fontSize: 12),
                    children: [
                      TextSpan(
                        text: _libraryDate(item.completedDate),
                        style: TextStyle(
                          color: context.visuals.textStrong,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  item.releaseYear?.toString() ?? '-',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.visuals.textMuted),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  _libraryExtraInfo(item),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.visuals.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryItemRow extends StatelessWidget {
  const _LibraryItemRow({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final LibraryItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) => _showLibraryContextMenu(
        context: context,
        position: details.globalPosition,
        onEdit: onTap,
        onDelete: onDelete,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          child: Row(
            children: [
              _LibraryThumbnail(item: item),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _libraryDate(item.completedDate),
                style:
                    TextStyle(color: context.visuals.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryThumbnail extends StatelessWidget {
  const _LibraryThumbnail({required this.item, this.small = false});

  final LibraryItem item;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 34.0 : 52.0;
    final coverUrl = item.coverUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(small ? 10 : 12),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _libraryColor(item.type).withValues(alpha: 0.14),
        ),
        child: _LibraryCoverImage(
          source: coverUrl,
          type: item.type,
          iconSize: small ? 18 : 24,
        ),
      ),
    );
  }
}

class _LibraryTypeListDialog extends StatelessWidget {
  const _LibraryTypeListDialog({
    required this.controller,
    required this.type,
    required this.items,
  });

  final TodoWorkspace controller;
  final LibraryItemType type;
  final List<LibraryItem> items;

  @override
  Widget build(BuildContext context) {
    final sorted = [
      ...items
    ]..sort((left, right) => right.completedDate.compareTo(left.completedDate));
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
                    '${sorted.length} completados',
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
                          'No hay completados en esta categorÃ­a.',
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
                          onTap: () async {
                            await showDialog<void>(
                              context: context,
                              builder: (context) => _LibraryItemDialog(
                                controller: controller,
                                item: item,
                              ),
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
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
      message: 'Â¿Quieres borrar "${item.title}" de la biblioteca?',
    );
    if (confirmed) {
      controller.deleteLibraryItem(item.id);
    }
  }
}

class _LibrarySidePanel extends StatelessWidget {
  const _LibrarySidePanel({
    required this.controller,
    required this.items,
    required this.year,
  });

  final TodoWorkspace controller;
  final List<LibraryItem> items;
  final int year;

  @override
  Widget build(BuildContext context) {
    final recent = [
      ...items
    ]..sort((left, right) => right.completedDate.compareTo(left.completedDate));
    final yearCounts = <int, int>{};
    for (final item in items) {
      yearCounts[item.yearGroup] = (yearCounts[item.yearGroup] ?? 0) + 1;
    }
    final years = yearCounts.keys.toList()..sort((a, b) => b.compareTo(a));
    final yearItems = items.where((item) => item.yearGroup == year).toList();

    return Column(
      children: [
        _SurfaceCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Recientes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Ãšltimos completados',
                  style: TextStyle(color: context.visuals.textMuted)),
              const SizedBox(height: 16),
              if (recent.isEmpty)
                Text(
                  'No hay completados recientes.',
                  style: TextStyle(color: context.visuals.textMuted),
                )
              else
                for (final item in recent.take(5))
                  GestureDetector(
                    onSecondaryTapDown: (details) => _showLibraryContextMenu(
                      context: context,
                      position: details.globalPosition,
                      onEdit: () => _editItem(context, item),
                      onDelete: () => _deleteItem(context, item),
                    ),
                    child: InkWell(
                      onTap: () => _editItem(context, item),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
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
                                          _libraryDate(item.completedDate),
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
              _LibrarySideLink(label: 'Ver todos los recientes', onTap: () {}),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SurfaceCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('AÃ±os',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Explora tu biblioteca por aÃ±o',
                  style: TextStyle(color: context.visuals.textMuted)),
              const SizedBox(height: 14),
              if (years.isEmpty)
                Text(
                  'AÃºn no hay aÃ±os registrados.',
                  style: TextStyle(color: context.visuals.textMuted),
                )
              else
                for (final value in years.take(4))
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
              _LibrarySideLink(label: 'Ver todos los aÃ±os', onTap: () {}),
            ],
          ),
        ),
        const SizedBox(height: 14),
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
      message: 'Â¿Quieres borrar "${item.title}" de la biblioteca?',
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Totales',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Resumen de completados en $year',
              style: TextStyle(color: context.visuals.textMuted)),
          const SizedBox(height: 16),
          _LibraryTotalRow(
            icon: Icons.bookmarks_outlined,
            color: const Color(0xFF7E9BB4),
            label: 'Total completados',
            value: items.length,
          ),
          const Divider(height: 18),
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

Future<void> _showLibraryContextMenu({
  required BuildContext context,
  required Offset position,
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
    items: const [
      PopupMenuItem(
        value: _LibraryContextAction.edit,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.edit_outlined),
          title: Text('Editar'),
        ),
      ),
      PopupMenuItem(
        value: _LibraryContextAction.delete,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.delete_outline_rounded),
          title: Text('Borrar'),
        ),
      ),
    ],
  );
  if (action == _LibraryContextAction.edit) {
    onEdit();
  } else if (action == _LibraryContextAction.delete) {
    onDelete();
  }
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

class _LibraryGoalsView extends StatefulWidget {
  const _LibraryGoalsView({
    required this.controller,
    required this.year,
    required this.onPreviousYear,
    required this.onNextYear,
    required this.onSelectYear,
    required this.onAdd,
  });

  final TodoWorkspace controller;
  final int year;
  final VoidCallback onPreviousYear;
  final VoidCallback onNextYear;
  final VoidCallback onSelectYear;
  final VoidCallback onAdd;

  @override
  State<_LibraryGoalsView> createState() => _LibraryGoalsViewState();
}

class _LibraryGoalsViewState extends State<_LibraryGoalsView> {
  LibraryItemType? _selectedType;

  @override
  Widget build(BuildContext context) {
    final goals = widget.controller.libraryGoals
        .where((goal) => goal.targetYear == widget.year)
        .toList()
      ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
    final wide = MediaQuery.sizeOf(context).width >= 1320;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F1DD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.track_changes_rounded,
                  color: Color(0xFF70835D)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PropÃ³sitos',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    'Las cosas que quiero jugar, leer y ver este aÃ±o sÃ­ o sÃ­.',
                    style: TextStyle(color: context.visuals.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _LibraryTypeFilters(
          selected: _selectedType,
          onChanged: (value) => setState(() => _selectedType = value),
        ),
        const SizedBox(height: 18),
        if (_selectedType != null)
          wide
              ? Expanded(child: _filteredGoalsPanel(context, goals))
              : SizedBox(
                  height: 620,
                  child: _filteredGoalsPanel(context, goals),
                )
        else if (wide)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _LibraryGoalTypeCard(
                    type: LibraryItemType.game,
                    goals: goals
                        .where((goal) => goal.type == LibraryItemType.game)
                        .toList(),
                    onAdd: () =>
                        _showGoalDialogFor(context, LibraryItemType.game),
                    onEdit: (goal) => _showGoalEditDialog(context, goal),
                    onToggle: widget.controller.toggleLibraryGoalCompleted,
                    onFavorite: widget.controller.toggleLibraryGoalFavorite,
                    onDelete: (goal) => _deleteGoal(context, goal),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _LibraryGoalTypeCard(
                    type: LibraryItemType.book,
                    goals: goals
                        .where((goal) => goal.type == LibraryItemType.book)
                        .toList(),
                    onAdd: () =>
                        _showGoalDialogFor(context, LibraryItemType.book),
                    onEdit: (goal) => _showGoalEditDialog(context, goal),
                    onToggle: widget.controller.toggleLibraryGoalCompleted,
                    onFavorite: widget.controller.toggleLibraryGoalFavorite,
                    onDelete: (goal) => _deleteGoal(context, goal),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _LibraryGoalTypeCard(
                    type: LibraryItemType.movieSeries,
                    goals: goals
                        .where(
                            (goal) => goal.type == LibraryItemType.movieSeries)
                        .toList(),
                    onAdd: () => _showGoalDialogFor(
                        context, LibraryItemType.movieSeries),
                    onEdit: (goal) => _showGoalEditDialog(context, goal),
                    onToggle: widget.controller.toggleLibraryGoalCompleted,
                    onFavorite: widget.controller.toggleLibraryGoalFavorite,
                    onDelete: (goal) => _deleteGoal(context, goal),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              for (final type in LibraryItemType.values) ...[
                _LibraryGoalTypeCard(
                  type: type,
                  goals: goals.where((goal) => goal.type == type).toList(),
                  onAdd: () => _showGoalDialogFor(context, type),
                  onEdit: (goal) => _showGoalEditDialog(context, goal),
                  onToggle: widget.controller.toggleLibraryGoalCompleted,
                  onFavorite: widget.controller.toggleLibraryGoalFavorite,
                  onDelete: (goal) => _deleteGoal(context, goal),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
      ],
    );
    return wide ? content : SingleChildScrollView(child: content);
  }

  Future<void> _showGoalDialogFor(
      BuildContext context, LibraryItemType type) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _LibraryGoalDialog(
        controller: widget.controller,
        year: widget.year,
        initialType: type,
      ),
    );
  }

  Future<void> _showGoalEditDialog(
      BuildContext context, LibraryGoal goal) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _LibraryGoalDialog(
        controller: widget.controller,
        year: widget.year,
        initialType: goal.type,
        goal: goal,
      ),
    );
  }

  Widget _filteredGoalsPanel(BuildContext context, List<LibraryGoal> goals) {
    final selectedType = _selectedType!;
    return _LibraryGoalFilteredCardsPanel(
      type: selectedType,
      goals: goals.where((goal) => goal.type == selectedType).toList(),
      onAdd: () => _showGoalDialogFor(context, selectedType),
      onEdit: (goal) => _showGoalEditDialog(context, goal),
      onToggle: widget.controller.toggleLibraryGoalCompleted,
      onFavorite: widget.controller.toggleLibraryGoalFavorite,
      onDelete: (goal) => _deleteGoal(context, goal),
    );
  }

  Future<void> _deleteGoal(BuildContext context, LibraryGoal goal) async {
    final confirmed = await _confirmLibraryDelete(
      context,
      title: 'Borrar propÃ³sito',
      message: 'Â¿Quieres borrar "${goal.title}" de tus propÃ³sitos?',
    );
    if (confirmed) {
      widget.controller.deleteLibraryGoal(goal.id);
    }
  }
}

class _LibraryGoalFilteredCardsPanel extends StatelessWidget {
  const _LibraryGoalFilteredCardsPanel({
    required this.type,
    required this.goals,
    required this.onAdd,
    required this.onEdit,
    required this.onToggle,
    required this.onFavorite,
    required this.onDelete,
  });

  final LibraryItemType type;
  final List<LibraryGoal> goals;
  final VoidCallback onAdd;
  final ValueChanged<LibraryGoal> onEdit;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onFavorite;
  final ValueChanged<LibraryGoal> onDelete;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _libraryColor(type).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_libraryIcon(type), color: _libraryColor(type)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _libraryTypePluralLabel(type),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                _miniBadge(
                  '${goals.length} ${goals.length == 1 ? 'propÃ³sito' : 'propÃ³sitos'}',
                  _libraryColor(type).withValues(alpha: 0.12),
                  _libraryColor(type),
                ),
                const SizedBox(width: 12),
                _HeaderSecondaryButton(
                  label: _addGoalLabel(type),
                  icon: Icons.add_rounded,
                  onPressed: onAdd,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: goals.isEmpty
                ? Center(
                    child: Text(
                      _emptyGoalText(type),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.visuals.textMuted),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1180
                          ? 3
                          : constraints.maxWidth >= 760
                              ? 2
                              : 1;
                      return GridView.builder(
                        padding: const EdgeInsets.all(20),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 18,
                          mainAxisSpacing: 18,
                          childAspectRatio: columns == 1
                              ? 1.9
                              : columns == 2
                                  ? 1.22
                                  : 1.14,
                        ),
                        itemCount: goals.length,
                        itemBuilder: (context, index) {
                          final goal = goals[index];
                          return _LibraryGoalLargeCard(
                            goal: goal,
                            onEdit: () => onEdit(goal),
                            onToggle: () => onToggle(goal.id),
                            onFavorite: () => onFavorite(goal.id),
                            onDelete: () => onDelete(goal),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LibraryGoalLargeCard extends StatelessWidget {
  const _LibraryGoalLargeCard({
    required this.goal,
    required this.onEdit,
    required this.onToggle,
    required this.onFavorite,
    required this.onDelete,
  });

  final LibraryGoal goal;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final metadata = _goalMetadata(goal);
    return GestureDetector(
      onSecondaryTapDown: (details) => _showLibraryContextMenu(
        context: context,
        position: details.globalPosition,
        onEdit: onEdit,
        onDelete: onDelete,
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE7DCCF)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 7,
                child: Container(
                  color: _libraryColor(goal.type).withValues(alpha: 0.13),
                  child: _LibraryCoverImage(
                    source: goal.coverUrl?.trim(),
                    type: goal.type,
                    iconSize: 64,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 15, 14, 15),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: onToggle,
                      borderRadius: BorderRadius.circular(999),
                      child: Icon(
                        goal.isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 28,
                        color: goal.isCompleted
                            ? const Color(0xFF70835D)
                            : context.visuals.textMuted,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              decoration: goal.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: goal.isCompleted
                                      ? const Color(0xFF607A4D)
                                      : const Color(0xFF70835D),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                goal.isCompleted ? 'Completado' : 'Pendiente',
                                style: TextStyle(
                                  color: context.visuals.textMuted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          if (metadata != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              metadata,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.visuals.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onFavorite,
                      icon: Icon(
                        goal.isFavorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: goal.isFavorite
                            ? const Color(0xFFF1A340)
                            : context.visuals.textMuted,
                      ),
                      tooltip: 'Marcar como prioritario',
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

class _LibraryGoalTypeCard extends StatelessWidget {
  const _LibraryGoalTypeCard({
    required this.type,
    required this.goals,
    required this.onAdd,
    required this.onEdit,
    required this.onToggle,
    required this.onFavorite,
    required this.onDelete,
  });

  final LibraryItemType type;
  final List<LibraryGoal> goals;
  final VoidCallback onAdd;
  final ValueChanged<LibraryGoal> onEdit;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onFavorite;
  final ValueChanged<LibraryGoal> onDelete;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
            child: Row(
              children: [
                Icon(_libraryIcon(type), color: _libraryColor(type)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _libraryTypePluralLabel(type),
                    style: TextStyle(
                      color: _libraryColor(type),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _miniBadge(
                  '${goals.length}',
                  _libraryColor(type).withValues(alpha: 0.12),
                  _libraryColor(type),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: goals.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(18, 30, 18, 28),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Text(
                        _emptyGoalText(type),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.visuals.textMuted),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final goal in goals)
                          _LibraryGoalRow(
                            goal: goal,
                            onEdit: () => onEdit(goal),
                            onToggle: () => onToggle(goal.id),
                            onFavorite: () => onFavorite(goal.id),
                            onDelete: () => onDelete(goal),
                          ),
                      ],
                    ),
                  ),
          ),
          InkWell(
            onTap: onAdd,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
              child: Row(
                children: [
                  Icon(Icons.add_rounded, size: 18, color: _libraryColor(type)),
                  const SizedBox(width: 8),
                  Text(_addGoalLabel(type),
                      style: TextStyle(color: _libraryColor(type))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryGoalRow extends StatelessWidget {
  const _LibraryGoalRow({
    required this.goal,
    required this.onEdit,
    required this.onToggle,
    required this.onFavorite,
    required this.onDelete,
  });

  final LibraryGoal goal;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onSecondaryTapDown: (details) => _showLibraryContextMenu(
            context: context,
            position: details.globalPosition,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
          child: InkWell(
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                children: [
                  InkWell(
                    onTap: onToggle,
                    borderRadius: BorderRadius.circular(999),
                    child: Icon(
                      goal.isCompleted
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: goal.isCompleted
                          ? const Color(0xFF70835D)
                          : context.visuals.textMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _LibraryGoalThumbnail(goal: goal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      goal.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration: goal.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: goal.isCompleted
                            ? context.visuals.textMuted
                            : context.visuals.textStrong,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onFavorite,
                    icon: Icon(
                      goal.isFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: goal.isFavorite
                          ? const Color(0xFFF1A340)
                          : context.visuals.textMuted,
                    ),
                    tooltip: 'Marcar como prioritario',
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _LibraryGoalThumbnail extends StatelessWidget {
  const _LibraryGoalThumbnail({required this.goal});

  final LibraryGoal goal;

  @override
  Widget build(BuildContext context) {
    final coverUrl = goal.coverUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: _libraryColor(goal.type).withValues(alpha: 0.13),
        ),
        child: _LibraryCoverImage(
          source: coverUrl,
          type: goal.type,
          iconSize: 24,
        ),
      ),
    );
  }
}

class _LibraryCoverImage extends StatelessWidget {
  const _LibraryCoverImage({
    required this.source,
    required this.type,
    this.iconSize = 24,
  });

  final String? source;
  final LibraryItemType type;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final value = source?.trim();
    if (value == null || value.isEmpty) {
      return _LibraryCoverFallback(type: type, iconSize: iconSize);
    }
    if (_isLocalCoverPath(value)) {
      return Image.file(
        File(value),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _LibraryCoverFallback(type: type, iconSize: iconSize),
      );
    }
    return Image.network(
      value,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          _LibraryCoverFallback(type: type, iconSize: iconSize),
    );
  }
}

class _LibraryCoverFallback extends StatelessWidget {
  const _LibraryCoverFallback({required this.type, required this.iconSize});

  final LibraryItemType type;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Icon(
      _libraryIcon(type),
      color: _libraryColor(type),
      size: iconSize,
    );
  }
}

class _LibraryFilterResult {
  const _LibraryFilterResult({
    required this.type,
    required this.year,
    required this.query,
    required this.minRating,
  });

  final LibraryItemType? type;
  final int year;
  final String query;
  final double? minRating;
}

class _LibraryFilterDialog extends StatefulWidget {
  const _LibraryFilterDialog({
    required this.type,
    required this.year,
    required this.query,
    required this.minRating,
  });

  final LibraryItemType? type;
  final int year;
  final String query;
  final double? minRating;

  @override
  State<_LibraryFilterDialog> createState() => _LibraryFilterDialogState();
}

class _LibraryFilterDialogState extends State<_LibraryFilterDialog> {
  late LibraryItemType? _type = widget.type;
  late int _year = widget.year;
  late final TextEditingController _query =
      TextEditingController(text: widget.query);
  late final TextEditingController _rating = TextEditingController(
    text: widget.minRating == null ? '' : '${widget.minRating}',
  );

  @override
  void dispose() {
    _query.dispose();
    _rating.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filtros'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<LibraryItemType?>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Todas')),
                DropdownMenuItem(
                    value: LibraryItemType.game, child: Text('Juegos')),
                DropdownMenuItem(
                    value: LibraryItemType.book, child: Text('Libros')),
                DropdownMenuItem(
                  value: LibraryItemType.movieSeries,
                  child: Text('PelÃ­culas y series'),
                ),
              ],
              onChanged: (value) => setState(() => _type = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _year,
              decoration: const InputDecoration(labelText: 'AÃ±o'),
              items: const [
                DropdownMenuItem(value: 2026, child: Text('2026')),
                DropdownMenuItem(value: 2025, child: Text('2025')),
                DropdownMenuItem(value: 2024, child: Text('2024')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _year = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _query,
              decoration:
                  const InputDecoration(labelText: 'Buscar por tÃ­tulo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rating,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'ValoraciÃ³n mÃ­nima'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            const _LibraryFilterResult(
              type: null,
              year: 2026,
              query: '',
              minRating: null,
            ),
          ),
          child: const Text('Limpiar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _LibraryFilterResult(
              type: _type,
              year: _year,
              query: _query.text.trim(),
              minRating: double.tryParse(_rating.text.replaceAll(',', '.')),
            ),
          ),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

class _LibraryGoalDialog extends StatefulWidget {
  const _LibraryGoalDialog({
    required this.controller,
    required this.year,
    this.initialType,
    this.goal,
  });

  final TodoWorkspace controller;
  final int year;
  final LibraryItemType? initialType;
  final LibraryGoal? goal;

  @override
  State<_LibraryGoalDialog> createState() => _LibraryGoalDialogState();
}

class _LibraryGoalDialogState extends State<_LibraryGoalDialog> {
  late LibraryItemType _type = widget.initialType ?? LibraryItemType.game;
  LibraryMediaType _mediaType = LibraryMediaType.movie;
  late int _year = widget.year;
  bool _favorite = false;
  final _title = TextEditingController();
  final _platform = TextEditingController();
  final _developer = TextEditingController();
  final _author = TextEditingController();
  final _releaseYear = TextEditingController();
  final _creator = TextEditingController();
  final _genre = TextEditingController();
  final _format = TextEditingController();
  final _duration = TextEditingController();
  final _pages = TextEditingController();
  final _country = TextEditingController();
  final _note = TextEditingController();
  final _cover = TextEditingController();
  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    if (goal == null) {
      return;
    }
    _type = goal.type;
    _mediaType = goal.mediaType ?? LibraryMediaType.movie;
    _year = goal.targetYear;
    _favorite = goal.isFavorite;
    _title.text = goal.title;
    _platform.text = goal.platform ?? '';
    _developer.text = goal.developer ?? '';
    _author.text = goal.author ?? '';
    _releaseYear.text = goal.releaseYear?.toString() ?? '';
    _creator.text = goal.creatorOrDirector ?? '';
    _genre.text = goal.genre ?? '';
    _format.text = goal.format ?? '';
    _duration.text = goal.duration ?? '';
    _pages.text = goal.pages ?? '';
    _country.text = goal.country ?? '';
    _note.text = goal.note ?? '';
    _cover.text = goal.coverUrl ?? '';
  }

  @override
  void dispose() {
    _title.dispose();
    _platform.dispose();
    _developer.dispose();
    _author.dispose();
    _releaseYear.dispose();
    _creator.dispose();
    _genre.dispose();
    _format.dispose();
    _duration.dispose();
    _pages.dispose();
    _country.dispose();
    _note.dispose();
    _cover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 22, 24, 18),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book_rounded,
                        color: Color(0xFF607A4D), size: 30),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing
                                ? 'Editar propÃ³sito'
                                : 'AÃ±adir propÃ³sito',
                            style: const TextStyle(
                                fontSize: 23, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _isEditing
                                ? 'Actualiza los datos de este propÃ³sito.'
                                : 'Registra algo que quieres completar este aÃ±o.',
                            style: TextStyle(color: visuals.textMuted),
                          ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_isEditing) ...[
                        const Text('Tipo de contenido',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _LibraryContentTypeButton(
                                label: 'Juego',
                                icon: Icons.sports_esports_rounded,
                                active: _type == LibraryItemType.game,
                                onTap: () => setState(
                                    () => _type = LibraryItemType.game),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _LibraryContentTypeButton(
                                label: 'Libro / Manga',
                                icon: Icons.menu_book_rounded,
                                active: _type == LibraryItemType.book,
                                onTap: () => setState(
                                    () => _type = LibraryItemType.book),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _LibraryContentTypeButton(
                                label: 'PelÃ­cula / Serie / Anime',
                                icon: Icons.movie_creation_outlined,
                                active: _type == LibraryItemType.movieSeries,
                                onTap: () => setState(
                                    () => _type = LibraryItemType.movieSeries),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                      ],
                      Text(_goalDialogInfoTitle(),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LibraryImageDropField(
                            label: _goalImageLabel(),
                            type: _type,
                            icon: _libraryIcon(_type),
                            controller: _cover,
                          ),
                          const SizedBox(width: 20),
                          Expanded(child: _goalTypedFields()),
                        ],
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
                        side: const BorderSide(color: Color(0xFFE3D8CB)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancelar'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text(_isEditing ? 'Guardar' : 'Siguiente'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(132, 48),
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

  Widget _goalTypedFields() {
    return Column(
      children: [
        _goalDialogField(_title, 'TÃ­tulo *', _goalTitleHint()),
        const SizedBox(height: 16),
        if (_type == LibraryItemType.game) ...[
          Row(
            children: [
              Expanded(
                  child: _goalDialogField(_platform, 'Plataforma', 'Ej. PC')),
              const SizedBox(width: 14),
              Expanded(
                child: _goalDialogField(
                  _releaseYear,
                  'AÃ±o de lanzamiento',
                  'Ej. 2017',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _goalDialogField(
                    _developer, 'Desarrollador', 'Ej. Arkane Studios'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child:
                    _goalDialogField(_genre, 'GÃ©nero', 'Ej. Inmersivo, RPG'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _goalGameFormatField()),
              const SizedBox(width: 14),
              Expanded(
                  child: _goalDialogField(
                      _duration, 'Horas estimadas', 'Ej. 20 h')),
            ],
          ),
        ] else if (_type == LibraryItemType.book) ...[
          Row(
            children: [
              Expanded(
                  child: _goalDialogField(
                      _author, 'Autor', 'Ej. Samantha Shannon')),
              const SizedBox(width: 14),
              Expanded(
                child: _goalDialogField(
                  _releaseYear,
                  'AÃ±o de publicaciÃ³n',
                  'Ej. 2023',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _goalBookTypeField()),
              const SizedBox(width: 14),
              Expanded(child: _goalBookFormatField()),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child:
                    _goalDialogField(_genre, 'Genero', 'Ej. Fantasia, Clasico'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _goalDialogField(
                    _pages, 'Paginas / Volumenes', 'Ej. 864 paginas'),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(child: _goalMediaTypeField()),
              const SizedBox(width: 14),
              Expanded(
                child: _goalDialogField(
                  _releaseYear,
                  'AÃ±o de estreno',
                  'Ej. 1972',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _goalDialogField(
                  _duration,
                  'DuraciÃ³n',
                  'Ej. 2h 55m',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _goalDialogField(
                  _country,
                  'PaÃ­s de origen',
                  'Ej. Estados Unidos',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _goalDialogField(
                  _creator,
                  'Director / Creador',
                  'Ej. Francis Ford Coppola',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _goalDialogField(
                  _genre,
                  'GÃ©nero',
                  'Ej. Drama, AcciÃ³n',
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _goalYearField(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SwitchListTile(
                value: _favorite,
                onChanged: (value) => setState(() => _favorite = value),
                title: const Text('Prioritario'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _goalDialogField(_note, 'Nota opcional', 'AÃ±ade contexto o motivo...'),
      ],
    );
  }

  Widget _goalDialogField(
    TextEditingController controller,
    String label,
    String hint, {
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }

  Widget _goalBookTypeField() {
    return _goalDropdownTextField(
      label: 'Tipo *',
      controller: _creator,
      fallback: 'Libro',
      options: const ['Libro', 'Manga', 'CÃ³mic'],
    );
  }

  Widget _goalGameFormatField() {
    return _goalDropdownTextField(
      label: 'Formato *',
      controller: _format,
      fallback: 'Digital',
      options: const ['FÃ­sico', 'Digital'],
    );
  }

  Widget _goalBookFormatField() {
    return _goalDropdownTextField(
      label: 'Formato *',
      controller: _format,
      fallback: 'eBook',
      options: const ['FÃ­sico', 'eBook'],
    );
  }

  Widget _goalDropdownTextField({
    required String label,
    required TextEditingController controller,
    required String fallback,
    required List<String> options,
  }) {
    final current =
        options.contains(controller.text) ? controller.text : fallback;
    controller.text = current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: current,
          decoration: const InputDecoration(),
          items: [
            for (final option in options)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => controller.text = value);
            }
          },
        ),
      ],
    );
  }

  Widget _goalYearField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('AÃ±o *', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _year,
          decoration: const InputDecoration(),
          items: const [
            DropdownMenuItem(value: 2026, child: Text('2026')),
            DropdownMenuItem(value: 2025, child: Text('2025')),
            DropdownMenuItem(value: 2024, child: Text('2024')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _year = value);
            }
          },
        ),
      ],
    );
  }

  Widget _goalMediaTypeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tipo *', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        DropdownButtonFormField<LibraryMediaType>(
          initialValue: _mediaType,
          decoration: const InputDecoration(),
          items: const [
            DropdownMenuItem(
                value: LibraryMediaType.movie, child: Text('PelÃ­cula')),
            DropdownMenuItem(
                value: LibraryMediaType.series, child: Text('Serie')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _mediaType = value);
            }
          },
        ),
      ],
    );
  }

  String _goalDialogInfoTitle() => switch (_type) {
        LibraryItemType.game => 'InformaciÃ³n del juego',
        LibraryItemType.book => 'InformaciÃ³n del libro / manga',
        LibraryItemType.movieSeries =>
          'InformaciÃ³n de la pelÃ­cula / serie / anime',
      };

  String _goalTitleHint() => switch (_type) {
        LibraryItemType.game => 'Ej. Prey',
        LibraryItemType.book => 'Ej. El Priorato del Naranjo',
        LibraryItemType.movieSeries => 'Ej. El Padrino',
      };

  String _goalImageLabel() => switch (_type) {
        LibraryItemType.game => 'CarÃ¡tula',
        LibraryItemType.book => 'Portada',
        LibraryItemType.movieSeries => 'PÃ³ster',
      };

  void _save() {
    if (_title.text.trim().isEmpty) {
      return;
    }
    final goal = widget.goal;
    if (goal != null) {
      widget.controller.updateLibraryGoal(
        goal.copyWith(
          title: _title.text.trim(),
          targetYear: _year,
          isFavorite: _favorite,
          coverUrl: _cover.text.trim().isEmpty ? null : _cover.text.trim(),
          clearCoverUrl: _cover.text.trim().isEmpty,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          clearNote: _note.text.trim().isEmpty,
          platform:
              _type == LibraryItemType.game ? _platform.text.trim() : null,
          clearPlatform:
              _type != LibraryItemType.game || _platform.text.trim().isEmpty,
          developer:
              _type == LibraryItemType.game ? _developer.text.trim() : null,
          clearDeveloper:
              _type != LibraryItemType.game || _developer.text.trim().isEmpty,
          author: _type == LibraryItemType.book ? _author.text.trim() : null,
          clearAuthor:
              _type != LibraryItemType.book || _author.text.trim().isEmpty,
          mediaType: _type == LibraryItemType.movieSeries ? _mediaType : null,
          clearMediaType: _type != LibraryItemType.movieSeries,
          releaseYear: int.tryParse(_releaseYear.text),
          clearReleaseYear: _releaseYear.text.trim().isEmpty,
          creatorOrDirector: _type == LibraryItemType.movieSeries ||
                  _type == LibraryItemType.book
              ? _creator.text.trim()
              : null,
          clearCreatorOrDirector: (_type != LibraryItemType.movieSeries &&
                  _type != LibraryItemType.book) ||
              _creator.text.trim().isEmpty,
          genre: _genre.text.trim().isEmpty ? null : _genre.text.trim(),
          clearGenre: _genre.text.trim().isEmpty,
          format: _format.text.trim().isEmpty ? null : _format.text.trim(),
          clearFormat: _format.text.trim().isEmpty,
          duration:
              _duration.text.trim().isEmpty ? null : _duration.text.trim(),
          clearDuration: _duration.text.trim().isEmpty,
          pages: _type == LibraryItemType.book ? _pages.text.trim() : null,
          clearPages:
              _type != LibraryItemType.book || _pages.text.trim().isEmpty,
          country: _type == LibraryItemType.movieSeries
              ? _country.text.trim()
              : null,
          clearCountry: _type != LibraryItemType.movieSeries ||
              _country.text.trim().isEmpty,
        ),
      );
      Navigator.of(context).pop();
      return;
    }
    widget.controller.createLibraryGoal(
      type: _type,
      title: _title.text,
      targetYear: _year,
      isFavorite: _favorite,
      coverUrl: _cover.text,
      note: _note.text,
      platform: _type == LibraryItemType.game ? _platform.text : null,
      developer: _type == LibraryItemType.game ? _developer.text : null,
      author: _type == LibraryItemType.book ? _author.text : null,
      mediaType: _type == LibraryItemType.movieSeries ? _mediaType : null,
      releaseYear: int.tryParse(_releaseYear.text),
      creatorOrDirector:
          _type == LibraryItemType.movieSeries || _type == LibraryItemType.book
              ? _creator.text
              : null,
      genre: _genre.text,
      format: _format.text,
      duration: _duration.text,
      pages: _type == LibraryItemType.book ? _pages.text : null,
      country: _type == LibraryItemType.movieSeries ? _country.text : null,
    );
    Navigator.of(context).pop();
  }
}

class _LibraryItemDialog extends StatefulWidget {
  const _LibraryItemDialog({required this.controller, this.item});

  final TodoWorkspace controller;
  final LibraryItem? item;

  @override
  State<_LibraryItemDialog> createState() => _LibraryItemDialogState();
}

class _LibraryItemDialogState extends State<_LibraryItemDialog> {
  LibraryItemType _type = LibraryItemType.game;
  LibraryMediaType _mediaType = LibraryMediaType.movie;
  late DateTime _completedDate;
  final _title = TextEditingController();
  final _platform = TextEditingController();
  final _developer = TextEditingController();
  final _author = TextEditingController();
  final _releaseYear = TextEditingController();
  final _creator = TextEditingController();
  final _format = TextEditingController();
  final _genre = TextEditingController();
  final _duration = TextEditingController();
  final _country = TextEditingController();
  final _pages = TextEditingController();
  final _note = TextEditingController();
  final _rating = TextEditingController();
  final _cover = TextEditingController();
  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item == null) {
      _completedDate = DateTime.now();
      return;
    }
    _type = item.type;
    _mediaType = item.mediaType ?? LibraryMediaType.movie;
    _completedDate = item.completedDate;
    _title.text = item.title;
    _platform.text = item.platform ?? '';
    _developer.text = item.developer ?? '';
    _author.text = item.author ?? '';
    _releaseYear.text = item.releaseYear?.toString() ?? '';
    _creator.text = item.creatorOrDirector ?? '';
    _format.text = item.format ?? '';
    _genre.text = item.genre ?? '';
    _duration.text = item.duration ?? '';
    _country.text = item.country ?? '';
    _pages.text = item.pages ?? '';
    _note.text = item.note ?? '';
    _rating.text = item.rating?.toString() ?? '';
    _cover.text = item.coverUrl ?? '';
  }

  @override
  void dispose() {
    _title.dispose();
    _platform.dispose();
    _developer.dispose();
    _author.dispose();
    _releaseYear.dispose();
    _creator.dispose();
    _format.dispose();
    _genre.dispose();
    _duration.dispose();
    _country.dispose();
    _pages.dispose();
    _note.dispose();
    _rating.dispose();
    _cover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 22, 24, 18),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book_rounded,
                        color: Color(0xFF607A4D), size: 30),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing
                                ? 'Editar en la biblioteca'
                                : 'AÃ±adir a la biblioteca',
                            style: const TextStyle(
                                fontSize: 23, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _isEditing
                                ? 'Actualiza los datos de este registro.'
                                : 'Registra algo que ya has completado.',
                            style: TextStyle(color: visuals.textMuted),
                          ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_isEditing) ...[
                        const Text('Tipo de contenido',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _LibraryContentTypeButton(
                                label: 'Juego',
                                icon: Icons.sports_esports_rounded,
                                active: _type == LibraryItemType.game,
                                onTap: () => setState(
                                    () => _type = LibraryItemType.game),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _LibraryContentTypeButton(
                                label: 'Libro / Manga',
                                icon: Icons.menu_book_rounded,
                                active: _type == LibraryItemType.book,
                                onTap: () => setState(
                                    () => _type = LibraryItemType.book),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _LibraryContentTypeButton(
                                label: 'PelÃ­cula / Serie / Anime',
                                icon: Icons.movie_creation_outlined,
                                active: _type == LibraryItemType.movieSeries,
                                onTap: () => setState(
                                    () => _type = LibraryItemType.movieSeries),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                      ],
                      Text(_dialogInfoTitle(),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LibraryImageDropField(
                            label: _imageLabel(),
                            type: _type,
                            icon: _libraryIcon(_type),
                            controller: _cover,
                          ),
                          const SizedBox(width: 20),
                          Expanded(child: _typedFields()),
                        ],
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
                        side: const BorderSide(color: Color(0xFFE3D8CB)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancelar'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text(_isEditing ? 'Guardar' : 'Siguiente'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(132, 48),
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

  Widget _typedFields() {
    return switch (_type) {
      LibraryItemType.game => Column(
          children: [
            _dialogField(_title, 'TÃ­tulo *', 'Ej. Prey'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _dialogField(_platform, 'Plataforma *', 'Ej. PC')),
                const SizedBox(width: 14),
                Expanded(
                    child: _dialogField(
                        _releaseYear, 'AÃ±o de lanzamiento', 'Ej. 2017',
                        keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _dateField('Fecha completado *')),
                const SizedBox(width: 14),
                Expanded(child: _gameFormatField()),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _dialogField(
                        _developer, 'Desarrollador', 'Ej. Arkane Studios')),
                const SizedBox(width: 14),
                Expanded(
                    child: _dialogField(
                        _genre, 'GÃ©nero', 'Ej. Inmersivo, RPG...')),
              ],
            ),
            const SizedBox(height: 16),
            _dialogField(_duration, 'Horas jugadas', 'Ej. 28 h (opcional)'),
          ],
        ),
      LibraryItemType.book => Column(
          children: [
            _dialogField(_title, 'TÃ­tulo *', 'Ej. El Priorato del Naranjo'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _dialogField(
                        _author, 'Autor *', 'Ej. Samantha Shannon')),
                const SizedBox(width: 14),
                Expanded(
                    child: _dialogField(
                        _releaseYear, 'AÃ±o de publicaciÃ³n', 'Ej. 2023',
                        keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _dateField('Fecha completado *')),
                const SizedBox(width: 14),
                Expanded(child: _bookFormatField()),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _bookTypeField()),
                const SizedBox(width: 14),
                Expanded(
                    child: _dialogField(
                        _genre, 'GÃ©nero', 'Ej. FantasÃ­a, Manga...')),
              ],
            ),
            const SizedBox(height: 16),
            _dialogField(_pages, 'PÃ¡ginas / VolÃºmenes',
                'Ej. 832 pÃ¡ginas / 3 tomos (opcional)'),
          ],
        ),
      LibraryItemType.movieSeries => Column(
          children: [
            _dialogField(_title, 'TÃ­tulo *', 'Ej. El Padrino'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _mediaTypeField()),
                const SizedBox(width: 14),
                Expanded(
                    child: _dialogField(
                        _releaseYear, 'AÃ±o de estreno', 'Ej. 1972',
                        keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _dateField('Fecha completado / Visto *')),
                const SizedBox(width: 14),
                Expanded(
                    child: _dialogField(_duration, 'DuraciÃ³n', 'Ej. 2h 55m')),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _dialogField(_creator, 'Director / Creador',
                        'Ej. Francis Ford Coppola (opcional)')),
                const SizedBox(width: 14),
                Expanded(
                    child: _dialogField(
                        _genre, 'GÃ©nero', 'Ej. Drama, AcciÃ³n...')),
              ],
            ),
            const SizedBox(height: 16),
            _dialogField(
                _country, 'PaÃ­s de origen', 'Ej. Estados Unidos (opcional)'),
          ],
        ),
    };
  }

  Widget _dialogField(
      TextEditingController controller, String label, String hint,
      {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }

  Widget _dateField(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text(_libraryDate(_completedDate)),
          ),
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            minimumSize: const Size.fromHeight(48),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            side: const BorderSide(color: Color(0xFFE3D8CB)),
            foregroundColor: const Color(0xFF2D2A25),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _mediaTypeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tipo *', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        DropdownButtonFormField<LibraryMediaType>(
          initialValue: _mediaType,
          decoration: const InputDecoration(),
          items: const [
            DropdownMenuItem(
                value: LibraryMediaType.movie, child: Text('PelÃ­cula')),
            DropdownMenuItem(
                value: LibraryMediaType.series, child: Text('Serie')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _mediaType = value);
            }
          },
        ),
      ],
    );
  }

  Widget _bookTypeField() {
    return _dropdownTextField(
      label: 'Tipo *',
      controller: _creator,
      fallback: 'Libro',
      options: const ['Libro', 'Manga', 'CÃ³mic'],
    );
  }

  Widget _gameFormatField() {
    return _dropdownTextField(
      label: 'Formato *',
      controller: _format,
      fallback: 'Digital',
      options: const ['FÃ­sico', 'Digital'],
    );
  }

  Widget _bookFormatField() {
    return _dropdownTextField(
      label: 'Formato *',
      controller: _format,
      fallback: 'eBook',
      options: const ['FÃ­sico', 'eBook'],
    );
  }

  Widget _dropdownTextField({
    required String label,
    required TextEditingController controller,
    required String fallback,
    required List<String> options,
  }) {
    final current =
        options.contains(controller.text) ? controller.text : fallback;
    controller.text = current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: current,
          decoration: const InputDecoration(),
          items: [
            for (final option in options)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => controller.text = value);
            }
          },
        ),
      ],
    );
  }

  String _dialogInfoTitle() => switch (_type) {
        LibraryItemType.game => 'InformaciÃ³n del juego',
        LibraryItemType.book => 'InformaciÃ³n del libro / manga',
        LibraryItemType.movieSeries =>
          'InformaciÃ³n de la pelÃ­cula / serie / anime',
      };

  String _imageLabel() => switch (_type) {
        LibraryItemType.game => 'CarÃ¡tula',
        LibraryItemType.book => 'Portada',
        LibraryItemType.movieSeries => 'PÃ³ster',
      };

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      locale: const Locale('es', 'ES'),
      initialDate: _completedDate,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) {
      setState(() => _completedDate = selected);
    }
  }

  void _save() {
    if (_title.text.trim().isEmpty) {
      return;
    }
    final item = widget.item;
    if (item != null) {
      widget.controller.updateLibraryItem(
        item.copyWith(
          title: _title.text.trim(),
          completedDate: _completedDate,
          coverUrl: _cover.text.trim().isEmpty ? null : _cover.text.trim(),
          clearCoverUrl: _cover.text.trim().isEmpty,
          rating: double.tryParse(_rating.text.replaceAll(',', '.')),
          clearRating: _rating.text.trim().isEmpty,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          clearNote: _note.text.trim().isEmpty,
          platform:
              _type == LibraryItemType.game ? _platform.text.trim() : null,
          clearPlatform:
              _type != LibraryItemType.game || _platform.text.trim().isEmpty,
          developer:
              _type == LibraryItemType.game ? _developer.text.trim() : null,
          clearDeveloper:
              _type != LibraryItemType.game || _developer.text.trim().isEmpty,
          author: _type == LibraryItemType.book ? _author.text.trim() : null,
          clearAuthor:
              _type != LibraryItemType.book || _author.text.trim().isEmpty,
          mediaType: _type == LibraryItemType.movieSeries ? _mediaType : null,
          clearMediaType: _type != LibraryItemType.movieSeries,
          releaseYear: int.tryParse(_releaseYear.text),
          clearReleaseYear: _releaseYear.text.trim().isEmpty,
          creatorOrDirector: _type == LibraryItemType.movieSeries ||
                  _type == LibraryItemType.book
              ? _creator.text.trim()
              : null,
          clearCreatorOrDirector: (_type != LibraryItemType.movieSeries &&
                  _type != LibraryItemType.book) ||
              _creator.text.trim().isEmpty,
          genre: _genre.text.trim().isEmpty ? null : _genre.text.trim(),
          clearGenre: _genre.text.trim().isEmpty,
          format: _format.text.trim().isEmpty ? null : _format.text.trim(),
          clearFormat: _format.text.trim().isEmpty,
          duration:
              _duration.text.trim().isEmpty ? null : _duration.text.trim(),
          clearDuration: _duration.text.trim().isEmpty,
          pages: _type == LibraryItemType.book ? _pages.text.trim() : null,
          clearPages:
              _type != LibraryItemType.book || _pages.text.trim().isEmpty,
          country: _type == LibraryItemType.movieSeries
              ? _country.text.trim()
              : null,
          clearCountry: _type != LibraryItemType.movieSeries ||
              _country.text.trim().isEmpty,
        ),
      );
      Navigator.of(context).pop();
      return;
    }
    widget.controller.createLibraryItem(
      type: _type,
      title: _title.text,
      completedDate: _completedDate,
      coverUrl: _cover.text,
      rating: double.tryParse(_rating.text.replaceAll(',', '.')),
      note: _note.text,
      platform: _type == LibraryItemType.game ? _platform.text : null,
      developer: _type == LibraryItemType.game ? _developer.text : null,
      author: _type == LibraryItemType.book ? _author.text : null,
      mediaType: _type == LibraryItemType.movieSeries ? _mediaType : null,
      releaseYear: int.tryParse(_releaseYear.text),
      creatorOrDirector:
          _type == LibraryItemType.movieSeries || _type == LibraryItemType.book
              ? _creator.text
              : null,
      genre: _genre.text,
      format: _format.text,
      duration: _duration.text,
      pages: _type == LibraryItemType.book ? _pages.text : null,
      country: _type == LibraryItemType.movieSeries ? _country.text : null,
    );
    Navigator.of(context).pop();
  }
}

class _LibraryContentTypeButton extends StatelessWidget {
  const _LibraryContentTypeButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? const Color(0xFF607A4D) : const Color(0xFFE3D8CB),
            width: active ? 1.4 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFF607A4D).withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                color: active
                    ? const Color(0xFF607A4D)
                    : context.visuals.textStrong),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active
                      ? const Color(0xFF607A4D)
                      : context.visuals.textStrong,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryImageDropField extends StatelessWidget {
  const _LibraryImageDropField({
    required this.label,
    required this.type,
    required this.icon,
    required this.controller,
  });

  final String label;
  final LibraryItemType type;
  final IconData icon;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 176,
      child: Column(
        children: [
          InkWell(
            onTap: () => _pickCoverFile(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE3D8CB)),
              ),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final source = value.text.trim();
                  if (source.isNotEmpty) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _LibraryCoverImage(
                        source: source,
                        type: type,
                        iconSize: 34,
                      ),
                    );
                  }
                  return _LibraryImagePlaceholder(icon: icon, label: label);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCoverFile(BuildContext context) async {
    const typeGroup = XTypeGroup(
      label: 'ImÃ¡genes',
      extensions: <String>['jpg', 'jpeg', 'png', 'webp'],
      mimeTypes: <String>['image/jpeg', 'image/png', 'image/webp'],
    );
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file == null) {
      return;
    }
    final savedPath = await _copyLibraryCover(file);
    if (savedPath == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar la imagen seleccionada.'),
          ),
        );
      }
      return;
    }
    controller.text = savedPath;
  }
}

class _LibraryImagePlaceholder extends StatelessWidget {
  const _LibraryImagePlaceholder({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 34, color: context.visuals.textStrong),
        const SizedBox(height: 18),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'Haz clic para seleccionar una imagen',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.visuals.textMuted, height: 1.35),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'JPG, PNG Â· MÃ¡x. 5MB',
          style: TextStyle(color: context.visuals.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

IconData _libraryIcon(LibraryItemType type) => switch (type) {
      LibraryItemType.game => Icons.sports_esports_rounded,
      LibraryItemType.book => Icons.menu_book_rounded,
      LibraryItemType.movieSeries => Icons.movie_creation_outlined,
    };

Color _libraryColor(LibraryItemType type) => switch (type) {
      LibraryItemType.game => const Color(0xFF70835D),
      LibraryItemType.book => const Color(0xFF8F74D3),
      LibraryItemType.movieSeries => const Color(0xFFF1A340),
    };

String _libraryTypePluralLabel(LibraryItemType type) => switch (type) {
      LibraryItemType.game => 'Juegos',
      LibraryItemType.book => 'Libros',
      LibraryItemType.movieSeries => 'PelÃ­culas y series',
    };

String _libraryTypeSingularLabel(LibraryItem item) => switch (item.type) {
      LibraryItemType.game => 'Juego',
      LibraryItemType.book => 'Libro',
      LibraryItemType.movieSeries =>
        item.mediaType == LibraryMediaType.series ? 'Serie' : 'PelÃ­cula',
    };

String _libraryItemSubtitle(LibraryItem item) => switch (item.type) {
      LibraryItemType.game => _libraryGameSubtitle(item),
      LibraryItemType.book => item.author ?? 'Sin autor',
      LibraryItemType.movieSeries => item.releaseYear == null
          ? _libraryTypeSingularLabel(item)
          : '${item.releaseYear}',
    };

String _libraryGameSubtitle(LibraryItem item) {
  final parts = <String>[
    if (item.platform?.trim().isNotEmpty ?? false) item.platform!.trim(),
    if (item.genre?.trim().isNotEmpty ?? false) item.genre!.trim(),
  ];
  return parts.isEmpty ? 'Sin plataforma' : parts.join(' Â· ');
}

String _libraryExtraInfo(LibraryItem item) => switch (item.type) {
      LibraryItemType.game => item.developer ?? 'Sin desarrollador',
      LibraryItemType.book => _libraryBookExtraInfo(item),
      LibraryItemType.movieSeries => item.creatorOrDirector ?? 'Sin creador',
    };

String _libraryBookExtraInfo(LibraryItem item) {
  final parts = <String>[
    if (item.creatorOrDirector?.trim().isNotEmpty ?? false)
      item.creatorOrDirector!.trim(),
    if (item.format?.trim().isNotEmpty ?? false) item.format!.trim(),
    if (item.pages?.trim().isNotEmpty ?? false) item.pages!.trim(),
    if (item.genre?.trim().isNotEmpty ?? false) item.genre!.trim(),
  ];
  return parts.isEmpty ? 'Sin tipo' : parts.join(' Â· ');
}

String _librarySeeAllLabel(LibraryItemType type, int count) => switch (type) {
      LibraryItemType.game => 'Ver los $count juegos completados',
      LibraryItemType.book => 'Ver los $count libros completados',
      LibraryItemType.movieSeries =>
        'Ver las $count pelÃ­culas y series completadas',
    };

String _addGoalLabel(LibraryItemType type) => switch (type) {
      LibraryItemType.game => 'AÃ±adir juego',
      LibraryItemType.book => 'AÃ±adir libro',
      LibraryItemType.movieSeries => 'AÃ±adir pelÃ­cula o serie',
    };

String _emptyGoalText(LibraryItemType type) => switch (type) {
      LibraryItemType.game => 'No hay juegos en tus propÃ³sitos de este aÃ±o.',
      LibraryItemType.book => 'No hay libros en tus propÃ³sitos de este aÃ±o.',
      LibraryItemType.movieSeries =>
        'No hay pelÃ­culas ni series en tus propÃ³sitos de este aÃ±o.',
    };

String? _goalMetadata(LibraryGoal goal) {
  final parts = <String>[];
  switch (goal.type) {
    case LibraryItemType.game:
      if (goal.platform?.trim().isNotEmpty ?? false) {
        parts.add(goal.platform!.trim());
      }
      if (goal.developer?.trim().isNotEmpty ?? false) {
        parts.add(goal.developer!.trim());
      }
      break;
    case LibraryItemType.book:
      if (goal.author?.trim().isNotEmpty ?? false) {
        parts.add(goal.author!.trim());
      }
      if (goal.pages?.trim().isNotEmpty ?? false) {
        parts.add(goal.pages!.trim());
      }
      break;
    case LibraryItemType.movieSeries:
      if (goal.mediaType != null) {
        parts.add(
            goal.mediaType == LibraryMediaType.series ? 'Serie' : 'PelÃ­cula');
      }
      if (goal.creatorOrDirector?.trim().isNotEmpty ?? false) {
        parts.add(goal.creatorOrDirector!.trim());
      }
      if (goal.duration?.trim().isNotEmpty ?? false) {
        parts.add(goal.duration!.trim());
      }
      break;
  }
  if (goal.releaseYear != null) {
    parts.add('${goal.releaseYear}');
  }
  if (goal.genre?.trim().isNotEmpty ?? false) {
    parts.add(goal.genre!.trim());
  }
  return parts.isEmpty ? null : parts.join(' Â· ');
}

String _libraryDate(DateTime date) =>
    '${date.day} ${_monthShortLibrary(date.month)} ${date.year}';

String _monthShortLibrary(int month) => const [
      '',
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ][month];

String _sortLabel(LibrarySortOrder order) => switch (order) {
      LibrarySortOrder.newestFirst => 'MÃ¡s reciente',
      LibrarySortOrder.oldestFirst => 'MÃ¡s antiguo',
      LibrarySortOrder.titleAsc => 'A-Z',
      LibrarySortOrder.titleDesc => 'Z-A',
      LibrarySortOrder.highestRating => 'Mejor valoraciÃ³n',
      LibrarySortOrder.releaseYearDesc => 'AÃ±o de salida',
      LibrarySortOrder.releaseYearAsc => 'AÃ±o de salida antiguo',
      LibrarySortOrder.creatorAsc => 'Creador / autor',
      LibrarySortOrder.genreAsc => 'GÃ©nero',
      LibrarySortOrder.platformAsc => 'Plataforma',
      LibrarySortOrder.formatAsc => 'Formato',
      LibrarySortOrder.pagesDesc => 'MÃ¡s pÃ¡ginas',
      LibrarySortOrder.pagesAsc => 'Menos pÃ¡ginas',
      LibrarySortOrder.durationDesc => 'MÃ¡s duraciÃ³n',
      LibrarySortOrder.durationAsc => 'Menos duraciÃ³n',
      LibrarySortOrder.countryAsc => 'PaÃ­s',
    };

String _sortLabelForType(LibrarySortOrder order, LibraryItemType type) {
  if (order == LibrarySortOrder.releaseYearDesc) {
    return switch (type) {
      LibraryItemType.game => 'AÃ±o de salida',
      LibraryItemType.book => 'AÃ±o de publicaciÃ³n',
      LibraryItemType.movieSeries => 'AÃ±o de estreno',
    };
  }
  if (order == LibrarySortOrder.releaseYearAsc) {
    return switch (type) {
      LibraryItemType.game => 'Salida mÃ¡s antigua',
      LibraryItemType.book => 'PublicaciÃ³n mÃ¡s antigua',
      LibraryItemType.movieSeries => 'Estreno mÃ¡s antiguo',
    };
  }
  if (order == LibrarySortOrder.creatorAsc) {
    return switch (type) {
      LibraryItemType.game => 'Desarrollador',
      LibraryItemType.book => 'Autor',
      LibraryItemType.movieSeries => 'Director / creador',
    };
  }
  return _sortLabel(order);
}

List<LibrarySortOrder> _sortOptionsForType(LibraryItemType type) {
  final common = <LibrarySortOrder>[
    LibrarySortOrder.newestFirst,
    LibrarySortOrder.oldestFirst,
    LibrarySortOrder.titleAsc,
    LibrarySortOrder.titleDesc,
    LibrarySortOrder.releaseYearDesc,
    LibrarySortOrder.releaseYearAsc,
    LibrarySortOrder.creatorAsc,
    LibrarySortOrder.genreAsc,
    LibrarySortOrder.highestRating,
  ];
  return switch (type) {
    LibraryItemType.game => [
        ...common,
        LibrarySortOrder.platformAsc,
        LibrarySortOrder.formatAsc,
        LibrarySortOrder.durationDesc,
        LibrarySortOrder.durationAsc,
      ],
    LibraryItemType.book => [
        ...common,
        LibrarySortOrder.formatAsc,
        LibrarySortOrder.pagesDesc,
        LibrarySortOrder.pagesAsc,
      ],
    LibraryItemType.movieSeries => [
        ...common,
        LibrarySortOrder.durationDesc,
        LibrarySortOrder.durationAsc,
        LibrarySortOrder.countryAsc,
      ],
  };
}

// ignore: unused_element
String _searchHint(LibraryItemType type) => switch (type) {
      LibraryItemType.game =>
        'Buscar por t?tulo, plataforma, desarrollador o g?nero',
      LibraryItemType.book =>
        'Buscar por t?tulo, autor, g?nero, tipo o formato',
      LibraryItemType.movieSeries =>
        'Buscar por t?tulo, director, g?nero, pa?s o a?o',
    };

int _compareLibraryItems(
  LibraryItem left,
  LibraryItem right,
  LibrarySortOrder order,
) {
  final result = switch (order) {
    LibrarySortOrder.newestFirst =>
      right.completedDate.compareTo(left.completedDate),
    LibrarySortOrder.oldestFirst =>
      left.completedDate.compareTo(right.completedDate),
    LibrarySortOrder.titleAsc =>
      _sortText(left.title).compareTo(_sortText(right.title)),
    LibrarySortOrder.titleDesc =>
      _sortText(right.title).compareTo(_sortText(left.title)),
    LibrarySortOrder.highestRating =>
      (right.rating ?? -1).compareTo(left.rating ?? -1),
    LibrarySortOrder.releaseYearDesc =>
      (right.releaseYear ?? 0).compareTo(left.releaseYear ?? 0),
    LibrarySortOrder.releaseYearAsc =>
      (left.releaseYear ?? 9999).compareTo(right.releaseYear ?? 9999),
    LibrarySortOrder.creatorAsc =>
      _libraryCreator(left).compareTo(_libraryCreator(right)),
    LibrarySortOrder.genreAsc =>
      _sortText(left.genre).compareTo(_sortText(right.genre)),
    LibrarySortOrder.platformAsc =>
      _sortText(left.platform).compareTo(_sortText(right.platform)),
    LibrarySortOrder.formatAsc =>
      _sortText(left.format).compareTo(_sortText(right.format)),
    LibrarySortOrder.pagesDesc => _extractFirstNumber(right.pages)
        .compareTo(_extractFirstNumber(left.pages)),
    LibrarySortOrder.pagesAsc => _extractFirstNumber(left.pages)
        .compareTo(_extractFirstNumber(right.pages)),
    LibrarySortOrder.durationDesc => _extractFirstNumber(right.duration)
        .compareTo(_extractFirstNumber(left.duration)),
    LibrarySortOrder.durationAsc => _extractFirstNumber(left.duration)
        .compareTo(_extractFirstNumber(right.duration)),
    LibrarySortOrder.countryAsc =>
      _sortText(left.country).compareTo(_sortText(right.country)),
  };
  if (result != 0) {
    return result;
  }
  return _sortText(left.title).compareTo(_sortText(right.title));
}

String _searchableText(LibraryItem item) {
  return [
    item.title,
    item.platform,
    item.developer,
    item.author,
    item.mediaType?.name,
    item.releaseYear?.toString(),
    item.creatorOrDirector,
    item.genre,
    item.format,
    item.duration,
    item.pages,
    item.country,
    item.note,
  ].whereType<String>().join(' ');
}

String _libraryCreator(LibraryItem item) {
  return _sortText(switch (item.type) {
    LibraryItemType.game => item.developer ?? item.creatorOrDirector,
    LibraryItemType.book => item.author ?? item.creatorOrDirector,
    LibraryItemType.movieSeries => item.creatorOrDirector,
  });
}

String _sortText(String? value) => (value ?? '').trim().toLowerCase();

int _extractFirstNumber(String? value) {
  final match = RegExp(r'\d+').firstMatch(value ?? '');
  return match == null ? 0 : int.tryParse(match.group(0)!) ?? 0;
}

bool _isLocalCoverPath(String value) {
  final lower = value.toLowerCase();
  return RegExp(r'^[a-z]:[\\/]').hasMatch(lower) ||
      lower.startsWith('\\\\') ||
      lower.startsWith('/');
}

Future<String?> _copyLibraryCover(XFile file) async {
  final extension = _coverExtension(file.name);
  if (extension == null) {
    return null;
  }
  final bytes = await file.readAsBytes();
  const maxBytes = 5 * 1024 * 1024;
  if (bytes.length > maxBytes) {
    return null;
  }
  final directory = await _libraryCoversDirectory();
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final target =
      File('${directory.path}${Platform.pathSeparator}cover_$stamp$extension');
  await target.writeAsBytes(bytes, flush: true);
  return target.path;
}

String? _coverExtension(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return '.jpg';
  }
  if (lower.endsWith('.png')) {
    return '.png';
  }
  if (lower.endsWith('.webp')) {
    return '.webp';
  }
  return null;
}

Future<Directory> _libraryCoversDirectory() async {
  final home = Platform.environment['USERPROFILE'] ??
      Platform.environment['HOME'] ??
      Directory.current.path;
  final documents = Directory('$home${Platform.pathSeparator}Documents');
  final base = documents.existsSync()
      ? Directory('${documents.path}${Platform.pathSeparator}Todo')
      : Directory(home);
  final covers = Directory(
    '${base.path}${Platform.pathSeparator}library_covers',
  );
  if (!await covers.exists()) {
    await covers.create(recursive: true);
  }
  return covers;
}
