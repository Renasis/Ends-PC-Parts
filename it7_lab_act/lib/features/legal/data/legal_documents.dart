import '../models/legal_document.dart';

/// The Terms of Service and the Return & Refund Policy.
///
/// NOTE: this is starter text written to match what the app really does
/// (order statuses, payment proofs, the return form, how refunds are sent).
/// Have it reviewed and edit it to match the shop's actual practices. Things
/// the app does not decide, such as a return time limit or warranty terms,
/// are deliberately left out: add them here once the shop has chosen them.
abstract final class LegalDocuments {
  static const terms = LegalDocument(
    title: 'Terms of Service',
    intro: 'These terms explain how ordering from PC Parts Store works. '
        'By creating an account or placing an order you agree to them.',
    sections: [
      (
        'Your account',
        'You need an account to order. Give accurate details, keep your '
            'password to yourself, and tell us if you think someone else is '
            'using your account. You are responsible for what happens under '
            'your login. You can delete your account at any time in '
            'Settings.',
      ),
      (
        'Products and prices',
        'Prices are in Philippine pesos. We do our best to keep product '
            'details, photos, specs and stock up to date, but mistakes can '
            'happen. If a price or detail was wrong, we may cancel the '
            'affected order and refund anything you paid.',
      ),
      (
        'Placing an order',
        'Before you can order, your profile needs your full name, a valid '
            'mobile number and a complete delivery address with ZIP code. '
            'Placing an order is a request to buy. It is accepted when the '
            'store starts processing it. We may cancel an order, for example '
            'when an item is out of stock or a payment cannot be verified, '
            'and we will refund any payment already received for it.',
      ),
      (
        'Payment',
        'You can pay by cash on delivery or by any online method shown at '
            'checkout, such as GCash, Maya or bank transfer. For an online '
            'payment you send the money, then upload a proof of payment. The '
            'store checks the proof before it processes the order. If the '
            'proof is refused you will see the reason. Fake or altered '
            'proofs may lead to the order being cancelled and the account '
            'being suspended. Vouchers follow the conditions shown with them '
            'and have no cash value.',
      ),
      (
        'Shipping and delivery',
        'The delivery fee depends on your province and is shown at checkout '
            'before you pay. Free shipping may apply when your order reaches '
            'the minimum amount the store sets. The estimated delivery date '
            'is an estimate, not a guarantee. A wrong address or an '
            'unreachable mobile number can delay delivery. When your order '
            'arrives, tap "Order received". If you do not, the app may mark '
            'the order as completed a few days after the estimated delivery '
            'date.',
      ),
      (
        'Cancelling an order',
        'You can cancel an order yourself while it is Pending or its payment '
            'was rejected. Once the store has started processing it, ask us '
            'through Support Chat. If you cancel an order you already paid '
            'for, contact us in Support Chat about your payment.',
      ),
      (
        'Returns and refunds',
        'Returns and refunds are covered by our Return & Refund Policy, '
            'which is part of these terms.',
      ),
      (
        'Reviews and messages',
        'Reviews and support chat messages must be honest and respectful. '
            'We may remove content that is abusive, misleading or unrelated '
            'to the product.',
      ),
      (
        'Suspending an account',
        'We may suspend or close an account that is used for fraud, abuse or '
            'to break these terms.',
      ),
      (
        'Limits of our responsibility',
        'As far as the law allows, we are not responsible for indirect '
            'losses, or for delays caused by couriers, payment providers or '
            'events outside our control. Nothing in these terms limits your '
            'rights under consumer protection laws that apply to you.',
      ),
      (
        'Changes and contact',
        'We may update these terms. Continuing to use the app means you '
            'accept the updated terms. Questions? Send us a message in '
            'Support Chat.',
      ),
    ],
  );

  static const returnPolicy = LegalDocument(
    title: 'Return & Refund Policy',
    intro: 'Read this before you request a return. It describes how returns '
        'and refunds work in the app.',
    sections: [
      (
        'Who can request a return',
        'You can request a return for an order once it is Completed. One '
            'request can be made per order, and it covers the whole order. '
            'Please request it as soon as you notice a problem, and keep '
            'the item and its packaging until your request is decided.',
      ),
      (
        'Reasons',
        'When you request a return you choose a reason: item arrived '
            'damaged, item is defective or not working, wrong item received, '
            'item not as described, missing parts or accessories, changed '
            'my mind, or other (tell us what happened). Being able to send '
            'a request does not mean it will be approved: the store reviews '
            'every request.',
      ),
      (
        'How to request one',
        'Open the Orders tab, find the Completed order and tap "Request '
            'Return". Pick a reason and, if you can, add a photo of the '
            'problem, since it helps us decide faster. Then tell us where to '
            'send your refund.',
      ),
      (
        'Review',
        'While we look at your request, the order shows "Return under '
            'review". We may ask you to send the item back so we can check '
            'it, and we may leave you a note in the order. You will get a '
            'notification when the request is approved or declined.',
      ),
      (
        'If your return is approved',
        'The store sets the refund amount when it approves the return. The '
            'order then shows that your refund is on its way.',
      ),
      (
        'If your return is declined',
        'The order shows our note explaining why. A declined request cannot '
            'be sent again from the app. If you disagree, talk to us in '
            'Support Chat.',
      ),
      (
        'How refunds are sent',
        'We send refunds by hand, to the account you entered in the return '
            'form: GCash, Maya or a bank account. If you paid by cash on '
            'delivery, the refund also goes to an e-wallet or bank account, '
            'because there is no card or online payment to reverse. Please '
            'double-check the account number before you submit. When the '
            'money is sent, the order shows "Refund sent" with a reference '
            'number, and you get a notification.',
      ),
      (
        'Cancelled orders',
        'Orders that were cancelled before they were processed are not '
            'returns. If you already paid for a cancelled order, contact us '
            'in Support Chat about your payment.',
      ),
      (
        'Questions',
        'Not sure whether something can be returned? Ask us in Support Chat '
            'before you submit a request.',
      ),
    ],
  );
}
