import 'package:flutter/material.dart';

import '../models/cancel_reasons.dart';

/// Asks the customer why they are cancelling.
///
/// Returns the reason to save, or null when they chose to keep the order.
Future<String?> askCancelReason(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _CancelReasonSheet(),
  );
}

class _CancelReasonSheet extends StatefulWidget {
  const _CancelReasonSheet();

  @override
  State<_CancelReasonSheet> createState() => _CancelReasonSheetState();
}

class _CancelReasonSheetState extends State<_CancelReasonSheet> {
  final _otherController = TextEditingController();
  String? _selected;
  String? _error;

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  void _submit() {
    final selected = _selected;
    if (selected == null) {
      setState(() => _error = 'Please select a reason.');
      return;
    }
    if (selected == CancelReasons.other) {
      final text = _otherController.text.trim();
      if (text.isEmpty) {
        setState(() => _error = 'Please tell us your reason.');
        return;
      }
      Navigator.pop(context, 'Other: $text');
      return;
    }
    Navigator.pop(context, selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isOther = _selected == CancelReasons.other;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cancel Order',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Please tell us why you are cancelling. This cannot be undone.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _selected,
              onChanged: (value) => setState(() {
                _selected = value;
                _error = null;
              }),
              child: Column(
                children: [
                  for (final reason in CancelReasons.presets)
                    RadioListTile<String>(
                      value: reason,
                      title: Text(reason),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            if (isOther)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: TextField(
                  controller: _otherController,
                  autofocus: true,
                  maxLines: 3,
                  maxLength: CancelReasons.maxOtherLength,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Your reason',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_error!, style: TextStyle(color: scheme.error)),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Keep Order'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                    ),
                    child: const Text('Cancel Order'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
