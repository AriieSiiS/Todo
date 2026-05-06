part of 'editors.dart';

class _TaskEditorDialog extends StatefulWidget {
  const _TaskEditorDialog({
    required this.controller,
    this.initialTask,
    this.parentTaskId,
    this.initialDateOverride,
    this.initialTitle,
    this.initialDescription,
  });

  final TodoWorkspace controller;
  final TaskModel? initialTask;
  final String? parentTaskId;
  final DateTime? initialDateOverride;
  final String? initialTitle;
  final String? initialDescription;

  @override
  State<_TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<_TaskEditorDialog> {
  static const List<int> _quickReminderMinutes = <int>[5, 30, 60, 1440];

  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final List<String> _subtasks;
  late DateTime _date;
  late TimeOfDay _time;
  late TaskPriority _priority;
  late RecurrenceType _recurrenceType;
  late int _recurrenceInterval;
  late String? _projectId;
  late List<String> _categoryIds;
  late bool _reminderEnabled;
  late int _minutesBefore;
  late bool _syncToGoogle;
  late int _estimatedDurationMinutes;

  TodoWorkspace get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _ensureSeedCategory();
    final initial = widget.initialTask;
    final scheduledAt = initial?.scheduledAt ??
        widget.initialDateOverride ??
        controller.logicalDate();
    _titleController = TextEditingController(
      text: initial?.title ?? widget.initialTitle ?? '',
    );
    _notesController = TextEditingController(
      text: initial?.description ?? widget.initialDescription ?? '',
    );
    _subtasks = [...(initial?.checklist ?? const <String>[])];
    _date = DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);
    _time = TimeOfDay(hour: scheduledAt.hour, minute: scheduledAt.minute);
    _priority = initial?.priority ?? TaskPriority.medium;
    _recurrenceType = initial?.recurrence.type ?? RecurrenceType.none;
    _recurrenceInterval = initial?.recurrence.interval ?? 1;
    _projectId = initial?.projectIds.isNotEmpty == true
        ? initial!.projectIds.first
        : null;
    _categoryIds = [...(initial?.categoryIds ?? const <String>[])];
    _reminderEnabled = initial?.reminderRule?.enabled ?? false;
    _minutesBefore = initial?.reminderRule?.minutesBefore ??
        controller.notificationSettings.defaultMinutesBeforeTask;
    _syncToGoogle = initial?.calendarLink != null;
    _estimatedDurationMinutes = 30;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visuals = Theme.of(context).extension<TodoVisuals>()!;
    final categories =
        controller.categories.where((item) => item.active).toList();
    final projects = controller.projects
        .where((item) => item.status == ProjectStatus.active)
        .toList();
    final selectedCategories =
        categories.where((item) => _categoryIds.contains(item.id)).toList();
    final selectedProject = _findProject(projects, _projectId);
    final title = _titleController.text.trim().isEmpty
        ? 'Tu tarea'
        : _titleController.text.trim();
    final wide = MediaQuery.sizeOf(context).width >= 1180;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.fromLTRB(
          32, 22, 32, MediaQuery.of(context).viewInsets.bottom + 22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: visuals.isPhantom ? visuals.panel : const Color(0xFFFFFCF8),
          borderRadius: BorderRadius.circular(visuals.isPhantom ? 0 : 28),
          border: Border.all(
            color: visuals.isPhantom
                ? visuals.textStrong
                : const Color(0xFFE2D5C4),
            width: visuals.isPhantom ? 1.8 : 1,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280, maxHeight: 920),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            child: Column(
              children: [
                _dialogHeader(
                  context,
                  title: widget.initialTask == null
                      ? 'Nueva tarea'
                      : 'Editar tarea',
                  subtitle: 'Crea una tarea y organízala para tu día real.',
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ScrollConfiguration(
                    behavior: const MaterialScrollBehavior()
                        .copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 7,
                                  child: _buildTaskForm(
                                      context, categories, projects),
                                ),
                                const SizedBox(width: 18),
                                SizedBox(
                                  width: 320,
                                  child: Column(
                                    children: [
                                      _AsideCard(
                                        title: 'Resumen',
                                        subtitle: 'Asi se vera tu tarea.',
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(14),
                                              decoration: _softBorderBox(),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                          Icons
                                                              .check_box_outline_blank_rounded,
                                                          size: 18),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Text(
                                                          title,
                                                          style: const TextStyle(
                                                              fontSize: 18,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (selectedCategories
                                                      .isNotEmpty) ...[
                                                    const SizedBox(height: 10),
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      children:
                                                          selectedCategories
                                                              .map(
                                                                (category) =>
                                                                    _tagChip(
                                                                  category.name,
                                                                  category.color
                                                                      .withValues(
                                                                          alpha:
                                                                              0.16),
                                                                  category
                                                                      .color,
                                                                ),
                                                              )
                                                              .toList(),
                                                    ),
                                                  ],
                                                  const SizedBox(height: 14),
                                                  if (selectedProject != null)
                                                    _summaryLine(
                                                        Icons
                                                            .home_work_outlined,
                                                        selectedProject.name),
                                                  _summaryLine(
                                                    Icons
                                                        .calendar_today_outlined,
                                                    _hasVisibleTimeOfDay(_time)
                                                        ? '${_weekdayLong(_date)} · ${_formatTime24(_time)}'
                                                        : _weekdayLong(_date),
                                                  ),
                                                  if (_recurrenceType !=
                                                      RecurrenceType.none)
                                                    _summaryLine(
                                                        Icons.autorenew_rounded,
                                                        _recurrenceLabel()),
                                                  _summaryLine(
                                                      Icons.flag_outlined,
                                                      _priorityLabel(
                                                          _priority)),
                                                  _summaryLine(
                                                      Icons.timelapse_rounded,
                                                      '$_estimatedDurationMinutes min'),
                                                  if (_subtasks
                                                      .where((item) => item
                                                          .trim()
                                                          .isNotEmpty)
                                                      .isNotEmpty)
                                                    _summaryLine(
                                                      Icons
                                                          .format_list_bulleted_rounded,
                                                      '${_subtasks.where((item) => item.trim().isNotEmpty).length} subtareas',
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      _AsideCard(
                                        title: 'Donde aparecera',
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text('Hoy',
                                                style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                            Text(_dateLabel(_date),
                                                style: TextStyle(
                                                    color: visuals.textMuted)),
                                            const SizedBox(height: 10),
                                            _appearanceRow(
                                              _hasVisibleTimeOfDay(_time)
                                                  ? _formatTime24(_time)
                                                  : 'Sin hora',
                                              title,
                                            ),
                                            const SizedBox(height: 16),
                                            const Text('Esta semana',
                                                style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                            const SizedBox(height: 8),
                                            _appearanceRow(
                                              _hasVisibleTimeOfDay(_time)
                                                  ? '${_weekdayShort(_date)} ${_date.day} ${_monthShort(_date.month)} · ${_formatTime24(_time)}'
                                                  : '${_weekdayShort(_date)} ${_date.day} ${_monthShort(_date.month)}',
                                              title,
                                            ),
                                            if (_recurrenceType ==
                                                RecurrenceType.weekly) ...[
                                              const SizedBox(height: 8),
                                              _appearanceRow(
                                                  _hasVisibleTimeOfDay(_time)
                                                      ? 'Dom 10 may · ${_formatTime24(_time)}'
                                                      : 'Dom 10 may',
                                                  title),
                                              const SizedBox(height: 8),
                                              _appearanceRow(
                                                  _hasVisibleTimeOfDay(_time)
                                                      ? 'Dom 17 may · ${_formatTime24(_time)}'
                                                      : 'Dom 17 may',
                                                  title),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      _AsideCard(
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.event_note_rounded,
                                                color: Color(0xFF70835D),
                                                size: 18),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                _syncToGoogle
                                                    ? 'Se creara tambien en tu Google Calendar.'
                                                    : 'Solo se guardara dentro de la app.',
                                                style: TextStyle(
                                                    color: visuals.textMuted,
                                                    height: 1.35),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : _buildTaskForm(context, categories, projects),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _dialogFooter(
                  primaryLabel: widget.initialTask == null
                      ? 'Guardar tarea'
                      : 'Guardar cambios',
                  secondaryLabel: 'Guardar y crear otra',
                  onPrimary: _saveTask,
                  onSecondary: _saveTaskAndReset,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskForm(BuildContext context, List<CategoryModel> categories,
      List<ProjectModel> projects) {
    const fieldTextStyle = TextStyle(fontWeight: FontWeight.w400, fontSize: 15);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Título de la tarea'),
        const SizedBox(height: 6),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            hintText: 'Limpiar baño',
            suffixText: '${_titleController.text.length}/80',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        _sectionLabel('Categorías'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((category) {
            final selected = _categoryIds.contains(category.id);
            return FilterChip(
              selected: selected,
              label: Text(category.name),
              labelStyle: TextStyle(
                color: selected ? category.color : const Color(0xFF4F4A43),
                fontWeight: FontWeight.w400,
              ),
              selectedColor: category.color.withValues(alpha: 0.16),
              backgroundColor: category.color.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(
                    color: selected
                        ? category.color.withValues(alpha: 0.35)
                        : Colors.transparent),
              ),
              onSelected: (value) {
                setState(() {
                  if (value) {
                    _categoryIds = <String>[..._categoryIds, category.id];
                  } else {
                    _categoryIds =
                        _categoryIds.where((id) => id != category.id).toList();
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        _sectionLabel('Proyecto (opcional)'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String?>(
          initialValue: _projectId,
          style: fieldTextStyle.copyWith(color: const Color(0xFF2D2A25)),
          items: [
            const DropdownMenuItem<String?>(
                value: null,
                child: Text('Sin proyecto', style: fieldTextStyle)),
            ...projects.map(
              (project) => DropdownMenuItem<String?>(
                value: project.id,
                child: Row(
                  children: [
                    Icon(project.icon, size: 16, color: project.color),
                    const SizedBox(width: 8),
                    Text(project.name, style: fieldTextStyle),
                  ],
                ),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _projectId = value),
          decoration: const InputDecoration(),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _pickerField(
                context,
                label: 'Fecha',
                icon: Icons.calendar_today_outlined,
                value: _dateLabel(_date),
                onTap: () async {
                  final picked = await _showTodoDatePicker(
                    context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    setState(() => _date = picked);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _pickerField(
                context,
                label: 'Hora',
                icon: Icons.schedule_rounded,
                value: _hasVisibleTimeOfDay(_time)
                    ? _formatTime24(_time)
                    : 'Sin hora',
                onTap: () async {
                  final picked = await _showTodoTimePicker(context, _time);
                  if (picked != null) {
                    setState(() => _time = picked);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Prioridad'),
                  const SizedBox(height: 6),
                  _PrioritySegmentedControl(
                    selected: _priority == TaskPriority.urgent
                        ? TaskPriority.high
                        : _priority,
                    onChanged: (value) => setState(() => _priority = value),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Duracion estimada (opcional)'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: _estimatedDurationMinutes,
                    style:
                        fieldTextStyle.copyWith(color: const Color(0xFF2D2A25)),
                    items: const [15, 30, 45, 60, 90]
                        .map((value) => DropdownMenuItem<int>(
                            value: value,
                            child: Text('$value min', style: fieldTextStyle)))
                        .toList(),
                    onChanged: (value) => setState(() =>
                        _estimatedDurationMinutes =
                            value ?? _estimatedDurationMinutes),
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.timelapse_rounded)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _sectionLabel('Repeticion'),
        const SizedBox(height: 6),
        DropdownButtonFormField<RecurrenceType>(
          initialValue: _recurrenceType,
          style: fieldTextStyle.copyWith(color: const Color(0xFF2D2A25)),
          items: const [
            DropdownMenuItem(
                value: RecurrenceType.none,
                child: Text('Sin repeticion', style: fieldTextStyle)),
            DropdownMenuItem(
                value: RecurrenceType.daily,
                child: Text('Diaria', style: fieldTextStyle)),
            DropdownMenuItem(
                value: RecurrenceType.weekly,
                child: Text('Semanal', style: fieldTextStyle)),
            DropdownMenuItem(
                value: RecurrenceType.everyXDays,
                child: Text('Cada X dias', style: fieldTextStyle)),
            DropdownMenuItem(
                value: RecurrenceType.yearly,
                child: Text('Anual', style: fieldTextStyle)),
          ],
          onChanged: (value) =>
              setState(() => _recurrenceType = value ?? _recurrenceType),
          decoration:
              const InputDecoration(prefixIcon: Icon(Icons.autorenew_rounded)),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            _sectionLabel('Subtareas'),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _subtasks.add('')),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Anadir subtarea'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: _softBorderBox(),
          child: Column(
            children: [
              for (var index = 0; index < _subtasks.length; index++)
                Column(
                  children: [
                    if (index > 0) const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.drag_indicator_rounded,
                              color: Color(0xFFB6ADA0)),
                          const SizedBox(width: 8),
                          const Icon(Icons.check_box_outline_blank_rounded,
                              size: 18, color: Color(0xFF8D8477)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              initialValue: _subtasks[index],
                              decoration: const InputDecoration.collapsed(
                                  hintText: 'Subtarea'),
                              onChanged: (value) => _subtasks[index] = value,
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                setState(() => _subtasks.removeAt(index)),
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 18),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              if (_subtasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Sin subtareas todavía.',
                        style: TextStyle(
                            color: Theme.of(context)
                                .extension<TodoVisuals>()!
                                .textMuted)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _sectionLabel('Notas'),
        const SizedBox(height: 6),
        TextField(
          controller: _notesController,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Usar limpiador multiusos y dejar todo ordenado.',
            suffixText: '${_notesController.text.length}/300',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Recordatorios'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        selected: !_reminderEnabled,
                        label: const Text('Sin aviso'),
                        onSelected: (_) =>
                            setState(() => _reminderEnabled = false),
                      ),
                      for (final minutes in _quickReminderMinutes)
                        FilterChip(
                          selected:
                              _reminderEnabled && _minutesBefore == minutes,
                          label: Text(_reminderPresetLabelGlobal(minutes)),
                          avatar: const Icon(Icons.notifications_none_rounded,
                              size: 16),
                          onSelected: (_) => setState(() {
                            _reminderEnabled = true;
                            _minutesBefore = minutes;
                          }),
                        ),
                      ActionChip(
                        label: Text(
                          _reminderEnabled &&
                                  !_quickReminderMinutes
                                      .contains(_minutesBefore)
                              ? _reminderPresetLabel(_minutesBefore)
                              : 'Personalizar',
                        ),
                        avatar: const Icon(Icons.add_rounded, size: 16),
                        onPressed: () async {
                          final custom = await _showReminderSettingsDialog(
                            context,
                            currentMinutes: _minutesBefore,
                            title: 'Recordatorio',
                            subtitle:
                                'Elige cuándo quieres que te avise antes de esta tarea.',
                          );
                          if (custom == null) {
                            return;
                          }
                          setState(() {
                            _reminderEnabled = true;
                            _minutesBefore = custom;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Sincronizar con calendario'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: _softBorderBox(),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded,
                            color: Color(0xFF4A82D9)),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('Google Calendar')),
                        Switch(
                          value: _syncToGoogle,
                          onChanged: controller.isCalendarConnected
                              ? (value) => setState(() => _syncToGoogle = value)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }
    final scheduledAt =
        DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final recurrence = RecurrenceRule(
      type: _recurrenceType,
      interval:
          _recurrenceType == RecurrenceType.none ? 1 : _recurrenceInterval,
    );
    final reminderRule = ReminderRule(
      enabled: _reminderEnabled,
      minutesBefore: _minutesBefore,
      triggerMode: ReminderTriggerMode.minutesBefore,
    );
    final categoryIds = _effectiveTaskCategoryIds();
    final checklist =
        _subtasks.where((item) => item.trim().isNotEmpty).toList();

    if (widget.initialTask == null) {
      final task = controller.createTask(
        title: title,
        description: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        categoryIds: categoryIds,
        projectIds:
            _projectId == null ? const <String>[] : <String>[_projectId!],
        scheduledAt: scheduledAt,
        priority: _priority,
        recurrence: recurrence,
        parentTaskId: widget.parentTaskId,
        reminderRule: _reminderEnabled ? reminderRule : null,
      );
      if (checklist.isNotEmpty) {
        controller.updateTask(task.copyWith(checklist: checklist));
      }
      if (_syncToGoogle && controller.isCalendarConnected) {
        await controller.syncTaskToCalendar(task.id);
      }
    } else {
      final updated = widget.initialTask!.copyWith(
        title: title,
        description: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        categoryIds: categoryIds,
        projectIds:
            _projectId == null ? const <String>[] : <String>[_projectId!],
        scheduledAt: scheduledAt,
        priority: _priority,
        recurrence: recurrence,
        checklist: checklist,
        reminderRule: _reminderEnabled ? reminderRule : null,
        clearReminderRule: !_reminderEnabled,
      );
      controller.updateTask(updated);
      if (_syncToGoogle && controller.isCalendarConnected) {
        await controller.syncTaskToCalendar(updated.id);
      } else if (!_syncToGoogle && widget.initialTask!.calendarLink != null) {
        controller.unlinkTaskFromCalendarEvent(updated.id);
      }
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveTaskAndReset() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }
    await _saveTask();
  }

  void _ensureSeedCategory() {
    if (controller.categories.isEmpty) {
      controller.createCategory(
        name: 'Test',
        colorValue: const Color(0xFF8FB6EF).toARGB32(),
        icon: Icons.label_rounded,
      );
    }
  }

  List<String> _effectiveTaskCategoryIds() {
    final cleaned =
        _categoryIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (cleaned.isNotEmpty) {
      return cleaned;
    }
    final existing = controller.categories
        .where((item) => item.name.toLowerCase() == 'otros')
        .toList();
    if (existing.isNotEmpty) {
      return <String>[existing.first.id];
    }
    final created = controller.createCategory(
      name: 'Otros',
      colorValue: const Color(0xFFD8D2CC).toARGB32(),
      icon: Icons.label_outline_rounded,
    );
    return <String>[created.id];
  }

  String _recurrenceLabel() {
    return _recurrenceLabelFor(
        _recurrenceType, _date, _time, _recurrenceInterval);
  }

  String _reminderPresetLabel(int minutes) {
    return _reminderPresetLabelGlobal(minutes);
  }
}
