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
  final hasTime = _hasVisibleTimeOfDay(initialTime);
  return showDialog<TimeOfDay>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.38),
    builder: (context) => _TodoTimePickerDialog(
      initialTime:
          hasTime ? initialTime : TimeOfDay.fromDateTime(DateTime.now()),
      startsWithoutTime: !hasTime,
    ),
  );
}

class _TodoTimePickerDialog extends StatefulWidget {
  const _TodoTimePickerDialog({
    required this.initialTime,
    required this.startsWithoutTime,
  });

  final TimeOfDay initialTime;
  final bool startsWithoutTime;

  @override
  State<_TodoTimePickerDialog> createState() => _TodoTimePickerDialogState();
}

class _TodoTimePickerDialogState extends State<_TodoTimePickerDialog> {
  static const _loopAnchor = 6000;

  late int _hour;
  late int _minute;
  late bool _withoutTime;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    _withoutTime = widget.startsWithoutTime;
    _hourController = FixedExtentScrollController(
      initialItem: _initialItem(24, _hour),
    );
    _minuteController = FixedExtentScrollController(
      initialItem: _initialItem(60, _minute),
    );
  }

  int _initialItem(int count, int value) =>
      _loopAnchor - (_loopAnchor % count) + value;

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  void _setTime(DateTime value) {
    setState(() {
      _hour = value.hour;
      _minute = value.minute;
      _withoutTime = false;
    });
    _moveWheel(_hourController, 24, _hour);
    _moveWheel(_minuteController, 60, _minute);
  }

  void _moveWheel(
    FixedExtentScrollController controller,
    int count,
    int value,
  ) {
    final current = controller.hasClients
        ? controller.selectedItem
        : _initialItem(count, value);
    final cycleStart = current - (current % count);
    final candidates = <int>[
      cycleStart + value,
      cycleStart + value - count,
      cycleStart + value + count,
    ];
    candidates.sort(
      (a, b) => (a - current).abs().compareTo((b - current).abs()),
    );
    controller.animateToItem(
      candidates.first,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _stepWheel(
    FixedExtentScrollController controller,
    int delta,
  ) {
    if (!controller.hasClients) return;
    controller.animateToItem(
      controller.selectedItem + delta,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _wheel({
    required String label,
    required int count,
    required int selectedValue,
    required FixedExtentScrollController controller,
    required ValueChanged<int> onChanged,
    required String keyPrefix,
    required double height,
  }) {
    const itemExtent = 47.0;
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Container(
            height: height,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F2EC),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                IconButton(
                  key: ValueKey('$keyPrefix-decrementar'),
                  tooltip: 'Valor anterior',
                  onPressed: () => _stepWheel(controller, -1),
                  icon: const Icon(Icons.arrow_drop_up_rounded, size: 30),
                ),
                Expanded(
                  child: Listener(
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent &&
                          event.scrollDelta.dy != 0) {
                        _stepWheel(
                          controller,
                          event.scrollDelta.dy > 0 ? 1 : -1,
                        );
                      }
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: Center(
                            child: Container(
                              height: itemExtent,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF70835D),
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                        ListWheelScrollView.useDelegate(
                          key: ValueKey('$keyPrefix-rueda'),
                          controller: controller,
                          itemExtent: itemExtent,
                          diameterRatio: 2.15,
                          perspective: 0.0025,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (index) {
                            final value = index % count;
                            if (value == selectedValue && !_withoutTime) return;
                            setState(() {
                              onChanged(value);
                              _withoutTime = false;
                            });
                          },
                          childDelegate: ListWheelChildLoopingListDelegate(
                            children: [
                              for (var value = 0; value < count; value++)
                                Center(
                                  child: Text(
                                    _twoDigits(value),
                                    style: TextStyle(
                                      color: value == selectedValue
                                          ? Colors.white
                                          : const Color(0xFF6E6961),
                                      fontSize:
                                          value == selectedValue ? 28 : 22,
                                      fontWeight: value == selectedValue
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  key: ValueKey('$keyPrefix-incrementar'),
                  tooltip: 'Valor siguiente',
                  onPressed: () => _stepWheel(controller, 1),
                  icon: const Icon(Icons.arrow_drop_down_rounded, size: 30),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAction({
    required Key key,
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    bool selected = false,
  }) {
    return SizedBox(
      height: 48,
      child: FilledButton.tonalIcon(
        key: key,
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 19),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor:
              selected ? const Color(0xFFDCE7D0) : const Color(0xFFF3F0E9),
          foregroundColor: const Color(0xFF3E4934),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final compact = screen.width < 520;
    final wheelHeight = compact ? 228.0 : 286.0;
    final now = DateTime.now;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 24,
        vertical: 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 610,
          maxHeight: screen.height - 32,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF8),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE2D5C4)),
            boxShadow: const [
              BoxShadow(
                blurRadius: 30,
                color: Color(0x26000000),
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              compact ? 18 : 34,
              compact ? 18 : 28,
              compact ? 18 : 34,
              compact ? 18 : 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                            'Seleccionar hora',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Elige una hora para esta tarea',
                            style: TextStyle(
                              color: Color(0xFF7A7369),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('selector-hora-cerrar'),
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 18 : 26),
                Center(
                  child: AnimatedContainer(
                    key: const ValueKey('selector-hora-valor'),
                    duration: const Duration(milliseconds: 160),
                    width: compact ? double.infinity : 410,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF1E7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _withoutTime
                          ? 'Sin hora'
                          : '${_twoDigits(_hour)}:${_twoDigits(_minute)}',
                      style: TextStyle(
                        color: const Color(0xFF263E20),
                        fontSize: compact ? 44 : 62,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _wheel(
                      label: 'Hora',
                      count: 24,
                      selectedValue: _hour,
                      controller: _hourController,
                      onChanged: (value) => _hour = value,
                      keyPrefix: 'selector-hora',
                      height: wheelHeight,
                    ),
                    SizedBox(width: compact ? 10 : 24),
                    Container(
                      width: 1,
                      height: wheelHeight - 24,
                      color: const Color(0xFFE6DED2),
                    ),
                    SizedBox(width: compact ? 10 : 24),
                    _wheel(
                      label: 'Minutos',
                      count: 60,
                      selectedValue: _minute,
                      controller: _minuteController,
                      onChanged: (value) => _minute = value,
                      keyPrefix: 'selector-minutos',
                      height: wheelHeight,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(color: Color(0xFFE4DACE)),
                const SizedBox(height: 16),
                if (compact)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _quickAction(
                        key: const ValueKey('selector-hora-ahora'),
                        label: 'Ahora',
                        icon: Icons.schedule_rounded,
                        onPressed: () => _setTime(now()),
                      ),
                      _quickAction(
                        key: const ValueKey('selector-hora-mas-30'),
                        label: '+30 min',
                        onPressed: () =>
                            _setTime(now().add(const Duration(minutes: 30))),
                      ),
                      _quickAction(
                        key: const ValueKey('selector-hora-sin-hora'),
                        label: 'Sin hora',
                        selected: _withoutTime,
                        onPressed: () => setState(() => _withoutTime = true),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _quickAction(
                          key: const ValueKey('selector-hora-ahora'),
                          label: 'Ahora',
                          icon: Icons.schedule_rounded,
                          onPressed: () => _setTime(now()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _quickAction(
                          key: const ValueKey('selector-hora-mas-30'),
                          label: '+30 min',
                          onPressed: () => _setTime(
                            now().add(const Duration(minutes: 30)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _quickAction(
                          key: const ValueKey('selector-hora-sin-hora'),
                          label: 'Sin hora',
                          selected: _withoutTime,
                          onPressed: () => setState(() => _withoutTime = true),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      key: const ValueKey('selector-hora-cancelar'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      key: const ValueKey('selector-hora-aceptar'),
                      onPressed: () => Navigator.of(context).pop(
                        _withoutTime
                            ? const TimeOfDay(hour: 0, minute: 0)
                            : TimeOfDay(hour: _hour, minute: _minute),
                      ),
                      child: const Text('Aceptar'),
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
                            0,
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
                                    effectiveMinutes == 0
                                        ? 'El aviso coincidirá con la hora programada de la tarea.'
                                        : 'Si la tarea es a las 09:00, el aviso llegará antes según esta configuración.',
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
                                  'Se aplicará a las nuevas tareas que crees.',
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
  if (minutes == 0) {
    return 'A la hora exacta';
  }
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
