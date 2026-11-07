import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import 'notification_preferences.dart';

/// The signed-in customer's in-app notifications, kept live from
/// `notifications/{uid}`.
///
/// Created once in main.dart and re-pointed at the current user with
/// [bindUser], like OrdersProvider. The admin dashboard writes the entries
/// (order status changes, price changes); nothing here needs cloud messaging.
class NotificationsProvider extends ChangeNotifier {
  static const _loadError =
      'Could not load your notifications. Please check your connection and try again.';
  static const _writeError = 'Something went wrong. Please try again.';

  final DatabaseReference _root =
      FirebaseDatabase.instance.ref().child('notifications');
  final StreamController<AppNotification> _incoming =
      StreamController<AppNotification>.broadcast();

  StreamSubscription<DatabaseEvent>? _sub;
  String? _userId;
  List<AppNotification> _items = const [];
  /// [_items] without the types the customer switched off. What the screens
  /// show, so a hidden type is also left out of the unread count.
  List<AppNotification> _visible = const [];
  NotificationPreferences? _preferences;
  Set<String> _seenIds = {};
  bool _hasLoaded = false;
  bool _isLoading = false;
  String _errorMessage = '';
  bool _disposed = false;

  List<AppNotification> get items => _visible;
  bool get isLoading => _isLoading;

  /// Non-empty when the notifications could not be loaded.
  String get errorMessage => _errorMessage;

  int get unreadCount => _visible.where((item) => !item.isRead).length;

  /// Emits each notification that arrives while the app is open (not the ones
  /// that were already waiting when the user logged in).
  Stream<AppNotification> get incoming => _incoming.stream;

  /// Follows the customer's notification choices. Safe to call on every
  /// rebuild: the same object is a no-op.
  void bindPreferences(NotificationPreferences preferences) {
    if (identical(preferences, _preferences)) return;
    _preferences?.removeListener(_onPreferencesChanged);
    _preferences = preferences..addListener(_onPreferencesChanged);
    _refreshVisible();
  }

  void _onPreferencesChanged() {
    _refreshVisible();
    notifyListeners();
  }

  void _refreshVisible() {
    final preferences = _preferences;
    _visible = preferences == null
        ? _items
        : _items.where((item) => preferences.allows(item.kind)).toList();
  }

  /// Starts listening for [userId]'s notifications, or clears everything when
  /// null. Safe to call on every auth change: the same user is a no-op.
  void bindUser(String? userId) {
    if (userId == _userId) return;

    _sub?.cancel();
    _sub = null;
    _userId = userId;
    _items = const [];
    _refreshVisible();
    _seenIds = {};
    _hasLoaded = false;
    _errorMessage = '';
    _isLoading = userId != null;

    if (userId != null) _listen(userId);

    // Called while the widget tree is building, so notify after the frame.
    scheduleMicrotask(notifyListeners);
  }

  /// Restarts the listener after a failed load.
  void retry() {
    final userId = _userId;
    _userId = null;
    bindUser(userId);
  }

  void _listen(String userId) {
    _sub = _root.child(userId).onValue.listen((event) {
      final raw = event.snapshot.value;
      final loaded = <AppNotification>[];
      if (raw is Map) {
        raw.forEach((key, value) {
          if (value is Map) {
            loaded.add(AppNotification.fromMap(key.toString(), value));
          }
        });
      }
      loaded.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final fresh = _hasLoaded
          ? loaded
              .where((item) =>
                  !item.isRead &&
                  !_seenIds.contains(item.id) &&
                  (_preferences?.allows(item.kind) ?? true))
              .toList()
          : <AppNotification>[];

      _seenIds = loaded.map((item) => item.id).toSet();
      _hasLoaded = true;
      _items = loaded;
      _refreshVisible();
      _errorMessage = '';
      _isLoading = false;
      notifyListeners();

      for (final item in fresh.reversed) {
        if (!_incoming.isClosed) _incoming.add(item);
      }
    }, onError: (Object _) {
      _errorMessage = _loadError;
      _isLoading = false;
      notifyListeners();
    });
  }

  /// Each action returns null on success, otherwise a message to show.
  Future<String?> markRead(AppNotification notification) async {
    final userId = _userId;
    if (userId == null || notification.isRead) return null;
    return _write(
      () => _root.child(userId).child(notification.id).update({'read': true}),
    );
  }

  Future<String?> markAllRead() async {
    final userId = _userId;
    if (userId == null) return null;

    final updates = <String, Object?>{
      for (final item in _visible)
        if (!item.isRead) '${item.id}/read': true,
    };
    if (updates.isEmpty) return null;
    return _write(() => _root.child(userId).update(updates));
  }

  Future<String?> delete(AppNotification notification) async {
    final userId = _userId;
    if (userId == null) return null;

    // Remove it from the list right away so a swipe feels instant; the
    // listener puts it back if the database refuses.
    _items = _items.where((item) => item.id != notification.id).toList();
    _refreshVisible();
    notifyListeners();

    return _write(() => _root.child(userId).child(notification.id).remove());
  }

  Future<String?> _write(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } on FirebaseException catch (e) {
      return e.code == 'permission-denied'
          ? 'You are not allowed to do that.'
          : _writeError;
    } catch (_) {
      return _writeError;
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _preferences?.removeListener(_onPreferencesChanged);
    _sub?.cancel();
    _incoming.close();
    super.dispose();
  }
}
