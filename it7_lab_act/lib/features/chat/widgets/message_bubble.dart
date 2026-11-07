import 'package:flutter/material.dart';

import '../../../core/utils/time_ago.dart';
import '../models/chat_message.dart';

/// One chat bubble: the customer's on the right, support's on the left.
class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMine = !message.isAdmin;
    final textColor = isMine ? scheme.onPrimary : scheme.onSurface;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMine ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine) ...[
              Text(
                'Support Team',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              message.message,
              style: TextStyle(color: textColor, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              _timeLabel(context),
              style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "3:05 PM" for today, "2 d ago · 3:05 PM" for older messages.
  String _timeLabel(BuildContext context) {
    if (message.timestamp <= 0) return '';

    final sent = DateTime.fromMillisecondsSinceEpoch(message.timestamp);
    final clock = TimeOfDay.fromDateTime(sent).format(context);
    final now = DateTime.now();
    final isToday =
        sent.year == now.year && sent.month == now.month && sent.day == now.day;
    return isToday ? clock : '${timeAgo(message.timestamp)} · $clock';
  }
}
