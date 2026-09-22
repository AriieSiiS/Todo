part of 'app_shell.dart';

class PlantsPage extends StatefulWidget {
  const PlantsPage({required this.controller, super.key});

  final TodoWorkspace controller;

  @override
  State<PlantsPage> createState() => _PlantsPageState();
}

class _PlantsPageState extends State<PlantsPage> {
  String _query = '';
  String _location = 'Todas';
  PlantCatSafety? _safety;

  TodoWorkspace get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final active = controller.plants.where((plant) => !plant.archived).toList();
    final locations = active
        .map((plant) => plant.location.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    locations.insert(0, 'Todas');
    final location = locations.contains(_location) ? _location : 'Todas';
    final query = _query.trim().toLowerCase();
    final plants = active.where((plant) {
      if (location != 'Todas' && plant.location != location) return false;
      if (_safety != null && plant.catSafety != _safety) return false;
      if (query.isEmpty) return true;
      return <String>[
        plant.name,
        plant.commonName,
        plant.scientificName,
        plant.cultivar,
        plant.location,
        ...plant.tags,
      ].join(' ').toLowerCase().contains(query);
    }).toList()
      ..sort((left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()));

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: _PageHeader(
              title: 'Plantas',
              subtitle: '',
              compact: true,
              pinTrailingToEdge: true,
              trailing: _HeaderActionButton(
                label: 'Añadir planta',
                icon: Icons.add_rounded,
                onPressed: () => _showPlantEditor(context, controller),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _CatalogSearchField(
            key: const ValueKey('plants-search'),
            label: 'Buscar plantas',
            hint: 'Nombre, especie, ubicación o etiqueta…',
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView(
              key: const ValueKey('plants-filters'),
              scrollDirection: Axis.horizontal,
              children: [
                for (final value in locations) ...[
                  _FilterPill(
                    label: value,
                    selected: location == value && _safety == null,
                    onTap: () => setState(() {
                      _location = value;
                      _safety = null;
                    }),
                  ),
                  const SizedBox(width: 7),
                ],
                for (final safety in PlantCatSafety.values) ...[
                  _FilterPill(
                    label: _plantSafetyLabel(safety),
                    selected: _safety == safety,
                    onTap: () => setState(() {
                      _safety = _safety == safety ? null : safety;
                    }),
                  ),
                  const SizedBox(width: 7),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: plants.isEmpty
                ? _PlantsEmpty(filtered: active.isNotEmpty)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns =
                          max(2, (constraints.maxWidth / 270).floor());
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          childAspectRatio: .75,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: plants.length,
                        itemBuilder: (context, index) => _PlantCard(
                          controller: controller,
                          plant: plants[index],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlantCard extends StatelessWidget {
  const _PlantCard({required this.controller, required this.plant});

  final TodoWorkspace controller;
  final Plant plant;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final next = _nextPlantTask(controller, plant.id);
    return Material(
      color: visuals.panel,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showPlantDetails(context, controller, plant.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: FutureBuilder<String>(
                future: controller.plantImageAbsolutePath(plant),
                builder: (context, snapshot) {
                  final path = snapshot.data ?? '';
                  if (path.isEmpty) return const _MissingPlantImage();
                  return Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _MissingPlantImage(),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          plant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _PlantSafetyBadge(safety: plant.catSafety, compact: true),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    plant.scientificName.isEmpty
                        ? plant.commonName
                        : plant.scientificName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: visuals.textMuted,
                      fontStyle: plant.scientificName.isEmpty
                          ? FontStyle.normal
                          : FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (plant.location.isNotEmpty)
                    _PlantMetaLine(
                      icon: Icons.location_on_outlined,
                      text: plant.location,
                    ),
                  _PlantMetaLine(
                    icon: Icons.event_available_rounded,
                    text: next == null
                        ? 'Sin cuidados pendientes'
                        : 'Próximo: ${_shortPlantDate(next.scheduledAt!)}',
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

class _PlantMetaLine extends StatelessWidget {
  const _PlantMetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Row(
          children: [
            Icon(icon, size: 15, color: context.visuals.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(color: context.visuals.textMuted, fontSize: 12),
              ),
            ),
          ],
        ),
      );
}

class _PlantSafetyBadge extends StatelessWidget {
  const _PlantSafetyBadge({required this.safety, this.compact = false});

  final PlantCatSafety safety;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (safety) {
      PlantCatSafety.nonToxic => (
          const Color(0xFFDCEEDB),
          const Color(0xFF315F35)
        ),
      PlantCatSafety.caution => (
          const Color(0xFFFFEDC4),
          const Color(0xFF74530B)
        ),
      PlantCatSafety.toxic => (
          const Color(0xFFF8D7D2),
          const Color(0xFF8A3028)
        ),
      PlantCatSafety.unknown => (
          const Color(0xFFE9E6E0),
          const Color(0xFF625D55)
        ),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 11,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        compact && safety == PlantCatSafety.nonToxic
            ? 'Apta para gatos'
            : _plantSafetyLabel(safety),
        style: TextStyle(
          color: foreground,
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MissingPlantImage extends StatelessWidget {
  const _MissingPlantImage();

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFFE8EFE3),
        child: const Center(
          child: Icon(Icons.local_florist_outlined,
              size: 64, color: Color(0xFF759071)),
        ),
      );
}

class _PlantsEmpty extends StatelessWidget {
  const _PlantsEmpty({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(filtered ? Icons.search_off_rounded : Icons.eco_outlined,
                size: 58, color: context.visuals.textMuted),
            const SizedBox(height: 12),
            Text(
              filtered
                  ? 'No hay plantas que coincidan con los filtros.'
                  : 'Añade tu primera planta para organizar sus cuidados.',
              style: TextStyle(color: context.visuals.textMuted),
            ),
          ],
        ),
      );
}

TaskModel? _nextPlantTask(TodoWorkspace controller, String plantId) {
  final today = controller.logicalDate();
  for (var offset = 0; offset <= 730; offset++) {
    final date = today.add(Duration(days: offset));
    for (final task in controller.tasksForDate(date)) {
      if (task.sourcePlantId == plantId && task.status == TaskStatus.active) {
        return task.copyWith(scheduledAt: date);
      }
    }
  }
  return null;
}

Future<void> _showPlantDetails(
  BuildContext context,
  TodoWorkspace controller,
  String plantId,
) async {
  final action = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final plant = controller.plantById(plantId);
      if (plant == null) return const SizedBox.shrink();
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 820),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(plant.name,
                              style: Theme.of(context).textTheme.headlineSmall),
                          if (plant.scientificName.isNotEmpty)
                            Text(
                              plant.scientificName,
                              style: TextStyle(
                                color: context.visuals.textMuted,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _PlantSafetyBadge(safety: plant.catSafety),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final details = _PlantDetailContent(
                        controller: controller,
                        plant: plant,
                      );
                      if (constraints.maxWidth < 760) return details;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 340,
                            height: 390,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: FutureBuilder<String>(
                                future: controller.plantImageAbsolutePath(
                                  plant,
                                  thumbnail: false,
                                ),
                                builder: (context, snapshot) {
                                  final path = snapshot.data ?? '';
                                  return path.isEmpty
                                      ? const _MissingPlantImage()
                                      : Image.file(
                                          File(path),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const _MissingPlantImage(),
                                        );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(child: details),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.pop(dialogContext, 'archive'),
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('Archivar'),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(dialogContext, 'delete'),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Eliminar'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(dialogContext, 'edit'),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (!context.mounted || action == null) return;
  if (action == 'edit') {
    await _showPlantEditor(context, controller,
        plant: controller.plantById(plantId));
  } else if (action == 'archive') {
    controller.archivePlant(plantId);
  } else if (action == 'delete') {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar planta'),
        content: const Text(
          'Se eliminarán también su imagen y todas las tareas de cuidado enlazadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) controller.deletePlant(plantId);
  }
}

class _PlantDetailContent extends StatelessWidget {
  const _PlantDetailContent({required this.controller, required this.plant});

  final TodoWorkspace controller;
  final Plant plant;

  @override
  Widget build(BuildContext context) {
    final fields = <(String, String, IconData)>[
      ('Nombre común', plant.commonName, Icons.badge_outlined),
      ('Cultivar', plant.cultivar, Icons.eco_outlined),
      ('Ubicación', plant.location, Icons.location_on_outlined),
      ('Luz', plant.light, Icons.light_mode_outlined),
      ('Riego', plant.watering, Icons.water_drop_outlined),
      ('Humedad', plant.humidity, Icons.water_outlined),
      ('Temperatura', plant.temperature, Icons.thermostat_outlined),
      ('Sustrato', plant.substrate, Icons.landscape_outlined),
      ('Abonado', plant.fertilizing, Icons.science_outlined),
      ('Poda', plant.pruning, Icons.content_cut_rounded),
      ('Propagación', plant.propagation, Icons.call_split_rounded),
      ('Trasplante', plant.repotting, Icons.local_florist_outlined),
      ('Problemas frecuentes', plant.commonProblems, Icons.bug_report_outlined),
    ].where((entry) => entry.$2.trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (plant.description.isNotEmpty) ...[
          Text(plant.description),
          const SizedBox(height: 20),
        ],
        _plantDetailHeading(context, 'Cuidados'),
        const SizedBox(height: 10),
        for (final field in fields)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(field.$3, size: 20),
            title: Text(field.$1,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(field.$2),
          ),
        const SizedBox(height: 18),
        _plantDetailHeading(context, 'Seguridad para gatos'),
        const SizedBox(height: 8),
        Text(plant.catSafetyNotes.isEmpty
            ? 'No hay información verificada todavía.'
            : plant.catSafetyNotes),
        const SizedBox(height: 20),
        _plantDetailHeading(context, 'Rutinas y tareas'),
        const SizedBox(height: 8),
        for (final routine in plant.routines)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(_plantCareIcon(routine.type)),
              title: Text(routine.title),
              subtitle: Text(
                '${_plantRecurrenceLabel(routine.recurrence)} · Próxima fecha: ${_shortPlantDate(routine.firstDueDate)}',
              ),
              trailing: Icon(
                routine.enabled
                    ? Icons.check_circle_rounded
                    : Icons.pause_circle,
                color: routine.enabled
                    ? const Color(0xFF52744B)
                    : context.visuals.textMuted,
              ),
            ),
          ),
        if (plant.sources.isNotEmpty) ...[
          const SizedBox(height: 18),
          _plantDetailHeading(context, 'Fuentes'),
          for (final source in plant.sources)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.open_in_new_rounded, size: 19),
              title: Text(source.title),
              subtitle: Text(source.url,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => launchUrl(Uri.parse(source.url)),
            ),
        ],
        if (plant.notes.isNotEmpty) ...[
          const SizedBox(height: 18),
          _plantDetailHeading(context, 'Notas'),
          const SizedBox(height: 8),
          Text(plant.notes),
        ],
      ],
    );
  }
}

Widget _plantDetailHeading(BuildContext context, String text) =>
    Text(text, style: Theme.of(context).textTheme.titleMedium);

Future<void> _showPlantEditor(
  BuildContext context,
  TodoWorkspace controller, {
  Plant? plant,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        _PlantEditorDialog(controller: controller, plant: plant),
  );
}

class _PlantEditorDialog extends StatefulWidget {
  const _PlantEditorDialog({required this.controller, this.plant});

  final TodoWorkspace controller;
  final Plant? plant;

  @override
  State<_PlantEditorDialog> createState() => _PlantEditorDialogState();
}

class _PlantEditorDialogState extends State<_PlantEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields = {};
  late PlantCatSafety _safety;
  DateTime? _acquiredAt;
  XFile? _imageFile;
  Uint8List? _pastedImageBytes;
  final FocusNode _imagePasteFocus =
      FocusNode(debugLabel: 'Pegar imagen de planta');
  final List<_PlantRoutineDraft> _routines = [];
  bool _saving = false;

  Plant? get plant => widget.plant;
  bool get editing => plant != null;

  @override
  void initState() {
    super.initState();
    final value = plant;
    final values = <String, String>{
      'name': value?.name ?? '',
      'commonName': value?.commonName ?? '',
      'scientificName': value?.scientificName ?? '',
      'cultivar': value?.cultivar ?? '',
      'location': value?.location ?? '',
      'description': value?.description ?? '',
      'light': value?.light ?? '',
      'watering': value?.watering ?? '',
      'humidity': value?.humidity ?? '',
      'temperature': value?.temperature ?? '',
      'substrate': value?.substrate ?? '',
      'fertilizing': value?.fertilizing ?? '',
      'pruning': value?.pruning ?? '',
      'propagation': value?.propagation ?? '',
      'repotting': value?.repotting ?? '',
      'commonProblems': value?.commonProblems ?? '',
      'catSafetyNotes': value?.catSafetyNotes ?? '',
      'sources':
          value?.sources.map((s) => '${s.title} | ${s.url}').join('\n') ?? '',
      'tags': value?.tags.join(', ') ?? '',
      'notes': value?.notes ?? '',
    };
    for (final entry in values.entries) {
      _fields[entry.key] = TextEditingController(text: entry.value);
    }
    _safety = value?.catSafety ?? PlantCatSafety.unknown;
    _acquiredAt = value?.acquiredAt;
    _routines.addAll(value?.routines.map(_PlantRoutineDraft.fromRoutine) ?? []);
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    for (final routine in _routines) {
      routine.dispose();
    }
    _imagePasteFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 860),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 20, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(editing ? 'Editar planta' : 'Añadir planta',
                            style: Theme.of(context).textTheme.headlineMedium),
                        Text(
                          'La ficha genera y mantiene sus tareas de cuidado automáticamente.',
                          style: TextStyle(color: context.visuals.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 820) {
                    return Column(
                      children: [
                        SizedBox(height: 240, child: _imagePanel()),
                        Expanded(child: _form()),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      SizedBox(width: 360, child: _imagePanel()),
                      const VerticalDivider(width: 1),
                      Expanded(child: _form()),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(editing ? 'Guardar cambios' : 'Añadir planta'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePanel() => CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyV, control: true):
              _pasteImage,
        },
        child: Focus(
          focusNode: _imagePasteFocus,
          child: ColoredBox(
            color: const Color(0xFFE8EFE3),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Expanded(child: _imagePreview()),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _selectImage,
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('Elegir imagen'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pasteImage,
                        icon: const Icon(Icons.content_paste_rounded),
                        label: const Text('Pegar imagen'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _imagePreview() {
    if (_pastedImageBytes != null) {
      return Image.memory(_pastedImageBytes!, fit: BoxFit.contain);
    }
    if (_imageFile != null) {
      return Image.file(File(_imageFile!.path), fit: BoxFit.contain);
    }
    if (plant?.imagePath.isNotEmpty == true) {
      return FutureBuilder<String>(
        future:
            widget.controller.plantImageAbsolutePath(plant!, thumbnail: false),
        builder: (context, snapshot) => snapshot.data?.isNotEmpty == true
            ? Image.file(File(snapshot.data!), fit: BoxFit.contain)
            : const _MissingPlantImage(),
      );
    }
    return const _MissingPlantImage();
  }

  Widget _form() => Form(
        key: _formKey,
        child: ListView(
          key: const ValueKey('plant-editor-form'),
          padding: const EdgeInsets.all(24),
          children: [
            _editorHeading('Identificación'),
            _input('name', 'Nombre', required: true),
            _pair(_input('commonName', 'Nombre común'),
                _input('scientificName', 'Nombre científico')),
            _pair(_input('cultivar', 'Cultivar o variedad'),
                _input('location', 'Ubicación')),
            _dateButton(),
            _input('description', 'Descripción', lines: 3),
            _editorHeading('Cuidados'),
            _input('light', 'Luz', lines: 2),
            _input('watering', 'Riego', lines: 2),
            _pair(_input('humidity', 'Humedad', lines: 2),
                _input('temperature', 'Temperatura', lines: 2)),
            _input('substrate', 'Sustrato', lines: 2),
            _input('fertilizing', 'Abonado', lines: 2),
            _pair(_input('pruning', 'Poda', lines: 2),
                _input('propagation', 'Propagación', lines: 2)),
            _input('repotting', 'Trasplante', lines: 2),
            _input('commonProblems', 'Problemas frecuentes', lines: 3),
            _editorHeading('Seguridad para gatos'),
            DropdownButtonFormField<PlantCatSafety>(
              initialValue: _safety,
              decoration: const InputDecoration(labelText: 'Clasificación'),
              items: PlantCatSafety.values
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(_plantSafetyLabel(value)),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _safety = value ?? _safety),
            ),
            const SizedBox(height: 12),
            _input('catSafetyNotes', 'Información y precauciones', lines: 3),
            _input('sources', 'Fuentes',
                lines: 3,
                hint: 'Título | https://fuente.example\nUna fuente por línea'),
            _editorHeading('Rutinas automáticas'),
            for (var index = 0; index < _routines.length; index++)
              _routineEditor(index),
            OutlinedButton.icon(
              onPressed: _addRoutine,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Añadir rutina'),
            ),
            _editorHeading('Organización'),
            _input('tags', 'Etiquetas', hint: 'interior, fácil, segura'),
            _input('notes', 'Notas', lines: 4),
          ],
        ),
      );

  Widget _editorHeading(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 12),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _input(String key, String label,
      {int lines = 1, bool required = false, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _fields[key],
        minLines: lines,
        maxLines: lines,
        decoration: InputDecoration(labelText: label, hintText: hint),
        validator: required
            ? (value) => value?.trim().isEmpty == true
                ? 'Este campo es obligatorio'
                : null
            : null,
      ),
    );
  }

  Widget _pair(Widget first, Widget second) => LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 540
            ? Column(children: [first, second])
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: first),
                  const SizedBox(width: 12),
                  Expanded(child: second),
                ],
              ),
      );

  Widget _dateButton() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: OutlinedButton.icon(
          onPressed: () async {
            final selected = await showDatePicker(
              context: context,
              initialDate: _acquiredAt ?? DateTime.now(),
              firstDate: DateTime(1950),
              lastDate: DateTime(2100),
            );
            if (selected != null) {
              setState(() => _acquiredAt = selected);
            }
          },
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(_acquiredAt == null
              ? 'Fecha de adquisición'
              : 'Adquirida el ${_shortPlantDate(_acquiredAt!)}'),
        ),
      );

  Widget _routineEditor(int index) {
    final draft = _routines[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<PlantCareType>(
                    initialValue: draft.type,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: PlantCareType.values
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(_plantCareTypeLabel(type)),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => draft.type = value ?? draft.type),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Eliminar rutina',
                  onPressed: () => setState(() {
                    _routines.removeAt(index).dispose();
                  }),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: draft.title,
              decoration:
                  const InputDecoration(labelText: 'Título de la tarea'),
              validator: (value) =>
                  value?.trim().isEmpty == true ? 'Escribe un título' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: draft.instructions,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Instrucciones'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<RecurrenceType>(
                    initialValue: draft.recurrenceType,
                    decoration: const InputDecoration(labelText: 'Frecuencia'),
                    items: const [
                      DropdownMenuItem(
                          value: RecurrenceType.daily, child: Text('Diaria')),
                      DropdownMenuItem(
                          value: RecurrenceType.everyXDays,
                          child: Text('Cada X días')),
                      DropdownMenuItem(
                          value: RecurrenceType.weekly, child: Text('Semanal')),
                      DropdownMenuItem(
                          value: RecurrenceType.monthly,
                          child: Text('Cada X meses')),
                      DropdownMenuItem(
                          value: RecurrenceType.yearly, child: Text('Anual')),
                    ],
                    onChanged: (value) => setState(
                      () =>
                          draft.recurrenceType = value ?? draft.recurrenceType,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    controller: draft.interval,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Intervalo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: draft.activeMonths,
              decoration: const InputDecoration(
                labelText: 'Meses activos opcionales',
                hintText: '4, 5, 6, 7, 8, 9',
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final selected = await showDatePicker(
                      context: context,
                      initialDate: draft.firstDueDate,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime(2100),
                    );
                    if (selected != null) {
                      setState(() => draft.firstDueDate = selected);
                    }
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                      'Primera fecha: ${_shortPlantDate(draft.firstDueDate)}'),
                ),
                const Spacer(),
                Switch(
                  value: draft.enabled,
                  onChanged: (value) => setState(() => draft.enabled = value),
                ),
                const Text('Activa'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addRoutine() => setState(() {
        _routines.add(_PlantRoutineDraft.empty());
      });

  Future<void> _selectImage() async {
    final selected = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
            label: 'Imágenes', extensions: ['png', 'jpg', 'jpeg', 'webp']),
      ],
    );
    if (selected != null && mounted) {
      setState(() {
        _imageFile = selected;
        _pastedImageBytes = null;
      });
    }
  }

  Future<void> _pasteImage() async {
    final result = await readClipboardImage();
    if (!mounted) return;
    if (!result.hasImage) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.errorMessage!)));
      return;
    }
    setState(() {
      _pastedImageBytes = result.bytes;
      _imageFile = null;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final routines = _routines.map((draft) => draft.toRoutine()).toList();
    final sources = _fields['sources']!
        .text
        .split('\n')
        .map((line) => line.split('|'))
        .where((parts) => parts.length >= 2 && parts.last.trim().isNotEmpty)
        .map((parts) => PlantSource(
              title: parts.first.trim(),
              url: parts.sublist(1).join('|').trim(),
            ))
        .toList();
    final tags = _fields['tags']!
        .text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    Plant saved;
    if (plant == null) {
      saved = widget.controller.createPlant(
        name: _text('name'),
        commonName: _text('commonName'),
        scientificName: _text('scientificName'),
        cultivar: _text('cultivar'),
        location: _text('location'),
        acquiredAt: _acquiredAt,
        description: _text('description'),
        light: _text('light'),
        watering: _text('watering'),
        humidity: _text('humidity'),
        temperature: _text('temperature'),
        substrate: _text('substrate'),
        fertilizing: _text('fertilizing'),
        pruning: _text('pruning'),
        propagation: _text('propagation'),
        repotting: _text('repotting'),
        commonProblems: _text('commonProblems'),
        catSafety: _safety,
        catSafetyNotes: _text('catSafetyNotes'),
        sources: sources,
        routines: routines,
        tags: tags,
        notes: _text('notes'),
      );
    } else {
      saved = plant!.copyWith(
        name: _text('name'),
        commonName: _text('commonName'),
        scientificName: _text('scientificName'),
        cultivar: _text('cultivar'),
        location: _text('location'),
        acquiredAt: _acquiredAt,
        clearAcquiredAt: _acquiredAt == null,
        description: _text('description'),
        light: _text('light'),
        watering: _text('watering'),
        humidity: _text('humidity'),
        temperature: _text('temperature'),
        substrate: _text('substrate'),
        fertilizing: _text('fertilizing'),
        pruning: _text('pruning'),
        propagation: _text('propagation'),
        repotting: _text('repotting'),
        commonProblems: _text('commonProblems'),
        catSafety: _safety,
        catSafetyNotes: _text('catSafetyNotes'),
        sources: sources,
        routines: routines,
        tags: tags,
        notes: _text('notes'),
      );
      widget.controller.updatePlant(saved);
    }
    try {
      if (_pastedImageBytes != null) {
        await widget.controller
            .importPlantImageBytes(saved.id, _pastedImageBytes!);
      } else if (_imageFile != null) {
        await widget.controller.importPlantImage(saved.id, _imageFile!.path);
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la imagen: $error')),
      );
    }
  }

  String _text(String key) => _fields[key]!.text.trim();
}

class _PlantRoutineDraft {
  _PlantRoutineDraft({
    required this.id,
    required this.type,
    required this.title,
    required this.instructions,
    required this.firstDueDate,
    required this.recurrenceType,
    required this.interval,
    required this.activeMonths,
    required this.enabled,
  });

  final String id;
  PlantCareType type;
  final TextEditingController title;
  final TextEditingController instructions;
  DateTime firstDueDate;
  RecurrenceType recurrenceType;
  final TextEditingController interval;
  final TextEditingController activeMonths;
  bool enabled;

  factory _PlantRoutineDraft.empty() {
    final now = DateTime.now();
    return _PlantRoutineDraft(
      id: 'plant-care-${now.microsecondsSinceEpoch}',
      type: PlantCareType.watering,
      title: TextEditingController(),
      instructions: TextEditingController(),
      firstDueDate: DateTime(now.year, now.month, now.day),
      recurrenceType: RecurrenceType.everyXDays,
      interval: TextEditingController(text: '7'),
      activeMonths: TextEditingController(),
      enabled: true,
    );
  }

  factory _PlantRoutineDraft.fromRoutine(PlantCareRoutine routine) =>
      _PlantRoutineDraft(
        id: routine.id,
        type: routine.type,
        title: TextEditingController(text: routine.title),
        instructions: TextEditingController(text: routine.instructions),
        firstDueDate: routine.firstDueDate,
        recurrenceType: routine.recurrence.type,
        interval: TextEditingController(text: '${routine.recurrence.interval}'),
        activeMonths: TextEditingController(
          text: routine.recurrence.activeMonths.join(', '),
        ),
        enabled: routine.enabled,
      );

  PlantCareRoutine toRoutine() => PlantCareRoutine(
        id: id,
        type: type,
        title: title.text.trim(),
        instructions: instructions.text.trim(),
        firstDueDate: DateTime(
          firstDueDate.year,
          firstDueDate.month,
          firstDueDate.day,
        ),
        recurrence: RecurrenceRule(
          type: recurrenceType,
          interval: max(1, int.tryParse(interval.text.trim()) ?? 1),
          activeMonths: activeMonths.text
              .split(',')
              .map((value) => int.tryParse(value.trim()))
              .whereType<int>()
              .where((value) => value >= 1 && value <= 12)
              .toSet()
              .toList()
            ..sort(),
        ),
        enabled: enabled,
      );

  void dispose() {
    title.dispose();
    instructions.dispose();
    interval.dispose();
    activeMonths.dispose();
  }
}

String _plantSafetyLabel(PlantCatSafety value) => switch (value) {
      PlantCatSafety.nonToxic => 'No tóxica',
      PlantCatSafety.caution => 'Precaución',
      PlantCatSafety.toxic => 'Tóxica',
      PlantCatSafety.unknown => 'Sin verificar',
    };

String _plantCareTypeLabel(PlantCareType value) => switch (value) {
      PlantCareType.watering => 'Riego',
      PlantCareType.fertilizing => 'Abonado',
      PlantCareType.inspection => 'Revisión',
      PlantCareType.repotting => 'Trasplante',
      PlantCareType.pruning => 'Poda',
      PlantCareType.cleaning => 'Limpieza',
      PlantCareType.misting => 'Pulverización',
      PlantCareType.custom => 'Personalizada',
    };

IconData _plantCareIcon(PlantCareType value) => switch (value) {
      PlantCareType.watering => Icons.water_drop_outlined,
      PlantCareType.fertilizing => Icons.science_outlined,
      PlantCareType.inspection => Icons.search_rounded,
      PlantCareType.repotting => Icons.local_florist_outlined,
      PlantCareType.pruning => Icons.content_cut_rounded,
      PlantCareType.cleaning => Icons.cleaning_services_outlined,
      PlantCareType.misting => Icons.grain_rounded,
      PlantCareType.custom => Icons.task_alt_rounded,
    };

String _plantRecurrenceLabel(RecurrenceRule recurrence) {
  final base = switch (recurrence.type) {
    RecurrenceType.none => 'Una vez',
    RecurrenceType.daily => 'Cada día',
    RecurrenceType.everyXDays => 'Cada ${recurrence.interval} días',
    RecurrenceType.weekly => recurrence.interval == 1
        ? 'Cada semana'
        : 'Cada ${recurrence.interval} semanas',
    RecurrenceType.monthly => recurrence.interval == 1
        ? 'Cada mes'
        : 'Cada ${recurrence.interval} meses',
    RecurrenceType.yearly => recurrence.interval == 1
        ? 'Cada año'
        : 'Cada ${recurrence.interval} años',
  };
  return recurrence.activeMonths.isEmpty
      ? base
      : '$base · meses ${recurrence.activeMonths.join(', ')}';
}

String _shortPlantDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
