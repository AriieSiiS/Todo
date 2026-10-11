part of 'app_shell.dart';

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
