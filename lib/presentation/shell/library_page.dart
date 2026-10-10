part of 'app_shell.dart';

enum _LibraryContextAction { pages, complete, edit, delete }

enum _LibraryOverviewMode { columns, covers }

class LibraryPage extends StatefulWidget {
  const LibraryPage({required this.controller, super.key});

  final TodoWorkspace controller;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  LibraryItemType? _typeFilter;
  LibraryItemType? _goalsTypeFilter;
  _LibraryOverviewMode _overviewMode = _LibraryOverviewMode.covers;
  LibrarySortOrder _allSortOrder = LibrarySortOrder.newestFirst;
  late final TextEditingController _allSearchController;
  late int _year = DateTime.now().year;
  double? _minRating;
  bool _showAllStatuses = false;

  TodoWorkspace get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _allSearchController = TextEditingController();
    // Completados era el valor histórico inicial, así que Todo es la nueva
    // vista inicial. Los filtros Pendiente y En curso sí representan una
    // elección anterior persistida y se mantienen al volver a abrir.
    _showAllStatuses =
        controller.libraryStatusView == LibraryItemStatus.completed;
  }

  @override
  void dispose() {
    _allSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = controller.visibilitySettings.visibleTabs(AppSection.library);
    final areas = LibraryAreaView.values
        .where((area) => tabs.contains(area.name))
        .toList();
    final area = areas.contains(controller.libraryAreaView)
        ? controller.libraryAreaView
        : areas.first;
    final status = _showAllStatuses ? null : controller.libraryStatusView;
    final statusFilteredItems = _filteredItems(controller.libraryItems, status);
    final items = _typeFilter == null
        ? _filterAndSortAllItems(statusFilteredItems)
        : _sortedItems(statusFilteredItems);
    final statusItems = status == null
        ? controller.libraryItems
        : controller.libraryItems
            .where((item) => item.status == status)
            .toList();
    final yearItems = status == LibraryItemStatus.completed
        ? statusItems.where((item) => item.yearGroup == _year).toList()
        : statusItems;
    final currentYear = DateTime.now().year;
    final availableYears = <int>{
      currentYear,
      if (area == LibraryAreaView.goals)
        for (final goal in controller.libraryGoals) goal.targetYear
      else
        for (final item in controller.libraryItems)
          if (item.completedDate != null) item.completedDate!.year,
    }.toList()
      ..sort((left, right) => right.compareTo(left));
    final wide = MediaQuery.sizeOf(context).width >= 1320;

    return DefaultTabController(
      key: ValueKey(tabs.join(',')),
      length: tabs.length,
      initialIndex: areas.indexOf(area),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: _LibraryHeader(
                year: _year,
                currentYear: currentYear,
                availableYears: availableYears,
                isGoals: area == LibraryAreaView.goals,
                libraryStatus: status,
                onYearChanged: (year) => setState(() => _year = year),
                onAdd: area == LibraryAreaView.goals
                    ? _showAddGoalDialog
                    : _showAddDialog,
              ),
            ),
            const SizedBox(height: 6),
            _SectionTabBar(
              labels: tabs
                  .map((id) =>
                      AppVisibilitySettings.tabs[AppSection.library]![id]!)
                  .toList(),
              onTap: (index) {
                final next = areas[index];
                controller.setLibraryAreaView(next);
                setState(() {});
              },
            ),
            if (area == LibraryAreaView.library) ...[
              const SizedBox(height: 12),
              _LibraryStatusTabs(
                status: status,
                onChanged: (value) {
                  setState(() {
                    _showAllStatuses = value == null;
                    if (value != null) {
                      controller.setLibraryStatusView(value);
                    }
                    if (value == LibraryItemStatus.completed &&
                        !availableYears.contains(_year)) {
                      _year = currentYear;
                    }
                  });
                },
              ),
            ],
            const SizedBox(height: 14),
            Expanded(
              child: area == LibraryAreaView.goals
                  ? _LibraryGoalsView(
                      controller: controller,
                      year: _year,
                      selectedType: _goalsTypeFilter,
                      onSelectedTypeChanged: (type) =>
                          setState(() => _goalsTypeFilter = type),
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
                                onSelectedTypeChanged: (type) =>
                                    setState(() => _typeFilter = type),
                                status: status,
                                showStatus: false,
                                overviewMode: _overviewMode,
                                onOverviewModeChanged: (mode) =>
                                    setState(() => _overviewMode = mode),
                                allSearchController: _allSearchController,
                                allSortOrder: _allSortOrder,
                                onAllSearchChanged: () => setState(() {}),
                                onAllSortChanged: (order) =>
                                    setState(() => _allSortOrder = order),
                                fillAvailableHeight: true,
                              ),
                            ),
                            const SizedBox(width: 18),
                            SizedBox(
                              width: 330,
                              child: SingleChildScrollView(
                                child: _LibrarySidePanel(
                                  controller: controller,
                                  items: controller.libraryItems,
                                  year: _year,
                                ),
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
                              onSelectedTypeChanged: (type) =>
                                  setState(() => _typeFilter = type),
                              status: status,
                              showStatus: false,
                              overviewMode: _overviewMode,
                              onOverviewModeChanged: (mode) =>
                                  setState(() => _overviewMode = mode),
                              allSearchController: _allSearchController,
                              allSortOrder: _allSortOrder,
                              onAllSearchChanged: () => setState(() {}),
                              onAllSortChanged: (order) =>
                                  setState(() => _allSortOrder = order),
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
      ),
    );
  }

  List<LibraryItem> _filteredItems(
    List<LibraryItem> source,
    LibraryItemStatus? status,
  ) {
    return source
        .where((item) => status == null || item.status == status)
        .where((item) =>
            status != LibraryItemStatus.completed || item.yearGroup == _year)
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

  List<LibraryItem> _filterAndSortAllItems(List<LibraryItem> source) {
    final query = _allSearchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? source
        : source
            .where(
              (item) => _searchableText(item).toLowerCase().contains(query),
            )
            .toList();
    final sorted = [...filtered];
    sorted.sort(
      (left, right) => _compareLibraryItems(left, right, _allSortOrder),
    );
    return sorted;
  }

  Future<void> _showAddDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _LibraryItemDialog(
        controller: controller,
        initialStatus: controller.libraryStatusView,
      ),
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
    required this.currentYear,
    required this.availableYears,
    required this.isGoals,
    required this.libraryStatus,
    required this.onYearChanged,
    required this.onAdd,
  });

  final int year;
  final int currentYear;
  final List<int> availableYears;
  final bool isGoals;
  final LibraryItemStatus? libraryStatus;
  final ValueChanged<int> onYearChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return _PageHeader(
      title: 'Biblioteca',
      subtitle: '',
      compact: true,
      pinTrailingToEdge: true,
      trailing: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.end,
        children: [
          if (isGoals || libraryStatus == LibraryItemStatus.completed)
            _LibraryGoalYearButton(
              year: year,
              currentYear: currentYear,
              availableYears: availableYears,
              onSelected: onYearChanged,
            ),
          _HeaderActionButton(
            label: isGoals ? 'Añadir propósito' : 'Añadir a Biblioteca',
            icon: Icons.add_rounded,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _LibraryGoalYearButton extends StatelessWidget {
  const _LibraryGoalYearButton({
    required this.year,
    required this.currentYear,
    required this.availableYears,
    required this.onSelected,
  });

  final int year;
  final int currentYear;
  final List<int> availableYears;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final historicalYears = availableYears
        .where((candidate) => candidate < currentYear)
        .toList(growable: false);
    final label = year < currentYear ? 'Histórico · $year' : '$year';

    if (historicalYears.isEmpty) {
      return _HeaderSecondaryButton(
        label: label,
        icon: Icons.calendar_today_outlined,
        onPressed: null,
      );
    }

    return PopupMenuButton<int>(
      tooltip: 'Cambiar año',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      constraints: const BoxConstraints(minWidth: 180),
      onSelected: onSelected,
      itemBuilder: (context) => [
        const PopupMenuItem<int>(
          enabled: false,
          height: 34,
          child: Text(
            'Año actual',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        PopupMenuItem<int>(
          value: currentYear,
          child: Text('$currentYear'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<int>(
          enabled: false,
          height: 34,
          child: Text(
            'Histórico',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        for (final historicalYear in historicalYears)
          PopupMenuItem<int>(
            value: historicalYear,
            child: Text('$historicalYear'),
          ),
      ],
      child: IgnorePointer(
        child: _HeaderSecondaryButton(
          label: label,
          icon: Icons.calendar_today_outlined,
          onPressed: () {},
        ),
      ),
    );
  }
}

class _LibraryStatusTabs extends StatelessWidget {
  const _LibraryStatusTabs({required this.status, required this.onChanged});

  final LibraryItemStatus? status;
  final ValueChanged<LibraryItemStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in const [
          LibraryItemStatus.completed,
          LibraryItemStatus.inProgress,
          LibraryItemStatus.pending,
        ])
          _FilterPill(
            label: _libraryStatusPluralLabel(value),
            icon: _libraryStatusIcon(value),
            selected: status == value,
            onTap: () => onChanged(value),
          ),
        _FilterPill(
          label: 'Todo',
          icon: Icons.select_all_rounded,
          selected: status == null,
          onTap: () => onChanged(null),
        ),
      ],
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
        _FilterPill(
          label: 'Todas',
          icon: Icons.inventory_2_outlined,
          selected: selected == null,
          onTap: () => onChanged(null),
        ),
        for (final type in LibraryItemType.values)
          _FilterPill(
            label: _libraryTypePluralLabel(type),
            icon: _libraryIcon(type),
            selected: selected == type,
            onTap: () => onChanged(type),
          ),
      ],
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
    required this.onSelectedTypeChanged,
    required this.status,
    required this.showStatus,
    required this.overviewMode,
    required this.onOverviewModeChanged,
    required this.allSearchController,
    required this.allSortOrder,
    required this.onAllSearchChanged,
    required this.onAllSortChanged,
    this.scrollColumns = true,
    this.fillAvailableHeight = false,
  });

  final TodoWorkspace controller;
  final List<LibraryItem> items;
  final List<LibraryItem> yearItems;
  final int year;
  final LibraryItemType? selectedType;
  final ValueChanged<LibraryItemType?> onSelectedTypeChanged;
  final LibraryItemStatus? status;
  final bool showStatus;
  final _LibraryOverviewMode overviewMode;
  final ValueChanged<_LibraryOverviewMode> onOverviewModeChanged;
  final TextEditingController allSearchController;
  final LibrarySortOrder allSortOrder;
  final VoidCallback onAllSearchChanged;
  final ValueChanged<LibrarySortOrder> onAllSortChanged;
  final bool scrollColumns;
  final bool fillAvailableHeight;

  @override
  Widget build(BuildContext context) {
    final typeFilters = _LibraryTypeFilters(
      selected: selectedType,
      onChanged: onSelectedTypeChanged,
    );
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
        status: status,
        showStatus: false,
        typeFilters: typeFilters,
      );
      final contextualSingle = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapDown: (details) => _showLibraryAddContextMenu(
          context: context,
          position: details.globalPosition,
          controller: controller,
          selectedType: selectedType,
          status: status,
        ),
        child: single,
      );
      final content = fillAvailableHeight
          ? LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                height: constraints.maxHeight,
                child: contextualSingle,
              ),
            )
          : contextualSingle;
      return fillAvailableHeight
          ? content
          : scrollColumns
              ? SingleChildScrollView(child: content)
              : content;
    }

    final overviewToolbar = _LibraryOverviewToolbar(
      filters: typeFilters,
      mode: overviewMode,
      onModeChanged: onOverviewModeChanged,
      totalCount: items.length,
      status: status,
      searchController: allSearchController,
      sortOrder: allSortOrder,
      onSearchChanged: onAllSearchChanged,
      onSortChanged: onAllSortChanged,
    );
    final cards = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final type in LibraryItemType.values) ...[
          Expanded(
            child: _LibraryTypeCard(
              controller: controller,
              type: type,
              items: items.where((item) => item.type == type).toList(),
              allItems: items.where((item) => item.type == type).toList(),
              totalCount: items.where((item) => item.type == type).length,
              status: status,
              showStatus: showStatus,
            ),
          ),
          if (type != LibraryItemType.values.last) const SizedBox(width: 14),
        ],
      ],
    );
    final overview = overviewMode == _LibraryOverviewMode.columns
        ? cards
        : _LibraryAllCoverGrid(
            items: items,
            controller: controller,
            showStatus: showStatus,
          );
    final contextualOverview = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) => _showLibraryAddContextMenu(
        context: context,
        position: details.globalPosition,
        controller: controller,
        selectedType: selectedType,
        status: status,
      ),
      child: overview,
    );
    final content = fillAvailableHeight
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              overviewToolbar,
              const SizedBox(height: 12),
              Expanded(child: contextualOverview),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              overviewToolbar,
              const SizedBox(height: 12),
              SizedBox(
                height:
                    overviewMode == _LibraryOverviewMode.columns ? 420 : 620,
                child: contextualOverview,
              ),
            ],
          );
    if (fillAvailableHeight) {
      return content;
    }
    if (!scrollColumns) {
      return content;
    }
    return SingleChildScrollView(child: content);
  }
}

class _LibraryOverviewToolbar extends StatelessWidget {
  const _LibraryOverviewToolbar({
    required this.filters,
    required this.mode,
    required this.onModeChanged,
    required this.totalCount,
    required this.status,
    required this.searchController,
    required this.sortOrder,
    required this.onSearchChanged,
    required this.onSortChanged,
  });

  final Widget filters;
  final _LibraryOverviewMode mode;
  final ValueChanged<_LibraryOverviewMode> onModeChanged;
  final int totalCount;
  final LibraryItemStatus? status;
  final TextEditingController searchController;
  final LibrarySortOrder sortOrder;
  final VoidCallback onSearchChanged;
  final ValueChanged<LibrarySortOrder> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final toggle = _LibraryOverviewModeToggle(
      value: mode,
      onChanged: onModeChanged,
    );
    final countBadge = _LibraryToolbarCountBadge(
      label: '$totalCount ${_libraryStatusCountLabel(status, totalCount)}',
      background: const Color(0xFFE8EEE5),
      foreground: const Color(0xFF70835D),
    );
    final searchField = SizedBox(
      width: 280,
      child: _CompactLibrarySearchField(
        controller: searchController,
        onChanged: onSearchChanged,
      ),
    );
    final sortButton = _LibrarySortButton(
      label: _sortLabel(sortOrder),
      onSelected: onSortChanged,
    );
    final controls = <Widget>[
      countBadge,
      const SizedBox(width: 10),
      searchField,
      const SizedBox(width: 10),
      sortButton,
      const SizedBox(width: 10),
      toggle,
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1120) {
          return Row(
            children: [
              Expanded(child: filters),
              const SizedBox(width: 16),
              ...controls,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            filters,
            const SizedBox(height: 8),
            if (constraints.maxWidth >= 680)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: controls,
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: controls),
              ),
          ],
        );
      },
    );
  }
}

class _LibraryOverviewModeToggle extends StatelessWidget {
  const _LibraryOverviewModeToggle({
    required this.value,
    required this.onChanged,
  });

  final _LibraryOverviewMode value;
  final ValueChanged<_LibraryOverviewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: context.visuals.panel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE3D7C8)),
      ),
      child: SizedBox(
        width: 70,
        height: 34,
        child: Stack(
          children: [
            AnimatedAlign(
              alignment: value == _LibraryOverviewMode.columns
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOutCubic,
              child: Container(
                width: 35,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0E3),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: [
                _LibraryOverviewModeButton(
                  icon: Icons.view_column_rounded,
                  tooltip: 'Vista por columnas',
                  selected: value == _LibraryOverviewMode.columns,
                  onPressed: () => onChanged(_LibraryOverviewMode.columns),
                ),
                _LibraryOverviewModeButton(
                  icon: Icons.grid_view_rounded,
                  tooltip: 'Vista de portadas',
                  selected: value == _LibraryOverviewMode.covers,
                  onPressed: () => onChanged(_LibraryOverviewMode.covers),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryOverviewModeButton extends StatelessWidget {
  const _LibraryOverviewModeButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 35,
          height: 34,
          child: Center(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              scale: selected ? 1.06 : 1,
              child: Icon(
                icon,
                size: 19,
                color: selected
                    ? const Color(0xFF3F5B3B)
                    : context.visuals.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryAllCoverGrid extends StatelessWidget {
  const _LibraryAllCoverGrid({
    required this.items,
    required this.controller,
    required this.showStatus,
  });

  final List<LibraryItem> items;
  final TodoWorkspace controller;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No hay contenido para este filtro.',
          style: TextStyle(color: context.visuals.textMuted),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxExtent = constraints.maxWidth >= 980
            ? 194.0
            : constraints.maxWidth >= 720
                ? 176.0
                : 154.0;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 16),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxExtent,
            mainAxisSpacing: 24,
            crossAxisSpacing: 20,
            childAspectRatio: 0.66,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _LibraryCoverGridCard(
              item: item,
              controller: controller,
              showStatus: showStatus,
              showTypeBadge: true,
              onTap: () => _showLibraryItemDetails(
                context,
                controller,
                items,
                item,
              ),
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
        );
      },
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

class _LibraryTypeCard extends StatelessWidget {
  const _LibraryTypeCard({
    required this.controller,
    required this.type,
    required this.items,
    required this.allItems,
    required this.totalCount,
    required this.status,
    required this.showStatus,
  });

  final TodoWorkspace controller;
  final LibraryItemType type;
  final List<LibraryItem> items;
  final List<LibraryItem> allItems;
  final int totalCount;
  final LibraryItemStatus? status;
  final bool showStatus;

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
                  '$totalCount ${_libraryStatusCountLabel(status, totalCount)}',
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
                        _libraryEmptyStatusText(status),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.visuals.textMuted),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _LibraryItemRow(
                        item: item,
                        controller: controller,
                        showStatus: showStatus,
                        onTap: () => _showDetailDialog(context, item),
                        onEdit: () => _showEditDialog(context, item),
                        onDelete: () => _deleteItem(context, item),
                      );
                    },
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
                      _librarySeeAllLabel(type, totalCount, status),
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

  Future<void> _showDetailDialog(BuildContext context, LibraryItem item) =>
      _showLibraryItemDetails(context, controller, allItems, item);

  Future<void> _showEditDialog(BuildContext context, LibraryItem item) {
    return showDialog<void>(
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

  Future<void> _showLibraryTypeList(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _LibraryTypeListDialog(
        controller: controller,
        type: type,
        items: allItems,
        status: status,
        showStatus: showStatus,
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
    required this.status,
    required this.showStatus,
    required this.typeFilters,
  });

  final TodoWorkspace controller;
  final LibraryItemType type;
  final List<LibraryItem> items;
  final int totalCount;
  final LibraryItemStatus? status;
  final bool showStatus;
  final Widget typeFilters;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final controls = <Widget>[
              _LibraryToolbarCountBadge(
                label:
                    '${widget.totalCount} ${_libraryStatusCountLabel(widget.status, widget.totalCount)}',
                background: _libraryColor(widget.type).withValues(alpha: 0.12),
                foreground: _libraryColor(widget.type),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 230,
                child: _CompactLibrarySearchField(
                  controller: _searchController,
                  onChanged: () => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              _LibrarySortButton(
                label: _sortLabelForType(_sortOrder, widget.type),
                type: widget.type,
                onSelected: (order) => setState(() => _sortOrder = order),
              ),
            ];
            if (constraints.maxWidth >= 1260) {
              return Row(
                children: [
                  Expanded(child: widget.typeFilters),
                  const SizedBox(width: 16),
                  ...controls,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                widget.typeFilters,
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: controls,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Expanded(
          child: sorted.isEmpty
              ? Center(
                  child: Text(
                    _libraryEmptyStatusText(widget.status),
                    style: TextStyle(color: context.visuals.textMuted),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final maxExtent = constraints.maxWidth >= 980
                        ? 194.0
                        : constraints.maxWidth >= 720
                            ? 176.0
                            : 154.0;
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 16),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: maxExtent,
                        mainAxisSpacing: 24,
                        crossAxisSpacing: 20,
                        childAspectRatio: 0.66,
                      ),
                      itemCount: sorted.length,
                      itemBuilder: (context, index) {
                        final item = sorted[index];
                        return _LibraryCoverGridCard(
                          item: item,
                          controller: widget.controller,
                          showStatus: widget.showStatus,
                          onTap: () => _showLibraryItemDetails(
                            context,
                            widget.controller,
                            sorted,
                            item,
                          ),
                          onEdit: () => showDialog<void>(
                            context: context,
                            builder: (context) => _LibraryItemDialog(
                              controller: widget.controller,
                              item: item,
                            ),
                          ),
                          onDelete: () => _deleteItem(context, item),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
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
      message: _libraryDeleteMessage(widget.controller, item),
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
      height: 38,
      child: TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 38, minHeight: 38),
          suffixIconConstraints:
              const BoxConstraints(minWidth: 38, minHeight: 38),
          suffixIcon: controller.text.trim().isEmpty
              ? null
              : IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 38, height: 38),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Limpiar búsqueda',
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
    this.type,
    required this.onSelected,
  });

  final String label;
  final LibraryItemType? type;
  final ValueChanged<LibrarySortOrder> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<LibrarySortOrder>(
      tooltip: 'Ordenar',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final order
            in type == null ? _sortOptionsForAll() : _sortOptionsForType(type!))
          PopupMenuItem(
            value: order,
            child: Text(
              type == null
                  ? _sortLabel(order)
                  : _sortLabelForType(order, type!),
            ),
          ),
      ],
      child: IgnorePointer(
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE8DCCB)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF34362F),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: Color(0xFF34362F),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryToolbarCountBadge extends StatelessWidget {
  const _LibraryToolbarCountBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LibraryCoverGridCard extends StatefulWidget {
  const _LibraryCoverGridCard({
    required this.item,
    required this.controller,
    required this.showStatus,
    this.showTypeBadge = false,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final LibraryItem item;
  final TodoWorkspace controller;
  final bool showStatus;
  final bool showTypeBadge;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_LibraryCoverGridCard> createState() => _LibraryCoverGridCardState();
}

class _LibraryCoverGridCardState extends State<_LibraryCoverGridCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final rewatchCount = _libraryRewatchCount(item);
    final collectionLabels = _libraryCollectionLabels(widget.controller, item);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onSecondaryTapDown: (details) => _showLibraryContextMenu(
          context: context,
          position: details.globalPosition,
          onPages: () => _openKnowledgeWorkspace(
            context,
            widget.controller,
            item,
          ),
          onComplete: item.status == LibraryItemStatus.completed
              ? null
              : () => _completeLibraryItem(
                    context,
                    widget.controller,
                    item,
                  ),
          onEdit: widget.onEdit,
          onDelete: widget.onDelete,
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(7),
          child: AnimatedContainer(
            key: ValueKey('library-cover-card-${item.id}'),
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            transform: Matrix4.identity()
              ..scaleByDouble(
                _hovered ? 1.025 : 1.0,
                _hovered ? 1.025 : 1.0,
                1,
                1,
              ),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF18202A),
              borderRadius: BorderRadius.circular(7),
              boxShadow: [
                if (item.status == LibraryItemStatus.completed)
                  BoxShadow(
                    color: const Color(0xFF5F7F49).withValues(alpha: 0.38),
                    blurRadius: _hovered ? 26 : 18,
                    spreadRadius: _hovered ? 2 : 1,
                  ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: _hovered ? 0.26 : 0.18),
                  blurRadius: _hovered ? 22 : 16,
                  offset: Offset(0, _hovered ? 11 : 8),
                ),
              ],
            ),
            foregroundDecoration: item.status == LibraryItemStatus.completed
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: const Color(0xFF5F7F49),
                      width: 4,
                    ),
                  )
                : null,
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _LibraryCoverImage(
                  source: item.coverUrl,
                  type: item.type,
                  iconSize: 44,
                ),
                AnimatedOpacity(
                  opacity: _hovered ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00000000),
                          Color(0x1A000000),
                          Color(0xB8000000),
                        ],
                        stops: [0.42, 0.72, 1],
                      ),
                    ),
                  ),
                ),
                if (widget.showTypeBadge ||
                    item.rating != null ||
                    rewatchCount > 1)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (widget.showTypeBadge)
                          _LibraryCoverTypeBadge(
                            key: ValueKey('library-cover-type-${item.id}'),
                            type: item.type,
                          ),
                        if (widget.showTypeBadge &&
                            (item.rating != null || rewatchCount > 1))
                          const SizedBox(height: 5),
                        if (item.rating != null)
                          _LibraryPosterBadge(
                            icon: Icons.star_rounded,
                            label: _formatRating(item.rating!),
                          ),
                        if (item.rating != null && rewatchCount > 1)
                          const SizedBox(height: 5),
                        if (rewatchCount > 1)
                          _LibraryRewatchBadge(count: rewatchCount),
                      ],
                    ),
                  ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  left: 12,
                  right: 12,
                  bottom: _hovered ? 50 : 38,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _hovered ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              shadows: [
                                Shadow(
                                  color: Color(0xAA000000),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          if (collectionLabels != null) ...[
                            const SizedBox(height: 6),
                            _LibraryCollectionChips(
                              controller: widget.controller,
                              item: item,
                              compact: true,
                              onDark: true,
                              alignment: WrapAlignment.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 8,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE63B4654),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.26),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        _libraryItemStatusMeta(item),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.showStatus)
                  Positioned(
                    left: 8,
                    bottom: 42,
                    child: _LibraryStatusBadge(status: item.status),
                  ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: _LibraryCoverMenuButton(
                    onPages: () => _openKnowledgeWorkspace(
                      context,
                      widget.controller,
                      item,
                    ),
                    onComplete: item.status == LibraryItemStatus.completed
                        ? null
                        : () => _completeLibraryItem(
                              context,
                              widget.controller,
                              item,
                            ),
                    onEdit: widget.onEdit,
                    onDelete: widget.onDelete,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryPosterBadge extends StatelessWidget {
  const _LibraryPosterBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xD9202732),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFFF7D36B)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryCoverTypeBadge extends StatelessWidget {
  const _LibraryCoverTypeBadge({super.key, required this.type});

  final LibraryItemType type;

  @override
  Widget build(BuildContext context) {
    final color = _libraryColor(type);
    return Tooltip(
      message: _libraryTypeSingularLabelForType(type),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xD9202732),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Icon(_libraryIcon(type), size: 15, color: color),
      ),
    );
  }
}

class _LibraryRewatchBadge extends StatelessWidget {
  const _LibraryRewatchBadge({required this.count, this.compact = false});

  final int count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Vista $count veces',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 8,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: compact ? const Color(0xFFEFF4E7) : const Color(0xDDEFF4E7),
          borderRadius: BorderRadius.circular(999),
          boxShadow: compact
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) ...[
              const Icon(
                Icons.replay_rounded,
                size: 15,
                color: Color(0xFF607A4D),
              ),
              const SizedBox(width: 3),
            ],
            Text(
              'x$count',
              style: const TextStyle(
                color: Color(0xFF607A4D),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryStatusBadge extends StatelessWidget {
  const _LibraryStatusBadge({required this.status});

  final LibraryItemStatus status;

  @override
  Widget build(BuildContext context) {
    final style = switch (status) {
      LibraryItemStatus.completed => (
          label: 'Completado',
          background: const Color(0xFFE7F2DF),
          foreground: const Color(0xFF597743),
          icon: Icons.check_rounded,
        ),
      LibraryItemStatus.inProgress => (
          label: 'En curso',
          background: const Color(0xFFFFEFD9),
          foreground: const Color(0xFFC77721),
          icon: Icons.play_arrow_rounded,
        ),
      LibraryItemStatus.pending => (
          label: 'Pendiente',
          background: const Color(0xFFECEFF3),
          foreground: const Color(0xFF687384),
          icon: Icons.bookmark_outline_rounded,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 12, color: style.foreground),
          const SizedBox(width: 3),
          Text(
            style.label,
            style: TextStyle(
              color: style.foreground,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryCoverMenuButton extends StatelessWidget {
  const _LibraryCoverMenuButton({
    this.onPages,
    this.onComplete,
    required this.onEdit,
    required this.onDelete,
  });

  final VoidCallback? onPages;
  final VoidCallback? onComplete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_LibraryContextAction>(
      tooltip: 'Opciones',
      position: PopupMenuPosition.under,
      onSelected: (action) {
        if (action == _LibraryContextAction.pages) {
          onPages?.call();
        } else if (action == _LibraryContextAction.complete) {
          onComplete?.call();
        } else if (action == _LibraryContextAction.edit) {
          onEdit();
        } else if (action == _LibraryContextAction.delete) {
          onDelete();
        }
      },
      itemBuilder: (context) => [
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
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xC2202732),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: const Icon(
          Icons.more_horiz_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

class _LibraryItemRow extends StatelessWidget {
  const _LibraryItemRow({
    required this.item,
    required this.controller,
    this.showStatus = false,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final LibraryItem item;
  final TodoWorkspace controller;
  final bool showStatus;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final rewatchCount = _libraryRewatchCount(item);
    final collectionLabels = _libraryCollectionLabels(controller, item);
    final seriesLabels = _librarySeriesLabels(item);
    return GestureDetector(
      onSecondaryTapDown: (details) => _showLibraryContextMenu(
        context: context,
        position: details.globalPosition,
        onPages: () => _openKnowledgeWorkspace(context, controller, item),
        onComplete: item.status == LibraryItemStatus.completed
            ? null
            : () => _completeLibraryItem(context, controller, item),
        onEdit: onEdit,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (collectionLabels != null ||
                        rewatchCount > 1 ||
                        seriesLabels != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (showStatus)
                            _LibraryStatusBadge(status: item.status),
                          if (showStatus &&
                              (collectionLabels != null ||
                                  rewatchCount > 1 ||
                                  seriesLabels != null))
                            const SizedBox(width: 5),
                          if (collectionLabels != null)
                            Flexible(
                              child: _LibraryCollectionChips(
                                controller: controller,
                                item: item,
                                compact: true,
                              ),
                            ),
                          if (rewatchCount > 1)
                            Padding(
                              padding: EdgeInsets.only(
                                left: collectionLabels == null ? 0 : 5,
                              ),
                              child: _LibraryRewatchBadge(
                                count: rewatchCount,
                                compact: true,
                              ),
                            ),
                          if (seriesLabels != null)
                            Flexible(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: collectionLabels == null &&
                                          rewatchCount <= 1
                                      ? 0
                                      : 5,
                                ),
                                child: _LibrarySeriesChips(
                                  labels: seriesLabels,
                                  compact: true,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _libraryItemStatusMeta(item),
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

class _LibraryCollectionChips extends StatelessWidget {
  const _LibraryCollectionChips({
    required this.controller,
    required this.item,
    this.compact = false,
    this.onDark = false,
    this.alignment = WrapAlignment.start,
  });

  final TodoWorkspace controller;
  final LibraryItem item;
  final bool compact;
  final bool onDark;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final labels = _libraryCollectionLabels(controller, item);
    if (labels == null) {
      return const SizedBox.shrink();
    }
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: _LibraryCollectionChip(
              label: labels.saga,
              item: item,
              compact: true,
              onDark: onDark,
            ),
          ),
          if (labels.installment != null) ...[
            const SizedBox(width: 5),
            _LibraryCollectionChip(
              label: labels.installment!,
              item: item,
              compact: true,
              onDark: onDark,
            ),
          ],
        ],
      );
    }
    return Wrap(
      spacing: 7,
      runSpacing: 5,
      alignment: alignment,
      children: [
        _LibraryCollectionChip(
          label: labels.saga,
          item: item,
          compact: compact,
          onDark: onDark,
        ),
        if (labels.installment != null)
          _LibraryCollectionChip(
            label: labels.installment!,
            item: item,
            compact: compact,
            onDark: onDark,
          ),
      ],
    );
  }
}

class _LibraryCollectionChip extends StatelessWidget {
  const _LibraryCollectionChip({
    required this.label,
    required this.item,
    required this.compact,
    required this.onDark,
  });

  final String label;
  final LibraryItem item;
  final bool compact;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = _libraryColor(item.type);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: 0.92)
            : color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: compact ? 10.5 : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LibrarySeriesChips extends StatelessWidget {
  const _LibrarySeriesChips({required this.labels, this.compact = false});

  final ({String seasons, String? upcoming}) labels;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: _LibrarySeriesChip(
              label: labels.seasons,
              tooltip: 'Temporadas disponibles',
            ),
          ),
          if (labels.upcoming != null) ...[
            const SizedBox(width: 5),
            Flexible(
              child: _LibrarySeriesChip(
                label: labels.upcoming!,
                tooltip: 'Siguiente temporada confirmada',
              ),
            ),
          ],
        ],
      );
    }
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        _LibrarySeriesChip(
          label: labels.seasons,
          tooltip: 'Temporadas disponibles',
        ),
        if (labels.upcoming != null)
          _LibrarySeriesChip(
            label: labels.upcoming!,
            tooltip: 'Siguiente temporada confirmada',
          ),
      ],
    );
  }
}

class _LibrarySeriesChip extends StatelessWidget {
  const _LibrarySeriesChip({required this.label, required this.tooltip});

  final String label;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0D9),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFC77721),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
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

class _LibraryGoalDetailsDialog extends StatefulWidget {
  const _LibraryGoalDetailsDialog({
    required this.controller,
    required this.year,
    required this.goals,
    required this.goal,
  });

  final TodoWorkspace controller;
  final int year;
  final List<LibraryGoal> goals;
  final LibraryGoal goal;

  @override
  State<_LibraryGoalDetailsDialog> createState() =>
      _LibraryGoalDetailsDialogState();
}

class _LibraryGoalDetailsDialogState extends State<_LibraryGoalDetailsDialog> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.goals.indexWhere((goal) => goal.id == widget.goal.id);
    if (_index < 0) {
      _index = 0;
    }
  }

  LibraryGoal get goal {
    if (widget.goals.isEmpty) {
      return widget.goal;
    }
    return widget.goals[_index.clamp(0, widget.goals.length - 1)];
  }

  bool get _hasPrevious => widget.goals.isNotEmpty && _index > 0;
  bool get _hasNext =>
      widget.goals.isNotEmpty && _index < widget.goals.length - 1;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final goal = this.goal;
    final fields = _goalDetailFields(goal);
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
                    Icon(_libraryIcon(goal.type),
                        color: _libraryColor(goal.type), size: 30),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 23, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            goal.isCompleted ? 'Completado' : 'Propósito',
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LibraryGoalDetailCover(goal: goal),
                      const SizedBox(width: 30),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_goalDetailTitle(goal.type),
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
                          builder: (context) => _LibraryGoalDialog(
                            controller: widget.controller,
                            year: widget.year,
                            initialType: goal.type,
                            goal: goal,
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

class _LibraryGoalDetailCover extends StatelessWidget {
  const _LibraryGoalDetailCover({required this.goal});

  final LibraryGoal goal;

  @override
  Widget build(BuildContext context) {
    final source = goal.coverUrl?.trim();
    return SizedBox(
      key: const ValueKey('library-goal-detail-cover'),
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
              type: goal.type,
              iconSize: 34,
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryGoalsView extends StatefulWidget {
  const _LibraryGoalsView({
    required this.controller,
    required this.year,
    required this.selectedType,
    required this.onSelectedTypeChanged,
    required this.onAdd,
  });

  final TodoWorkspace controller;
  final int year;
  final LibraryItemType? selectedType;
  final ValueChanged<LibraryItemType?> onSelectedTypeChanged;
  final VoidCallback onAdd;

  @override
  State<_LibraryGoalsView> createState() => _LibraryGoalsViewState();
}

class _LibraryGoalsViewState extends State<_LibraryGoalsView> {
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
        _LibraryTypeFilters(
          selected: widget.selectedType,
          onChanged: widget.onSelectedTypeChanged,
        ),
        const SizedBox(height: 14),
        if (widget.selectedType != null)
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
                    onOpen: (goal) => _showGoalDetails(
                      context,
                      goals
                          .where((goal) => goal.type == LibraryItemType.game)
                          .toList(),
                      goal,
                    ),
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
                    onOpen: (goal) => _showGoalDetails(
                      context,
                      goals
                          .where((goal) => goal.type == LibraryItemType.book)
                          .toList(),
                      goal,
                    ),
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
                    onOpen: (goal) => _showGoalDetails(
                      context,
                      goals
                          .where((goal) =>
                              goal.type == LibraryItemType.movieSeries)
                          .toList(),
                      goal,
                    ),
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
                  onOpen: (goal) => _showGoalDetails(
                    context,
                    goals.where((goal) => goal.type == type).toList(),
                    goal,
                  ),
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
    final selectedType = widget.selectedType!;
    return _LibraryGoalFilteredCardsPanel(
      type: selectedType,
      goals: goals.where((goal) => goal.type == selectedType).toList(),
      onAdd: () => _showGoalDialogFor(context, selectedType),
      onOpen: (goal) => _showGoalDetails(
        context,
        goals.where((goal) => goal.type == selectedType).toList(),
        goal,
      ),
      onEdit: (goal) => _showGoalEditDialog(context, goal),
      onFavorite: widget.controller.toggleLibraryGoalFavorite,
      onDelete: (goal) => _deleteGoal(context, goal),
    );
  }

  Future<void> _showGoalDetails(
    BuildContext context,
    List<LibraryGoal> goals,
    LibraryGoal goal,
  ) {
    return _showLibraryGoalDetails(
      context,
      widget.controller,
      widget.year,
      goals,
      goal,
    );
  }

  Future<void> _deleteGoal(BuildContext context, LibraryGoal goal) async {
    final confirmed = await _confirmLibraryDelete(
      context,
      title: 'Borrar propósito',
      message: '¿Quieres borrar "${goal.title}" de tus propósitos?',
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
    required this.onOpen,
    required this.onEdit,
    required this.onFavorite,
    required this.onDelete,
  });

  final LibraryItemType type;
  final List<LibraryGoal> goals;
  final VoidCallback onAdd;
  final ValueChanged<LibraryGoal> onOpen;
  final ValueChanged<LibraryGoal> onEdit;
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
                  '${goals.length} ${goals.length == 1 ? 'propósito' : 'propósitos'}',
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
                      final crossAxisCount = constraints.maxWidth >= 1350
                          ? 6
                          : constraints.maxWidth >= 980
                              ? 4
                              : constraints.maxWidth >= 680
                                  ? 3
                                  : 2;
                      const horizontalPadding = 44.0;
                      const verticalPadding = 48.0;
                      const crossSpacing = 20.0;
                      const mainSpacing = 24.0;
                      final rowCount = (goals.length / crossAxisCount).ceil();
                      final cardWidth = (constraints.maxWidth -
                              horizontalPadding -
                              (crossAxisCount - 1) * crossSpacing) /
                          crossAxisCount;
                      final availableCardHeight = (constraints.maxHeight -
                              verticalPadding -
                              (rowCount - 1) * mainSpacing) /
                          rowCount;
                      final cardHeight = min(
                        cardWidth / 0.66,
                        max(1.0, availableCardHeight),
                      );
                      return GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: mainSpacing,
                          crossAxisSpacing: crossSpacing,
                          childAspectRatio: cardWidth / cardHeight,
                        ),
                        itemCount: goals.length,
                        itemBuilder: (context, index) {
                          final goal = goals[index];
                          return _LibraryGoalLargeCard(
                            goal: goal,
                            onOpen: () => onOpen(goal),
                            onEdit: () => onEdit(goal),
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

class _LibraryGoalLargeCard extends StatefulWidget {
  const _LibraryGoalLargeCard({
    required this.goal,
    required this.onOpen,
    required this.onEdit,
    required this.onFavorite,
    required this.onDelete,
  });

  final LibraryGoal goal;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;

  @override
  State<_LibraryGoalLargeCard> createState() => _LibraryGoalLargeCardState();
}

class _LibraryGoalLargeCardState extends State<_LibraryGoalLargeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    final metadata = _goalMetadata(goal);
    return Tooltip(
      message: metadata == null ? goal.title : '${goal.title}\n$metadata',
      waitDuration: const Duration(milliseconds: 450),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onSecondaryTapDown: (details) => _showLibraryContextMenu(
            context: context,
            position: details.globalPosition,
            onEdit: widget.onEdit,
            onDelete: widget.onDelete,
          ),
          child: InkWell(
            onTap: widget.onOpen,
            borderRadius: BorderRadius.circular(7),
            child: AnimatedContainer(
              key: ValueKey('library-goal-card-${goal.id}'),
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              transform: Matrix4.identity()
                ..scaleByDouble(
                  _hovered ? 1.025 : 1.0,
                  _hovered ? 1.025 : 1.0,
                  1,
                  1,
                ),
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF18202A),
                borderRadius: BorderRadius.circular(7),
                boxShadow: [
                  if (goal.isCompleted)
                    BoxShadow(
                      color: const Color(0xFF5F7F49).withValues(alpha: 0.38),
                      blurRadius: _hovered ? 26 : 18,
                      spreadRadius: _hovered ? 2 : 1,
                    ),
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: _hovered ? 0.26 : 0.18),
                    blurRadius: _hovered ? 22 : 16,
                    offset: Offset(0, _hovered ? 11 : 8),
                  ),
                ],
              ),
              foregroundDecoration: goal.isCompleted
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: const Color(0xFF5F7F49),
                        width: 4,
                      ),
                    )
                  : null,
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _LibraryCoverImage(
                    source: goal.coverUrl?.trim(),
                    type: goal.type,
                    iconSize: 44,
                  ),
                  AnimatedOpacity(
                    opacity: _hovered ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x00000000),
                            Color(0x1A000000),
                            Color(0xB8000000),
                          ],
                          stops: [0.42, 0.72, 1],
                        ),
                      ),
                    ),
                  ),
                  if (goal.isFavorite)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _LibraryGoalTopIconButton(
                        tooltip: 'Quitar prioridad',
                        icon: Icons.star_rounded,
                        color: const Color(0xFFF1A340),
                        onPressed: widget.onFavorite,
                      ),
                    ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    left: 12,
                    right: 12,
                    bottom: _hovered ? 50 : 38,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _hovered ? 1 : 0,
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut,
                        child: Text(
                          goal.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            decoration: goal.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: Colors.white,
                            shadows: const [
                              Shadow(
                                color: Color(0xAA000000),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: goal.isCompleted
                              ? const Color(0xE6506844)
                              : const Color(0xE63B4654),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.26),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          goal.isCompleted ? 'Completado' : 'Pendiente',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryGoalTopIconButton extends StatelessWidget {
  const _LibraryGoalTopIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xDDEFF4E7),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, size: 18, color: color),
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
    required this.onOpen,
    required this.onEdit,
    required this.onToggle,
    required this.onFavorite,
    required this.onDelete,
  });

  final LibraryItemType type;
  final List<LibraryGoal> goals;
  final VoidCallback onAdd;
  final ValueChanged<LibraryGoal> onOpen;
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
                            onOpen: () => onOpen(goal),
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
    required this.onOpen,
    required this.onEdit,
    required this.onToggle,
    required this.onFavorite,
    required this.onDelete,
  });

  final LibraryGoal goal;
  final VoidCallback onOpen;
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
            onTap: onOpen,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
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
                        if (_goalMetadata(goal) != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            _goalMetadata(goal)!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.visuals.textMuted,
                              fontSize: 12,
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
      return _LocalLibraryCoverImage(
        path: value,
        type: type,
        iconSize: iconSize,
      );
    }
    return Image.network(
      value,
      fit: BoxFit.cover,
      cacheWidth: 600,
      errorBuilder: (context, error, stackTrace) =>
          _LibraryCoverFallback(type: type, iconSize: iconSize),
    );
  }
}

class _LocalLibraryCoverImage extends StatelessWidget {
  const _LocalLibraryCoverImage({
    required this.path,
    required this.type,
    required this.iconSize,
  });

  final String path;
  final LibraryItemType type;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      cacheWidth: 600,
      gaplessPlayback: true,
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
  bool _completed = false;
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
    _completed = goal.isCompleted;
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
                    Icon(
                      _libraryIcon(_type),
                      color: _libraryColor(_type),
                      size: 30,
                    ),
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
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _LibraryImageDropField(
                            label: _goalImageLabel(),
                            type: _type,
                            icon: _libraryIcon(_type),
                            controller: _cover,
                            width: 244,
                            height: 416,
                          ),
                          const SizedBox(width: 30),
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
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(_isEditing ? 'Guardar' : 'Añadir'),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _goalDialogField(
                    _developer, 'Desarrollador', 'Ej. Arkane Studios'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _goalDialogField(_genre, 'Género', 'Ej. Inmersivo, RPG'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _goalDialogField(
            _duration,
            'Horas estimadas',
            'Ej. 20 h',
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
                    _goalDialogField(_genre, 'Género', 'Ej. Fantasía, Clásico'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _goalDialogField(
                    _pages, 'Páginas / Volúmenes', 'Ej. 864 páginas'),
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
          Row(
            children: [
              Expanded(
                child: _goalDialogField(
                  _duration,
                  'Duración',
                  'Ej. 2h 55m',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _goalDialogField(
                  _country,
                  'País de origen',
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
                  'Género',
                  'Ej. Drama, Acción',
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
        if (_isEditing) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            value: _completed,
            onChanged: (value) => setState(() => _completed = value),
            title: const Text('Completado'),
            secondary: Icon(
              _completed
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: _completed
                  ? const Color(0xFF70835D)
                  : context.visuals.textMuted,
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ],
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
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: context.visuals.textMuted.withValues(alpha: 0.72),
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _goalBookTypeField() {
    return _goalDropdownTextField(
      label: 'Tipo *',
      controller: _creator,
      fallback: 'Libro',
      options: const ['Libro', 'Manga', 'Cómic'],
    );
  }

  Widget _goalBookFormatField() {
    return _goalDropdownTextField(
      label: 'Formato *',
      controller: _format,
      fallback: 'eBook',
      options: const ['Físico', 'eBook'],
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
          style: TextStyle(
            color: context.visuals.textStrong,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
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
    final currentYear = DateTime.now().year;
    final years = <int>{_year, currentYear, currentYear + 1}.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Año *', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _year,
          decoration: const InputDecoration(),
          items: [
            for (final year in years)
              DropdownMenuItem(value: year, child: Text('$year')),
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
          style: TextStyle(
            color: context.visuals.textStrong,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
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
          format: _type == LibraryItemType.game
              ? 'Digital'
              : _format.text.trim().isEmpty
                  ? null
                  : _format.text.trim(),
          clearFormat:
              _type != LibraryItemType.game && _format.text.trim().isEmpty,
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
      if (_completed != goal.isCompleted) {
        widget.controller.toggleLibraryGoalCompleted(goal.id);
      }
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
      format: _type == LibraryItemType.game ? 'Digital' : _format.text,
      duration: _duration.text,
      pages: _type == LibraryItemType.book ? _pages.text : null,
      country: _type == LibraryItemType.movieSeries ? _country.text : null,
    );
    Navigator.of(context).pop();
  }
}

class _LibraryItemDialog extends StatefulWidget {
  const _LibraryItemDialog({
    required this.controller,
    this.item,
    this.initialType = LibraryItemType.game,
    this.initialStatus = LibraryItemStatus.pending,
  });

  final TodoWorkspace controller;
  final LibraryItem? item;
  final LibraryItemType initialType;
  final LibraryItemStatus initialStatus;

  @override
  State<_LibraryItemDialog> createState() => _LibraryItemDialogState();
}

class _LibraryItemDialogState extends State<_LibraryItemDialog> {
  late LibraryItemType _type;
  LibraryMediaType _mediaType = LibraryMediaType.movie;
  late LibraryItemStatus _status;
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
  final _collectionName = TextEditingController();
  final _collectionNumber = TextEditingController();
  final _seasonCount = TextEditingController();
  bool _showCollectionNumber = false;
  bool _nextSeasonConfirmed = false;
  LibraryPublicationStatus? _publicationStatus;
  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _type = item?.type ?? widget.initialType;
    _status = item?.status ?? widget.initialStatus;
    if (item == null) {
      _completedDate = DateTime.now();
      return;
    }
    _type = item.type;
    _mediaType = item.mediaType ?? LibraryMediaType.movie;
    _completedDate = item.completedDate ?? DateTime.now();
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
    _collectionName.text = item.collectionName ?? '';
    _collectionNumber.text = item.collectionNumber?.toString() ?? '';
    _seasonCount.text = item.seasonCount?.toString() ?? '';
    _showCollectionNumber = item.showCollectionNumber;
    _nextSeasonConfirmed = item.nextSeasonConfirmed;
    _publicationStatus = item.publicationStatus;
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
    _collectionName.dispose();
    _collectionNumber.dispose();
    _seasonCount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
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
                    Icon(
                      _libraryIcon(_type),
                      color: _libraryColor(_type),
                      size: 30,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing
                                ? widget.item!.title
                                : 'Añadir a la biblioteca',
                            style: const TextStyle(
                                fontSize: 23, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _isEditing
                                ? '${_libraryTypeSingularLabel(widget.item!)} · Edición'
                                : 'Guarda algo pendiente, en curso o completado.',
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
                      Row(
                        // La ficha de la derecha puede crecer al mostrar la
                        // fecha y la valoración de un elemento completado.
                        // Mantener la carátula alineada arriba evita que salte
                        // de posición al cambiar el estado.
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LibraryImageDropField(
                            label: _imageLabel(),
                            type: _type,
                            icon: _libraryIcon(_type),
                            controller: _cover,
                            width: 244,
                            height: 416,
                          ),
                          const SizedBox(width: 30),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _dialogInfoTitle(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 14),
                                _typedFields(),
                              ],
                            ),
                          ),
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
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(_isEditing ? 'Guardar' : 'Añadir'),
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
            ..._collectionFields(),
            const SizedBox(height: 8),
            _dialogField(_platform, 'Plataforma *', 'Ej. PC'),
            const SizedBox(height: 8),
            _statusField(),
            if (_status == LibraryItemStatus.completed) ...[
              const SizedBox(height: 8),
              _dateField('Fecha completado *'),
            ],
            const SizedBox(height: 8),
            _dialogField(_releaseYear, 'Año de lanzamiento', 'Ej. 2017',
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            _dialogField(_genre, 'Género', 'Ej. Inmersivo, RPG...'),
            if (_status == LibraryItemStatus.completed) ...[
              const SizedBox(height: 8),
              _dialogField(
                _rating,
                'Valoración opcional',
                'Ej. 8,5',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
            const SizedBox(height: 8),
            _dialogField(
              _note,
              'Notas opcionales',
              'Añade contexto, una reseña o cualquier detalle…',
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 8),
            _dialogField(_developer, 'Desarrollador', 'Ej. Arkane Studios'),
            const SizedBox(height: 8),
            _dialogField(_duration, 'Horas jugadas', 'Ej. 28 h (opcional)'),
          ],
        ),
      LibraryItemType.book => Column(
          children: [
            _dialogField(_title, 'Título *', 'Ej. El Priorato del Naranjo'),
            ..._collectionFields(),
            const SizedBox(height: 8),
            _dialogField(_author, 'Autor *', 'Ej. Samantha Shannon'),
            const SizedBox(height: 8),
            _statusField(),
            if (_status == LibraryItemStatus.completed) ...[
              const SizedBox(height: 8),
              _dateField('Fecha completado *'),
            ],
            const SizedBox(height: 8),
            _dialogField(_releaseYear, 'Año de publicación', 'Ej. 2023',
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            _bookFormatField(),
            const SizedBox(height: 8),
            _dialogField(_genre, 'Género', 'Ej. Fantasía, Manga...'),
            if (_status == LibraryItemStatus.completed) ...[
              const SizedBox(height: 8),
              _dialogField(
                _rating,
                'Valoración opcional',
                'Ej. 8,5',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
            const SizedBox(height: 8),
            _dialogField(
              _note,
              'Notas opcionales',
              'Añade contexto, una reseña o cualquier detalle…',
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 8),
            _bookTypeField(),
            if (_creator.text == 'Manga') ...[
              const SizedBox(height: 8),
              _publicationStatusField(),
            ],
            const SizedBox(height: 8),
            _dialogField(_pages, 'Páginas / Volúmenes',
                'Ej. 832 páginas / 3 tomos (opcional)'),
          ],
        ),
      LibraryItemType.movieSeries => Column(
          children: [
            _dialogField(_title, 'Título *', 'Ej. El Padrino'),
            ..._collectionFields(),
            const SizedBox(height: 8),
            _mediaTypeField(),
            if (_mediaType == LibraryMediaType.series) ...[
              const SizedBox(height: 8),
              _dialogField(
                _seasonCount,
                'Temporadas disponibles',
                'Ej. 2',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              _nextSeasonConfirmedField(),
            ],
            const SizedBox(height: 8),
            _statusField(),
            if (_status == LibraryItemStatus.completed) ...[
              const SizedBox(height: 8),
              _dateField('Fecha completado / visto *'),
            ],
            const SizedBox(height: 8),
            _dialogField(_releaseYear, 'Año de estreno', 'Ej. 1972',
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            _dialogField(_format, 'Formato', 'Ej. Digital'),
            const SizedBox(height: 8),
            _dialogField(_genre, 'Género', 'Ej. Drama, Acción...'),
            if (_status == LibraryItemStatus.completed) ...[
              const SizedBox(height: 8),
              _dialogField(
                _rating,
                'Valoración opcional',
                'Ej. 8,5',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
            const SizedBox(height: 8),
            _dialogField(
              _note,
              'Notas opcionales',
              'Añade contexto, una reseña o cualquier detalle…',
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 8),
            _dialogField(_creator, 'Director / Creador',
                'Ej. Francis Ford Coppola (opcional)'),
            const SizedBox(height: 8),
            _dialogField(_duration, 'Duración', 'Ej. 2 h 55 min'),
            const SizedBox(height: 8),
            _dialogField(
                _country, 'País de origen', 'Ej. Estados Unidos (opcional)'),
          ],
        ),
    };
  }

  List<Widget> _collectionFields() {
    return [
      const SizedBox(height: 8),
      _dialogField(
        _collectionName,
        'Saga / colección',
        'Ej. Carl el mazmorrero',
      ),
      const SizedBox(height: 8),
      _dialogField(
        _collectionNumber,
        'Número de entrega',
        'Ej. 2',
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: 8),
      _LibraryEditLine(
        label: 'Mostrar etiquetas',
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Aunque sea la única entrega',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            Switch(
              value: _showCollectionNumber,
              onChanged: (value) =>
                  setState(() => _showCollectionNumber = value),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _dialogField(
      TextEditingController controller, String label, String hint,
      {TextInputType? keyboardType, int maxLines = 1, int? minLines}) {
    return _LibraryEditLine(
      label: label,
      alignTop: maxLines > 1,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        minLines: minLines,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: _libraryEditInputDecoration(context, hint),
      ),
    );
  }

  Widget _statusField() {
    return _LibraryEditLine(
      label: 'Estado',
      child: DropdownButtonFormField<LibraryItemStatus>(
        initialValue: _status,
        decoration: _libraryEditInputDecoration(context, null),
        style: TextStyle(
          color: context.visuals.textStrong,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        items: [
          for (final status in LibraryItemStatus.values)
            DropdownMenuItem(
              value: status,
              child: Row(
                children: [
                  Icon(_libraryStatusIcon(status), size: 18),
                  const SizedBox(width: 10),
                  Text(_libraryStatusSingularLabel(status)),
                ],
              ),
            ),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() => _status = value);
          }
        },
      ),
    );
  }

  Widget _dateField(String label) {
    return _LibraryEditLine(
      label: label,
      child: InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 18),
              const SizedBox(width: 10),
              Text(
                _libraryDate(_completedDate),
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mediaTypeField() {
    return _LibraryEditLine(
      label: 'Tipo *',
      child: DropdownButtonFormField<LibraryMediaType>(
        initialValue: _mediaType,
        decoration: _libraryEditInputDecoration(context, null),
        style: TextStyle(
          color: context.visuals.textStrong,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
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
    );
  }

  Widget _bookTypeField() {
    return _dropdownTextField(
      label: 'Tipo *',
      controller: _creator,
      fallback: 'Libro',
      options: const ['Libro', 'Manga', 'Cómic'],
    );
  }

  Widget _bookFormatField() {
    return _dropdownTextField(
      label: 'Formato *',
      controller: _format,
      fallback: 'eBook',
      options: const ['Físico', 'eBook'],
    );
  }

  Widget _publicationStatusField() {
    return _LibraryEditLine(
      label: 'Publicación',
      child: DropdownButtonFormField<LibraryPublicationStatus>(
        initialValue: _publicationStatus,
        decoration: _libraryEditInputDecoration(context, 'Selecciona estado'),
        style: TextStyle(
          color: context.visuals.textStrong,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        items: const [
          DropdownMenuItem(
            value: LibraryPublicationStatus.ongoing,
            child: Text('En publicación'),
          ),
          DropdownMenuItem(
            value: LibraryPublicationStatus.finished,
            child: Text('Finalizado'),
          ),
        ],
        onChanged: (value) => setState(() => _publicationStatus = value),
      ),
    );
  }

  Widget _nextSeasonConfirmedField() {
    return _LibraryEditLine(
      label: 'Próxima temporada',
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Temporada confirmada',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Switch(
            value: _nextSeasonConfirmed,
            onChanged: (value) => setState(() => _nextSeasonConfirmed = value),
          ),
        ],
      ),
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
    return _LibraryEditLine(
      label: label,
      child: DropdownButtonFormField<String>(
        initialValue: current,
        decoration: _libraryEditInputDecoration(context, null),
        style: TextStyle(
          color: context.visuals.textStrong,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
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
          status: _status,
          completedDate:
              _status == LibraryItemStatus.completed ? _completedDate : null,
          clearCompletedDate: _status != LibraryItemStatus.completed,
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
          format: _type == LibraryItemType.game
              ? 'Digital'
              : _format.text.trim().isEmpty
                  ? null
                  : _format.text.trim(),
          clearFormat:
              _type != LibraryItemType.game && _format.text.trim().isEmpty,
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
          collectionName: _collectionName.text.trim().isEmpty
              ? null
              : _collectionName.text.trim(),
          clearCollectionName: _collectionName.text.trim().isEmpty,
          collectionNumber: _validCollectionNumber,
          clearCollectionNumber: _validCollectionNumber == null,
          showCollectionNumber: _validCollectionNumber != null &&
              _collectionName.text.trim().isNotEmpty &&
              _showCollectionNumber,
          seasonCount: _type == LibraryItemType.movieSeries &&
                  _mediaType == LibraryMediaType.series
              ? _validSeasonCount
              : null,
          clearSeasonCount: _type != LibraryItemType.movieSeries ||
              _mediaType != LibraryMediaType.series ||
              _validSeasonCount == null,
          nextSeasonConfirmed: _type == LibraryItemType.movieSeries &&
              _mediaType == LibraryMediaType.series &&
              _nextSeasonConfirmed,
          publicationStatus:
              _type == LibraryItemType.book && _creator.text == 'Manga'
                  ? _publicationStatus
                  : null,
          clearPublicationStatus:
              _type != LibraryItemType.book || _creator.text != 'Manga',
        ),
      );
      Navigator.of(context).pop();
      return;
    }
    widget.controller.createLibraryItem(
      type: _type,
      title: _title.text,
      status: _status,
      completedDate:
          _status == LibraryItemStatus.completed ? _completedDate : null,
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
      format: _type == LibraryItemType.game ? 'Digital' : _format.text,
      duration: _duration.text,
      pages: _type == LibraryItemType.book ? _pages.text : null,
      country: _type == LibraryItemType.movieSeries ? _country.text : null,
      collectionName: _collectionName.text,
      collectionNumber: _validCollectionNumber,
      showCollectionNumber: _validCollectionNumber != null &&
          _collectionName.text.trim().isNotEmpty &&
          _showCollectionNumber,
      seasonCount: _type == LibraryItemType.movieSeries &&
              _mediaType == LibraryMediaType.series
          ? _validSeasonCount
          : null,
      nextSeasonConfirmed: _type == LibraryItemType.movieSeries &&
          _mediaType == LibraryMediaType.series &&
          _nextSeasonConfirmed,
      publicationStatus:
          _type == LibraryItemType.book && _creator.text == 'Manga'
              ? _publicationStatus
              : null,
    );
    Navigator.of(context).pop();
  }

  int? get _validCollectionNumber {
    final value = int.tryParse(_collectionNumber.text.trim());
    return value != null && value > 0 ? value : null;
  }

  int? get _validSeasonCount {
    final value = int.tryParse(_seasonCount.text.trim());
    return value != null && value > 0 ? value : null;
  }
}

class _LibraryEditLine extends StatelessWidget {
  const _LibraryEditLine({
    required this.label,
    required this.child,
    this.alignTop = false,
  });

  final String label;
  final Widget child;
  final bool alignTop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: alignTop ? 10 : 2,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        border: Border.all(color: const Color(0xFFE3D8CB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment:
            alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: alignTop ? 12 : 0),
            child: Icon(
              _detailIcon(label),
              size: 17,
              color: const Color(0xFF607A4D),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: alignTop ? 11 : 0),
              child: Text(
                label,
                style: TextStyle(
                  color: context.visuals.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(flex: 2, child: child),
        ],
      ),
    );
  }
}

InputDecoration _libraryEditInputDecoration(
  BuildContext context,
  String? hint,
) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      color: context.visuals.textMuted.withValues(alpha: 0.72),
      fontSize: 14,
      fontWeight: FontWeight.w400,
    ),
    isDense: true,
    filled: false,
    contentPadding: const EdgeInsets.symmetric(vertical: 12),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
  );
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

class _LibraryImageDropField extends StatefulWidget {
  const _LibraryImageDropField({
    required this.label,
    required this.type,
    required this.icon,
    required this.controller,
    this.width = 176,
    this.height = 300,
  });

  final String label;
  final LibraryItemType type;
  final IconData icon;
  final TextEditingController controller;
  final double width;
  final double height;

  @override
  State<_LibraryImageDropField> createState() => _LibraryImageDropFieldState();
}

class _LibraryImageDropFieldState extends State<_LibraryImageDropField> {
  final FocusNode _pasteFocus = FocusNode(
    debugLabel: 'Pegar portada de biblioteca',
  );

  @override
  void dispose() {
    _pasteFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: Column(
        children: [
          CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.keyV, control: true):
                  () => _pasteCover(context),
            },
            child: Focus(
              focusNode: _pasteFocus,
              child: InkWell(
                onTap: () {
                  _pasteFocus.requestFocus();
                  _pickCoverFile(context);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFCF8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE3D8CB)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x260F1B0C),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.controller,
                    builder: (context, value, _) {
                      final source = value.text.trim();
                      if (source.isNotEmpty) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _LibraryCoverImage(
                            source: source,
                            type: widget.type,
                            iconSize: 34,
                          ),
                        );
                      }
                      return _LibraryImagePlaceholder(
                        icon: widget.icon,
                        label: widget.label,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _pasteCover(context),
              icon: const Icon(Icons.content_paste_rounded),
              label: const Text('Pegar imagen'),
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
    try {
      final file = await openFile(acceptedTypeGroups: const [typeGroup]);
      if (file == null) {
        return;
      }
      final savedPath = await _copyLibraryCover(file);
      if (!context.mounted) {
        return;
      }
      if (savedPath == null) {
        _showCoverError(context, 'No se pudo guardar la imagen seleccionada.');
        return;
      }
      widget.controller.text = savedPath;
    } catch (error) {
      if (context.mounted) {
        _showCoverError(context, 'No se pudo cambiar la portada: $error');
      }
    }
  }

  Future<void> _pasteCover(BuildContext context) async {
    final result = await readClipboardImage();
    if (!context.mounted) return;
    if (!result.hasImage) {
      _showCoverError(context, result.errorMessage!);
      return;
    }
    try {
      final savedPath = await _copyLibraryCoverBytes(result.bytes!);
      if (!context.mounted) return;
      if (savedPath == null) {
        _showCoverError(context, 'La imagen copiada no es compatible.');
        return;
      }
      widget.controller.text = savedPath;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Imagen pegada.')),
      );
    } catch (error) {
      if (context.mounted) {
        _showCoverError(context, 'No se pudo pegar la portada: $error');
      }
    }
  }

  void _showCoverError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
          'JPG, PNG · Máx. 5MB',
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
      LibraryItemType.movieSeries => 'Películas y series',
    };

String _libraryTypeSingularLabelForType(LibraryItemType type) => switch (type) {
      LibraryItemType.game => 'Juego',
      LibraryItemType.book => 'Libro',
      LibraryItemType.movieSeries => 'Película o serie',
    };

String _libraryTypeSingularLabel(LibraryItem item) => switch (item.type) {
      LibraryItemType.game => 'Juego',
      LibraryItemType.book => 'Libro',
      LibraryItemType.movieSeries =>
        item.mediaType == LibraryMediaType.series ? 'Serie' : 'Película',
    };

String _librarySeeAllLabel(
  LibraryItemType type,
  int count,
  LibraryItemStatus? status,
) {
  final state = _libraryStatusCountLabel(status, count);
  return switch (type) {
    LibraryItemType.game => 'Ver los $count juegos $state',
    LibraryItemType.book => 'Ver los $count libros $state',
    LibraryItemType.movieSeries => 'Ver las $count películas y series $state',
  };
}

String _libraryStatusPluralLabel(LibraryItemStatus? status) => switch (status) {
      LibraryItemStatus.pending => 'Pendientes',
      LibraryItemStatus.inProgress => 'En curso',
      LibraryItemStatus.completed => 'Completados',
      null => 'Todo',
    };

String _libraryStatusSingularLabel(LibraryItemStatus? status) =>
    switch (status) {
      LibraryItemStatus.pending => 'Pendiente',
      LibraryItemStatus.inProgress => 'En curso',
      LibraryItemStatus.completed => 'Completado',
      null => 'Contenido',
    };

String _libraryStatusCountLabel(LibraryItemStatus? status, int count) =>
    switch (status) {
      LibraryItemStatus.pending => count == 1 ? 'pendiente' : 'pendientes',
      LibraryItemStatus.inProgress => 'en curso',
      LibraryItemStatus.completed => count == 1 ? 'completado' : 'completados',
      null => count == 1 ? 'elemento' : 'elementos',
    };

String _libraryEmptyStatusText(LibraryItemStatus? status) => switch (status) {
      LibraryItemStatus.pending =>
        'No hay contenido pendiente para este filtro.',
      LibraryItemStatus.inProgress =>
        'No hay contenido en curso para este filtro.',
      LibraryItemStatus.completed =>
        'No hay contenido completado para este filtro.',
      null => 'No hay contenido en la biblioteca.',
    };

IconData _libraryStatusIcon(LibraryItemStatus status) => switch (status) {
      LibraryItemStatus.pending => Icons.bookmark_border_rounded,
      LibraryItemStatus.inProgress => Icons.play_circle_outline_rounded,
      LibraryItemStatus.completed => Icons.check_circle_outline_rounded,
    };

String _libraryItemStatusMeta(LibraryItem item) {
  final date = item.completedDate;
  if (item.status == LibraryItemStatus.completed && date != null) {
    return _libraryDate(date);
  }
  return _libraryStatusSingularLabel(item.status);
}

({String saga, String? installment})? _libraryCollectionLabels(
  TodoWorkspace controller,
  LibraryItem item,
) {
  final collectionName = item.collectionName?.trim();
  final collectionNumber = item.collectionNumber;
  if (collectionName == null || collectionName.isEmpty) {
    return null;
  }
  final collectionKey = _libraryCollectionKey(collectionName);
  final distinctNumbers = controller.libraryItems
      .where(
        (candidate) =>
            candidate.type == item.type &&
            _libraryCollectionKey(candidate.collectionName) == collectionKey,
      )
      .map((candidate) => candidate.collectionNumber)
      .whereType<int>()
      .toSet();
  final showInstallment = collectionNumber != null &&
      (distinctNumbers.length >= 2 || item.showCollectionNumber);
  return (
    saga: collectionName.toLowerCase().startsWith('saga ')
        ? collectionName
        : 'Saga $collectionName',
    installment: showInstallment ? '#$collectionNumber' : null,
  );
}

({String seasons, String? upcoming})? _librarySeriesLabels(
  LibraryItem item,
) {
  if (item.type != LibraryItemType.movieSeries ||
      item.mediaType != LibraryMediaType.series ||
      item.seasonCount == null) {
    return null;
  }
  final count = item.seasonCount!;
  return (
    seasons: 'T$count',
    upcoming: item.nextSeasonConfirmed ? 'T${count + 1} ✓' : null,
  );
}

String _libraryCollectionKey(String? value) =>
    (value ?? '').trim().toLowerCase();

String _libraryDeleteMessage(TodoWorkspace controller, LibraryItem item) {
  final linked = controller.libraryGoals.any(
    (goal) =>
        goal.id == item.linkedGoalId || goal.linkedLibraryItemId == item.id,
  );
  if (linked) {
    return '¿Quieres borrar "${item.title}" de la biblioteca? El propósito vinculado se conservará y volverá a crear esta obra como pendiente.';
  }
  return '¿Quieres borrar "${item.title}" de la biblioteca?';
}

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
            goal.mediaType == LibraryMediaType.series ? 'Serie' : 'Película');
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
  return parts.isEmpty ? null : parts.join(' · ');
}

String _libraryDate(DateTime date) =>
    '${date.day} ${_monthShortLibrary(date.month)} ${date.year}';

String _formatRating(double rating) {
  final rounded = rating.roundToDouble();
  if ((rating - rounded).abs() < 0.05) {
    return rounded.toInt().toString();
  }
  return rating.toStringAsFixed(1);
}

int _libraryRewatchCount(LibraryItem item) {
  final note = item.note ?? '';
  final match =
      RegExp(r'\[rewatch:x(\d+)\]', caseSensitive: false).firstMatch(note);
  final legacyCount =
      match == null ? 1 : int.tryParse(match.group(1) ?? '') ?? 1;
  return item.rewatchCount > legacyCount ? item.rewatchCount : legacyCount;
}

String _detailTitle(LibraryItemType type) => switch (type) {
      LibraryItemType.game => 'Información del juego',
      LibraryItemType.book => 'Información del libro / manga',
      LibraryItemType.movieSeries => 'Información de la película / serie',
    };

String _goalDetailTitle(LibraryItemType type) => _detailTitle(type);

List<(String, String)> _detailFields(LibraryItem item) {
  final common = <(String, String)>[
    ('Estado', _libraryStatusSingularLabel(item.status)),
    if (item.collectionName?.isNotEmpty == true)
      ('Saga / colección', item.collectionName!),
    if (item.collectionNumber != null)
      ('Número de entrega', '#${item.collectionNumber}'),
    if (item.rewatchCount > 1) ('Rewatch', 'x${item.rewatchCount}'),
    if (item.completedDate != null)
      ('Fecha completado', _libraryDate(item.completedDate!)),
    if (item.releaseYear != null) ('Año', item.releaseYear.toString()),
    if (item.type != LibraryItemType.game && item.format?.isNotEmpty == true)
      ('Formato', item.format!),
    if (item.genre?.isNotEmpty == true) ('Género', item.genre!),
    if (item.note?.isNotEmpty == true) ('Notas', item.note!),
  ];
  return switch (item.type) {
    LibraryItemType.game => [
        if (item.platform?.isNotEmpty == true) ('Plataforma', item.platform!),
        ...common,
        if (item.developer?.isNotEmpty == true)
          ('Desarrollador', item.developer!),
        if (item.duration?.isNotEmpty == true)
          ('Horas jugadas', item.duration!),
        if (item.rating != null) ('Valoración', item.rating!.toString()),
      ],
    LibraryItemType.book => [
        if (item.author?.isNotEmpty == true) ('Autor', item.author!),
        ...common,
        if (item.creatorOrDirector?.isNotEmpty == true)
          ('Tipo', item.creatorOrDirector!),
        if (item.creatorOrDirector == 'Manga' && item.publicationStatus != null)
          (
            'Publicación',
            item.publicationStatus == LibraryPublicationStatus.ongoing
                ? 'En publicación'
                : 'Finalizado'
          ),
        if (item.pages?.isNotEmpty == true)
          ('Páginas / volúmenes', item.pages!),
        if (item.rating != null) ('Valoración', item.rating!.toString()),
      ],
    LibraryItemType.movieSeries => [
        (
          'Tipo',
          item.mediaType == LibraryMediaType.series ? 'Serie' : 'Película'
        ),
        ...common,
        if (item.mediaType == LibraryMediaType.series &&
            item.seasonCount != null)
          ('Temporadas disponibles', item.seasonCount.toString()),
        if (item.mediaType == LibraryMediaType.series &&
            item.nextSeasonConfirmed)
          ('Próxima temporada', 'Confirmada'),
        if (item.creatorOrDirector?.isNotEmpty == true)
          ('Director / creador', item.creatorOrDirector!),
        if (item.duration?.isNotEmpty == true) ('Duración', item.duration!),
        if (item.country?.isNotEmpty == true) ('País de origen', item.country!),
        if (item.rating != null) ('Valoración', item.rating!.toString()),
      ],
  };
}

List<(String, String)> _goalDetailFields(LibraryGoal goal) {
  final common = <(String, String)>[
    ('Estado', goal.isCompleted ? 'Completado' : 'Pendiente'),
    ('Año objetivo', goal.targetYear.toString()),
    if (goal.releaseYear != null) ('Año', goal.releaseYear.toString()),
    if (goal.type != LibraryItemType.game && goal.format?.isNotEmpty == true)
      ('Formato', goal.format!),
    if (goal.genre?.isNotEmpty == true) ('Género', goal.genre!),
    if (goal.note?.isNotEmpty == true) ('Notas', goal.note!),
  ];
  return switch (goal.type) {
    LibraryItemType.game => [
        if (goal.platform?.isNotEmpty == true) ('Plataforma', goal.platform!),
        ...common,
        if (goal.developer?.isNotEmpty == true)
          ('Desarrollador', goal.developer!),
        if (goal.duration?.isNotEmpty == true)
          ('Horas previstas', goal.duration!),
      ],
    LibraryItemType.book => [
        if (goal.author?.isNotEmpty == true) ('Autor', goal.author!),
        ...common,
        if (goal.creatorOrDirector?.isNotEmpty == true)
          ('Tipo', goal.creatorOrDirector!),
        if (goal.pages?.isNotEmpty == true)
          ('Páginas / volúmenes', goal.pages!),
      ],
    LibraryItemType.movieSeries => [
        (
          'Tipo',
          goal.mediaType == LibraryMediaType.series ? 'Serie' : 'Película'
        ),
        ...common,
        if (goal.creatorOrDirector?.isNotEmpty == true)
          ('Director / creador', goal.creatorOrDirector!),
        if (goal.duration?.isNotEmpty == true) ('Duración', goal.duration!),
        if (goal.country?.isNotEmpty == true) ('País de origen', goal.country!),
      ],
  };
}

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
      LibrarySortOrder.releaseYearDesc => 'Año de salida',
      LibrarySortOrder.releaseYearAsc => 'Año de salida antiguo',
      LibrarySortOrder.creatorAsc => 'Creador / autor',
      LibrarySortOrder.genreAsc => 'Género',
      LibrarySortOrder.platformAsc => 'Plataforma',
      LibrarySortOrder.formatAsc => 'Formato',
      LibrarySortOrder.pagesDesc => 'Más páginas',
      LibrarySortOrder.pagesAsc => 'Menos páginas',
      LibrarySortOrder.durationDesc => 'Más duración',
      LibrarySortOrder.durationAsc => 'Menos duración',
      LibrarySortOrder.countryAsc => 'País',
    };

String _sortLabelForType(LibrarySortOrder order, LibraryItemType type) {
  if (order == LibrarySortOrder.releaseYearDesc) {
    return switch (type) {
      LibraryItemType.game => 'Año de salida',
      LibraryItemType.book => 'Año de publicación',
      LibraryItemType.movieSeries => 'Año de estreno',
    };
  }
  if (order == LibrarySortOrder.releaseYearAsc) {
    return switch (type) {
      LibraryItemType.game => 'Salida más antigua',
      LibraryItemType.book => 'Publicación más antigua',
      LibraryItemType.movieSeries => 'Estreno más antiguo',
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

List<LibrarySortOrder> _sortOptionsForAll() => const [
      LibrarySortOrder.newestFirst,
      LibrarySortOrder.oldestFirst,
      LibrarySortOrder.titleAsc,
      LibrarySortOrder.titleDesc,
      LibrarySortOrder.highestRating,
      LibrarySortOrder.releaseYearDesc,
      LibrarySortOrder.releaseYearAsc,
      LibrarySortOrder.creatorAsc,
      LibrarySortOrder.genreAsc,
    ];

int _compareLibraryItems(
  LibraryItem left,
  LibraryItem right,
  LibrarySortOrder order,
) {
  final result = switch (order) {
    LibrarySortOrder.newestFirst => (right.completedDate ?? right.updatedAt)
        .compareTo(left.completedDate ?? left.updatedAt),
    LibrarySortOrder.oldestFirst => (left.completedDate ?? left.updatedAt)
        .compareTo(right.completedDate ?? right.updatedAt),
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
    item.collectionName,
    item.collectionNumber?.toString(),
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
  final extension = await _detectCoverExtension(file);
  if (extension == null) {
    return null;
  }
  final directory = await _libraryCoversDirectory();
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final target =
      File('${directory.path}${Platform.pathSeparator}cover_$stamp$extension');
  await file.saveTo(target.path);
  return target.path;
}

Future<String?> _copyLibraryCoverBytes(Uint8List bytes) async {
  final extension = _coverExtensionFromSignature(bytes);
  if (extension == null) return null;
  final directory = await _libraryCoversDirectory();
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final target =
      File('${directory.path}${Platform.pathSeparator}cover_$stamp$extension');
  await target.writeAsBytes(bytes, flush: true);
  return target.path;
}

Future<String?> _detectCoverExtension(XFile file) async {
  final signature = await _readCoverSignature(file.openRead);
  return _coverExtensionFromSignature(signature);
}

Future<List<int>> _readCoverSignature(
  Stream<List<int>> Function([int? start, int? end]) openRead,
) async {
  final bytes = <int>[];
  await for (final chunk in openRead(0, 16)) {
    bytes.addAll(chunk);
    if (bytes.length >= 16) {
      break;
    }
  }
  return bytes.length > 16 ? bytes.sublist(0, 16) : bytes;
}

String? _coverExtensionFromSignature(List<int> bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return '.jpg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return '.png';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
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
