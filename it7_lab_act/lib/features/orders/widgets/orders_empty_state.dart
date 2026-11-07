import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class OrdersEmptyState extends StatelessWidget {
  final String message;

  const OrdersEmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.network(
              'https://assets5.lottiefiles.com/packages/lf20_e1p5a6q5.json',
              height: 180,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}