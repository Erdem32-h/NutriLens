import 'dart:convert';
import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Produces a stable, privacy-preserving per-device identifier used to cap the
/// guest free-scan budget server-side.
///
/// We hash the raw OS identifier (ANDROID_ID on Android, identifierForVendor
/// on iOS) with an app salt, so the raw value never leaves the device — only
/// the SHA-256 digest is sent to Supabase.
///
/// Why this beats the old local counter: ANDROID_ID lives in system
/// Settings.Secure and **survives an app cache/data clear** (the exact abuse a
/// tester found). It resets on factory reset; IDFV resets only when all of the
/// vendor's apps are removed. Not unspoofable on rooted devices, but it raises
/// the bar well past "clear cache for 5 more scans".
class DeviceIdService {
  DeviceIdService(this._prefs);

  final SharedPreferences _prefs;

  static const _salt = 'nutrilens-guest-device-v1';
  static const _fallbackKey = 'device.fallback_id_v1';

  String? _cached;

  /// SHA-256(salt + rawDeviceId). Stable for the lifetime of the install
  /// (and across cache clears on Android). Cached in memory after the first
  /// call.
  Future<String> deviceHash() async {
    final cached = _cached;
    if (cached != null) return cached;
    final raw = await _rawId();
    final digest = sha256.convert(utf8.encode('$_salt:$raw'));
    final hash = digest.toString();
    _cached = hash;
    return hash;
  }

  Future<String> _rawId() async {
    try {
      if (Platform.isAndroid) {
        final id = await const AndroidId().getId();
        if (id != null && id.isNotEmpty) return 'android:$id';
      } else if (Platform.isIOS) {
        final info = await DeviceInfoPlugin().iosInfo;
        final idfv = info.identifierForVendor;
        if (idfv != null && idfv.isNotEmpty) return 'ios:$idfv';
      }
    } catch (e) {
      debugPrint('[DeviceId] native id unavailable: $e');
    }
    // Last resort when the OS id is unavailable: a locally-persisted UUID.
    // Doesn't survive a data clear, but keeps the hash stable within an
    // install so the server counter still works for that session.
    var fallback = _prefs.getString(_fallbackKey);
    if (fallback == null || fallback.isEmpty) {
      fallback = const Uuid().v4();
      await _prefs.setString(_fallbackKey, fallback);
    }
    return 'fallback:$fallback';
  }
}
