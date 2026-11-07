import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/widgets/product_image.dart';
import '../services/product_image_service.dart';
import 'product_image_viewer.dart';

/// The big picture at the top of the product page, with an optional gallery of
/// additional images below.
///
/// Shows the first image from [imageUrls] (or [thumbnail]) as the main picture,
/// then a horizontal scrollable row of thumbnails for the remaining images.
/// Tapping the main picture opens it full screen for zooming.
class ProductImageHeader extends StatefulWidget {
  final String productId;
  final String thumbnail;
  final List<String> imageUrls;

  const ProductImageHeader({
    super.key,
    required this.productId,
    required this.thumbnail,
    this.imageUrls = const [],
  });

  @override
  State<ProductImageHeader> createState() => _ProductImageHeaderState();
}

class _ProductImageHeaderState extends State<ProductImageHeader> {
  final _service = ProductImageService();
  String? _fullImage;
  bool _loading = true;
  int _selectedIndex = 0;

  String get _heroTag => 'product-image-${widget.productId}';

  /// All images: main (index 0) + gallery thumbnails.
  List<String> get _allImages {
    final urls = <String>[];
    if (_fullImage != null && _fullImage!.isNotEmpty) {
      urls.add(_fullImage!);
    }
    if (widget.thumbnail.isNotEmpty && widget.thumbnail != _fullImage) {
      urls.add(widget.thumbnail);
    }
    urls.addAll(widget.imageUrls.where((u) => u != _fullImage && u != widget.thumbnail));
    return urls;
  }

  String get _currentImage => _fullImage ?? (_allImages.isNotEmpty ? _allImages[_selectedIndex] : widget.thumbnail);

  @override
  void initState() {
    super.initState();
    _loadFullImage();
  }

  Future<void> _loadFullImage() async {
    try {
      final full = await _service.loadFull(widget.productId);
      if (mounted && full != null) setState(() => _fullImage = full);
    } catch (_) {
      // Offline or not allowed: the thumbnail already on screen is enough.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final source = _currentImage;

    final hasGallery = _allImages.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => ProductImageViewer.open(
            context,
            source: source,
            heroTag: _heroTag,
          ),
          child: Container(
            height: 280,
            width: double.infinity,
            color: colors.surfaceContainerHighest,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: _heroTag,
                  child: ProductImage(source, fit: BoxFit.cover, iconSize: 80),
                ),
                if (_loading)
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.zoom_in, size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)),

        if (hasGallery) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _allImages.length,
              itemBuilder: (context, index) {
                final isSelected = index == _selectedIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: ProductImage(
                        _allImages[index],
                        fit: BoxFit.cover,
                        iconSize: 32,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
