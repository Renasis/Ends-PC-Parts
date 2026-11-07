import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';

/// Shown when the search or category filter matches nothing.
class NoResultsState extends StatelessWidget {
  final VoidCallback onReset;

  const NoResultsState({super.key, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.network(
              'https://assets9.lottiefiles.com/packages/lf20_02223838.json',
              height: 160,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.search_off, size: 64, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            const Text(
              'No matching products found.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onReset,
              child: const Text('Reset Filters'),
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }
}