import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/analytics/analytics_event.dart';
import 'package:nutrilens/core/analytics/analytics_service.dart';
import 'package:nutrilens/core/services/device_id_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Captures batches instead of hitting Supabase, and can be told to fail so
/// the offline path is exercised.
class _RecordingUploader {
  final List<List<Map<String, Object?>>> batches = [];
  final List<String> deviceHashes = [];
  bool shouldFail = false;

  Future<void> call({
    required String deviceHash,
    required List<Map<String, Object?>> events,
  }) async {
    if (shouldFail) throw Exception('offline');
    deviceHashes.add(deviceHash);
    batches.add(events);
  }
}

const _queueKey = 'analytics.pending_v1';

Future<AnalyticsService> _service({
  Map<String, Object> prefs = const {},
  _RecordingUploader? uploader,
  bool enabled = true,
  bool withPrefs = true,
  int batchSize = 20,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  return AnalyticsService(
    client: null,
    deviceId: withPrefs ? DeviceIdService(instance) : null,
    prefs: withPrefs ? instance : null,
    enabled: enabled,
    batchSize: batchSize,
    uploader: uploader?.call,
    // Long enough that no test races the periodic timer; every test drives
    // flush() explicitly.
    flushInterval: const Duration(hours: 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('track', () {
    test('queues events without needing a flush', () async {
      final service = await _service();
      addTearDown(service.dispose);

      service.track(FunnelEvents.appOpened);
      service.track(FunnelEvents.scannerOpened);

      expect(service.pendingCount, 2);
    });

    test('stamps every event with the same session id', () async {
      final uploader = _RecordingUploader();
      final service = await _service(uploader: uploader);
      addTearDown(service.dispose);

      service.track(FunnelEvents.appOpened);
      service.track(FunnelEvents.productViewed);
      await service.flush();

      // One session id across the batch is what lets a query ask "of the
      // launches that opened the scanner, how many reached a product".
      final sessions = uploader.batches.single
          .map((e) => e['session_id'])
          .toSet();
      expect(sessions, hasLength(1));
      expect(sessions.single, service.sessionId);
    });

    test('is a no-op when the service is disabled', () async {
      final service = await _service(enabled: false);
      addTearDown(service.dispose);

      service.track(FunnelEvents.appOpened);

      expect(service.pendingCount, 0);
    });

    test('is a no-op when SharedPreferences never initialised', () async {
      // Without prefs there is no device hash and no durable queue, so the
      // service must disable itself rather than half-work.
      final service = await _service(withPrefs: false);
      addTearDown(service.dispose);

      service.track(FunnelEvents.appOpened);

      expect(service.pendingCount, 0);
    });

    test('drops the oldest events once the queue cap is reached', () async {
      final service = await _service(batchSize: 100000);
      addTearDown(service.dispose);

      for (var i = 0; i < 260; i++) {
        service.track(FunnelEvents.productViewed, props: {'i': i});
      }

      expect(service.pendingCount, 200);
    });
  });

  group('flush', () {
    test('uploads queued events and clears the queue', () async {
      final uploader = _RecordingUploader();
      final service = await _service(uploader: uploader);
      addTearDown(service.dispose);

      service.track(FunnelEvents.appOpened, props: {'first_launch': true});
      await service.flush();

      expect(uploader.batches, hasLength(1));
      expect(uploader.batches.single.single['event'], FunnelEvents.appOpened);
      expect(service.pendingCount, 0);
    });

    test('sends a stable device hash rather than a raw identifier', () async {
      final uploader = _RecordingUploader();
      final service = await _service(uploader: uploader);
      addTearDown(service.dispose);

      service.track(FunnelEvents.appOpened);
      await service.flush();
      service.track(FunnelEvents.scannerOpened);
      await service.flush();

      // SHA-256 hex, identical across flushes — the server keys the funnel
      // on this, so an unstable value would split one device into many.
      expect(uploader.deviceHashes, hasLength(2));
      expect(uploader.deviceHashes.first, uploader.deviceHashes.last);
      expect(uploader.deviceHashes.first, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('keeps events queued when the upload fails', () async {
      final uploader = _RecordingUploader()..shouldFail = true;
      final service = await _service(uploader: uploader);
      addTearDown(service.dispose);

      service.track(FunnelEvents.appOpened);
      await service.flush();

      expect(uploader.batches, isEmpty);
      expect(service.pendingCount, 1, reason: 'offline must not lose events');
    });

    test('retries the same events on the next flush', () async {
      final uploader = _RecordingUploader()..shouldFail = true;
      final service = await _service(uploader: uploader);
      addTearDown(service.dispose);

      service.track(FunnelEvents.appOpened);
      await service.flush();

      uploader.shouldFail = false;
      await service.flush();

      expect(uploader.batches.single, hasLength(1));
      expect(service.pendingCount, 0);
    });

    test('never sends more than the server accepts in one batch', () async {
      final uploader = _RecordingUploader();
      final service = await _service(uploader: uploader, batchSize: 100000);
      addTearDown(service.dispose);

      for (var i = 0; i < 120; i++) {
        service.track(FunnelEvents.productViewed);
      }
      await service.flush();

      // track_events rejects batches over 50 outright, so an oversized batch
      // would silently discard everything in it.
      expect(uploader.batches.single, hasLength(50));
      expect(service.pendingCount, 70);
    });

    test('preserves events recorded while an upload is in flight', () async {
      final uploader = _RecordingUploader();
      final service = await _service(uploader: uploader);
      addTearDown(service.dispose);

      service.track(FunnelEvents.appOpened);
      final pending = service.flush();
      service.track(FunnelEvents.scannerOpened);
      await pending;

      expect(uploader.batches.single, hasLength(1));
      expect(service.pendingCount, 1);
    });

    test('does nothing when there is no uploader', () async {
      final service = await _service();
      addTearDown(service.dispose);

      service.track(FunnelEvents.appOpened);
      await service.flush();

      expect(service.pendingCount, 1);
    });
  });

  group('persistence', () {
    test('restores events a previous launch never delivered', () async {
      // Deliberately shares one SharedPreferences instance across both
      // services: that is what a cold restart looks like, and the whole
      // point is that a user who churns without reopening still shows up.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      AnalyticsService build(_RecordingUploader? uploader) => AnalyticsService(
        client: null,
        deviceId: DeviceIdService(prefs),
        prefs: prefs,
        uploader: uploader?.call,
        flushInterval: const Duration(hours: 1),
      );

      final first = build(null);
      first.track(FunnelEvents.appOpened);
      first.track(FunnelEvents.scannerOpened);
      await first.dispose();
      expect(prefs.getString(_queueKey), isNotNull);

      final uploader = _RecordingUploader();
      final second = build(uploader);
      addTearDown(second.dispose);
      expect(second.pendingCount, 2);

      await second.flush();
      expect(
        uploader.batches.single.map((e) => e['event']),
        containsAll(<String>[
          FunnelEvents.appOpened,
          FunnelEvents.scannerOpened,
        ]),
      );
    });

    test(
      'survives a corrupt queue instead of throwing at construction',
      () async {
        final service = await _service(prefs: {_queueKey: 'not json at all'});
        addTearDown(service.dispose);

        expect(service.pendingCount, 0);
      },
    );

    test('ignores malformed entries but keeps the well-formed ones', () async {
      final blob = jsonEncode([
        {'event': 'app_opened', 'session_id': 'abc', 'occurred_at': 'nonsense'},
        {
          'event': 'product_viewed',
          'session_id': 'abc',
          'occurred_at': DateTime.now().toIso8601String(),
          'props': {'has_score': true},
        },
      ]);
      final service = await _service(prefs: {_queueKey: blob});
      addTearDown(service.dispose);

      expect(service.pendingCount, 1);
    });
  });

  group('opt out', () {
    test('stops recording and clears anything already queued', () async {
      final service = await _service();
      addTearDown(service.dispose);

      service.track(FunnelEvents.appOpened);
      await service.setOptedOut(true);
      service.track(FunnelEvents.scannerOpened);

      expect(service.isOptedOut, isTrue);
      expect(service.pendingCount, 0);
    });
  });

  group('AnalyticsEvent', () {
    test('round-trips through JSON', () {
      final event = AnalyticsEvent(
        name: FunnelEvents.scanLookupFailed,
        sessionId: 'session-1234',
        occurredAt: DateTime.utc(2026, 7, 21, 10, 30),
        props: const {'reason': 'not_found'},
      );

      final restored = AnalyticsEvent.tryFromJson(event.toJson());

      expect(restored, isNotNull);
      expect(restored!.name, event.name);
      expect(restored.sessionId, event.sessionId);
      expect(restored.occurredAt, event.occurredAt);
      expect(restored.props, event.props);
    });

    test('rejects a payload with no usable timestamp', () {
      expect(
        AnalyticsEvent.tryFromJson(const {
          'event': 'app_opened',
          'session_id': 'session-1234',
        }),
        isNull,
      );
    });
  });
}
