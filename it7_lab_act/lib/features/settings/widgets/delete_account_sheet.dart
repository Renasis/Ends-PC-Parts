import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/widgets/password_field.dart';
import '../../orders/models/order.dart';
import '../../orders/models/order_status.dart';
import '../../orders/providers/orders_provider.dart';

/// Bottom sheet for permanently deleting the customer's account.
///
/// It explains what is removed and what the store keeps, asks for the
/// password, and asks once more before deleting. Deleting is blocked while an
/// order is still open, so no order is left without a customer who can follow
/// it.
class DeleteAccountSheet extends StatefulWidget {
  const DeleteAccountSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const DeleteAccountSheet(),
    );
  }

  @override
  State<DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<DeleteAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _deleting = false;
  String _error = '';

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  /// An order the customer still needs to follow: not yet delivered, or with
  /// a return or refund still being handled.
  static bool _isOpen(Order order) =>
      order.status == OrderStatus.pending ||
      order.status == OrderStatus.paymentRejected ||
      order.status == OrderStatus.processing ||
      order.status == OrderStatus.shipping ||
      order.isReturnAwaitingReview ||
      order.refundStatus == PaymentStatus.refundPending;

  Future<bool> _confirm() async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This cannot be undone. Your profile, cart, wishlist and login '
          'will be removed for good.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _delete() async {
    if (!_formKey.currentState!.validate()) return;
    if (!await _confirm() || !mounted) return;

    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _deleting = true;
      _error = '';
    });
    final error = await auth.deleteAccount(_password.text);

    if (error == null) {
      // Signed out now: go back to the home screen, which shows the login
      // prompt.
      navigator.popUntil((route) => route.isFirst);
      messenger.showSnackBar(
        const SnackBar(content: Text('Your account has been deleted.')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _deleting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final orders = context.watch<OrdersProvider>();

    final checkingOrders = orders.isLoading;
    final ordersUnknown = orders.errorMessage.isNotEmpty;
    final openOrders = orders.orders.where(_isOpen).length;
    final blocked = checkingOrders || ordersUnknown || openOrders > 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.delete_forever_outlined, color: scheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Delete my account',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.error,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _deleting ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('This is permanent and cannot be undone.'),
              const SizedBox(height: 16),
              const _Heading('What will be deleted'),
              const _Bullet(
                'Your profile and saved delivery address',
              ),
              const _Bullet('Your cart and wishlist'),
              const _Bullet(
                'Your login. You can sign up again later with the same email, '
                'but your old data will not come back.',
              ),
              const SizedBox(height: 12),
              const _Heading('What the store keeps'),
              const _Bullet(
                'Your past orders, payment proofs and return or refund '
                'records',
              ),
              const _Bullet('Your support chat messages'),
              const SizedBox(height: 16),
              if (checkingOrders)
                const _Notice(
                  icon: Icons.hourglass_top,
                  text: 'Checking your orders...',
                )
              else if (ordersUnknown)
                const _Notice(
                  icon: Icons.error_outline,
                  text: 'We could not check your orders. Please check your '
                      'connection, then open this screen again.',
                  isWarning: true,
                )
              else if (openOrders > 0)
                _Notice(
                  icon: Icons.local_shipping_outlined,
                  text: openOrders == 1
                      ? 'You have 1 order that is not finished yet. Wait until '
                          'it is completed or cancelled (and any return or '
                          'refund is done), then delete your account.'
                      : 'You have $openOrders orders that are not finished '
                          'yet. Wait until they are completed or cancelled '
                          '(and any returns or refunds are done), then delete '
                          'your account.',
                  isWarning: true,
                ),
              if (!blocked) ...[
                PasswordField(
                  controller: _password,
                  label: 'Enter your password to confirm',
                  textInputAction: TextInputAction.done,
                  validator: (v) => v == null || v.isEmpty
                      ? 'Enter your password'
                      : null,
                ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_error, style: TextStyle(color: scheme.error)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _deleting ? null : _delete,
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: _deleting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Delete my account'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;

  const _Heading(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('\u2022  '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isWarning;

  const _Notice({
    required this.icon,
    required this.text,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isWarning ? scheme.onErrorContainer : scheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWarning
            ? scheme.errorContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}
