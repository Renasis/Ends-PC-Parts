import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/require_login.dart';
import '../../wishlist/providers/wishlist_provider.dart';

/// Heart button that saves or removes a product from the customer's wishlist.
/// Guests are sent to the login screen first.
class WishlistButton extends StatelessWidget {
  final String productId;

  const WishlistButton({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    final isFavorite = context
        .select<WishlistProvider, bool>((wishlist) => wishlist.isFavorite(productId));

    return IconButton(
      tooltip: isFavorite ? 'Remove from wishlist' : 'Add to wishlist',
      icon: Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        color: isFavorite ? Colors.red : Colors.grey.shade600,
      ),
      onPressed: () async {
        final wishlist = context.read<WishlistProvider>();
        final loggedIn = await ensureLoggedIn(
          context,
          message: 'Please log in to save favorites.',
        );
        if (loggedIn) await wishlist.toggleFavorite(productId);
      },
    );
  }
}