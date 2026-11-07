import 'package:flutter/material.dart';

import '../screens/login_screen.dart';

/// Centered "please log in" message with a button that opens the login screen.
class LoginPrompt extends StatelessWidget {
  final IconData icon;
  final String message;
  final String buttonLabel;

  const LoginPrompt({
    super.key,
    required this.message,
    this.icon = Icons.lock_outline,
    this.buttonLabel = 'Login',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}