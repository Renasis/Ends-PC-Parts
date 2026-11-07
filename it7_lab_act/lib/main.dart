import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'firebase_options.dart'; 
import 'features/auth/providers/auth_provider.dart';
import 'features/cart/providers/cart_provider.dart';
import 'features/chat/providers/chat_provider.dart';
import 'features/notifications/providers/notification_preferences.dart';
import 'features/notifications/providers/notifications_provider.dart';
import 'features/orders/providers/orders_provider.dart';
import 'features/products/providers/product_provider.dart';
import 'features/promos/providers/promo_provider.dart';
import 'features/settings/providers/theme_provider.dart';
import 'features/splash/screens/splash_screen.dart';
import 'features/wishlist/providers/wishlist_provider.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final themeProvider = await ThemeProvider.load();
  final notificationPreferences = await NotificationPreferences.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: notificationPreferences),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProxyProvider<AuthProvider, CartProvider>(
          create: (_) => CartProvider(),
          update: (_, auth, cart) => cart!..bindUser(auth.currentUser?.uid),
        ),
        ChangeNotifierProxyProvider<AuthProvider, OrdersProvider>(
          create: (_) => OrdersProvider(),
          update: (_, auth, orders) =>
              orders!..bindUser(auth.currentUser?.uid),
        ),
        ChangeNotifierProxyProvider2<AuthProvider, NotificationPreferences,
            NotificationsProvider>(
          create: (_) => NotificationsProvider(),
          update: (_, auth, preferences, notifications) => notifications!
            ..bindPreferences(preferences)
            ..bindUser(auth.currentUser?.uid),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (_) => ChatProvider(),
          update: (_, auth, chat) => chat!..bindUser(auth.currentUser?.uid),
        ),
        ChangeNotifierProvider(create: (_) => PromoProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
      ],

      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().mode;

    return MaterialApp(
      title: 'PC Parts Store',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}