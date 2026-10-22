import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:nagarik/core/maps/maps_availability.dart';
import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/l10n/app_localizations.dart';
import 'package:nagarik/features/reports/data/location_service.dart';
import 'package:nagarik/features/reports/presentation/widgets/map_unavailable_view.dart';

/// The pin is a draggable [Marker] (dragging it, tapping the map, searching
/// or "locate me" all move it); [onPositionChanged] reports every new pin
/// position. The map opens with the pin at [initialPosition].
///
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
/// Lets the screen that owns a [LocationPickerMap] move its camera from
/// outside (the Place step's "Search an area or landmark" field) without
/// reaching into the map's private state.
class LocationPickerController {
  Future<void> Function(LatLng target)? _moveTo;

  Future<void> moveTo(LatLng target) async => _moveTo?.call(target);
}

class LocationPickerMap extends StatefulWidget {
  const LocationPickerMap({
    super.key,
    required this.initialPosition,
    required this.onPositionChanged,
    required this.locationService,
    this.controller,
  });

  final LocationPickerController? controller;

  final LatLng initialPosition;
  final ValueChanged<LatLng> onPositionChanged;
  final LocationService locationService;

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  late LatLng _selected = widget.initialPosition;
  bool _isLocating = false;

  /// Moves the pin to [target], recenters the camera and reports it.
  Future<void> _selectAndShow(LatLng target) async {
    setState(() => _selected = target);
    widget.onPositionChanged(target);
    final controller = await _controller.future;
    await controller.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
  }

  void _select(LatLng target) {
    setState(() => _selected = target);
    widget.onPositionChanged(target);
  }

  @override
  void initState() {
    super.initState();
    widget.controller?._moveTo = _selectAndShow;
  }

  @override
  void dispose() {
    widget.controller?._moveTo = null;
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    final settingsLabel = AppLocalizations.of(context).repSettings;
    try {
      final position = await widget.locationService.getCurrentPosition();
      final target = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      await _selectAndShow(target);
    } on LocationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          // Permanently denied / services off can only be fixed in OS
          // settings — offer a direct way there instead of a dead end.
          action: error.needsAppSettings
              ? SnackBarAction(label: settingsLabel, onPressed: widget.locationService.openAppSettings)
              : error.needsLocationServices
                  ? SnackBarAction(
                      label: settingsLabel,
                      onPressed: widget.locationService.openLocationSettings,
                    )
                  : null,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!MapsAvailability.isAvailable) {
      return const ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(24)),
        child: SizedBox(height: 300, child: MapUnavailableView()),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 300,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: _selected, zoom: 15),
              onMapCreated: _controller.complete,
              onTap: _select,
              markers: {
                Marker(
                  markerId: const MarkerId('selected'),
                  position: _selected,
                  draggable: true,
                  onDragEnd: _select,
                ),
              },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [BoxShadow(blurRadius: 6, color: Color(0x220F1F3D))],
                ),
                child: Text(
                  AppLocalizations.of(context).repDragPin,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimaryColor),
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
      color: context.surfaceColor,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: const Color(0x330F1F3D),
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
              : Icon(Icons.my_location, size: 18, color: context.accentColor),
        ),
      ),
    );
  }
}
