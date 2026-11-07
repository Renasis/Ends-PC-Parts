import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Shows a product picture stored as a base64 string (with or without the
/// `data:image/...;base64,` prefix). Falls back to a placeholder icon when the
/// image is missing or cannot be decoded. Plain http(s) URLs also work.
///
/// Decoded bytes are remembered, so scrolling back to a product does not
/// decode its base64 again, and the picture is decoded at the size it is
/// shown (see [cacheWidth]) instead of full size.
class ProductImage extends StatefulWidget {
  final String source;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double iconSize;

  /// Width in logical pixels the picture is decoded at. Defaults to [width]
  /// when that is set; with neither, the picture is decoded at full size.
  final int? cacheWidth;

  const ProductImage(
    this.source, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.iconSize = 32,
    this.cacheWidth,
  });

  @override
  State<ProductImage> createState() => _ProductImageState();
}

class _ProductImageState extends State<ProductImage> {
  /// Most recently used decoded pictures, kept under [_maxCacheBytes].
  static const _maxCacheBytes = 16 * 1024 * 1024;
  static final _cache = <String, Uint8List>{}; // keeps insertion order
  static int _cacheBytes = 0;

  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _decode(widget.source);
  }

  @override
  void didUpdateWidget(ProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _bytes = _decode(widget.source);
    }
  }

  static Uint8List? _decode(String source) {
    if (source.isEmpty || source.startsWith('http')) return null;

    final key = '${source.length}-${source.hashCode}';
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached; // now the most recently used
      return cached;
    }

    final comma = source.indexOf(',');
    final raw = source.startsWith('data:') && comma != -1
        ? source.substring(comma + 1)
        : source;
    try {
      final bytes = base64Decode(raw.replaceAll(RegExp(r'\s'), ''));
      _cache[key] = bytes;
      _cacheBytes += bytes.length;
      while (_cacheBytes > _maxCacheBytes && _cache.length > 1) {
        final oldest = _cache.keys.first;
        _cacheBytes -= _cache.remove(oldest)!.length;
      }
      return bytes;
    } on FormatException {
      return null; // not valid base64: the placeholder is shown instead
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined,
          size: widget.iconSize, color: Colors.grey),
    );

    final width = widget.width;
    final decodeWidth = widget.cacheWidth ??
        (width != null && width.isFinite
            ? (width * MediaQuery.devicePixelRatioOf(context)).round()
            : null);

    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheWidth: decodeWidth,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    if (widget.source.startsWith('http')) {
      return Image.network(
        widget.source,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheWidth: decodeWidth,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    return placeholder;
  }
}
