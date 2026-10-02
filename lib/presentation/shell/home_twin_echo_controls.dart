part of 'app_shell.dart';

class _HomeTwinEchoControls extends StatefulWidget {
  const _HomeTwinEchoControls({required this.home});

  final HomeAssistantController? home;

  @override
  State<_HomeTwinEchoControls> createState() => _HomeTwinEchoControlsState();
}

class _HomeTwinEchoControlsState extends State<_HomeTwinEchoControls> {
  final _message = TextEditingController();
  final _command = TextEditingController();
  bool _busy = false;
  double? _volumeDraft;

  String _shortName(HomeAssistantEchoEntity item, String echoName) {
    final name = item.name.trim();
    final prefix = '$echoName ';
    if (name.toLowerCase().startsWith(prefix.toLowerCase())) {
      final short = name.substring(prefix.length).trim();
      if (short.isNotEmpty) return short;
    }
    return name;
  }

  String _controlName(HomeAssistantEchoEntity item, String echoName) {
    final name = _shortName(item, echoName);
    if (name.toLowerCase().contains('iluminancia')) return 'Luz ambiente';
    if (name.toLowerCase().contains('comunicaciones')) {
      return 'Comunicaciones de Alexa';
    }
    if (name.toLowerCase().contains('anuncios')) return 'Anuncios de Alexa';
    return name;
  }

  String? _switchDescription(HomeAssistantEchoEntity item) {
    final name = item.name.toLowerCase();
    if (name.contains('anuncios')) {
      return 'Permite recibir anuncios en este Echo.';
    }
    if (name.contains('comunicaciones')) {
      return 'Permite llamadas, Drop In y anuncios.';
    }
    return null;
  }

  String _valueLabel(String value) => switch (value.toLowerCase()) {
        'on' => 'Activado',
        'off' => 'Desactivado',
        'unavailable' || 'unknown' => 'No disponible',
        'all' => 'Todos',
        'none' => 'Nadie',
        'household' => 'Hogar',
        _ => value,
      };

  @override
  void initState() {
    super.initState();
    widget.home?.addListener(_updated);
  }

  @override
  void didUpdateWidget(covariant _HomeTwinEchoControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.home == widget.home) return;
    oldWidget.home?.removeListener(_updated);
    widget.home?.addListener(_updated);
  }

  void _updated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.home?.removeListener(_updated);
    _message.dispose();
    _command.dispose();
    super.dispose();
  }

  Future<void> _send(
    String domain,
    String service, {
    String? entityId,
    Map<String, dynamic> data = const {},
  }) async {
    final home = widget.home;
    if (home == null || _busy) return;
    setState(() => _busy = true);
    try {
      await home.callEcho(domain, service, entityId: entityId, data: data);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error is FormatException
              ? error.message
              : 'No se pudo enviar la orden al Echo.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = widget.home;
    final echo = home?.selectedEcho;
    if (home == null || home.echoEntityId.isEmpty || echo == null) {
      return Text(
        'Para controlar el Echo, añade «Alexa Devices» en Home Assistant y asócialo en Ajustes. '
        'No requiere Home Assistant Cloud; la conexión del Echo usa Amazon.',
        style: TextStyle(color: context.visuals.textMuted),
      );
    }
    final enabled = home.connected && echo.available && !_busy;
    final playing = echo.state == 'playing';
    final notify = home.echoEntities('notify');
    final speak =
        notify.where((item) => item.entityId.endsWith('_speak')).firstOrNull;
    final announce =
        notify.where((item) => item.entityId.endsWith('_announce')).firstOrNull;
    final sourceList = ((echo.attributes['source_list'] as List?) ?? const [])
        .whereType<String>()
        .toList();
    final source = echo.attributes['source'] as String?;
    final volume = (_volumeDraft ?? echo.volume ?? 0.5).clamp(0.0, 1.0);
    final switches = home.echoEntities('switch');
    final selects = home.echoEntities('select');
    final buttons = home.echoEntities('button');
    final data = [
      for (final domain in const ['sensor', 'binary_sensor', 'todo'])
        ...home.echoEntities(domain).where((item) => item.available),
    ];
    final hasExtras = switches.isNotEmpty ||
        selects.any((item) => item.options.isNotEmpty) ||
        buttons.isNotEmpty ||
        data.isNotEmpty ||
        home.echoDeviceId != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(echo.name,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(
        !home.connected || !echo.available
            ? 'Sin conexión'
            : switch (echo.state) {
                'playing' => 'Reproduciendo',
                'paused' => 'En pausa',
                'idle' => 'En espera',
                _ => 'Disponible',
              },
        style: TextStyle(color: context.visuals.textMuted),
      ),
      if (echo.mediaTitle?.isNotEmpty == true) ...[
        const SizedBox(height: 5),
        Text(echo.mediaTitle!, maxLines: 2, overflow: TextOverflow.ellipsis),
        if (echo.mediaArtist?.isNotEmpty == true)
          Text(echo.mediaArtist!,
              style: TextStyle(color: context.visuals.textMuted)),
      ],
      if (echo.supports(1) || echo.supports(16384) || echo.supports(4096)) ...[
        const SizedBox(height: 10),
        Wrap(spacing: 5, children: [
          if (echo.supports(16))
            IconButton.filledTonal(
              tooltip: 'Anterior',
              onPressed: enabled
                  ? () => _send('media_player', 'media_previous_track',
                      entityId: echo.entityId)
                  : null,
              icon: const Icon(Icons.skip_previous_rounded),
            ),
          if (playing && echo.supports(1) || !playing && echo.supports(16384))
            IconButton.filledTonal(
              tooltip: playing ? 'Pausar' : 'Reproducir',
              onPressed: enabled
                  ? () => _send(
                      'media_player', playing ? 'media_pause' : 'media_play',
                      entityId: echo.entityId)
                  : null,
              icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
            ),
          if (echo.supports(4096))
            IconButton.filledTonal(
              tooltip: 'Detener',
              onPressed: enabled
                  ? () => _send('media_player', 'media_stop',
                      entityId: echo.entityId)
                  : null,
              icon: const Icon(Icons.stop_rounded),
            ),
          if (echo.supports(32))
            IconButton.filledTonal(
              tooltip: 'Siguiente',
              onPressed: enabled
                  ? () => _send('media_player', 'media_next_track',
                      entityId: echo.entityId)
                  : null,
              icon: const Icon(Icons.skip_next_rounded),
            ),
        ]),
      ],
      if (echo.supports(4) && echo.volume != null) ...[
        const SizedBox(height: 10),
        Text('Volumen: ${(volume * 100).round()} %'),
        Slider(
          value: volume,
          onChanged:
              enabled ? (value) => setState(() => _volumeDraft = value) : null,
          onChangeEnd: enabled
              ? (value) {
                  setState(() => _volumeDraft = null);
                  unawaited(_send('media_player', 'volume_set',
                      entityId: echo.entityId, data: {'volume_level': value}));
                }
              : null,
        ),
      ],
      if (echo.supports(8) && echo.muted != null)
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Silenciar'),
          value: echo.muted!,
          onChanged: enabled
              ? (value) => _send('media_player', 'volume_mute',
                  entityId: echo.entityId, data: {'is_volume_muted': value})
              : null,
        ),
      if (echo.supports(2048) && sourceList.isNotEmpty) ...[
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey('echo-fuente-$source'),
          initialValue: sourceList.contains(source) ? source : null,
          decoration: const InputDecoration(labelText: 'Fuente de audio'),
          items: [
            for (final item in sourceList)
              DropdownMenuItem(value: item, child: Text(item))
          ],
          onChanged: enabled
              ? (value) {
                  if (value != null) {
                    unawaited(_send('media_player', 'select_source',
                        entityId: echo.entityId, data: {'source': value}));
                  }
                }
              : null,
        ),
      ],
      if (speak != null || announce != null) ...[
        const Divider(height: 28),
        const Text('Haz que el Echo hable',
            style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          'Escribe solo la frase que quieres que diga.',
          style: TextStyle(color: context.visuals.textMuted),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _message,
          onChanged: (_) => setState(() {}),
          maxLength: 300,
          decoration: const InputDecoration(
            hintText: 'Por ejemplo: Qué tal estás',
            counterText: '',
          ),
        ),
        Wrap(spacing: 8, runSpacing: 6, children: [
          if (speak != null)
            FilledButton.tonal(
              onPressed:
                  enabled && speak.available && _message.text.trim().isNotEmpty
                      ? () => _send('notify', 'send_message',
                          entityId: speak.entityId,
                          data: {'message': _message.text.trim()})
                      : null,
              child: const Text('Decir en voz alta'),
            ),
          if (announce != null)
            FilledButton.tonal(
              onPressed: enabled &&
                      announce.available &&
                      _message.text.trim().isNotEmpty
                  ? () => _send('notify', 'send_message',
                      entityId: announce.entityId,
                      data: {'message': _message.text.trim()})
                  : null,
              child: const Text('Anunciar con sonido'),
            ),
        ]),
      ],
      if (speak == null && announce == null)
        Text(
          'Este Echo no tiene disponible la función de voz en Home Assistant.',
          style: TextStyle(color: context.visuals.textMuted),
        ),
      if (hasExtras) ...[
        const SizedBox(height: 12),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const Text('Más controles del Echo',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          children: [
            if (home.echoDeviceId != null) ...[
              const Text('Pedir algo a Alexa',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Para música, temporizadores o dispositivos. Para leer una frase, usa «Decir en voz alta».',
                style: TextStyle(color: context.visuals.textMuted),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _command,
                onChanged: (_) => setState(() {}),
                maxLength: 300,
                decoration: const InputDecoration(
                  hintText: 'Por ejemplo: pon música tranquila',
                  counterText: '',
                ),
              ),
              FilledButton.tonal(
                onPressed: enabled && _command.text.trim().isNotEmpty
                    ? () => _send('alexa_devices', 'send_text_command',
                        data: {'text_command': _command.text.trim()})
                    : null,
                child: const Text('Enviar petición'),
              ),
              const SizedBox(height: 8),
            ],
            for (final item in switches)
              SwitchListTile.adaptive(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(_controlName(item, echo.name)),
                subtitle: _switchDescription(item) == null
                    ? null
                    : Text(_switchDescription(item)!),
                value: item.state == 'on',
                onChanged: enabled && item.available
                    ? (value) => _send('switch', value ? 'turn_on' : 'turn_off',
                        entityId: item.entityId)
                    : null,
              ),
            for (final item in selects)
              if (item.options.isNotEmpty) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey('echo-opcion-${item.entityId}-${item.state}'),
                  isExpanded: true,
                  initialValue:
                      item.options.contains(item.state) ? item.state : null,
                  decoration:
                      InputDecoration(labelText: _controlName(item, echo.name)),
                  items: [
                    for (final option in item.options)
                      DropdownMenuItem(
                        value: option,
                        child: Text(_valueLabel(option),
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: enabled && item.available
                      ? (option) {
                          if (option != null) {
                            unawaited(_send('select', 'select_option',
                                entityId: item.entityId,
                                data: {'option': option}));
                          }
                        }
                      : null,
                ),
              ],
            if (buttons.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Acciones',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, children: [
                for (final item in buttons)
                  OutlinedButton(
                    onPressed: enabled && item.available
                        ? () =>
                            _send('button', 'press', entityId: item.entityId)
                        : null,
                    child: Text(_shortName(item, echo.name)),
                  ),
              ]),
            ],
            if (data.isNotEmpty) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('Datos del Echo',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                children: [
                  for (final item in data)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(_controlName(item, echo.name))),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${_valueLabel(item.state)}${item.attributes['unit_of_measurement'] is String ? ' ${item.attributes['unit_of_measurement']}' : ''}',
                              textAlign: TextAlign.end,
                              style:
                                  TextStyle(color: context.visuals.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ],
    ]);
  }
}
