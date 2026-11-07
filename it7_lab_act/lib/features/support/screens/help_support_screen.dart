import 'package:flutter/material.dart';

import '../../../core/widgets/surface_card.dart';
import '../../chat/screens/chat_screen.dart';
import '../../legal/data/legal_documents.dart';
import '../../legal/widgets/legal_document_sheet.dart';

/// Short answers to the questions customers ask most, and a button that opens
/// Support Chat for everything else.
///
/// Open it from the Account tab, which only shows for logged-in customers
/// (Support Chat needs an account).
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _shipping = <(String, String)>[
    (
      'How much is shipping?',
      'The delivery fee depends on your province and is shown at checkout '
          'before you pay. The store may offer free shipping once your '
          'order reaches a minimum amount, and checkout tells you how much '
          'more to add.',
    ),
    (
      'How do I track my order?',
      'Open the Orders tab and tap "View details" on your order. Once it '
          'ships you will see the estimated delivery date and, when the '
          'store adds one, a tracking number. You also get a notification '
          'each time the status changes.',
    ),
    (
      'My order arrived. What now?',
      'Tap "Order received" on the order. If you do not, the app may mark '
          'it as completed for you a few days after the estimated delivery '
          'date.',
    ),
  ];

  static const _payment = <(String, String)>[
    (
      'Which payment methods can I use?',
      'Cash on delivery, plus the online methods the store has set up, '
          'such as GCash, Maya or bank transfer. You can see the available '
          'methods at checkout.',
    ),
    (
      'How do online payments work?',
      'Choose the method at checkout, send the payment using the account '
          'or QR code shown, then upload a screenshot of your payment as '
          'proof. The store checks it before processing your order. If the '
          'proof is rejected, the order shows the reason and you can cancel '
          'it and order again.',
    ),
    (
      'Can I cancel an order?',
      'Yes, while the order is Pending or its payment was rejected: tap '
          '"Cancel order" on the Orders tab. Once the store has started '
          'processing it, ask us in Support Chat.',
    ),
  ];

  static const _returns = <(String, String)>[
    (
      'How do I return something?',
      'When an order is Completed, open it in the Orders tab and tap '
          '"Request Return". Choose a reason, add a photo if you can, and '
          'enter the account where we should send your refund.',
    ),
    (
      'How long does a refund take?',
      'The store reviews every request and sends refunds by hand, so we '
          'cannot promise an exact time. Your order shows where things '
          'stand: "Return under review", then "refund on its way", then '
          '"Refund sent" with a reference number. You get a notification at '
          'each step.',
    ),
    (
      'Where is my refund sent?',
      'To the GCash, Maya or bank account you entered in the return form. '
          'If you paid by cash on delivery, the refund also goes to an '
          'e-wallet or bank account.',
    ),
  ];

  static const _account = <(String, String)>[
    (
      'Why can\'t I check out?',
      'Your profile needs your full name, a valid mobile number and a '
          'complete delivery address with ZIP code. Add them in the Account '
          'tab under shipping information.',
    ),
    (
      'How do I change my password or delete my account?',
      'Go to Account > Settings. You will find Change Password under '
          'Security and Delete my account at the bottom.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionLabel('Shipping & delivery'),
          _FaqCard(items: _shipping),
          const SizedBox(height: 24),
          const _SectionLabel('Payment & orders'),
          _FaqCard(items: _payment),
          const SizedBox(height: 24),
          const _SectionLabel('Returns & refunds'),
          _FaqCard(items: _returns),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => LegalDocumentSheet.show(
                context,
                LegalDocuments.returnPolicy,
              ),
              icon: const Icon(Icons.assignment_return_outlined, size: 18),
              label: const Text('Read the full Return & Refund Policy'),
            ),
          ),
          const SizedBox(height: 12),
          const _SectionLabel('Account'),
          _FaqCard(items: _account),
          const SizedBox(height: 24),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.support_agent,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Still need help?',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Send us a message and the store will reply in the chat.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatScreen()),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Chat with us'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  final List<(String, String)> items;

  const _FaqCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SurfaceCard(
      padding: EdgeInsets.zero,
      // ExpansionTile draws its own divider lines; the card already has a
      // border, so hide them.
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
              ExpansionTile(
                title: Text(
                  items[i].$1,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Text(
                    items[i].$2,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
