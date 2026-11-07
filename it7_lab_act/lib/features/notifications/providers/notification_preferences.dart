import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification.dart';

/// Which kinds of notifications the customer wants to see on this phone.
///
/// The choices are saved with SharedPreferences, like the theme: nothing goes
/// to the database. A type that is switched off is only hidden (in the bell,
/// the Notifications list and the pop-up banner); the notification itself is
/// still stored, so switching the type back on brings it back.
///
/// Created once in main.dart. NotificationsProvider listens to it.
class NotificationPreferences extends ChangeNotifier {
  static const _orderKey = 'notif_order_updates';
  static const _priceKey = 'notif_price_changes';
  static const _generalKey = 'notif_promos_system';

  final SharedPreferences? _prefs;
  bool _orders;
  bool _prices;
  bool _general;

  NotificationPreferences._(this._prefs, this._orders, this._prices, this._general);

  /// Reads the saved choices. Everything is on by default, and stays on if
  /// the saved values cannot be read.
  static Future<NotificationPreferences> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return NotificationPreferences._(
        prefs,
        prefs.getBool(_orderKey) ?? true,
        prefs.getBool(_priceKey) ?? true,
        prefs.getBool(_generalKey) ?? true,
      );
    } catch (_) {
      return NotificationPreferences._(null, true, true, true);
    }
  }

  bool get orderUpdates => _orders;
  bool get priceChanges => _prices;
  bool get promosAndSystem => _general;

  /// True when notifications of [kind] should be shown.
  bool allows(NotificationKind kind) {
    switch (kind) {
      case NotificationKind.order:
        return _orders;
      case NotificationKind.price:
        return _prices;
      case NotificationKind.general:
        return _general;
    }
  }

  Future<void> setAllowed(NotificationKind kind, bool value) async {
    if (allows(kind) == value) return;

    final String key;
    switch (kind) {
      case NotificationKind.order:
        _orders = value;
        key = _orderKey;
      case NotificationKind.price:
        _prices = value;
        key = _priceKey;
      case NotificationKind.general:
        _general = value;
        key = _generalKey;
    }
    notifyListeners();

    try {
      await _prefs?.setBool(key, value);
    } catch (e) {
      // The switch still works for this session; it just will not be
      // remembered after the app closes.
      debugPrint('NotificationPreferences: $e');
    }
  }
}
