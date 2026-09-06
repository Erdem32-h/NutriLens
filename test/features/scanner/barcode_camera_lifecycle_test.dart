import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/scanner/presentation/providers/barcode_camera_lifecycle.dart';

void main() {
  test('background stop waits for restart; next resume is not lost', () async {
    final lifecycle = BarcodeCameraLifecycle();
    final gate = Completer<void>();
    final events = <String>[];
    final first = lifecycle.run(() async {
      events.add('restart-start');
      await gate.future;
      events.add('restart-end');
    });
    final stop = lifecycle.run(() async {
      events.add('stop');
    });
    final resume = lifecycle.run(() async {
      events.add('resume');
    });
    await Future<void>.delayed(Duration.zero);
    expect(events, ['restart-start']);
    gate.complete();
    await Future.wait([first, stop, resume]);
    expect(events, ['restart-start', 'restart-end', 'stop', 'resume']);
  });

  test('failure does not poison later camera operations', () async {
    final lifecycle = BarcodeCameraLifecycle();
    await expectLater(
      lifecycle.run(() async {
        throw StateError('native failure');
      }),
      throwsStateError,
    );
    var ran = false;
    await lifecycle.run(() async {
      ran = true;
    });
    expect(ran, isTrue);
  });
}
