import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Test seam for "get the device's current position", same shape as
/// [ramadanClockProvider] in `ramadan_provider.dart` — the provider exposes
/// a function rather than a value so a test can override it with a fixed
/// result without waiting on real GPS/permission plumbing.
///
/// Requests permission if needed, then reads a coarse (`LocationAccuracy.low`
/// — a city centroid is all Ramadan timing needs) position. Returns null on
/// denial, a disabled location service, or any platform error — callers
/// treat null as "ask the user to pick a city instead".
final currentPositionProvider =
    Provider<Future<({double lat, double lng})?> Function()>(
      (_) => _currentPosition,
    );

Future<({double lat, double lng})?> _currentPosition() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
      ),
    );
    return (lat: position.latitude, lng: position.longitude);
  } catch (_) {
    return null;
  }
}
