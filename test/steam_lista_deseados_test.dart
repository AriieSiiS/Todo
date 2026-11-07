import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:todo/services/steam_lista_deseados.dart';
import 'package:todo/services/steam_service.dart';

class _Secretos implements SteamSecretStore {
  _Secretos(this.value);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
  @override
  Future<void> delete() async => value = null;
}

class _Tokens implements SteamTokenStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
  @override
  Future<void> delete() async => value = null;
}

void main() {
  const id = '76561198000000001';
  final ahora = DateTime(2026, 11, 7, 19, 30);
  String token({String sub = id, Duration vida = const Duration(hours: 24)}) {
    String parte(Object datos) =>
        base64Url.encode(utf8.encode(jsonEncode(datos))).replaceAll('=', '');
    final exp = ahora.add(vida).millisecondsSinceEpoch ~/ 1000;
    return 'eyJ${parte({'typ': 'JWT'}).substring(3)}.'
        '${parte({'sub': sub, 'exp': exp})}.firma';
  }

  SteamService steam() => SteamService(
      store: _Secretos(jsonEncode({'steamid': id, 'key': 'a' * 32})),
      client: MockClient((_) async => fail('No debe usar la clave Web API.')));

  http.Response json(Object datos, {String resultado = '1'}) => http.Response(
      jsonEncode(datos), 200,
      headers: {'content-type': 'application/json', 'x-eresult': resultado});

  test('extrae el token de la página completa y valida la cuenta', () async {
    final tokens = _Tokens();
    final servicio = SteamListaDeseados(
        steam: steam(),
        store: tokens,
        client: MockClient((_) async => fail('No debe consultar Steam.')),
        reloj: () => ahora);
    final valido = token();
    expect(
        SteamListaDeseados.extraerToken(
            '{"success":1,"data":{"webapi_token":"$valido"}}'),
        valido);
    await servicio.guardarToken('{"data":{"webapi_token":"$valido"}}');
    expect(tokens.value, valido);
    await expectLater(servicio.guardarToken(token(sub: '76561198000000002')),
        throwsFormatException);
    await expectLater(
        servicio.guardarToken(token(vida: const Duration(hours: -1))),
        throwsA(isA<SteamTokenException>()));
    expect(() => SteamListaDeseados.extraerToken('sin token'),
        throwsFormatException);
    // Steam escribe la cabecera con espacios: el token empieza por «eyAi».
    String b64(String texto) =>
        base64Url.encode(utf8.encode(texto)).replaceAll('=', '');
    final exp = ahora.add(const Duration(hours: 24)).millisecondsSinceEpoch ~/ 1000;
    final real = '${b64('{ "typ": "JWT", "alg": "EdDSA" }')}.'
        '${b64('{ "iss": "r:x", "sub": "$id", "exp": $exp }')}.Usie-Hj49_pmhO';
    expect(real, startsWith('eyAi'));
    final pagina = '{"success":1,"data":{"webapi_token":"$real"}}';
    expect(SteamListaDeseados.extraerToken(pagina), real);
    expect(SteamListaDeseados.extraerToken('  $pagina\n'), real);
    expect(SteamListaDeseados.extraerToken(real), real);
    await servicio.guardarToken(pagina);
    expect(tokens.value, real);
  });

  test('sin token o con el token caducado lo pide en lugar de cruzar',
      () async {
    final tokens = _Tokens();
    final servicio = SteamListaDeseados(
        steam: steam(),
        store: tokens,
        client: MockClient((_) async => fail('No debe consultar Steam.')),
        reloj: () => ahora);
    await expectLater(servicio.limpiar(), throwsA(isA<SteamTokenException>()));
    tokens.value = token(vida: const Duration(minutes: -5));
    await expectLater(servicio.limpiar(), throwsA(isA<SteamTokenException>()));
  });

  test('un token rechazado por Steam no se confunde con cero coincidencias',
      () async {
    final tokens = _Tokens()..value = token();
    final servicio = SteamListaDeseados(
        steam: steam(),
        store: tokens,
        client: MockClient((_) async => http.Response('', 401)),
        reloj: () => ahora);
    await expectLater(servicio.limpiar(), throwsA(isA<SteamTokenException>()));
  });

  test('cruza por AppID, quita uno a uno, sigue tras un fallo y guarda',
      () async {
    final carpeta = await Directory.systemTemp.createTemp('steam_deseados');
    addTearDown(() => carpeta.delete(recursive: true));
    final tokens = _Tokens()..value = token();
    final quitadas = <String>[];
    final servicio = SteamListaDeseados(
      steam: steam(),
      store: tokens,
      retardo: Duration.zero,
      carpeta: carpeta,
      reloj: () => ahora,
      client: MockClient((request) async {
        expect(request.url.queryParameters['access_token'], tokens.value);
        expect(request.url.queryParameters.containsKey('key'), isFalse);
        switch (request.url.path) {
          case '/IFamilyGroupsService/GetFamilyGroupForUser/v1/':
            return json({
              'response': {'family_groupid': '123'}
            });
          case '/IFamilyGroupsService/GetSharedLibraryApps/v1/':
            expect(request.url.queryParameters['family_groupid'], '123');
            return json({
              'response': {
                'apps': [
                  {'appid': 10, 'name': 'Fuera de la lista'},
                  {'appid': 30, 'name': 'Celeste'},
                  {'appid': 20, 'name': 'Braid'},
                ]
              }
            });
          case '/IWishlistService/GetWishlist/v1/':
            return json({
              'response': {
                'items': [
                  {'appid': 20},
                  {'appid': 30},
                  {'appid': 40},
                ]
              }
            });
          case '/IWishlistService/RemoveFromWishlist/v1/':
            expect(request.method, 'POST');
            final appid = Uri.splitQueryString(request.body)['appid']!;
            quitadas.add(appid);
            return appid == '30'
                ? json({}, resultado: '2')
                : json({'response': {}});
        }
        fail('Petición inesperada: ${request.url.path}');
      }),
    );
    final resultado = await servicio.limpiar();
    expect(quitadas, ['20', '30']);
    expect(resultado.quitados.map((juego) => juego.name), ['Braid']);
    expect(resultado.fallos.single.$1.appId, 30);
    expect(resultado.texto,
        contains('Había 2 juegos del plan familiar en tu lista de deseados'));
    expect(resultado.texto,
        contains('Braid — https://store.steampowered.com/app/20/'));
    expect(resultado.texto, contains('No se pudieron quitar:'));
    final archivo = File(resultado.archivo!);
    expect(archivo.path,
        endsWith('lista_deseados_plan_familiar_2026-11-07_1930.txt'));
    expect(await archivo.readAsString(), resultado.texto);
  });
}
