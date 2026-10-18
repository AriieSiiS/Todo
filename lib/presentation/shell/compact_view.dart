part of 'app_shell.dart';

/// Vista mini de Hoy para dejar la ventana a un lado de la pantalla.
class CompactTodayView extends StatefulWidget {
  const CompactTodayView({
    required this.controller,
    required this.onExpand,
    required this.onQuickNote,
    super.key,
  });

  final TodoWorkspace controller;
  final VoidCallback onExpand;
  final VoidCallback onQuickNote;

  @override
  State<CompactTodayView> createState() => CompactTodayViewState();
}

class CompactTodayViewState extends State<CompactTodayView> {
  final TextEditingController _input = TextEditingController();

  TodoWorkspace get controller => widget.controller;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add() {
    final title = _input.text.trim();
    if (title.isEmpty) return;
    controller.createTask(title: title, scheduledAt: controller.logicalDate());
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return Scaffold(
      key: const ValueKey('compact-view'),
      backgroundColor: visuals.backgroundStart,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final today = controller.logicalDate();
            final pending = controller.tasksForToday();
            final active = controller.activeFocus;
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hoy',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            Text(
                              '${_capitalizar(_fechaConDia(today))} · ${pending.length} ${pending.length == 1 ? 'pendiente' : 'pendientes'}',
                              style: TextStyle(
                                  color: visuals.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('compact-note'),
                        tooltip: 'Nota rápida',
                        onPressed: widget.onQuickNote,
                        icon: const Icon(Icons.edit_note_rounded),
                      ),
                      IconButton(
                        key: const ValueKey('compact-expand'),
                        tooltip: 'Volver a la ventana completa',
                        onPressed: widget.onExpand,
                        icon: const Icon(Icons.open_in_full_rounded),
                      ),
                    ],
                  ),
                  if (active != null) ...[
                    const SizedBox(height: 6),
                    _SoftChip(
                      label: active.isRunning
                          ? 'Enfoque: ${_duracionLegible(active.remainingSeconds(DateTime.now()))} restantes'
                          : 'Enfoque en pausa',
                      icon: Icons.timer_rounded,
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('compact-input'),
                    controller: _input,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(),
                    decoration: InputDecoration(
                      hintText: 'Nueva tarea para hoy',
                      isDense: true,
                      suffixIcon: IconButton(
                        tooltip: 'Añadir',
                        onPressed: _add,
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: pending.isEmpty
                        ? Center(
                            child: Text(
                              'Nada pendiente para hoy.',
                              style: TextStyle(color: visuals.textMuted),
                            ),
                          )
                        : ListView.separated(
                            itemCount: pending.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final task = pending[index];
                              return Material(
                                color: visuals.panel,
                                borderRadius: BorderRadius.circular(14),
                                child: CheckboxListTile(
                                  key: ValueKey('compact-task-${task.id}'),
                                  dense: true,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  value: false,
                                  onChanged: (_) =>
                                      controller.completeTask(task.id),
                                  title: Text(
                                    task.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: task.scheduledAt != null &&
                                          (task.scheduledAt!.hour != 0 ||
                                              task.scheduledAt!.minute != 0)
                                      ? Text(
                                          '${task.scheduledAt!.hour.toString().padLeft(2, '0')}:${task.scheduledAt!.minute.toString().padLeft(2, '0')}',
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
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
