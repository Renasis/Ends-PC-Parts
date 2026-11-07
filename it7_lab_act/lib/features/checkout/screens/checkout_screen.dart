import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/form_scroll.dart';
import '../../../core/widgets/error_state.dart';
import '../../address/models/address_fields_controller.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/models/cart_item.dart';
import '../../cart/providers/cart_provider.dart';
import '../../promos/providers/promo_provider.dart';
import '../providers/checkout_provider.dart';
import '../widgets/address_section.dart';
import '../widgets/checkout_bottom_bar.dart';
import '../widgets/order_items_card.dart';
import '../widgets/payment_section.dart';
import '../widgets/profile_incomplete_view.dart';
import '../widgets/price_summary_card.dart';
import '../widgets/voucher_card.dart';
import 'order_success_screen.dart';

class CheckoutScreen extends StatelessWidget {
  /// Set by "Buy Now": checkout uses only these items and leaves the cart alone.
  /// When null, checkout uses the items selected in the cart.
  final List<CartItem>? buyNowItems;

  const CheckoutScreen({super.key, this.buyNowItems});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();

    return ChangeNotifierProvider(
      create: (_) => CheckoutProvider(
        items: buyNowItems ?? cart.selectedItems,
        cart: cart,
        isBuyNow: buyNowItems != null,
      ),
      child: const _CheckoutView(),
    );
  }
}

class _CheckoutView extends StatefulWidget {
  const _CheckoutView();

  @override
  State<_CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<_CheckoutView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _newAddress = AddressFieldsController();
  final _paymentKey = GlobalKey();

  /// The customer's explicit pick; null means "not chosen yet", which uses
  /// the saved address whenever there is one (even if it loads late).
  bool? _choice;

  /// A saved address can be used only when name, phone and address are all set.
  bool _hasSaved(AuthProvider auth) =>
      auth.recipientName.isNotEmpty &&
      auth.phoneNumber.isNotEmpty &&
      auth.savedAddress.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    // Pre-fill the new-address contact details; the address itself starts empty.
    _name.text = auth.recipientName;
    _phone.text = auth.phoneNumber;
    if (!auth.isProfileLoaded) auth.fetchUserProfile();
    // The shipping fee depends on the province, so follow it while typing.
    _newAddress.province.addListener(_onProvinceTyped);
  }

  void _onProvinceTyped() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _newAddress.province.removeListener(_onProvinceTyped);
    _newAddress.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    final messenger = ScaffoldMessenger.of(context);

    // Scroll to the first empty box instead of failing silently off-screen.
    if (!validateAndScrollToError(_formKey)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please fill in the highlighted fields.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final checkout = context.read<CheckoutProvider>();
    final promo = context.read<PromoProvider>();
    final auth = context.read<AuthProvider>();
    final uid = auth.currentUser?.uid;
    final navigator = Navigator.of(context);

    FocusScope.of(context).unfocus();

    if (!auth.isProfileComplete) return; // the form is hidden in that case
    final usingSaved = (_choice ?? true) && _hasSaved(auth);
    final address = usingSaved ? auth.savedAddress : _newAddress.toAddress();
    final recipient = usingSaved ? auth.recipientName : _name.text.trim();
    final phone = usingSaved ? auth.phoneNumber : _phone.text.trim();

    final method = checkout.selectedMethod;
    final total = checkout.grandTotal(
      promo.calculateDiscount(checkout.subtotal),
      address.province,
    );

    final orderId = await checkout.placeOrder(
      userId: uid,
      recipientName: recipient,
      phoneNumber: phone,
      deliveryAddress: address.formatted,
      province: address.province,
      deliveryLat: address.latitude,
      deliveryLng: address.longitude,
      discount: promo.calculateDiscount(checkout.subtotal),
      promoCode: promo.appliedPromo?.code,
    );

    if (orderId == null) {
      // Problems shown lower on the page (payment proof) would otherwise be
      // out of sight, so bring them into view and say something.
      final message = checkout.errorMessage.isNotEmpty
          ? checkout.errorMessage
          : checkout.proofError;
      if (message.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
      if (checkout.proofError.isNotEmpty && _paymentKey.currentContext != null) {
        Scrollable.ensureVisible(
          _paymentKey.currentContext!,
          alignment: 0.1,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
      return;
    }

    promo.removePromo();
    if (!mounted) return;
    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => OrderSuccessScreen(
          orderId: orderId,
          paymentLabel: method.label,
          paymentIsOnline: method.isOnline,
          total: total,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkout = context.watch<CheckoutProvider>();
    final promo = context.watch<PromoProvider>();
    final profile = context.watch<AuthProvider>();

    final appBar = AppBar(
      title: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold)),
      elevation: 0,
    );

    // Nobody can order until their name, mobile number and delivery address
    // are saved. This also covers any route that skips the check before
    // opening checkout.
    if (!profile.isProfileLoaded) {
      return Scaffold(
        appBar: appBar,
        body: profile.profileLoadFailed
            ? ErrorState(
                message: 'Could not load your profile. Please check your connection and try again.',
                onRetry: profile.fetchUserProfile,
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }
    if (!profile.isProfileComplete) {
      return Scaffold(
        appBar: appBar,
        body: ProfileIncompleteView(missing: profile.missingProfileItems),
      );
    }

    if (checkout.isLoadingSettings) {
      return Scaffold(
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (checkout.settingsError.isNotEmpty) {
      return Scaffold(
        appBar: appBar,
        body: ErrorState(
          message: checkout.settingsError,
          onRetry: checkout.loadSettings,
        ),
      );
    }

    final items = checkout.items;
    final subtotal = checkout.subtotal;
    final discount = promo.calculateDiscount(subtotal);
    // Delivery fee follows the province of the address being used.
    final usingSaved = _hasSaved(profile) && (_choice ?? true);
    final province =
        usingSaved ? profile.savedAddress.province : _newAddress.province.text;
    final shippingFee = checkout.shippingFeeFor(province);
    final total = checkout.grandTotal(discount, province);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      appBar: appBar,
      body: items.isEmpty
          ? _EmptyOrder(notice: checkout.notice)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (checkout.notice.isNotEmpty) ...[
                      _NoticeBanner(message: checkout.notice),
                      const SizedBox(height: 12),
                    ],
                    Builder(builder: (context) {
                      final auth = context.watch<AuthProvider>();
                      final hasSaved = _hasSaved(auth);
                      return AddressSection(
                        savedName: auth.recipientName,
                        savedPhone: auth.phoneNumber,
                        savedAddress: auth.savedAddress,
                        hasSaved: hasSaved,
                        useSaved: hasSaved && (_choice ?? true),
                        onModeChanged: (v) => setState(() => _choice = v),
                        name: _name,
                        phone: _phone,
                        address: _newAddress,
                      );
                    }),
                    const SizedBox(height: 12),
                    OrderItemsCard(items: items, subtotal: subtotal),
                    const SizedBox(height: 12),
                    VoucherCard(subtotal: subtotal, discount: discount),
                    const SizedBox(height: 12),
                    KeyedSubtree(
                      key: _paymentKey,
                      child: PaymentSection(amount: total),
                    ),
                    const SizedBox(height: 12),
                    PriceSummaryCard(
                      subtotal: subtotal,
                      shippingFee: shippingFee,
                      regularShippingFee:
                          checkout.regularShippingFeeFor(province),
                      remainingForFree: checkout.remainingForFreeShipping,
                      discount: discount,
                      total: total,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: CheckoutBottomBar(
        total: total,
        isSubmitting: checkout.isSubmitting,
        enabled: items.isNotEmpty,
        onPlaceOrder: _placeOrder,
      ),
    );
  }
}

/// Explains what changed in the order after the final stock and price check.
class _NoticeBanner extends StatelessWidget {
  final String message;

  const _NoticeBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

/// Shown when no items are left to order.
class _EmptyOrder extends StatelessWidget {
  final String notice;

  const _EmptyOrder({required this.notice});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_cart_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              notice.isEmpty ? 'No items selected for checkout.' : notice,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}