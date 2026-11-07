import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/surface_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/widgets/privacy_policy_sheet.dart';
import '../../legal/data/legal_documents.dart';
import '../../legal/widgets/legal_document_sheet.dart';
import '../widgets/about_card.dart';
import '../widgets/change_password_sheet.dart';
import '../widgets/delete_account_sheet.dart';
import '../widgets/email_verification_tile.dart';
import '../widgets/notification_preferences_card.dart';
import '../widgets/theme_mode_picker.dart';

/// Appearance, notification choices, security, legal pages, app version and
/// account deletion.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final signedIn =
        context.select<AuthProvider, bool>((auth) => auth.isAuthenticated);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionLabel('Appearance'),
          const SurfaceCard(child: ThemeModePicker()),
          const SizedBox(height: 24),
          const _SectionLabel('Notifications'),
          const NotificationPreferencesCard(),
          if (signedIn) ...[
            const SizedBox(height: 24),
            const _SectionLabel('Security'),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _NavTile(
                    icon: Icons.lock_outline,
                    title: 'Change Password',
                    subtitle: 'Update your account password',
                    onTap: () => ChangePasswordSheet.show(context),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  const EmailVerificationTile(),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          const _SectionLabel('Legal'),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _NavTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'How we collect and use your data',
                  onTap: () => PrivacyPolicySheet.show(context),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _NavTile(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  subtitle: 'The rules for using the app and ordering',
                  onTap: () =>
                      LegalDocumentSheet.show(context, LegalDocuments.terms),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _NavTile(
                  icon: Icons.assignment_return_outlined,
                  title: 'Return & Refund Policy',
                  subtitle: 'How returns and refunds work',
                  onTap: () => LegalDocumentSheet.show(
                    context,
                    LegalDocuments.returnPolicy,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('About'),
          const AboutCard(),
          if (signedIn) ...[
            const SizedBox(height: 24),
            const _SectionLabel('Account'),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: _NavTile(
                icon: Icons.delete_forever_outlined,
                color: scheme.error,
                title: 'Delete my account',
                titleColor: scheme.error,
                subtitle: 'Permanently remove your profile, cart and login',
                onTap: () => DeleteAccountSheet.show(context),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final String title;
  final Color? titleColor;
  final String subtitle;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;

    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: tint),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w500, color: titleColor),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
