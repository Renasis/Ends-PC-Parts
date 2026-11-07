import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/widgets/login_prompt.dart';
import '../widgets/orders_list.dart';

/// Body of the "Orders" tab on the home screen (no Scaffold of its own).
class OrdersTab extends StatelessWidget {
  const OrdersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.watch<AuthProvider>().isAuthenticated;
    if (!isAuthenticated) {
      return const LoginPrompt(
        message: 'Please login to view your order history',
      );
    }
    return const OrdersList();
  }
}