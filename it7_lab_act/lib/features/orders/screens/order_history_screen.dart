import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/widgets/login_prompt.dart';
import '../models/order_filter.dart';
import '../widgets/orders_list.dart';

/// Full-screen list of orders for one group ("To Ship", "Completed", ...).
class OrderHistoryScreen extends StatelessWidget {
  final OrderFilter filter;

  const OrderHistoryScreen({super.key, this.filter = OrderFilter.all});

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.watch<AuthProvider>().isAuthenticated;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          filter == OrderFilter.all
              ? 'Purchase History'
              : '${filter.label} Orders',
        ),
      ),
      body: isAuthenticated
          ? OrdersList(filter: filter)
          : const LoginPrompt(message: 'Please login to view orders.'),
    );
  }
}