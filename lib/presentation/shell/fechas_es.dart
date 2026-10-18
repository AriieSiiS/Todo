part of 'app_shell.dart';

const List<String> _mesesCompletos = <String>[
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

const List<String> _diasCompletos = <String>[
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

/// «18 de octubre de 2026».
String _fechaLarga(DateTime fecha) =>
    '${fecha.day} de ${_mesesCompletos[fecha.month - 1]} de ${fecha.year}';

/// «domingo, 18 de octubre».
String _fechaConDia(DateTime fecha) =>
    '${_diasCompletos[fecha.weekday - 1]}, ${fecha.day} de ${_mesesCompletos[fecha.month - 1]}';

/// «octubre de 2026».
String _mesYAnio(DateTime fecha) =>
    '${_mesesCompletos[fecha.month - 1]} de ${fecha.year}';

/// «18/10/2026».
String _fechaNumerica(DateTime fecha) =>
    '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

/// «2 h 05 min» o «45 min».
String _duracionLegible(int segundos) {
  final minutos = segundos ~/ 60;
  if (minutos < 60) return '$minutos min';
  final horas = minutos ~/ 60;
  final resto = minutos % 60;
  return '$horas h ${resto.toString().padLeft(2, '0')} min';
}

String _capitalizar(String texto) =>
    texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);
