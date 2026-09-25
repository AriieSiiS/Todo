part of 'app_shell.dart';

class HomeTwinPage extends StatefulWidget {
  const HomeTwinPage({required this.controller, this.homeAssistant, super.key});

  final TodoWorkspace controller;
  final HomeAssistantController? homeAssistant;

  @override
  State<HomeTwinPage> createState() => _HomeTwinPageState();
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
  double? _brightnessDraft;
  double? _temperatureDraft;
  double? _hueDraft;
  double? _saturationDraft;
  bool _viewerReady = false;

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
    setState(() {});
    unawaited(_sendLightToViewer());
  }

  Future<void> _sendLightToViewer() async {
    final light = widget.homeAssistant?.selectedLight;
    if (!_viewerReady || _viewer == null || light == null) return;
    try {
      await _viewer!.evaluateJavascript(
        source: 'window.actualizarLuz(${jsonEncode(light.toVisualState())})',
      );
    } catch (_) {
      // El visor puede estar recargando la habitación.
    }
  }

  Future<void> _sendLight({
    required bool on,
    int? brightness,
    List<int>? rgb,
    int? temperature,
  }) async {
    try {
      await widget.homeAssistant?.setLight(
        on: on,
        brightness: brightness,
        rgb: rgb,
        temperature: temperature,
      );
    } catch (_) {
      // El error de la conexión se muestra junto a los controles.
    }
  }

  Future<void> _load() async {
    try {
      final scene = await _home.load();
      final url = Platform.isWindows && scene.rooms.isNotEmpty
          ? await _server.start()
          : null;
      if (!mounted) return;
      setState(() {
        _scene = scene;
        _url = url;
        _error = null;
        _selectedRoom = scene.rooms
            .where((room) => room.id == _selectedRoom?.id)
            .firstOrNull;
        _selectedObject = null;
      });
      if (_viewer != null && url != null) {
        await _viewer!.reload();
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
    if (room == null || object == null) return;
    setState(() {
      _selectedRoom = room;
      _selectedObject = object;
    });
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
                ),
                onWebViewCreated: (viewer) {
                  _viewer = viewer;
                  viewer.addJavaScriptHandler(
                    handlerName: 'seleccionarObjeto',
                    callback: _selectObject,
                  );
                },
                onLoadStart: (_, __) => _viewerReady = false,
                onLoadStop: (_, __) {
                  _viewerReady = true;
                  unawaited(_sendLightToViewer());
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
                  'Arrastra para girar · rueda para acercar · pulsa un objeto para verlo',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Ver toda la casa',
                onPressed: () =>
                    _viewer?.evaluateJavascript(source: 'window.enfocarCasa()'),
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
                    SizedBox(width: 292, child: details),
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
            height: 72,
            child: ListView(
              children: [
                for (final room in _scene!.rooms)
                  ListTile(
                    dense: true,
                    selected: room.id == _selectedRoom?.id,
                    title: Text(room.name),
                    onTap: () => _focusRoom(room),
                  ),
              ],
            ),
          ),
          const Divider(),
          if (_selectedObject == null)
            Text(
              'Selecciona un objeto de la maqueta para ver su información.',
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
            if (_selectedObject!.id == 'luz_techo') ...[
              const SizedBox(height: 12),
              _lightControls(context),
            ],
          ],
        ],
      )),
    );
  }

  Widget _lightControls(BuildContext context) {
    final home = widget.homeAssistant;
    if (home == null || home.endpoint.isEmpty || home.entityId.isEmpty) {
      return const Text(
          'Configura Home Assistant y asocia la bombilla en Ajustes.');
    }
    final light = home.selectedLight;
    final enabled =
        home.connected && light?.available == true && !home.commandPending;
    if (light == null) {
      return Text(home.connected
          ? 'La bombilla asociada no aparece en Home Assistant.'
          : 'Home Assistant está sin conexión. El estado de la bombilla no está actualizado.');
    }
    final rgb = light.rgb ?? const [255, 245, 225];
    final hsv = HSVColor.fromColor(Color.fromARGB(255, rgb[0], rgb[1], rgb[2]));
    final brightness = _brightnessDraft ?? light.brightness.toDouble();
    final minimum = light.minTemperature.toDouble();
    final maximum = light.maxTemperature.toDouble();
    final temperature =
        (_temperatureDraft ?? (light.temperature ?? minimum.toInt()).toDouble())
            .clamp(minimum, maximum);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(home.connected && light.available
            ? light.isOn
                ? 'Encendida'
                : 'Apagada'
            : 'Sin conexión · estado desactualizado'),
        if (home.error != null) ...[
          const SizedBox(height: 5),
          Text(home.error!, style: const TextStyle(color: Color(0xFF9D4436))),
        ],
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Luz del techo'),
          value: light.isOn,
          onChanged:
              enabled ? (value) => unawaited(_sendLight(on: value)) : null,
        ),
        if (light.supportsBrightness) ...[
          Text('Brillo · ${(brightness / 255 * 100).round()} %'),
          Slider(
            value: brightness.clamp(1, 255),
            min: 1,
            max: 255,
            onChanged: enabled
                ? (value) => setState(() => _brightnessDraft = value)
                : null,
            onChangeEnd: enabled
                ? (value) {
                    setState(() => _brightnessDraft = null);
                    unawaited(_sendLight(on: true, brightness: value.round()));
                  }
                : null,
          ),
        ],
        if (light.supportsColor) ...[
          const Text('Color'),
          Slider(
            value: _hueDraft ?? hsv.hue,
            min: 0,
            max: 360,
            onChanged:
                enabled ? (value) => setState(() => _hueDraft = value) : null,
          ),
          Text(
              'Saturación · ${((_saturationDraft ?? hsv.saturation) * 100).round()} %'),
          Slider(
            value: _saturationDraft ?? hsv.saturation,
            min: 0,
            max: 1,
            onChanged: enabled
                ? (value) => setState(() => _saturationDraft = value)
                : null,
          ),
          OutlinedButton.icon(
            onPressed: enabled
                ? () {
                    final selected = HSVColor.fromAHSV(
                      1,
                      _hueDraft ?? hsv.hue,
                      _saturationDraft ?? hsv.saturation,
                      1,
                    ).toColor();
                    setState(() {
                      _hueDraft = null;
                      _saturationDraft = null;
                    });
                    unawaited(_sendLight(on: true, rgb: [
                      (selected.r * 255).round().clamp(0, 255),
                      (selected.g * 255).round().clamp(0, 255),
                      (selected.b * 255).round().clamp(0, 255),
                    ]));
                  }
                : null,
            icon: const Icon(Icons.palette_outlined),
            label: const Text('Aplicar color'),
          ),
        ],
        if (light.supportsTemperature) ...[
          const SizedBox(height: 8),
          Text('Blanco · ${temperature.round()} K'),
          Slider(
            value: temperature,
            min: minimum,
            max: maximum,
            onChanged: enabled
                ? (value) => setState(() => _temperatureDraft = value)
                : null,
            onChangeEnd: enabled
                ? (value) {
                    setState(() => _temperatureDraft = null);
                    unawaited(_sendLight(on: true, temperature: value.round()));
                  }
                : null,
          ),
        ],
      ],
    );
  }
}
