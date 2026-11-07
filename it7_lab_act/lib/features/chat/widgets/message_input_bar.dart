import 'package:flutter/material.dart';

/// The text box and Send button at the bottom of the chat.
///
/// [onSend] returns null on success or a message to show; on failure the text
/// is put back so the customer can send it again.
class MessageInputBar extends StatefulWidget {
  final Future<String?> Function(String text) onSend;

  const MessageInputBar({super.key, required this.onSend});

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  static const _maxLength = 1000;

  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    final error = await widget.onSend(text);
    if (error == null || !mounted) return;

    if (_controller.text.isEmpty) _controller.text = text;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 4,
      color: Theme.of(context).cardColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLength: _maxLength,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Type your message...',
                    counterText: '',
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(24)),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) => IconButton(
                  tooltip: 'Send',
                  onPressed: value.text.trim().isEmpty ? null : _send,
                  icon: const Icon(Icons.send),
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
