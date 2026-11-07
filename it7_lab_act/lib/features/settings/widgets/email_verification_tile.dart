import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../account/widgets/verify_email_dialog.dart';
import '../../auth/providers/auth_provider.dart';

/// One row for the Security section: shows whether the customer's email is
/// verified, or a "Verify now" button that opens the same dialog as the
/// Account tab.
class EmailVerificationTile extends StatelessWidget {
  const EmailVerificationTile({super.key});

  @override
  Widget build(BuildContext context) {
    // Watching AuthProvider also refreshes this row after the dialog's
    // "I've verified" check reloads the account.
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const SizedBox.shrink();

    final email = user.email ?? '';
    final verified = user.emailVerified;
    final color = verified ? Colors.green.shade700 : Colors.orange.shade700;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          verified
              ? Icons.mark_email_read_outlined
              : Icons.mark_email_unread_outlined,
          color: color,
        ),
      ),
      title: const Text(
        'Email verification',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(email, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: verified
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, color: color, size: 18),
                const SizedBox(width: 4),
                Text(
                  'Verified',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ],
            )
          : FilledButton.tonal(
              onPressed: email.isEmpty
                  ? null
                  : () => VerifyEmailDialog.show(context, email: email),
              child: const Text('Verify now'),
            ),
    );
  }
}
