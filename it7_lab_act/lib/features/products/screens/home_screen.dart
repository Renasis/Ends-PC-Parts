import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../account/screens/account_tab.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../app_update/widgets/update_dialog.dart';
import '../../auth/widgets/privacy_acceptance_dialog.dart';
import '../../cart/providers/cart_provider.dart';
import '../../cart/screens/cart_screen.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../../notifications/widgets/notification_banner_host.dart';
import '../../orders/screens/orders_tab.dart';
import 'home_tab.dart';
import 'shop_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _privacyPromptOpen = false;

  @override
  void initState() {
    super.initState();
    // Once per app launch: tell the customer when a newer APK is published.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) checkForAppUpdate(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Accounts made before the Privacy Policy existed must accept it once.
    final needsPrivacy = context
        .select<AuthProvider, bool>((auth) => auth.needsPrivacyAcceptance);
    if (needsPrivacy && !_privacyPromptOpen) {
      _privacyPromptOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showPrivacyAcceptanceDialog(context);
        _privacyPromptOpen = false;
      });
    }

  final pages = [
    HomeTab(onShopNow: () => setState(() => _currentIndex = 1)),
    const ShopTab(),
    const OrdersTab(),
    const AccountTab(),
  ];

    final itemCount = context.watch<CartProvider>().itemCount;
    final isAuthenticated = context.watch<AuthProvider>().isAuthenticated;
    final unread =
        context.select<NotificationsProvider, int>((p) => p.unreadCount);

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle(_currentIndex)),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  if (isAuthenticated) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                },
              ),
              if (itemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$itemCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack),
            ],
          ),
        ],
      ),
      body: NotificationBannerHost(
        child: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront),
            label: 'Shop',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              child: const Icon(Icons.person_outline),
            ),
            activeIcon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              child: const Icon(Icons.person),
            ),
            label: 'Account',
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return 'PC Parts Store';
      case 1:
        return 'Shop Catalog';
      case 2:
        return 'My Orders';
      case 3:
        return 'Account Profile';
      default:
        return 'Store';
    }
  }
}
