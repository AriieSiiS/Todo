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
      title: 'Home Assistant · luz del techo',
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
