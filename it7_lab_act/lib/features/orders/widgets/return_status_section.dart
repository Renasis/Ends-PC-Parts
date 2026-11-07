import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/order.dart';

/// Shows the customer where their return request stands: waiting for review,
/// declined, approved with the refund on its way, or refunded.
class ReturnStatusSection extends StatelessWidget {
  final Order order;
  const ReturnStatusSection({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    if (order.returnedAt == 0 && order.returnReason.isEmpty) {
      return const SizedBox.shrink();
    }

    final (color, icon, title) = _headline();
    final destination = _destination();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (order.returnedAt > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Requested on ${_formatDate(order.returnedAt)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          if (order.returnReason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Your reason: ${order.returnReason}',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
          if (order.returnImageUrl.startsWith('data:image')) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                base64Decode(
                  order.returnImageUrl
                      .substring(order.returnImageUrl.indexOf(',') + 1),
                ),
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
          if (order.returnAdminNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Store note: ${order.returnAdminNote}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          if (!order.isReturnRejected && order.refundAmount > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Refund amount: \u20b1${order.refundAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
          if (destination != null) ...[
            const SizedBox(height: 2),
            Text(
              'Sent to: $destination',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          if (order.isRefunded && order.refundReference.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Reference no.: ${order.refundReference}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  (Color, IconData, String) _headline() {
    if (order.isRefunded) {
      final when = order.refundedAt > 0 ? ' on ${_formatDate(order.refundedAt)}' : '';
      return (Colors.green, Icons.check_circle, 'Refund sent$when');
    }
    if (order.isReturnRejected) {
      return (Colors.red, Icons.cancel, 'Return request declined');
    }
    if (order.refundStatus == 'refund_pending') {
      return (Colors.blue, Icons.hourglass_top, 'Return approved - refund on its way');
    }
    return (Colors.orange, Icons.assignment_return_outlined, 'Return under review');
  }

  /// "GCash - ****4567 (Juan Dela Cruz)", hiding all but the last 4 digits.
  String? _destination() {
    if (order.isReturnRejected || order.refundMethod.isEmpty) return null;
    final number = order.refundAccountNumber.replaceAll(RegExp(r'\s'), '');
    final tail = number.length > 4 ? number.substring(number.length - 4) : number;
    final masked = tail.isEmpty ? '' : ' ****$tail';
    final holder = order.refundAccountName.isEmpty ? '' : ' (${order.refundAccountName})';
    return '${order.refundMethod}$masked$holder';
  }

  static String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}/${d.year}';
  }
}
