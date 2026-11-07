import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';

/// Sends the verification link, then lets the customer confirm once they have
/// opened it (the app cannot find out by itself).
class VerifyEmailDialog extends StatefulWidget {
  final String email;

  const VerifyEmailDialog({super.key, required this.email});

  static Future<void> show(BuildContext context, {required String email}) {
    return showDialog<void>(
      context: context,
      builder: (_) => VerifyEmailDialog(email: email),
    );
  }

  @override
  State<VerifyEmailDialog> createState() => _VerifyEmailDialogState();
}

class _VerifyEmailDialogState extends State<VerifyEmailDialog> {
  bool _sent = false;
  bool _busy = false;
  String _message = '';

  Future<void> _send() async {
    final auth = context.read<AuthProvider>();
    setState(() {
      _busy = true;
      _message = '';
    });
    final error = await auth.sendVerificationEmail();

    if (!mounted) return;
    setState(() {
      _busy = false;
      _sent = error == null;
      _message = error ?? '';
    });
  }

  Future<void> _confirm() async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _message = '';
    });
    final verified = await auth.refreshVerification();

    if (!mounted) return;
    if (verified) {
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Email verified. Thank you!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() {
        _busy = false;
        _message = 'Not verified yet. Open the link in the email, then try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    return AlertDialog(
      title: const Text('Verify your email'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _sent
                ? 'We sent a link to ${widget.email}. Open it, then tap "I\'ve verified".'
                : 'We will email a verification link to ${widget.email}.',
          ),
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_message, style: TextStyle(color: errorColor)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (_sent) ...[
          TextButton(
            onPressed: _busy ? null : _send,
            child: const Text('Resend'),
          ),
          FilledButton(
            onPressed: _busy ? null : _confirm,
            child: const Text("I've verified"),
          ),
        ] else
          FilledButton(
            onPressed: _busy ? null : _send,
            child: const Text('Send link'),
          ),
      ],
    );
  }
}
