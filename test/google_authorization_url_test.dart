import 'package:flutter_test/flutter_test.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:todo/services/calendar_service_io.dart';

void main() {
  test('la URL de autorización de Google se genera una sola vez', () {
    final grant = oauth2.AuthorizationCodeGrant(
      'cliente.apps.googleusercontent.com',
      Uri.parse('https://accounts.google.com/o/oauth2/v2/auth'),
      Uri.parse('https://oauth2.googleapis.com/token'),
      secret: 'secreto',
    );

    final url = googleAuthorizationUrl(
        grant, Uri.parse('http://127.0.0.1:5000/oauth2callback'));

    expect(
        url.queryParameters['client_id'], 'cliente.apps.googleusercontent.com');
    expect(url.queryParameters['access_type'], 'offline');
    expect(url.queryParameters['prompt'], 'consent');
    expect(url.queryParameters['scope'], contains('auth/calendar'));
    // Pedirla otra vez por el mismo cliente es justo el error que se corrigió.
    expect(
        () => grant.getAuthorizationUrl(
            Uri.parse('http://127.0.0.1:5000/oauth2callback')),
        throwsStateError);
  });
}
