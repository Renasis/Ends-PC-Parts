import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/ph_locations.dart';
import '../models/address_fields_controller.dart';
import '../models/shipping_address.dart';
import '../utils/address_validators.dart';
import 'address_label_selector.dart';
import 'map_pin_field.dart';

/// The whole address form, in clear groups:
/// label, address details (with ZIP code), delivery notes and map pin.
///
/// Used by the profile sheet and by checkout so both stay identical.
/// Set [showLabel] to false for a one-time address that is not being saved.
class AddressFields extends StatefulWidget {
  final AddressFieldsController controller;
  final bool showLabel;
  final bool showPreview;

  const AddressFields({
    super.key,
    required this.controller,
    this.showLabel = true,
    this.showPreview = true,
  });

  @override
  State<AddressFields> createState() => _AddressFieldsState();
}

class _AddressFieldsState extends State<AddressFields> {
  final _cityFocus = FocusNode();

  @override
  void dispose() {
    _cityFocus.dispose();
    super.dispose();
  }

  Iterable<String> _cityOptions(TextEditingValue value) {
    final c = widget.controller;
    if (!PhLocations.isRizal(c.province.text)) return const [];

    final query = value.text.trim().toLowerCase();
    final matches = PhLocations.rizalTowns
        .where((town) => town.toLowerCase().contains(query))
        .toList();

    // Nothing left to suggest once the whole name is typed.
    if (matches.length == 1 && matches.first.toLowerCase() == query) {
      return const [];
    }
    return matches;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;

    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showLabel) ...[
            const _FormLabel(icon: Icons.label_outline, text: 'Save address as'),
            const SizedBox(height: 8),
            AddressLabelSelector(
              value: c.label,
              onChanged: (label) => c.label = label,
            ),
            const SizedBox(height: 20),
          ],

          const _FormLabel(icon: Icons.home_outlined, text: 'Address details'),
          const SizedBox(height: 10),
          TextFormField(
            controller: c.street,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.streetAddressLine1],
            decoration: const InputDecoration(
              labelText: 'Street, Building, House No.',
              helperText: 'House or unit number, building and street name',
              prefixIcon: Icon(Icons.home_outlined),
            ),
            validator: (v) => AddressValidators.notEmpty(
              v,
              'Please enter your street address',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: c.barangay,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Barangay',
              prefixIcon: Icon(Icons.location_searching),
            ),
            validator: (v) =>
                AddressValidators.notEmpty(v, 'Please enter your barangay'),
          ),
          const SizedBox(height: 12),

          // City with suggestions for the towns of Rizal.
          LayoutBuilder(
            builder: (context, constraints) => RawAutocomplete<String>(
              textEditingController: c.city,
              focusNode: _cityFocus,
              optionsBuilder: _cityOptions,
              fieldViewBuilder: (context, textController, focusNode, submit) {
                return TextFormField(
                  controller: textController,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.addressCity],
                  onFieldSubmitted: (_) => submit(),
                  decoration: const InputDecoration(
                    labelText: 'City / Municipality',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                  validator: (v) => AddressValidators.notEmpty(
                    v,
                    'Please enter your city or municipality',
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                final scheme = Theme.of(context).colorScheme;
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: 220,
                        maxWidth: constraints.maxWidth,
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final town = options.elementAt(index);
                          return ListTile(
                            dense: true,
                            title: Text(town),
                            trailing: Text(
                              PhLocations.rizalZipCodes[town] ?? '',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                            onTap: () => onSelected(town),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: c.province,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.addressState],
                  decoration: const InputDecoration(labelText: 'Province'),
                  validator: (v) =>
                      AddressValidators.notEmpty(v, 'Required'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: c.zip,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.postalCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'ZIP code',
                    counterText: '',
                  ),
                  validator: AddressValidators.zip,
                ),
              ),
            ],
          ),
          if (c.zipIsSuggested) ...[
            const SizedBox(height: 6),
            _ZipHint(city: c.city.text.trim()),
          ],

          const SizedBox(height: 20),
          const _FormLabel(
            icon: Icons.sticky_note_2_outlined,
            text: 'Delivery notes',
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: c.landmark,
            maxLength: ShippingAddress.maxLandmarkLength,
            minLines: 1,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Landmark or note for the rider (optional)',
              hintText: 'e.g. Blue gate beside the sari-sari store',
              prefixIcon: Icon(Icons.flag_outlined),
            ),
          ),

          const SizedBox(height: 12),
          const _FormLabel(icon: Icons.map_outlined, text: 'Map location'),
          const SizedBox(height: 4),
          Text(
            'A pin helps the rider find you faster.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 10),
          MapPinField(
            value: c.pin,
            onChanged: (point) => c.pin = point,
          ),

          if (widget.showPreview) ...[
            const SizedBox(height: 16),
            ListenableBuilder(
              listenable: c.changes,
              builder: (context, _) {
                final address = c.toAddress();
                if (address.street.isEmpty) return const SizedBox.shrink();
                return _DeliveryPreview(text: address.formatted);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FormLabel({required this.icon, required this.text});

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

class _ZipHint extends StatelessWidget {
  final String city;

  const _ZipHint({required this.city});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(Icons.auto_awesome, size: 14, color: muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'ZIP code suggested for $city. Please check it is correct.',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
      ],
    );
  }
}

/// Shows the address exactly as it will be printed on the order.
class _DeliveryPreview extends StatelessWidget {
  final String text;

  const _DeliveryPreview({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_shipping_outlined, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your parcel will be delivered to',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
