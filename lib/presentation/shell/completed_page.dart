// ignore_for_file: unused_element

part of 'app_shell.dart';

class CompletedPage extends StatelessWidget {
  const CompletedPage({required this.controller, super.key});

  final TodoWorkspace controller;

  @override
  Widget build(BuildContext context) {
    final completed = controller.completedTasks();
    final today = controller.logicalDate();
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final todayTasks = <TaskModel>[];
    final thisWeekTasks = <TaskModel>[];
    final olderTasks = <TaskModel>[];

    for (final task in completed) {
      final stamp = task.completedAt ?? task.scheduledAt ?? today;
      final day = controller.logicalDate(stamp);
      if (_sameDay(day, today)) {
        todayTasks.add(task);
      } else if (!day.isBefore(weekStart) && day.isBefore(today)) {
        thisWeekTasks.add(task);
      } else {
        olderTasks.add(task);
      }
    }

    final sections = <_CompletedSectionData>[
      _CompletedSectionData(
        id: 'today',
        title: 'Hoy',
        subtitle:
            '${_weekdayLong(today)}, ${today.day} de ${_monthLong(today.month)} de ${today.year}',
        tasks: todayTasks,
      ),
      _CompletedSectionData(
        id: 'this-week',
        title: 'Esta semana',
        subtitle: _completedWeekRangeLabel(weekStart, today),
        tasks: thisWeekTasks,
      ),
      _CompletedSectionData(
        id: 'older',
        title: 'Más antiguas',
        subtitle: '',
        tasks: olderTasks,
      ),
    ];

    final completedToday = todayTasks.length;
    final completedThisWeek = completed.where((task) {
      final stamp = task.completedAt ?? task.scheduledAt ?? today;
      final day = controller.logicalDate(stamp);
      return !day.isBefore(weekStart) && day.isBefore(weekEnd);
    }).length;
    const weeklyTotal = 7;
    final weeklyCompleted = min(completedThisWeek, weeklyTotal);
    final progress = weeklyCompleted / weeklyTotal;
    final streak = _completedStreak(completed, today);
    final weeklyActivity = _completedWeeklyActivity(
      completed,
      weekStart: weekStart,
      logicalDate: controller.logicalDate,
    );
    final productiveDay = _completedProductiveDay(weeklyActivity);
    final featuredCategory = _completedFeaturedCategory(controller, completed);

    void showStatistics() {
      _showCompletedStatisticsDialog(
        context,
        weeklyActivity: weeklyActivity,
        streak: streak,
        productiveDay: productiveDay,
        featuredCategory: featuredCategory,
      );
    }

    void recoverTask() {
      _showCompletedRecoveryDialog(context, controller, completed);
    }

    return SizedBox.expand(
      child: Padding(
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
                      'Revisa lo que ya has resuelto y mantén perspectiva de tu progreso.',
                ),
                const SizedBox(height: 18),
                _CompletedSummaryCard(
                  progress: progress,
                  completedToday: completedToday,
                  completedThisWeek: completedThisWeek,
                  streak: streak,
                  totalCompleted: completed.length,
                  weeklyCompleted: weeklyCompleted,
                  weeklyTotal: weeklyTotal,
                  onViewProgress: showStatistics,
                ),
                const SizedBox(height: 16),
                for (final section in sections) ...[
                  _CompletedSectionCard(
                    controller: controller,
                    section: section,
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CompletedQuickStatsCard(
                            weeklyActivity: weeklyActivity,
                            streak: streak,
                            productiveDay: productiveDay,
                            featuredCategory: featuredCategory,
                          ),
                          const SizedBox(height: 16),
                          _CompletedRecoverCard(
                            onRecover: completed.isEmpty ? null : recoverTask,
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  main,
                  const SizedBox(height: 16),
                  _CompletedQuickStatsCard(
                    weeklyActivity: weeklyActivity,
                    streak: streak,
                    productiveDay: productiveDay,
                    featuredCategory: featuredCategory,
                  ),
                  const SizedBox(height: 16),
                  _CompletedRecoverCard(
                    onRecover: completed.isEmpty ? null : recoverTask,
                  ),
                ],
              ),
            );
          },
        ),
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
                value: _CompletedDateFilter.older, child: Text('Más antiguas')),
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
                child: Text('Más recientes')),
            PopupMenuItem(
                value: _CompletedSortOrder.oldestFirst,
                child: Text('Más antiguas')),
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
              'Prueba otra búsqueda o vuelve a mostrar las antiguas.',
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
  });

  final TodoWorkspace controller;
  final _CompletedSectionData section;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return _CompletedCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                section.title,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontSize: 23),
              ),
              const SizedBox(width: 9),
              _miniBadge(
                '${section.tasks.length}',
                const Color(0xFFF1ECE4),
                const Color(0xFF665E54),
              ),
              if (section.subtitle.isNotEmpty) ...[
                const Spacer(),
                Flexible(
                  child: Text(
                    section.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: visuals.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          if (section.tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No hay tareas completadas en este periodo.',
                  style: TextStyle(color: visuals.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            for (var index = 0; index < section.tasks.length; index++) ...[
              _CompletedTaskRow(
                controller: controller,
                task: section.tasks[index],
              ),
              if (index != section.tasks.length - 1)
                Divider(
                  height: 1,
                  color: visuals.panelBorder.withValues(alpha: 0.72),
                ),
            ],
        ],
      ),
    );
  }
}

class _CompletedTaskRow extends StatelessWidget {
  const _CompletedTaskRow({
    required this.controller,
    required this.task,
  });

  final TodoWorkspace controller;
  final TaskModel task;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final category = task.categoryIds.isEmpty
        ? null
        : controller.categoryById(task.categoryIds.first);
    final project = task.projectIds.isEmpty
        ? null
        : controller.projectById(task.projectIds.first);

    return SizedBox(
      height: 50,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Reabrir tarea',
            onPressed: () => controller.reopenTask(task.id),
            icon: const Icon(Icons.check_circle_rounded, size: 22),
            color: const Color(0xFF6F8D5E),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                decoration: TextDecoration.lineThrough,
                decorationColor: visuals.textMuted,
                color: visuals.textMuted,
                fontSize: 15,
              ),
            ),
          ),
          if (category != null) ...[
            const SizedBox(width: 12),
            _SoftChip(label: category.name, color: category.color),
          ],
          if (project != null) ...[
            const SizedBox(width: 10),
            _SoftChip(label: project.name),
          ],
          const SizedBox(width: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 70),
            child: Text(
              _completedTaskTimeLabel(task, controller.logicalDate()),
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 13, color: visuals.textMuted),
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            iconSize: 20,
            padding: EdgeInsets.zero,
            onSelected: (value) {
              if (value == 'reopen') {
                controller.reopenTask(task.id);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'reopen',
                child: Text('Recuperar tarea'),
              ),
            ],
          ),
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
    required this.weeklyCompleted,
    required this.weeklyTotal,
    required this.onViewProgress,
  });

  final double progress;
  final int completedToday;
  final int completedThisWeek;
  final int streak;
  final int totalCompleted;
  final int weeklyCompleted;
  final int weeklyTotal;
  final VoidCallback onViewProgress;

  @override
  Widget build(BuildContext context) {
    final metrics = <_CompletedMetricData>[
      _CompletedMetricData(
        icon: Icons.event_available_outlined,
        value: '$completedToday',
        label: 'Hoy',
      ),
      _CompletedMetricData(
        icon: Icons.calendar_month_outlined,
        value: '$completedThisWeek',
        label: 'Esta semana',
      ),
      _CompletedMetricData(
        icon: Icons.local_fire_department_rounded,
        value: '$streak ${streak == 1 ? 'día' : 'días'}',
        label: 'Racha',
      ),
      _CompletedMetricData(
        icon: Icons.check_circle_rounded,
        value: '$totalCompleted',
        label: 'Total',
      ),
    ];

    return _CompletedCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 790;
          final metricGrid = _CompletedMetricGrid(metrics: metrics);
          final progressPanel = _CompletedProgressPanel(
            progress: progress,
            weeklyCompleted: weeklyCompleted,
            weeklyTotal: weeklyTotal,
            onViewProgress: onViewProgress,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Resumen de completadas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              if (horizontal)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 5, child: metricGrid),
                    Container(
                      width: 1,
                      height: 138,
                      margin: const EdgeInsets.symmetric(horizontal: 18),
                      color: context.visuals.panelBorder.withValues(alpha: 0.7),
                    ),
                    Expanded(flex: 4, child: progressPanel),
                  ],
                )
              else ...[
                metricGrid,
                const SizedBox(height: 18),
                Divider(
                  height: 1,
                  color: context.visuals.panelBorder.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 18),
                progressPanel,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CompletedMetricData {
  const _CompletedMetricData({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;
}

class _CompletedMetricGrid extends StatelessWidget {
  const _CompletedMetricGrid({required this.metrics});

  final List<_CompletedMetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 430 ? 4 : 2;
        final tileWidth =
            (constraints.maxWidth - (10 * (columns - 1))) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: tileWidth,
                height: 78,
                child: _CompletedMetricTile(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class _CompletedMetricTile extends StatelessWidget {
  const _CompletedMetricTile({required this.metric});

  final _CompletedMetricData metric;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: visuals.isPhantom
            ? visuals.panelAlt
            : Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(visuals.isPhantom ? 0 : 12),
        border: Border.all(
          color: visuals.panelBorder.withValues(alpha: 0.78),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        child: Row(
          children: [
            Icon(metric.icon, size: 23, color: visuals.accent),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      metric.value,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    metric.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: visuals.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedProgressPanel extends StatelessWidget {
  const _CompletedProgressPanel({
    required this.progress,
    required this.weeklyCompleted,
    required this.weeklyTotal,
    required this.onViewProgress,
  });

  final double progress;
  final int weeklyCompleted;
  final int weeklyTotal;
  final VoidCallback onViewProgress;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 142,
          height: 142,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: progress.clamp(0, 1),
                  strokeWidth: 11,
                  strokeCap: StrokeCap.round,
                  backgroundColor: visuals.accent.withValues(alpha: 0.14),
                  color: visuals.accent,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${(progress * 100).round()} %',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'completado\nesta semana',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: visuals.textMuted,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                weeklyCompleted == 0
                    ? 'Tu progreso empieza aquí'
                    : '¡Vas muy bien!',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Has completado $weeklyCompleted de $weeklyTotal tareas esta semana.',
                style: TextStyle(
                  color: visuals.textMuted,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onViewProgress,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                label: const Text('Ver estadísticas'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  backgroundColor: visuals.accent,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(visuals.isPhantom ? 0 : 999),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompletedQuickStatsCard extends StatelessWidget {
  const _CompletedQuickStatsCard({
    required this.weeklyActivity,
    required this.streak,
    required this.productiveDay,
    required this.featuredCategory,
  });

  final List<int> weeklyActivity;
  final int streak;
  final String productiveDay;
  final _CompletedFeaturedCategory featuredCategory;

  @override
  Widget build(BuildContext context) {
    return _CompletedCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Estadísticas rápidas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              _CompletedPeriodLabel(label: 'Esta semana'),
            ],
          ),
          const SizedBox(height: 18),
          _CompletedStatisticsBody(
            weeklyActivity: weeklyActivity,
            streak: streak,
            productiveDay: productiveDay,
            featuredCategory: featuredCategory,
          ),
        ],
      ),
    );
  }
}

class _CompletedPeriodLabel extends StatelessWidget {
  const _CompletedPeriodLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(visuals.isPhantom ? 0 : 10),
        border: Border.all(
          color: visuals.panelBorder.withValues(alpha: 0.82),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: visuals.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 5),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 15, color: visuals.accent),
        ],
      ),
    );
  }
}

class _CompletedStatisticsBody extends StatelessWidget {
  const _CompletedStatisticsBody({
    required this.weeklyActivity,
    required this.streak,
    required this.productiveDay,
    required this.featuredCategory,
  });

  final List<int> weeklyActivity;
  final int streak;
  final String productiveDay;
  final _CompletedFeaturedCategory featuredCategory;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CompletedWeeklyChart(values: weeklyActivity),
        const SizedBox(height: 18),
        Divider(
          height: 1,
          color: visuals.panelBorder.withValues(alpha: 0.72),
        ),
        const SizedBox(height: 10),
        _CompletedStatLine(
          icon: Icons.local_fire_department_rounded,
          label: 'Racha actual',
          value: '$streak ${streak == 1 ? 'día' : 'días'}',
        ),
        _CompletedStatLine(
          icon: Icons.bar_chart_rounded,
          label: 'Día más productivo',
          value: productiveDay,
        ),
        _CompletedStatLine(
          icon: Icons.sell_outlined,
          label: 'Categoría destacada',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SoftChip(
                label: featuredCategory.name,
                color: featuredCategory.color,
              ),
              if (featuredCategory.count > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '${featuredCategory.count}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CompletedWeeklyChart extends StatelessWidget {
  const _CompletedWeeklyChart({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    const labels = <String>['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final visuals = context.visuals;
    final peak = values.isEmpty ? 1 : max(1, values.reduce(max));

    return SizedBox(
      height: 122,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < labels.length; index++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  children: [
                    Text(
                      '${index < values.length ? values[index] : 0}',
                      style: TextStyle(
                        color: visuals.textStrong,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor:
                              index < values.length && values[index] > 0
                                  ? max(0.18, values[index] / peak)
                                  : 0.04,
                          widthFactor: 0.58,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: index < values.length &&
                                      values[index] == peak &&
                                      values[index] > 0
                                  ? visuals.accent
                                  : visuals.accent.withValues(alpha: 0.38),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                                bottom: Radius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[index],
                      style: TextStyle(
                        color: visuals.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompletedStatLine extends StatelessWidget {
  const _CompletedStatLine({
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: visuals.accent),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: visuals.textMuted, fontSize: 12),
            ),
          ),
          if (trailing != null)
            Flexible(child: trailing!)
          else
            Text(
              value ?? '',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }
}

class _CompletedFeaturedCategory {
  const _CompletedFeaturedCategory({
    required this.name,
    required this.count,
    this.color,
  });

  final String name;
  final int count;
  final Color? color;
}

class _CompletedCard extends StatelessWidget {
  const _CompletedCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: visuals.isPhantom
            ? visuals.panel
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(visuals.isPhantom ? 0 : 18),
        border: Border.all(
          color: visuals.panelBorder.withValues(alpha: 0.82),
          width: visuals.isPhantom ? 1.5 : 1,
        ),
        boxShadow: elevated && !visuals.isPhantom
            ? const [
                BoxShadow(
                  blurRadius: 16,
                  color: Color(0x0C000000),
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

String _completedWeekRangeLabel(DateTime start, DateTime end) {
  if (start.month == end.month) {
    return '${start.day} – ${end.day} de ${_monthLong(end.month)}';
  }
  return '${start.day} de ${_monthLong(start.month)} – '
      '${end.day} de ${_monthLong(end.month)}';
}

List<int> _completedWeeklyActivity(
  List<TaskModel> tasks, {
  required DateTime weekStart,
  required DateTime Function([DateTime?]) logicalDate,
}) {
  final activity = List<int>.filled(7, 0);
  final weekEnd = weekStart.add(const Duration(days: 7));
  for (final task in tasks) {
    final stamp = task.completedAt ?? task.scheduledAt;
    if (stamp == null) {
      continue;
    }
    final day = logicalDate(stamp);
    if (!day.isBefore(weekStart) && day.isBefore(weekEnd)) {
      activity[day.weekday - 1] += 1;
    }
  }
  return activity;
}

String _completedProductiveDay(List<int> weeklyActivity) {
  if (weeklyActivity.isEmpty) {
    return 'Sin datos';
  }
  final peak = weeklyActivity.reduce(max);
  if (peak == 0) {
    return 'Sin datos';
  }
  final latestPeakIndex = weeklyActivity.lastIndexOf(peak);
  return _weekdayLong(DateTime(2026, 1, 5 + latestPeakIndex));
}

_CompletedFeaturedCategory _completedFeaturedCategory(
  TodoWorkspace controller,
  List<TaskModel> completed,
) {
  final counts = <String, int>{};
  for (final task in completed) {
    if (task.categoryIds.isEmpty) {
      continue;
    }
    final categoryId = task.categoryIds.first;
    if (controller.categoryById(categoryId) != null) {
      counts.update(categoryId, (value) => value + 1, ifAbsent: () => 1);
    }
  }
  if (counts.isEmpty) {
    return const _CompletedFeaturedCategory(
      name: 'Sin categoría',
      count: 0,
    );
  }
  final featuredId = counts.entries.reduce((left, right) {
    return right.value > left.value ? right : left;
  }).key;
  final category = controller.categoryById(featuredId)!;
  return _CompletedFeaturedCategory(
    name: category.name,
    count: counts[featuredId]!,
    color: category.color,
  );
}

Future<void> _showCompletedStatisticsDialog(
  BuildContext context, {
  required List<int> weeklyActivity,
  required int streak,
  required String productiveDay,
  required _CompletedFeaturedCategory featuredCategory,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Estadísticas rápidas'),
      content: SizedBox(
        width: 420,
        child: _CompletedStatisticsBody(
          weeklyActivity: weeklyActivity,
          streak: streak,
          productiveDay: productiveDay,
          featuredCategory: featuredCategory,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

Future<void> _showCompletedRecoveryDialog(
  BuildContext context,
  TodoWorkspace controller,
  List<TaskModel> completed,
) async {
  final selected = await showDialog<TaskModel>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Recuperar una tarea'),
      content: SizedBox(
        width: 480,
        height: min(420, 68.0 * completed.length),
        child: ListView.separated(
          itemCount: completed.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final task = completed[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF6F8D5E),
              ),
              title: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                _completedTaskTimeLabel(task, controller.logicalDate()),
              ),
              trailing: const Icon(Icons.restore_rounded),
              onTap: () => Navigator.of(dialogContext).pop(task),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    ),
  );
  if (selected != null) {
    controller.reopenTask(selected.id);
  }
}

String _dateFilterLabel(_CompletedDateFilter value) {
  return switch (value) {
    _CompletedDateFilter.all => 'Filtrar por fecha',
    _CompletedDateFilter.today => 'Hoy',
    _CompletedDateFilter.yesterday => 'Ayer',
    _CompletedDateFilter.thisWeek => 'Esta semana',
    _CompletedDateFilter.lastWeek => 'Semana pasada',
    _CompletedDateFilter.older => 'Más antiguas',
  };
}

String _sortOrderLabel(_CompletedSortOrder value) {
  return switch (value) {
    _CompletedSortOrder.newestFirst => 'Más recientes',
    _CompletedSortOrder.oldestFirst => 'Más antiguas',
    _CompletedSortOrder.alphabetical => 'A-Z',
  };
}

String _completedTaskTimeLabel(TaskModel task, DateTime today) {
  final stamp = task.completedAt ?? task.scheduledAt;
  if (stamp == null) {
    return '-';
  }
  final timeLabel = _completedTaskClockLabel(task);
  if (_sameDay(stamp, today) ||
      _sameDay(stamp, today.subtract(const Duration(days: 1)))) {
    return timeLabel;
  }
  return '${_weekdayShort(stamp)} ${stamp.day}, $timeLabel';
}

String _completedTaskClockLabel(TaskModel task) {
  final stamp = task.completedAt ?? task.scheduledAt;
  if (stamp == null ||
      (task.completedAt == null && _isCompletedTaskWithoutVisibleTime(task))) {
    return '-';
  }
  return _timeLabel(stamp);
}

String _completedActivityTime(TaskModel task, {DateTime? fallbackDate}) {
  final reference = task.completedAt ?? task.scheduledAt ?? fallbackDate;
  if (reference == null) {
    return 'Completada · Sin hora registrada';
  }
  final when = _activityWhenLabel(reference, fallbackDate ?? DateTime.now());
  if (task.completedAt == null) {
    return 'Completada $when · Sin hora registrada';
  }
  return 'Completada $when a las ${_timeLabel(task.completedAt!)}';
}

bool _isCompletedTaskWithoutVisibleTime(TaskModel task) {
  final stamp = task.scheduledAt;
  return stamp != null &&
      stamp.hour == 0 &&
      stamp.minute == 0 &&
      stamp.second == 0 &&
      stamp.millisecond == 0 &&
      stamp.microsecond == 0;
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
    final visuals = context.visuals;
    return _CompletedCard(
      elevated: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: visuals.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.restore_rounded,
                    size: 21, color: visuals.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¿Completaste algo por error?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Restaura una completada a tu lista de hoy en pocos segundos.',
                      style: TextStyle(
                        color: visuals.textMuted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRecover,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 17),
              label: const Text('Recuperar una tarea'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(38),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                foregroundColor: visuals.accent,
                side: BorderSide(color: visuals.accent.withValues(alpha: 0.8)),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(visuals.isPhantom ? 0 : 999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
