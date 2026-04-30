part of 'app_shell.dart';

enum _InboxConversionTarget { task, project, event }

class InboxPage extends StatefulWidget {
  const InboxPage({required this.controller, super.key});

  final TodoWorkspace controller;

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  late final TextEditingController _searchController;
  _InboxConversionTarget _target = _InboxConversionTarget.task;
  String _query = '';
  String? _selectedNoteId;
  DateTime? _selectedDate;

  TodoWorkspace get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notes = controller.inboxNotes();
    final filteredNotes = notes.where((note) {
      if (_query.trim().isEmpty) {
        return true;
      }
      return note.content.toLowerCase().contains(_query.trim().toLowerCase());
    }).toList();
    final selected = _selectedNote(
      filteredNotes: filteredNotes,
      allNotes: notes,
    );
    final wide = MediaQuery.sizeOf(context).width >= 1180;
    final notesWithDate =
        notes.where((note) => note.scheduledFor != null).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageHeader(
            title: 'Inbox',
            subtitle: 'Aqui llegan las notas rapidas para revisarlas despues.',
            trailing: wide
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HeaderActionButton(
                        label: 'Nueva nota',
                        icon: Icons.add_rounded,
                        onPressed: () =>
                            showQuickNoteComposer(context, controller),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 320,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _query = value;
                            });
                          },
                          decoration: const InputDecoration(
                            hintText: 'Buscar una nota...',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeaderActionButton(
                        label: 'Nueva nota',
                        icon: Icons.add_rounded,
                        onPressed: () =>
                            showQuickNoteComposer(context, controller),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _query = value;
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'Buscar una nota...',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _InboxNotesCard(
                          notes: filteredNotes,
                          selectedNoteId: selected?.id,
                          onSelect: (note) {
                            setState(() {
                              _selectedNoteId = note.id;
                              _selectedDate = note.scheduledFor;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 18),
                      SizedBox(
                        width: 360,
                        child: Column(
                          children: [
                            _InboxStatsCard(
                              pendingCount: notes.length,
                              withDateCount: notesWithDate,
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: _InboxProcessCard(
                                controller: controller,
                                selectedNote: selected,
                                target: _target,
                                selectedDate: _resolvedSelectedDate(selected),
                                onTargetChanged: (value) {
                                  setState(() {
                                    _target = value;
                                  });
                                },
                                onDatePressed:
                                    selected == null ? null : _pickDate,
                                onOpenForm: selected == null
                                    ? null
                                    : () => _processSelectedNote(selected),
                                onArchive: selected == null
                                    ? null
                                    : () {
                                        controller.archiveNote(selected.id);
                                        setState(() {
                                          _selectedNoteId = null;
                                          _selectedDate = null;
                                        });
                                      },
                                onEdit: selected == null
                                    ? null
                                    : () async {
                                        await showQuickNoteComposer(
                                          context,
                                          controller,
                                          initialNote: selected,
                                        );
                                        if (!mounted) {
                                          return;
                                        }
                                        setState(() {});
                                      },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView(
                    children: [
                      _InboxStatsCard(
                        pendingCount: notes.length,
                        withDateCount: notesWithDate,
                      ),
                      const SizedBox(height: 16),
                      _InboxProcessCard(
                        controller: controller,
                        selectedNote: selected,
                        target: _target,
                        selectedDate: _resolvedSelectedDate(selected),
                        onTargetChanged: (value) {
                          setState(() {
                            _target = value;
                          });
                        },
                        onDatePressed: selected == null ? null : _pickDate,
                        onOpenForm: selected == null
                            ? null
                            : () => _processSelectedNote(selected),
                        onArchive: selected == null
                            ? null
                            : () {
                                controller.archiveNote(selected.id);
                                setState(() {
                                  _selectedNoteId = null;
                                  _selectedDate = null;
                                });
                              },
                        onEdit: selected == null
                            ? null
                            : () async {
                                await showQuickNoteComposer(
                                  context,
                                  controller,
                                  initialNote: selected,
                                );
                                if (!mounted) {
                                  return;
                                }
                                setState(() {});
                              },
                      ),
                      const SizedBox(height: 16),
                      _InboxNotesCard(
                        notes: filteredNotes,
                        selectedNoteId: selected?.id,
                        onSelect: (note) {
                          setState(() {
                            _selectedNoteId = note.id;
                            _selectedDate = note.scheduledFor;
                          });
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  QuickNote? _selectedNote({
    required List<QuickNote> filteredNotes,
    required List<QuickNote> allNotes,
  }) {
    final selected =
        _selectedNoteId == null ? null : controller.noteById(_selectedNoteId!);
    if (selected != null &&
        selected.status == NoteStatus.inbox &&
        filteredNotes.any((note) => note.id == selected.id)) {
      return selected;
    }
    if (filteredNotes.isNotEmpty) {
      return filteredNotes.first;
    }
    if (_query.trim().isEmpty && allNotes.isNotEmpty) {
      return allNotes.first;
    }
    return null;
  }

  DateTime? _resolvedSelectedDate(QuickNote? note) {
    return _selectedDate ?? note?.scheduledFor;
  }

  Future<void> _pickDate() async {
    final base =
        _resolvedSelectedDate(controller.noteById(_selectedNoteId ?? '')) ??
            controller.logicalDate();
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: base.subtract(const Duration(days: 365)),
      lastDate: base.add(const Duration(days: 3650)),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day, 10);
    });
  }

  Future<void> _processSelectedNote(QuickNote note) async {
    switch (_target) {
      case _InboxConversionTarget.task:
        final task = controller.convertNoteToTask(
          note.id,
          scheduledAt: _resolvedSelectedDate(note),
        );
        setState(() {
          _selectedNoteId = null;
          _selectedDate = null;
        });
        await showTaskEditor(context, controller, initialTask: task);
        return;
      case _InboxConversionTarget.project:
        final project = controller.convertNoteToProject(note.id);
        setState(() {
          _selectedNoteId = null;
          _selectedDate = null;
        });
        await showProjectEditor(context, controller, initialProject: project);
        return;
      case _InboxConversionTarget.event:
        controller.convertNoteToCalendarEvent(
          note.id,
          startAt: _resolvedSelectedDate(note),
        );
        controller.setSection(AppSection.calendar);
        setState(() {
          _selectedNoteId = null;
          _selectedDate = null;
        });
        return;
    }
  }
}

class _InboxNotesCard extends StatelessWidget {
  const _InboxNotesCard({
    required this.notes,
    required this.selectedNoteId,
    required this.onSelect,
  });

  final List<QuickNote> notes;
  final String? selectedNoteId;
  final ValueChanged<QuickNote> onSelect;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${notes.length} notas pendientes',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: 20,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: notes.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No hay notas pendientes en este momento.',
                        style: TextStyle(color: visuals.textMuted),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: notes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      final selected = selectedNoteId == note.id;
                      return InkWell(
                        onTap: () => onSelect(note),
                        child: Container(
                          color: selected
                              ? const Color(0xFFEEF3E7).withValues(alpha: 0.9)
                              : Colors.transparent,
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selected
                                        ? const Color(0xFF607A5A)
                                        : const Color(0xFFD7CCBC),
                                    width: 1.4,
                                  ),
                                ),
                                child: selected
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                        color: Color(0xFF607A5A),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  _notePreviewLine(note),
                                  style: TextStyle(
                                    color: visuals.textStrong,
                                    fontSize: 17,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatInboxCreatedAt(note.createdAt),
                                    style: TextStyle(color: visuals.textMuted),
                                  ),
                                  if (note.scheduledFor != null) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFFE3D7C8),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.calendar_today_outlined,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(_formatInboxDate(
                                              note.scheduledFor!)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE8DCCD))),
            ),
            child: Text(
              selectedNoteId == null ? '0 seleccionadas' : '1 seleccionada',
              style: TextStyle(color: visuals.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxStatsCard extends StatelessWidget {
  const _InboxStatsCard({
    required this.pendingCount,
    required this.withDateCount,
  });

  final int pendingCount;
  final int withDateCount;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        children: [
          Expanded(
            child: _InboxMiniStat(
              icon: Icons.inventory_2_outlined,
              tone: const Color(0xFFE58E1C),
              value: pendingCount.toString(),
              label: 'pendientes',
            ),
          ),
          Container(width: 1, height: 92, color: const Color(0xFFE8DCCD)),
          Expanded(
            child: _InboxMiniStat(
              icon: Icons.calendar_month_outlined,
              tone: const Color(0xFF607A5A),
              value: withDateCount.toString(),
              label: 'con fecha',
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxMiniStat extends StatelessWidget {
  const _InboxMiniStat({
    required this.icon,
    required this.tone,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color tone;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Icon(icon, color: tone, size: 24),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .displaySmall
                ?.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}

class _InboxProcessCard extends StatelessWidget {
  const _InboxProcessCard({
    required this.controller,
    required this.selectedNote,
    required this.target,
    required this.selectedDate,
    required this.onTargetChanged,
    required this.onDatePressed,
    required this.onOpenForm,
    required this.onArchive,
    required this.onEdit,
  });

  final TodoWorkspace controller;
  final QuickNote? selectedNote;
  final _InboxConversionTarget target;
  final DateTime? selectedDate;
  final ValueChanged<_InboxConversionTarget> onTargetChanged;
  final VoidCallback? onDatePressed;
  final VoidCallback? onOpenForm;
  final VoidCallback? onArchive;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Procesar nota',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 14),
          if (selectedNote == null)
            Expanded(
              child: Center(
                child: Text(
                  'Selecciona una nota para convertirla con calma.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: visuals.textMuted, height: 1.45),
                ),
              ),
            )
          else
            Expanded(
              child: ScrollConfiguration(
                behavior:
                    const MaterialScrollBehavior().copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Vista previa',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Editar nota',
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE7DACA)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _notePreviewLine(selectedNote!),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: visuals.textStrong,
                                fontSize: 16,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatInboxCreatedAt(selectedNote!.createdAt),
                              style: TextStyle(color: visuals.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Convertir en',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _InboxTargetButton(
                              label: 'Tarea',
                              icon: Icons.task_alt_rounded,
                              selected: target == _InboxConversionTarget.task,
                              onTap: () =>
                                  onTargetChanged(_InboxConversionTarget.task),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _InboxTargetButton(
                              label: 'Proyecto',
                              icon: Icons.folder_open_rounded,
                              selected:
                                  target == _InboxConversionTarget.project,
                              onTap: () => onTargetChanged(
                                  _InboxConversionTarget.project),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _InboxTargetButton(
                              label: 'Evento',
                              icon: Icons.calendar_month_rounded,
                              selected: target == _InboxConversionTarget.event,
                              onTap: () =>
                                  onTargetChanged(_InboxConversionTarget.event),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Fecha opcional',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: onDatePressed,
                          icon: const Icon(Icons.calendar_today_outlined,
                              size: 18),
                          label: Text(
                            selectedDate == null
                                ? 'Elegir fecha'
                                : _formatInboxDate(selectedDate!),
                          ),
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: onOpenForm,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF243C24),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            target == _InboxConversionTarget.event
                                ? 'Crear evento'
                                : 'Abrir formulario',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          onPressed: onArchive,
                          icon: const Icon(Icons.inventory_2_outlined),
                          label: const Text('Archivar nota'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InboxTargetButton extends StatelessWidget {
  const _InboxTargetButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 78,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF607A5A) : const Color(0xFFE5D8C7),
            width: selected ? 1.5 : 1,
          ),
          color: selected ? const Color(0xFFF0F5EA) : Colors.transparent,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color:
                  selected ? const Color(0xFF607A5A) : const Color(0xFF3C433C),
            ),
            const SizedBox(height: 6),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

String _notePreviewLine(QuickNote note) {
  final collapsed = note.content
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .join(' ');
  return collapsed.isEmpty ? 'Nota vacia' : collapsed;
}

String _formatInboxCreatedAt(DateTime value) {
  final now = DateTime.now();
  if (_sameDay(value, now)) {
    return 'Hoy, ${_timeLabel(value)}';
  }
  if (_sameDay(value, now.subtract(const Duration(days: 1)))) {
    return 'Ayer, ${_timeLabel(value)}';
  }
  return '${_weekdayShort(value)} ${value.day} ${_monthShortInbox(value.month)}';
}

String _formatInboxDate(DateTime value) {
  return '${_weekdayShort(value)} ${value.day} ${_monthShortInbox(value.month)}';
}

String _monthShortInbox(int month) {
  const names = <String>[
    '',
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return names[month];
}
