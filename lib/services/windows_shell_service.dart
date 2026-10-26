import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Comunicación con la ventana de Windows: atajo global de captura rápida,
/// argumentos de una segunda instancia y modo mini.
class WindowsShellService extends ChangeNotifier {
  WindowsShellService({this.enabled = true, this.beforeExit});

  static const MethodChannel _channel = MethodChannel('todo/shell');

  /// Ctrl + Alt + N, registrado por la parte nativa.
  static const String hotkeyLabel = 'Ctrl + Alt + N';

  final bool enabled;
  final Future<void> Function()? beforeExit;
  final StreamController<String> _arguments =
      StreamController<String>.broadcast();
  bool _hotkeyRegistered = false;
  bool _compact = false;

  /// Argumentos de arranque (`--quick-capture`, `--compact`, `--section=…`)
  /// que llegan mientras la app ya está abierta.
  Stream<String> get arguments => _arguments.stream;
  bool get hotkeyRegistered => _hotkeyRegistered;
  bool get compact => _compact;

  Future<void> initialize() async {
    if (!enabled) return;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'requestExit':
          try {
            await beforeExit?.call();
            await _channel.invokeMethod<void>('finishExit');
          } catch (_) {
            await _channel.invokeMethod<void>('exitFailed');
          }
          break;
        case 'quickCapture':
          _arguments.add('--quick-capture');
        case 'launchArgument':
          final value = call.arguments;
          if (value is String && value.isNotEmpty) _arguments.add(value);
      }
      return null;
    });
    try {
      final status = await _channel.invokeMapMethod<String, Object?>(
        'getStatus',
      );
      _hotkeyRegistered = status?['hotkeyRegistered'] == true;
      _compact = status?['compact'] == true;
      notifyListeners();
    } on MissingPluginException {
      // Una compilación sin el puente nativo sigue funcionando sin atajo.
    }
  }

  /// Cambia entre la ventana normal y el modo mini. Devuelve el estado final.
  Future<bool> setCompact(bool value) async {
    if (!enabled || value == _compact) return _compact;
    try {
      final ok = await _channel.invokeMethod<bool>('setCompactMode', value);
      if (ok == true) {
        _compact = value;
        notifyListeners();
      }
    } on MissingPluginException {
      // Sin puente nativo no hay modo mini.
    }
    return _compact;
  }

  @override
  void dispose() {
    if (enabled) _channel.setMethodCallHandler(null);
    unawaited(_arguments.close());
    super.dispose();
  }
}
