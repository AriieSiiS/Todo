part of 'app_shell.dart';

class FocusPage extends StatefulWidget {
  const FocusPage({required this.controller, super.key});

  final TodoWorkspace controller;

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  static const List<int> _presets = <int>[15, 25, 45, 60];

  Timer? _ticker;
  int _minutes = 25;
  String? _taskId;
  final TextEditingController _label = TextEditingController();

  TodoWorkspace get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && controller.activeFocus?.isRunning == true) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _label.dispose();
    super.dispose();
  }

  void _start() {
    controller.startFocus(
      taskId: _taskId,
      label: _label.text,
      minutes: _minutes,
    );
    _label.clear();
  }

  @override
  Widget build(BuildContext context) {
    final active = controller.activeFocus;
    final today = controller.logicalDate();
    final weekStart = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final todaySeconds = controller.focusSecondsBetween(
      DateTime(today.year, today.month, today.day),
      tomorrow,
    );
    final weekSeconds = controller.focusSecondsBetween(weekStart, weekEnd);
    final sessions = controller.focusSessions.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final byTask = <String, int>{};
    for (final session in sessions) {
      if (session.startedAt.isBefore(weekStart) ||
          !session.startedAt.isBefore(weekEnd)) {
        continue;
      }
      final key = session.label.isNotEmpty ? session.label : 'Sin tarea';
      byTask[key] = (byTask[key] ?? 0) + session.actualSeconds;
    }
    final topTasks = byTask.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PageHeader(title: 'Enfoque', subtitle: '', compact: true),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              children: [
                active == null
                    ? _buildSetup(context)
                    : _buildRunning(context, active),
                const SizedBox(height: 16),
                _buildSummary(
                  context,
                  todaySeconds: todaySeconds,
                  weekSeconds: weekSeconds,
                  weekStart: weekStart,
                  topTasks: topTasks,
                ),
                const SizedBox(height: 16),
                if (sessions.isNotEmpty)
                  _SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sesiones recientes',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        for (final session in sessions.take(12))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: Icon(
                              session.completed
                                  ? Icons.check_circle_rounded
                                  : Icons.timelapse_rounded,
                              color: session.completed
                                  ? context.visuals.success
                                  : context.visuals.textMuted,
                            ),
                            title: Text(session.label.isEmpty
                                ? 'Sesión libre'
                                : session.label),
                            subtitle: Text(
                              '${_fechaConDia(session.startedAt)} · '
                              '${_duracionLegible(session.actualSeconds)}',
                            ),
                            trailing: IconButton(
                              tooltip: 'Borrar sesión',
                              onPressed: () =>
                                  controller.deleteFocusSession(session.id),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetup(BuildContext context) {
    final visuals = context.visuals;
    final tasks = controller.tasks
        .where((task) => task.status == TaskStatus.active)
        .toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final selected = tasks.any((task) => task.id == _taskId) ? _taskId : null;
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nueva sesión', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in _presets)
                _FilterPill(
                  label: '$preset min',
                  selected: _minutes == preset,
                  onTap: () => setState(() => _minutes = preset),
                ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String?>(
            key: const ValueKey('focus-task'),
            initialValue: selected,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Tarea (opcional)',
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Sin tarea concreta'),
              ),
              for (final task in tasks)
                DropdownMenuItem<String?>(
                  value: task.id,
                  child: Text(task.title, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => setState(() => _taskId = value),
          ),
          if (selected == null) ...[
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('focus-label'),
              controller: _label,
              decoration: const InputDecoration(
                labelText: 'En qué vas a trabajar',
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                key: const ValueKey('focus-start'),
                onPressed: _start,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text('Empezar $_minutes min'),
              ),
              const SizedBox(width: 12),
              Text(
                'Al terminar suena un aviso y se anota el tiempo.',
                style: TextStyle(color: visuals.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRunning(BuildContext context, ActiveFocus active) {
    final visuals = context.visuals;
    final now = DateTime.now();
    final remaining = active.remainingSeconds(now);
    final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    final progress = active.plannedSeconds == 0
        ? 0.0
        : (active.elapsedSeconds(now) / active.plannedSeconds).clamp(0.0, 1.0);
    return _SurfaceCard(
      child: Column(
        children: [
          Text(
            active.label.isEmpty ? 'Sesión libre' : active.label,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          Text(
            '$minutes:$seconds',
            key: const ValueKey('focus-clock'),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: visuals.accent,
              backgroundColor: visuals.panelBorder,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              if (active.isRunning)
                FilledButton.icon(
                  key: const ValueKey('focus-pause'),
                  onPressed: controller.pauseFocus,
                  icon: const Icon(Icons.pause_rounded),
                  label: const Text('Pausar'),
                )
              else
                FilledButton.icon(
                  key: const ValueKey('focus-resume'),
                  onPressed: controller.resumeFocus,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Reanudar'),
                ),
              OutlinedButton.icon(
                key: const ValueKey('focus-stop'),
                onPressed: controller.stopFocus,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Terminar y anotar'),
              ),
              TextButton(
                onPressed: controller.discardFocus,
                child: const Text('Descartar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(
    BuildContext context, {
    required int todaySeconds,
    required int weekSeconds,
    required DateTime weekStart,
    required List<MapEntry<String, int>> topTasks,
  }) {
    final visuals = context.visuals;
    final perDay = List<int>.generate(7, (index) {
      final from = weekStart.add(Duration(days: index));
      return controller.focusSecondsBetween(
        from,
        from.add(const Duration(days: 1)),
      );
    });
    final maxDay = perDay.fold<int>(1, (m, v) => v > m ? v : m);
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _SoftChip(
                label: 'Hoy: ${_duracionLegible(todaySeconds)}',
                icon: Icons.today_rounded,
              ),
              _SoftChip(
                label: 'Esta semana: ${_duracionLegible(weekSeconds)}',
                icon: Icons.date_range_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 92,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Tooltip(
                          message: _duracionLegible(perDay[i]),
                          child: Container(
                            height: 6 + 54 * (perDay[i] / maxDay),
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: perDay[i] == 0
                                  ? visuals.panelBorder
                                  : visuals.accent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _diasCompletos[i].substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: visuals.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (topTasks.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Más tiempo esta semana',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            for (final entry in topTasks.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(entry.key, overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      _duracionLegible(entry.value),
                      style: TextStyle(color: visuals.textMuted),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
