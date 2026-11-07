import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// OpenStreetMap needs an app identifier on tile requests.
/// Change this to your app's package name.
const mapUserAgentPackage = 'com.example.it7_lab_act';
const mapTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Default map centre (Binangonan, Rizal) when nothing is pinned yet.
const defaultMapCenter = LatLng(14.4650, 121.1925);

/// Small read-only map showing one pin. Touches pass through to whatever
/// is behind it, so it is safe inside a scrolling list.
class MapPreview extends StatelessWidget {
  final LatLng point;
  final double height;
  final VoidCallback? onTap;

  const MapPreview({
    super.key,
    required this.point,
    this.height = 140,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: [
            IgnorePointer(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 16,
                  interactionOptions:
                      const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  TileLayer(
                    urlTemplate: mapTileUrl,
                    userAgentPackageName: mapUserAgentPackage,
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 44,
                        height: 44,
                        alignment: Alignment.topCenter,
                        child: Icon(
                          Icons.location_on,
                          size: 44,
                          color: scheme.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(onTap: onTap),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
