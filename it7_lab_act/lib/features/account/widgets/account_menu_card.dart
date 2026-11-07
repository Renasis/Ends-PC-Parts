import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/surface_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/screens/chat_screen.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../support/screens/help_support_screen.dart';

/// Help & Support, Support Chat, Notifications, Settings and Sign Out.
class AccountMenuCard extends StatelessWidget {
  const AccountMenuCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unread =
        context.select<NotificationsProvider, int>((p) => p.unreadCount);
    final chatUnread = context.select<ChatProvider, bool>((p) => p.hasUnread);

    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _MenuTile(
            icon: Icons.help_outline,
            color: Colors.teal.shade700,
            title: 'Help & Support',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _MenuTile(
            icon: Icons.support_agent,
            color: Colors.green.shade700,
            title: 'Support Chat',
            showDot: chatUnread,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatScreen()),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _MenuTile(
            icon: Icons.notifications_outlined,
            color: Colors.orange.shade700,
            title: 'Notifications',
            unread: unread,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _MenuTile(
            icon: Icons.settings_outlined,
            color: scheme.primary,
            title: 'Settings',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _MenuTile(
            icon: Icons.logout,
            color: scheme.error,
            title: 'Sign Out',
            titleColor: scheme.error,
            onTap: () => _confirmSignOut(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().logout();
    }
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final Color? titleColor;
  final int unread;
  final bool showDot;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.titleColor,
    this.unread = 0,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w500, color: titleColor),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (unread > 0) Badge.count(count: unread),
          if (showDot) const Badge(smallSize: 10),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
