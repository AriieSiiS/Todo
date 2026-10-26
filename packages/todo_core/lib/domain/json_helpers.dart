T enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}

List<String> stringList(Object? value) {
  return (value as List<dynamic>? ?? const <dynamic>[]).cast<String>();
}
