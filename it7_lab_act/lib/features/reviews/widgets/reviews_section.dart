import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/require_login.dart';
import '../providers/reviews_provider.dart';
import 'review_form_sheet.dart';
import 'review_tile.dart';

/// "Customer Reviews" block on the product details screen.
/// Needs a [ReviewsProvider] above it.
class ReviewsSection extends StatelessWidget {
  const ReviewsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReviewsProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _Summary(provider: provider)),
            OutlinedButton.icon(
              onPressed: () => _writeReview(context),
              icon: const Icon(Icons.rate_review_outlined, size: 16),
              label: const Text('Write Review'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Body(provider: provider),
      ],
    );
  }

  Future<void> _writeReview(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final reviews = context.read<ReviewsProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final loggedIn = await ensureLoggedIn(
      context,
      message: 'Please log in to write a review.',
    );
    final user = auth.currentUser;
    if (!loggedIn || user == null || !context.mounted) return;

    final eligibility = await reviews.checkEligibility(user.uid);
    if (!context.mounted) return;

    if (eligibility == ReviewEligibility.failed) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not check your purchases. Please try again.'),
      ));
      return;
    }
    if (eligibility == ReviewEligibility.notPurchased) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Verified Buyers Only'),
          content: const Text(
            'Only customers who have received this product can submit a review.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final draft = await showReviewFormSheet(context);
    if (draft == null) return;

    final name = auth.recipientName.isNotEmpty
        ? auth.recipientName
        : user.email?.split('@').first ?? 'Buyer';
    final saved = await reviews.addReview(
      userId: user.uid,
      userName: name,
      rating: draft.rating,
      comment: draft.comment,
    );
    messenger.showSnackBar(SnackBar(
      content: Text(saved
          ? 'Review submitted successfully!'
          : 'Could not submit your review. Please try again.'),
    ));
  }
}

class _Summary extends StatelessWidget {
  final ReviewsProvider provider;

  const _Summary({required this.provider});

  @override
  Widget build(BuildContext context) {
    final count = provider.reviews.length;
    final text = count == 0
        ? 'No reviews yet'
        : '${provider.averageRating.toStringAsFixed(1)} '
            '($count ${count == 1 ? 'review' : 'reviews'})';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Customer Reviews',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 20),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  final ReviewsProvider provider;

  const _Body({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (provider.errorMessage.isNotEmpty) {
      return Column(
        children: [
          Text(provider.errorMessage, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: provider.retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      );
    }
    if (provider.reviews.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Be the first verified buyer to leave a review!',
          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: provider.reviews.length,
      separatorBuilder: (_, _) => const Divider(height: 16),
      itemBuilder: (_, index) => ReviewTile(review: provider.reviews[index]),
    );
  }
}