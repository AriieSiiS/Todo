part of 'app_shell.dart';

class HomeAssistantSettingsCard extends StatefulWidget {
  const HomeAssistantSettingsCard({required this.controller, super.key});

  final HomeAssistantController controller;

  @override
  State<HomeAssistantSettingsCard> createState() =>
      _HomeAssistantSettingsCardState();
}

class _HomeAssistantSettingsCardState extends State<HomeAssistantSettingsCard> {
  late final TextEditingController _url;
  final TextEditingController _token = TextEditingController();
  bool _editedUrl = false;
  bool _busy = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(
      text: widget.controller.endpoint.isEmpty
          ? 'http://homeassistant.local'
          : widget.controller.endpoint,
    );
    widget.controller.addListener(_updated);
  }

  void _updated() {
    if (!mounted) return;
    if (!_editedUrl &&
        widget.controller.endpoint.isNotEmpty &&
        _url.text != widget.controller.endpoint) {
      _url.text = widget.controller.endpoint;
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updated);
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _localError = null;
    });
    try {
      await widget.controller.configure(
        url: _url.text,
        newToken: _token.text,
        selectedEntityId: widget.controller.entityId,
      );
      _token.clear();
      _editedUrl = false;
    } catch (error) {
      _localError = error is FormatException
          ? error.message
          : 'No se pudo guardar la conexión.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bind(String id) async {
    setState(() {
      _busy = true;
      _localError = null;
    });
    try {
      await widget.controller.bindLight(id);
    } catch (_) {
      _localError = 'No se pudo asociar la bombilla.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bindHallway(String id) async {
    setState(() {
      _busy = true;
      _localError = null;
    });
    try {
      await widget.controller.bindHallwayLight(id);
    } on FormatException catch (error) {
      _localError = error.message;
    } catch (_) {
      _localError = 'No se pudo asociar la bombilla del pasillo.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bindSecondRoom(String id) async {
    setState(() {
      _busy = true;
      _localError = null;
    });
    try {
      await widget.controller.bindSecondRoomLight(id);
    } on FormatException catch (error) {
      _localError = error.message;
    } catch (_) {
      _localError = 'No se pudo asociar la bombilla del dormitorio.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bindWeather(String id) async {
    setState(() {
      _busy = true;
      _localError = null;
    });
    try {
      await widget.controller.bindWeather(id);
    } catch (_) {
      _localError = 'No se pudo asociar la entidad meteorológica.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bindEcho(String id) async {
    setState(() {
      _busy = true;
      _localError = null;
    });
    try {
      await widget.controller.bindEcho(id);
    } on FormatException catch (error) {
      _localError = error.message;
    } catch (_) {
      _localError = 'No se pudo asociar el Echo.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = widget.controller;
    final available = home.lights;
    final selected = available.any((item) => item.entityId == home.entityId)
        ? home.entityId
        : null;
    final status = home.connected
        ? 'Conectado'
        : home.connecting
            ? 'Conectando…'
            : 'Sin conexión';
    return _SettingsSectionCard(
      icon: Icons.lightbulb_outline_rounded,
      title: 'Home Assistant · luz y tiempo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Estado: $status'),
          const SizedBox(height: 10),
          TextField(
            controller: _url,
            onChanged: (_) => _editedUrl = true,
            decoration: const InputDecoration(
              labelText: 'Dirección local de Home Assistant',
              hintText: 'http://192.168.1.50:8123',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _token,
            obscureText: true,
            decoration: InputDecoration(
              labelText: home.hasToken
                  ? 'Nuevo token (dejar vacío para conservar el actual)'
                  : 'Token de acceso de larga duración',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar y conectar'),
            ),
            OutlinedButton.icon(
              onPressed:
                  _busy || home.endpoint.isEmpty ? null : () => home.connect(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Probar conexión'),
            ),
          ]),
          if (_busy || home.connecting) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_localError != null || home.error != null) ...[
            const SizedBox(height: 10),
            Text(_localError ?? home.error!,
                style: const TextStyle(color: Color(0xFF9D4436))),
          ],
          const Divider(height: 28),
          Text(
            'Bombilla asociada a la luz del techo',
            style: TextStyle(color: context.visuals.textMuted),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey('home-assistant-light-$selected'),
            initialValue: selected,
            hint: const Text('Selecciona la bombilla'),
            isExpanded: true,
            items: [
              for (final light in available)
                DropdownMenuItem(
                  value: light.entityId,
                  child: Text('${light.name} · ${light.entityId}',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _busy || !home.connected
                ? null
                : (id) {
                    if (id != null) unawaited(_bind(id));
                  },
          ),
          if (home.entityId.isNotEmpty && selected == null) ...[
            const SizedBox(height: 8),
            Text('La entidad ${home.entityId} no aparece en Home Assistant.'),
          ],
          const Divider(height: 28),
          Text(
            'Bombilla del pasillo',
            style: TextStyle(color: context.visuals.textMuted),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey('home-assistant-hallway-${home.hallwayEntityId}'),
            initialValue: available.any((item) =>
                    item.entityId == home.hallwayEntityId &&
                    item.entityId != home.entityId)
                ? home.hallwayEntityId
                : null,
            hint: const Text('Selecciona la bombilla del pasillo'),
            isExpanded: true,
            items: [
              for (final light
                  in available.where((item) => item.entityId != home.entityId))
                DropdownMenuItem(
                  value: light.entityId,
                  child: Text('${light.name} · ${light.entityId}',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _busy || !home.connected
                ? null
                : (id) {
                    if (id != null) unawaited(_bindHallway(id));
                  },
          ),
          if (home.hallwayEntityId.isNotEmpty && home.hallwayLight == null) ...[
            const SizedBox(height: 8),
            Text(
                'La entidad ${home.hallwayEntityId} no aparece en Home Assistant.'),
          ],
          const Divider(height: 28),
          Text(
            'Bombilla del dormitorio',
            style: TextStyle(color: context.visuals.textMuted),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey(
                'home-assistant-second-room-${home.secondRoomEntityId}'),
            initialValue: available.any((item) =>
                    item.entityId == home.secondRoomEntityId &&
                    item.entityId != home.entityId &&
                    item.entityId != home.hallwayEntityId)
                ? home.secondRoomEntityId
                : null,
            hint: const Text('Selecciona la bombilla del dormitorio'),
            isExpanded: true,
            items: [
              for (final light in available.where((item) =>
                  item.entityId != home.entityId &&
                  item.entityId != home.hallwayEntityId))
                DropdownMenuItem(
                  value: light.entityId,
                  child: Text('${light.name} · ${light.entityId}',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _busy || !home.connected
                ? null
                : (id) {
                    if (id != null) unawaited(_bindSecondRoom(id));
                  },
          ),
          if (home.secondRoomEntityId.isNotEmpty &&
              home.secondRoomLight == null) ...[
            const SizedBox(height: 8),
            Text(
                'La entidad ${home.secondRoomEntityId} no aparece en Home Assistant.'),
          ],
          const Divider(height: 28),
          Text(
            'Tiempo actual de la ventana',
            style: TextStyle(color: context.visuals.textMuted),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey('home-assistant-weather-${home.weatherEntityId}'),
            initialValue: home.weathers
                    .any((item) => item.entityId == home.weatherEntityId)
                ? home.weatherEntityId
                : null,
            hint: const Text('Selecciona el tiempo de casa'),
            isExpanded: true,
            items: [
              for (final weather in home.weathers)
                DropdownMenuItem(
                  value: weather.entityId,
                  child: Text('${weather.name} · ${weather.entityId}',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _busy || !home.connected
                ? null
                : (id) {
                    if (id != null) unawaited(_bindWeather(id));
                  },
          ),
          if (home.weathers.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'No hay ninguna entidad meteorológica. Añade Met.no en Home Assistant usando la ubicación de tu casa y vuelve a conectar.',
              style: TextStyle(color: context.visuals.textMuted),
            ),
          ],
          const Divider(height: 28),
          Text(
            'Echo Dot de Habitación',
            style: TextStyle(color: context.visuals.textMuted),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey('home-assistant-echo-${home.echoEntityId}'),
            initialValue: home.echoPlayers
                    .any((item) => item.entityId == home.echoEntityId)
                ? home.echoEntityId
                : null,
            hint: const Text('Selecciona el Echo'),
            isExpanded: true,
            items: [
              for (final player in home.echoPlayers)
                DropdownMenuItem(
                  value: player.entityId,
                  child: Text('${player.name} · ${player.entityId}',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _busy || !home.connected
                ? null
                : (id) {
                    if (id != null) unawaited(_bindEcho(id));
                  },
          ),
          if (home.echoPlayers.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Añade «Alexa Devices» en Dispositivos y servicios de Home Assistant. '
              'Esta opción no necesita Home Assistant Cloud, pero sí usa tu cuenta de Amazon.',
              style: TextStyle(color: context.visuals.textMuted),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'El token se guarda en Windows. Los cambios de la maqueta no alteran esta asociación.',
            style: TextStyle(color: context.visuals.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
