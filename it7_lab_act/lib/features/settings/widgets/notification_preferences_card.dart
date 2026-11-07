import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/surface_card.dart';
import '../../notifications/models/app_notification.dart';
import '../../notifications/providers/notification_preferences.dart';

/// Switches for the three kinds of notifications. The choices are saved on
/// this phone only and just hide the types that are switched off.
class NotificationPreferencesCard extends StatelessWidget {
  const NotificationPreferencesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = context.watch<NotificationPreferences>();

    Widget toggle({
      required NotificationKind kind,
      required IconData icon,
      required String title,
      required String subtitle,
    }) {
      return SwitchListTile(
        value: prefs.allows(kind),
        onChanged: (value) => prefs.setAllowed(kind, value),
        secondary: Icon(icon, color: theme.colorScheme.primary),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(subtitle),
      );
    }

    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          toggle(
            kind: NotificationKind.order,
            icon: Icons.local_shipping_outlined,
            title: 'Order updates',
            subtitle: 'Status changes, returns and refunds',
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          toggle(
            kind: NotificationKind.price,
            icon: Icons.sell_outlined,
            title: 'Price changes',
            subtitle: 'When an item in your wishlist goes up or down in price',
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          toggle(
            kind: NotificationKind.general,
            icon: Icons.campaign_outlined,
            title: 'Promos & system messages',
            subtitle: 'News and announcements from the store',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Text(
              'Switched-off types are hidden in the bell, the Notifications '
              'list and the pop-up banners on this phone. Nothing is deleted.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
