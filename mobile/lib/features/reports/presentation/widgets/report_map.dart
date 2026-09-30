import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

import 'package:nagarik/core/constants/report_status.dart';
import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/features/reports/domain/report_marker.dart';

/// Renders [markers] as pins on an OpenStreetMap-tiled map — the "Map" half
/// of Search's List/Map toggle (Location Discovery & Home upgrade).
///
/// Uses `flutter_map` (OpenStreetMap tiles) rather than `google_maps_flutter`
/// deliberately: no API key or native platform configuration is needed to
/// show real report coordinates on a map, which is all this step actually
/// asks for — see `pubspec.yaml`'s comment on the dependency. Each pin is
/// colored by the report's status using the exact same colors as
/// `StatusBadge`, so a marker's color means the same thing everywhere in
/// the app.
class ReportMap extends StatelessWidget {
  const ReportMap({
    super.key,
    required this.markers,
    required this.center,
    this.onMarkerTap,
  });

  final List<ReportMarker> markers;
  final latlong.LatLng center;
  final ValueChanged<ReportMarker>? onMarkerTap;

  static Color _colorForStatus(ReportStatus status) => switch (status) {
        ReportStatus.submitted => AppColors.statusSubmitted,
        ReportStatus.inReview => AppColors.statusInReview,
        ReportStatus.resolved => AppColors.statusResolved,
      };

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 13),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.nagarik.app',
        ),
        MarkerLayer(
          markers: [
            for (final marker in markers)
              Marker(
                point: latlong.LatLng(marker.latitude, marker.longitude),
                width: 36,
                height: 36,
                child: GestureDetector(
                  onTap: onMarkerTap == null ? null : () => onMarkerTap!(marker),
                  child: Icon(
                    Icons.location_on,
                    color: _colorForStatus(marker.status),
                    size: 36,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
