import 'dart:isolate';

/// Cola única para el trabajo pesado con imágenes (decodificar, redimensionar
/// y codificar). Cada trabajo corre en un isolate aparte, así que la interfaz
/// no se congela, y de uno en uno, así que importar varias imágenes seguidas
/// no dispara la memoria con varias fotos decodificadas a la vez.
Future<void> _ultimo = Future<void>.value();

Future<T> procesarImagen<T>(T Function() trabajo) {
  final resultado = _ultimo.then((_) => Isolate.run(trabajo));
  _ultimo = resultado.then<void>((_) {}, onError: (Object _, StackTrace __) {});
  return resultado;
}
