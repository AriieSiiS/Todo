part of 'app_shell.dart';

Future<void> showQuickNoteComposer(
  BuildContext context,
  TodoWorkspace controller, {
  QuickNote? initialNote,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.30),
    builder: (context) => _QuickNoteComposerDialog(
      controller: controller,
      initialNote: initialNote,
    ),
  );
}

class _QuickCaptureBar extends StatelessWidget {
  const _QuickCaptureBar({
    required this.controller,
    this.compact = false,
  });

  final TodoWorkspace controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final action = FilledButton.tonal(
      onPressed: () => showQuickNoteComposer(context, controller),
      style: FilledButton.styleFrom(
        backgroundColor:
            visuals.isPhantom ? visuals.panelAlt : const Color(0xFFF7F1E8),
        foregroundColor:
            visuals.isPhantom ? visuals.textStrong : const Color(0xFF243127),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.edit_note_rounded, size: 18),
          const SizedBox(width: 8),
          Text(compact ? 'Abrir nota rápida' : 'Nueva nota rápida'),
        ],
      ),
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Apunta algo rápido y lo revisas después.',
            style: TextStyle(color: visuals.textMuted, height: 1.35),
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: action),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Guarda ideas sueltas, recados o cosas por decidir sin forzarte a clasificarlas ahora.',
          style: TextStyle(color: visuals.textMuted, height: 1.4),
        ),
        const SizedBox(height: 14),
        action,
      ],
    );
  }
}

class _QuickNoteComposerDialog extends StatefulWidget {
  const _QuickNoteComposerDialog({
    required this.controller,
    this.initialNote,
  });

  final TodoWorkspace controller;
  final QuickNote? initialNote;

  @override
  State<_QuickNoteComposerDialog> createState() =>
      _QuickNoteComposerDialogState();
}

class _QuickNoteComposerDialogState extends State<_QuickNoteComposerDialog> {
  late final TextEditingController _contentController;
  DateTime? _scheduledFor;

  bool get _isEditing => widget.initialNote != null;

  @override
  void initState() {
    super.initState();
    _contentController =
        TextEditingController(text: widget.initialNote?.content ?? '');
    _scheduledFor = widget.initialNote?.scheduledFor;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.fromLTRB(
        32,
        22,
        32,
        MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: visuals.isPhantom ? visuals.panel : const Color(0xFFFFFCF8),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: visuals.isPhantom
                ? visuals.textStrong
                : const Color(0xFFE2D5C4),
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 790),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F0E7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        color: Color(0xFF607A5A),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEditing ? 'Editar nota' : 'Nota',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Apunta algo rápido y lo revisas después.',
                              style: TextStyle(color: visuals.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _contentController,
                  maxLines: 9,
                  minLines: 9,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Escribe una nota rápida...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month_outlined, size: 18),
                      label: Text(
                        _scheduledFor == null
                            ? 'Anadir fecha'
                            : _formatInboxDate(_scheduledFor!),
                      ),
                    ),
                    if (_scheduledFor != null)
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _scheduledFor = null;
                          });
                        },
                        child: const Text('Quitar fecha'),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                const Divider(height: 1),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.inventory_2_outlined, size: 18),
                      label:
                          Text(_isEditing ? 'Guardar cambios' : 'Guardar nota'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = widget.controller.logicalDate();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledFor ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _scheduledFor = DateTime(picked.year, picked.month, picked.day, 10);
    });
  }

  void _save() {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      return;
    }
    if (_isEditing) {
      widget.controller.updateNote(
        widget.initialNote!.id,
        content: content,
        scheduledFor: _scheduledFor,
      );
    } else {
      widget.controller.createNote(content, scheduledFor: _scheduledFor);
    }
    Navigator.of(context).pop();
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.controller,
    required this.task,
    super.key,
  });

  final TodoWorkspace controller;
  final TaskModel task;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final subtasks = controller.subtasksOf(task);
    final category = task.categoryIds.isNotEmpty
        ? controller.categoryById(task.categoryIds.first)
        : null;
    final project = task.projectIds.isNotEmpty
        ? controller.projectById(task.projectIds.first)
        : null;
    final index =
        controller.tasksForToday().indexWhere((item) => item.id == task.id);

    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: visuals.isPhantom
              ? (task.priority == TaskPriority.urgent
                  ? visuals.accent.withValues(alpha: 0.18)
                  : visuals.panelAlt)
              : Colors.white,
          borderRadius: BorderRadius.circular(visuals.isPhantom ? 0 : 22),
          border: Border.all(
            color: visuals.isPhantom
                ? (task.priority.index >= TaskPriority.high.index
                    ? visuals.accent
                    : visuals.textStrong)
                : const Color(0xFFE5D8C7),
            width: visuals.isPhantom ? 1.5 : 1,
          ),
          boxShadow: visuals.isPhantom
              ? const [
                  BoxShadow(
                    blurRadius: 0,
                    color: Color(0xFF0A0A0A),
                    offset: Offset(8, 8),
                  ),
                ]
              : const [
                  BoxShadow(
                    blurRadius: 18,
                    color: Color(0x12000000),
                    offset: Offset(0, 8),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReorderableDragStartListener(
                    index: index < 0 ? 0 : index,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 8, top: 6),
                      child: Icon(Icons.drag_indicator_rounded),
                    ),
                  ),
                  Checkbox(
                    value: task.status == TaskStatus.completed,
                    onChanged: (_) => controller.completeTask(task.id),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => showTaskEditor(context, controller,
                          initialTask: task),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  task.title,
                                  style: TextStyle(
                                    fontSize: visuals.isPhantom ? 24 : 19,
                                    fontWeight: FontWeight.w700,
                                    color: visuals.textStrong,
                                    letterSpacing: visuals.isPhantom ? 0.45 : 0,
                                  ),
                                ),
                              ),
                              if (subtasks.isNotEmpty)
                                IconButton(
                                  onPressed: () =>
                                      controller.toggleTaskCollapse(task.id),
                                  icon: Icon(task.collapsed
                                      ? Icons.unfold_more_rounded
                                      : Icons.unfold_less_rounded),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (category != null)
                                _SoftChip(
                                  label: category.name,
                                  icon: category.icon,
                                  color: category.color,
                                ),
                              if (project != null)
                                _SoftChip(label: project.name),
                              if (task.scheduledAt != null &&
                                  _hasVisibleTime(task.scheduledAt!))
                                _SoftChip(label: _timeLabel(task.scheduledAt!)),
                              _SoftChip(label: task.priority.name),
                              if (task.reminderRule?.enabled ?? false)
                                const _SoftChip(
                                    label: 'Aviso',
                                    icon: Icons.notifications_active_rounded),
                              if (task.calendarLink != null)
                                _SoftChip(
                                  label:
                                      'Google ${task.calendarLink!.syncStatus.name}',
                                  icon: Icons.calendar_month_rounded,
                                  color: const Color(0xFF6C7B8E),
                                ),
                            ],
                          ),
                          if (task.description != null &&
                              task.description!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(task.description!,
                                style: TextStyle(color: visuals.textMuted)),
                          ],
                          if (task.materials.isNotEmpty ||
                              task.checklist.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            if (task.materials.isNotEmpty)
                              Text('Materiales: ${task.materials.join(', ')}',
                                  style: TextStyle(color: visuals.textMuted)),
                            if (task.checklist.isNotEmpty)
                              Text('Checklist: ${task.checklist.join(' · ')}',
                                  style: TextStyle(color: visuals.textMuted)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'subtask') {
                        controller.createSubtask(task.id, 'Nueva subtarea');
                      } else if (value == 'tomorrow') {
                        await controller.moveTaskToDay(
                            task.id,
                            controller
                                .logicalDate()
                                .add(const Duration(days: 1)));
                      } else if (value == 'sync') {
                        await controller.syncTaskToCalendar(task.id);
                      } else if (value == 'unlink') {
                        controller.unlinkTaskFromCalendarEvent(task.id);
                      } else if (value == 'delete') {
                        controller.deleteTask(task.id);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                          value: 'subtask', child: Text('Crear subtarea')),
                      const PopupMenuItem(
                          value: 'tomorrow', child: Text('Mover a mañana')),
                      if (controller.isCalendarConnected) ...[
                        const PopupMenuItem(
                            value: 'sync',
                            child: Text('Sincronizar con Google')),
                        if (task.calendarLink != null)
                          const PopupMenuItem(
                              value: 'unlink', child: Text('Quitar enlace')),
                      ],
                      const PopupMenuItem(
                          value: 'delete', child: Text('Borrar')),
                    ],
                  ),
                ],
              ),
              if (subtasks.isNotEmpty && !task.collapsed)
                Padding(
                  padding: const EdgeInsets.only(left: 54, top: 12),
                  child: Column(
                    children: subtasks
                        .map(
                          (subtask) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: visuals.isPhantom
                                    ? visuals.panel
                                    : const Color(0xFFF7F1E9),
                                borderRadius: BorderRadius.circular(
                                    visuals.isPhantom ? 0 : 14),
                                border: Border.all(
                                    color: visuals.isPhantom
                                        ? visuals.panelBorder
                                        : const Color(0xFFE4D8CA)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    visuals.isPhantom
                                        ? Icons.chevron_right_rounded
                                        : Icons
                                            .subdirectory_arrow_right_rounded,
                                    size: 16,
                                    color: visuals.isPhantom
                                        ? visuals.accentAlt
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(subtask.title,
                                          style: TextStyle(
                                              color: visuals.textStrong))),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.tone,
  });

  final String label;
  final String value;
  final String detail;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: visuals.isPhantom
            ? visuals.panel
            : Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(visuals.isPhantom ? 0 : 22),
        border: Border.all(
            color: visuals.isPhantom
                ? visuals.textStrong
                : const Color(0xFFE3D5C3),
            width: visuals.isPhantom ? 1.6 : 1),
        boxShadow: visuals.isPhantom
            ? const [
                BoxShadow(
                  blurRadius: 0,
                  offset: Offset(8, 8),
                  color: Color(0xFF121212),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: visuals.isPhantom ? visuals.accentAlt : tone,
                  fontWeight: FontWeight.w700,
                  letterSpacing: visuals.isPhantom ? 0.8 : 0)),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  fontSize: visuals.isPhantom ? 46 : 36,
                  fontWeight: FontWeight.w800,
                  color: visuals.textStrong)),
          const SizedBox(height: 6),
          Text(detail, style: TextStyle(color: visuals.textMuted)),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: visuals.isPhantom
            ? visuals.panel
            : Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(visuals.isPhantom ? 0 : 26),
        border: Border.all(
            color: visuals.isPhantom
                ? visuals.panelBorder
                : const Color(0xFFE5D8C7),
            width: visuals.isPhantom ? 1.6 : 1),
        boxShadow: visuals.isPhantom
            ? const [
                BoxShadow(
                  blurRadius: 0,
                  color: Color(0xFF0A0A0A),
                  offset: Offset(10, 10),
                ),
              ]
            : const [
                BoxShadow(
                  blurRadius: 20,
                  color: Color(0x10000000),
                  offset: Offset(0, 10),
                ),
              ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({
    required this.label,
    this.icon,
    this.color,
  });

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: visuals.isPhantom
            ? (color ?? visuals.accent).withValues(alpha: 0.22)
            : color?.withValues(alpha: 0.14) ?? const Color(0xFFF0E7DA),
        borderRadius: BorderRadius.circular(visuals.isPhantom ? 0 : 999),
        border: visuals.isPhantom
            ? Border.all(color: visuals.textStrong, width: 1.1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon,
                size: 15,
                color: visuals.isPhantom
                    ? visuals.textStrong
                    : color ?? const Color(0xFF5A5A57)),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: TextStyle(
                  color: visuals.isPhantom ? visuals.textStrong : null,
                  letterSpacing: visuals.isPhantom ? 0.3 : 0)),
        ],
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 154, minHeight: 48),
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: FilledButton.styleFrom(
          minimumSize: const Size(154, 48),
          backgroundColor:
              visuals.isPhantom ? visuals.accent : const Color(0xFF263625),
          foregroundColor: const Color(0xFFFFFCF8),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: visuals.isPhantom
              ? const BeveledRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(3),
                    bottomRight: Radius.circular(22),
                  ),
                )
              : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
        ),
      ),
    );
  }
}

class _HeaderSecondaryButton extends StatelessWidget {
  const _HeaderSecondaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 154, minHeight: 48),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(154, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          backgroundColor: Colors.white.withValues(alpha: 0.62),
          side: const BorderSide(color: Color(0xFFE8DCCB)),
          foregroundColor: const Color(0xFF2D2A25),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final narrow = MediaQuery.sizeOf(context).width < 760;
    final heading = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (visuals.isPhantom)
          Container(
            width: 18,
            height: 46,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: visuals.accent,
              border: Border.all(color: visuals.textStrong),
            ),
          ),
        Flexible(
          child: Text(title, style: Theme.of(context).textTheme.displaySmall),
        ),
      ],
    );
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: visuals.textMuted)),
          if (trailing != null) const SizedBox(height: 14),
          if (trailing != null) trailing!,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: 6),
              Text(subtitle, style: TextStyle(color: visuals.textMuted)),
            ],
          ),
        ),
        if (trailing != null) const SizedBox(width: 12),
        if (trailing != null) Flexible(child: trailing!),
      ],
    );
  }
}
