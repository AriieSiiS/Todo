part of 'app_shell.dart';

class HomeTwinPage extends StatefulWidget {
  const HomeTwinPage({required this.controller, this.homeAssistant, super.key});

  final TodoWorkspace controller;
  final HomeAssistantController? homeAssistant;

  @override
  State<HomeTwinPage> createState() => _HomeTwinPageState();
}

class _HomeTwinLightControls extends StatefulWidget {
  const _HomeTwinLightControls({required this.home, required this.roomId});

  final HomeAssistantController? home;
  final String roomId;

  @override
  State<_HomeTwinLightControls> createState() => _HomeTwinLightControlsState();
}

class _HomeTwinLightControlsState extends State<_HomeTwinLightControls> {
  double? _hueDraft;
  double? _saturationDraft;
  bool _editingColor = false;

  @override
  void initState() {
    super.initState();
    widget.home?.addListener(_updated);
  }

  @override
  void didUpdateWidget(covariant _HomeTwinLightControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId) {
      _hueDraft = null;
      _saturationDraft = null;
      _editingColor = false;
    }
    if (oldWidget.home == widget.home) return;
    oldWidget.home?.removeListener(_updated);
    widget.home?.addListener(_updated);
  }

  @override
  void dispose() {
    widget.home?.removeListener(_updated);
    super.dispose();
  }

  void _updated() {
    if (!mounted) return;
    if (widget.home?.commandPendingForRoom(widget.roomId) != true &&
        !_editingColor) {
      _hueDraft = null;
      _saturationDraft = null;
    }
    setState(() {});
  }

  void _send(Future<void> command) {
    unawaited(command.catchError((Object _) {}));
  }

  List<int> _rgb(double hue, double saturation) {
    final color = HSVColor.fromAHSV(1, hue, saturation, 1).toColor();
    return [
      (color.r * 255).round().clamp(0, 255),
      (color.g * 255).round().clamp(0, 255),
      (color.b * 255).round().clamp(0, 255),
    ];
  }

  void _previewColor(double hue, double saturation) {
    _editingColor = true;
    widget.home?.previewLightForRoom(
      widget.roomId,
      on: true,
      rgb: _rgb(hue, saturation),
    );
  }

  void _commitColor(double hue, double saturation) {
    _editingColor = false;
    final home = widget.home;
    if (home != null) {
      _send(home.setLightForRoom(
        widget.roomId,
        on: true,
        rgb: _rgb(hue, saturation),
      ));
    }
  }

  Future<void> _namePreset({HomeLightPreset? existing}) async {
    final home = widget.home;
    if (home == null) return;
    final nameController = TextEditingController(
      text: existing?.name ??
          'Ajuste ${home.presetsForRoom(widget.roomId).length + 1}',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null ? 'Guardar ajuste' : 'Renombrar ajuste'),
        content: TextField(
          controller: nameController,
          maxLength: 50,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, nameController.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (name == null || !mounted) return;
    try {
      if (existing == null) {
        await home.savePresetForRoom(widget.roomId, name);
      } else {
        await home.renamePreset(existing.id, name);
      }
    } on FormatException catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      }
    }
  }

  Color _presetColor(HomeLightPreset preset) {
    if (preset.colorMode == 'color_temp') {
      return _whiteColor(preset.temperature ?? 4000, 2500, 6500);
    }
    final rgb = preset.rgb ?? const [255, 181, 105];
    return Color.fromARGB(255, rgb[0], rgb[1], rgb[2]);
  }

  String _presetDescription(HomeLightPreset preset) {
    final brightness = (preset.brightness / 255 * 100).round();
    if (preset.colorMode == 'color_temp') {
      return 'Blanco · $brightness % · ${preset.temperature ?? 4000} K';
    }
    return 'Color · $brightness %';
  }

  Color _whiteColor(int kelvin, int minimum, int maximum) {
    final value = kelvin.clamp(minimum, maximum);
    if (value <= 3000) {
      return Color.lerp(
        const Color(0xFFFFD7A1),
        const Color(0xFFFFE9CA),
        ((value - 2500) / 500).clamp(0.0, 1.0),
      )!;
    }
    if (value <= 4000) {
      return Color.lerp(
        const Color(0xFFFFE9CA),
        const Color(0xFFFFFDF5),
        ((value - 3000) / 1000).clamp(0.0, 1.0),
      )!;
    }
    return Color.lerp(
      const Color(0xFFFFFDF5),
      const Color(0xFFDDEEFF),
      ((value - 4000) / 2500).clamp(0.0, 1.0),
    )!;
  }

  Widget _label(BuildContext context, String title, String value) {
    return Row(children: [
      Expanded(
        child: Text(title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ),
      Text(value,
          style: TextStyle(
              color: context.visuals.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final home = widget.home;
    if (home == null ||
        home.endpoint.isEmpty ||
        home.entityIdForRoom(widget.roomId).isEmpty) {
      return const Text(
          'Configura Home Assistant y asocia la bombilla en Ajustes.');
    }
    final light = home.lightForRoom(widget.roomId);
    if (light == null) {
      return Text(home.connected
          ? 'La bombilla asociada no aparece en Home Assistant.'
          : 'Home Assistant está sin conexión. El estado de la bombilla no está actualizado.');
    }
    final enabled = home.connected && light.available;
    final whiteMode = light.colorMode == 'color_temp';
    final rgb = light.rgb ?? const [255, 181, 105];
    final hsv = HSVColor.fromColor(Color.fromARGB(255, rgb[0], rgb[1], rgb[2]));
    final hue = _hueDraft ?? hsv.hue;
    final saturation = _saturationDraft ?? hsv.saturation;
    final minimum = light.minTemperature;
    final maximum = light.maxTemperature;
    final temperature = (light.temperature ?? 4000).clamp(minimum, maximum);
    final previewColor = whiteMode
        ? _whiteColor(temperature, minimum, maximum)
        : HSVColor.fromAHSV(1, hue, saturation, 1).toColor();
    final brightness = light.brightness / 255;
    final previewSurface = Color.lerp(
      context.visuals.panel,
      previewColor,
      whiteMode ? 0.07 : 0.09,
    )!;
    final previewIconColor = previewColor.computeLuminance() < 0.42
        ? Colors.white
        : context.visuals.textStrong.withValues(alpha: 0.70);
    final status = !enabled
        ? 'Sin conexión'
        : home.commandPendingForRoom(widget.roomId)
            ? 'Sincronizando'
            : 'En directo';
    final statusColor = !enabled
        ? context.visuals.danger
        : home.commandPendingForRoom(widget.roomId)
            ? context.visuals.accentAlt
            : context.visuals.success;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.visuals.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.visuals.panelBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.lightbulb_rounded,
              color: enabled && light.isOn
                  ? previewColor
                  : context.visuals.textMuted),
          const SizedBox(width: 9),
          const Expanded(
            child: Text('Control de luz',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
          IconButton.filledTonal(
            tooltip: light.isOn ? 'Apagar luz' : 'Encender luz',
            onPressed: enabled
                ? () =>
                    _send(home.setLightForRoom(widget.roomId, on: !light.isOn))
                : null,
            icon: Icon(light.isOn ? Icons.power_settings_new : Icons.power_off),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Container(
              width: 7,
              height: 7,
              decoration:
                  BoxDecoration(color: statusColor, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Text(status,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: statusColor)),
          const Spacer(),
          Text(light.isOn ? 'Encendida' : 'Apagada',
              style: TextStyle(fontSize: 12, color: context.visuals.textMuted)),
        ]),
        if (home.error != null) ...[
          const SizedBox(height: 8),
          Text(home.error!,
              style: TextStyle(color: context.visuals.danger, fontSize: 12)),
        ],
        const SizedBox(height: 14),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 106,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: previewSurface,
            border: Border.all(color: context.visuals.panelBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                  child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(light.isOn ? 'VISTA PREVIA' : 'AL ENCENDER',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: context.visuals.textMuted)),
                  const SizedBox(height: 4),
                  Text('${(light.brightness / 255 * 100).round()} %',
                      style: const TextStyle(
                          fontSize: 27, fontWeight: FontWeight.w800)),
                  Text(whiteMode ? 'Blanco · $temperature K' : 'Color',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: context.visuals.textMuted)),
                ],
              )),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 74,
                height: 74,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(previewSurface, previewColor, 0.17),
                  border: Border.all(color: context.visuals.panelBorder),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: previewColor,
                    border: Border.all(
                      color: context.visuals.textMuted.withValues(alpha: 0.28),
                    ),
                    boxShadow: light.isOn
                        ? [
                            BoxShadow(
                              color: previewColor.withValues(
                                alpha: 0.20 + 0.18 * brightness,
                              ),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(Icons.lightbulb_rounded,
                      size: 28, color: previewIconColor),
                ),
              ),
            ]),
          ),
        ),
        if (light.supportsBrightness) ...[
          const SizedBox(height: 18),
          _label(context, 'Intensidad',
              '${(light.brightness / 255 * 100).round()} %'),
          const SizedBox(height: 3),
          _HomeTwinGradientSlider(
            value: light.brightness.toDouble(),
            min: 1,
            max: 255,
            colors: [const Color(0xFF343332), previewColor],
            onChanged: enabled
                ? (value) => home.previewLightForRoom(widget.roomId,
                    on: true, brightness: value.round())
                : null,
            onChangeEnd: enabled
                ? (value) => _send(home.setLightForRoom(widget.roomId,
                    on: true, brightness: value.round()))
                : null,
          ),
        ],
        if (light.supportsColor && light.supportsTemperature) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Color')),
                ButtonSegment(value: true, label: Text('Blanco')),
              ],
              selected: {whiteMode},
              onSelectionChanged: enabled
                  ? (selection) {
                      if (selection.single) {
                        _send(home.setLightForRoom(widget.roomId,
                            on: true, temperature: temperature));
                      } else {
                        _send(home.setLightForRoom(widget.roomId,
                            on: true, rgb: _rgb(hue, saturation)));
                      }
                    }
                  : null,
            ),
          ),
        ],
        if (light.supportsColor && !whiteMode) ...[
          const SizedBox(height: 16),
          _label(context, 'Elige un color', 'Arrastra el punto'),
          const SizedBox(height: 10),
          Center(
            child: _HomeTwinColorWheel(
              hue: hue,
              saturation: saturation,
              enabled: enabled,
              onChanged: _previewColor,
              onChangeEnd: _commitColor,
            ),
          ),
          const SizedBox(height: 16),
          _label(context, 'Tono', '${hue.round()}°'),
          _HomeTwinGradientSlider(
            value: hue,
            min: 0,
            max: 360,
            colors: const [
              Color(0xFFE95850),
              Color(0xFFFFB84D),
              Color(0xFFF4DE57),
              Color(0xFF69C879),
              Color(0xFF55C9D6),
              Color(0xFF647FE9),
              Color(0xFFC56BD5),
              Color(0xFFE95850),
            ],
            onChanged: enabled
                ? (value) {
                    _hueDraft = value;
                    _previewColor(value, saturation);
                  }
                : null,
            onChangeEnd:
                enabled ? (value) => _commitColor(value, saturation) : null,
          ),
          const SizedBox(height: 8),
          _label(context, 'Saturación', '${(saturation * 100).round()} %'),
          _HomeTwinGradientSlider(
            value: saturation,
            min: 0,
            max: 1,
            colors: [
              const Color(0xFFF2F0EB),
              HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
            ],
            onChanged: enabled
                ? (value) {
                    _saturationDraft = value;
                    _previewColor(hue, value);
                  }
                : null,
            onChangeEnd: enabled ? (value) => _commitColor(hue, value) : null,
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final option in const [
              ('Coral', Color(0xFFFF6859)),
              ('Ámbar', Color(0xFFFFB347)),
              ('Amarillo', Color(0xFFFFD95B)),
              ('Lima', Color(0xFFACD96B)),
              ('Verde', Color(0xFF55C97B)),
              ('Turquesa', Color(0xFF55C9C2)),
              ('Azul', Color(0xFF568BEB)),
              ('Violeta', Color(0xFFBA6BE1)),
              ('Rosa', Color(0xFFE77BAA)),
              ('Melocotón', Color(0xFFFFBDA0)),
            ])
              Tooltip(
                message: option.$1,
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: enabled
                      ? () {
                          final selected = HSVColor.fromColor(option.$2);
                          _hueDraft = selected.hue;
                          _saturationDraft = selected.saturation;
                          _send(home.setLightForRoom(widget.roomId,
                              on: true,
                              rgb: _rgb(selected.hue, selected.saturation)));
                        }
                      : null,
                  child: Container(
                    width: 33,
                    height: 33,
                    decoration: BoxDecoration(
                      color: option.$2,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.visuals.panelBorder),
                    ),
                  ),
                ),
              ),
          ]),
        ],
        if (light.supportsTemperature && whiteMode) ...[
          const SizedBox(height: 16),
          _label(context, 'Temperatura', '$temperature K'),
          _HomeTwinGradientSlider(
            value: temperature.toDouble(),
            min: minimum.toDouble(),
            max: maximum.toDouble(),
            colors: const [
              Color(0xFFFFAC61),
              Color(0xFFFFF1D3),
              Color(0xFFCFE8FF)
            ],
            onChanged: enabled
                ? (value) => home.previewLightForRoom(widget.roomId,
                    on: true, temperature: value.round())
                : null,
            onChangeEnd: enabled
                ? (value) => _send(home.setLightForRoom(widget.roomId,
                    on: true, temperature: value.round()))
                : null,
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Cálida',
                style:
                    TextStyle(fontSize: 11, color: context.visuals.textMuted)),
            Text('Fría',
                style:
                    TextStyle(fontSize: 11, color: context.visuals.textMuted)),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final option in const [
              ('Cálida', 3000),
              ('Neutra', 4000),
              ('Fría', 6000),
            ])
              ActionChip(
                label: Text(option.$1),
                onPressed: enabled
                    ? () => _send(home.setLightForRoom(widget.roomId,
                        on: true,
                        temperature: option.$2.clamp(minimum, maximum)))
                    : null,
              ),
          ]),
        ],
        const SizedBox(height: 18),
        Divider(color: context.visuals.panelBorder),
        const SizedBox(height: 6),
        Row(children: [
          const Expanded(
            child: Text('Ajustes guardados',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ),
          IconButton.filledTonal(
            tooltip: 'Guardar el ajuste actual',
            onPressed: enabled ? () => unawaited(_namePreset()) : null,
            icon: const Icon(Icons.bookmark_add_outlined),
          ),
        ]),
        if (home.presetsForRoom(widget.roomId).isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
                'Guarda un color, un blanco o un brillo para recuperarlo con un clic.',
                style:
                    TextStyle(fontSize: 12, color: context.visuals.textMuted)),
          ),
        for (final preset in home.presetsForRoom(widget.roomId)) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.fromLTRB(9, 4, 1, 4),
            decoration: BoxDecoration(
              color: context.visuals.panelAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              CircleAvatar(radius: 12, backgroundColor: _presetColor(preset)),
              const SizedBox(width: 9),
              Expanded(
                child: InkWell(
                  onTap: enabled
                      ? () =>
                          _send(home.applyPresetForRoom(widget.roomId, preset))
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(preset.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                        Text(_presetDescription(preset),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                color: context.visuals.textMuted)),
                      ],
                    ),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opciones del ajuste',
                onSelected: (action) {
                  if (action == 'rename') {
                    unawaited(_namePreset(existing: preset));
                  } else if (action == 'delete') {
                    _send(home.deletePreset(preset.id));
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'El gemelo anima el encendido y el apagado gradualmente durante ${HomeAssistantController.powerFadeSeconds.toInt()} s.',
          style: TextStyle(fontSize: 12, color: context.visuals.textMuted),
        ),
        if (!enabled) ...[
          const SizedBox(height: 12),
          Text('Los controles se activarán cuando vuelva la conexión.',
              style: TextStyle(fontSize: 12, color: context.visuals.textMuted)),
        ],
      ]),
    );
  }
}

class _HomeTwinColorWheel extends StatefulWidget {
  const _HomeTwinColorWheel({
    required this.hue,
    required this.saturation,
    required this.enabled,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double hue;
  final double saturation;
  final bool enabled;
  final void Function(double hue, double saturation) onChanged;
  final void Function(double hue, double saturation) onChangeEnd;

  @override
  State<_HomeTwinColorWheel> createState() => _HomeTwinColorWheelState();
}

class _HomeTwinColorWheelState extends State<_HomeTwinColorWheel> {
  late double _hue = widget.hue;
  late double _saturation = widget.saturation;
  bool _dragging = false;

  @override
  void didUpdateWidget(covariant _HomeTwinColorWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging) {
      _hue = widget.hue;
      _saturation = widget.saturation;
    }
  }

  void _pick(Offset position) {
    final dx = position.dx - 86;
    final dy = position.dy - 86;
    final hue = (atan2(dy, dx) * 180 / pi + 360) % 360;
    final saturation = (sqrt(dx * dx + dy * dy) / 76).clamp(0.0, 1.0);
    setState(() {
      _hue = hue;
      _saturation = saturation;
    });
    widget.onChanged(hue, saturation);
  }

  void _commit() {
    _dragging = false;
    widget.onChangeEnd(_hue, _saturation);
  }

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: widget.enabled ? 1 : 0.45,
        child: GestureDetector(
          onTapDown: widget.enabled
              ? (details) {
                  _dragging = true;
                  _pick(details.localPosition);
                }
              : null,
          onTapUp: widget.enabled ? (_) => _commit() : null,
          onPanStart: widget.enabled
              ? (details) {
                  _dragging = true;
                  _pick(details.localPosition);
                }
              : null,
          onPanUpdate:
              widget.enabled ? (details) => _pick(details.localPosition) : null,
          onPanEnd: widget.enabled ? (_) => _commit() : null,
          onPanCancel: widget.enabled ? _commit : null,
          child: CustomPaint(
            size: const Size(172, 172),
            painter: _HomeTwinColorWheelPainter(_hue, _saturation),
          ),
        ),
      );
}

class _HomeTwinColorWheelPainter extends CustomPainter {
  const _HomeTwinColorWheelPainter(this.hue, this.saturation);

  final double hue;
  final double saturation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final area = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const SweepGradient(colors: [
          Color(0xFFFF0000),
          Color(0xFFFFFF00),
          Color(0xFF00FF00),
          Color(0xFF00FFFF),
          Color(0xFF0000FF),
          Color(0xFFFF00FF),
          Color(0xFFFF0000),
        ]).createShader(area),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Colors.white, Color(0x00FFFFFF)],
        ).createShader(area),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFA69D8B),
    );
    final angle = hue * pi / 180;
    final marker = Offset(
      center.dx + cos(angle) * radius * saturation,
      center.dy + sin(angle) * radius * saturation,
    );
    canvas.drawCircle(marker, 10, Paint()..color = Colors.white);
    canvas.drawCircle(
      marker,
      7,
      Paint()..color = HSVColor.fromAHSV(1, hue, saturation, 1).toColor(),
    );
  }

  @override
  bool shouldRepaint(covariant _HomeTwinColorWheelPainter oldDelegate) =>
      oldDelegate.hue != hue || oldDelegate.saturation != saturation;
}

class _HomeTwinGradientSlider extends StatelessWidget {
  const _HomeTwinGradientSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.colors,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final double min;
  final double max;
  final List<Color> colors;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 10,
        activeTrackColor: Colors.transparent,
        inactiveTrackColor: Colors.transparent,
        disabledActiveTrackColor: Colors.transparent,
        disabledInactiveTrackColor: Colors.transparent,
        thumbColor: Colors.white,
        disabledThumbColor: Colors.white70,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 17),
      ),
      child: Stack(alignment: Alignment.center, children: [
        Positioned(
          left: 22,
          right: 22,
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(colors: colors),
            ),
          ),
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ]),
    );
  }
}

class _HomeTwinPageState extends State<HomeTwinPage> {
  final HomeTwinService _home = HomeTwinService();
  late final HomeTwinWebServer _server = HomeTwinWebServer(_home);
  InAppWebViewController? _viewer;
  HomeTwinScene? _scene;
  String? _url;
  String? _error;
  HomeTwinRoom? _selectedRoom;
  HomeTwinObject? _selectedObject;
  Map<String, dynamic>? _pendingVisualState;
  bool _sendingVisualState = false;
  bool _viewerReady = false;
  Map<String, bool> _windowsOpen = {};
  String? _weatherPreview;
  String? _weatherDetailsKey;
  Map<String, dynamic>? _pendingEnvironment;
  bool _sendingEnvironment = false;

  @override
  void initState() {
    super.initState();
    widget.homeAssistant?.addListener(_homeAssistantChanged);
    _load();
  }

  @override
  void dispose() {
    widget.homeAssistant?.removeListener(_homeAssistantChanged);
    unawaited(_server.stop());
    super.dispose();
  }

  void _homeAssistantChanged() {
    if (!mounted) return;
    unawaited(_sendLightToViewer());
    unawaited(_sendHallwayLightToViewer());
    unawaited(_sendSecondRoomLightToViewer());
    final weatherKey = jsonEncode({
      ...?widget.homeAssistant?.weatherVisualState,
      'entityId': widget.homeAssistant?.weatherEntityId,
    });
    if (_weatherDetailsKey != weatherKey) {
      _weatherDetailsKey = weatherKey;
      setState(() {});
      unawaited(_sendEnvironmentToViewer());
    }
  }

  Map<String, dynamic> _environmentState() {
    final state = Map<String, dynamic>.from(
        widget.homeAssistant?.weatherVisualState ?? const {});
    final preview = _weatherPreview;
    if (preview != null) {
      state['condition'] = switch (preview) {
        'frio' ||
        'calor' ||
        'madrugada' ||
        'atardecer' ||
        'tarde_noche' =>
          'sunny',
        'noche' => 'clear-night',
        _ => preview,
      };
      state['timeScene'] = preview;
      state['temperatureC'] = switch (preview) {
        'frio' => 8.0,
        'calor' => 32.0,
        _ => 22.0,
      };
      state['sunAboveHorizon'] = preview != 'noche';
      state['sunElevation'] = preview == 'noche' ? -18.0 : 38.0;
      state['stale'] = false;
      state['preview'] = true;
    }
    return state;
  }

  Future<void> _sendEnvironmentToViewer() async {
    if (!_viewerReady || _viewer == null) return;
    _pendingEnvironment = {
      'weather': _environmentState(),
      'windows': {
        for (final room in _scene?.rooms ?? [])
          room.id: (_windowsOpen[room.id] ?? false) || _weatherPreview != null,
      },
    };
    if (_sendingEnvironment) return;
    _sendingEnvironment = true;
    try {
      while (mounted && _viewerReady && _pendingEnvironment != null) {
        final value = _pendingEnvironment!;
        _pendingEnvironment = null;
        try {
          await _viewer!.evaluateJavascript(
            source:
                'window.actualizarAmbiente(${jsonEncode(value['weather'])});'
                'window.actualizarPersianas(${jsonEncode(value['windows'])})',
          );
        } catch (_) {
          // El visor puede estar recargando la habitación.
        }
      }
    } finally {
      _sendingEnvironment = false;
    }
  }

  Future<void> _toggleWindow(String roomId) async {
    final next = !(_windowsOpen[roomId] ?? false);
    setState(() {
      _weatherPreview = null;
      _windowsOpen[roomId] = next;
    });
    await _sendEnvironmentToViewer();
    try {
      await _home.saveWindowOpen(next, roomId);
    } catch (_) {
      if (mounted) {
        if (_windowsOpen[roomId] == next) {
          setState(() => _windowsOpen[roomId] = !next);
        }
        await _sendEnvironmentToViewer();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No se pudo guardar la posición de la persiana.'),
          ));
        }
      }
    }
  }

  Future<void> _toggleLightFromSwitch(String roomId) async {
    final home = widget.homeAssistant;
    final light = home?.lightForRoom(roomId);
    if (home == null || !home.connected || light == null || !light.available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('La bombilla no está disponible en Home Assistant.'),
        ));
      }
      return;
    }
    try {
      await home.setLightForRoom(roomId, on: !light.isOn);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo cambiar la luz.'),
        ));
      }
    }
  }

  void _previewWeather(String? scene) {
    setState(() => _weatherPreview = scene);
    unawaited(_sendEnvironmentToViewer());
  }

  Future<void> _sendLightToViewer() async {
    final light = widget.homeAssistant?.selectedLight;
    if (!_viewerReady || _viewer == null || light == null) return;
    _pendingVisualState = {
      ...light.toVisualState(),
      'powerTransitionMs':
          (HomeAssistantController.powerFadeSeconds * 1000).round(),
    };
    if (_sendingVisualState) return;
    _sendingVisualState = true;
    try {
      while (mounted && _viewerReady && _pendingVisualState != null) {
        final state = _pendingVisualState!;
        _pendingVisualState = null;
        try {
          await _viewer!.evaluateJavascript(
            source: 'window.actualizarLuz(${jsonEncode(state)})',
          );
        } catch (_) {
          // El visor puede estar recargando la habitación.
        }
      }
    } finally {
      _sendingVisualState = false;
    }
  }

  Future<void> _sendHallwayLightToViewer() async {
    final light = widget.homeAssistant?.hallwayLight;
    if (!_viewerReady || _viewer == null || light == null) return;
    final state = light.toVisualState(
      roomId: 'pasillo',
      objectId: 'luz_pasillo',
    );
    state['powerTransitionMs'] =
        (HomeAssistantController.powerFadeSeconds * 1000).round();
    try {
      await _viewer!.evaluateJavascript(
        source: 'window.actualizarLuzPasillo(${jsonEncode(state)})',
      );
    } catch (_) {
      // El visor puede estar recargando el pasillo.
    }
  }

  Future<void> _sendSecondRoomLightToViewer() async {
    final light = widget.homeAssistant?.secondRoomLight;
    if (!_viewerReady || _viewer == null || light == null) return;
    final state = light.toVisualState(
      roomId: 'habitacion_vacia',
      objectId: 'luz_techo',
    );
    state['powerTransitionMs'] =
        (HomeAssistantController.powerFadeSeconds * 1000).round();
    try {
      await _viewer!.evaluateJavascript(
        source: 'window.actualizarLuzSegundaHabitacion(${jsonEncode(state)})',
      );
    } catch (_) {
      // El visor puede estar recargando el dormitorio.
    }
  }

  Future<void> _load() async {
    try {
      final scene = await _home.load();
      final windowsOpen = {
        for (final room in scene.rooms)
          room.id: await _home.loadWindowOpen(room.id),
      };
      final url = Platform.isWindows && scene.rooms.isNotEmpty
          ? await _server.start()
          : null;
      if (!mounted) return;
      setState(() {
        _scene = scene;
        _windowsOpen = windowsOpen;
        _url = url == null
            ? null
            : Uri.parse(url)
                .replace(queryParameters: const {'deselect': '1'}).toString();
        _error = null;
        _selectedRoom = scene.rooms
            .where((room) => room.id == _selectedRoom?.id)
            .firstOrNull;
        _selectedObject = null;
      });
      if (_viewer != null && url != null) {
        _viewerReady = false;
        final refreshedUrl = Uri.parse(_url!).replace(queryParameters: {
          ...Uri.parse(_url!).queryParameters,
          'revision': DateTime.now().microsecondsSinceEpoch.toString(),
        });
        await _viewer!.loadUrl(
          urlRequest: URLRequest(url: WebUri(refreshedUrl.toString())),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  void _selectObject(List<dynamic> arguments) {
    if (arguments.length != 2 || !mounted) return;
    final roomId = arguments[0];
    final objectId = arguments[1];
    final room =
        _scene?.rooms.where((candidate) => candidate.id == roomId).firstOrNull;
    final object = room?.objects
        .where((candidate) => candidate.id == objectId)
        .firstOrNull;
    if (room == null || object == null || !_hasControls(room, object)) return;
    setState(() {
      _selectedRoom = room;
      _selectedObject = object;
    });
  }

  void _clearSelectedObject() {
    if (!mounted || (_selectedRoom == null && _selectedObject == null)) return;
    setState(() {
      _selectedRoom = null;
      _selectedObject = null;
    });
  }

  bool _hasControls(HomeTwinRoom room, HomeTwinObject object) =>
      object.id == 'ventana' ||
      (room.id == 'dormitorio' && object.id == 'echo_dot') ||
      ((room.id == 'dormitorio' || room.id == 'habitacion_vacia') &&
          object.id == 'luz_techo') ||
      (room.id == 'pasillo' && object.id == 'luz_pasillo');

  Future<void> _focusDevice(HomeTwinRoom room, HomeTwinObject object) async {
    if (!_hasControls(room, object)) return;
    setState(() {
      _selectedRoom = room;
      _selectedObject = object;
    });
    await _viewer?.evaluateJavascript(
      source:
          'window.enfocarObjeto(${jsonEncode(room.id)}, ${jsonEncode(object.id)})',
    );
  }

  Future<void> _focusRoom(HomeTwinRoom room) async {
    setState(() {
      _selectedRoom = room;
      _selectedObject = null;
    });
    await _viewer?.evaluateJavascript(
      source: 'window.enfocarHabitacion(${jsonEncode(room.id)})',
    );
  }

  Future<void> _focusHouse() async {
    setState(() {
      _selectedRoom = null;
      _selectedObject = null;
    });
    await _viewer?.evaluateJavascript(source: 'window.enfocarCasa()');
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return const Center(
          child: Text('El gemelo 3D está disponible en Windows.'));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No se pudo cargar el gemelo de la casa.'),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: context.visuals.textMuted)),
            TextButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_scene == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_scene!.rooms.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.view_in_ar_rounded,
                  size: 68, color: context.visuals.accent),
              const SizedBox(height: 16),
              const Text(
                'Tu casa empezará por tu habitación',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 9),
              Text(
                'Cuando preparemos la maqueta con tus fotos y medidas, aparecerá aquí. Después añadiremos las demás habitaciones a la misma casa.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.visuals.textMuted),
              ),
              const SizedBox(height: 15),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Buscar habitaciones nuevas'),
              ),
            ],
          ),
        ),
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 780;
      final viewer = ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: _url == null
            ? const Center(child: CircularProgressIndicator())
            : InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(_url!)),
                initialSettings: InAppWebViewSettings(
                  supportZoom: false,
                  transparentBackground: true,
                  javaScriptEnabled: true,
                  supportMultipleWindows: false,
                  mediaPlaybackRequiresUserGesture: false,
                ),
                onWebViewCreated: (viewer) {
                  _viewer = viewer;
                  viewer.addJavaScriptHandler(
                    handlerName: 'seleccionarObjeto',
                    callback: _selectObject,
                  );
                  viewer.addJavaScriptHandler(
                    handlerName: 'deseleccionarObjeto',
                    callback: (_) => _clearSelectedObject(),
                  );
                  viewer.addJavaScriptHandler(
                    handlerName: 'alternarPersiana',
                    callback: (arguments) => _toggleWindow(
                      arguments.isNotEmpty && arguments.first is String
                          ? arguments.first as String
                          : 'dormitorio',
                    ),
                  );
                  viewer.addJavaScriptHandler(
                    handlerName: 'alternarInterruptorLuz',
                    callback: (arguments) => _toggleLightFromSwitch(
                      arguments.isNotEmpty && arguments.first is String
                          ? arguments.first as String
                          : 'dormitorio',
                    ),
                  );
                },
                onLoadStart: (_, __) => _viewerReady = false,
                onLoadStop: (_, __) {
                  _viewerReady = true;
                  unawaited(_sendLightToViewer());
                  unawaited(_sendHallwayLightToViewer());
                  unawaited(_sendSecondRoomLightToViewer());
                  unawaited(_sendEnvironmentToViewer());
                },
              ),
      );
      final details = _details(context);
      return Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Arrastra para girar · rueda para acercar · pulsa la luz o la persiana',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Ver toda la casa',
                onPressed: _focusHouse,
                icon: const Icon(Icons.home_outlined),
              ),
              IconButton(
                tooltip: 'Actualizar maqueta',
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: narrow
                ? Column(children: [
                    Expanded(child: viewer),
                    const SizedBox(height: 10),
                    SizedBox(height: 280, child: details),
                  ])
                : Row(children: [
                    Expanded(child: viewer),
                    const SizedBox(width: 12),
                    SizedBox(width: 320, child: details),
                  ]),
          ),
        ],
      );
    });
  }

  Widget _details(BuildContext context) {
    final linkedItem = _selectedObject?.householdItemId == null
        ? null
        : widget.controller.householdItemById(
            _selectedObject!.householdItemId!,
          );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.visuals.panelAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.visuals.pageBorder),
      ),
      child: SingleChildScrollView(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Habitaciones (${_scene!.rooms.length})',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SizedBox(
            height: (_scene!.rooms.length * 52.0 + 12).clamp(72.0, 220.0),
            child: ListView(
              children: [
                for (final room in _scene!.rooms)
                  ListTile(
                    dense: true,
                    selected: room.id == _selectedRoom?.id,
                    title: Text(room.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final object in room.objects)
                          if (_hasControls(room, object) &&
                              object.id != 'ventana')
                            IconButton.filledTonal(
                              tooltip: 'Ir a ${object.name.toLowerCase()}',
                              onPressed: () => _focusDevice(room, object),
                              icon: Icon(object.id == 'echo_dot'
                                  ? Icons.speaker_rounded
                                  : Icons.lightbulb_outline_rounded),
                            ),
                      ],
                    ),
                    onTap: () => _focusRoom(room),
                  ),
              ],
            ),
          ),
          const Divider(),
          if (_selectedObject == null)
            Text(
              'Pulsa la luz o la persiana de la maqueta para abrir sus controles.',
              style: TextStyle(color: context.visuals.textMuted),
            )
          else ...[
            Text(_selectedObject!.name,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(_selectedRoom?.name ?? '',
                style: TextStyle(color: context.visuals.textMuted)),
            if (linkedItem != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Abrir ficha'),
                onPressed: () => _showHouseholdDetail(
                  context,
                  widget.controller,
                  linkedItem,
                ),
              ),
            ],
            if (_selectedObject!.id == 'luz_techo' ||
                _selectedObject!.id == 'luz_pasillo') ...[
              const SizedBox(height: 12),
              _HomeTwinLightControls(
                home: widget.homeAssistant,
                roomId: _selectedRoom!.id,
              ),
            ],
            if (_selectedObject!.id == 'echo_dot') ...[
              const SizedBox(height: 12),
              _HomeTwinEchoControls(home: widget.homeAssistant),
            ],
            if (_selectedObject!.id == 'ventana') ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _toggleWindow(_selectedRoom!.id),
                icon: Icon((_windowsOpen[_selectedRoom?.id] ?? false)
                    ? Icons.blinds_closed
                    : Icons.blinds),
                label: Text((_windowsOpen[_selectedRoom?.id] ?? false)
                    ? 'Bajar persiana'
                    : 'Subir persiana'),
              ),
              const SizedBox(height: 12),
              Text(_weatherPreview != null
                  ? 'Vista previa · la persiana volverá a su posición anterior'
                  : widget.homeAssistant?.weatherVisualState['stale'] == true
                      ? 'Tiempo sin actualizar · se muestra el último dato disponible'
                      : 'Tiempo actual de Home Assistant'),
              if (widget.homeAssistant?.selectedWeather case final weather?)
                Text(
                    '${weather.name} · ${weather.temperatureC?.toStringAsFixed(1) ?? '—'} °C'),
              const SizedBox(height: 10),
              const Text('Probar escenas'),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final (name, condition) in const [
                  ('Despejado', 'sunny'),
                  ('Nublado', 'cloudy'),
                  ('Lluvia', 'rainy'),
                  ('Tormenta', 'lightning-rainy'),
                  ('Niebla', 'fog'),
                  ('Frío', 'frio'),
                  ('Calor', 'calor'),
                  ('Madrugada', 'madrugada'),
                  ('Atardecer', 'atardecer'),
                  ('Tarde noche', 'tarde_noche'),
                  ('Noche', 'noche'),
                ])
                  ChoiceChip(
                    label: Text(name),
                    selected: _weatherPreview == condition,
                    onSelected: (_) => _previewWeather(condition),
                  ),
              ]),
              if (_weatherPreview != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _previewWeather(null),
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('Volver al tiempo real'),
                ),
              ],
            ],
          ],
        ],
      )),
    );
  }
}
