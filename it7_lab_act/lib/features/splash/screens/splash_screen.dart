import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../products/providers/product_provider.dart';
import '../../products/screens/home_screen.dart';
import '../widgets/rgb_keyboard.dart';

/// Shows the shop logo while the products load. The keyboard lights up
/// until the shop is ready, then the app opens the home screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// Long enough to see the lights, even when everything loads instantly.
  static const _minimumTime = Duration(milliseconds: 2500);

  /// Never keep the customer waiting longer than this (e.g. no internet).
  static const _maximumWait = Duration(seconds: 6);

  @override
  void initState() {
    super.initState();
    _openHomeWhenReady();
  }

  Future<void> _openHomeWhenReady() async {
    await Future.wait([
      Future<void>.delayed(_minimumTime),
      _waitForProducts(),
    ]);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  /// Completes when the product list has loaded (or failed), or after
  /// [_maximumWait]. The home screen shows its own error state if it failed.
  Future<void> _waitForProducts() {
    final products = context.read<ProductProvider>();
    if (!products.isLoading) return Future.value();

    final loaded = Completer<void>();
    void onChange() {
      if (!products.isLoading && !loaded.isCompleted) loaded.complete();
    }

    products.addListener(onChange);
    return loaded.future
        .timeout(_maximumWait, onTimeout: () {})
        .whenComplete(() => products.removeListener(onChange));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/splash_logo.png',
                width: double.infinity,
                fit: BoxFit.fitWidth,
                semanticLabel: 'Ends PC Parts',
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.computer,
                  size: 120,
                  color: Colors.white70,
                ),
              ),
              const RgbKeyboard(),
            ],
          ).animate().fadeIn(duration: 600.ms),
        ),
      ),
    );
  }
}