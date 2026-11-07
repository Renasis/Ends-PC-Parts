import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../validators.dart';

/// Bottom sheet that emails a password reset link.
class ForgotPasswordSheet extends StatefulWidget {
  /// Filled in from what the customer already typed on the login screen.
  final String initialEmail;

  const ForgotPasswordSheet({super.key, this.initialEmail = ''});

  static Future<void> show(BuildContext context, {String initialEmail = ''}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ForgotPasswordSheet(initialEmail: initialEmail),
    );
  }

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail.trim());
  bool _sending = false;
  String _error = '';

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final email = _email.text.trim();

    setState(() {
      _sending = true;
      _error = '';
    });
    final error = await auth.sendPasswordReset(email);

    if (!mounted) return;
    if (error == null) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'If an account exists for $email, a reset link is on its way. '
            'Check your inbox and spam folder.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() {
        _sending = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Forgot Password',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your account email and we will send you a link to choose a new password.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                onFieldSubmitted: (_) => _sending ? null : _send(),
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: AuthValidators.email,
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_error, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send reset link'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
