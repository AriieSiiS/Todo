import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:multicast_dns/multicast_dns.dart';

import 'mobile_lan_store.dart';

class LanPairingData {
  const LanPairingData({
    required this.serverId,
    required this.endpoint,
    required this.certificateFingerprint,
    required this.secret,
    required this.expiresAt,
  });

  final String serverId;
  final String endpoint;
  final String certificateFingerprint;
  final String secret;
  final DateTime expiresAt;

  factory LanPairingData.parse(String raw) {
    final json = (jsonDecode(raw) as Map).cast<String, dynamic>();
    final endpoint = json['endpoint'] as String? ?? '';
    final fingerprint = (json['certificateFingerprint'] as String? ?? '')
        .replaceAll(':', '')
        .toLowerCase();
    final expiresAt = DateTime.tryParse(json['expiresAt'] as String? ?? '');
    if (json['type'] != 'todo-lan-pairing' ||
        (json['protocolVersion'] as num?)?.toInt() != 1 ||
        !endpoint.startsWith('https://') ||
        fingerprint.length != 64 ||
        expiresAt == null ||
        expiresAt.toLocal().isBefore(DateTime.now())) {
      throw const FormatException(
          'El código de emparejamiento no es válido o ha caducado.');
    }
    return LanPairingData(
      serverId: json['serverId'] as String? ?? '',
      endpoint: endpoint,
      certificateFingerprint: fingerprint,
      secret: json['secret'] as String? ?? '',
      expiresAt: expiresAt.toLocal(),
    );
  }
}

class LanPairingResult {
  const LanPairingResult({required this.config, required this.token});

  final LanConnectionConfig config;
  final String token;
}

class LanSyncResult {
  const LanSyncResult({
    required this.changed,
    required this.endpoint,
    this.snapshot,
  });

  final bool changed;
  final String endpoint;
  final Map<String, dynamic>? snapshot;
}

class LanWardrobeResult {
  const LanWardrobeResult({
    required this.changed,
    required this.endpoint,
    this.snapshot,
  });

  final bool changed;
  final String endpoint;
  final Map<String, dynamic>? snapshot;
}

class MobileLanClient {
  Future<LanWardrobeResult> syncWardrobe({
    required LanConnectionConfig config,
    required String token,
    required String revision,
  }) async {
    final endpoints = <String>[config.endpoint];
    final discovered = await discoverEndpoint(config.serverId);
    if (discovered != null && !endpoints.contains(discovered)) {
      endpoints.add(discovered);
    }
    Object? lastError;
    for (final endpoint in endpoints.where((value) => value.isNotEmpty)) {
      final client = _pinnedClient(config.certificateFingerprint);
      try {
        final request = await client
            .getUrl(Uri.parse('$endpoint/v1/wardrobe-snapshot'))
            .timeout(const Duration(seconds: 8));
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        if (revision.isNotEmpty) {
          request.headers.set(HttpHeaders.ifNoneMatchHeader, '"$revision"');
        }
        final response =
            await request.close().timeout(const Duration(seconds: 10));
        if (response.statusCode == HttpStatus.notModified) {
          return LanWardrobeResult(changed: false, endpoint: endpoint);
        }
        final body = await utf8.decoder.bind(response).join();
        if (response.statusCode != 200) {
          throw StateError(response.statusCode == 404
              ? 'Actualiza Todo en Windows para compartir Ropa.'
              : _errorMessage(response.statusCode, body));
        }
        final json = (jsonDecode(body) as Map).cast<String, dynamic>();
        if (json['serverId'] != config.serverId ||
            (json['protocolVersion'] as num?)?.toInt() != 1 ||
            (json['wardrobeVersion'] as num?)?.toInt() != 1) {
          throw const FormatException('La respuesta de Ropa no es compatible.');
        }
        return LanWardrobeResult(
          changed: true,
          endpoint: endpoint,
          snapshot: json,
        );
      } catch (error) {
        lastError = error;
      } finally {
        client.close(force: true);
      }
    }
    throw StateError('No se pudo descargar Ropa: $lastError');
  }

  Future<Uint8List?> wardrobeImage({
    required LanConnectionConfig config,
    required String endpoint,
    required String token,
    required String itemId,
    required String variant,
  }) async {
    final client = _pinnedClient(config.certificateFingerprint);
    try {
      final uri = Uri.parse('$endpoint/v1/wardrobe-image/$itemId')
          .replace(queryParameters: {'variant': variant});
      final request =
          await client.getUrl(uri).timeout(const Duration(seconds: 8));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final response =
          await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        throw StateError(
            'No se pudo descargar una foto: ${response.statusCode}.');
      }
      const maximumBytes = 10 * 1024 * 1024;
      if (response.contentLength > maximumBytes) {
        throw const FormatException('Una foto supera el tamaño permitido.');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        builder.add(chunk);
        if (builder.length > maximumBytes) {
          throw const FormatException('Una foto supera el tamaño permitido.');
        }
      }
      return builder.takeBytes();
    } finally {
      client.close(force: true);
    }
  }

  Future<LanPairingResult> pair(
    LanPairingData pairing, {
    required String deviceName,
  }) async {
    final client = _pinnedClient(pairing.certificateFingerprint);
    try {
      final request = await client
          .postUrl(Uri.parse('${pairing.endpoint}/v1/pair'))
          .timeout(const Duration(seconds: 8));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'secret': pairing.secret,
        'deviceName': deviceName,
      }));
      final response =
          await request.close().timeout(const Duration(seconds: 8));
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode != 200) {
        throw StateError(_errorMessage(response.statusCode, body));
      }
      final json = (jsonDecode(body) as Map).cast<String, dynamic>();
      if (json['serverId'] != pairing.serverId) {
        throw const FormatException(
            'El PC respondió con una identidad diferente.');
      }
      final token = json['token'] as String? ?? '';
      if (token.isEmpty) {
        throw const FormatException('El PC no devolvió un token.');
      }
      return LanPairingResult(
        token: token,
        config: LanConnectionConfig(
          serverId: pairing.serverId,
          deviceId: json['deviceId'] as String? ?? '',
          endpoint: pairing.endpoint,
          certificateFingerprint: pairing.certificateFingerprint,
          revision: '',
          lastSyncAt: null,
        ),
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<LanSyncResult> sync({
    required LanConnectionConfig config,
    required String token,
  }) async {
    final endpoints = <String>[config.endpoint];
    final discovered = await discoverEndpoint(config.serverId);
    if (discovered != null && !endpoints.contains(discovered)) {
      endpoints.add(discovered);
    }
    Object? lastError;
    for (final endpoint in endpoints.where((value) => value.isNotEmpty)) {
      final client = _pinnedClient(config.certificateFingerprint);
      try {
        final request = await client
            .getUrl(Uri.parse('$endpoint/v1/task-snapshot'))
            .timeout(const Duration(seconds: 8));
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        if (config.revision.isNotEmpty) {
          request.headers
              .set(HttpHeaders.ifNoneMatchHeader, '"${config.revision}"');
        }
        final response =
            await request.close().timeout(const Duration(seconds: 10));
        if (response.statusCode == HttpStatus.notModified) {
          return LanSyncResult(changed: false, endpoint: endpoint);
        }
        final body = await utf8.decoder.bind(response).join();
        if (response.statusCode != 200) {
          throw StateError(_errorMessage(response.statusCode, body));
        }
        final json = (jsonDecode(body) as Map).cast<String, dynamic>();
        if (json['serverId'] != config.serverId ||
            (json['protocolVersion'] as num?)?.toInt() != 1) {
          throw const FormatException(
              'La respuesta pertenece a otro PC o versión.');
        }
        return LanSyncResult(
          changed: true,
          endpoint: endpoint,
          snapshot: json,
        );
      } catch (error) {
        lastError = error;
      } finally {
        client.close(force: true);
      }
    }
    throw StateError(
      'No se pudo alcanzar el PC emparejado en esta red Wi-Fi${lastError == null ? '.' : ': $lastError'}',
    );
  }

  Future<String?> discoverEndpoint(String serverId) async {
    final client = MDnsClient();
    try {
      await client.start();
      final pointer = await client
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer('_todo-sync._tcp.local'),
          )
          .firstWhere(
            (record) => record.domainName
                .toLowerCase()
                .contains(serverId.toLowerCase()),
          )
          .timeout(const Duration(seconds: 3));
      final service = await client
          .lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(pointer.domainName))
          .first
          .timeout(const Duration(seconds: 2));
      final address = await client
          .lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(service.target),
          )
          .first
          .timeout(const Duration(seconds: 2));
      return 'https://${address.address.address}:${service.port}';
    } catch (_) {
      return null;
    } finally {
      client.stop();
    }
  }

  HttpClient _pinnedClient(String expectedFingerprint) {
    final normalized = expectedFingerprint.replaceAll(':', '').toLowerCase();
    return HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..badCertificateCallback = (certificate, _, __) {
        final lines = certificate.pem
            .split(RegExp(r'\r?\n'))
            .where((line) => !line.startsWith('---') && line.trim().isNotEmpty)
            .join();
        final der = base64Decode(lines);
        final actual = sha256.convert(der).toString();
        return _constantTimeEquals(actual, normalized);
      };
  }

  String _errorMessage(int status, String body) {
    try {
      final error = (jsonDecode(body) as Map)['error'];
      if (error == 'codigo_caducado') {
        return 'El código ha caducado. Genera otro en Windows.';
      }
      if (error == 'no_autorizado') {
        return 'El acceso de este móvil ha sido revocado.';
      }
    } catch (_) {}
    return 'El PC respondió con el estado $status.';
  }
}

bool _constantTimeEquals(String left, String right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
  }
  return difference == 0;
}
