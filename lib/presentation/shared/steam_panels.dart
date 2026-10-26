import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
      {required this.service, this.itemId, this.title, super.key});
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
  bool _pendingOnly = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
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
      if (mounted) _error = _steamMessage(error);
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
    final achievements = (result['achievements'] as List)
        .cast<Map<String, dynamic>>()
        .where((item) => !_pendingOnly || item['unlocked'] == false)
        .toList();
    final game = _games.where((game) => game['appid'] == _appId).firstOrNull;
    final percent = result['completion_percent'] as num?;
    final queried =
        DateTime.tryParse(result['queried_at'] as String? ?? '')?.toLocal();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(result['name'] as String,
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text('${result['unlocked']} de ${result['total']} logros'
          '${percent == null ? '' : ' · ${percent.toStringAsFixed(1).replaceAll('.', ',')} %'}'
          '${game == null ? '' : ' · ${_hours(game)}'}'),
      if (queried != null)
        Text('Consultado: ${queried.day}/${queried.month}/${queried.year} '
            '${queried.hour.toString().padLeft(2, '0')}:${queried.minute.toString().padLeft(2, '0')}'),
      const SizedBox(height: 8),
      FilterChip(
          label: const Text('Solo pendientes'),
          selected: _pendingOnly,
          onSelected: (value) => setState(() => _pendingOnly = value)),
      const Divider(),
      Expanded(
          child: result['total'] == 0
              ? const Center(
                  child: Text('Este juego no tiene logros en Steam.'))
              : achievements.isEmpty
                  ? const Center(child: Text('No hay logros pendientes.'))
                  : ListView.builder(
                      itemCount: achievements.length,
                      itemBuilder: (_, index) {
                        final item = achievements[index];
                        final unlocked = item['unlocked'] as bool?;
                        final rarity = item['global_percent'] as num?;
                        final timestamp = item['unlock_time'] as num?;
                        final date = unlocked == true &&
                                timestamp != null &&
                                timestamp > 0
                            ? DateTime.fromMillisecondsSinceEpoch(
                                    timestamp.toInt() * 1000)
                                .toLocal()
                            : null;
                        return ListTile(
                          leading: Icon(unlocked == true
                              ? Icons.emoji_events
                              : unlocked == false
                                  ? Icons.lock_outline
                                  : Icons.help_outline),
                          title: Text(item['name'] as String),
                          subtitle: Text([
                            if ((item['description'] as String).isNotEmpty)
                              item['description'],
                            unlocked == true
                                ? 'Desbloqueado${date == null ? '' : ' el ${date.day}/${date.month}/${date.year}'}'
                                : unlocked == false
                                    ? 'Pendiente'
                                    : 'Estado no disponible',
                            if (rarity != null)
                              '${rarity.toStringAsFixed(1).replaceAll('.', ',')} % de jugadores',
                          ].join('\n')),
                        );
                      })),
    ]);
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _content()),
        const SizedBox(height: 12),
        Wrap(spacing: 12, children: [
          OutlinedButton.icon(
              onPressed: _busy ? null : () => _load(refresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar')),
          if (_appId != null)
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
      ]);
}
