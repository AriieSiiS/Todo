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
  static const List<int> _quickReminderMinutes = <int>[0, 5, 15, 30, 60, 1440];

  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final List<String> _subtasks;
  late DateTime _date;
  late TimeOfDay _time;
  late TaskPriority _priority;
  late RecurrenceType _recurrenceType;
  late int _recurrenceInterval;
  late final TextEditingController _recurrenceIntervalController;
  String? _recurrenceIntervalError;
  late String? _projectId;
  late List<String> _categoryIds;
  late Map<int, ReminderDeliveryMode> _reminderModes;
  late bool _reminderSelectionMade;
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
    final linkedSubtasks =
        initial == null ? const <TaskModel>[] : controller.subtasksOf(initial);
    _subtasks = linkedSubtasks.isNotEmpty
        ? linkedSubtasks.map((task) => task.title).toList()
        : [...(initial?.checklist ?? const <String>[])];
    _date = DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);
    _time = TimeOfDay(hour: scheduledAt.hour, minute: scheduledAt.minute);
    _priority = initial?.priority ?? TaskPriority.medium;
    _recurrenceType = initial?.recurrence.type ?? RecurrenceType.none;
    _recurrenceInterval = initial?.recurrence.interval ?? 1;
    if (_recurrenceType == RecurrenceType.everyXDays &&
        _recurrenceInterval < 2) {
      _recurrenceInterval = 2;
    }
    _recurrenceIntervalController = TextEditingController(
      text: _recurrenceInterval.toString(),
    );
    _projectId = initial?.projectIds.isNotEmpty == true
        ? initial!.projectIds.first
        : null;
    _categoryIds = [...(initial?.categoryIds ?? const <String>[])];
    _reminderModes = <int, ReminderDeliveryMode>{
      for (final rule in (initial?.reminderRules ?? const <ReminderRule>[])
          .where((rule) => rule.enabled))
        rule.minutesBefore: rule.deliveryMode,
    };
    _reminderSelectionMade = initial?.reminderRules.isNotEmpty ?? false;
    _syncToGoogle = initial?.calendarLink != null;
    _estimatedDurationMinutes = 30;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _recurrenceIntervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        controller.categories.where((item) => item.active).toList();
    final projects = controller.projects
        .where((item) => item.status == ProjectStatus.active)
        .toList();
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.fromLTRB(
          32, 22, 32, MediaQuery.of(context).viewInsets.bottom + 22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF8),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFFE2D5C4),
            width: 1,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980, maxHeight: 920),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            child: Column(
              children: [
                _dialogHeader(
                  context,
                  title: widget.initialTask == null
                      ? 'Nueva tarea'
                      : 'Editar tarea',
                  subtitle: 'Añade solo la información que necesites.',
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ScrollConfiguration(
                    behavior: const MaterialScrollBehavior()
                        .copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      child: _buildTaskForm(context, categories, projects),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saveTask,
                        child: Text(widget.initialTask == null
                            ? 'Guardar tarea'
                            : 'Guardar cambios'),
                      ),
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
          minLines: 1,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Limpiar baño'),
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
                    setState(() {
                      _time = picked;
                      if (!_hasVisibleTimeOfDay(picked)) {
                        _reminderModes.clear();
                        _reminderSelectionMade = true;
                      } else if (!_reminderSelectionMade) {
                        _reminderModes[0] = ReminderDeliveryMode.normal;
                      }
                    });
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
                  _sectionLabel('Duración estimada (opcional)'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
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
        _sectionLabel('Repetición'),
        const SizedBox(height: 6),
        DropdownButtonFormField<RecurrenceType>(
          initialValue: _recurrenceType,
          style: fieldTextStyle.copyWith(color: const Color(0xFF2D2A25)),
          items: const [
            DropdownMenuItem(
                value: RecurrenceType.none,
                child: Text('Sin repetición', style: fieldTextStyle)),
            DropdownMenuItem(
                value: RecurrenceType.daily,
                child: Text('Diaria', style: fieldTextStyle)),
            DropdownMenuItem(
                value: RecurrenceType.weekly,
                child: Text('Semanal', style: fieldTextStyle)),
            DropdownMenuItem(
                value: RecurrenceType.everyXDays,
                child: Text('Cada X días', style: fieldTextStyle)),
            DropdownMenuItem(
                value: RecurrenceType.yearly,
                child: Text('Anual', style: fieldTextStyle)),
          ],
          onChanged: (value) => setState(() {
            _recurrenceType = value ?? _recurrenceType;
            if (_recurrenceType == RecurrenceType.everyXDays &&
                _recurrenceInterval < 2) {
              _recurrenceInterval = 2;
              _recurrenceIntervalController.text = '2';
            }
            _recurrenceIntervalError = null;
          }),
          decoration:
              const InputDecoration(prefixIcon: Icon(Icons.autorenew_rounded)),
        ),
        if (_recurrenceType == RecurrenceType.everyXDays) ...[
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('recurrence-interval-input'),
            controller: _recurrenceIntervalController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Número de días',
              prefixText: 'Cada ',
              suffixText: ' días',
              helperText: 'La tarea se repetirá con este intervalo.',
              errorText: _recurrenceIntervalError,
              prefixIcon: const Icon(Icons.event_repeat_rounded),
            ),
            onChanged: (value) {
              final parsed = int.tryParse(value.trim());
              setState(() {
                if (parsed != null && parsed >= 2) {
                  _recurrenceInterval = parsed;
                  _recurrenceIntervalError = null;
                } else {
                  _recurrenceIntervalError =
                      'Introduce un número de días igual o superior a 2.';
                }
              });
            },
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            _sectionLabel('Subtareas'),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () => setState(() => _subtasks.add('')),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Añadir subtarea'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_subtasks.isNotEmpty)
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
                                key: ValueKey('subtask-input-$index'),
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
                        selected: _reminderModes.isEmpty,
                        label: const Text('Sin aviso'),
                        onSelected: (_) => setState(() {
                          _reminderModes.clear();
                          _reminderSelectionMade = true;
                        }),
                      ),
                      for (final minutes in _quickReminderMinutes)
                        FilterChip(
                          selected: _reminderModes.containsKey(minutes),
                          label: Text(_reminderPresetLabelGlobal(minutes)),
                          avatar: const Icon(Icons.notifications_none_rounded,
                              size: 16),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _reminderModes[minutes] =
                                  ReminderDeliveryMode.normal;
                            } else {
                              _reminderModes.remove(minutes);
                            }
                            _reminderSelectionMade = true;
                          }),
                        ),
                      ActionChip(
                        label: const Text('Personalizar'),
                        avatar: const Icon(Icons.add_rounded, size: 16),
                        onPressed: () async {
                          final custom = await _showReminderSettingsDialog(
                            context,
                            currentMinutes: _reminderModes.isEmpty
                                ? controller.notificationSettings
                                    .defaultMinutesBeforeTask
                                : _reminderModes.keys.last,
                            title: 'Recordatorio',
                            subtitle:
                                'Elige cuándo quieres que te avise antes de esta tarea.',
                          );
                          if (custom == null) {
                            return;
                          }
                          setState(() {
                            _reminderModes.putIfAbsent(
                              custom,
                              () => ReminderDeliveryMode.normal,
                            );
                            _reminderSelectionMade = true;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        _reminderModes.isNotEmpty
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                        size: 17,
                        color: Theme.of(context)
                            .extension<TodoVisuals>()!
                            .textMuted,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          _reminderModes.isEmpty
                              ? 'Avisos activos: ninguno'
                              : 'Avisos activos (${_reminderModes.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_reminderModes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Column(
                      children: [
                        for (final minutes in _sortedReminderMinutes())
                          Container(
                            key: ValueKey<String>('active-reminder-$minutes'),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.fromLTRB(12, 7, 5, 7),
                            decoration: _softBorderBox(),
                            child: Row(
                              children: [
                                Icon(
                                  _reminderModes[minutes] ==
                                          ReminderDeliveryMode.important
                                      ? Icons.notification_important_rounded
                                      : Icons.notifications_active_outlined,
                                  size: 19,
                                  color: _reminderModes[minutes] ==
                                          ReminderDeliveryMode.important
                                      ? const Color(0xFFB05C22)
                                      : const Color(0xFF70835D),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    _activeReminderLabel(minutes),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Text(
                                  'Importante',
                                  style: TextStyle(fontSize: 12),
                                ),
                                Switch(
                                  key: ValueKey<String>(
                                    'important-reminder-$minutes',
                                  ),
                                  value: _reminderModes[minutes] ==
                                      ReminderDeliveryMode.important,
                                  onChanged: (important) => setState(() {
                                    _reminderModes[minutes] = important
                                        ? ReminderDeliveryMode.important
                                        : ReminderDeliveryMode.normal;
                                    _reminderSelectionMade = true;
                                  }),
                                ),
                                IconButton(
                                  tooltip: 'Quitar este aviso',
                                  onPressed: () => setState(() {
                                    _reminderModes.remove(minutes);
                                    _reminderSelectionMade = true;
                                  }),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
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
    if (_recurrenceType == RecurrenceType.everyXDays) {
      final interval = int.tryParse(_recurrenceIntervalController.text.trim());
      if (interval == null || interval < 2) {
        setState(() {
          _recurrenceIntervalError =
              'Introduce un número de días igual o superior a 2.';
        });
        return;
      }
      _recurrenceInterval = interval;
    }
    final scheduledAt =
        DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final recurrence = RecurrenceRule(
      type: _recurrenceType,
      interval:
          _recurrenceType == RecurrenceType.none ? 1 : _recurrenceInterval,
    );
    final reminderRules = _sortedReminderMinutes()
        .map(
          (minutes) => ReminderRule(
            enabled: true,
            minutesBefore: minutes,
            triggerMode: ReminderTriggerMode.minutesBefore,
            deliveryMode: _reminderModes[minutes]!,
          ),
        )
        .toList();
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
        reminderRules: reminderRules,
      );
      controller.replaceTaskSubtasks(task.id, checklist);
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
        checklist: const <String>[],
        reminderRules: reminderRules,
      );
      controller.updateTask(updated);
      controller.replaceTaskSubtasks(updated.id, checklist);
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

  List<int> _sortedReminderMinutes() {
    final values = _reminderModes.keys.toList()..sort();
    return values;
  }

  String _activeReminderLabel(int minutes) {
    final scheduledAt =
        DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final reminderAt = scheduledAt.subtract(Duration(minutes: minutes));
    return '${_reminderPresetLabelGlobal(minutes)} · ${_dateLabel(reminderAt)} a las '
        '${_formatTime24(TimeOfDay.fromDateTime(reminderAt))}';
  }
}
