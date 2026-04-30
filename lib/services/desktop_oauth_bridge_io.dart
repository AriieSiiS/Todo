import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> signInWithDesktopGoogleOAuth({
  required String redirectUrl,
  required void Function(String message) setError,
}) async {
  HttpServer? server;
  StreamSubscription<HttpRequest>? subscription;

  try {
    final redirectUri = Uri.parse(redirectUrl);
    final host = redirectUri.host.isEmpty ? 'localhost' : redirectUri.host;
    final port = redirectUri.hasPort ? redirectUri.port : 3000;
    final path = redirectUri.path.isEmpty ? '/' : redirectUri.path;

    server =
        await HttpServer.bind(InternetAddress.loopbackIPv4, port, shared: true);
    final completer = Completer<bool>();

    Future<void> finishRequest(
        HttpRequest request, String html, bool success) async {
      request.response.headers.contentType = ContentType.html;
      request.response.write(html);
      await request.response.close();
      if (!completer.isCompleted) {
        completer.complete(success);
      }
      await subscription?.cancel();
      await server?.close(force: true);
    }

    subscription = server.listen((request) async {
      if (request.uri.path != path) {
        request.response.statusCode = HttpStatus.notFound;
        request.response.headers.contentType = ContentType.html;
        request.response.write(_htmlPage(
          title: 'Ruta no valida',
          body: 'Esta ventana ya no hace falta. Puedes volver a Todo.',
          success: false,
        ));
        await request.response.close();
        return;
      }

      final error = request.uri.queryParameters['error_description'] ??
          request.uri.queryParameters['error'];
      final code = request.uri.queryParameters['code'];

      if (error != null && error.isNotEmpty) {
        setError('Google ha cancelado o rechazado el acceso.');
        await finishRequest(
          request,
          _htmlPage(
            title: 'Acceso cancelado',
            body: 'Puedes cerrar esta ventana y volver a la app.',
            success: false,
          ),
          false,
        );
        return;
      }

      if (code == null || code.isEmpty) {
        setError('No llego el codigo de acceso de Google.');
        await finishRequest(
          request,
          _htmlPage(
            title: 'Falta el codigo',
            body:
                'No se pudo terminar el acceso. Vuelve a la app e intentalo de nuevo.',
            success: false,
          ),
          false,
        );
        return;
      }

      try {
        await Supabase.instance.client.auth.exchangeCodeForSession(code);
        setError('');
        await finishRequest(
          request,
          _htmlPage(
            title: 'Todo ya esta conectado',
            body:
                'La sesion se ha guardado. Puedes cerrar esta ventana y volver a la app.',
            success: true,
          ),
          true,
        );
      } catch (_) {
        setError('La vuelta de Google no se pudo completar dentro de la app.');
        await finishRequest(
          request,
          _htmlPage(
            title: 'No se pudo completar',
            body:
                'La app recibio la vuelta de Google, pero no pudo guardar la sesion. Prueba otra vez.',
            success: false,
          ),
          false,
        );
      }
    });

    final response = await Supabase.instance.client.auth.getOAuthSignInUrl(
      provider: OAuthProvider.google,
      redirectTo: 'http://$host:$port$path',
    );

    final launched = await launchUrl(
      Uri.parse(response.url),
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      setError('No se pudo abrir el navegador para Google.');
      await subscription.cancel();
      await server.close(force: true);
      return false;
    }

    return await completer.future.timeout(
      const Duration(minutes: 3),
      onTimeout: () async {
        setError('Google tardo demasiado en volver a la app.');
        await subscription?.cancel();
        await server?.close(force: true);
        return false;
      },
    );
  } catch (_) {
    setError('No se pudo preparar la vuelta local del acceso de Google.');
    await subscription?.cancel();
    await server?.close(force: true);
    return false;
  }
}

String _htmlPage({
  required String title,
  required String body,
  required bool success,
}) {
  final accent = success ? '#6f8a5e' : '#b46a58';
  return '''
<!doctype html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>$title</title>
    <style>
      :root {
        color-scheme: light;
      }
      body {
        margin: 0;
        min-height: 100vh;
        display: grid;
        place-items: center;
        background: linear-gradient(135deg, #f7f1e8, #ebe2d5);
        font-family: "Segoe UI", sans-serif;
        color: #231f1a;
      }
      article {
        width: min(420px, calc(100vw - 40px));
        padding: 28px;
        border-radius: 24px;
        background: rgba(255, 255, 255, 0.86);
        box-shadow: 0 18px 48px rgba(0, 0, 0, 0.12);
        border: 1px solid rgba(125, 106, 81, 0.18);
      }
      .pill {
        display: inline-flex;
        padding: 8px 12px;
        border-radius: 999px;
        background: ${accent}22;
        color: $accent;
        font-weight: 700;
        margin-bottom: 14px;
      }
      h1 {
        font-size: 28px;
        line-height: 1.1;
        margin: 0 0 12px;
      }
      p {
        margin: 0;
        line-height: 1.6;
        color: #5b5349;
      }
    </style>
  </head>
  <body>
    <article>
      <div class="pill">Todo</div>
      <h1>$title</h1>
      <p>$body</p>
    </article>
  </body>
</html>
''';
}
