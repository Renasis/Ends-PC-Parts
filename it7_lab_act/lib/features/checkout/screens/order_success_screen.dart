import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';

class OrderSuccessScreen extends StatelessWidget {
  final String? orderId;
  final String paymentLabel;
  final bool paymentIsOnline;
  final double total;

  const OrderSuccessScreen({
    super.key,
    this.orderId,
    this.paymentLabel = 'COD',
    this.paymentIsOnline = false,
    this.total = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _checkmark().animate()
                  .scale(duration: 400.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 24),
              const Text(
                'Order Placed Successfully!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (orderId != null) _row('Order ID', orderId!),
                      _row('Payment Method', paymentLabel),
                      _row('Total', '₱${total.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 12),
              Text(
                paymentIsOnline
                    ? 'Your payment proof was submitted. We will process your order once your payment is verified.'
                    : 'Please prepare the exact amount for the courier. You can track your order under the Orders tab.',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 350.ms),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                child: const Text('Return to Home'),
              ).animate().fadeIn(delay: 500.ms).scale(begin: const Offset(0.9, 0.9)),
            ],
          ),
        ),
      ),
    );
  }

  /// Typed as Widget so `.animate()` is the flutter_animate extension
  /// (Lottie has its own `animate` field).
  Widget _checkmark() => Lottie.network(
        'https://assets2.lottiefiles.com/packages/lf20_pqn42y2e.json',
        height: 180,
        repeat: false,
        errorBuilder: (_, _, _) => const Icon(
          Icons.check_circle_outline,
          size: 96,
          color: Colors.green,
        ),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey)),
            const SizedBox(width: 16),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}