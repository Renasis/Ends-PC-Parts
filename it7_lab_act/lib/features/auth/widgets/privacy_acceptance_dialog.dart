import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'privacy_policy_sheet.dart';

/// Shown once to customers whose account was made before the Privacy Policy
/// existed. They either accept it or log out; it cannot be dismissed.
Future<void> showPrivacyAcceptanceDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _PrivacyAcceptanceDialog(),
  );
}

class _PrivacyAcceptanceDialog extends StatefulWidget {
  const _PrivacyAcceptanceDialog();

  @override
  State<_PrivacyAcceptanceDialog> createState() =>
      _PrivacyAcceptanceDialogState();
}

class _PrivacyAcceptanceDialogState extends State<_PrivacyAcceptanceDialog> {
  bool _saving = false;
  String _error = '';

  Future<void> _accept() async {
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = '';
    });
    final ok = await auth.acceptPrivacy();
    if (!mounted) return;
    if (ok) {
      navigator.pop();
    } else {
      setState(() {
        _saving = false;
        _error = auth.errorMessage;
      });
    }
  }

  Future<void> _logout() async {
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    await auth.logout();
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Privacy Policy'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'We added a Privacy Policy that explains what data we collect '
              'and how we use it. Please read and accept it to keep using '
              'your account.',
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed:
                  _saving ? null : () => PrivacyPolicySheet.show(context),
              child: const Text('Read the Privacy Policy'),
            ),
            if (_error.isNotEmpty)
              Text(_error, style: TextStyle(color: scheme.error)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _logout,
            child: const Text('Log out'),
          ),
          FilledButton(
            onPressed: _saving ? null : _accept,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('I understand and agree'),
          ),
        ],
      ),
    );
  }
}
