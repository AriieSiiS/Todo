import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:todo/presentation/shared/steam_panels.dart';
import 'package:todo/services/steam_service.dart';

import 'steam_service_test.dart' show MemorySecrets;

void main() {
  testWidgets(
      'comprueba la conexión y borra la clave del campo después de guardarla',
      (tester) async {
    final store = MemorySecrets();
    final service = SteamService(
        store: store,
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'response': {'game_count': 0}
            }),
            200)));
    addTearDown(service.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: SteamSettingsPanel(service: service)))));
    await tester.pumpAndSettle();
    final key = List.filled(32, 'a').join();
    await tester.enterText(
        find.byKey(const ValueKey('steam-profile')), '76561198000000001');
    await tester.enterText(find.byKey(const ValueKey('steam-api-key')), key);
    await tester.tap(find.byKey(const ValueKey('steam-connect')));
    await tester.pumpAndSettle();
    expect(find.text('Conexión comprobada y guardada: 0 juegos accesibles.'),
        findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('steam-api-key')))
            .controller!
            .text,
        isEmpty);
    expect(store.value, isNotNull);
    await tester.tap(find.text('Desconectar'));
    await tester.pumpAndSettle();
    expect(store.value, isNull);
    expect(find.text('Conexión eliminada de este PC.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explica cómo conectar cuando se abren los logros sin configurar',
      (tester) async {
    final service = SteamService(store: MemorySecrets());
    addTearDown(service.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SteamGameDialog(
                service: service, itemId: 'ficha', title: 'Juego'))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Conecta Steam en Ajustes'), findsOneWidget);
    expect(find.text('Actualizar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
