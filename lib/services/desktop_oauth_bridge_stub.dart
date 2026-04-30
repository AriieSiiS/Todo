Future<bool> signInWithDesktopGoogleOAuth({
  required String redirectUrl,
  required void Function(String message) setError,
}) async {
  setError('Este acceso solo esta disponible en la app de escritorio.');
  return false;
}
