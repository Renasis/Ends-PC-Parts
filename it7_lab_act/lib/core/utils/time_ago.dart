/// Short, friendly time for a list: "Just now", "5 min ago", "Nov 2, 2026".
String timeAgo(int millisecondsSinceEpoch, {DateTime? now}) {
  if (millisecondsSinceEpoch <= 0) return '';

  final then = DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
  final diff = (now ?? DateTime.now()).difference(then);

  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[then.month - 1]} ${then.day}, ${then.year}';
}
