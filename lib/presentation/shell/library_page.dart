part of 'app_shell.dart';

enum _LibraryTab { library, goals }

class LibraryPage extends StatefulWidget {
  const LibraryPage({required this.controller, super.key});

  final TodoWorkspace controller;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  _LibraryTab _tab = _LibraryTab.library;
  LibraryItemType? _typeFilter;
  LibrarySortOrder _sortOrder = LibrarySortOrder.newestFirst;
  int _year = 2026;
  String _query = '';
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
            sortOrder: _sortOrder,
            isGoals: _tab == _LibraryTab.goals,
            onYearChanged: _selectYear,
            onAdd:
                _tab == _LibraryTab.goals ? _showAddGoalDialog : _showAddDialog,
            onFilter: _showFilterMenu,
            onSort: _showSortMenu,
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
        .where((item) =>
            _query.trim().isEmpty ||
            item.title.toLowerCase().contains(_query.trim().toLowerCase()))
        .where(
            (item) => _minRating == null || (item.rating ?? -1) >= _minRating!)
        .toList();
  }

  List<LibraryItem> _sortedItems(List<LibraryItem> source) {
    final sorted = [...source];
    sorted.sort((left, right) {
      return switch (_sortOrder) {
        LibrarySortOrder.newestFirst =>
          right.completedDate.compareTo(left.completedDate),
        LibrarySortOrder.oldestFirst =>
          left.completedDate.compareTo(right.completedDate),
        LibrarySortOrder.titleAsc =>
          left.title.toLowerCase().compareTo(right.title.toLowerCase()),
        LibrarySortOrder.titleDesc =>
          right.title.toLowerCase().compareTo(left.title.toLowerCase()),
        LibrarySortOrder.highestRating =>
          (right.rating ?? -1).compareTo(left.rating ?? -1),
      };
    });
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

  Future<void> _showFilterMenu() async {
    final result = await showDialog<_LibraryFilterResult>(
      context: context,
      builder: (context) => _LibraryFilterDialog(
        type: _typeFilter,
        year: _year,
        query: _query,
        minRating: _minRating,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _typeFilter = result.type;
        _year = result.year;
        _query = result.query;
        _minRating = result.minRating;
      });
    }
  }

  Future<void> _showSortMenu() async {
    final selected = await showMenu<LibrarySortOrder>(
      context: context,
      position: const RelativeRect.fromLTRB(0, 110, 24, 0),
      items: const [
        PopupMenuItem(
          value: LibrarySortOrder.newestFirst,
          child: Text('Más reciente primero'),
        ),
        PopupMenuItem(
          value: LibrarySortOrder.oldestFirst,
          child: Text('Más antiguo primero'),
        ),
        PopupMenuItem(value: LibrarySortOrder.titleAsc, child: Text('A-Z')),
        PopupMenuItem(value: LibrarySortOrder.titleDesc, child: Text('Z-A')),
        PopupMenuItem(
          value: LibrarySortOrder.highestRating,
          child: Text('Mejor valoración'),
        ),
      ],
    );
    if (selected != null && mounted) {
      setState(() => _sortOrder = selected);
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
    required this.sortOrder,
    required this.isGoals,
    required this.onYearChanged,
    required this.onAdd,
    required this.onFilter,
    required this.onSort,
  });

  final int year;
  final LibrarySortOrder sortOrder;
  final bool isGoals;
  final VoidCallback onYearChanged;
  final VoidCallback onAdd;
  final VoidCallback onFilter;
  final VoidCallback onSort;

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
                'Aquí se guardan los juegos, libros y películas/series que ya has completado.',
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
            _HeaderSecondaryButton(
              label: '$year',
              icon: Icons.calendar_today_outlined,
              onPressed: onYearChanged,
            ),
            if (!isGoals) ...[
              _HeaderSecondaryButton(
                label: 'Filtrar',
                icon: Icons.filter_alt_outlined,
                onPressed: onFilter,
              ),
              _HeaderSecondaryButton(
                label: _sortLabel(sortOrder),
                icon: Icons.swap_vert_rounded,
                onPressed: onSort,
              ),
            ],
            _HeaderActionButton(
              label: isGoals ? 'Añadir propósito' : 'Añadir completado',
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
          label: 'Propósitos',
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
    final summary = [
      _LibrarySummaryData(
        title: 'Total completados',
        value: '${yearItems.length}',
        subtitle: 'en $year',
        icon: Icons.bookmarks_outlined,
        color: const Color(0xFF7E9BB4),
      ),
      _summaryForType(yearItems, LibraryItemType.game),
      _summaryForType(yearItems, LibraryItemType.book),
      _summaryForType(yearItems, LibraryItemType.movieSeries),
    ];
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
    final summaryGrid = GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisExtent: 112,
        crossAxisSpacing: 14,
      ),
      itemCount: summary.length,
      itemBuilder: (context, index) => _LibrarySummaryCard(summary[index]),
    );
    final content = fillAvailableHeight
        ? LayoutBuilder(
            builder: (context, constraints) {
              final cardHeight = max(320.0, constraints.maxHeight - 130);
              return Column(
                children: [
                  summaryGrid,
                  const SizedBox(height: 18),
                  SizedBox(height: cardHeight, child: cards),
                ],
              );
            },
          )
        : Column(
            children: [
              summaryGrid,
              const SizedBox(height: 18),
              cards,
            ],
          );
    if (!scrollColumns) {
      return content;
    }
    return SingleChildScrollView(child: content);
  }
}

class _LibrarySummaryData {
  const _LibrarySummaryData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _LibrarySummaryCard extends StatelessWidget {
  const _LibrarySummaryCard(this.data);

  final _LibrarySummaryData data;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(data.icon, color: data.color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(data.value,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w700)),
                Text(data.subtitle,
                    style: TextStyle(color: context.visuals.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
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
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'all', child: Text('Ver todos')),
                  ],
                  onSelected: (_) => _showLibraryTypeList(context),
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

class _LibraryFilteredTypePanel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final sorted = [
      ...items
    ]..sort((left, right) => right.completedDate.compareTo(left.completedDate));
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
                        fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                _miniBadge(
                  '$totalCount completados',
                  _libraryColor(type).withValues(alpha: 0.12),
                  _libraryColor(type),
                ),
                const SizedBox(width: 12),
                _HeaderSecondaryButton(
                  label: 'Más reciente',
                  icon: Icons.expand_more_rounded,
                  onPressed: () {},
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
                            controller: controller,
                            item: item,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LibraryDetailedItemRow extends StatelessWidget {
  const _LibraryDetailedItemRow({required this.item, required this.onTap});

  final LibraryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
                  style:
                      TextStyle(color: context.visuals.textMuted, fontSize: 12),
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
    );
  }
}

class _LibraryItemRow extends StatelessWidget {
  const _LibraryItemRow({required this.item, required this.onTap});

  final LibraryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        child: Row(
          children: [
            _LibraryThumbnail(item: item),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _libraryItemSubtitle(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.visuals.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _libraryDate(item.completedDate),
              style: TextStyle(color: context.visuals.textMuted, fontSize: 13),
            ),
          ],
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
                          'No hay completados en esta categoría.',
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
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibrarySidePanel extends StatelessWidget {
  const _LibrarySidePanel({required this.items, required this.year});

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
              Text('Últimos completados',
                  style: TextStyle(color: context.visuals.textMuted)),
              const SizedBox(height: 16),
              if (recent.isEmpty)
                Text(
                  'No hay completados recientes.',
                  style: TextStyle(color: context.visuals.textMuted),
                )
              else
                for (final item in recent.take(5))
                  Padding(
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
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
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
              const Text('Años',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Explora tu biblioteca por año',
                  style: TextStyle(color: context.visuals.textMuted)),
              const SizedBox(height: 14),
              if (years.isEmpty)
                Text(
                  'Aún no hay años registrados.',
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
              _LibrarySideLink(label: 'Ver todos los años', onTap: () {}),
            ],
          ),
        ),
      ],
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

class _LibraryGoalsView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final goals = controller.libraryGoals
        .where((goal) => goal.targetYear == year)
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
                  const Text('Propósitos',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    'Las cosas que quiero jugar, leer y ver este año sí o sí.',
                    style: TextStyle(color: context.visuals.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (wide)
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
                    onToggle: controller.toggleLibraryGoalCompleted,
                    onFavorite: controller.toggleLibraryGoalFavorite,
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
                    onToggle: controller.toggleLibraryGoalCompleted,
                    onFavorite: controller.toggleLibraryGoalFavorite,
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
                    onToggle: controller.toggleLibraryGoalCompleted,
                    onFavorite: controller.toggleLibraryGoalFavorite,
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
                  onToggle: controller.toggleLibraryGoalCompleted,
                  onFavorite: controller.toggleLibraryGoalFavorite,
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
        controller: controller,
        year: year,
        initialType: type,
      ),
    );
  }

  Future<void> _showGoalEditDialog(
      BuildContext context, LibraryGoal goal) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _LibraryGoalDialog(
        controller: controller,
        year: year,
        initialType: goal.type,
        goal: goal,
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
  });

  final LibraryItemType type;
  final List<LibraryGoal> goals;
  final VoidCallback onAdd;
  final ValueChanged<LibraryGoal> onEdit;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onFavorite;

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
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'add', child: Text('Añadir')),
                  ],
                  onSelected: (_) => onAdd(),
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
  });

  final LibraryGoal goal;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
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
                      decoration:
                          goal.isCompleted ? TextDecoration.lineThrough : null,
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
                  child: Text('Películas y series'),
                ),
              ],
              onChanged: (value) => setState(() => _type = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _year,
              decoration: const InputDecoration(labelText: 'Año'),
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
              decoration: const InputDecoration(labelText: 'Buscar por título'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rating,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Valoración mínima'),
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
  final _author = TextEditingController();
  final _releaseYear = TextEditingController();
  final _creator = TextEditingController();
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
    _author.text = goal.author ?? '';
    _releaseYear.text = goal.releaseYear?.toString() ?? '';
    _creator.text = goal.creatorOrDirector ?? '';
    _note.text = goal.note ?? '';
    _cover.text = goal.coverUrl ?? '';
  }

  @override
  void dispose() {
    _title.dispose();
    _platform.dispose();
    _author.dispose();
    _releaseYear.dispose();
    _creator.dispose();
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
                                ? 'Editar propósito'
                                : 'Añadir propósito',
                            style: const TextStyle(
                                fontSize: 23, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _isEditing
                                ? 'Actualiza los datos de este propósito.'
                                : 'Registra algo que quieres completar este año.',
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
                                label: 'Película / Serie / Anime',
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
        _goalDialogField(_title, 'Título *', _goalTitleHint()),
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
                  'Año de lanzamiento',
                  'Ej. 2017',
                  keyboardType: TextInputType.number,
                ),
              ),
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
                  'Año de publicación',
                  'Ej. 2023',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ] else ...[
          Row(
            children: [
              Expanded(child: _goalMediaTypeField()),
              const SizedBox(width: 14),
              Expanded(
                child: _goalDialogField(
                  _releaseYear,
                  'Año de estreno',
                  'Ej. 1972',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _goalDialogField(
            _creator,
            'Director / Creador',
            'Ej. Francis Ford Coppola (opcional)',
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
        _goalDialogField(_note, 'Nota opcional', 'Añade contexto o motivo...'),
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

  Widget _goalYearField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Año *', style: TextStyle(fontWeight: FontWeight.w700)),
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
                value: LibraryMediaType.movie, child: Text('Película')),
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
        LibraryItemType.game => 'Información del juego',
        LibraryItemType.book => 'Información del libro / manga',
        LibraryItemType.movieSeries =>
          'Información de la película / serie / anime',
      };

  String _goalTitleHint() => switch (_type) {
        LibraryItemType.game => 'Ej. Prey',
        LibraryItemType.book => 'Ej. El Priorato del Naranjo',
        LibraryItemType.movieSeries => 'Ej. El Padrino',
      };

  String _goalImageLabel() => switch (_type) {
        LibraryItemType.game => 'Carátula',
        LibraryItemType.book => 'Portada',
        LibraryItemType.movieSeries => 'Póster',
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
          author: _type == LibraryItemType.book ? _author.text.trim() : null,
          clearAuthor:
              _type != LibraryItemType.book || _author.text.trim().isEmpty,
          mediaType: _type == LibraryItemType.movieSeries ? _mediaType : null,
          clearMediaType: _type != LibraryItemType.movieSeries,
          releaseYear: int.tryParse(_releaseYear.text),
          clearReleaseYear: _releaseYear.text.trim().isEmpty,
          creatorOrDirector: _type == LibraryItemType.movieSeries
              ? _creator.text.trim()
              : null,
          clearCreatorOrDirector: _type != LibraryItemType.movieSeries ||
              _creator.text.trim().isEmpty,
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
      author: _type == LibraryItemType.book ? _author.text : null,
      mediaType: _type == LibraryItemType.movieSeries ? _mediaType : null,
      releaseYear: int.tryParse(_releaseYear.text),
      creatorOrDirector:
          _type == LibraryItemType.movieSeries ? _creator.text : null,
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
                                : 'Añadir a la biblioteca',
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
                                label: 'Película / Serie / Anime',
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
            _dialogField(_title, 'Título *', 'Ej. Prey'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _dialogField(_platform, 'Plataforma *', 'Ej. PC')),
                const SizedBox(width: 14),
                Expanded(
                    child: _dialogField(
                        _releaseYear, 'Año de lanzamiento', 'Ej. 2017',
                        keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _dateField('Fecha completado *')),
                const SizedBox(width: 14),
                Expanded(child: _dialogField(_format, 'Formato', 'Digital')),
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
                        _genre, 'Género', 'Ej. Inmersivo, RPG...')),
              ],
            ),
            const SizedBox(height: 16),
            _dialogField(_duration, 'Horas jugadas', 'Ej. 28 h (opcional)'),
          ],
        ),
      LibraryItemType.book => Column(
          children: [
            _dialogField(_title, 'Título *', 'Ej. El Priorato del Naranjo'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _dialogField(
                        _author, 'Autor *', 'Ej. Samantha Shannon')),
                const SizedBox(width: 14),
                Expanded(
                    child: _dialogField(
                        _releaseYear, 'Año de publicación', 'Ej. 2023',
                        keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _dateField('Fecha completado *')),
                const SizedBox(width: 14),
                Expanded(
                    child: _dialogField(_format, 'Formato', 'Libro físico')),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _dialogField(_creator, 'Tipo', 'Libro')),
                const SizedBox(width: 14),
                Expanded(
                    child: _dialogField(
                        _genre, 'Género', 'Ej. Fantasía, Manga...')),
              ],
            ),
            const SizedBox(height: 16),
            _dialogField(_pages, 'Páginas / Volúmenes',
                'Ej. 832 páginas / 3 tomos (opcional)'),
          ],
        ),
      LibraryItemType.movieSeries => Column(
          children: [
            _dialogField(_title, 'Título *', 'Ej. El Padrino'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _mediaTypeField()),
                const SizedBox(width: 14),
                Expanded(
                    child: _dialogField(
                        _releaseYear, 'Año de estreno', 'Ej. 1972',
                        keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _dateField('Fecha completado / Visto *')),
                const SizedBox(width: 14),
                Expanded(
                    child: _dialogField(_duration, 'Duración', 'Ej. 2h 55m')),
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
                    child:
                        _dialogField(_genre, 'Género', 'Ej. Drama, Acción...')),
              ],
            ),
            const SizedBox(height: 16),
            _dialogField(
                _country, 'País de origen', 'Ej. Estados Unidos (opcional)'),
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
                value: LibraryMediaType.movie, child: Text('Película')),
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

  String _dialogInfoTitle() => switch (_type) {
        LibraryItemType.game => 'Información del juego',
        LibraryItemType.book => 'Información del libro / manga',
        LibraryItemType.movieSeries =>
          'Información de la película / serie / anime',
      };

  String _imageLabel() => switch (_type) {
        LibraryItemType.game => 'Carátula',
        LibraryItemType.book => 'Portada',
        LibraryItemType.movieSeries => 'Póster',
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
          creatorOrDirector: _type == LibraryItemType.movieSeries
              ? _creator.text.trim()
              : null,
          clearCreatorOrDirector: _type != LibraryItemType.movieSeries ||
              _creator.text.trim().isEmpty,
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
          _type == LibraryItemType.movieSeries ? _creator.text : null,
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
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            minLines: 1,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'URL de imagen opcional',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCoverFile(BuildContext context) async {
    const typeGroup = XTypeGroup(
      label: 'Imágenes',
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
            'Arrastra una imagen o pega una URL',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.visuals.textMuted, height: 1.35),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'JPG, PNG · Máx. 5MB',
          style: TextStyle(color: context.visuals.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

_LibrarySummaryData _summaryForType(
    List<LibraryItem> items, LibraryItemType type) {
  final count = items.where((item) => item.type == type).length;
  return _LibrarySummaryData(
    title: _libraryTypePluralLabel(type),
    value: '$count',
    subtitle:
        type == LibraryItemType.movieSeries ? 'completadas' : 'completados',
    icon: _libraryIcon(type),
    color: _libraryColor(type),
  );
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
      LibraryItemType.movieSeries => 'Películas y series',
    };

String _libraryTypeSingularLabel(LibraryItem item) => switch (item.type) {
      LibraryItemType.game => 'Juego',
      LibraryItemType.book => 'Libro',
      LibraryItemType.movieSeries =>
        item.mediaType == LibraryMediaType.series ? 'Serie' : 'Película',
    };

String _libraryItemSubtitle(LibraryItem item) => switch (item.type) {
      LibraryItemType.game => item.platform ?? 'Sin plataforma',
      LibraryItemType.book => item.author ?? 'Sin autor',
      LibraryItemType.movieSeries => item.releaseYear == null
          ? _libraryTypeSingularLabel(item)
          : '${item.releaseYear}',
    };

String _libraryExtraInfo(LibraryItem item) => switch (item.type) {
      LibraryItemType.game => item.developer ?? 'Sin desarrollador',
      LibraryItemType.book => item.creatorOrDirector ?? 'Sin tipo',
      LibraryItemType.movieSeries => item.creatorOrDirector ?? 'Sin creador',
    };

String _librarySeeAllLabel(LibraryItemType type, int count) => switch (type) {
      LibraryItemType.game => 'Ver los $count juegos completados',
      LibraryItemType.book => 'Ver los $count libros completados',
      LibraryItemType.movieSeries =>
        'Ver las $count películas y series completadas',
    };

String _addGoalLabel(LibraryItemType type) => switch (type) {
      LibraryItemType.game => 'Añadir juego',
      LibraryItemType.book => 'Añadir libro',
      LibraryItemType.movieSeries => 'Añadir película o serie',
    };

String _emptyGoalText(LibraryItemType type) => switch (type) {
      LibraryItemType.game => 'No hay juegos en tus propósitos de este año.',
      LibraryItemType.book => 'No hay libros en tus propósitos de este año.',
      LibraryItemType.movieSeries =>
        'No hay películas ni series en tus propósitos de este año.',
    };

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
      LibrarySortOrder.newestFirst => 'Más reciente',
      LibrarySortOrder.oldestFirst => 'Más antiguo',
      LibrarySortOrder.titleAsc => 'A-Z',
      LibrarySortOrder.titleDesc => 'Z-A',
      LibrarySortOrder.highestRating => 'Mejor valoración',
    };

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
