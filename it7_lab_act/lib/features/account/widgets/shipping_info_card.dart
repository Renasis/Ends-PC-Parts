import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/widgets/surface_card.dart';
import '../../address/models/shipping_address.dart';
import '../../address/utils/address_validators.dart';
import '../../address/widgets/map_preview.dart';
import 'edit_profile_sheet.dart';

/// Name, email, phone and delivery address (with ZIP code, label, landmark and
/// map pin) used at checkout, plus a progress bar showing what is still missing.
class ShippingInfoCard extends StatelessWidget {
  final String name;
  final String email;
  final String phone;
  final ShippingAddress address;

  const ShippingInfoCard({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
  });

  void _edit(BuildContext context) => EditProfileSheet.show(context);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final steps = <_Step>[
      _Step('Name', 'Add your name', name.trim().isNotEmpty),
      _Step('Phone number', 'Add a valid mobile number',
          AddressValidators.isValidPhone(phone)),
      _Step(
        'Delivery address',
        'Add full address',
        address.street.isNotEmpty &&
            address.barangay.isNotEmpty &&
            address.city.isNotEmpty &&
            address.province.isNotEmpty,
      ),
      _Step('ZIP code', 'Add ZIP code', RegExp(r'^\d{4}$').hasMatch(address.zipCode)),
    ];

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: scheme.primary.withValues(alpha: 0.12),
                child: Icon(Icons.local_shipping_outlined,
                    color: scheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shipping Information',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Used to fill in checkout for you',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _edit(context),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          _Progress(steps: steps, onEdit: () => _edit(context)),

          const SizedBox(height: 16),
          const _SectionLabel('Contact'),
          const SizedBox(height: 8),
          _GroupBox(
            children: [
              _InfoTile(
                icon: Icons.person_outline,
                label: 'Name',
                value: name,
              ),
              _InfoTile(
                icon: Icons.email_outlined,
                label: 'Email',
                value: email,
              ),
              _InfoTile(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: phone,
                placeholder: 'Add your phone number',
              ),
            ],
          ),

          const SizedBox(height: 16),
          const _SectionLabel('Delivery address'),
          const SizedBox(height: 8),
          _AddressBlock(address: address, onEdit: () => _edit(context)),
        ],
      ),
    );
  }
}

class _Step {
  final String name;
  final String action;
  final bool done;

  const _Step(this.name, this.action, this.done);
}

/// "2 of 4 done" bar with one tappable chip per missing item, or a green
/// "ready" message once everything is filled in.
class _Progress extends StatelessWidget {
  final List<_Step> steps;
  final VoidCallback onEdit;

  const _Progress({required this.steps, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = steps.where((s) => s.done).length;
    final missing = steps.where((s) => !s.done).toList();
    final complete = missing.isEmpty;

    final background =
        complete ? scheme.tertiaryContainer : scheme.secondaryContainer;
    final foreground =
        complete ? scheme.onTertiaryContainer : scheme.onSecondaryContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                complete ? Icons.check_circle : Icons.info_outline,
                size: 18,
                color: foreground,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  complete
                      ? 'Ready to order'
                      : 'Complete your profile to place orders',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '$done / ${steps.length}',
                style: theme.textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: done / steps.length,
              minHeight: 6,
              backgroundColor: foreground.withValues(alpha: 0.18),
              color: foreground,
            ),
          ),
          if (complete) ...[
            const SizedBox(height: 8),
            Text(
              'We will fill in your details for you at checkout.',
              style: theme.textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 0,
              children: [
                for (final step in missing)
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: Text(step.action),
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ],
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
    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      ),
    );
  }
}

/// Rounded box that stacks rows with thin dividers between them.
class _GroupBox extends StatelessWidget {
  final List<Widget> children;

  const _GroupBox({required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? placeholder;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final missing = value.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  missing ? (placeholder ?? 'Not provided') : value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: missing ? FontWeight.normal : FontWeight.w600,
                    fontStyle: missing ? FontStyle.italic : FontStyle.normal,
                    color: missing ? scheme.onSurfaceVariant : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressBlock extends StatelessWidget {
  final ShippingAddress address;
  final VoidCallback onEdit;

  const _AddressBlock({required this.address, required this.onEdit});

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: address.formatted));
    messenger.showSnackBar(
      const SnackBar(content: Text('Address copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (address.isEmpty) {
      return _GroupBox(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.location_off_outlined,
                    size: 20, color: scheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No delivery address saved yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(onPressed: onEdit, child: const Text('Add')),
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tags: Home / Work / Other, and whether a map pin is saved.
          Row(
            children: [
              _Pill(
                icon: address.label.icon,
                text: address.label.text,
                background: scheme.primary.withValues(alpha: 0.12),
                foreground: scheme.primary,
              ),
              const Spacer(),
              if (address.hasPin)
                _Pill(
                  icon: Icons.pin_drop_outlined,
                  text: 'Pin saved',
                  background: scheme.tertiaryContainer,
                  foreground: scheme.onTertiaryContainer,
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (address.isStructured) ...[
            Text(
              address.street,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _DetailCell(label: 'Barangay', value: address.barangay),
                ),
                Expanded(
                  child: _DetailCell(
                      label: 'City / Municipality', value: address.city),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _DetailCell(label: 'Province', value: address.province),
                ),
                Expanded(
                  child: _DetailCell(
                    label: 'ZIP code',
                    value: address.zipCode,
                    flagIfMissing: true,
                  ),
                ),
              ],
            ),
          ] else ...[
            // Old one-line address that could not be split into parts.
            Text(
              address.legacyText,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            _Note(
              icon: Icons.upgrade,
              text:
                  'This address uses the old format. Tap Edit to add your barangay and ZIP code.',
              color: scheme.secondaryContainer,
              onColor: scheme.onSecondaryContainer,
            ),
          ],

          if (address.hasLandmark) ...[
            const SizedBox(height: 12),
            _Note(
              icon: Icons.flag_outlined,
              text: address.landmark,
              color: scheme.surfaceContainerHighest,
              onColor: scheme.onSurface,
            ),
          ],

          const SizedBox(height: 12),
          if (address.hasPin)
            MapPreview(
              point: LatLng(address.latitude!, address.longitude!),
              height: 130,
              onTap: onEdit,
            )
          else
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: const Text('Add a map pin'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copy(context),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
                  label: const Text('Edit address'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;

  const _Pill({
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCell extends StatelessWidget {
  final String label;
  final String value;

  /// Show "Missing" in the error colour instead of a dash.
  final bool flagIfMissing;

  const _DetailCell({
    required this.label,
    required this.value,
    this.flagIfMissing = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final missing = value.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          missing ? (flagIfMissing ? 'Missing' : '—') : value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontStyle: missing && flagIfMissing
                ? FontStyle.italic
                : FontStyle.normal,
            color: missing && flagIfMissing ? scheme.error : null,
          ),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color onColor;

  const _Note({
    required this.icon,
    required this.text,
    required this.color,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: onColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: onColor),
            ),
          ),
        ],
      ),
    );
  }
}
