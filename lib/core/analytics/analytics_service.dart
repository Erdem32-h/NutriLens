import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../services/device_id_service.dart';
import 'analytics_event.dart';

/// Ships one batch. Injectable so tests can drive the delivery, retry, and
/// offline paths without standing up a Supabase client (`rpc` returns a
/// `PostgrestFilterBuilder`, which is impractical to fake convincingly).
typedef AnalyticsUploader =
    Future<void> Function({
      required String deviceHash,
      required List<Map<String, Object?>> events,
    });

/// Buffers funnel events on-device and ships them to Supabase in batches.
///
/// Contract for callers: [track] is synchronous, never throws, and never
/// blocks. Analytics is the least important thing the app does — a failure
/// to record a step must never be visible to the user, so every failure path
/// here degrades to "the event is dropped" rather than surfacing an error.
///
/// Delivery is best-effort-with-persistence: events survive a cold kill via
/// SharedPreferences and are retried on the next launch, but a batch the
/// server rejects is discarded rather than retried forever.
class AnalyticsService {
  /// [prefs] and [deviceId] are nullable because `SharedPreferences` can fail
  /// to initialise at boot (main() only overrides the provider when it
  /// succeeded). Without them there is no device hash and no durable queue,
  /// so the service degrades to a no-op rather than half-working.
  AnalyticsService({
    required SupabaseClient? client,
    required DeviceIdService? deviceId,
    required SharedPreferences? prefs,
    bool enabled = true,
    Duration flushInterval = const Duration(seconds: 30),
    int batchSize = 20,
    String? sessionId,
    AnalyticsUploader? uploader,
  }) : _client = client,
       _uploader = uploader,
       _deviceId = deviceId,
       _prefs = prefs,
       _enabled = enabled && prefs != null && deviceId != null,
       _batchSize = batchSize,
       _sessionId = sessionId ?? const Uuid().v4() {
    _restore();
    if (_enabled) {
      _timer = Timer.periodic(flushInterval, (_) => unawaited(flush()));
    }
  }

  final SupabaseClient? _client;
  final AnalyticsUploader? _uploader;
  final DeviceIdService? _deviceId;
  final SharedPreferences? _prefs;
  final bool _enabled;
  final int _batchSize;
  final String _sessionId;

  /// Server-side cap in `track_events`. Sending more guarantees the whole
  /// batch is dropped, so we never build one larger than this.
  static const _maxServerBatch = 50;

  /// Bounds how much a long offline stretch can grow the on-device queue
  /// (and therefore the SharedPreferences blob). Oldest events are dropped
  /// first — the newest steps are the ones that explain current behaviour.
  static const _maxQueued = 200;

  static const _queueKey = 'analytics.pending_v1';
  static const _optOutKey = 'analytics.opt_out_v1';
  static const _localeKey = 'locale';

  final List<AnalyticsEvent> _queue = [];
  Timer? _timer;
  bool _flushing = false;
  String? _appVersion;
  bool _disposed = false;

  /// Groups every event from this app launch. Exposed for tests and for
  /// correlating a Sentry event with the funnel session that produced it.
  String get sessionId => _sessionId;

  @visibleForTesting
  int get pendingCount => _queue.length;

  /// User-facing kill switch, honoured on top of the build-time [_enabled]
  /// flag. Read fresh on every [track] so toggling it takes effect at once.
  bool get isOptedOut => _prefs?.getBool(_optOutKey) ?? false;

  Future<void> setOptedOut(bool value) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setBool(_optOutKey, value);
    if (value) {
      _queue.clear();
      await prefs.remove(_queueKey);
    }
  }

  /// Records one funnel step. Fire-and-forget by design.
  void track(String name, {Map<String, Object?> props = const {}}) {
    if (!_enabled || _disposed || isOptedOut) return;
    _queue.add(
      AnalyticsEvent(
        name: name,
        sessionId: _sessionId,
        occurredAt: DateTime.now(),
        props: props,
      ),
    );
    if (_queue.length > _maxQueued) {
      _queue.removeRange(0, _queue.length - _maxQueued);
    }
    unawaited(_persist());
    if (_queue.length >= _batchSize) unawaited(flush());
  }

  /// Uploads whatever is queued. Safe to call at any time; concurrent calls
  /// collapse into the one already running.
  Future<void> flush() async {
    if (!_enabled || _disposed || _flushing || _queue.isEmpty) return;
    final deviceId = _deviceId;
    final upload = _uploader ?? _supabaseUploader;
    if (upload == null || deviceId == null) return;

    _flushing = true;
    try {
      // Snapshot before awaiting: track() can append while the upload is in
      // flight, and those later events must survive this flush untouched.
      final batch = _queue.take(_maxServerBatch).toList(growable: false);
      final deviceHash = await deviceId.deviceHash();
      final version = await _resolveAppVersion();
      final locale = _prefs?.getString(_localeKey);
      final platform = Platform.operatingSystem;

      final payload = batch
          .map(
            (e) => {
              ...e.toJson(),
              'app_version': version,
              'platform': platform,
              'locale': locale,
            },
          )
          .toList(growable: false);

      await upload(deviceHash: deviceHash, events: payload);

      // Delivered (or deliberately dropped server-side — either way it is
      // not coming back). Remove exactly what we sent, by identity, so
      // events appended during the await are preserved.
      _queue.removeWhere((e) => batch.contains(e));
      await _persist();
    } catch (e) {
      // Offline, RPC missing, auth hiccup — leave the queue alone and let
      // the next tick retry. Nothing user-visible happens either way.
      debugPrint('[Analytics] flush failed: $e');
    } finally {
      _flushing = false;
    }
  }

  /// Default transport: the anon-executable `track_events` RPC. Null when
  /// Supabase never initialised, which disables flushing (events keep
  /// queueing and persist for a later launch).
  AnalyticsUploader? get _supabaseUploader {
    final client = _client;
    if (client == null) return null;
    return ({required deviceHash, required events}) async {
      await client.rpc(
        'track_events',
        params: {
          'p_device_hash': deviceHash,
          // Resolved per flush, not per event: a batch queued as a guest and
          // delivered after login is correctly attributed to the new user,
          // which is what stitches the two halves of the funnel together.
          'p_user_id': client.auth.currentUser?.id,
          'p_events': events,
        },
      );
    };
  }

  Future<String?> _resolveAppVersion() async {
    final cached = _appVersion;
    if (cached != null) return cached;
    try {
      final info = await PackageInfo.fromPlatform();
      final version = '${info.version}+${info.buildNumber}';
      _appVersion = version;
      return version;
    } catch (e) {
      debugPrint('[Analytics] package info unavailable: $e');
      return null;
    }
  }

  Future<void> _persist() async {
    final prefs = _prefs;
    if (!_enabled || prefs == null) return;
    try {
      if (_queue.isEmpty) {
        await prefs.remove(_queueKey);
        return;
      }
      final encoded = jsonEncode(
        _queue.map((e) => e.toJson()).toList(growable: false),
      );
      await prefs.setString(_queueKey, encoded);
    } catch (e) {
      debugPrint('[Analytics] persist failed: $e');
    }
  }

  /// Reloads events that a previous launch queued but never delivered.
  void _restore() {
    final prefs = _prefs;
    if (!_enabled || prefs == null) return;
    try {
      final raw = prefs.getString(_queueKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final item in decoded) {
        if (item is! Map) continue;
        final event = AnalyticsEvent.tryFromJson(
          Map<String, Object?>.from(item),
        );
        if (event != null) _queue.add(event);
      }
      if (_queue.length > _maxQueued) {
        _queue.removeRange(0, _queue.length - _maxQueued);
      }
    } catch (e) {
      // A corrupt blob must not brick the launch — drop it and move on.
      debugPrint('[Analytics] restore failed: $e');
      _queue.clear();
      unawaited(prefs.remove(_queueKey));
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    // Persist before tearing down; flush() is a no-op once disposed.
    await _persist();
    _disposed = true;
  }
}
