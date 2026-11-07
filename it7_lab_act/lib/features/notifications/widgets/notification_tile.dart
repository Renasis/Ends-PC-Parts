import 'package:flutter/material.dart';

import '../../../core/utils/time_ago.dart';
import '../models/app_notification.dart';

/// One row of the notifications list. Unread ones are tinted and bold.
class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unread = !notification.isRead;
    final look = _lookOf(notification.kind, scheme);

    return Material(
      color: unread
          ? scheme.primaryContainer.withValues(alpha: 0.35)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: look.color.withValues(alpha: 0.15),
                child: Icon(look.icon, color: look.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    if (notification.message.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        notification.message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      timeAgo(notification.timestamp),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread)
                Container(
                  margin: const EdgeInsets.only(left: 8, top: 6),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

({IconData icon, Color color}) _lookOf(
  NotificationKind kind,
  ColorScheme scheme,
) {
  switch (kind) {
    case NotificationKind.order:
      return (icon: Icons.local_shipping_outlined, color: scheme.primary);
    case NotificationKind.price:
      return (icon: Icons.sell_outlined, color: Colors.orange.shade700);
    case NotificationKind.general:
      return (icon: Icons.notifications_outlined, color: scheme.secondary);
  }
}
