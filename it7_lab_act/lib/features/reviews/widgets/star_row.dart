import 'package:flutter/material.dart';

/// Five stars, filled up to [rating].
class StarRow extends StatelessWidget {
  final double rating;
  final double size;

  const StarRow({super.key, required this.rating, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            i < rating ? Icons.star : Icons.star_border,
            size: size,
            color: Colors.amber,
          ),
      ],
    );
  }
}