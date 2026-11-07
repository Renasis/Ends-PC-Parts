import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WishlistProvider with ChangeNotifier {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Store wishlist as a Set for O(1) fast lookups
  Set<String> _wishlistIds = {};
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DatabaseEvent>? _wishlistSub;

  Set<String> get wishlistIds => _wishlistIds;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  WishlistProvider() {
    // Fires right away with the current user, and again on every login/logout,
    // so the wishlist always matches whoever is signed in.
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  void _onAuthChanged(User? user) {
    _wishlistSub?.cancel();
    _wishlistSub = null;
    _wishlistIds = {};

    if (user == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _wishlistSub = _dbRef
        .child('users')
        .child(user.uid)
        .child('wishlist')
        .onValue
        .listen((event) {
      final value = event.snapshot.value;
      if (value is Map) {
        _wishlistIds = value.keys.map((k) => k.toString()).toSet();
      } else {
        _wishlistIds = {};
      }
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    }, onError: (Object e) {
      _errorMessage = 'Could not load your wishlist. Please check your connection.';
      _isLoading = false;
      notifyListeners();
    });
  }

  bool isFavorite(String productId) {
    return _wishlistIds.contains(productId);
  }

  Future<void> toggleFavorite(String productId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // Must be logged in

    _errorMessage = null; // clear any prior error on new attempt

    final wishlistRef =
        _dbRef.child('users').child(user.uid).child('wishlist').child(productId);

    final wasFavorite = _wishlistIds.contains(productId);
    final previousState = Set<String>.from(_wishlistIds);

    if (wasFavorite) {
      // Remove from wishlist
      _wishlistIds.remove(productId);
    } else {
      // Add to wishlist
      _wishlistIds.add(productId);
    }
    notifyListeners(); // Optimistic update

    try {
      if (wasFavorite) {
        await wishlistRef.remove();
      } else {
        await wishlistRef.set(true);
      }
    } catch (e) {
      _wishlistIds = previousState; // ROLLBACK
      _errorMessage = 'Could not update your wishlist. Please try again.';
      notifyListeners();
    }
  }

  /// Kept for compatibility - the auth listener now clears this automatically on logout.
  void clearWishlistState() {
    _wishlistIds.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _wishlistSub?.cancel();
    super.dispose();
  }
}