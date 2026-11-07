import 'package:flutter/material.dart';

import '../models/legal_document.dart';

/// Full-screen-ish sheet that shows a [LegalDocument]. Same look as the
/// Privacy Policy sheet.
class LegalDocumentSheet extends StatelessWidget {
  final LegalDocument document;

  const LegalDocumentSheet({super.key, required this.document});

  static Future<void> show(BuildContext context, LegalDocument document) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => LegalDocumentSheet(document: document),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              children: [
                Text(
                  document.title,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'PC Parts Store',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (document.intro.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(document.intro),
                ],
                const SizedBox(height: 16),
                for (final (title, body) in document.sections) ...[
                  Text(
                    title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(body),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
