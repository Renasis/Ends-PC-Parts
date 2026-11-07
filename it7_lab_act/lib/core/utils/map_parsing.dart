/// Null-safe readers for values coming out of the Realtime Database.
///
/// Firebase can return a number as `int`, `double` or even a `String` (when
/// the admin typed it), so models read every field through these helpers.
String readText(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

double readNumber(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? 0;
  return 0;
}

int readInt(Object? value) => readNumber(value).toInt();