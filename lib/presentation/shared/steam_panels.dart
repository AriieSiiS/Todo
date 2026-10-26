import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/todo_theme.dart';
import '../../services/steam_service.dart';

String _steamMessage(Object error) => error is FormatException
    ? error.message
    : 'No se pudo completar la operación con Steam.';

class SteamSettingsPanel extends StatefulWidget {
  const SteamSettingsPanel({required this.service, super.key});
  final SteamService service;
  @override
  State<SteamSettingsPanel> createState() => _SteamSettingsPanelState();
}

class _SteamSettingsPanelState extends State<SteamSettingsPanel> {
  final _profile = TextEditingController();
  final _key = TextEditingController();
  bool _busy = true;
  bool _configured = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final profile = await widget.service.profile();
      if (!mounted) return;
      _profile.text = profile ?? '';
      _configured = profile != null;
      _message = _configured
          ? 'Conexión guardada. Comprueba el acceso a Steam cuando quieras.'
          : '';
    } catch (error) {
      if (mounted) _message = _steamMessage(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _message = 'Comprobando el acceso a Steam…';
    });
    try {
      final games = await widget.service.connect(_profile.text, _key.text);
      if (!mounted) return;
      _key.clear();
      _configured = true;
      _message =
          'Conexión comprobada y guardada: ${games.length} juegos accesibles.';
    } catch (error) {
      if (mounted) _message = _steamMessage(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() => _busy = true);
    try {
      await widget.service.disconnect();
      if (!mounted) return;
      _profile.clear();
      _key.clear();
      _configured = false;
      _message = 'Conexión eliminada de este PC.';
    } catch (error) {
      if (mounted) _message = _steamMessage(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _profile.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              'Consulta tus juegos, horas y logros. La clave se guarda únicamente en el almacenamiento seguro de este PC.'),
          const SizedBox(height: 14),
          TextField(
              key: const ValueKey('steam-profile'),
              controller: _profile,
              enabled: !_busy,
              decoration: const InputDecoration(
                  labelText: 'SteamID o enlace del perfil',
                  hintText: 'https://steamcommunity.com/profiles/…')),
          const SizedBox(height: 12),
          TextField(
              key: const ValueKey('steam-api-key'),
              controller: _key,
              enabled: !_busy,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                  labelText: 'Clave de la API de Steam',
                  helperText: _configured
                      ? 'Déjala vacía para conservar la clave guardada.'
                      : 'Introduce aquí la clave; no la envíes por chat.')),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 8, children: [
            FilledButton.icon(
                key: const ValueKey('steam-connect'),
                onPressed: _busy ? null : _connect,
                icon: const Icon(Icons.link),
                label: Text(_busy ? 'Comprobando…' : 'Guardar y comprobar')),
            if (_configured) ...[
              OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => showDialog<void>(
                          context: context,
                          builder: (_) =>
                              SteamGameDialog(service: widget.service)),
                  child: const Text('Ver juegos')),
              TextButton(
                  onPressed: _busy ? null : _disconnect,
                  child: const Text('Desconectar')),
            ],
            TextButton(
                onPressed: () => launchUrl(
                    Uri.parse('https://steamcommunity.com/dev/apikey'),
                    mode: LaunchMode.externalApplication),
                child: const Text('Obtener clave')),
            TextButton(
                onPressed: () => launchUrl(
                    Uri.parse('https://steamcommunity.com/my/edit/settings/'),
                    mode: LaunchMode.externalApplication),
                child: const Text('Privacidad de Steam')),
          ]),
          if (_message.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_message, key: const ValueKey('steam-status'))),
        ],
      );
}

class SteamGameDialog extends StatelessWidget {
  const SteamGameDialog(
      {required this.service, this.itemId, this.title, super.key});
  final SteamService service;
  final String? itemId;
  final String? title;

  @override
  Widget build(BuildContext context) => Dialog(
      child: SizedBox(
          width: 760,
          height: 620,
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Expanded(
                          child: Text('Steam',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold))),
                      IconButton(
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Cerrar',
                          icon: const Icon(Icons.close)),
                    ]),
                    const SizedBox(height: 12),
                    Expanded(
                        child: SteamGamePanel(
                            service: service, itemId: itemId, title: title)),
                  ]))));
}

/// Logros de Steam de un juego, sin marco, para incrustarlos en una pestaña.
class SteamGamePanel extends StatefulWidget {
  const SteamGamePanel(
      {required this.service,
      this.itemId,
      this.title,
      this.allowChangeGame = true,
      super.key});
  final bool allowChangeGame;
  final SteamService service;
  final String? itemId;
  final String? title;
  @override
  State<SteamGamePanel> createState() => _SteamGamePanelState();
}

class _SteamGamePanelState extends State<SteamGamePanel> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _games = [];
  Map<String, dynamic>? _result;
  int? _appId;
  bool _busy = true;
  int _filter = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool refresh = false}) async {
    // Con datos guardados se muestran al instante y Steam los renueva detrás.
    var silent = false;
    if (!refresh && _result == null && widget.itemId != null) {
      final saved = await widget.service.savedAchievements(widget.itemId!);
      if (!mounted) return;
      if (saved != null && saved['appid'] is int) {
        silent = true;
        setState(() {
          _appId = saved['appid'] as int;
          _result = saved;
          _busy = false;
          _error = null;
        });
      }
    }
    if (!silent) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    try {
      final games = await widget.service.games(refresh: refresh);
      if (!mounted) return;
      _games = games;
      if (_appId == null && widget.itemId != null) {
        _appId = await widget.service
            .linkedApp(widget.itemId!, widget.title ?? '', games);
      }
      final result = _appId == null
          ? null
          : await widget.service.achievements(_appId!, refresh: refresh);
      if (!mounted) return;
      _result = result;
    } catch (error) {
      if (mounted && !silent) _error = _steamMessage(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _select(Map<String, dynamic> game) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.itemId != null) {
        await widget.service.link(widget.itemId!, game['appid'] as int);
      }
      _appId = game['appid'] as int;
      if (mounted) {
        await _load();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _steamMessage(error);
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _hours(Map<String, dynamic> game) {
    final minutes = game['playtime_minutes'] as num?;
    return minutes == null
        ? 'Horas no disponibles'
        : '${(minutes / 60).toStringAsFixed(1).replaceAll('.', ',')} h jugadas';
  }

  Widget _content() {
    if (_busy) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
          child:
              Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    }
    final result = _result;
    if (_appId == null || result == null) {
      final games = _games
          .where((game) => (game['name'] as String? ?? '')
              .toLowerCase()
              .contains(_search.text.trim().toLowerCase()))
          .toList();
      return Column(children: [
        if (widget.title != null)
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child:
                  Text('Selecciona el juego de Steam para «${widget.title}».')),
        TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                labelText: 'Buscar en tus juegos de Steam',
                prefixIcon: Icon(Icons.search))),
        const SizedBox(height: 12),
        Expanded(
            child: games.isEmpty
                ? const Center(child: Text('No hay juegos que coincidan.'))
                : ListView.builder(
                    itemCount: games.length,
                    itemBuilder: (_, index) {
                      final game = games[index];
                      return ListTile(
                          title: Text(game['name'] as String? ?? 'Juego'),
                          subtitle: Text(_hours(game)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _select(game));
                    })),
      ]);
    }
    final all = (result['achievements'] as List).cast<Map<String, dynamic>>();
    final achievements = all
        .where((item) => switch (_filter) {
              1 => item['unlocked'] == true,
              2 => item['unlocked'] != true,
              _ => true,
            })
        .toList()
      ..sort(_compare);
    final game = _games.where((game) => game['appid'] == _appId).firstOrNull;
    final percent = result['completion_percent'] as num?;
    final unlocked = result['unlocked'] as num;
    final total = result['total'] as num;
    final scheme = Theme.of(context).colorScheme;
    final details = [
      if (percent != null) '${_decimal(percent)} % completado',
      if (game != null) _hours(game),
    ].join('  ·  ');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text.rich(TextSpan(children: [
            TextSpan(
                text: '$unlocked',
                style:
                    const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            TextSpan(
                text: ' de $total logros',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ])),
          const SizedBox(height: 2),
          Text(details,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
        ])),
        const SizedBox(width: 12),
        _FilterTabs(
            selected: _filter,
            onChanged: (value) => setState(() => _filter = value)),
        IconButton(
            tooltip: 'Actualizar logros',
            onPressed: _busy ? null : () => _load(refresh: true),
            icon: const Icon(Icons.refresh)),
      ]),
      const SizedBox(height: 10),
      ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
              minHeight: 8,
              value: total == 0 ? 0 : (unlocked / total).toDouble())),
      const SizedBox(height: 14),
      Expanded(
          child: total == 0
              ? const Center(
                  child: Text('Este juego no tiene logros en Steam.'))
              : achievements.isEmpty
                  ? const Center(child: Text('No hay logros en esta lista.'))
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 480,
                              mainAxisExtent: 112,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10),
                      itemCount: achievements.length,
                      itemBuilder: (_, index) =>
                          _AchievementTile(item: achievements[index]))),
    ]);
  }

  /// Primero los desbloqueados, del más reciente al más antiguo; después los
  /// pendientes, de los más comunes a los más raros.
  static int _compare(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aOn = a['unlocked'] == true, bOn = b['unlocked'] == true;
    if (aOn != bOn) return aOn ? -1 : 1;
    if (aOn) {
      return ((b['unlock_time'] as num?) ?? 0)
          .compareTo((a['unlock_time'] as num?) ?? 0);
    }
    return ((b['global_percent'] as num?) ?? -1)
        .compareTo((a['global_percent'] as num?) ?? -1);
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _content()),
        if (widget.allowChangeGame || _result == null) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 12, children: [
            if (_result == null)
              OutlinedButton.icon(
                  onPressed: _busy ? null : () => _load(refresh: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar')),
            if (_appId != null && widget.allowChangeGame)
              TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _appId = null;
                            _result = null;
                            _error = null;
                          }),
                  child: const Text('Cambiar juego')),
          ]),
        ],
      ]);
}

String _decimal(num value) => value.toStringAsFixed(1).replaceAll('.', ',');

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unlocked = item['unlocked'] == true;
    final rarity = item['global_percent'] as num?;
    final timestamp = item['unlock_time'] as num?;
    final date = unlocked && timestamp != null && timestamp > 0
        ? DateTime.fromMillisecondsSinceEpoch(timestamp.toInt() * 1000)
            .toLocal()
        : null;
    final description = (item['description'] as String? ?? '').trim();
    final path = (unlocked
        ? item['icon_path']
        : item['icon_gray_path'] ?? item['icon_path']) as String?;
    const green = Color(0xFF607A4D);
    final icon = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
            width: 64,
            height: 64,
            child: path == null
                ? ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: Icon(
                        unlocked ? Icons.emoji_events : Icons.lock_outline,
                        color: scheme.onSurfaceVariant))
                : Image.file(File(path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => ColoredBox(
                        color: scheme.surfaceContainerHighest,
                        child: const Icon(Icons.emoji_events_outlined)))));
    return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: unlocked ? green : scheme.outlineVariant,
                width: unlocked ? 1.6 : 1)),
        child: Row(children: [
          Opacity(opacity: unlocked ? 1 : .6, child: icon),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(item['name'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Expanded(
                    child: Text(
                        description.isNotEmpty
                            ? description
                            : item['hidden'] == true
                                ? 'Logro oculto'
                                : 'Sin descripción',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5, color: scheme.onSurfaceVariant))),
                Text(
                    [
                      if (unlocked && date != null)
                        '${date.day}/${date.month}/${date.year}'
                      else if (item['unlocked'] == null)
                        'Estado no disponible',
                      if (rarity != null) '${_decimal(rarity)} %',
                    ].join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: unlocked ? green : scheme.onSurfaceVariant)),
              ])),
        ]));
  }
}

/// Selector de lista con el mismo aspecto que las pestañas de la ficha.
class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.selected, required this.onChanged});
  final int selected;
  final ValueChanged<int> onChanged;

  static const _items = [
    (Icons.apps_rounded, 'Todos'),
    (Icons.emoji_events_outlined, 'Desbloqueados'),
    (Icons.lock_outline, 'Pendientes'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent =
        theme.extension<TodoVisuals>()?.accent ?? theme.colorScheme.primary;
    final muted = theme.extension<TodoVisuals>()?.textMuted ??
        theme.colorScheme.onSurfaceVariant;
    return Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: accent.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < _items.length; i++)
            InkWell(
                borderRadius: BorderRadius.circular(7),
                onTap: () => onChanged(i),
                child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: selected == i ? theme.colorScheme.surface : null,
                        borderRadius: BorderRadius.circular(7)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_items[i].$1,
                          size: 16, color: selected == i ? accent : muted),
                      const SizedBox(width: 6),
                      Text(_items[i].$2,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: selected == i ? accent : muted)),
                    ]))),
        ]));
  }
}
