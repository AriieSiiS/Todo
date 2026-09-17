// ignore_for_file: unused_element

part of 'app_shell.dart';

class _LegacyTodayPage extends StatelessWidget {
  const _LegacyTodayPage({required this.controller});

  final TodoWorkspace controller;

  @override
  Widget build(BuildContext context) {
    final today = controller.tasksForToday();
    final notes = controller.inboxNotes();
    final logicalToday = controller.logicalDate();
    final wide = MediaQuery.sizeOf(context).width >= 1200;
    final completedCount = controller.completedTasks().where((task) {
      final scheduled = task.scheduledAt;
      return scheduled != null && _sameDay(scheduled, logicalToday);
    }).length;

    final summary = Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _MetricCard(
          label: 'Activas hoy',
          value: today.length.toString(),
          detail: 'Tareas visibles para hoy',
          tone: const Color(0xFF6E835B),
        ),
        _MetricCard(
          label: 'Notas',
          value: notes.length.toString(),
          detail: 'Ideas y recordatorios guardados',
          tone: const Color(0xFFB2705A),
        ),
        _MetricCard(
          label: 'Completadas',
          value: completedCount.toString(),
          detail: 'Movimiento ya resuelto hoy',
          tone: const Color(0xFF6C7B8E),
        ),
      ],
    );

    final mainColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          title: 'Hoy',
          subtitle:
              '${logicalToday.day}/${logicalToday.month}/${logicalToday.year}',
          trailing: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _HeaderActionButton(
                label: 'Nueva tarea',
                icon: Icons.add_rounded,
                onPressed: () => showTaskEditor(context, controller),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        summary,
        const SizedBox(height: 18),
        const SizedBox(height: 8),
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Captura rápida',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _QuickCaptureBar(controller: controller),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: _SurfaceCard(
            padding: const EdgeInsets.all(16),
            child: today.isEmpty
                ? const Center(child: Text('No hay tareas activas para hoy.'))
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: today.length,
                    onReorder: (oldIndex, newIndex) {
                      final reordered = List<TaskModel>.from(today);
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final item = reordered.removeAt(oldIndex);
                      reordered.insert(newIndex, item);
                      controller.changeManualOrder(
                          reordered.map((task) => task.id).toList());
                    },
                    itemBuilder: (context, index) {
                      final task = today[index];
                      return _TaskCard(
                        key: ValueKey(task.id),
                        controller: controller,
                        task: task,
                      );
                    },
                  ),
          ),
        ),
      ],
    );

    final sideColumn = ListView(
      children: [
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Semana activa',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              ...List<Widget>.generate(7, (index) {
                final day = logicalToday.add(Duration(days: index));
                final count = controller
                    .tasksForDate(day)
                    .where((task) => task.scheduledAt != null)
                    .length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(child: Text(_weekdayLabel(day))),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9E2D8),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('$count'),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Notas',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                  FilledButton.tonal(
                    onPressed: controller.reorganizeDay,
                    child: const Text('Ordenar'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (notes.isEmpty)
                const Text('No tienes notas guardadas.')
              else
                ...notes.map(
                  (note) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFCF7),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE4D5C2)),
                      ),
                      child: ListTile(
                        title: Text(
                          '${note.emoji} ${_noteTitleFromContent(note.content)}'
                              .trim(),
                        ),
                        subtitle: Text(
                          'Capturada a las ${note.createdAt.hour.toString().padLeft(2, '0')}:${note.createdAt.minute.toString().padLeft(2, '0')}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'task') {
                              showTaskEditor(
                                context,
                                controller,
                                initialTitle:
                                    _noteTitleFromContent(note.content),
                                initialDescription:
                                    _noteDescriptionFromContent(note.content),
                                initialDateOverride: note.scheduledFor,
                              );
                            } else if (value == 'project') {
                              showProjectEditor(
                                context,
                                controller,
                                initialName:
                                    _noteTitleFromContent(note.content),
                                initialDescription:
                                    _noteDescriptionFromContent(note.content),
                              );
                            } else {
                              controller.archiveNote(note.id);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                                value: 'task', child: Text('Crear una tarea')),
                            PopupMenuItem(
                                value: 'project',
                                child: Text('Crear un proyecto')),
                            PopupMenuItem(
                                value: 'archive', child: Text('Archivar')),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: mainColumn),
                const SizedBox(width: 20),
                SizedBox(width: 360, child: sideColumn),
              ],
            )
          : Column(
              children: [
                Expanded(child: mainColumn),
                const SizedBox(height: 18),
                SizedBox(height: 360, child: sideColumn),
              ],
            ),
    );
  }
}

class TodayPage extends StatefulWidget {
  const TodayPage({required this.controller, super.key});

  final TodoWorkspace controller;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  String? _categoryFilterId;
  bool _showCompleted = false;
  bool _subtasksExpanded = true;
  bool _selectionMode = false;
  late DateTime _selectedDay;
  final Set<String> _selectedTaskIds = <String>{};
  final Map<String, TaskModel> _completionGhosts = <String, TaskModel>{};
  final Set<String> _completionMarkedTaskIds = <String>{};
  final Set<String> _completionFadingTaskIds = <String>{};

  TodoWorkspace get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _selectedDay = controller.logicalDate();
  }

  @override
  Widget build(BuildContext context) {
    final logicalToday = controller.logicalDate();
    final allDayTasks = controller.tasksForDate(_selectedDay);
    final visibleToday = _withCompletionGhosts(_applyTodayFilter(allDayTasks));
    final notes = controller.inboxNotes();
    final todayCompleted = controller.completedTasks().where((task) {
      final scheduled = task.completedAt ?? task.scheduledAt;
      return !task.isSubtask &&
          scheduled != null &&
          _sameDay(controller.logicalDate(scheduled), _selectedDay);
    }).toList();
    final selectedTasks = _selectedTasks();
    final wide = MediaQuery.sizeOf(context).width >= 1240;
    final progressDenominator = allDayTasks.length + todayCompleted.length;
    final progress = progressDenominator == 0
        ? 0.0
        : todayCompleted.length / progressDenominator;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReferenceTodayHeader(
            controller: controller,
            selectedDay: _selectedDay,
            logicalToday: logicalToday,
            activeFilterLabel: _activeFilterLabel(),
            activeFilterId: _categoryFilterId,
            onCreateTask: () => showTaskEditor(context, controller),
            onSortChanged: controller.setTodaySort,
            onFilterChanged: _setCategoryFilter,
            onReorder: controller.reorganizeDay,
            onMovePreviousDay: _moveToPreviousLogicalDay,
            onAdvanceDay: _advanceToNextLogicalDay,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _ReferenceTodayBoard(
                          controller: controller,
                          selectedDay: _selectedDay,
                          logicalToday: logicalToday,
                          tasks: visibleToday,
                          hasActiveFilter: _categoryFilterId != null,
                          showFilterBadge: _categoryFilterId != null,
                          subtasksExpanded: _subtasksExpanded,
                          onToggleSubtasks: () {
                            setState(() {
                              _subtasksExpanded = !_subtasksExpanded;
                            });
                          },
                          completedTasks: todayCompleted,
                          showCompleted: _showCompleted,
                          selectionMode: _selectionMode,
                          selectedTaskIds: _selectedTaskIds,
                          selectedCount: selectedTasks.length,
                          selectedHasActive: selectedTasks.any(
                              (task) => task.status != TaskStatus.completed),
                          selectedHasCompleted: selectedTasks.any(
                              (task) => task.status == TaskStatus.completed),
                          onToggleCompleted: () {
                            setState(() {
                              _showCompleted = !_showCompleted;
                            });
                          },
                          onToggleSelectionMode: _toggleSelectionMode,
                          onToggleTaskSelection: _toggleTaskSelection,
                          onStartSelection: _startSelection,
                          onSelectVisible: () => _toggleVisibleSelection(
                            [
                              ...visibleToday,
                              if (_showCompleted) ...todayCompleted,
                            ],
                          ),
                          onMoveSelectedToTomorrow: _moveSelectedToTomorrow,
                          onCompleteSelected: _completeSelectedTasks,
                          onReopenSelected: _reopenSelectedTasks,
                          onDeleteSelected: _deleteSelectedTasks,
                          onToggleCompletion: _toggleTaskCompletion,
                          onToggleTaskCollapse: _toggleTaskCollapse,
                          completionMarkedTaskIds: _completionMarkedTaskIds,
                          completionFadingTaskIds: _completionFadingTaskIds,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Align(
                        alignment: Alignment.topCenter,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: 314,
                            child: Column(
                              children: [
                                _ReferenceWeekPanel(
                                  controller: controller,
                                  logicalToday: logicalToday,
                                  selectedDay: _selectedDay,
                                  onSelectDay: _setSelectedDay,
                                ),
                                const SizedBox(height: 12),
                                _ReferenceInboxPanel(
                                    controller: controller, notes: notes),
                                const SizedBox(height: 12),
                                _ReferenceSummaryPanel(
                                  totalTasks: allDayTasks.length,
                                  completedTasks: todayCompleted.length,
                                  progress: progress,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    children: [
                      SizedBox(
                        height:
                            max(520, MediaQuery.sizeOf(context).height * 0.68),
                        child: _ReferenceTodayBoard(
                          controller: controller,
                          selectedDay: _selectedDay,
                          logicalToday: logicalToday,
                          tasks: visibleToday,
                          hasActiveFilter: _categoryFilterId != null,
                          showFilterBadge: _categoryFilterId != null,
                          subtasksExpanded: _subtasksExpanded,
                          onToggleSubtasks: () {
                            setState(() {
                              _subtasksExpanded = !_subtasksExpanded;
                            });
                          },
                          completedTasks: todayCompleted,
                          showCompleted: _showCompleted,
                          selectionMode: _selectionMode,
                          selectedTaskIds: _selectedTaskIds,
                          selectedCount: selectedTasks.length,
                          selectedHasActive: selectedTasks.any(
                              (task) => task.status != TaskStatus.completed),
                          selectedHasCompleted: selectedTasks.any(
                              (task) => task.status == TaskStatus.completed),
                          onToggleCompleted: () {
                            setState(() {
                              _showCompleted = !_showCompleted;
                            });
                          },
                          onToggleSelectionMode: _toggleSelectionMode,
                          onToggleTaskSelection: _toggleTaskSelection,
                          onStartSelection: _startSelection,
                          onSelectVisible: () => _toggleVisibleSelection(
                            [
                              ...visibleToday,
                              if (_showCompleted) ...todayCompleted,
                            ],
                          ),
                          onMoveSelectedToTomorrow: _moveSelectedToTomorrow,
                          onCompleteSelected: _completeSelectedTasks,
                          onReopenSelected: _reopenSelectedTasks,
                          onDeleteSelected: _deleteSelectedTasks,
                          onToggleCompletion: _toggleTaskCompletion,
                          onToggleTaskCollapse: _toggleTaskCollapse,
                          completionMarkedTaskIds: _completionMarkedTaskIds,
                          completionFadingTaskIds: _completionFadingTaskIds,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ReferenceWeekPanel(
                        controller: controller,
                        logicalToday: logicalToday,
                        selectedDay: _selectedDay,
                        onSelectDay: _setSelectedDay,
                      ),
                      const SizedBox(height: 16),
                      _ReferenceInboxPanel(
                          controller: controller, notes: notes),
                      const SizedBox(height: 16),
                      _ReferenceSummaryPanel(
                        totalTasks: allDayTasks.length,
                        completedTasks: todayCompleted.length,
                        progress: progress,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  List<TaskModel> _applyTodayFilter(List<TaskModel> source) {
    if (_categoryFilterId == null) {
      return source;
    }
    return source
        .where((task) => task.categoryIds.contains(_categoryFilterId))
        .toList();
  }

  List<TaskModel> _withCompletionGhosts(List<TaskModel> source) {
    if (_completionGhosts.isEmpty) {
      return source;
    }
    final result = List<TaskModel>.from(source);
    final ids = result.map((task) => task.id).toSet();
    for (final ghost in _completionGhosts.values) {
      if (ids.contains(ghost.id)) {
        continue;
      }
      if (_categoryFilterId != null &&
          !ghost.categoryIds.contains(_categoryFilterId)) {
        continue;
      }
      result.add(ghost);
    }
    result.sort((left, right) => left.manualOrder.compareTo(right.manualOrder));
    return result;
  }

  String _activeFilterLabel() {
    if (_categoryFilterId == null) {
      return 'Todas';
    }
    return controller.categoryById(_categoryFilterId!)?.name ?? 'Todas';
  }

  void _setCategoryFilter(String? selected) {
    if (!mounted || selected == _categoryFilterId) {
      return;
    }
    setState(() {
      _categoryFilterId = selected;
      _selectionMode = false;
      _selectedTaskIds.clear();
      _clearCompletionAnimation();
    });
  }

  void _setSelectedDay(DateTime selected) {
    if (!mounted || _sameDay(selected, _selectedDay)) {
      return;
    }
    setState(() {
      _selectedDay = DateTime(selected.year, selected.month, selected.day);
      _showCompleted = false;
      _selectionMode = false;
      _selectedTaskIds.clear();
      _clearCompletionAnimation();
    });
  }

  void _moveToPreviousLogicalDay() {
    controller.moveToPreviousLogicalDay();
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedDay = controller.logicalDate();
      _showCompleted = false;
      _selectionMode = false;
      _selectedTaskIds.clear();
      _clearCompletionAnimation();
    });
  }

  void _advanceToNextLogicalDay() {
    controller.advanceToNextLogicalDay();
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedDay = controller.logicalDate();
      _showCompleted = false;
      _selectionMode = false;
      _selectedTaskIds.clear();
      _clearCompletionAnimation();
    });
  }

  List<TaskModel> _selectedTasks() {
    return _selectedTaskIds
        .map(controller.taskById)
        .whereType<TaskModel>()
        .toList();
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) {
        _selectedTaskIds.clear();
      }
    });
  }

  void _startSelection(String taskId) {
    setState(() {
      _selectionMode = true;
      _selectedTaskIds.add(taskId);
    });
  }

  void _toggleTaskSelection(String taskId) {
    setState(() {
      _selectionMode = true;
      if (_selectedTaskIds.contains(taskId)) {
        _selectedTaskIds.remove(taskId);
      } else {
        _selectedTaskIds.add(taskId);
      }
      if (_selectedTaskIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _toggleTaskCompletion(String taskId) {
    if (_completionMarkedTaskIds.contains(taskId)) {
      return;
    }
    final task = controller.taskById(taskId);
    final alreadyCompleted =
        task != null && controller.isTaskCompletedOnDay(task, _selectedDay);
    if (task != null && !task.isSubtask && !alreadyCompleted) {
      setState(() {
        _completionGhosts[taskId] = task;
        _completionMarkedTaskIds.add(taskId);
      });
      Timer(const Duration(milliseconds: 900), () {
        if (!mounted) {
          return;
        }
        unawaited(controller.completeTask(taskId));
        setState(() {
          _completionFadingTaskIds.add(taskId);
        });
      });
      Timer(const Duration(milliseconds: 1550), () {
        if (!mounted) {
          return;
        }
        setState(() {
          _completionGhosts.remove(taskId);
          _completionMarkedTaskIds.remove(taskId);
          _completionFadingTaskIds.remove(taskId);
        });
      });
      return;
    }
    controller.completeTask(taskId).then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  void _clearCompletionAnimation() {
    _completionGhosts.clear();
    _completionMarkedTaskIds.clear();
    _completionFadingTaskIds.clear();
  }

  void _toggleTaskCollapse(String taskId) {
    controller.toggleTaskCollapse(taskId);
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _toggleVisibleSelection(List<TaskModel> tasks) {
    final ids = tasks.map((task) => task.id).toSet();
    if (ids.isEmpty) {
      return;
    }
    setState(() {
      _selectionMode = true;
      final allSelected = ids.every(_selectedTaskIds.contains);
      if (allSelected) {
        _selectedTaskIds.removeAll(ids);
      } else {
        _selectedTaskIds.addAll(ids);
      }
      if (_selectedTaskIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  Future<void> _moveSelectedToTomorrow() async {
    final ids = _selectedTaskIds.toList(growable: false);
    if (ids.isEmpty) {
      return;
    }
    await controller.moveTasksToDay(
      ids,
      _selectedDay.add(const Duration(days: 1)),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectionMode = false;
      _selectedTaskIds.clear();
    });
  }

  Future<void> _completeSelectedTasks() async {
    final ids = _selectedTasks()
        .where((task) => task.status != TaskStatus.completed)
        .map((task) => task.id)
        .toList(growable: false);
    if (ids.isEmpty) {
      return;
    }
    await controller.completeTasks(ids);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectionMode = false;
      _selectedTaskIds.clear();
    });
  }

  void _reopenSelectedTasks() {
    final ids = _selectedTasks()
        .where((task) => task.status == TaskStatus.completed)
        .map((task) => task.id)
        .toList(growable: false);
    if (ids.isEmpty) {
      return;
    }
    controller.reopenTasks(ids);
    setState(() {
      _selectionMode = false;
      _selectedTaskIds.clear();
    });
  }

  void _deleteSelectedTasks() {
    final ids = _selectedTaskIds.toList(growable: false);
    if (ids.isEmpty) {
      return;
    }
    controller.deleteTasks(ids);
    setState(() {
      _selectionMode = false;
      _selectedTaskIds.clear();
      _showCompleted = false;
    });
  }
}

class _ReferenceTodayHeader extends StatelessWidget {
  const _ReferenceTodayHeader({
    required this.controller,
    required this.selectedDay,
    required this.logicalToday,
    required this.activeFilterId,
    required this.activeFilterLabel,
    required this.onCreateTask,
    required this.onSortChanged,
    required this.onFilterChanged,
    required this.onReorder,
    required this.onMovePreviousDay,
    required this.onAdvanceDay,
  });
  final TodoWorkspace controller;
  final DateTime selectedDay;
  final DateTime logicalToday;
  final String? activeFilterId;
  final String activeFilterLabel;
  final VoidCallback onCreateTask;
  final ValueChanged<TodaySort> onSortChanged;
  final ValueChanged<String?> onFilterChanged;
  final VoidCallback onReorder;
  final VoidCallback onMovePreviousDay;
  final VoidCallback onAdvanceDay;
  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final narrow = MediaQuery.sizeOf(context).width < 1080;
    final heading =
        _sameDay(selectedDay, logicalToday) ? 'Hoy' : _weekdayLong(selectedDay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(heading,
                      style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 6),
                  Text(
                    '${selectedDay.day}/${selectedDay.month}/${selectedDay.year}',
                    style: TextStyle(
                        color: visuals.textMuted, fontSize: 15, height: 1.2),
                  ),
                ],
              ),
            ),
            if (!narrow)
              _ReferenceHeaderControls(
                controller: controller,
                activeFilterId: activeFilterId,
                activeFilterLabel: activeFilterLabel,
                onCreateTask: onCreateTask,
                onSortChanged: onSortChanged,
                onFilterChanged: onFilterChanged,
                onReorder: onReorder,
                onMovePreviousDay: onMovePreviousDay,
                onAdvanceDay: onAdvanceDay,
              ),
          ],
        ),
        if (narrow) ...[
          const SizedBox(height: 14),
          _ReferenceHeaderControls(
            controller: controller,
            activeFilterId: activeFilterId,
            activeFilterLabel: activeFilterLabel,
            onCreateTask: onCreateTask,
            onSortChanged: onSortChanged,
            onFilterChanged: onFilterChanged,
            onReorder: onReorder,
            onMovePreviousDay: onMovePreviousDay,
            onAdvanceDay: onAdvanceDay,
          ),
        ],
      ],
    );
  }
}

class _ReferenceHeaderControls extends StatelessWidget {
  const _ReferenceHeaderControls({
    required this.controller,
    required this.activeFilterId,
    required this.activeFilterLabel,
    required this.onCreateTask,
    required this.onSortChanged,
    required this.onFilterChanged,
    required this.onReorder,
    required this.onMovePreviousDay,
    required this.onAdvanceDay,
  });
  final TodoWorkspace controller;
  final String? activeFilterId;
  final String activeFilterLabel;
  final VoidCallback onCreateTask;
  final ValueChanged<TodaySort> onSortChanged;
  final ValueChanged<String?> onFilterChanged;
  final VoidCallback onReorder;
  final VoidCallback onMovePreviousDay;
  final VoidCallback onAdvanceDay;
  @override
  Widget build(BuildContext context) {
    final activeCategories =
        controller.categories.where((category) => category.active).toList();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _TodayHeaderButton(
          icon: Icons.add_rounded,
          label: 'Nueva tarea',
          primary: true,
          onTap: onCreateTask,
        ),
        _TodayShiftDayButton(
          icon: Icons.skip_previous_rounded,
          tooltip: 'Volver al día anterior',
          active: controller.hasManualLogicalDate,
          onTap: onMovePreviousDay,
        ),
        _TodayAdvanceDayButton(
          controller: controller,
          onTap: onAdvanceDay,
        ),
        PopupMenuButton<String?>(
          tooltip: 'Filtrar tareas',
          initialValue: activeFilterId,
          offset: const Offset(0, 8),
          onSelected: onFilterChanged,
          itemBuilder: (context) => [
            CheckedPopupMenuItem<String?>(
              value: null,
              checked: activeFilterId == null,
              child: const Text('Todas las categorías'),
            ),
            ...activeCategories.map(
              (category) => CheckedPopupMenuItem<String?>(
                value: category.id,
                checked: activeFilterId == category.id,
                child: Text(category.name),
              ),
            ),
          ],
          child: const _TodayHeaderButton(
            icon: Icons.filter_alt_outlined,
            label: 'Filtrar',
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Ordenar tareas',
          initialValue: controller.todaySort.name,
          offset: const Offset(0, 8),
          onSelected: (value) {
            if (value == 'rebalance') {
              onReorder();
              return;
            }
            onSortChanged(TodaySort.values.byName(value));
          },
          itemBuilder: (context) => [
            CheckedPopupMenuItem<String>(
              value: TodaySort.manual.name,
              checked: controller.todaySort == TodaySort.manual,
              child: const Text('Manual'),
            ),
            CheckedPopupMenuItem<String>(
              value: TodaySort.priority.name,
              checked: controller.todaySort == TodaySort.priority,
              child: const Text('Prioridad'),
            ),
            CheckedPopupMenuItem<String>(
              value: TodaySort.time.name,
              checked: controller.todaySort == TodaySort.time,
              child: const Text('Hora'),
            ),
            CheckedPopupMenuItem<String>(
              value: TodaySort.category.name,
              checked: controller.todaySort == TodaySort.category,
              child: const Text('Categoría'),
            ),
            CheckedPopupMenuItem<String>(
              value: TodaySort.project.name,
              checked: controller.todaySort == TodaySort.project,
              child: const Text('Proyecto'),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'rebalance',
              child: Text('Reorganizar por prioridad'),
            ),
          ],
          child: const _TodayHeaderButton(
            icon: Icons.swap_vert_rounded,
            label: 'Ordenar',
          ),
        ),
      ],
    );
  }
}

class _TodayHeaderButton extends StatelessWidget {
  const _TodayHeaderButton({
    required this.icon,
    required this.label,
    this.primary = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final background =
        primary ? const Color(0xFF263625) : const Color(0xFFFFFCF8);
    final foreground = primary ? const Color(0xFFFFFCF8) : visuals.textStrong;
    final borderColor =
        primary ? const Color(0xFF263625) : const Color(0xFFE3D4C2);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 154,
          height: 48,
          decoration: ShapeDecoration(
            color: background,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: borderColor),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 15,
                    fontWeight: primary ? FontWeight.w700 : FontWeight.w500,
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

class _TodayAdvanceDayButton extends StatelessWidget {
  const _TodayAdvanceDayButton({
    required this.controller,
    required this.onTap,
  });

  final TodoWorkspace controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = controller.hasManualLogicalDate;
    return _TodayShiftDayButton(
      icon: active ? Icons.check_rounded : Icons.skip_next_rounded,
      tooltip: active ? 'Pasar otro día' : 'Pasar al día siguiente ahora',
      active: active,
      onTap: onTap,
    );
  }
}

class _TodayShiftDayButton extends StatelessWidget {
  const _TodayShiftDayButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final background =
        active ? const Color(0xFFE8F0DF) : const Color(0xFFFFFCF8);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            width: 48,
            height: 48,
            decoration: ShapeDecoration(
              color: background,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  color: active
                      ? const Color(0xFF9BAF81)
                      : const Color(0xFFE3D4C2),
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: active ? const Color(0xFF263625) : visuals.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferenceTodayBoard extends StatelessWidget {
  const _ReferenceTodayBoard({
    required this.controller,
    required this.selectedDay,
    required this.logicalToday,
    required this.tasks,
    required this.hasActiveFilter,
    required this.showFilterBadge,
    required this.subtasksExpanded,
    required this.onToggleSubtasks,
    required this.completedTasks,
    required this.showCompleted,
    required this.onToggleCompleted,
    required this.selectionMode,
    required this.selectedTaskIds,
    required this.selectedCount,
    required this.selectedHasActive,
    required this.selectedHasCompleted,
    required this.onToggleSelectionMode,
    required this.onToggleTaskSelection,
    required this.onStartSelection,
    required this.onSelectVisible,
    required this.onMoveSelectedToTomorrow,
    required this.onCompleteSelected,
    required this.onReopenSelected,
    required this.onDeleteSelected,
    required this.onToggleCompletion,
    required this.onToggleTaskCollapse,
    required this.completionMarkedTaskIds,
    required this.completionFadingTaskIds,
  });

  final TodoWorkspace controller;
  final DateTime selectedDay;
  final DateTime logicalToday;
  final List<TaskModel> tasks;
  final bool hasActiveFilter;
  final bool showFilterBadge;
  final bool subtasksExpanded;
  final VoidCallback onToggleSubtasks;
  final List<TaskModel> completedTasks;
  final bool showCompleted;
  final VoidCallback onToggleCompleted;
  final bool selectionMode;
  final Set<String> selectedTaskIds;
  final int selectedCount;
  final bool selectedHasActive;
  final bool selectedHasCompleted;
  final VoidCallback onToggleSelectionMode;
  final ValueChanged<String> onToggleTaskSelection;
  final ValueChanged<String> onStartSelection;
  final VoidCallback onSelectVisible;
  final Future<void> Function() onMoveSelectedToTomorrow;
  final Future<void> Function() onCompleteSelected;
  final VoidCallback onReopenSelected;
  final VoidCallback onDeleteSelected;
  final ValueChanged<String> onToggleCompletion;
  final ValueChanged<String> onToggleTaskCollapse;
  final Set<String> completionMarkedTaskIds;
  final Set<String> completionFadingTaskIds;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return Column(
      children: [
        Expanded(
          child: _SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                  child: Row(
                    children: [
                      Text(
                        _sameDay(selectedDay, logicalToday)
                            ? 'Tareas de hoy'
                            : 'Tareas del día',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontSize: 21),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: visuals.panelAlt,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${tasks.length}',
                            style: TextStyle(color: visuals.textMuted)),
                      ),
                      if (showFilterBadge) ...[
                        const SizedBox(width: 10),
                        const _SoftChip(
                            label: 'Filtro activo', icon: Icons.tune_rounded),
                      ],
                      const Spacer(),
                      TextButton.icon(
                        onPressed: onToggleSelectionMode,
                        icon: Icon(selectionMode
                            ? Icons.close_rounded
                            : Icons.checklist_rounded),
                        label: Text(selectionMode ? 'Cancelar' : 'Seleccionar'),
                      ),
                      TextButton.icon(
                        onPressed: onToggleSubtasks,
                        icon: Icon(subtasksExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded),
                        label: const Text('Expandir todo'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (selectionMode)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F2E8),
                      border: Border(
                        bottom: BorderSide(color: visuals.panelBorder),
                      ),
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '$selectedCount seleccionadas',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        OutlinedButton(
                          onPressed: onSelectVisible,
                          child: const Text('Seleccionar visibles'),
                        ),
                        if (selectedHasActive)
                          FilledButton.tonalIcon(
                            onPressed: onMoveSelectedToTomorrow,
                            icon: const Icon(Icons.east_rounded),
                            label: const Text('Mañana'),
                          ),
                        if (selectedHasActive)
                          FilledButton.tonalIcon(
                            onPressed: onCompleteSelected,
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Completar'),
                          ),
                        if (selectedHasCompleted)
                          FilledButton.tonalIcon(
                            onPressed: onReopenSelected,
                            icon: const Icon(Icons.undo_rounded),
                            label: const Text('Reabrir'),
                          ),
                        FilledButton.tonalIcon(
                          onPressed: onDeleteSelected,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Borrar'),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: tasks.isEmpty
                      ? Center(
                          child: Text(
                            hasActiveFilter
                                ? 'No hay tareas para este filtro.'
                                : 'No hay tareas para este día.',
                            style: TextStyle(color: visuals.textMuted),
                          ),
                        )
                      : ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          padding: EdgeInsets.zero,
                          itemCount: tasks.length,
                          onReorder: (oldIndex, newIndex) {
                            final reordered = List<TaskModel>.from(tasks);
                            if (newIndex > oldIndex) {
                              newIndex -= 1;
                            }
                            final item = reordered.removeAt(oldIndex);
                            reordered.insert(newIndex, item);
                            controller.setTodaySort(TodaySort.manual);
                            controller.changeManualOrder(
                              reordered.map((task) => task.id).toList(),
                            );
                          },
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return Column(
                              key: ValueKey(task.id),
                              children: [
                                _ReferenceTaskRow(
                                  controller: controller,
                                  task: task,
                                  reorderIndex: index,
                                  subtasksExpanded: subtasksExpanded,
                                  selectionMode: selectionMode,
                                  selected: selectedTaskIds.contains(task.id),
                                  selectedTaskIds: selectedTaskIds,
                                  onToggleSelection: onToggleTaskSelection,
                                  onStartSelection: onStartSelection,
                                  selectedDay: selectedDay,
                                  onToggleCompletion: onToggleCompletion,
                                  onToggleCollapse: onToggleTaskCollapse,
                                  forceCompleted:
                                      completionMarkedTaskIds.contains(task.id),
                                  fadeOut:
                                      completionFadingTaskIds.contains(task.id),
                                ),
                                if (index != tasks.length - 1)
                                  const Divider(height: 1),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              InkWell(
                onTap: onToggleCompleted,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF70835D)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${completedTasks.length} completadas hoy',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Icon(showCompleted
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded),
                    ],
                  ),
                ),
              ),
              if (showCompleted) ...[
                const Divider(height: 1),
                if (completedTasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text('Todavía no hay tareas completadas.',
                        style: TextStyle(color: visuals.textMuted)),
                  )
                else
                  ...completedTasks.map(
                    (task) => Column(
                      children: [
                        _ReferenceCompletedRow(
                          controller: controller,
                          task: task,
                          selectionMode: selectionMode,
                          selected: selectedTaskIds.contains(task.id),
                          onToggleSelection: onToggleTaskSelection,
                          onStartSelection: onStartSelection,
                        ),
                        if (task != completedTasks.last)
                          const Divider(height: 1),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ReferenceTaskRow extends StatelessWidget {
  const _ReferenceTaskRow({
    required this.controller,
    required this.task,
    required this.reorderIndex,
    required this.subtasksExpanded,
    required this.selectionMode,
    required this.selected,
    required this.selectedTaskIds,
    required this.onToggleSelection,
    required this.onStartSelection,
    required this.selectedDay,
    required this.onToggleCompletion,
    required this.onToggleCollapse,
    required this.forceCompleted,
    required this.fadeOut,
  });

  final TodoWorkspace controller;
  final TaskModel task;
  final int reorderIndex;
  final bool subtasksExpanded;
  final bool selectionMode;
  final bool selected;
  final Set<String> selectedTaskIds;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<String> onStartSelection;
  final DateTime selectedDay;
  final ValueChanged<String> onToggleCompletion;
  final ValueChanged<String> onToggleCollapse;
  final bool forceCompleted;
  final bool fadeOut;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final category = task.categoryIds.isNotEmpty
        ? controller.categoryById(task.categoryIds.first)
        : null;
    final project = task.projectIds.isNotEmpty
        ? controller.projectById(task.projectIds.first)
        : null;
    final subtasks = controller.subtasksOf(task);
    final hasSubtasks = subtasks.isNotEmpty;
    final showsSubtasks =
        hasSubtasks && subtasksExpanded && !task.collapsed && !fadeOut;
    final overdue = _isOverdueTask(task, controller.logicalDate());
    final completed =
        forceCompleted || controller.isTaskCompletedOnDay(task, selectedDay);

    final content = Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTapDown: (details) => _showTaskActionsMenu(
            context,
            controller,
            task,
            details.globalPosition,
          ),
          child: InkWell(
            onTap: selectionMode
                ? () => onToggleSelection(task.id)
                : hasSubtasks
                    ? () => onToggleCollapse(task.id)
                    : () =>
                        showTaskEditor(context, controller, initialTask: task),
            onLongPress: selectionMode
                ? () => onToggleSelection(task.id)
                : () => onStartSelection(task.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: Row(
                children: [
                  if (!selectionMode) ...[
                    ReorderableDragStartListener(
                      index: reorderIndex,
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: visuals.textMuted.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (forceCompleted && !selectionMode)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: _CompletionCheckPulse(),
                    )
                  else
                    Checkbox(
                      value: selectionMode ? selected : completed,
                      activeColor: const Color(0xFF70835D),
                      onChanged: (_) => selectionMode
                          ? onToggleSelection(task.id)
                          : onToggleCompletion(task.id),
                    ),
                  const SizedBox(width: 8),
                  if (hasSubtasks && !selectionMode) ...[
                    Icon(
                      task.collapsed
                          ? Icons.keyboard_arrow_right_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: visuals.textMuted,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          task.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontSize: 18,
                                    color: completed
                                        ? const Color(0xFF70835D)
                                        : visuals.textStrong,
                                    decoration: completed
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                        ),
                        if (category != null)
                          _ReferenceTagChip(
                            label: category.name,
                            color: category.color.withValues(alpha: 0.18),
                            textColor: category.color,
                          ),
                        if (project != null)
                          _ReferenceTagChip(
                            label: project.name,
                            color: const Color(0xFFF0ECE4),
                            textColor: const Color(0xFF5D5A54),
                          ),
                        if (overdue)
                          const _ReferenceTagChip(
                            label: 'Tarde',
                            icon: Icons.warning_amber_rounded,
                            color: Color(0xFFFFECE6),
                            textColor: Color(0xFFC04B37),
                          ),
                      ],
                    ),
                  ),
                  if (!selectionMode) _ReferenceTaskStateGlyph(task: task),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 66,
                    child: task.scheduledAt != null &&
                            _hasVisibleTime(task.scheduledAt!)
                        ? Text(
                            _timeLabel(task.scheduledAt!),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                color: visuals.textMuted,
                                fontWeight: FontWeight.w600),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 10),
                  _ReferencePriorityFlag(priority: task.priority),
                  const SizedBox(width: 8),
                  if (!selectionMode)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz_rounded),
                      onSelected: (value) =>
                          _handleTaskAction(context, controller, task, value),
                      itemBuilder: (context) =>
                          _taskActionItems(controller, task),
                    ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: showsSubtasks
              ? Column(
                  key: ValueKey('${task.id}-subtasks-open'),
                  children: subtasks
                      .map(
                        (subtask) => _ReferenceSubtaskRow(
                          controller: controller,
                          task: subtask,
                          selectedDay: selectedDay,
                          selectionMode: selectionMode,
                          selected: selectedTaskIds.contains(subtask.id),
                          onToggleSelection: onToggleSelection,
                          onStartSelection: onStartSelection,
                          onToggleCompletion: onToggleCompletion,
                        ),
                      )
                      .toList(),
                )
              : const SizedBox.shrink(
                  key: ValueKey('subtasks-closed'),
                ),
        ),
      ],
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      opacity: fadeOut ? 0 : 1,
      child: ClipRect(
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 460),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          heightFactor: fadeOut ? 0 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color:
                  forceCompleted ? const Color(0xFFEAF3E2) : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: forceCompleted
                      ? const Color(0xFF70835D)
                      : Colors.transparent,
                  width: forceCompleted ? 4 : 0,
                ),
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _CompletionCheckPulse extends StatelessWidget {
  const _CompletionCheckPulse();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.72, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF70835D),
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 20,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ReferenceSubtaskRow extends StatelessWidget {
  const _ReferenceSubtaskRow({
    required this.controller,
    required this.task,
    required this.selectedDay,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelection,
    required this.onStartSelection,
    required this.onToggleCompletion,
  });

  final TodoWorkspace controller;
  final TaskModel task;
  final DateTime selectedDay;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<String> onStartSelection;
  final ValueChanged<String> onToggleCompletion;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final completed = controller.isTaskCompletedOnDay(task, selectedDay);
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFF0E8DC)),
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: (details) => _showTaskActionsMenu(
          context,
          controller,
          task,
          details.globalPosition,
        ),
        child: InkWell(
          onTap: selectionMode
              ? () => onToggleSelection(task.id)
              : () => showTaskEditor(context, controller, initialTask: task),
          onLongPress: selectionMode
              ? () => onToggleSelection(task.id)
              : () => onStartSelection(task.id),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(58, 10, 18, 10),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 32,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: visuals.panelBorder, width: 1.2),
                      bottom:
                          BorderSide(color: visuals.panelBorder, width: 1.2),
                    ),
                  ),
                ),
                Checkbox(
                  value: selectionMode ? selected : completed,
                  onChanged: (_) => selectionMode
                      ? onToggleSelection(task.id)
                      : onToggleCompletion(task.id),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      color: completed
                          ? const Color(0xFF70835D)
                          : visuals.textStrong.withValues(alpha: 0.88),
                      decoration: completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                SizedBox(
                  width: 66,
                  child: task.scheduledAt != null &&
                          _hasVisibleTime(task.scheduledAt!)
                      ? Text(
                          _timeLabel(task.scheduledAt!),
                          textAlign: TextAlign.right,
                          style: TextStyle(color: visuals.textMuted),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 12),
                if (!selectionMode)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (value) =>
                        _handleTaskAction(context, controller, task, value),
                    itemBuilder: (context) =>
                        _taskActionItems(controller, task),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferenceWeekPanel extends StatelessWidget {
  const _ReferenceWeekPanel({
    required this.controller,
    required this.logicalToday,
    required this.selectedDay,
    required this.onSelectDay,
  });
  final TodoWorkspace controller;
  final DateTime logicalToday;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelectDay;
  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Semana activa',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontSize: 21),
                ),
              ),
              Icon(Icons.calendar_month_rounded, color: visuals.accent),
            ],
          ),
          const SizedBox(height: 8),
          ...List<Widget>.generate(7, (index) {
            final day = logicalToday.add(Duration(days: index));
            final isSelected = _sameDay(day, selectedDay);
            final count = controller
                .tasksForDate(day)
                .where((task) => task.scheduledAt != null)
                .length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelectDay(day),
                  borderRadius: BorderRadius.circular(14),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF1ECE3)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: isSelected
                          ? Border.all(color: const Color(0xFFE3D4C2))
                          : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _weekdayLabel(day),
                              style: TextStyle(
                                color: visuals.textStrong,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFD8D0C4)
                                  : const Color(0xFFE5DFD5),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                color: visuals.textStrong,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
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
          }),
          const SizedBox(height: 2),
          OutlinedButton(
            onPressed: () => controller.setSection(AppSection.calendar),
            child: const Text('Ver calendario completo'),
          ),
        ],
      ),
    );
  }
}

List<PopupMenuEntry<String>> _taskActionItems(
  TodoWorkspace controller,
  TaskModel task,
) {
  return [
    const PopupMenuItem(value: 'edit', child: Text('Editar')),
    if (!task.isSubtask)
      const PopupMenuItem(value: 'subtask', child: Text('Crear subtarea')),
    const PopupMenuItem(value: 'tomorrow', child: Text('Mover a mañana')),
    if (controller.isCalendarConnected) ...[
      const PopupMenuItem(value: 'sync', child: Text('Sincronizar con Google')),
      if (task.calendarLink != null)
        const PopupMenuItem(value: 'unlink', child: Text('Quitar enlace')),
    ],
    const PopupMenuDivider(),
    const PopupMenuItem(value: 'delete', child: Text('Borrar')),
  ];
}

Future<void> _showTaskActionsMenu(
  BuildContext context,
  TodoWorkspace controller,
  TaskModel task,
  Offset globalPosition,
) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final selected = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1),
      Offset.zero & overlay.size,
    ),
    items: _taskActionItems(controller, task),
  );
  if (selected == null || !context.mounted) {
    return;
  }
  await _handleTaskAction(context, controller, task, selected);
}

Future<void> _handleTaskAction(
  BuildContext context,
  TodoWorkspace controller,
  TaskModel task,
  String value,
) async {
  if (value == 'edit') {
    await showTaskEditor(context, controller, initialTask: task);
  } else if (value == 'subtask') {
    final subtask = controller.createSubtask(task.id, 'Nueva subtarea');
    if (context.mounted) {
      await showTaskEditor(context, controller, initialTask: subtask);
    }
  } else if (value == 'tomorrow') {
    await controller.moveTaskToDay(
      task.id,
      controller.logicalDate().add(const Duration(days: 1)),
    );
  } else if (value == 'sync') {
    await controller.syncTaskToCalendar(task.id);
  } else if (value == 'unlink') {
    controller.unlinkTaskFromCalendarEvent(task.id);
  } else if (value == 'delete') {
    controller.deleteTask(task.id);
  }
}

class _ReferenceInboxPanel extends StatelessWidget {
  const _ReferenceInboxPanel({
    required this.controller,
    required this.notes,
  });
  final TodoWorkspace controller;
  final List<QuickNote> notes;
  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final visibleNotes = notes.take(3).toList();
    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(Icons.edit_note_rounded, color: visuals.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Nota rápida',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(
                  onPressed: () => showQuickNoteComposer(context, controller),
                  icon: const Icon(Icons.open_in_new_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _QuickCaptureBar(controller: controller, compact: true),
          ),
          const Divider(height: 1),
          if (visibleNotes.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Text('No tienes notas guardadas.',
                  style: TextStyle(color: visuals.textMuted)),
            )
          else
            ...visibleNotes.map(
              (note) => Column(
                children: [
                  _ReferenceInboxNoteRow(controller: controller, note: note),
                  if (note != visibleNotes.last) const Divider(height: 1),
                ],
              ),
            ),
          InkWell(
            onTap: () => controller.setSection(AppSection.inbox),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Ver todas las notas (${notes.length})',
                        style: TextStyle(color: visuals.textMuted)),
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
}

class _ReferenceInboxNoteRow extends StatelessWidget {
  const _ReferenceInboxNoteRow({
    required this.controller,
    required this.note,
  });

  final TodoWorkspace controller;
  final QuickNote note;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.note_alt_outlined, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${note.emoji} ${_noteTitleFromContent(note.content)}'.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: visuals.textStrong),
                ),
                const SizedBox(height: 6),
                Text(
                  _noteRowMeta(note),
                  style: TextStyle(color: visuals.textMuted, fontSize: 12.6),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (value) {
              if (value == 'open') {
                controller.setSection(AppSection.inbox);
              } else if (value == 'edit') {
                showQuickNoteComposer(context, controller, initialNote: note);
              } else {
                controller.archiveNote(note.id);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'open', child: Text('Abrir en Notas')),
              PopupMenuItem(value: 'edit', child: Text('Editar nota')),
              PopupMenuItem(value: 'archive', child: Text('Archivar')),
            ],
          ),
        ],
      ),
    );
  }

  String _noteRowMeta(QuickNote note) {
    if (note.scheduledFor != null) {
      return 'Con fecha · ${_formatInboxDate(note.scheduledFor!)}';
    }
    return 'Sin fecha';
  }
}

class _ReferenceSummaryPanel extends StatelessWidget {
  const _ReferenceSummaryPanel({
    required this.totalTasks,
    required this.completedTasks,
    required this.progress,
  });

  final int totalTasks;
  final int completedTasks;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final percent = (progress * 100).round();
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Resumen rápido',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontSize: 21),
                ),
              ),
              Icon(Icons.insights_outlined, color: visuals.accent, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ReferenceSummaryDatum(
                  value: '$totalTasks',
                  label: 'Tareas hoy',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReferenceSummaryDatum(
                  value: '$completedTasks',
                  label: 'Completadas',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReferenceSummaryDatum(
                  value: '$percent%',
                  label: 'Progreso\ndel día',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReferenceSummaryDatum extends StatelessWidget {
  const _ReferenceSummaryDatum({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final labelLines = label.contains('\n') ? 2 : 1;
    return SizedBox(
      height: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            height: 36,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontSize: 31, height: 1),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 30,
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: labelLines,
                softWrap: labelLines > 1,
                style: TextStyle(
                  color: context.visuals.textMuted,
                  fontSize: 13,
                  height: 1.12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceCompletedRow extends StatelessWidget {
  const _ReferenceCompletedRow({
    required this.controller,
    required this.task,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelection,
    required this.onStartSelection,
  });

  final TodoWorkspace controller;
  final TaskModel task;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<String> onStartSelection;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final category = task.categoryIds.isNotEmpty
        ? controller.categoryById(task.categoryIds.first)
        : null;
    return InkWell(
      onTap: selectionMode ? () => onToggleSelection(task.id) : null,
      onLongPress: selectionMode
          ? () => onToggleSelection(task.id)
          : () => onStartSelection(task.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        child: Row(
          children: [
            if (selectionMode)
              Checkbox(
                value: selected,
                onChanged: (_) => onToggleSelection(task.id),
              )
            else
              IconButton(
                tooltip: 'Reabrir tarea',
                onPressed: () => controller.reopenTask(task.id),
                icon: const Icon(Icons.check_circle_outline_rounded),
                color: const Color(0xFF70835D),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  color: visuals.textMuted,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ),
            if (category != null)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _ReferenceTagChip(
                  label: category.name,
                  color: category.color.withValues(alpha: 0.15),
                  textColor: category.color,
                ),
              ),
            SizedBox(
              width: 62,
              child:
                  task.scheduledAt != null && _hasVisibleTime(task.scheduledAt!)
                      ? Text(
                          _timeLabel(task.scheduledAt!),
                          textAlign: TextAlign.right,
                          style: TextStyle(color: visuals.textMuted),
                        )
                      : const SizedBox.shrink(),
            ),
            const SizedBox(width: 8),
            if (!selectionMode)
              TextButton(
                onPressed: () => controller.reopenTask(task.id),
                child: const Text('Reabrir'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceTaskStateGlyph extends StatelessWidget {
  const _ReferenceTaskStateGlyph({required this.task});

  final TaskModel task;

  @override
  Widget build(BuildContext context) {
    if (task.recurrence.isRecurring) {
      return const Icon(Icons.autorenew_rounded,
          size: 18, color: Color(0xFF8B7D68));
    }
    if (task.reminderRules.any((rule) => rule.enabled)) {
      return const Icon(Icons.notifications_active_outlined,
          size: 18, color: Color(0xFF8B7D68));
    }
    if (task.calendarLink != null) {
      return const Icon(Icons.calendar_month_outlined,
          size: 18, color: Color(0xFF8B7D68));
    }
    return const SizedBox(width: 18, height: 18);
  }
}

class _ReferencePriorityFlag extends StatelessWidget {
  const _ReferencePriorityFlag({required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      TaskPriority.urgent => const Color(0xFFE54A44),
      TaskPriority.high => const Color(0xFFF2A633),
      TaskPriority.medium => const Color(0xFFC9BFB2),
      TaskPriority.low => const Color(0xFFDCD6CB),
    };
    return Icon(Icons.flag_rounded, size: 18, color: color);
  }
}

class _ReferenceTagChip extends StatelessWidget {
  const _ReferenceTagChip({
    required this.label,
    required this.color,
    required this.textColor,
    this.icon,
  });

  final String label;
  final Color color;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

bool _isOverdueTask(TaskModel task, DateTime logicalToday) {
  final scheduled = task.scheduledAt;
  if (scheduled == null ||
      task.status == TaskStatus.completed ||
      task.recurrence.isRecurring) {
    return false;
  }
  return DateTime(scheduled.year, scheduled.month, scheduled.day).isBefore(
      DateTime(logicalToday.year, logicalToday.month, logicalToday.day));
}
