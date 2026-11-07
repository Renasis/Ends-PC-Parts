import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../account/widgets/edit_profile_sheet.dart';
import '../../address/models/address_fields_controller.dart';
import '../../address/models/shipping_address.dart';
import '../../address/utils/address_validators.dart';
import '../../address/widgets/address_fields.dart';
import '../../address/widgets/map_preview.dart';
import 'section_card.dart';

/// Delivery address for checkout. The customer either uses the address saved
/// on their profile or types a new one for this order only.
class AddressSection extends StatelessWidget {
  /// Saved profile details. [hasSaved] is false when any of them is missing.
  final String savedName;
  final String savedPhone;
  final ShippingAddress savedAddress;
  final bool hasSaved;

  /// True = use the saved address, false = enter a new one.
  final bool useSaved;
  final ValueChanged<bool> onModeChanged;

  /// Fields for the "new address" option.
  final TextEditingController name;
  final TextEditingController phone;
  final AddressFieldsController address;

  const AddressSection({
    super.key,
    required this.savedName,
    required this.savedPhone,
    required this.savedAddress,
    required this.hasSaved,
    required this.useSaved,
    required this.onModeChanged,
    required this.name,
    required this.phone,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    final showSaved = hasSaved && useSaved;

    return SectionCard(
      icon: Icons.location_on_outlined,
      title: 'Delivery Address',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasSaved) ...[
            _OptionTile(
              selected: useSaved,
              icon: Icons.bookmark_outline,
              title: 'Use my saved address',
              onTap: () => onModeChanged(true),
              child: _SavedSummary(
                name: savedName,
                phone: savedPhone,
                address: savedAddress,
              ),
            ),
            const SizedBox(height: 8),
            _OptionTile(
              selected: !useSaved,
              icon: Icons.add_location_alt_outlined,
              title: 'Deliver to a new address',
              subtitle: 'Only for this order. Your saved address stays the same.',
              onTap: () => onModeChanged(false),
            ),
            const SizedBox(height: 4),
          ] else
            const _NoSavedNotice(),

          if (!showSaved) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) =>
                  AddressValidators.notEmpty(v, 'Please enter your name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                hintText: '09123456789',
                helperText: 'The rider will call or text this number',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: AddressValidators.phone,
            ),
            const SizedBox(height: 20),
            // A one-time address does not need a Home / Work tag.
            AddressFields(controller: address, showLabel: false),
          ],
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? child;

  const _OptionTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? scheme.primary.withValues(alpha: 0.06) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 20,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (child != null) ...[
              const SizedBox(height: 10),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}

class _SavedSummary extends StatelessWidget {
  final String name;
  final String phone;
  final ShippingAddress address;

  const _SavedSummary({
    required this.name,
    required this.phone,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(left: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(address.label.icon, size: 14, color: scheme.primary),
              const SizedBox(width: 4),
              Text(
                address.label.text,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('$name  •  $phone',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(address.primaryLine,
              style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          if (address.secondaryLine.isNotEmpty)
            Text(address.secondaryLine,
                style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          if (address.hasLandmark) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.flag_outlined, size: 14, color: muted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    address.landmark,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: muted, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ],
          if (!address.hasZip) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => EditProfileSheet.show(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 16, color: scheme.onErrorContainer),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'No ZIP code yet. Tap to add it.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (address.hasPin) ...[
            const SizedBox(height: 10),
            MapPreview(
              point: LatLng(address.latitude!, address.longitude!),
              height: 110,
            ),
          ],
        ],
      ),
    );
  }
}

class _NoSavedNotice extends StatelessWidget {
  const _NoSavedNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You have no saved address. Enter one below, or save one in '
              'Account > Shipping Information for faster checkout.',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
