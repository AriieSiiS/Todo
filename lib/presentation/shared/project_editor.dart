part of 'editors.dart';

class _ProjectEditorDialog extends StatefulWidget {
  const _ProjectEditorDialog({
    required this.controller,
    this.initialProject,
    this.initialName,
    this.initialDescription,
  });

  final TodoWorkspace controller;
  final ProjectModel? initialProject;
  final String? initialName;
  final String? initialDescription;

  @override
  State<_ProjectEditorDialog> createState() => _ProjectEditorDialogState();
}

class _ProjectEditorDialogState extends State<_ProjectEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _notesController;
  late final TextEditingController _customColorController;
  late int _colorValue;
  late IconData _icon;
  late ProjectStatus _status;
  late TaskPriority _priority;
  late DateTime _targetDate;
  late List<String> _categoryIds;
  late List<_DraftProjectTask> _draftTasks;
  late int _reminderMinutes;
  late bool _syncToGoogle;

  TodoWorkspace get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.initialProject?.name ?? widget.initialName ?? '');
    _descriptionController =
        TextEditingController(
            text: widget.initialProject?.description ??
                widget.initialDescription ??
                '');
    _notesController = TextEditingController();
    _colorValue =
        widget.initialProject?.colorValue ?? const Color(0xFFF2A67A).toARGB32();
    _customColorController =
        TextEditingController(text: _hexFromColorValue(_colorValue));
    _icon = widget.initialProject?.icon ?? Icons.celebration_rounded;
    _status = widget.initialProject?.status ?? ProjectStatus.active;
    _priority = TaskPriority.medium;
    _targetDate = DateTime.now().add(const Duration(days: 3));
    _categoryIds = [
      ...(widget.initialProject?.categoryIds ?? const <String>[])
    ];
    _draftTasks = <_DraftProjectTask>[];
    _reminderMinutes = 1440;
    _syncToGoogle = false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _customColorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visuals = Theme.of(context).extension<TodoVisuals>()!;
    final categories =
        controller.categories.where((item) => item.active).toList();
    final selectedCategories =
        categories.where((item) => _categoryIds.contains(item.id)).toList();
    final title = _nameController.text.trim().isEmpty
        ? 'Tu proyecto'
        : _nameController.text.trim();
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
          constraints: const BoxConstraints(maxWidth: 1320, maxHeight: 940),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            child: Column(
              children: [
                _dialogHeader(
                  context,
                  title: widget.initialProject == null
                      ? 'Nuevo proyecto'
                      : 'Editar proyecto',
                  subtitle:
                      'Crea un proyecto temporal y organiza sus tareas, fechas y detalles.',
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
                                    child:
                                        _buildProjectForm(context, categories)),
                                const SizedBox(width: 18),
                                SizedBox(
                                    width: 320,
                                    child: _buildProjectAside(
                                        context, selectedCategories, title)),
                              ],
                            )
                          : _buildProjectForm(context, categories),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _dialogFooter(
                  primaryLabel: widget.initialProject == null
                      ? 'Guardar proyecto'
                      : 'Guardar cambios',
                  secondaryLabel: 'Guardar y crear otro',
                  onPrimary: _saveProject,
                  onSecondary: _saveProjectAndReset,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectForm(
      BuildContext context, List<CategoryModel> categories) {
    const fieldTextStyle = TextStyle(fontWeight: FontWeight.w400, fontSize: 15);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Nombre del proyecto'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'Cumpleanos de Ana',
                      suffixText: '${_nameController.text.length}/100',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Estado'),
                  const SizedBox(height: 6),
                  SegmentedButton<ProjectStatus>(
                    segments: const [
                      ButtonSegment(
                          value: ProjectStatus.active, label: Text('Activo')),
                      ButtonSegment(
                          value: ProjectStatus.paused, label: Text('En pausa')),
                      ButtonSegment(
                          value: ProjectStatus.completed,
                          label: Text('Completado')),
                    ],
                    selected: <ProjectStatus>{_status},
                    onSelectionChanged: (selection) =>
                        setState(() => _status = selection.first),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Descripcion'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _descriptionController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Planifica el proyecto, sus detalles y tareas.',
                      suffixText: '${_descriptionController.text.length}/300',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Icono y color'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final icon in const <IconData>[
                        Icons.celebration_rounded,
                        Icons.chair_rounded,
                        Icons.emoji_emotions_outlined,
                        Icons.sports_gymnastics_rounded,
                        Icons.menu_book_rounded,
                      ])
                        InkWell(
                          onTap: () => setState(() => _icon = icon),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _icon == icon
                                    ? const Color(0xFF70835D)
                                    : const Color(0xFFE2D5C4),
                              ),
                            ),
                            child: Icon(icon, color: Color(_colorValue)),
                          ),
                        ),
                      InkWell(
                        onTap: () async {
                          final icon = await _showIconPicker(context);
                          if (icon != null) {
                            setState(() => _icon = icon);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2D5C4)),
                          ),
                          child: const Icon(Icons.more_horiz_rounded,
                              color: Color(0xFF6A665F)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ColorPicker(
                    selected: _colorValue,
                    onSelected: (value) => setState(() {
                      _colorValue = value;
                      _customColorController.text = _hexFromColorValue(value);
                    }),
                  ),
                  const SizedBox(height: 12),
                  _sectionLabel('Color personalizado'),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final color = await _showColorPickerDialog(
                        context,
                        initialColor: _colorValue,
                        title: 'Elegir color',
                        subtitle: 'Escoge un color para este proyecto.',
                      );
                      if (color != null) {
                        setState(() {
                          _colorValue = color;
                          _customColorController.text =
                              _hexFromColorValue(color);
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      decoration: _softBorderBox(),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Color(_colorValue),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.edit_outlined,
                              size: 18, color: Color(0xFF6A665F)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _hexFromColorValue(_colorValue),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w400),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _pickerField(
                context,
                label: 'Fecha objetivo',
                icon: Icons.calendar_today_outlined,
                value: _dateLabel(_targetDate),
                onTap: () async {
                  final picked = await _showTodoDatePicker(
                    context,
                    initialDate: _targetDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    setState(() => _targetDate = picked);
                  }
                },
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Prioridad general'),
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
          ],
        ),
        const SizedBox(height: 18),
        _sectionLabel('Categorias relacionadas'),
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
        Row(
          children: [
            _sectionLabel('Tareas iniciales'),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _draftTasks
                  .add(_DraftProjectTask(title: '', dueDate: _targetDate))),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Añadir tarea'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Arrastra para reordenar · Agrega fecha limite para lo importante.',
          style: TextStyle(
              color: Theme.of(context).extension<TodoVisuals>()!.textMuted,
              fontSize: 13),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: _softBorderBox(),
          child: Column(
            children: [
              if (_draftTasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Sin tareas iniciales todavía.',
                      style: TextStyle(
                          color: Theme.of(context)
                              .extension<TodoVisuals>()!
                              .textMuted),
                    ),
                  ),
                ),
              for (var index = 0; index < _draftTasks.length; index++)
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
                              initialValue: _draftTasks[index].title,
                              decoration: const InputDecoration.collapsed(
                                  hintText: 'Tarea inicial'),
                              onChanged: (value) => _draftTasks[index] =
                                  _draftTasks[index].copyWith(title: value),
                            ),
                          ),
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: () async {
                              final picked = await _showTodoDatePicker(
                                context,
                                initialDate:
                                    _draftTasks[index].dueDate ?? _targetDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setState(() => _draftTasks[index] =
                                    _draftTasks[index]
                                        .copyWith(dueDate: picked));
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFBF7F0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_month_outlined,
                                      size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    _draftTasks[index].dueDate == null
                                        ? 'Sin fecha'
                                        : _shortDate(
                                            _draftTasks[index].dueDate!),
                                    style: fieldTextStyle,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                setState(() => _draftTasks.removeAt(index)),
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Notas'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Presupuesto, ideas o detalles importantes.',
                      suffixText: '${_notesController.text.length}/1000',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            SizedBox(
              width: 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Recordatorios'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final minutes in const <int>[5, 30, 60, 1440])
                        FilterChip(
                          selected: _reminderMinutes == minutes,
                          label: Text(_reminderPresetLabelGlobal(minutes)),
                          avatar: const Icon(Icons.notifications_none_rounded,
                              size: 16),
                          onSelected: (_) =>
                              setState(() => _reminderMinutes = minutes),
                        ),
                      ActionChip(
                        label: Text(
                          const <int>[5, 30, 60, 1440]
                                  .contains(_reminderMinutes)
                              ? 'Personalizar'
                              : _reminderPresetLabelGlobal(_reminderMinutes),
                        ),
                        avatar: const Icon(Icons.add_rounded, size: 16),
                        onPressed: () async {
                          final custom = await _showReminderSettingsDialog(
                            context,
                            currentMinutes: _reminderMinutes,
                            title: 'Recordatorio',
                            subtitle:
                                'Elige cuándo quieres que te avise antes de este proyecto.',
                          );
                          if (custom != null) {
                            setState(() => _reminderMinutes = custom);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
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
                        const Expanded(
                          child: Text(
                            'Google Calendar',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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

  Widget _buildProjectAside(BuildContext context,
      List<CategoryModel> selectedCategories, String title) {
    final visuals = Theme.of(context).extension<TodoVisuals>()!;
    final tasks =
        _draftTasks.where((task) => task.title.trim().isNotEmpty).toList();
    return Column(
      children: [
        _AsideCard(
          title: 'Resumen',
          subtitle: 'Asi se vera tu proyecto.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: _softBorderBox(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_icon, color: Color(_colorValue)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _projectStatusBadge(_status),
                    const SizedBox(height: 14),
                    _summaryLine(
                        Icons.calendar_today_outlined, _dateLabel(_targetDate)),
                    _summaryLine(
                        Icons.flag_outlined, _priorityLabel(_priority)),
                    _summaryLine(Icons.format_list_bulleted_rounded,
                        '${tasks.length} tareas iniciales'),
                    _summaryLine(Icons.event_note_outlined,
                        '${tasks.where((item) => item.dueDate != null).length} con fecha limite'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _AsideCard(
          title: 'Proximas tareas con fecha limite',
          child: Column(
            children: [
              for (final task in tasks.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined,
                          size: 18, color: Color(0xFF6A6A60)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(task.title)),
                      Text(
                        task.dueDate == null
                            ? 'Sin fecha'
                            : _shortDate(task.dueDate!),
                        style: TextStyle(color: visuals.textMuted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (selectedCategories.isNotEmpty) ...[
          const SizedBox(height: 14),
          _AsideCard(
            title: 'Categorias vinculadas',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedCategories
                  .map((category) => _tagChip(category.name,
                      category.color.withValues(alpha: 0.16), category.color))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _saveProject() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    final description = _descriptionController.text.trim();

    if (widget.initialProject == null) {
      final project = controller.createProject(
        name: name,
        description: description,
        colorValue: _colorValue,
        icon: _icon,
        categoryIds: _categoryIds,
      );
      controller.updateProject(project.copyWith(status: _status));
      for (final task
          in _draftTasks.where((item) => item.title.trim().isNotEmpty)) {
        final createdTask = controller.createTask(
          title: task.title.trim(),
          description: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          categoryIds: _categoryIds,
          projectIds: <String>[project.id],
          scheduledAt: task.dueDate == null
              ? null
              : DateTime(task.dueDate!.year, task.dueDate!.month,
                  task.dueDate!.day, 10),
          priority: _priority,
          reminderRule: ReminderRule(
            enabled: true,
            minutesBefore: _reminderMinutes,
            triggerMode: ReminderTriggerMode.minutesBefore,
          ),
        );
        if (_syncToGoogle && controller.isCalendarConnected) {
          await controller.syncTaskToCalendar(createdTask.id);
        }
      }
    } else {
      controller.updateProject(
        widget.initialProject!.copyWith(
          name: name,
          description: description,
          colorValue: _colorValue,
          icon: _icon,
          status: _status,
          categoryIds: _categoryIds,
        ),
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveProjectAndReset() async {
    await _saveProject();
  }
}
