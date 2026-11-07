const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Nov 6, 2026", or an empty string when there is no date yet.
String formatDate(int millisecondsSinceEpoch) {
  if (millisecondsSinceEpoch <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
  return '${_months[d.month - 1]} ${d.day}, ${d.year}';
}

/// "Nov 6, 2026 · 3:45 PM", or an empty string when there is no date yet.
String formatDateTime(int millisecondsSinceEpoch) {
  if (millisecondsSinceEpoch <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final period = d.hour < 12 ? 'AM' : 'PM';
  return '${formatDate(millisecondsSinceEpoch)} · $hour:$minute $period';
}
