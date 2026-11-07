import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_database/firebase_database.dart';

import '../../address/models/shipping_address.dart';
import '../../address/utils/address_validators.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  late final StreamSubscription<User?> _authSub;

  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => _auth.currentUser != null;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Last user-facing error from login / sign up / profile actions.
  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  String _recipientName = '';
  String _phoneNumber = '';
  ShippingAddress _address = ShippingAddress.empty;

  /// Milliseconds since epoch when the Privacy Policy was accepted; 0 when
  /// the customer has not accepted it yet (accounts made before it existed).
  int _privacyAcceptedAt = 0;

  String get recipientName => _recipientName;
  String get phoneNumber => _phoneNumber;

  /// The saved delivery address, split into parts with an optional map pin.
  ShippingAddress get savedAddress => _address;

  /// The saved address as one line.
  String get deliveryAddress => _address.formatted;

  bool _profileLoaded = false;
  bool _profileLoadFailed = false;

  /// True once the saved profile has been read from the database. Until then
  /// [isProfileComplete] cannot be trusted, so checkout waits for it.
  bool get isProfileLoaded => _profileLoaded;

  /// True when the last attempt to read the profile failed.
  bool get profileLoadFailed => _profileLoadFailed;

  /// What is still missing before the customer may place an order. Empty when
  /// the profile is complete. Matches the rules in the database, which refuse
  /// orders from incomplete profiles.
  List<String> get missingProfileItems => [
        if (_recipientName.trim().isEmpty) 'Full name',
        if (!AddressValidators.isValidPhone(_phoneNumber)) 'Mobile number',
        if (_address.street.isEmpty ||
            _address.barangay.isEmpty ||
            _address.city.isEmpty ||
            _address.province.isEmpty)
          'Complete delivery address',
        if (!RegExp(r'^\d{4}$').hasMatch(_address.zipCode)) 'ZIP code',
      ];

  /// True when a signed-in customer still has to accept the Privacy Policy.
  /// Never true while a sign-up or save is running, because the acceptance is
  /// written as part of it.
  bool get needsPrivacyAcceptance =>
      currentUser != null &&
      _profileLoaded &&
      !_profileLoadFailed &&
      !_isLoading &&
      _privacyAcceptedAt == 0;

  /// A customer must have a name, a valid mobile number and a full delivery
  /// address (with ZIP code) saved before they can order.
  bool get isProfileComplete => missingProfileItems.isEmpty;

  AuthProvider() {
    _authSub = _auth.authStateChanges().listen((user) {
      if (user != null) {
        fetchUserProfile();
      } else {
        _clearProfile();
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  Future<void>? _profileFetch;

  /// Loads the saved profile. A call made while a load is already running
  /// shares it (logging in triggers both the auth listener and login()).
  /// Pass [force] to load again, for example right after the profile was
  /// first saved during sign up.
  Future<void> fetchUserProfile({bool force = false}) async {
    final running = _profileFetch;
    if (running != null) {
      await running;
      if (!force) return;
    }
    final load = _loadProfile();
    _profileFetch = load;
    try {
      await load;
    } finally {
      if (identical(_profileFetch, load)) _profileFetch = null;
    }
  }

  Future<void> _loadProfile() async {
    final user = currentUser;
    if (user == null) return;
    _profileLoadFailed = false;
    try {
      final snapshot = await _dbRef.child('users').child(user.uid).get();
      if (currentUser?.uid != user.uid) return; // logged out or switched
      _profileLoaded = true;
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        _recipientName = (data['name'] ?? '').toString();
        _phoneNumber = (data['phoneNumber'] ?? '').toString();
        final accepted = data['privacyAcceptedAt'];
        _privacyAcceptedAt = accepted is num ? accepted.toInt() : 0;
        final rawAddress = data['address'];
        _address = ShippingAddress.fromProfile(
          rawAddress is Map ? rawAddress : null,
          (data['deliveryAddress'] ?? '').toString(),
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('AuthProvider: $e');
      _profileLoadFailed = true;
      _errorMessage = 'Could not load your profile. Please check your connection.';
      notifyListeners();
    }
  }

  Future<bool> updateShippingProfile({
    required String name,
    required String phone,
    required ShippingAddress address,
  }) async {
    final user = currentUser;
    if (user == null) return false;
    _errorMessage = '';
    _setLoading(true);
    try {
      await _dbRef.child('users').child(user.uid).update({
        'name': name.trim(),
        'phoneNumber': phone.trim(),
        // One-line copy keeps the admin dashboard and old orders working.
        'deliveryAddress': address.formatted,
        'address': address.toMap(),
      });

      _recipientName = name.trim();
      _phoneNumber = phone.trim();
      _address = address;
      _profileLoaded = true;
      return true;
    } catch (e) {
      debugPrint('AuthProvider: $e');
      _errorMessage = 'Could not save your details. Please try again.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Saves that the signed-in customer accepted the Privacy Policy.
  Future<bool> acceptPrivacy() async {
    final user = currentUser;
    if (user == null) return false;
    try {
      await _dbRef
          .child('users')
          .child(user.uid)
          .update({'privacyAcceptedAt': ServerValue.timestamp});
      _privacyAcceptedAt = DateTime.now().millisecondsSinceEpoch;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('AuthProvider: $e');
      _errorMessage = 'Could not save your choice. Please try again.';
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _errorMessage = '';
    _setLoading(true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await fetchUserProfile();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _authMessage(e);
      return false;
    } catch (e) {
      debugPrint('AuthProvider: $e');
      _errorMessage = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUp(String name, String email, String password) async {
    _errorMessage = '';
    _setLoading(true);
    User? created;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      created = cred.user;

      await _dbRef.child('users').child(cred.user!.uid).set({
        'name': name.trim(),
        'email': email.trim(),
        'createdAt': ServerValue.timestamp,
        // The sign-up form only submits after the Privacy Policy is accepted.
        'privacyAcceptedAt': ServerValue.timestamp,
      });

      await fetchUserProfile(force: true);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _authMessage(e);
      return false;
    } catch (e) {
      debugPrint('AuthProvider: $e');
      _errorMessage = await _undoSignUp(created);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Checks the current password again, then sets the new one. Returns false
  /// and sets [errorMessage] when it fails.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      _errorMessage = 'Please log in again to change your password.';
      return false;
    }

    _errorMessage = '';
    _setLoading(true);
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: currentPassword),
      );
      await user.updatePassword(newPassword);
      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          _errorMessage = 'Your current password is incorrect.';
        case 'requires-recent-login':
          _errorMessage = 'Please sign out, sign back in, then try again.';
        default:
          _errorMessage = _authMessage(e);
      }
      return false;
    } catch (e) {
      debugPrint('AuthProvider: $e');
      _errorMessage = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Emails a password reset link. Returns null on success, otherwise a
  /// message to show. An unknown email also counts as success, so the screen
  /// never reveals which emails have an account.
  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return e.code == 'user-not-found' ? null : _authMessage(e);
    } catch (e) {
      debugPrint('AuthProvider: $e');
      return 'Something went wrong. Please try again.';
    }
  }

  /// Emails a link that verifies the signed-in customer's address. Returns
  /// null on success, otherwise a message to show.
  Future<String?> sendVerificationEmail() async {
    final user = currentUser;
    if (user == null) return 'Please log in again.';
    try {
      await user.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      return _authMessage(e);
    } catch (e) {
      debugPrint('AuthProvider: $e');
      return 'Something went wrong. Please try again.';
    }
  }

  /// Reloads the account so a verification done in the browser shows up.
  /// Returns true when the email is now verified.
  Future<bool> refreshVerification() async {
    try {
      await currentUser?.reload();
    } catch (e) {
      debugPrint('AuthProvider: $e');
    }
    notifyListeners();
    return currentUser?.emailVerified ?? false;
  }

  /// Permanently deletes the signed-in customer's account.
  ///
  /// In order: check the password again (Firebase wants a recent sign-in for
  /// this), remove `users/{uid}` (the profile, saved address, cart and
  /// wishlist all live there), then delete the sign-in account. Past orders,
  /// payment proofs and chat messages are not touched: the store keeps them
  /// for its records.
  ///
  /// The profile has to go first, because once the sign-in account is gone
  /// the database no longer accepts writes from it. If the last step fails
  /// the account can simply be deleted again: removing an already removed
  /// profile is harmless.
  ///
  /// Returns null on success, otherwise a message to show.
  Future<String?> deleteAccount(String password) async {
    final user = currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      return 'Please log in again to delete your account.';
    }

    // While this runs the Privacy Policy prompt must not appear for the
    // half-deleted account, and isLoading tells the screens to wait.
    _setLoading(true);
    var profileRemoved = false;
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      await _dbRef.child('users').child(user.uid).remove();
      profileRemoved = true;
      await user.delete();
      _clearProfile();
      return null;
    } on FirebaseAuthException catch (e) {
      final message = switch (e.code) {
        'wrong-password' ||
        'invalid-credential' =>
          'That password is incorrect.',
        'requires-recent-login' =>
          'For your security, please sign out, sign back in, then try again.',
        _ => _authMessage(e),
      };
      return profileRemoved
          ? '$message Your saved profile was already removed. Try again to '
              'finish deleting the account.'
          : message;
    } catch (e) {
      debugPrint('AuthProvider: $e');
      return profileRemoved
          ? 'Your saved profile was removed, but the account could not be '
              'deleted yet. Please try again.'
          : 'Could not delete your account. Please check your connection '
              'and try again.';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    _clearProfile();
    notifyListeners();
  }

  /// The account exists but saving the profile failed: remove the account so
  /// the person can simply try again.
  Future<String> _undoSignUp(User? user) async {
    try {
      await user?.delete();
      return 'Could not save your profile. Please check your connection and try again.';
    } catch (e) {
      debugPrint('AuthProvider: $e');
      return 'Your account was created but your profile could not be saved. Please log in.';
    }
  }

  String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email sign-in is not enabled for this app.';
      default:
        return 'Something went wrong (${e.code}). Please try again.';
    }
  }

  void _clearProfile() {
    _profileLoaded = false;
    _profileLoadFailed = false;
    _recipientName = '';
    _phoneNumber = '';
    _address = ShippingAddress.empty;
    _privacyAcceptedAt = 0;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}