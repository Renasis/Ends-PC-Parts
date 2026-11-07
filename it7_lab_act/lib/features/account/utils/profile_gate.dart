import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../widgets/edit_profile_sheet.dart';

/// Customers must have a name, a mobile number and a full delivery address
/// (with ZIP code) saved before they can order.
///
/// Call this after [ensureLoggedIn] and before opening checkout. When the
/// profile is incomplete it explains what is missing and opens the profile
/// form. Returns true only when the profile is complete afterwards.
Future<bool> ensureProfileComplete(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  final messenger = ScaffoldMessenger.of(context);

  if (!auth.isProfileLoaded) await auth.fetchUserProfile();
  if (!context.mounted) return false;

  if (!auth.isProfileLoaded) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Could not load your profile. Please check your connection and try again.'),
        backgroundColor: Colors.red,
      ),
    );
    return false;
  }
  if (auth.isProfileComplete) return true;

  final proceed = await showDialog<bool>(
    context: context,
    builder: (_) => _CompleteProfileDialog(missing: auth.missingProfileItems),
  );
  if (proceed != true || !context.mounted) return false;

  await EditProfileSheet.show(context);
  return auth.isProfileComplete;
}

class _CompleteProfileDialog extends StatelessWidget {
  final List<String> missing;
  const _CompleteProfileDialog({required this.missing});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.badge_outlined, size: 36),
      title: const Text('Complete your profile first'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'We need your details to deliver your order and reach you if '
            'something comes up. Still missing:',
          ),
          const SizedBox(height: 12),
          for (final item in missing)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.radio_button_unchecked,
                      size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Complete profile'),
        ),
      ],
    );
  }
}
