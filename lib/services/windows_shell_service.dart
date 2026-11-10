import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Comunicación con la ventana de Windows: atajo global de captura rápida,
/// argumentos de una segunda instancia, modo mini y pantalla completa.
class WindowsShellService extends ChangeNotifier {
  WindowsShellService({this.enabled = true, this.beforeExit});

  static const MethodChannel _channel = MethodChannel('todo/shell');

  /// Ctrl + Alt + N, registrado por la parte nativa.
  static const String hotkeyLabel = 'Ctrl + Alt + N';

  /// Indica si la ventana está en pantalla completa sin bordes. Lo escucha la
  /// raíz de la app para ampliar toda la interfaz, diálogos incluidos.
  static final ValueNotifier<bool> pantallaCompleta = ValueNotifier(false);

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
  bool get fullScreen => pantallaCompleta.value;

  Future<void> initialize() async {
    if (!enabled) return;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'requestExit':
          try {
            await beforeExit?.call().timeout(const Duration(seconds: 15));
            await _channel.invokeMethod<void>('finishExit');
          } catch (error) {
            _registrarFallo(error);
            await _channel.invokeMethod<void>('exitFailed', '$error');
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
      pantallaCompleta.value = status?['fullScreen'] == true;
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
        // El modo mini sale antes de la pantalla completa en la parte nativa.
        if (value) pantallaCompleta.value = false;
        notifyListeners();
      }
    } on MissingPluginException {
      // Sin puente nativo no hay modo mini.
    }
    return _compact;
  }

  /// Entra o sale de la pantalla completa en ventana sin bordes, que tapa
  /// también la barra de tareas. Devuelve el estado final.
  Future<bool> setFullScreen(bool value) async {
    if (!enabled || value == fullScreen) return fullScreen;
    try {
      final ok = await _channel.invokeMethod<bool>('setFullScreen', value);
      if (ok == true) {
        if (value) _compact = false;
        pantallaCompleta.value = value;
        notifyListeners();
      }
    } on MissingPluginException {
      // Sin puente nativo no hay pantalla completa.
    }
    return fullScreen;
  }

  Future<bool> toggleFullScreen() => setFullScreen(!fullScreen);

  /// Deja constancia de por qué no se pudo cerrar, para poder investigarlo.
  static void _registrarFallo(Object error) {
    try {
      final inicio = Platform.environment['USERPROFILE'] ?? '';
      final s = Platform.pathSeparator;
      final archivo =
          File('$inicio${s}Documents${s}Todo${s}runtime${s}cierres_fallidos.log');
      if (archivo.existsSync() && archivo.lengthSync() > 200000) {
        archivo.deleteSync();
      }
      archivo.writeAsStringSync(
          '${DateTime.now().toIso8601String()}  $error\n',
          mode: FileMode.append);
    } catch (_) {}
  }

  @override
  void dispose() {
    if (enabled) _channel.setMethodCallHandler(null);
    unawaited(_arguments.close());
    super.dispose();
  }
}
