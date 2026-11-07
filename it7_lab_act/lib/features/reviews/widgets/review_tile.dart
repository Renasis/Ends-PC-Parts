import 'package:flutter/material.dart';

import '../models/review.dart';
import 'star_row.dart';

class ReviewTile extends StatelessWidget {
  final Review review;

  const ReviewTile({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                review.userName,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            StarRow(rating: review.rating),
          ],
        ),
        const SizedBox(height: 4),
        Text(review.comment, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        if (review.adminReply.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Store reply: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: review.adminReply),
                ],
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }
}