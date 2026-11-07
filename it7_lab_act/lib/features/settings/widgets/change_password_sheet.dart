import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';

/// Bottom sheet that asks for the current password and a new one.
class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ChangePasswordSheet(),
    );
  }

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _showPasswords = false;
  bool _saving = false;
  String _error = '';

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _saving = true;
      _error = '';
    });
    final changed = await auth.changePassword(
      currentPassword: _current.text,
      newPassword: _new.text,
    );

    if (!mounted) return;
    if (changed) {
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() {
        _saving = false;
        _error = auth.errorMessage;
      });
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
      );

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
                    'Change Password',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _current,
                obscureText: !_showPasswords,
                decoration: _decoration('Current password'),
                validator: (v) => v == null || v.isEmpty
                    ? 'Enter your current password'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _new,
                obscureText: !_showPasswords,
                decoration: _decoration('New password'),
                validator: (v) => v == null || v.length < 6
                    ? 'Use at least 6 characters'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                obscureText: !_showPasswords,
                decoration: _decoration('Confirm new password'),
                validator: (v) =>
                    v != _new.text ? 'Passwords do not match' : null,
              ),
              CheckboxListTile(
                value: _showPasswords,
                onChanged: (v) => setState(() => _showPasswords = v ?? false),
                title: const Text('Show passwords'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(_error, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Change password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
