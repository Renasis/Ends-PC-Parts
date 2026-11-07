import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../providers/notifications_provider.dart';
import '../screens/notifications_screen.dart';

/// Wraps a screen and shows a banner at the top whenever a new notification
/// arrives while the app is open. Tapping "View" opens the notifications list.
class NotificationBannerHost extends StatefulWidget {
  final Widget child;

  const NotificationBannerHost({super.key, required this.child});

  @override
  State<NotificationBannerHost> createState() => _NotificationBannerHostState();
}

class _NotificationBannerHostState extends State<NotificationBannerHost> {
  static const _visibleFor = Duration(seconds: 6);

  StreamSubscription<AppNotification>? _sub;
  ScaffoldMessengerState? _messenger;
  Timer? _hideTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
    _sub ??= context.read<NotificationsProvider>().incoming.listen(_show);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _sub?.cancel();
    // The messenger rebuilds when banners change, which is not allowed while
    // this widget is being removed, so clear them after the frame.
    final messenger = _messenger;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => messenger?.clearMaterialBanners(),
    );
    super.dispose();
  }

  void _show(AppNotification item) {
    final messenger = _messenger;
    if (messenger == null || !mounted) return;

    final scheme = Theme.of(context).colorScheme;
    final icon = switch (item.kind) {
      NotificationKind.price => Icons.sell_outlined,
      NotificationKind.order => Icons.local_shipping_outlined,
      NotificationKind.general => Icons.notifications_outlined,
    };

    messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: scheme.primaryContainer,
        leading: Icon(icon, color: scheme.onPrimaryContainer),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: scheme.onPrimaryContainer,
              ),
            ),
            if (item.message.isNotEmpty)
              Text(
                item.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: messenger.hideCurrentMaterialBanner,
            child: const Text('Dismiss'),
          ),
          TextButton(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
            child: const Text('View'),
          ),
        ],
      ),
    );

    _hideTimer?.cancel();
    _hideTimer = Timer(_visibleFor, messenger.hideCurrentMaterialBanner);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
