import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/error_state.dart';
import '../../orders/screens/order_history_screen.dart';
import '../../products/screens/product_details_screen.dart';
import '../models/app_notification.dart';
import '../providers/notifications_provider.dart';
import '../widgets/notification_tile.dart';

/// All of the customer's notifications, newest first.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (provider.unreadCount > 0)
            TextButton.icon(
              onPressed: () => _markAllRead(context),
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark all read'),
            ),
        ],
      ),
      body: _body(context, provider),
    );
  }

  Widget _body(BuildContext context, NotificationsProvider provider) {
    if (provider.errorMessage.isNotEmpty) {
      return ErrorState(
        message: provider.errorMessage,
        onRetry: provider.retry,
      );
    }
    if (provider.isLoading && provider.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.items.isEmpty) return const _EmptyState();

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: provider.items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = provider.items[index];
        return Dismissible(
          key: ValueKey(item.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Theme.of(context).colorScheme.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) => _delete(context, item),
          child: NotificationTile(
            notification: item,
            onTap: () => _open(context, item),
          ),
        );
      },
    );
  }

  Future<void> _markAllRead(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<NotificationsProvider>().markAllRead();
    if (error != null) _showError(messenger, error);
  }

  Future<void> _delete(BuildContext context, AppNotification item) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<NotificationsProvider>().delete(item);
    if (error != null) _showError(messenger, error);
  }

  Future<void> _open(BuildContext context, AppNotification item) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final error = await context.read<NotificationsProvider>().markRead(item);
    if (error != null) _showError(messenger, error);

    switch (item.kind) {
      case NotificationKind.order:
        navigator.push(
          MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
        );
      case NotificationKind.price:
        if (item.productId.isNotEmpty) {
          navigator.push(
            MaterialPageRoute(
              builder: (_) => ProductDetailsScreen(productId: item.productId),
            ),
          );
        }
      case NotificationKind.general:
        break;
    }
  }

  void _showError(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.notifications_none,
                size: 40,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text('No notifications yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Order updates and price changes on items in your wishlist will show up here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
