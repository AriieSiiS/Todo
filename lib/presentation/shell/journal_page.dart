part of 'app_shell.dart';

const List<IconData> _iconosAnimo = <IconData>[
  Icons.sentiment_very_dissatisfied_rounded,
  Icons.sentiment_dissatisfied_rounded,
  Icons.sentiment_neutral_rounded,
  Icons.sentiment_satisfied_rounded,
  Icons.sentiment_very_satisfied_rounded,
];

const List<String> _etiquetasAnimo = <String>[
  'Muy bajo',
  'Bajo',
  'Normal',
  'Bien',
  'Muy bien',
];

const List<Color> _coloresAnimo = <Color>[
  Color(0xFFB85C5C),
  Color(0xFFD08A5A),
  Color(0xFFB8A25A),
  Color(0xFF8DAA7F),
  Color(0xFF4F8F6B),
];

class JournalPage extends StatelessWidget {
  const JournalPage({required this.controller, super.key});

  final TodoWorkspace controller;

  @override
  Widget build(BuildContext context) {
    final entries = controller.journalEntries.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final today = controller.logicalDate();
    final todayEntry = controller.journalEntryForDate(today);
    final memories = controller.journalOnThisDay(today);
    final grouped = <String, List<JournalEntry>>{};
    for (final entry in entries) {
      grouped.putIfAbsent(_mesYAnio(entry.date), () => []).add(entry);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: _PageHeader(
              title: 'Diario',
              subtitle: '',
              compact: true,
              pinTrailingToEdge: true,
              trailing: _HeaderActionButton(
                key: const ValueKey('journal-write-today'),
                label: todayEntry == null ? 'Escribir hoy' : 'Editar hoy',
                icon: todayEntry == null
                    ? Icons.edit_rounded
                    : Icons.edit_note_rounded,
                onPressed: () => showJournalEditor(context, controller, today),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: entries.isEmpty
                ? const _JournalEmpty()
                : ListView(
                    children: [
                      if (memories.isNotEmpty) ...[
                        _JournalMemories(
                          controller: controller,
                          memories: memories,
                        ),
                        const SizedBox(height: 16),
                      ],
                      _JournalMoodStrip(controller: controller, today: today),
                      const SizedBox(height: 18),
                      for (final month in grouped.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10, top: 4),
                          child: Text(
                            _capitalizar(month.key),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        for (final entry in month.value) ...[
                          _JournalEntryCard(
                            controller: controller,
                            entry: entry,
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _JournalEmpty extends StatelessWidget {
  const _JournalEmpty();

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_stories_rounded, size: 46, color: visuals.textMuted),
          const SizedBox(height: 12),
          Text(
            'Todavía no hay entradas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Escribe unas líneas sobre hoy, con tu ánimo y una foto si quieres.',
            style: TextStyle(color: visuals.textMuted),
          ),
        ],
      ),
    );
  }
}

class _JournalMemories extends StatelessWidget {
  const _JournalMemories({required this.controller, required this.memories});

  final TodoWorkspace controller;
  final List<JournalEntry> memories;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, color: visuals.accent),
              const SizedBox(width: 8),
              Text('Hace tiempo, un día como hoy',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          for (final memory in memories)
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => showJournalEditor(context, controller, memory.date),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        '${memory.date.year}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: visuals.accent,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        memory.text.isEmpty ? 'Sin texto' : memory.text,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
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

/// Últimos 14 días con el ánimo de cada uno.
class _JournalMoodStrip extends StatelessWidget {
  const _JournalMoodStrip({required this.controller, required this.today});

  final TodoWorkspace controller;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final days = List<DateTime>.generate(
      14,
      (index) => DateTime(today.year, today.month, today.day - (13 - index)),
    );
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ánimo de las últimas dos semanas',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final day in days)
                Expanded(
                  child: Builder(builder: (context) {
                    final mood = controller.journalEntryForDate(day)?.mood ?? 0;
                    return Tooltip(
                      message: mood == 0
                          ? '${_fechaConDia(day)}: sin indicar'
                          : '${_fechaConDia(day)}: ${_etiquetasAnimo[mood - 1]}',
                      child: Container(
                        key: ValueKey('mood-day-${day.day}-${day.month}'),
                        height: 8.0 + (mood == 0 ? 0 : mood * 7),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: mood == 0
                              ? visuals.panelBorder
                              : _coloresAnimo[mood - 1],
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    );
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JournalEntryCard extends StatelessWidget {
  const _JournalEntryCard({required this.controller, required this.entry});

  final TodoWorkspace controller;
  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return Material(
      color: visuals.panel,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showJournalEditor(context, controller, entry.date),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 64,
                child: Column(
                  children: [
                    Text(
                      '${entry.date.day}',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      _diasCompletos[entry.date.weekday - 1]
                          .substring(0, 3)
                          .toUpperCase(),
                      style: TextStyle(color: visuals.textMuted, fontSize: 12),
                    ),
                    if (entry.mood > 0) ...[
                      const SizedBox(height: 6),
                      Icon(
                        _iconosAnimo[entry.mood - 1],
                        color: _coloresAnimo[entry.mood - 1],
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  entry.text.isEmpty ? 'Sin texto' : entry.text,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: entry.text.isEmpty ? visuals.textMuted : null,
                    height: 1.35,
                  ),
                ),
              ),
              if (entry.hasImage) ...[
                const SizedBox(width: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: FutureBuilder<String>(
                      future: controller.journalImageAbsolutePath(entry),
                      builder: (context, snapshot) {
                        final path = snapshot.data ?? '';
                        if (path.isEmpty) return const SizedBox.shrink();
                        return Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          cacheWidth: 240,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink(),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showJournalEditor(
  BuildContext context,
  TodoWorkspace controller,
  DateTime date,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => _JournalEditorDialog(
      controller: controller,
      date: date,
    ),
  );
}

class _JournalEditorDialog extends StatefulWidget {
  const _JournalEditorDialog({required this.controller, required this.date});

  final TodoWorkspace controller;
  final DateTime date;

  @override
  State<_JournalEditorDialog> createState() => _JournalEditorDialogState();
}

class _JournalEditorDialogState extends State<_JournalEditorDialog> {
  late DateTime _date;
  late final TextEditingController _text;
  int _mood = 0;
  XFile? _newImage;
  bool _removeImage = false;
  bool _saving = false;
  String? _error;

  TodoWorkspace get controller => widget.controller;

  JournalEntry? get _existing => controller.journalEntryForDate(_date);

  @override
  void initState() {
    super.initState();
    _date = DateTime(widget.date.year, widget.date.month, widget.date.day);
    final existing = _existing;
    _text = TextEditingController(text: existing?.text ?? '');
    _mood = existing?.mood ?? 0;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _cambiarFecha(DateTime nueva) {
    final day = DateTime(nueva.year, nueva.month, nueva.day);
    final existing = controller.journalEntryForDate(day);
    setState(() {
      _date = day;
      _text.text = existing?.text ?? '';
      _mood = existing?.mood ?? 0;
      _newImage = null;
      _removeImage = false;
    });
  }

  Future<void> _elegirFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) _cambiarFecha(picked);
  }

  Future<void> _elegirImagen() async {
    final selected = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Imágenes',
          extensions: ['png', 'jpg', 'jpeg', 'webp'],
        ),
      ],
    );
    if (selected != null && mounted) {
      setState(() {
        _newImage = selected;
        _removeImage = false;
      });
    }
  }

  Future<void> _guardar() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final entry = controller.saveJournalEntry(
        date: _date,
        text: _text.text,
        mood: _mood,
      );
      if (_removeImage && _newImage == null) {
        await controller.removeJournalImage(entry.id);
      }
      final image = _newImage;
      if (image != null) {
        await controller.importJournalImage(entry.id, image.path);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No se pudo guardar la foto: $error';
        });
      }
    }
  }

  Future<void> _eliminar() async {
    final existing = _existing;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar entrada'),
        content: Text('Se borrará la entrada del ${_fechaLarga(_date)}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      controller.deleteJournalEntry(existing.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final existing = _existing;
    final showStoredImage =
        existing != null && existing.hasImage && !_removeImage;
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(_capitalizar(_fechaConDia(_date)))),
          IconButton(
            key: const ValueKey('journal-pick-date'),
            tooltip: 'Cambiar de día',
            onPressed: _elegirFecha,
            icon: const Icon(Icons.calendar_month_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (var i = 0; i < _iconosAnimo.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Tooltip(
                        message: _etiquetasAnimo[i],
                        child: IconButton.filledTonal(
                          key: ValueKey('journal-mood-${i + 1}'),
                          isSelected: _mood == i + 1,
                          onPressed: () =>
                              setState(() => _mood = _mood == i + 1 ? 0 : i + 1),
                          style: IconButton.styleFrom(
                            backgroundColor: _mood == i + 1
                                ? _coloresAnimo[i].withValues(alpha: 0.28)
                                : null,
                          ),
                          icon: Icon(
                            _iconosAnimo[i],
                            color: _coloresAnimo[i],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('journal-text'),
                controller: _text,
                autofocus: true,
                minLines: 6,
                maxLines: 12,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: '¿Cómo ha ido el día?',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              if (_newImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(_newImage!.path),
                    height: 160,
                    fit: BoxFit.cover,
                    cacheWidth: 600,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                )
              else if (showStoredImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: FutureBuilder<String>(
                      future: controller.journalImageAbsolutePath(
                        existing,
                        thumbnail: false,
                      ),
                      builder: (context, snapshot) {
                        final path = snapshot.data ?? '';
                        if (path.isEmpty) return const SizedBox.shrink();
                        return Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          cacheWidth: 600,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink(),
                        );
                      },
                    ),
                  ),
                ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _elegirImagen,
                    icon: const Icon(Icons.add_photo_alternate_rounded),
                    label: Text(
                      _newImage != null || showStoredImage
                          ? 'Cambiar foto'
                          : 'Añadir foto',
                    ),
                  ),
                  if (_newImage != null || showStoredImage)
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _newImage = null;
                        _removeImage = true;
                      }),
                      icon: const Icon(Icons.hide_image_outlined),
                      label: const Text('Quitar foto'),
                    ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_error!, style: TextStyle(color: visuals.danger)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (existing != null)
          TextButton(
            onPressed: _saving ? null : _eliminar,
            child: Text('Eliminar', style: TextStyle(color: visuals.danger)),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('journal-save'),
          onPressed: _saving ? null : _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
