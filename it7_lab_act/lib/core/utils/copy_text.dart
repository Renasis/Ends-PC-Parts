import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Copies [text] to the clipboard and tells the person with a snackbar.
Future<void> copyText(BuildContext context, String text, String message) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: text));
  messenger.showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
  );
}
