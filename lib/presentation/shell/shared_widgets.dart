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
          Text(compact ? 'Escribir nota' : 'Nueva nota'),
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
  static const _emojis = <String>[
    '💡',
    '📌',
    '📝',
    '🎯',
    '✨',
    '❤️',
    '🏠',
    '🎬',
    '📚',
    '💻',
    '🛒',
    '🌱',
  ];

  late final TextEditingController _titleController;
  late final EditorState _editorState;
  late String _emoji;
  late bool _isPinned;
  late List<String> _categoryIds;

  bool get _isEditing => widget.initialNote != null;

  @override
  void initState() {
    super.initState();
    final parts = _splitNoteContent(widget.initialNote?.content ?? '');
    _titleController = TextEditingController(
      text: widget.initialNote == null ? '' : parts.title,
    );
    final initialBody = parts.body ?? '';
    _editorState = initialBody.trim().isEmpty
        ? EditorState.blank()
        : EditorState(document: markdownToDocument(initialBody));
    _editorState.logConfiguration.level = AppFlowyEditorLogLevel.off;
    _emoji = widget.initialNote?.emoji ?? '';
    _isPinned = widget.initialNote?.isPinned ?? false;
    _categoryIds = List<String>.from(
      widget.initialNote?.categoryIds ?? const <String>[],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _editorState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final dialogHeight =
        (MediaQuery.sizeOf(context).height - 44).clamp(360.0, 720.0).toDouble();
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
          color: visuals.panel,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: visuals.isPhantom
                ? visuals.textStrong
                : const Color(0xFFE2D5C4),
          ),
        ),
        child: SizedBox(
          width: 900,
          height: dialogHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
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
                          Text(
                            _isEditing ? 'Editar nota' : 'Nueva nota',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Escribe libremente. Puedes decidir qué hacer con ella más adelante.',
                            style: TextStyle(color: visuals.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    PopupMenuButton<String>(
                      tooltip: 'Elegir emoji',
                      onSelected: (value) => setState(() {
                        _emoji = value == 'none' ? '' : value;
                      }),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'none',
                          child: Text('Sin emoji'),
                        ),
                        for (final emoji in _emojis)
                          PopupMenuItem(
                            value: emoji,
                            child: Text(emoji,
                                style: const TextStyle(fontSize: 24)),
                          ),
                      ],
                      child: Container(
                        width: 58,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F0E8),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2D5C4)),
                        ),
                        child: Text(
                          _emoji.isEmpty ? '＋' : _emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _titleController,
                        autofocus: true,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Título de la nota',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      tooltip: _isPinned ? 'Desfijar nota' : 'Fijar nota',
                      onPressed: () => setState(() => _isPinned = !_isPinned),
                      icon: Icon(
                        _isPinned
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Categorías',
                      style: TextStyle(color: visuals.textMuted),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final category
                              in widget.controller.categories.where(
                            (category) => _categoryIds.contains(category.id),
                          ))
                            InputChip(
                              label: Text(category.name),
                              avatar: Icon(category.icon, size: 16),
                              backgroundColor:
                                  category.color.withValues(alpha: 0.16),
                              side: BorderSide(
                                color: category.color.withValues(alpha: 0.38),
                              ),
                              onDeleted: () => setState(
                                () => _categoryIds.remove(category.id),
                              ),
                            ),
                          ActionChip(
                            avatar: const Icon(Icons.add_rounded, size: 17),
                            label: const Text('Añadir categoría'),
                            onPressed: _pickCategories,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _NoteFormattingToolbar(editorState: _editorState),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFCF8),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2D5C4)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AppFlowyEditor(
                      key: const ValueKey('editorContenidoNota'),
                      editorState: _editorState,
                      editable: true,
                      blockComponentBuilders: standardBlockComponentBuilderMap,
                      commandShortcutEvents: standardCommandShortcutEvents,
                      characterShortcutEvents: standardCharacterShortcutEvents,
                      editorStyle: EditorStyle.desktop(
                        padding: const EdgeInsets.all(18),
                        cursorColor: const Color(0xFF607A4D),
                        selectionColor: const Color(0xFFD8E4CF),
                        textStyleConfiguration: const TextStyleConfiguration(
                          text: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: Color(0xFF2D2A25),
                          ),
                          bold: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
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
                      icon: const Icon(Icons.save_outlined, size: 18),
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

  void _save() {
    final title = _titleController.text.trim();
    final body = documentToMarkdown(_editorState.document).trim();
    if (title.isEmpty && body.isEmpty) return;
    final resolvedTitle = title.isEmpty ? 'Sin título' : title;
    final content = body.isEmpty ? resolvedTitle : '$resolvedTitle\n$body';
    if (_isEditing) {
      widget.controller.updateNote(
        widget.initialNote!.id,
        content: content,
        scheduledFor: widget.initialNote!.scheduledFor,
        emoji: _emoji,
        isPinned: _isPinned,
        categoryIds: _categoryIds,
      );
    } else {
      widget.controller.createNote(
        content,
        emoji: _emoji,
        isPinned: _isPinned,
        categoryIds: _categoryIds,
      );
    }
    Navigator.of(context).pop();
  }

  Future<void> _pickCategories() async {
    final categories = widget.controller.categories
        .where((category) => category.active)
        .toList();
    final draft = _categoryIds.toSet();
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Categorías de la nota'),
          content: SizedBox(
            width: 480,
            child: categories.isEmpty
                ? const Text(
                    'Todavía no hay categorías activas. Puedes crearlas desde la sección Categorías.',
                  )
                : Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final category in categories)
                        FilterChip(
                          selected: draft.contains(category.id),
                          avatar: Icon(category.icon, size: 17),
                          label: Text(category.name),
                          selectedColor: category.color.withValues(alpha: 0.22),
                          checkmarkColor: category.color,
                          onSelected: (value) => setDialogState(() {
                            if (value) {
                              draft.add(category.id);
                            } else {
                              draft.remove(category.id);
                            }
                          }),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(draft),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _categoryIds = selected.toList());
  }
}

class _NoteFormattingToolbar extends StatelessWidget {
  const _NoteFormattingToolbar({required this.editorState});

  final EditorState editorState;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Selection?>(
      valueListenable: editorState.selectionNotifier,
      builder: (context, selection, _) {
        return Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F0E8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _NoteFormatButton(
                icon: Icons.format_bold_rounded,
                tooltip: 'Negrita',
                active: _isTextStyleActive(
                  selection,
                  AppFlowyRichTextKeys.bold,
                ),
                onPressed: () =>
                    editorState.toggleAttribute(AppFlowyRichTextKeys.bold),
              ),
              _NoteFormatButton(
                icon: Icons.format_italic_rounded,
                tooltip: 'Cursiva',
                active: _isTextStyleActive(
                  selection,
                  AppFlowyRichTextKeys.italic,
                ),
                onPressed: () =>
                    editorState.toggleAttribute(AppFlowyRichTextKeys.italic),
              ),
              const VerticalDivider(indent: 9, endIndent: 9),
              PopupMenuButton<int>(
                tooltip: 'Estilo de texto',
                onSelected: _setHeading,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 0, child: Text('Texto normal')),
                  PopupMenuItem(value: 1, child: Text('Título grande')),
                  PopupMenuItem(value: 2, child: Text('Título mediano')),
                  PopupMenuItem(value: 3, child: Text('Título pequeño')),
                ],
                icon: const Icon(Icons.title_rounded),
              ),
              _NoteFormatButton(
                icon: Icons.check_box_outlined,
                tooltip: 'Lista de tareas',
                onPressed: () => _toggleBlock(TodoListBlockKeys.type),
              ),
              _NoteFormatButton(
                icon: Icons.format_list_bulleted_rounded,
                tooltip: 'Lista con viñetas',
                onPressed: () => _toggleBlock(BulletedListBlockKeys.type),
              ),
              _NoteFormatButton(
                icon: Icons.format_list_numbered_rounded,
                tooltip: 'Lista numerada',
                onPressed: () => _toggleBlock(NumberedListBlockKeys.type),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isTextStyleActive(Selection? selection, String key) {
    if (selection == null) return editorState.toggledStyle.containsKey(key);
    if (selection.isCollapsed) return editorState.toggledStyle.containsKey(key);
    final nodes = editorState.getNodesInSelection(selection);
    return nodes.allSatisfyInSelection(
      selection,
      (delta) => delta.everyAttributes(
        (attributes) => attributes[key] == true,
      ),
    );
  }

  void _setHeading(int level) {
    editorState.formatNode(null, (node) {
      if (level == 0) return node.copyWith(type: ParagraphBlockKeys.type);
      return node.copyWith(
        type: HeadingBlockKeys.type,
        attributes: {...node.attributes, HeadingBlockKeys.level: level},
      );
    });
  }

  void _toggleBlock(String type) {
    editorState.formatNode(null, (node) {
      final nextType = node.type == type ? ParagraphBlockKeys.type : type;
      return node.copyWith(
        type: nextType,
        attributes: {
          ...node.attributes,
          if (nextType == TodoListBlockKeys.type)
            TodoListBlockKeys.checked: false,
        },
      );
    });
  }
}

class _NoteFormatButton extends StatelessWidget {
  const _NoteFormatButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: active ? const Color(0xFFDCE8D3) : Colors.transparent,
        foregroundColor: const Color(0xFF31472F),
      ),
      icon: Icon(icon, size: 20),
    );
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
                              _SoftChip(
                                  label: _taskPriorityLabel(task.priority)),
                              if (task.reminderRule?.enabled ?? false)
                                const _SoftChip(
                                    label: 'Aviso',
                                    icon: Icons.notifications_active_rounded),
                              if (task.calendarLink != null)
                                _SoftChip(
                                  label:
                                      'Google ${_calendarSyncStatusLabel(task.calendarLink!.syncStatus)}',
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
                              Text(
                                  'Lista de comprobación: ${task.checklist.join(' · ')}',
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

class _CatalogSearchField extends StatelessWidget {
  const _CatalogSearchField({
    required this.label,
    required this.hint,
    required this.onChanged,
    this.controller,
    super.key,
  });

  final String label;
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        labelText: label,
        hintText: hint,
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
    this.compact = false,
    this.pinTrailingToEdge = false,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool compact;
  final bool pinTrailingToEdge;

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
          child: Text(
            title,
            style: compact
                ? Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(fontSize: 40, height: 1)
                : Theme.of(context).textTheme.displaySmall,
          ),
        ),
      ],
    );
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: TextStyle(color: visuals.textMuted)),
          ],
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
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(color: visuals.textMuted)),
              ],
            ],
          ),
        ),
        if (trailing != null) const SizedBox(width: 12),
        if (trailing != null)
          if (pinTrailingToEdge) trailing! else Flexible(child: trailing!),
      ],
    );
  }
}

class _SectionTabBar extends StatelessWidget {
  const _SectionTabBar({required this.labels, this.onTap});

  final List<String> labels;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return TabBar(
      onTap: onTap,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.label,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(
          color: visuals.isPhantom ? visuals.accent : const Color(0xFF70835D),
          width: 2,
        ),
      ),
      labelColor:
          visuals.isPhantom ? visuals.textStrong : const Color(0xFF51693E),
      unselectedLabelColor: visuals.textMuted,
      labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      unselectedLabelStyle:
          const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      labelPadding: const EdgeInsets.only(right: 26),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      tabs: [
        for (final label in labels)
          Tab(
              height: 36,
              child:
                  Align(alignment: Alignment.centerLeft, child: Text(label))),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected
              ? (visuals.isPhantom ? visuals.accent : const Color(0xFFE8F1DD))
              : (visuals.isPhantom ? visuals.panel : Colors.white),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: visuals.pageBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: visuals.isPhantom
                    ? visuals.textStrong
                    : const Color(0xFF61764C),
              ),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(
                color: visuals.textStrong,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _taskPriorityLabel(TaskPriority priority) => switch (priority) {
      TaskPriority.low => 'Prioridad baja',
      TaskPriority.medium => 'Prioridad media',
      TaskPriority.high => 'Prioridad alta',
      TaskPriority.urgent => 'Urgente',
    };

String _calendarSyncStatusLabel(CalendarSyncStatus status) => switch (status) {
      CalendarSyncStatus.idle => 'sin sincronizar',
      CalendarSyncStatus.synced => 'sincronizado',
      CalendarSyncStatus.pending => 'pendiente',
      CalendarSyncStatus.error => 'con error',
    };
