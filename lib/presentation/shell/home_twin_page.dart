part of 'app_shell.dart';

class HomeTwinPage extends StatefulWidget {
  const HomeTwinPage({required this.controller, super.key});

  final TodoWorkspace controller;

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    unawaited(_server.stop());
    super.dispose();
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
                    SizedBox(height: 160, child: details),
                  ])
                : Row(children: [
                    Expanded(child: viewer),
                    const SizedBox(width: 12),
                    SizedBox(width: 246, child: details),
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
          ],
        ],
      ),
    );
  }
}
