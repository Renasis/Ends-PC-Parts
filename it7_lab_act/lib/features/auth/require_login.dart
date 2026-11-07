import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';

/// Guests can browse and fill a cart, but must log in before checking out.
/// Returns true when the person is (or just became) logged in.
///
/// [message] is shown before the login screen opens.
Future<bool> ensureLoggedIn(
  BuildContext context, {
  String message = 'Please log in to check out.',
}) async {
  final auth = context.read<AuthProvider>();
  if (auth.isAuthenticated) return true;

  final navigator = Navigator.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
  await navigator.push(MaterialPageRoute(builder: (_) => const LoginScreen()));
  return auth.isAuthenticated;
}