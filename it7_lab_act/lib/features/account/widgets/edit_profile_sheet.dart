import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/form_scroll.dart';
import '../../address/models/address_fields_controller.dart';
import '../../address/utils/address_validators.dart';
import '../../address/widgets/address_fields.dart';
import '../../auth/providers/auth_provider.dart';

/// Bottom sheet for the name, phone and delivery address (ZIP code, label,
/// landmark and map pin) used at checkout. The Save button stays pinned at
/// the bottom while the form scrolls.
class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const EditProfileSheet(),
    );
  }

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  final _address = AddressFieldsController();
  bool _saving = false;

  /// Old accounts may have an address we could not split into fields.
  String _unsplitLegacy = '';

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _name = TextEditingController(text: auth.recipientName);
    _phone = TextEditingController(text: auth.phoneNumber);

    final saved = auth.savedAddress;
    _address.load(saved);
    if (saved.street.isEmpty && saved.legacyText.isNotEmpty) {
      _unsplitLegacy = saved.legacyText;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!validateAndScrollToError(_formKey)) return;

    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _saving = true);
    final saved = await auth.updateShippingProfile(
      name: _name.text,
      // Saved in one format: 09123456789.
      phone: AddressValidators.normalizePhone(_phone.text),
      address: _address.toAddress(),
    );

    if (!mounted) return;
    if (saved) {
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Shipping information updated.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage.isNotEmpty
              ? auth.errorMessage
              : 'Could not save your details. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shipping Information',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Where should we send your parts?',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Scrollable form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SheetLabel(
                      icon: Icons.person_outline,
                      text: 'Contact',
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => AddressValidators.notEmpty(
                        v,
                        'Please enter your name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-()]')),
                        LengthLimitingTextInputFormatter(17),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Mobile number',
                        hintText: '09123456789',
                        helperText: 'The rider will call or text this number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: AddressValidators.phone,
                    ),
                    const SizedBox(height: 24),
                    if (_unsplitLegacy.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                size: 18, color: scheme.onSecondaryContainer),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Your current address: $_unsplitLegacy\n'
                                'Please re-enter it in the fields below so we '
                                'can add your barangay and ZIP code.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    AddressFields(controller: _address),
                  ],
                ),
              ),
            ),
          ),

          // Pinned save bar
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save shipping information'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SheetLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          text.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
