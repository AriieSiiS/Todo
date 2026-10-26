part of 'app_shell.dart';

enum _LibraryContextAction {
  pages,
  complete,
  rating,
  progress,
  edit,
  delete,
}

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
  String? _allUniverse;
  String? _allSaga;

  TodoWorkspace get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _allSearchController = TextEditingController();
    _typeFilter = controller.libraryTypeView;
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
    final allUniverses =
        _libraryDistinctNames(statusFilteredItems.map((i) => i.universeName));
    final allSagas = _libraryDistinctNames(statusFilteredItems
        .where((i) => _allUniverse == null || i.universeName == _allUniverse)
        .map((i) => i.collectionName));
    final allFilters = <Widget>[
      if (allUniverses.isNotEmpty)
        _LibraryFilterButton(
          tooltip: 'Filtrar por universo',
          allLabel: 'Universos',
          selected: _allUniverse,
          options: allUniverses,
          onSelected: (value) => setState(() {
            _allUniverse = value;
            _allSaga = null;
          }),
        ),
      if (allSagas.isNotEmpty)
        _LibraryFilterButton(
          tooltip: 'Filtrar por saga',
          allLabel: 'Sagas',
          selected: _allSaga,
          options: allSagas,
          onSelected: (value) => setState(() => _allSaga = value),
        ),
    ];

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
                showStatistics: area == LibraryAreaView.library &&
                    _typeFilter == LibraryItemType.book,
                libraryStatus: status,
                onYearChanged: (year) => setState(() => _year = year),
                onStatistics: () => showDialog<void>(
                    context: context,
                    builder: (_) => ListenableBuilder(
                        listenable: controller,
                        builder: (context, child) =>
                            AnnualReadingStatisticsDialog(
                                books: controller.libraryItems,
                                goals: controller.libraryGoals,
                                coverBuilder: (book) => _LibraryCoverImage(
                                    source: book.coverUrl,
                                    type: book.type)))),
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
                                onSelectedTypeChanged: (type) {
                                  controller.setLibraryTypeView(type);
                                  setState(() => _typeFilter = type);
                                },
                                status: status,
                                showStatus: false,
                                overviewMode: _overviewMode,
                                onOverviewModeChanged: (mode) =>
                                    setState(() => _overviewMode = mode),
                                allSearchController: _allSearchController,
                                allFilters: allFilters,
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
                              onSelectedTypeChanged: (type) {
                                controller.setLibraryTypeView(type);
                                setState(() => _typeFilter = type);
                              },
                              status: status,
                              showStatus: false,
                              overviewMode: _overviewMode,
                              onOverviewModeChanged: (mode) =>
                                  setState(() => _overviewMode = mode),
                              allSearchController: _allSearchController,
                              allFilters: allFilters,
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
    final query = _allSearchController.text.trim().paraBuscar;
    final filtered = source
        .where(
            (item) => _allUniverse == null || item.universeName == _allUniverse)
        .where((item) => _allSaga == null || item.collectionName == _allSaga)
        .where((item) =>
            query.isEmpty || _searchableText(item).paraBuscar.contains(query))
        .toList();
    final sorted = [...filtered];
    sorted.sort(
      (left, right) => _compareLibraryItems(
        left,
        right,
        _effectiveSortOrderForAll(_allSortOrder),
      ),
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
    required this.showStatistics,
    required this.libraryStatus,
    required this.onYearChanged,
    required this.onAdd,
    required this.onStatistics,
  });

  final int year;
  final int currentYear;
  final List<int> availableYears;
  final bool isGoals;
  final bool showStatistics;
  final LibraryItemStatus? libraryStatus;
  final ValueChanged<int> onYearChanged;
  final VoidCallback onAdd;
  final VoidCallback onStatistics;

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
          if (showStatistics)
            IconButton(
                tooltip: 'Estadísticas de lectura',
                onPressed: onStatistics,
                icon: const Icon(Icons.insights_outlined)),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FilterPill(
          label: 'Todas',
          icon: Icons.inventory_2_outlined,
          selected: selected == null,
          onTap: () => onChanged(null),
        ),
        for (final type in LibraryItemType.values) ...[
          const SizedBox(width: 10),
          _FilterPill(
            label: _libraryTypePluralLabel(type),
            icon: _libraryIcon(type),
            selected: selected == type,
            onTap: () => onChanged(type),
          ),
        ],
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
    required this.allFilters,
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
  final List<Widget> allFilters;
  final LibrarySortOrder allSortOrder;
  final VoidCallback onAllSearchChanged;
  final ValueChanged<LibrarySortOrder> onAllSortChanged;
  final bool scrollColumns;
  final bool fillAvailableHeight;

  @override
  Widget build(BuildContext context) {
    // Los menús de los elementos añaden estas opciones tras las suyas.
    _libraryAddMenuContext = _libraryAddMenuRequest(
      controller: controller,
      selectedType: selectedType,
      status: status,
    );
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
        sortOrder: allSortOrder,
        onSortChanged: onAllSortChanged,
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
      extraFilters: allFilters,
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
    required this.extraFilters,
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
  final List<Widget> extraFilters;
  final LibrarySortOrder sortOrder;
  final VoidCallback onSearchChanged;
  final ValueChanged<LibrarySortOrder> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return _LibraryToolbarRow(
      chips: filters,
      controls: [
        ...extraFilters.map((f) => _LibraryToolbarControl(f, 120, 60)),
        _LibraryToolbarControl(
          SizedBox(
            width: 230,
            child: _CompactLibrarySearchField(
              controller: searchController,
              onChanged: onSearchChanged,
            ),
          ),
          230,
          64,
          elastico: true,
        ),
        _LibraryToolbarControl(
          _LibrarySortButton(
            label: _sortLabel(_effectiveSortOrderForAll(sortOrder)),
            onSelected: onSortChanged,
          ),
          130,
          70,
        ),      ],
      trailing: _LibraryOverviewModeToggle(
        value: mode,
        onChanged: onModeChanged,
      ),
    );
  }
}

/// Control de la barra con su ancho ideal y el mínimo al que puede encogerse.
class _LibraryToolbarControl {
  const _LibraryToolbarControl(
    this.child,
    this.ideal,
    this.minimo, {
    this.elastico = false,
  });

  final Widget child;
  final double ideal;
  final double minimo;

  /// Los elásticos (la búsqueda) ceden ancho antes que los demás.
  final bool elastico;
}

List<double> _repartirAnchos(
  List<_LibraryToolbarControl> controles,
  double disponible,
) {
  var falta = controles.fold<double>(0, (s, c) => s + c.ideal) - disponible;
  final anchos = [for (final c in controles) c.ideal];
  for (final soloElasticos in [true, false]) {
    if (falta <= 0) break;
    final candidatos = [
      for (var i = 0; i < controles.length; i++)
        if (!soloElasticos || controles[i].elastico) i,
    ];
    final margen = candidatos.fold<double>(
      0,
      (s, i) => s + anchos[i] - controles[i].minimo,
    );
    if (margen <= 0) continue;
    final recorte = falta < margen ? falta : margen;
    for (final i in candidatos) {
      anchos[i] -= recorte * (anchos[i] - controles[i].minimo) / margen;
    }
    falta -= recorte;
  }
  return anchos;
}

/// Fila común de Biblioteca: los chips de tipo siempre en una sola línea a la
/// izquierda y los controles a la derecha, centrados con ellos. Si falta
/// espacio, los controles se encogen en lugar de partir los chips.
class _LibraryToolbarRow extends StatelessWidget {
  const _LibraryToolbarRow({
    required this.chips,
    required this.controls,
    this.trailing,
  });

  final Widget chips;
  final List<_LibraryToolbarControl> controls;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        chips,
        const SizedBox(width: 16),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Reparte el ancho: cada control conserva su tamaño ideal y,
              // si falta sitio, todos ceden a la vez hasta su mínimo.
              final fijo = (trailing == null ? 0 : 86) +
                  10.0 * (controls.length - 1);
              final anchos = _repartirAnchos(
                controls,
                constraints.maxWidth - fijo,
              );
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (var i = 0; i < controls.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: anchos[i]),
                      child: controls[i].child,
                    ),
                  ],
                  if (trailing != null) ...[
                    const SizedBox(width: 10),
                    trailing!,
                  ],
                ],
              );
            },
          ),
        ),
      ],
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
    required this.sortOrder,
    required this.onSortChanged,
  });

  final LibrarySortOrder sortOrder;
  final ValueChanged<LibrarySortOrder> onSortChanged;
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
  late final TextEditingController _searchController;
  String? _universe;
  String? _saga;

  LibrarySortOrder get _sortOrder =>
      _effectiveSortOrderForType(widget.sortOrder, widget.type);

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
    final universes = _distinctNames(widget.controller.libraryItems
        .where((i) => i.type == widget.type)
        .map((i) => i.universeName));
    final sagas = _distinctNames(widget.items
        .where((i) => _universe == null || i.universeName == _universe)
        .map((i) => i.collectionName));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LibraryToolbarRow(
          chips: widget.typeFilters,
          controls: [
            if (universes.isNotEmpty)
              _LibraryToolbarControl(
                _LibraryFilterButton(
                  tooltip: 'Filtrar por universo',
                  allLabel: 'Universos',
                  selected: _universe,
                  options: universes,
                  onSelected: (value) => setState(() {
                    _universe = value;
                    _saga = null;
                  }),
                ),
                130,
                60,
              ),
            if (sagas.isNotEmpty)
              _LibraryToolbarControl(
                _LibraryFilterButton(
                  tooltip: 'Filtrar por saga',
                  allLabel: 'Sagas',
                  selected: _saga,
                  options: sagas,
                  onSelected: (value) => setState(() => _saga = value),
                ),
                110,
                60,
              ),
            _LibraryToolbarControl(
              SizedBox(
                width: 230,
                child: _CompactLibrarySearchField(
                  controller: _searchController,
                  onChanged: () => setState(() {}),
                ),
              ),
              230,
              64,
              elastico: true,
            ),
            _LibraryToolbarControl(
              _LibrarySortButton(
                label: _sortLabelForType(_sortOrder, widget.type),
                type: widget.type,
                onSelected: widget.onSortChanged,
              ),
              130,
              70,
            ),
          ],
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
    final query = _searchController.text.trim().paraBuscar;
    return source
        .where((item) => _universe == null || item.universeName == _universe)
        .where((item) => _saga == null || item.collectionName == _saga)
        .where((item) =>
            query.isEmpty || _searchableText(item).paraBuscar.contains(query))
        .toList();
  }

  List<String> _distinctNames(Iterable<String?> values) =>
      _libraryDistinctNames(values);

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
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF34362F),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
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

List<String> _libraryDistinctNames(Iterable<String?> values) {
  final names = values
      .map((value) => value?.trim() ?? '')
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();
  names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return names;
}

class _LibraryFilterButton extends StatelessWidget {
  const _LibraryFilterButton({
    required this.tooltip,
    required this.allLabel,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  final String tooltip;
  final String allLabel;
  final String? selected;
  final List<String> options;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: tooltip,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      onSelected: (value) => onSelected(value.isEmpty ? null : value),
      itemBuilder: (context) => [
        PopupMenuItem(value: '', child: Text(allLabel)),
        for (final option in options)
          PopupMenuItem(value: option, child: Text(option)),
      ],
      child: IgnorePointer(
        child: Container(
          height: 38,
          constraints: const BoxConstraints(maxWidth: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE8DCCB)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  selected ?? allLabel,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF34362F),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
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
