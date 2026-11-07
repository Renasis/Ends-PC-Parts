import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/error_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_empty_state.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_bar.dart';

/// The customer's conversation with the store's support team.
///
/// Open it from the Account tab, which only shows for logged-in customers.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Kept so dispose can use it without looking up the context.
  late final ChatProvider _chat;

  @override
  void initState() {
    super.initState();
    _chat = context.read<ChatProvider>()..open();
  }

  @override
  void dispose() {
    _chat.close();
    super.dispose();
  }

  Future<String?> _send(String text) {
    final auth = context.read<AuthProvider>();
    final emailName = auth.currentUser?.email?.split('@').first ?? '';
    final name = auth.recipientName.isNotEmpty
        ? auth.recipientName
        : (emailName.isNotEmpty ? emailName : 'Customer');
    return _chat.send(text, name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support Chat')),
      body: Column(
        children: [
          const Expanded(child: _MessageList()),
          MessageInputBar(onSend: _send),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList();

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();

    if (chat.errorMessage.isNotEmpty) {
      return ErrorState(message: chat.errorMessage, onRetry: chat.retry);
    }
    if (chat.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final messages = chat.messages;
    if (messages.isEmpty) return const ChatEmptyState();

    // Reversed so the newest message sits at the bottom and the list stays
    // there as new messages arrive.
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) => MessageBubble(
        key: ValueKey(messages[messages.length - 1 - index].id),
        message: messages[messages.length - 1 - index],
      ),
    );
  }
}
