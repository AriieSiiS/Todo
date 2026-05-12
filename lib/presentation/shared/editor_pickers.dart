part of 'editors.dart';

Future<DateTime?> _showTodoDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    locale: const Locale('es'),
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF70835D),
            onPrimary: Colors.white,
            surface: Color(0xFFFFFCF8),
            onSurface: Color(0xFF2D2A25),
          ),
          dialogTheme:
              const DialogThemeData(backgroundColor: Color(0xFFFFFCF8)),
        ),
        child: child!,
      );
    },
  );
}

Future<TimeOfDay?> _showTodoTimePicker(
    BuildContext context, TimeOfDay initialTime) {
  return showTimePicker(
    context: context,
    initialTime: initialTime,
    builder: (context, child) {
      return Localizations.override(
        context: context,
        locale: const Locale('es'),
        child: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF70835D),
              onPrimary: Colors.white,
              surface: Color(0xFFFFFCF8),
              onSurface: Color(0xFF2D2A25),
            ),
            dialogTheme:
                const DialogThemeData(backgroundColor: Color(0xFFFFFCF8)),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        ),
      );
    },
  );
}

Future<int?> _showReminderSettingsDialog(
  BuildContext context, {
  required int currentMinutes,
  required String title,
  required String subtitle,
}) async {
  String selectedUnit = currentMinutes >= 1440 && currentMinutes % 1440 == 0
      ? 'días'
      : currentMinutes >= 60 && currentMinutes % 60 == 0
          ? 'horas'
          : 'minutos';
  int amount = switch (selectedUnit) {
    'días' => (currentMinutes / 1440).round(),
    'horas' => (currentMinutes / 60).round(),
    _ => currentMinutes,
  };
  bool useAsDefault = false;

  int minutesFromSelection() {
    return switch (selectedUnit) {
      'días' => amount * 1440,
      'horas' => amount * 60,
      _ => amount,
    };
  }

  return showDialog<int>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setLocalState) {
          final effectiveMinutes = minutesFromSelection();
          return Dialog(
            backgroundColor: Colors.transparent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF8),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFE2D5C4)),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium),
                                const SizedBox(height: 8),
                                Text(subtitle,
                                    style: const TextStyle(
                                        color: Color(0xFF7A7369))),
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
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final minutes in const <int>[
                            5,
                            15,
                            30,
                            60,
                            1440
                          ])
                            ChoiceChip(
                              selected: effectiveMinutes == minutes,
                              label: Text(_reminderPresetLabelGlobal(minutes)),
                              onSelected: (_) {
                                setLocalState(() {
                                  selectedUnit = minutes >= 1440
                                      ? 'días'
                                      : minutes >= 60
                                          ? 'horas'
                                          : 'minutos';
                                  amount = minutes >= 1440
                                      ? (minutes / 1440).round()
                                      : minutes >= 60
                                          ? (minutes / 60).round()
                                          : minutes;
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Text('Avisarme',
                              style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 14),
                          SizedBox(
                            width: 90,
                            child: TextFormField(
                              initialValue: amount.toString(),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setLocalState(() {
                                  amount = int.tryParse(value) ?? amount;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          SizedBox(
                            width: 150,
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedUnit,
                              items: const [
                                DropdownMenuItem(
                                    value: 'minutos', child: Text('minutos')),
                                DropdownMenuItem(
                                    value: 'horas', child: Text('horas')),
                                DropdownMenuItem(
                                    value: 'días', child: Text('días')),
                              ],
                              onChanged: (value) => setLocalState(
                                  () => selectedUnit = value ?? selectedUnit),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Text('antes', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F3EA),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE7DDCC)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: const Color(0xFF70835D), width: 3),
                              ),
                              child: const Icon(Icons.schedule_rounded,
                                  color: Color(0xFF70835D)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Te avisaré ${_reminderPresetLabelGlobal(effectiveMinutes).toLowerCase()}',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Si la tarea es a las 09:00, el aviso llegará antes según esta configuración.',
                                    style: const TextStyle(
                                        color: Color(0xFF7A7369)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: useAsDefault,
                            onChanged: (value) => setLocalState(
                                () => useAsDefault = value ?? false),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Usar este recordatorio por defecto',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600)),
                                SizedBox(height: 4),
                                Text(
                                  'Se aplicara a las nuevas tareas que crees.',
                                  style: TextStyle(color: Color(0xFF7A7369)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () =>
                                Navigator.of(context).pop(effectiveMinutes),
                            child: const Text('Guardar recordatorio'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Future<int?> _showColorPickerDialog(
  BuildContext context, {
  required int initialColor,
  required String title,
  required String subtitle,
}) {
  final hsv = HSVColor.fromColor(Color(initialColor));
  double hue = hsv.hue;
  double saturation = hsv.saturation;
  double value = hsv.value;
  final hexController =
      TextEditingController(text: _hexFromColorValue(initialColor));

  Color currentColor() =>
      HSVColor.fromAHSV(1, hue, saturation, value).toColor();

  const suggested = <int>[
    0xFF70835D,
    0xFF92A4D8,
    0xFFC0A0DA,
    0xFFE6A9A2,
    0xFFF2B68F,
    0xFFE7BE63,
    0xFF8EBBB2,
    0xFFD4C1AA,
    0xFFB9BEC6,
    0xFF9D92D6,
  ];

  return showDialog<int>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setLocalState) {
          final color = currentColor();
          hexController.value = TextEditingValue(
            text: _hexFromColorValue(color.toARGB32()),
            selection: TextSelection.collapsed(
                offset: _hexFromColorValue(color.toARGB32()).length),
          );
          return Dialog(
            backgroundColor: Colors.transparent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF8),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFE2D5C4)),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium),
                                const SizedBox(height: 8),
                                Text(subtitle,
                                    style: const TextStyle(
                                        color: Color(0xFF7A7369))),
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
                      const Text('Colores sugeridos',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final suggestedColor in suggested)
                            InkWell(
                              onTap: () {
                                final suggestedHsv =
                                    HSVColor.fromColor(Color(suggestedColor));
                                setLocalState(() {
                                  hue = suggestedHsv.hue;
                                  saturation = suggestedHsv.saturation;
                                  value = suggestedHsv.value;
                                });
                              },
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Color(suggestedColor),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: color.toARGB32() == suggestedColor
                                        ? const Color(0xFF70835D)
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Text('Color personalizado',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Container(
                                  height: 190,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.topRight,
                                      colors: [
                                        Colors.white,
                                        HSVColor.fromAHSV(1, hue, 1, 1)
                                            .toColor()
                                      ],
                                    ),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      gradient: const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Slider(
                                  value: saturation,
                                  onChanged: (newValue) => setLocalState(
                                      () => saturation = newValue),
                                ),
                                Slider(
                                  value: value,
                                  onChanged: (newValue) =>
                                      setLocalState(() => value = newValue),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 18),
                          SizedBox(
                            width: 36,
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: Slider(
                                value: hue,
                                min: 0,
                                max: 360,
                                onChanged: (newValue) =>
                                    setLocalState(() => hue = newValue),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 140,
                            child: TextField(
                              controller: hexController,
                              onChanged: (valueText) {
                                final parsed = _tryParseHexColor(valueText);
                                if (parsed != null) {
                                  final parsedHsv =
                                      HSVColor.fromColor(Color(parsed));
                                  setLocalState(() {
                                    hue = parsedHsv.hue;
                                    saturation = parsedHsv.saturation;
                                    value = parsedHsv.value;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text('Vista previa',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _tagChip('Autocuidado', color.withValues(alpha: 0.16),
                              color),
                          _tagChip('Cumpleaños', color.withValues(alpha: 0.16),
                              color),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () =>
                                Navigator.of(context).pop(color.toARGB32()),
                            child: const Text('Usar color'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _projectStatusBadge(ProjectStatus status) {
  final (background, foreground, label) = switch (status) {
    ProjectStatus.active => (
        const Color(0xFFEAF0DE),
        const Color(0xFF70835D),
        'Activo'
      ),
    ProjectStatus.paused => (
        const Color(0xFFF9EED9),
        const Color(0xFFC58B2D),
        'En pausa'
      ),
    ProjectStatus.completed => (
        const Color(0xFFEDEDED),
        const Color(0xFF6F6F6F),
        'Completado'
      ),
    ProjectStatus.cancelled => (
        const Color(0xFFF4E3E3),
        const Color(0xFF9D5C5C),
        'Cancelado'
      ),
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color: background, borderRadius: BorderRadius.circular(999)),
    child: Text(label,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w600)),
  );
}

String _reminderPresetLabelGlobal(int minutes) {
  if (minutes == 60) {
    return '1 hora antes';
  }
  if (minutes == 1440) {
    return '24 horas antes';
  }
  return '$minutes min antes';
}

String _hexFromColorValue(int colorValue) {
  final hex =
      colorValue.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
  return '#$hex';
}

int? _tryParseHexColor(String value) {
  final clean = value.trim().replaceAll('#', '');
  if (clean.length != 6) {
    return null;
  }
  final parsed = int.tryParse(clean, radix: 16);
  if (parsed == null) {
    return null;
  }
  return 0xFF000000 | parsed;
}

Future<IconData?> _showIconPicker(BuildContext context) {
  final icons = <IconData>[
    Icons.celebration_rounded,
    Icons.chair_rounded,
    Icons.emoji_emotions_outlined,
    Icons.sports_gymnastics_rounded,
    Icons.menu_book_rounded,
    Icons.shopping_bag_outlined,
    Icons.cleaning_services_outlined,
    Icons.local_florist_outlined,
    Icons.favorite_outline_rounded,
    Icons.palette_outlined,
    Icons.event_outlined,
    Icons.restaurant_outlined,
    Icons.bed_outlined,
    Icons.flight_takeoff_outlined,
    Icons.computer_outlined,
    Icons.edit_note_outlined,
    Icons.pets_outlined,
    Icons.music_note_outlined,
    Icons.camera_alt_outlined,
    Icons.work_outline_rounded,
    Icons.lightbulb_outline_rounded,
    Icons.home_repair_service_outlined,
    Icons.spa_outlined,
    Icons.school_outlined,
    MdiIcons.partyPopper,
    MdiIcons.sofaOutline,
    MdiIcons.broom,
    MdiIcons.dumbbell,
    MdiIcons.bookOpenPageVariantOutline,
    MdiIcons.giftOutline,
    MdiIcons.silverwareForkKnife,
    MdiIcons.leaf,
    MdiIcons.pawOutline,
    MdiIcons.briefcaseOutline,
    MdiIcons.notebookOutline,
    MdiIcons.coffeeOutline,
  ];

  return showDialog<IconData>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Elegir icono'),
      content: SizedBox(
        width: 520,
        child: GridView.builder(
          shrinkWrap: true,
          itemCount: icons.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final icon = icons[index];
            return InkWell(
              onTap: () => Navigator.of(context).pop(icon),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2D5C4)),
                ),
                child: Icon(icon, color: const Color(0xFF3B3A35)),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    ),
  );
}
