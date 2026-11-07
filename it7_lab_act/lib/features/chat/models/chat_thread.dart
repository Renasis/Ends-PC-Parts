import '../../../core/utils/map_parsing.dart';

/// The summary of one customer's chat at `chatThreads/{uid}`.
///
/// Fields: customerName, lastMessage, lastTimestamp (ms), lastFromAdmin,
/// customerReadAt and adminReadAt (ms). Unread is worked out by comparing the
/// last message time with the time each side last opened the chat, so no
/// counters need to be kept in step.
class ChatThread {
  final String customerName;
  final String lastMessage;
  final int lastTimestamp;
  final bool lastFromAdmin;
  final int customerReadAt;

  const ChatThread({
    required this.customerName,
    required this.lastMessage,
    required this.lastTimestamp,
    required this.lastFromAdmin,
    required this.customerReadAt,
  });

  factory ChatThread.fromMap(Map<dynamic, dynamic> map) {
    return ChatThread(
      customerName: readText(map['customerName']),
      lastMessage: readText(map['lastMessage']),
      lastTimestamp: readInt(map['lastTimestamp']),
      lastFromAdmin: map['lastFromAdmin'] == true,
      customerReadAt: readInt(map['customerReadAt']),
    );
  }

  /// True when support replied after the customer last opened the chat.
  bool get hasUnreadForCustomer =>
      lastFromAdmin && lastTimestamp > customerReadAt;
}
