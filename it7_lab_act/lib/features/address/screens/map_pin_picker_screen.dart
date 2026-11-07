import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../widgets/map_preview.dart';

/// Full-screen map. The pin stays in the middle of the screen; the customer
/// drags the map until the pin sits on their door, then confirms.
/// Pops with the chosen [LatLng], or null when cancelled.
class MapPinPickerScreen extends StatefulWidget {
  final LatLng? initial;

  const MapPinPickerScreen({super.key, this.initial});

  /// Opens the picker and returns the chosen point (null if cancelled).
  static Future<LatLng?> open(BuildContext context, {LatLng? initial}) {
    return Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (_) => MapPinPickerScreen(initial: initial)),
    );
  }

  @override
  State<MapPinPickerScreen> createState() => _MapPinPickerScreenState();
}

class _MapPinPickerScreenState extends State<MapPinPickerScreen> {
  static const _pinSize = 48.0;

  late LatLng _center = widget.initial ?? defaultMapCenter;
  bool _moving = false;

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _center = camera.center;
    if (hasGesture != _moving) setState(() => _moving = hasGesture);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pin your location',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _center,
              initialZoom: widget.initial == null ? 14 : 17,
              minZoom: 5,
              maxZoom: 19,
              onPositionChanged: _onPositionChanged,
            ),
            children: [
              TileLayer(
                urlTemplate: mapTileUrl,
                userAgentPackageName: mapUserAgentPackage,
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),

          // Fixed pin in the middle: its tip sits exactly on the map centre.
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: _pinSize + (_moving ? 12 : 0)),
                child: Icon(Icons.location_on, size: _pinSize, color: scheme.error),
              ),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: _moving ? 10 : 6,
                height: _moving ? 5 : 3,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Material(
              elevation: 2,
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.open_with, size: 18, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Drag the map so the pin is on your delivery spot.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, _center),
            icon: const Icon(Icons.check),
            label: const Text('Confirm location'),
          ),
        ),
      ),
    );
  }
}
