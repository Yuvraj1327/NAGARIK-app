import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:nagarik/core/constants/report_status.dart';
import 'package:nagarik/core/maps/maps_availability.dart';
import 'package:nagarik/features/reports/domain/report_marker.dart';
import 'package:nagarik/features/reports/presentation/widgets/map_unavailable_view.dart';

/// Renders [markers] as pins on a Google Map — the "Map" half of Search's
/// List/Map toggle. Pins are tinted by report status (blue = submitted,
/// orange = in review, green = resolved), matching `StatusBadge`'s meaning.
/// Only ever draws the markers it is given (real backend results).
class ReportMap extends StatelessWidget {
  const ReportMap({
    super.key,
    required this.markers,
    required this.center,
    this.onMarkerTap,
  });

  final List<ReportMarker> markers;
  final LatLng center;
  final ValueChanged<ReportMarker>? onMarkerTap;

  static double _hueForStatus(ReportStatus status) => switch (status) {
        ReportStatus.submitted => BitmapDescriptor.hueAzure,
        ReportStatus.inReview => BitmapDescriptor.hueOrange,
        ReportStatus.resolved => BitmapDescriptor.hueGreen,
      };

  @override
  Widget build(BuildContext context) {
    if (!MapsAvailability.isAvailable) return const MapUnavailableView();

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: center, zoom: 13),
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      markers: {
        for (final marker in markers)
          Marker(
            markerId: MarkerId(marker.id),
            position: LatLng(marker.latitude, marker.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(_hueForStatus(marker.status)),
            onTap: onMarkerTap == null ? null : () => onMarkerTap!(marker),
          ),
      },
    );
  }
}
