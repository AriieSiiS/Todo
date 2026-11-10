import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class DragMouseCursors {
  static MouseCursor get grab =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
          ? _open
          : SystemMouseCursors.grab;
  static MouseCursor get grabbing =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
          ? _closed
          : SystemMouseCursors.grabbing;
  static const _open = _WindowsHandCursor(false);
  static const _closed = _WindowsHandCursor(true);
}

class _WindowsHandCursor extends MouseCursor {
  const _WindowsHandCursor(this.closed);
  final bool closed;
  static final _created = <bool, Future<String>>{};

  @override
  String get debugDescription =>
      closed ? 'Mano agarrando' : 'Mano para agarrar';

  @override
  MouseCursorSession createSession(int device) =>
      _HandCursorSession(this, device);

  Future<String> get name => _created.putIfAbsent(closed, _create);

  Future<String> _create() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final path = ui.Path()
      ..moveTo(11, 29)
      ..lineTo(9, 25)
      ..lineTo(4, 19)
      ..quadraticBezierTo(1, 15, 4, 14)
      ..quadraticBezierTo(5, 13, 7, 15)
      ..lineTo(10, 18)
      ..lineTo(10, closed ? 13 : 8)
      ..quadraticBezierTo(10, closed ? 10 : 5, 13, closed ? 10 : 5)
      ..lineTo(13, closed ? 13 : 15)
      ..lineTo(13, closed ? 10 : 4)
      ..quadraticBezierTo(14, closed ? 7 : 1, 16, closed ? 9 : 3)
      ..lineTo(16, closed ? 13 : 15)
      ..lineTo(16, closed ? 10 : 5)
      ..quadraticBezierTo(18, closed ? 7 : 2, 19, closed ? 10 : 5)
      ..lineTo(19, closed ? 14 : 16)
      ..lineTo(19, closed ? 12 : 9)
      ..quadraticBezierTo(21, closed ? 9 : 6, 23, closed ? 12 : 9)
      ..lineTo(23, 20)
      ..quadraticBezierTo(23, 26, 20, 29)
      ..close();
    canvas.drawPath(path, ui.Paint()..color = const ui.Color(0xFFFFFFFF));
    canvas.drawPath(
        path,
        ui.Paint()
          ..color = const ui.Color(0xFF111111)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeJoin = ui.StrokeJoin.round);
    final picture = recorder.endRecording();
    final image = await picture.toImage(32, 32);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (data == null) throw StateError('No se pudo dibujar el cursor.');
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    // El canal de Windows recibe los píxeles en orden BGRA.
    for (var index = 0; index < bytes.length; index += 4) {
      final red = bytes[index];
      bytes[index] = bytes[index + 2];
      bytes[index + 2] = red;
    }
    final name = closed ? 'todo-mano-cerrada' : 'todo-mano-abierta';
    await SystemChannels.mouseCursor
        .invokeMethod<String>('createCustomCursor/windows', {
      'name': name,
      'buffer': bytes,
      'width': 32,
      'height': 32,
      'hotX': 14.0,
      'hotY': 16.0,
    });
    return name;
  }
}

class _HandCursorSession extends MouseCursorSession {
  _HandCursorSession(_WindowsHandCursor super.cursor, super.device);
  bool _active = true;

  @override
  Future<void> activate() async {
    try {
      final name = await (cursor as _WindowsHandCursor).name;
      if (!_active) return;
      await SystemChannels.mouseCursor
          .invokeMethod<void>('setCustomCursor/windows', {'name': name});
    } catch (_) {
      if (_active) {
        await SystemChannels.mouseCursor.invokeMethod<void>(
            'activateSystemCursor', {'device': device, 'kind': 'click'});
      }
    }
  }

  @override
  void dispose() => _active = false;
}
