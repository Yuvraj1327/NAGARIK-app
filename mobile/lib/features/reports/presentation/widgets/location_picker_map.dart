import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/features/reports/data/location_service.dart';

/// Report Issue redesign: the "Place" step's map — a real `GoogleMap` (per
/// explicit request; see `pubspec.yaml`'s comment on why this is a
/// different map technology from `flutter_map`, which Search/Nearby keeps
/// using unchanged) with a pin fixed at the exact center of the view.
/// Dragging/panning the map — not dragging a marker — is how the person
/// adjusts the point, the same "drag the map, the pin stays put" pattern
/// the reference screenshots use; [onPositionChanged] fires once the
/// camera settles (`onCameraIdle`), not on every frame of the pan, so the
/// caller (reverse geocoding the center, in `create_report_screen.dart`)
/// isn't re-triggered dozens of times per second while the finger is still
/// moving.
///
/// Only ever shows real coordinates: [initialPosition] comes from either
/// the draft's already-captured latitude/longitude or, if none yet, a
/// neutral India-wide default the caller passes in — never a fabricated
/// "current location". The "locate me" button requests the device's real
/// GPS position through [locationService] (the same class/permission
/// handling Home's location indicator and the old Location step already
/// used) and recenters the map there; it never invents a position either.
///
/// [onPositionChanged] is never called for the map's very first
/// `onCameraIdle` — `google_maps_flutter` fires that callback once on
/// initial layout too, not only after a real user-driven pan, and calling
/// back then would silently write [initialPosition] (which may be the
/// neutral default, not anything the person chose) into the draft. The
/// first idle event is swallowed by [_hasHadFirstIdle] below; every idle
/// after that one really does follow a pan or a "locate me" tap.
class LocationPickerMap extends StatefulWidget {
  const LocationPickerMap({
    super.key,
    required this.initialPosition,
    required this.onPositionChanged,
    required this.locationService,
  });

  final LatLng initialPosition;
  final ValueChanged<LatLng> onPositionChanged;
  final LocationService locationService;

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  late LatLng _center = widget.initialPosition;
  bool _isLocating = false;

  /// Swallows the very first `onCameraIdle` (initial layout settling, not a
  /// user pan) — see this class's doc comment above. Flips to `true` the
  /// first time `onCameraIdle` fires and is never reset.
  bool _hasHadFirstIdle = false;

  void _onCameraIdle() {
    if (!_hasHadFirstIdle) {
      _hasHadFirstIdle = true;
      return;
    }
    widget.onPositionChanged(_center);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final position = await widget.locationService.getCurrentPosition();
      final target = LatLng(position.latitude, position.longitude);
      final controller = await _controller.future;
      await controller.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
      // `onCameraIdle` fires once the animated pan above settles and
      // reports the new center back through `onPositionChanged` — no need
      // to call it a second time here.
    } on LocationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 260,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: _center, zoom: 15),
              onMapCreated: _controller.complete,
              onCameraMove: (position) => _center = position.target,
              onCameraIdle: _onCameraIdle,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
            // The fixed center pin — nudged up by half its height so the
            // glyph's visual tip (not its bounding box's center) lands on
            // the exact map center the map reports back as the chosen
            // point.
            IgnorePointer(
              child: Transform.translate(
                offset: const Offset(0, -18),
                child: const Icon(
                  Icons.location_on,
                  size: 40,
                  color: AppColors.primary,
                  shadows: [Shadow(blurRadius: 6, color: Color(0x5512213A))],
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: _LocateMeButton(isLoading: _isLocating, onPressed: _useCurrentLocation),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocateMeButton extends StatelessWidget {
  const _LocateMeButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: const Color(0x3312213A),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: isLoading ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.primary),
                )
              : const Icon(Icons.my_location, size: 18, color: AppColors.primary),
        ),
      ),
    );
  }
}
