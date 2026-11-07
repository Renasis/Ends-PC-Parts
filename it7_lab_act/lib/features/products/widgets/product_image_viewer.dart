import 'package:flutter/material.dart';

import '../../../core/widgets/product_image.dart';

/// Full-screen picture that can be pinched and dragged to zoom.
class ProductImageViewer extends StatelessWidget {
  final String source;
  final String heroTag;

  const ProductImageViewer({
    super.key,
    required this.source,
    required this.heroTag,
  });

  static Future<void> open(
    BuildContext context, {
    required String source,
    required String heroTag,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        pageBuilder: (_, _, _) =>
            ProductImageViewer(source: source, heroTag: heroTag),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: SizedBox.expand(
          child: Hero(
            tag: heroTag,
            child: ProductImage(source, fit: BoxFit.contain, iconSize: 96),
          ),
        ),
      ),
    );
  }
}
