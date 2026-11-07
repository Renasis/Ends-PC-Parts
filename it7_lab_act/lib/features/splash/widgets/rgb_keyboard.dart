import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The glowing keyboard from the logo, animated like gaming RGB lighting:
/// the colours keep cycling through the rainbow while a band of light
/// sweeps across the keys. It repeats until the widget is removed.
class RgbKeyboard extends StatefulWidget {
  const RgbKeyboard({super.key});

  @override
  State<RgbKeyboard> createState() => _RgbKeyboardState();
}

class _RgbKeyboardState extends State<RgbKeyboard>
    with SingleTickerProviderStateMixin {
  /// One full colour cycle and one full sweep of the light band.
  static const _cycleTime = Duration(seconds: 4);

  /// How dark the keys get away from the light band.
  static const _dim = Color(0xFF666666);

  /// Width of one light band, as a share of the keyboard width.
  static const _bandWidth = 0.6;

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _cycleTime)..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// A colour matrix that rotates every hue by [degrees]. Black stays black,
  /// so only the lit parts of the picture change colour.
  static ColorFilter _hueRotation(double degrees) {
    final radians = degrees * math.pi / 180;
    final c = math.cos(radians);
    final s = math.sin(radians);
    return ColorFilter.matrix(<double>[
      0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715,
      0.072 - c * 0.072 + s * 0.928, 0, 0, //
      0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140,
      0.072 - c * 0.072 - s * 0.283, 0, 0, //
      0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715,
      0.072 + c * 0.928 + s * 0.072, 0, 0, //
      0, 0, 0, 1, 0, //
    ]);
  }

  /// Bands of full brightness on a dimmer background, moving to the right.
  /// The pattern repeats, so after one cycle it looks exactly like the start.
  /// Multiplying it with the picture keeps the black background black.
  static Shader _lightBand(Rect bounds, double progress) {
    final bandWidth = bounds.width * _bandWidth;
    return const LinearGradient(
      colors: [_dim, Colors.white, _dim],
      tileMode: TileMode.repeated,
    ).createShader(
      Rect.fromLTWH(
        bounds.left + progress * bandWidth,
        bounds.top,
        bandWidth,
        bounds.height,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = Image.asset(
      'assets/images/splash_keyboard.png',
      width: double.infinity,
      fit: BoxFit.fitWidth,
      errorBuilder: (context, error, stackTrace) => const SizedBox(
        height: 60,
        child: Center(
          child: Icon(
            Icons.keyboard,
            size: 48,
            color: Colors.white30,
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _controller,
      child: keyboard,
      builder: (context, child) {
        final progress = _controller.value;
        return ColorFiltered(
          colorFilter: _hueRotation(progress * 360),
          child: ShaderMask(
            blendMode: BlendMode.modulate,
            shaderCallback: (bounds) => _lightBand(bounds, progress),
            child: child,
          ),
        );
      },
    );
  }
}