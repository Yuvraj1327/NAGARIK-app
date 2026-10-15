import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:nagarik/core/maps/maps_availability.dart';
import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/features/reports/presentation/widgets/map_unavailable_view.dart';

/// Whether [latitude]/[longitude] are a real, usable position. Rejects
/// null, NaN/infinite, out-of-range, and the (0, 0) "null island" value that
/// uninitialised data tends to produce — a bad pair shows no map rather than
/// a wrong one.
bool isValidCoordinate(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) return false;
  if (!latitude.isFinite || !longitude.isFinite) return false;
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) return false;
  if (latitude == 0 && longitude == 0) return false;
  return true;
}

/// Compact, read-only map of one report's saved location for Report Detail.
/// Not interactive (a scrolling page shouldn't fight a map for gestures);
/// tapping opens [ReportLocationFullScreen]. Renders nothing for missing or
/// invalid coordinates.
class ReportLocationMap extends StatelessWidget {
  const ReportLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.title,
  });

  final double? latitude;
  final double? longitude;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (!isValidCoordinate(latitude, longitude)) return const SizedBox.shrink();
    final position = LatLng(latitude!, longitude!);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 180,
        child: !MapsAvailability.isAvailable
            ? const MapUnavailableView(compact: true)
            : Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(target: position, zoom: 15),
                    markers: {Marker(markerId: const MarkerId('report'), position: position)},
                                    scrollGesturesEnabled: false,
                    zoomGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                    onTap: (_) => _openFullScreen(context, position),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Material(
                      color: AppColors.surface,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: IconButton(
                        tooltip: 'Open larger map',
                        icon: const Icon(Icons.fullscreen, color: AppColors.primary),
                        onPressed: () => _openFullScreen(context, position),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _openFullScreen(BuildContext context, LatLng position) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReportLocationFullScreen(position: position, title: title),
      ),
    );
  }
}

/// Larger, freely pannable/zoomable view of one report's location.
class ReportLocationFullScreen extends StatelessWidget {
  const ReportLocationFullScreen({super.key, required this.position, required this.title});

  final LatLng position;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: MapsAvailability.isAvailable
          ? GoogleMap(
              initialCameraPosition: CameraPosition(target: position, zoom: 16),
              markers: {Marker(markerId: const MarkerId('report'), position: position)},
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
            )
          : const MapUnavailableView(),
    );
  }
}
