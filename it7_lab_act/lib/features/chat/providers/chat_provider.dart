import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/chat_thread.dart';

/// The signed-in customer's support chat.
///
/// Created once in main.dart and re-pointed at the current user with
/// [bindUser], like OrdersProvider. The small summary at `chatThreads/{uid}`
/// is always listened to (it drives the unread badge); the messages at
/// `chats/{uid}/messages` are only listened to while the chat screen is open
/// ([open] / [close]).
class ChatProvider extends ChangeNotifier {
  static const _loadError =
      'Could not load the chat. Please check your connection and try again.';
  static const _sendError = 'Message not sent. Please try again.';
  static const _historyLimit = 100;
  static const _previewLength = 200;

  final DatabaseReference _root = FirebaseDatabase.instance.ref();

  StreamSubscription<DatabaseEvent>? _threadSub;
  StreamSubscription<DatabaseEvent>? _messagesSub;
  String? _userId;
  ChatThread? _thread;
  List<ChatMessage> _messages = const [];
  bool _isOpen = false;
  bool _isLoading = false;
  String _errorMessage = '';
  bool _markingRead = false;
  bool _disposed = false;

  /// Oldest first.
  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;

  /// Non-empty when the messages could not be loaded.
  String get errorMessage => _errorMessage;

  /// True when support has replied since the customer last opened the chat.
  bool get hasUnread => _thread?.hasUnreadForCustomer ?? false;

  /// Starts listening for [userId]'s chat summary, or clears everything when
  /// null. Safe to call on every auth change: the same user is a no-op.
  void bindUser(String? userId) {
    if (userId == _userId) return;

    _threadSub?.cancel();
    _messagesSub?.cancel();
    _threadSub = null;
    _messagesSub = null;
    _userId = userId;
    _thread = null;
    _messages = const [];
    _isOpen = false;
    _isLoading = false;
    _errorMessage = '';

    if (userId != null) _listenThread(userId);

    // Called while the widget tree is building, so notify after the frame.
    scheduleMicrotask(notifyListeners);
  }

  /// Call from the chat screen's initState, before its first build.
  void open() {
    final userId = _userId;
    _isOpen = true;
    _messagesSub?.cancel();
    _messages = const [];
    _errorMessage = '';
    _isLoading = userId != null;
    if (userId != null) _listenMessages(userId);
  }

  /// Call from the chat screen's dispose.
  void close() {
    _isOpen = false;
    _messagesSub?.cancel();
    _messagesSub = null;
    _messages = const [];
    _isLoading = false;
  }

  /// Restarts the message listener after a failed load.
  void retry() {
    if (!_isOpen) return;
    open();
    notifyListeners();
  }

  void _listenThread(String userId) {
    _threadSub = _root.child('chatThreads').child(userId).onValue.listen(
      (event) {
        final raw = event.snapshot.value;
        _thread = raw is Map ? ChatThread.fromMap(raw) : null;
        notifyListeners();
        _markReadIfNeeded();
      },
      // Only the badge depends on this; if it fails the badge stays hidden
      // and the chat screen reports its own load error.
      onError: (Object _) {},
    );
  }

  void _listenMessages(String userId) {
    _messagesSub = _root
        .child('chats')
        .child(userId)
        .child('messages')
        .limitToLast(_historyLimit)
        .onValue
        .listen((event) {
      final raw = event.snapshot.value;
      final loaded = <ChatMessage>[];
      if (raw is Map) {
        raw.forEach((key, value) {
          if (value is Map) {
            loaded.add(ChatMessage.fromMap(key.toString(), value));
          }
        });
      }
      loaded.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      _messages = loaded;
      _errorMessage = '';
      _isLoading = false;
      notifyListeners();
      _markReadIfNeeded();
    }, onError: (Object _) {
      _errorMessage = _loadError;
      _isLoading = false;
      notifyListeners();
    });
  }

  /// While the chat is open, a reply from support counts as seen.
  Future<void> _markReadIfNeeded() async {
    final userId = _userId;
    final thread = _thread;
    if (!_isOpen ||
        userId == null ||
        thread == null ||
        !thread.hasUnreadForCustomer ||
        _markingRead) {
      return;
    }

    _markingRead = true;
    try {
      await _root
          .child('chatThreads')
          .child(userId)
          .child('customerReadAt')
          .set(ServerValue.timestamp);
    } catch (_) {
      // Not worth interrupting the customer; the badge clears next time.
    } finally {
      _markingRead = false;
    }
  }

  /// Sends [text] to support. Returns null on success, otherwise a message
  /// to show. The message and the thread summary are written together so they
  /// can never disagree.
  Future<String?> send(String text, String senderName) async {
    final userId = _userId;
    final body = text.trim();
    if (userId == null || body.isEmpty) return null;

    final key =
        _root.child('chats').child(userId).child('messages').push().key;
    if (key == null) return _sendError;

    final message = ChatMessage(
      id: key,
      senderId: userId,
      senderName: senderName,
      message: body,
      timestamp: 0,
      isAdmin: false,
    );
    final preview = body.length > _previewLength
        ? body.substring(0, _previewLength)
        : body;

    try {
      await _root.update({
        'chats/$userId/messages/$key': {
          ...message.toMap(),
          'timestamp': ServerValue.timestamp,
        },
        'chatThreads/$userId/customerName': senderName,
        'chatThreads/$userId/lastMessage': preview,
        'chatThreads/$userId/lastTimestamp': ServerValue.timestamp,
        'chatThreads/$userId/lastFromAdmin': false,
        'chatThreads/$userId/customerReadAt': ServerValue.timestamp,
      });
      return null;
    } on FirebaseException catch (e) {
      return e.code == 'permission-denied'
          ? 'You are not allowed to do that.'
          : _sendError;
    } catch (_) {
      return _sendError;
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _threadSub?.cancel();
    _messagesSub?.cancel();
    super.dispose();
  }
}
