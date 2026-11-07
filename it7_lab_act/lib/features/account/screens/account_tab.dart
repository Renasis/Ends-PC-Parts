import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/widgets/login_prompt.dart';
import '../widgets/account_menu_card.dart';
import '../widgets/my_purchases_card.dart';
import '../widgets/profile_header.dart';
import '../widgets/shipping_info_card.dart';
import '../widgets/verify_email_dialog.dart';

/// The "Account" tab of the home screen.
class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    if (!auth.isAuthenticated || user == null) {
      return const LoginPrompt(
        message: 'Log in to see your profile, orders and notifications.',
      );
    }

    final email = user.email ?? '';
    final fallbackName = email.split('@').first;
    final name = auth.recipientName.isNotEmpty
        ? auth.recipientName
        : (fallbackName.isNotEmpty ? fallbackName : 'User');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ProfileHeader(
          name: name,
          email: email,
          isVerified: user.emailVerified,
          onVerify: () => VerifyEmailDialog.show(context, email: email),
        ).animate().fadeIn(duration: 350.ms),
        const SizedBox(height: 16),
        const MyPurchasesCard().animate().fadeIn(delay: 80.ms),
        const SizedBox(height: 16),
        ShippingInfoCard(
          name: name,
          email: email,
          phone: auth.phoneNumber,
          address: auth.savedAddress,
        ).animate().fadeIn(delay: 160.ms),
        const SizedBox(height: 16),
        const AccountMenuCard().animate().fadeIn(delay: 240.ms),
        const SizedBox(height: 24),
      ],
    );
  }
}
