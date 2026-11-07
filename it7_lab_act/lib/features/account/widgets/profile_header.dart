import 'package:flutter/material.dart';

import '../../notifications/widgets/notification_bell.dart';

/// Top card of the Account tab: avatar, name, email and the notification bell.
class ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final bool isVerified;

  /// Shows a "Verify email" button while the address is not verified.
  final VoidCallback onVerify;

  const ProfileHeader({
    super.key,
    required this.name,
    required this.email,
    required this.isVerified,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.tertiary, 0.45)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: scheme.onPrimary,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
              ),
              if (isVerified)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.onPrimary, width: 2),
                  ),
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onPrimary.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
                if (!isVerified)
                  TextButton.icon(
                    onPressed: onVerify,
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onPrimary,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.mark_email_unread_outlined, size: 16),
                    label: const Text('Verify email'),
                  ),
              ],
            ),
          ),
          NotificationBell(color: scheme.onPrimary),
        ],
      ),
    );
  }
}
