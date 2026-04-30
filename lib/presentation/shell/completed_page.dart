// ignore_for_file: unused_element

part of 'app_shell.dart';

class CompletedPage extends StatelessWidget {
  const CompletedPage({required this.controller, super.key});

  final TodoWorkspace controller;

  @override
  Widget build(BuildContext context) {
    final completed = controller.completedTasks();
    final today = controller.logicalDate();
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final lastWeekStart = weekStart.subtract(const Duration(days: 7));
    final lastWeekEnd = weekStart.subtract(const Duration(days: 1));

    final todayTasks = <TaskModel>[];
    final yesterdayTasks = <TaskModel>[];
    final thisWeekTasks = <TaskModel>[];
    final lastWeekTasks = <TaskModel>[];
    final olderTasks = <TaskModel>[];

    for (final task in completed) {
      final stamp = task.scheduledAt ?? today;
      final day = DateTime(stamp.year, stamp.month, stamp.day);
      if (_sameDay(day, today)) {
        todayTasks.add(task);
      } else if (_sameDay(day, yesterday)) {
        yesterdayTasks.add(task);
      } else if (!day.isBefore(weekStart) && day.isBefore(today)) {
        thisWeekTasks.add(task);
      } else if (!day.isBefore(lastWeekStart) && !day.isAfter(lastWeekEnd)) {
        lastWeekTasks.add(task);
      } else {
        olderTasks.add(task);
      }
    }

    final sections = <_CompletedSectionData>[
      _CompletedSectionData(
          id: 'today', title: 'Hoy', subtitle: '', tasks: todayTasks),
      _CompletedSectionData(
          id: 'yesterday', title: 'Ayer', subtitle: '', tasks: yesterdayTasks),
      _CompletedSectionData(
        id: 'this-week',
        title: 'Esta semana',
        subtitle: '${weekStart.day} - ${today.day} ${_monthLong(today.month)}',
        tasks: thisWeekTasks,
      ),
      _CompletedSectionData(
        id: 'last-week',
        title: 'Semana pasada',
        subtitle:
            '${lastWeekStart.day} - ${lastWeekEnd.day} ${_monthLong(lastWeekStart.month)}',
        tasks: lastWeekTasks,
      ),
      _CompletedSectionData(
        id: 'older',
        title: 'Mas antiguas',
        subtitle: '',
        tasks: olderTasks,
      ),
    ].where((section) => section.tasks.isNotEmpty).toList();

    final completedToday = todayTasks.length;
    final completedThisWeek = completed.where((task) {
      final stamp = task.scheduledAt ?? today;
      final day = DateTime(stamp.year, stamp.month, stamp.day);
      return !day.isBefore(weekStart);
    }).length;
    final totalActive = controller.tasks
        .where((task) => task.status == TaskStatus.active)
        .length;
    final denominator = completed.length + totalActive;
    final progress = completed.isEmpty && totalActive == 0
        ? 0.0
        : completed.length / (denominator <= 0 ? 1 : denominator);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1200;
          final main = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PageHeader(
                title: 'Completadas',
                subtitle:
                    'Revisa lo que ya has resuelto y manten perspectiva de tu progreso.',
              ),
              const SizedBox(height: 18),
              _CompletedSummaryCard(
                progress: progress,
                completedToday: completedToday,
                completedThisWeek: completedThisWeek,
                streak: _completedStreak(completed, today),
                totalCompleted: completed.length,
                onViewProgress: () {},
              ),
              const SizedBox(height: 16),
              for (final section in sections) ...[
                _CompletedSectionCard(
                  controller: controller,
                  section: section,
                  expanded: true,
                  onToggle: () {},
                ),
                const SizedBox(height: 16),
              ],
            ],
          );

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    child: main,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _CompletedActivityCard(
                          tasks: completed.take(5).toList(),
                          fallbackDate: today,
                          onViewAll: () {},
                        ),
                        const SizedBox(height: 16),
                        _CompletedRecoverCard(
                          onRecover: completed.isEmpty
                              ? null
                              : () => controller.reopenTask(completed.first.id),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                main,
                _CompletedActivityCard(
                  tasks: completed.take(5).toList(),
                  fallbackDate: today,
                  onViewAll: () {},
                ),
                const SizedBox(height: 16),
                _CompletedRecoverCard(
                  onRecover: completed.isEmpty
                      ? null
                      : () => controller.reopenTask(completed.first.id),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _CompletedDateFilter { all, today, yesterday, thisWeek, lastWeek, older }

enum _CompletedSortOrder { newestFirst, oldestFirst, alphabetical }

class _CompletedToolbar extends StatelessWidget {
  const _CompletedToolbar({
    required this.searchController,
    required this.dateFilterLabel,
    required this.sortLabel,
    required this.hideOlderCompleted,
    required this.onSearchChanged,
    required this.onDateFilterSelected,
    required this.onToggleHideOlder,
    required this.onSortSelected,
  });

  final TextEditingController searchController;
  final String dateFilterLabel;
  final String sortLabel;
  final bool hideOlderCompleted;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_CompletedDateFilter> onDateFilterSelected;
  final VoidCallback onToggleHideOlder;
  final ValueChanged<_CompletedSortOrder> onSortSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: _settingsOutlineShell(
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'Buscar completadas...',
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        PopupMenuButton<_CompletedDateFilter>(
          onSelected: onDateFilterSelected,
          itemBuilder: (context) => const [
            PopupMenuItem(
                value: _CompletedDateFilter.all, child: Text('Todas')),
            PopupMenuItem(
                value: _CompletedDateFilter.today, child: Text('Hoy')),
            PopupMenuItem(
                value: _CompletedDateFilter.yesterday, child: Text('Ayer')),
            PopupMenuItem(
                value: _CompletedDateFilter.thisWeek,
                child: Text('Esta semana')),
            PopupMenuItem(
                value: _CompletedDateFilter.lastWeek,
                child: Text('Semana pasada')),
            PopupMenuItem(
                value: _CompletedDateFilter.older, child: Text('Mas antiguas')),
          ],
          child: _CompletedToolbarButton(
            icon: Icons.calendar_month_outlined,
            label: dateFilterLabel,
            showsChevron: true,
          ),
        ),
        _CompletedToolbarButton(
          icon: hideOlderCompleted
              ? Icons.visibility_rounded
              : Icons.visibility_off_outlined,
          label: hideOlderCompleted
              ? 'Mostrando solo recientes'
              : 'Ocultar completadas antiguas',
          active: hideOlderCompleted,
          onTap: onToggleHideOlder,
        ),
        PopupMenuButton<_CompletedSortOrder>(
          onSelected: onSortSelected,
          itemBuilder: (context) => const [
            PopupMenuItem(
                value: _CompletedSortOrder.newestFirst,
                child: Text('Mas recientes')),
            PopupMenuItem(
                value: _CompletedSortOrder.oldestFirst,
                child: Text('Mas antiguas')),
            PopupMenuItem(
                value: _CompletedSortOrder.alphabetical, child: Text('A-Z')),
          ],
          child: _CompletedToolbarButton(
            icon: Icons.swap_vert_rounded,
            label: sortLabel,
            showsChevron: true,
          ),
        ),
      ],
    );
  }
}

class _CompletedToolbarButton extends StatelessWidget {
  const _CompletedToolbarButton({
    required this.icon,
    required this.label,
    this.active = false,
    this.showsChevron = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool showsChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final button = _settingsOutlineShell(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: active ? const Color(0xFF6A8254) : null),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFF6A8254) : null,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          if (showsChevron) ...[
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          ],
        ],
      ),
    );
    if (onTap == null) {
      return button;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: button,
    );
  }
}

class _CompletedEmptyState extends StatelessWidget {
  const _CompletedEmptyState();

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            const Icon(Icons.done_all_rounded,
                size: 30, color: Color(0xFF738B57)),
            const SizedBox(height: 12),
            Text(
              'No hay completadas para este filtro.',
              style: TextStyle(
                color: context.visuals.textStrong,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Prueba otra busqueda o vuelve a mostrar las antiguas.',
              style: TextStyle(color: context.visuals.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedSectionData {
  const _CompletedSectionData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tasks,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<TaskModel> tasks;
}

class _CompletedSectionCard extends StatelessWidget {
  const _CompletedSectionCard({
    required this.controller,
    required this.section,
    required this.expanded,
    required this.onToggle,
  });

  final TodoWorkspace controller;
  final _CompletedSectionData section;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                Text(section.title,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(width: 10),
                _miniBadge(
                  '${section.tasks.length}',
                  const Color(0xFFF1ECE4),
                  const Color(0xFF665E54),
                ),
                if (section.subtitle.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Text(section.subtitle,
                      style: TextStyle(color: visuals.textMuted)),
                ],
                const Spacer(),
                Icon(expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 10),
            for (final task in section.tasks)
              Column(
                children: [
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF738B57)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: visuals.textMuted,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        if (task.categoryIds.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: Builder(
                              builder: (context) {
                                final category = controller
                                    .categoryById(task.categoryIds.first);
                                if (category == null) {
                                  return const SizedBox.shrink();
                                }
                                return _SoftChip(
                                  label: category.name,
                                  color: category.color,
                                );
                              },
                            ),
                          ),
                        if (task.projectIds.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: Builder(
                              builder: (context) {
                                final project = controller
                                    .projectById(task.projectIds.first);
                                if (project == null) {
                                  return const SizedBox.shrink();
                                }
                                return _SoftChip(label: project.name);
                              },
                            ),
                          ),
                        Text(
                          _completedTaskTimeLabel(
                              task, controller.logicalDate()),
                          style: const TextStyle(fontSize: 15),
                        ),
                        const SizedBox(width: 12),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'reopen') {
                              controller.reopenTask(task.id);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                                value: 'reopen',
                                child: Text('Recuperar tarea')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _CompletedSummaryCard extends StatelessWidget {
  const _CompletedSummaryCard({
    required this.progress,
    required this.completedToday,
    required this.completedThisWeek,
    required this.streak,
    required this.totalCompleted,
    required this.onViewProgress,
  });

  final double progress;
  final int completedToday;
  final int completedThisWeek;
  final int streak;
  final int totalCompleted;
  final VoidCallback onViewProgress;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Resumen de completadas',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('Buen trabajo, sigue asi.',
                        style: TextStyle(color: context.visuals.textMuted)),
                  ],
                ),
              ),
              SizedBox(
                width: 74,
                height: 74,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress.clamp(0, 1),
                      strokeWidth: 4,
                      backgroundColor: const Color(0xFFEDE6DA),
                      color: const Color(0xFF70835D),
                    ),
                    Text('${(progress * 100).round()}%',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _settingsMetricRow(Icons.event_available_outlined, '$completedToday',
              'Completadas hoy'),
          _settingsMetricRow(Icons.calendar_today_outlined,
              '$completedThisWeek', 'Completadas esta semana'),
          _settingsMetricRow(Icons.local_fire_department_outlined, '$streak',
              'Racha de dias activos'),
          _settingsMetricRow(Icons.track_changes_outlined, '$totalCompleted',
              'Total completadas'),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onViewProgress,
              child: const Text('Ver mi progreso'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedActivityCard extends StatelessWidget {
  const _CompletedActivityCard({
    required this.tasks,
    required this.fallbackDate,
    required this.onViewAll,
  });

  final List<TaskModel> tasks;
  final DateTime fallbackDate;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final items = tasks;
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Actividad reciente',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          for (final task in items.take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: context.visuals.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Completada ${_activityWhenLabel(task.scheduledAt ?? fallbackDate, fallbackDate)} a las ${task.scheduledAt == null ? '07:20' : _timeLabel(task.scheduledAt!)}',
                          style: TextStyle(color: context.visuals.textMuted),
                        ),
                      ],
                    ),
                  ),
                  _miniBadge(
                    _activityBadgeLabel(
                        task.scheduledAt ?? fallbackDate, fallbackDate),
                    const Color(0xFFE8F1DD),
                    const Color(0xFF6A8254),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onViewAll,
              child: const Text('Ver toda la actividad'),
            ),
          ),
        ],
      ),
    );
  }
}

String _dateFilterLabel(_CompletedDateFilter value) {
  return switch (value) {
    _CompletedDateFilter.all => 'Filtrar por fecha',
    _CompletedDateFilter.today => 'Hoy',
    _CompletedDateFilter.yesterday => 'Ayer',
    _CompletedDateFilter.thisWeek => 'Esta semana',
    _CompletedDateFilter.lastWeek => 'Semana pasada',
    _CompletedDateFilter.older => 'Mas antiguas',
  };
}

String _sortOrderLabel(_CompletedSortOrder value) {
  return switch (value) {
    _CompletedSortOrder.newestFirst => 'Mas recientes',
    _CompletedSortOrder.oldestFirst => 'Mas antiguas',
    _CompletedSortOrder.alphabetical => 'A-Z',
  };
}

String _completedTaskTimeLabel(TaskModel task, DateTime today) {
  final stamp = task.scheduledAt;
  if (stamp == null) {
    return '--:--';
  }
  if (_sameDay(stamp, today) ||
      _sameDay(stamp, today.subtract(const Duration(days: 1)))) {
    return _timeLabel(stamp);
  }
  return '${_weekdayShort(stamp)} ${stamp.day}, ${_timeLabel(stamp)}';
}

String _completedTimestampLabel(DateTime value, DateTime today) {
  if (_sameDay(value, today)) {
    return 'Hoy';
  }
  if (_sameDay(value, today.subtract(const Duration(days: 1)))) {
    return 'Ayer';
  }
  return '${_weekdayLong(value)} ${value.day} ${_monthLong(value.month)}';
}

class _CompletedRecoverCard extends StatelessWidget {
  const _CompletedRecoverCard({
    required this.onRecover,
  });

  final VoidCallback? onRecover;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recuperar tarea',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            '¿Necesitas recuperar algo?\nRestaura una completada a tu lista de hoy.',
            style: TextStyle(color: context.visuals.textMuted, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onRecover,
              child: const Text('Ir a recuperar'),
            ),
          ),
        ],
      ),
    );
  }
}
