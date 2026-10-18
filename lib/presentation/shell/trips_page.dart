part of 'app_shell.dart';

class TripsPage extends StatefulWidget {
  const TripsPage({required this.controller, super.key});

  final TodoWorkspace controller;

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  bool _showArchived = false;

  TodoWorkspace get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final today = controller.logicalDate();
    final all = controller.trips
        .where((trip) => trip.archived == _showArchived)
        .toList();
    final upcoming = all.where((trip) => !trip.endDate.isBefore(today)).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    final past = all.where((trip) => trip.endDate.isBefore(today)).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: _PageHeader(
              title: 'Viajes',
              subtitle: '',
              compact: true,
              pinTrailingToEdge: true,
              trailing: _HeaderActionButton(
                key: const ValueKey('trips-new'),
                label: 'Nuevo viaje',
                icon: Icons.add_rounded,
                onPressed: () => showTripEditor(context, controller),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _FilterPill(
                label: 'Activos',
                selected: !_showArchived,
                onTap: () => setState(() => _showArchived = false),
              ),
              const SizedBox(width: 7),
              _FilterPill(
                label: 'Archivados',
                selected: _showArchived,
                onTap: () => setState(() => _showArchived = true),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: all.isEmpty
                ? _TripsEmpty(archived: _showArchived)
                : ListView(
                    children: [
                      for (final trip in upcoming) ...[
                        _TripCard(
                          controller: controller,
                          trip: trip,
                          today: today,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (past.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 10),
                          child: Text('Pasados',
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                        for (final trip in past) ...[
                          _TripCard(
                            controller: controller,
                            trip: trip,
                            today: today,
                          ),
                          const SizedBox(height: 12),
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

class _TripsEmpty extends StatelessWidget {
  const _TripsEmpty({required this.archived});

  final bool archived;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.luggage_rounded, size: 46, color: visuals.textMuted),
          const SizedBox(height: 12),
          Text(
            archived ? 'No hay viajes archivados' : 'Aún no hay viajes',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (!archived) ...[
            const SizedBox(height: 6),
            Text(
              'Crea uno con sus fechas, reservas, documentos y maleta.',
              style: TextStyle(color: visuals.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

String _tripCountdown(Trip trip, DateTime today) {
  if (trip.endDate.isBefore(today)) return 'Terminado';
  if (!trip.startDate.isAfter(today)) {
    final day = today.difference(trip.startDate).inDays + 1;
    return 'En curso · día $day de ${trip.durationDays}';
  }
  final days = trip.startDate.difference(today).inDays;
  return days == 1 ? 'Mañana' : 'Faltan $days días';
}

String _tripRange(Trip trip) => trip.startDate == trip.endDate
    ? _fechaLarga(trip.startDate)
    : '${trip.startDate.day} ${_mesesCompletos[trip.startDate.month - 1].substring(0, 3)} – '
        '${trip.endDate.day} ${_mesesCompletos[trip.endDate.month - 1].substring(0, 3)} ${trip.endDate.year}';

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.controller,
    required this.trip,
    required this.today,
  });

  final TodoWorkspace controller;
  final Trip trip;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final ongoing =
        !trip.startDate.isAfter(today) && !trip.endDate.isBefore(today);
    return Material(
      color: visuals.panel,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('trip-card-${trip.id}'),
        onTap: () => showTripDetails(context, controller, trip.id),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: visuals.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  ongoing ? Icons.flight_rounded : Icons.luggage_rounded,
                  color: visuals.accent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (trip.destination.isNotEmpty) trip.destination,
                        _tripRange(trip),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: visuals.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _SoftChip(
                label: _tripCountdown(trip, today),
                icon: Icons.schedule_rounded,
                color: ongoing ? visuals.success : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showTripEditor(
  BuildContext context,
  TodoWorkspace controller, {
  Trip? trip,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _TripEditorDialog(controller: controller, trip: trip),
  );
}

class _TripEditorDialog extends StatefulWidget {
  const _TripEditorDialog({required this.controller, this.trip});

  final TodoWorkspace controller;
  final Trip? trip;

  @override
  State<_TripEditorDialog> createState() => _TripEditorDialogState();
}

class _TripEditorDialogState extends State<_TripEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _destination;
  late final TextEditingController _notes;
  late DateTime _start;
  late DateTime _end;
  bool _createPackingList = true;

  @override
  void initState() {
    super.initState();
    final trip = widget.trip;
    final today = widget.controller.logicalDate();
    _name = TextEditingController(text: trip?.name ?? '');
    _destination = TextEditingController(text: trip?.destination ?? '');
    _notes = TextEditingController(text: trip?.notes ?? '');
    _start = trip?.startDate ?? today.add(const Duration(days: 7));
    _end = trip?.endDate ?? today.add(const Duration(days: 10));
  }

  @override
  void dispose() {
    _name.dispose();
    _destination.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool start}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _start = picked;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = picked.isBefore(_start) ? _start : picked;
      }
    });
  }

  void _save() {
    final controller = widget.controller;
    final trip = widget.trip;
    if (trip == null) {
      controller.createTrip(
        name: _name.text,
        destination: _destination.text,
        startDate: _start,
        endDate: _end,
        notes: _notes.text,
        createPackingList: _createPackingList,
      );
    } else {
      controller.updateTrip(
        trip.id,
        name: _name.text,
        destination: _destination.text,
        startDate: _start,
        endDate: _end,
        notes: _notes.text,
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.trip != null;
    return AlertDialog(
      title: Text(editing ? 'Editar viaje' : 'Nuevo viaje'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('trip-name'),
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('trip-destination'),
                controller: _destination,
                decoration: const InputDecoration(labelText: 'Destino'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('trip-start'),
                      onPressed: () => _pick(start: true),
                      icon: const Icon(Icons.flight_takeoff_rounded),
                      label: Text('Ida ${_fechaNumerica(_start)}'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('trip-end'),
                      onPressed: () => _pick(start: false),
                      icon: const Icon(Icons.flight_land_rounded),
                      label: Text('Vuelta ${_fechaNumerica(_end)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Notas'),
              ),
              if (!editing)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _createPackingList,
                  onChanged: (value) =>
                      setState(() => _createPackingList = value ?? false),
                  title: const Text('Crear la maleta en Ropa'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('trip-save'),
          onPressed: _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

Future<void> showTripDetails(
  BuildContext context,
  TodoWorkspace controller,
  String tripId,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => _TripDetailsDialog(
      controller: controller,
      tripId: tripId,
    ),
  );
}

class _TripDetailsDialog extends StatelessWidget {
  const _TripDetailsDialog({required this.controller, required this.tripId});

  final TodoWorkspace controller;
  final String tripId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final trip = controller.tripById(tripId);
        if (trip == null) {
          return const AlertDialog(content: Text('El viaje ya no existe.'));
        }
        final visuals = context.visuals;
        final today = controller.logicalDate();
        final dated = trip.reservations.where((r) => r.date != null).toList()
          ..sort((a, b) => a.date!.compareTo(b.date!));
        final undated = trip.reservations.where((r) => r.date == null).toList();
        final packing = trip.packingListId == null
            ? null
            : controller.wardrobePackingLists
                .where((list) => list.id == trip.packingListId)
                .firstOrNull;
        return AlertDialog(
          title: Row(
            children: [
              Expanded(child: Text(trip.name)),
              IconButton(
                tooltip: 'Editar viaje',
                onPressed: () =>
                    showTripEditor(context, controller, trip: trip),
                icon: const Icon(Icons.edit_rounded),
              ),
            ],
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (trip.destination.isNotEmpty)
                        _SoftChip(
                          label: trip.destination,
                          icon: Icons.place_rounded,
                        ),
                      _SoftChip(
                        label: _tripRange(trip),
                        icon: Icons.date_range_rounded,
                      ),
                      _SoftChip(
                        label: '${trip.durationDays} días',
                        icon: Icons.wb_sunny_outlined,
                      ),
                      _SoftChip(
                        label: _tripCountdown(trip, today),
                        icon: Icons.schedule_rounded,
                      ),
                    ],
                  ),
                  if (trip.notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(trip.notes),
                  ],
                  const SizedBox(height: 18),
                  _TripSectionTitle(
                    title: 'Itinerario y reservas',
                    actionLabel: 'Añadir',
                    onAction: () => _showReservationDialog(context, trip),
                  ),
                  if (trip.reservations.isEmpty)
                    Text('Sin reservas todavía.',
                        style: TextStyle(color: visuals.textMuted)),
                  for (final reservation in [...dated, ...undated])
                    _TripReservationTile(
                      reservation: reservation,
                      onEdit: () => _showReservationDialog(
                        context,
                        trip,
                        reservation: reservation,
                      ),
                      onDelete: () => controller.deleteTripReservation(
                        trip.id,
                        reservation.id,
                      ),
                    ),
                  const SizedBox(height: 18),
                  _TripSectionTitle(
                    title: 'Documentos',
                    actionLabel: 'PDF',
                    onAction: () => _addPdf(context, trip),
                    secondaryLabel: 'Enlace',
                    onSecondary: () => _addLink(context, trip),
                  ),
                  if (trip.documents.isEmpty)
                    Text('Sin documentos.',
                        style: TextStyle(color: visuals.textMuted)),
                  for (final document in trip.documents)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(
                        document.filePath.isNotEmpty
                            ? Icons.picture_as_pdf_rounded
                            : Icons.link_rounded,
                      ),
                      title: Text(document.title),
                      onTap: () => _openDocument(document),
                      trailing: IconButton(
                        tooltip: 'Quitar documento',
                        onPressed: () => controller.deleteTripDocument(
                          trip.id,
                          document.id,
                        ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  const SizedBox(height: 18),
                  _TripSectionTitle(title: 'Maleta'),
                  _TripPackingPicker(
                    controller: controller,
                    trip: trip,
                    packing: packing,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => _confirmDelete(context, trip),
              child: Text('Eliminar', style: TextStyle(color: visuals.danger)),
            ),
            TextButton(
              onPressed: () => controller.updateTrip(
                trip.id,
                archived: !trip.archived,
              ),
              child: Text(trip.archived ? 'Desarchivar' : 'Archivar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showReservationDialog(
    BuildContext context,
    Trip trip, {
    TripReservation? reservation,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => _TripReservationDialog(
        controller: controller,
        trip: trip,
        reservation: reservation,
      ),
    );
  }

  Future<void> _addPdf(BuildContext context, Trip trip) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final selected = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PDF', extensions: ['pdf']),
      ],
    );
    if (selected == null) return;
    try {
      await controller.addTripPdf(trip.id, selected.path);
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text('No se pudo añadir el PDF: $error')),
      );
    }
  }

  Future<void> _addLink(BuildContext context, Trip trip) async {
    final title = TextEditingController();
    final url = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir enlace'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: url,
                decoration: const InputDecoration(labelText: 'Dirección web'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
    if (accepted == true && url.text.trim().isNotEmpty) {
      controller.addTripLink(trip.id, title.text, url.text);
    }
    title.dispose();
    url.dispose();
  }

  Future<void> _openDocument(TripDocument document) async {
    if (document.filePath.isNotEmpty) {
      final path = await controller.tripDocumentAbsolutePath(document);
      if (path.isNotEmpty) {
        await launchUrl(Uri.file(path), mode: LaunchMode.externalApplication);
      }
      return;
    }
    final uri = Uri.tryParse(document.url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _confirmDelete(BuildContext context, Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar viaje'),
        content: Text(
          'Se borrará «${trip.name}» con sus reservas y documentos. '
          'La maleta de Ropa se conserva.',
        ),
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
      await controller.deleteTrip(trip.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _TripSectionTitle extends StatelessWidget {
  const _TripSectionTitle({
    required this.title,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (secondaryLabel != null)
            TextButton.icon(
              onPressed: onSecondary,
              icon: const Icon(Icons.link_rounded, size: 18),
              label: Text(secondaryLabel!),
            ),
          if (actionLabel != null)
            TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

IconData _tripReservationIcon(TripReservationKind kind) => switch (kind) {
      TripReservationKind.flight => Icons.flight_rounded,
      TripReservationKind.lodging => Icons.hotel_rounded,
      TripReservationKind.transport => Icons.directions_bus_rounded,
      TripReservationKind.activity => Icons.local_activity_rounded,
      TripReservationKind.other => Icons.bookmark_rounded,
    };

class _TripReservationTile extends StatelessWidget {
  const _TripReservationTile({
    required this.reservation,
    required this.onEdit,
    required this.onDelete,
  });

  final TripReservation reservation;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final date = reservation.date;
    final hasTime = date != null && (date.hour != 0 || date.minute != 0);
    final details = <String>[
      reservation.kind.label,
      if (date != null)
        hasTime
            ? '${_fechaConDia(date)} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
            : _fechaConDia(date),
      if (reservation.confirmation.isNotEmpty)
        'Ref. ${reservation.confirmation}',
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(_tripReservationIcon(reservation.kind)),
      title: Text(reservation.title),
      subtitle: Text(
        [
          details.join(' · '),
          if (reservation.note.isNotEmpty) reservation.note,
        ].join('\n'),
      ),
      isThreeLine: reservation.note.isNotEmpty,
      onTap: onEdit,
      trailing: IconButton(
        tooltip: 'Quitar reserva',
        onPressed: onDelete,
        icon: const Icon(Icons.close_rounded),
      ),
    );
  }
}

class _TripReservationDialog extends StatefulWidget {
  const _TripReservationDialog({
    required this.controller,
    required this.trip,
    this.reservation,
  });

  final TodoWorkspace controller;
  final Trip trip;
  final TripReservation? reservation;

  @override
  State<_TripReservationDialog> createState() => _TripReservationDialogState();
}

class _TripReservationDialogState extends State<_TripReservationDialog> {
  late final TextEditingController _title;
  late final TextEditingController _confirmation;
  late final TextEditingController _note;
  late TripReservationKind _kind;
  DateTime? _date;
  TimeOfDay? _time;

  @override
  void initState() {
    super.initState();
    final reservation = widget.reservation;
    _title = TextEditingController(text: reservation?.title ?? '');
    _confirmation = TextEditingController(text: reservation?.confirmation ?? '');
    _note = TextEditingController(text: reservation?.note ?? '');
    _kind = reservation?.kind ?? TripReservationKind.activity;
    final date = reservation?.date;
    if (date != null) {
      _date = DateTime(date.year, date.month, date.day);
      if (date.hour != 0 || date.minute != 0) {
        _time = TimeOfDay(hour: date.hour, minute: date.minute);
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _confirmation.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? widget.trip.startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null && mounted) setState(() => _time = picked);
  }

  void _save() {
    final date = _date;
    final time = _time;
    widget.controller.saveTripReservation(
      widget.trip.id,
      reservationId: widget.reservation?.id,
      title: _title.text,
      kind: _kind,
      date: date == null
          ? null
          : DateTime(date.year, date.month, date.day, time?.hour ?? 0,
              time?.minute ?? 0),
      confirmation: _confirmation.text,
      note: _note.text,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.reservation == null ? 'Nueva reserva' : 'Editar reserva'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<TripReservationKind>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [
                  for (final kind in TripReservationKind.values)
                    DropdownMenuItem(value: kind, child: Text(kind.label)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _kind = value);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('reservation-title'),
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event_rounded),
                      label: Text(
                        _date == null ? 'Sin fecha' : _fechaNumerica(_date!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _date == null ? null : _pickTime,
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(_time == null ? 'Sin hora' : _time!.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _confirmation,
                decoration:
                    const InputDecoration(labelText: 'Localizador o referencia'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Nota'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('reservation-save'),
          onPressed: _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _TripPackingPicker extends StatelessWidget {
  const _TripPackingPicker({
    required this.controller,
    required this.trip,
    required this.packing,
  });

  final TodoWorkspace controller;
  final Trip trip;
  final WardrobePackingList? packing;

  @override
  Widget build(BuildContext context) {
    final lists = controller.wardrobePackingLists;
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String?>(
            initialValue: packing?.id,
            decoration: const InputDecoration(
              labelText: 'Maleta de Ropa asociada',
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Sin maleta'),
              ),
              for (final list in lists)
                DropdownMenuItem<String?>(
                  value: list.id,
                  child: Text(list.name),
                ),
            ],
            onChanged: (value) => controller.updateTrip(
              trip.id,
              packingListId: value,
              clearPackingListId: value == null,
            ),
          ),
        ),
        const SizedBox(width: 10),
        if (packing == null)
          OutlinedButton.icon(
            onPressed: () {
              final list = controller.createWardrobePackingList(
                name: trip.name,
                startDate: trip.startDate,
                endDate: trip.endDate,
              );
              controller.updateTrip(trip.id, packingListId: list.id);
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Crear'),
          )
        else
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              controller.setSection(AppSection.wardrobe);
            },
            icon: const Icon(Icons.checkroom_rounded),
            label: const Text('Ir a Ropa'),
          ),
      ],
    );
  }
}
