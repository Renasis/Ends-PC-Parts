import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/notifications_provider.dart';
import '../screens/notifications_screen.dart';

/// A bell that shows how many notifications are still unread and opens the
/// notifications list.
class NotificationBell extends StatelessWidget {
  final Color? color;

  const NotificationBell({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final unread =
        context.select<NotificationsProvider, int>((p) => p.unreadCount);

    return IconButton(
      tooltip: 'Notifications',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
      },
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: Icon(Icons.notifications_outlined, color: color),
      ),
    );
  }
}
