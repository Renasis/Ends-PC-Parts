import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/widgets/surface_card.dart';
import '../../app_update/services/app_update_service.dart';
import '../../app_update/widgets/update_dialog.dart';

/// The app name and version, with a button that looks for a newer version.
class AboutCard extends StatefulWidget {
  const AboutCard({super.key});

  @override
  State<AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<AboutCard> {
  String _versionText = 'Loading...';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    String text;
    try {
      final info = await PackageInfo.fromPlatform();
      text = 'Version ${info.version} (build ${info.buildNumber})';
    } catch (_) {
      text = 'Version unavailable';
    }
    if (!mounted) return;
    setState(() => _versionText = text);
  }

  Future<void> _checkForUpdates() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _checking = true);

    final result = await AppUpdateService().check();
    if (!mounted) return;
    setState(() => _checking = false);

    switch (result.status) {
      case UpdateCheckStatus.updateAvailable:
        await showUpdateDialog(context, result.info!);
      case UpdateCheckStatus.upToDate:
        messenger.showSnackBar(
          const SnackBar(content: Text('You have the latest version.')),
        );
      case UpdateCheckStatus.failed:
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Could not check for updates. Please check your connection and try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.info_outline, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PC Parts Store',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _versionText,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _checking ? null : _checkForUpdates,
              icon: _checking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.system_update, size: 18),
              label: Text(_checking ? 'Checking...' : 'Check for updates'),
            ),
          ),
        ],
      ),
    );
  }
}
