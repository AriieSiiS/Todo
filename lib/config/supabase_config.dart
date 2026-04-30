class SupabaseConfig {
  const SupabaseConfig._();

  static const String _repoSupabaseUrl =
      'https://hgdzwoieicreenpapese.supabase.co';
  static const String _repoPublishableKey =
      'sb_publishable_7QgBLNA353YvBgI2dPlnaw_R_tkfjtS';
  static const String _repoAllowedEmail = 'ariesix20@gmail.com';
  static const String _repoRedirectUrl = 'http://localhost:3000/';

  static const String _supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String _nextPublicSupabaseUrl =
      String.fromEnvironment('NEXT_PUBLIC_SUPABASE_URL', defaultValue: '');
  static const String _anonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  static const String _publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: '');
  static const String _nextPublicPublishableKey = String.fromEnvironment(
    'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );
  static const String _allowedEmail =
      String.fromEnvironment('SUPABASE_ALLOWED_EMAIL', defaultValue: '');
  static const String _redirectUrl =
      String.fromEnvironment('SUPABASE_REDIRECT_URL', defaultValue: '');

  static Future<void> load() async {}

  static String get url {
    if (_supabaseUrl.isNotEmpty) {
      return _supabaseUrl;
    }
    if (_nextPublicSupabaseUrl.isNotEmpty) {
      return _nextPublicSupabaseUrl;
    }
    return _repoSupabaseUrl;
  }

  static String get anonKey {
    if (_anonKey.isNotEmpty) {
      return _anonKey;
    }
    if (_publishableKey.isNotEmpty) {
      return _publishableKey;
    }
    if (_nextPublicPublishableKey.isNotEmpty) {
      return _nextPublicPublishableKey;
    }
    return _repoPublishableKey;
  }

  static String get allowedEmail {
    if (_allowedEmail.isNotEmpty) {
      return _allowedEmail;
    }
    return _repoAllowedEmail;
  }

  static String get redirectUrl {
    if (_redirectUrl.isNotEmpty) {
      return _redirectUrl;
    }
    return _repoRedirectUrl;
  }

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
  static bool get hasAllowedEmail => allowedEmail.isNotEmpty;
}
