// La prueba verifica el ciclo de vida interno del cursor y las activaciones tardías.
// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/presentation/shared/drag_mouse_cursors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Windows crea ambas manos y no activa una sesión ya terminada',
      (tester) async {
    final calls = <MethodCall>[];
    final created = Completer<String>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.mouseCursor,
      (call) async {
        calls.add(call);
        if (call.method == 'createCustomCursor/windows') {
          return created.future;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.mouseCursor, null));
    final open = DragMouseCursors.grab.createSession(1);
    final activation = open.activate();
    await tester.runAsync(() async {
      while (calls.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    open.dispose();
    final openBuffer = (calls.first.arguments as Map)['buffer'];
    created.complete('mano-abierta');
    await activation;
    expect(calls.where((c) => c.method == 'setCustomCursor/windows'), isEmpty);
    calls.clear();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.mouseCursor,
      (call) async {
        calls.add(call);
        return call.method == 'createCustomCursor/windows'
            ? (call.arguments as Map)['name']
            : null;
      },
    );
    final closed = DragMouseCursors.grabbing.createSession(1);
    await tester.runAsync(closed.activate);
    expect(calls.map((c) => c.method),
        ['createCustomCursor/windows', 'setCustomCursor/windows']);
    final args = calls.first.arguments as Map;
    expect(args['width'], 32);
    expect(args['buffer'], hasLength(32 * 32 * 4));
    expect(args['buffer'], isNot(orderedEquals(openBuffer as Iterable<int>)));
    closed.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
