import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/entities/shopping.dart';

typedef PriceApiCall = Future<Map<String, dynamic>> Function(
    String method, String path, Map<String, dynamic>? body);

class PriceObservation {
  PriceObservation.fromJson(Map<String, dynamic> data)
      : price = (data['price'] as num).toDouble(),
        checkedAt = DateTime.parse(data['checkedAt'] as String).toLocal();
  final double price;
  final DateTime checkedAt;
}

class PriceWatch {
  PriceWatch.fromJson(Map<String, dynamic> data)
      : enabled = data['enabled'] as bool? ?? false,
        name = data['name'] as String? ?? '',
        url = data['url'] as String? ?? '',
        currentPrice = (data['currentPrice'] as num?)?.toDouble(),
        checkedAt =
            DateTime.tryParse(data['checkedAt'] as String? ?? '')?.toLocal(),
        lastSuccessAt =
            DateTime.tryParse(data['lastSuccessAt'] as String? ?? '')
                ?.toLocal(),
        error = data['error'] as String? ?? '',
        history = (data['history'] as List? ?? [])
            .map((value) => PriceObservation.fromJson(
                Map<String, dynamic>.from(value as Map)))
            .toList(growable: false),
        offers = (data['offers'] as List? ?? [])
            .map((value) =>
                PriceWatch.fromJson(Map<String, dynamic>.from(value as Map)))
            .toList(growable: false);
  final bool enabled;
  final String name;
  final String url;
  final double? currentPrice;
  final DateTime? checkedAt;
  final DateTime? lastSuccessAt;
  final String error;
  final List<PriceObservation> history;
  final List<PriceWatch> offers;
}

class PriceAlert {
  PriceAlert.fromJson(Map<String, dynamic> data)
      : itemId = data['itemId'] as String,
        name = data['name'] as String,
        previousPrice = (data['previousPrice'] as num).toDouble(),
        price = (data['price'] as num).toDouble(),
        checkedAt = DateTime.parse(data['checkedAt'] as String).toLocal(),
        seen = data['seen'] as bool? ?? false,
        notificationError = data['notificationError'] as String? ?? '';
  final String itemId;
  final String name;
  final double previousPrice;
  final double price;
  final DateTime checkedAt;
  final bool seen;
  final String notificationError;
}

/// Consulta el servicio del usuario. El historial nunca reemplaza precios manuales.
class ShoppingPriceService extends ChangeNotifier {
  ShoppingPriceService(
      {this.enabled = true, Directory? runtimeDirectory, PriceApiCall? apiCall})
      : _runtimeDirectory = runtimeDirectory,
        _apiCall = apiCall;

  final bool enabled;
  final Directory? _runtimeDirectory;
  final PriceApiCall? _apiCall;
  Timer? _timer;
  bool _disposed = false;
  bool _refreshing = false;
  bool available = false;
  bool notificationsEnabled = true;
  String issue = '';
  Map<String, PriceWatch> _watches = {};
  List<PriceAlert> alerts = [];

  PriceWatch? watch(String id) => _watches[id];
  int get activeCount => _watches.values.where((watch) => watch.enabled).length;
  int get unreadCount => alerts.where((alert) => !alert.seen).length;

  static bool supports(ShoppingItem item) {
    final urls = item.offers.isEmpty
        ? [item.sourceUrl]
        : item.offers.map((offer) => offer.sourceUrl);
    return urls.every(supportsUrl);
  }

  static bool supportsUrl(String value) {
    final url = Uri.tryParse(value);
    return url != null &&
        url.scheme == 'https' &&
        url.userInfo.isEmpty &&
        (url.host == 'amazon.es' || url.host == 'www.amazon.es') &&
        url.port == 443 &&
        RegExp(r'/(?:dp|gp/product)/[a-zA-Z0-9]{10}(?:/|$)').hasMatch(url.path);
  }

  Future<void> start() async {
    if (!enabled || _disposed || _timer != null) return;
    await refresh();
    if (!_disposed) {
      _timer = Timer.periodic(
          const Duration(seconds: 15), (_) => unawaited(refresh()));
    }
  }

  Future<Map<String, dynamic>> _call(String method, String path,
      [Map<String, dynamic>? body]) async {
    if (_apiCall != null) return _apiCall(method, path, body);
    final root = _runtimeDirectory ??
        Directory('${Platform.environment['LOCALAPPDATA']}/Todo/price_tracker');
    final connection =
        jsonDecode(await File('${root.path}/connection.json').readAsString())
            as Map;
    final port = connection['port'];
    final token = connection['token'];
    if (port is! int ||
        port < 1 ||
        port > 65535 ||
        token is! String ||
        token.length < 32) {
      throw StateError('La configuración del seguimiento no es válida.');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client.openUrl(
          method, Uri.parse('http://127.0.0.1:$port$path'));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response =
          await request.close().timeout(const Duration(seconds: 20));
      final data = jsonDecode(await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 5))) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        throw StateError(
            data['error'] as String? ?? 'No se pudo completar el seguimiento.');
      }
      return data;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> refresh() async {
    if (!enabled || _disposed || _refreshing) return;
    _refreshing = true;
    try {
      final data = await _call('GET', '/state');
      final watches = Map<String, dynamic>.from(data['watches'] as Map? ?? {});
      final parsed = watches.map((key, value) => MapEntry(
          key, PriceWatch.fromJson(Map<String, dynamic>.from(value as Map))));
      final parsedAlerts = (data['alerts'] as List? ?? [])
          .map((value) =>
              PriceAlert.fromJson(Map<String, dynamic>.from(value as Map)))
          .toList(growable: false);
      if (_disposed) return;
      _watches = parsed;
      alerts = parsedAlerts;
      available = data['engineAvailable'] == true;
      notificationsEnabled = data['notificationsEnabled'] != false;
      issue = available
          ? ''
          : 'El motor de seguimiento está arrancando o no está disponible.';
    } catch (_) {
      if (_disposed) return;
      available = false;
      issue =
          'El servicio de precios no está disponible. El historial guardado se conserva.';
    } finally {
      _refreshing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> setTracking(ShoppingItem item, bool value) async {
    await _call('PUT', '/watches/${item.id}', {
      'name': item.name,
      'sourceUrl': item.sourceUrl,
      'offers': item.offers.map((offer) => offer.toJson()).toList(),
      'targetPrice': item.targetPrice,
      'status': item.status.name,
      'archived': item.archived,
      'enabled': value,
    });
    await refresh();
  }

  Future<void> checkNow(String id) async => _call('POST', '/watches/$id/check');

  Future<void> markAlertsRead() async {
    await _call('POST', '/alerts/read');
    await refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
