import 'package:flutter/material.dart';

import '../../account/widgets/edit_profile_sheet.dart';

/// Shown instead of the checkout form when the customer's profile is not
/// complete. Checkout opens again by itself once it is saved.
class ProfileIncompleteView extends StatelessWidget {
  final List<String> missing;
  const ProfileIncompleteView({super.key, required this.missing});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.badge_outlined, size: 56, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              'Complete your profile to place an order',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'We need these details to deliver your order:',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            for (final item in missing)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.radio_button_unchecked,
                        size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(item),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => EditProfileSheet.show(context),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Complete profile'),
            ),
          ],
        ),
      ),
    );
  }
}
