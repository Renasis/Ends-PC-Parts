import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../screens/map_pin_picker_screen.dart';
import 'map_preview.dart';

/// "Pin on map" row for an address form: a button when nothing is pinned,
/// or a small map with Adjust / Remove when a pin is set.
class MapPinField extends StatelessWidget {
  final LatLng? value;
  final ValueChanged<LatLng?> onChanged;

  const MapPinField({super.key, required this.value, required this.onChanged});

  Future<void> _pick(BuildContext context) async {
    final point = await MapPinPickerScreen.open(context, initial: value);
    if (point != null) onChanged(point);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pin = value;

    if (pin == null) {
      return OutlinedButton.icon(
        onPressed: () => _pick(context),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Pin location on map (optional)'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MapPreview(point: pin, onTap: () => _pick(context)),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.check_circle, size: 16, color: scheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text('Location pinned',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ),
            TextButton(
              onPressed: () => _pick(context),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: const Text('Adjust'),
            ),
            TextButton(
              onPressed: () => onChanged(null),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: scheme.error,
              ),
              child: const Text('Remove'),
            ),
          ],
        ),
      ],
    );
  }
}
