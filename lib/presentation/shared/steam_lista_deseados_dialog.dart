import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/steam_lista_deseados.dart';
import '../../services/steam_service.dart';

/// Página de la tienda que muestra el token de sesión («webapi_token») cuando
/// se ha iniciado sesión en Steam desde el navegador.
const paginaTokenSteam =
    'https://store.steampowered.com/pointssummary/ajaxgetasyncconfig';

enum _Fase { token, trabajando, resultado, error }

/// Cruza la lista de deseados con el plan familiar, quita los coincidentes y
/// muestra el resultado.
class SteamListaDeseadosDialog extends StatefulWidget {
  const SteamListaDeseadosDialog(
      {required this.service, this.limpieza, super.key});
  final SteamService service;

  /// Permite inyectar el servicio en las pruebas.
  final SteamListaDeseados? limpieza;

  @override
  State<SteamListaDeseadosDialog> createState() =>
      _SteamListaDeseadosDialogState();
}

class _SteamListaDeseadosDialogState extends State<SteamListaDeseadosDialog> {
  late final SteamListaDeseados _limpieza =
      widget.limpieza ?? SteamListaDeseados(steam: widget.service);
  final _token = TextEditingController();
  _Fase _fase = _Fase.trabajando;
  String _mensaje = 'Descargando la lista de deseados y el plan familiar…';
  String? _avisoToken;
  ResultadoLimpieza? _resultado;
  bool _guardando = false;
  bool _copiado = false;

  @override
  void initState() {
    super.initState();
    unawaited(_empezar());
  }

  @override
  void dispose() {
    _token.dispose();
    if (widget.limpieza == null) _limpieza.dispose();
    super.dispose();
  }

  Future<void> _empezar() async {
    try {
      await _limpieza.tokenVigente();
    } on SteamTokenException catch (error) {
      _pedirToken(error.falta ? null : error.message);
      return;
    }
    await _ejecutar();
  }

  void _pedirToken(String? aviso) {
    if (!mounted) return;
    setState(() {
      _fase = _Fase.token;
      _avisoToken = aviso;
      _guardando = false;
    });
  }

  Future<void> _guardarToken() async {
    setState(() {
      _guardando = true;
      _avisoToken = null;
    });
    try {
      await _limpieza.guardarToken(_token.text);
      _token.clear();
    } on SteamTokenException catch (error) {
      _pedirToken(error.message);
      return;
    } on FormatException catch (error) {
      _pedirToken(error.message);
      return;
    }
    await _ejecutar();
  }

  Future<void> _ejecutar() async {
    if (!mounted) return;
    setState(() {
      _fase = _Fase.trabajando;
      _mensaje = 'Descargando la lista de deseados y el plan familiar…';
    });
    try {
      final resultado = await _limpieza.limpiar(progreso: (hechos, total) {
        if (!mounted || total == 0) return;
        setState(() => _mensaje = hechos < total
            ? 'Quitando de la lista de deseados: ${hechos + 1} de $total…'
            : 'Guardando el resultado…');
      });
      if (!mounted) return;
      setState(() {
        _resultado = resultado;
        _fase = _Fase.resultado;
      });
    } on SteamTokenException catch (error) {
      _pedirToken(error.falta ? null : error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _fase = _Fase.error;
        _mensaje = error is FormatException
            ? error.message
            : 'No se pudo completar la limpieza de la lista de deseados.';
      });
    }
  }

  Future<void> _copiar() async {
    final texto = _resultado?.texto;
    if (texto == null) return;
    await Clipboard.setData(ClipboardData(text: texto));
    if (mounted) setState(() => _copiado = true);
  }

  void _abrir(String url) => unawaited(
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                    child: Text('Limpiar lista de deseados',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold))),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close)),
              ]),
              const SizedBox(height: 12),
              Flexible(child: _contenido(theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contenido(ThemeData theme) => switch (_fase) {
        _Fase.token => _pasoToken(theme),
        _Fase.trabajando => Row(children: [
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 14),
            Expanded(
                child: Text(_mensaje,
                    key: const ValueKey('steam-limpieza-progreso'))),
          ]),
        _Fase.error => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_mensaje, key: const ValueKey('steam-limpieza-error')),
              const SizedBox(height: 16),
              FilledButton.icon(
                  onPressed: _empezar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar')),
            ],
          ),
        _Fase.resultado => _pasoResultado(theme),
      };

  Widget _pasoToken(ThemeData theme) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_avisoToken != null) ...[
              Text(_avisoToken!,
                  key: const ValueKey('steam-token-aviso'),
                  style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 12),
            ],
            const Text(
                'El plan familiar y los cambios en la lista de deseados necesitan '
                'un token de sesión de Steam; la clave de la API no sirve. '
                'Abre la página con la sesión de Steam iniciada en el navegador, '
                'copia todo su texto y pégalo aquí. El token dura unas 24 horas '
                'y se guarda cifrado en este PC.'),
            const SizedBox(height: 12),
            TextButton.icon(
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: Size.zero),
                onPressed: () => _abrir(paginaTokenSteam),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Abrir la página del token')),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('steam-token'),
              controller: _token,
              enabled: !_guardando,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                  labelText: 'Token de sesión de Steam',
                  helperText:
                      'Puedes pegar la página completa; no lo envíes por chat.'),
              onSubmitted: (_) => _guardando ? null : _guardarToken(),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
                key: const ValueKey('steam-token-guardar'),
                onPressed: _guardando ? null : _guardarToken,
                icon: const Icon(Icons.check),
                label: Text(_guardando ? 'Comprobando…' : 'Guardar y continuar')),
          ],
        ),
      );

  Widget _pasoResultado(ThemeData theme) {
    final resultado = _resultado!;
    final secundario = theme.colorScheme.onSurfaceVariant;
    Widget fila(JuegoCoincidente juego, {String? motivo}) => ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(juego.name),
          subtitle: Text(motivo == null ? juego.url : '${juego.url}\n$motivo',
              style: TextStyle(color: secundario)),
          trailing: IconButton(
              tooltip: 'Abrir en Steam',
              onPressed: () => _abrir(juego.url),
              icon: const Icon(Icons.open_in_new, size: 18)),
          onTap: () => _abrir(juego.url),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(resultado.texto.split('\n').first,
            key: const ValueKey('steam-limpieza-resumen'),
            style: theme.textTheme.titleSmall),
        if (resultado.total > 0)
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final juego in resultado.quitados) fila(juego),
                if (resultado.fallos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('No se pudieron quitar',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: theme.colorScheme.error)),
                  for (final (juego, motivo) in resultado.fallos)
                    fila(juego, motivo: motivo),
                ],
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (resultado.archivo != null)
          Text('Guardado en ${resultado.archivo}',
              style: theme.textTheme.bodySmall?.copyWith(color: secundario)),
        if (resultado.total > 0) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
              key: const ValueKey('steam-limpieza-copiar'),
              onPressed: _copiar,
              icon: Icon(_copiado ? Icons.check : Icons.copy, size: 18),
              label: Text(_copiado ? 'Lista copiada' : 'Copiar lista')),
        ],
      ],
    );
  }
}
