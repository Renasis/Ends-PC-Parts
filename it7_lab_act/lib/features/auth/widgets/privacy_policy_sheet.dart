import 'package:flutter/material.dart';

/// Full-screen-ish sheet that shows the Privacy Policy.
///
/// NOTE: this is starter text written for the app's real data use. Have it
/// reviewed and edit it to match the shop's actual practices.
class PrivacyPolicySheet extends StatelessWidget {
  const PrivacyPolicySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const PrivacyPolicySheet(),
    );
  }

  static const _sections = <(String, String)>[
    (
      'Information we collect',
      'Your name, email address, mobile number and delivery address; your '
          'orders, cart and wishlist; payment proofs you upload (such as '
          'GCash, Maya or bank transfer screenshots); return photos; and '
          'messages you send to our support chat.',
    ),
    (
      'How we use it',
      'To create and secure your account, process and deliver your orders, '
          'verify payments, handle returns and refunds, send in-app '
          'notifications about your orders, and answer your questions.',
    ),
    (
      'Where it is stored',
      'Your data is stored with Google Firebase (Authentication and '
          'Realtime Database). Only you and the store administrators can '
          'see your profile and orders.',
    ),
    (
      'Sharing',
      'We do not sell your personal data. Your name, phone number and '
          'address are only used to deliver your order.',
    ),
    (
      'Your choices',
      'You can view and edit your profile at any time in the Account tab. '
          'You can delete your account in Settings: this removes your '
          'profile, saved address, cart and wishlist, and your login. To ask '
          'for anything else to be corrected or deleted, contact the store '
          'through the in-app support chat.',
    ),
    (
      'What we keep',
      'When you delete your account, the store keeps your past orders, '
          'payment proofs, return and refund records, and support chat '
          'messages, because it needs them for its own records.',
    ),
    (
      'Changes',
      'If this policy changes, we will update it here. Continuing to use '
          'the app means you accept the updated policy.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              children: [
                Text(
                  'Privacy Policy',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'PC Parts Store',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                for (final (title, body) in _sections) ...[
                  Text(
                    title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(body),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
