import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_update_info.dart';
import '../services/app_update_service.dart';

/// Checks for a newer app version and, when there is one, tells the customer
/// and offers the download link. Call once after the app opens.
Future<void> checkForAppUpdate(BuildContext context) async {
  final info = await AppUpdateService().findUpdate();
  if (info == null || !context.mounted) return;

  await showUpdateDialog(context, info);
}

/// Shows the "Update available" dialog for [info]. Also used by the
/// "Check for updates" button in Settings.
Future<void> showUpdateDialog(BuildContext context, AppUpdateInfo info) {
  return showDialog<void>(
    context: context,
    builder: (_) => _UpdateDialog(info: info),
  );
}

class _UpdateDialog extends StatelessWidget {
  final AppUpdateInfo info;

  const _UpdateDialog({required this.info});

  Future<void> _download(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);

    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(info.apkUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not open the download link. Please try again later.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: Icon(Icons.system_update, color: scheme.primary, size: 32),
      title: const Text('Update available'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info.versionName.isEmpty
                ? 'A new version of Ends Pc Parts is ready.'
                : 'Version ${info.versionName} of Ends Pc Parts is ready.',
          ),
          if (info.message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(info.message, style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 12),
          Text(
            'Download the APK, then tap it to install. Your account and '
            'orders stay as they are.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Later'),
        ),
        FilledButton.icon(
          onPressed: () => _download(context),
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Download'),
        ),
      ],
    );
  }
}
