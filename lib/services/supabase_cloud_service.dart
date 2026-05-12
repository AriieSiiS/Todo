import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../domain/models.dart';
import 'desktop_oauth_bridge_stub.dart'
    if (dart.library.io) 'desktop_oauth_bridge_io.dart';

class SupabaseCloudService {
  SupabaseCloudService();

  static bool _sdkInitialized = false;
  String _lastError = '';

  String get lastError => _lastError;
  bool get isConfigured => SupabaseConfig.isConfigured;
  bool get isInitialized => _sdkInitialized;
  String get url => SupabaseConfig.url;
  String get allowedEmail => SupabaseConfig.allowedEmail;
  String get redirectUrl => SupabaseConfig.redirectUrl;
  bool get isAuthenticated =>
      _sdkInitialized && Supabase.instance.client.auth.currentSession != null;
  String get currentEmail {
    if (!_sdkInitialized) {
      return '';
    }
    return Supabase.instance.client.auth.currentUser?.email ?? '';
  }

  Future<void> initialize() async {
    await SupabaseConfig.load();
    if (!isConfigured || _sdkInitialized) {
      return;
    }
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
        authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
      );
      _sdkInitialized = true;
      _lastError = '';
      await _enforceAllowedEmail();
    } catch (error) {
      _lastError = 'No se pudo iniciar Supabase. ${_cleanError(error)}';
      rethrow;
    }
  }

  Future<bool> signInWithGoogle() async {
    if (!isConfigured) {
      _lastError = 'Falta la configuración de Supabase.';
      return false;
    }
    try {
      await initialize();
    } catch (_) {
      return false;
    }

    try {
      final launched = await signInWithDesktopGoogleOAuth(
        redirectUrl:
            redirectUrl.isNotEmpty ? redirectUrl : 'http://localhost:3000/',
        setError: (message) {
          _lastError = message;
        },
      );
      if (!launched && _lastError.isEmpty) {
        _lastError = 'No se pudo abrir el acceso de Google.';
      }
      return launched;
    } catch (error) {
      _lastError =
          'No se pudo iniciar el acceso en Windows. ${_cleanError(error)}';
      return false;
    }
  }

  Future<void> signOut() async {
    if (!_sdkInitialized) {
      return;
    }
    try {
      await Supabase.instance.client.auth.signOut();
      _lastError = '';
    } catch (error) {
      _lastError = 'No se pudo cerrar la sesión. ${_cleanError(error)}';
      rethrow;
    }
  }

  Future<AppStateSnapshot?> fetchSnapshot() async {
    try {
      await initialize();
      await _enforceAllowedEmail();
      if (!isAuthenticated || currentEmail.isEmpty) {
        return null;
      }

      final response = await Supabase.instance.client
          .from('todo_app_states')
          .select('state')
          .eq('owner_email', currentEmail)
          .maybeSingle();
      if (response == null) {
        _lastError = '';
        return null;
      }

      final rawState = response['state'];
      if (rawState is! Map<String, dynamic>) {
        _lastError = '';
        return null;
      }
      _lastError = '';
      return AppStateSnapshot.fromJson(rawState);
    } catch (error) {
      _lastError = 'No se pudo leer la nube. ${_cleanError(error)}';
      rethrow;
    }
  }

  Future<void> pushSnapshot(AppStateSnapshot snapshot) async {
    try {
      await initialize();
      await _enforceAllowedEmail();
      if (!isAuthenticated || currentEmail.isEmpty) {
        return;
      }

      await Supabase.instance.client.from('todo_app_states').upsert(
        <String, dynamic>{
          'owner_email': currentEmail,
          'schema_version': snapshot.schemaVersion,
          'state': snapshot.toJson(),
          'updated_at': snapshot.resolvedUpdatedAt.toUtc().toIso8601String(),
        },
        onConflict: 'owner_email',
      );
      _lastError = '';
    } catch (error) {
      _lastError = 'No se pudo guardar en la nube. ${_cleanError(error)}';
      rethrow;
    }
  }

  String _cleanError(Object error) {
    final text = error.toString().trim();
    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }
    return text;
  }

  Future<void> _enforceAllowedEmail() async {
    if (!isConfigured || !_sdkInitialized || !SupabaseConfig.hasAllowedEmail) {
      return;
    }

    final email = currentEmail;
    if (email.isEmpty) {
      return;
    }
    if (email.toLowerCase() == SupabaseConfig.allowedEmail.toLowerCase()) {
      _lastError = '';
      return;
    }

    _lastError = 'La cuenta conectada no coincide con el email permitido.';
    await Supabase.instance.client.auth.signOut();
  }
}
