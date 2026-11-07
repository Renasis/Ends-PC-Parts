import '../../../core/utils/map_parsing.dart';

/// One message at `chats/{uid}/messages/{id}`.
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String message;
  final int timestamp;
  final bool isAdmin;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.message,
    required this.timestamp,
    required this.isAdmin,
  });

  factory ChatMessage.fromMap(String id, Map<dynamic, dynamic> map) {
    return ChatMessage(
      id: id,
      senderId: readText(map['senderId']),
      senderName: readText(map['senderName'], fallback: 'User'),
      message: readText(map['message']),
      timestamp: readInt(map['timestamp']),
      isAdmin: map['isAdmin'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'timestamp': timestamp,
      'isAdmin': isAdmin,
    };
  }
}
