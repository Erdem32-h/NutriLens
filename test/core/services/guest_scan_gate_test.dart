import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/services/guest_scan_gate.dart';

void main() {
  group('decideGuestScan', () {
    group('server answered — it is the authority', () {
      test('allows when the server says there is budget', () {
        expect(
          decideGuestScan(
            serverAnswered: true,
            serverAllowed: true,
            // Deliberately the worst-case local state: a server "yes"
            // must not be second-guessed by the cache.
            hasServerBaseline: false,
            localCanScan: false,
          ),
          GuestScanDecision.allowed,
        );
      });

      test('blocks with the paywall when the server says the budget is '
          'spent, even if the local counter disagrees', () {
        expect(
          decideGuestScan(
            serverAnswered: true,
            serverAllowed: false,
            hasServerBaseline: true,
            // A data clear leaves the local counter looking fresh; the
            // server is what remembers.
            localCanScan: true,
          ),
          GuestScanDecision.blockedByLimit,
        );
      });
    });

    group('server unreachable', () {
      test('REGRESSION: an install that never synced is blocked, not '
          'granted a fresh budget', () {
        // The hole: the old code fell straight through to the local
        // counter here, so clearing app data and turning the network off
        // handed out five more scans — repeatable indefinitely, which is
        // exactly what the device-hash check exists to prevent.
        expect(
          decideGuestScan(
            serverAnswered: false,
            serverAllowed: false,
            hasServerBaseline: false,
            localCanScan: true,
          ),
          GuestScanDecision.blockedByNetwork,
        );
      });

      test('a never-synced install is blocked by network, not by limit — '
          'the user is told to get online, not sold a registration', () {
        final decision = decideGuestScan(
          serverAnswered: false,
          serverAllowed: false,
          hasServerBaseline: false,
          localCanScan: false,
        );
        expect(decision, GuestScanDecision.blockedByNetwork);
        expect(decision, isNot(GuestScanDecision.blockedByLimit));
      });

      test('a previously synced install may still spend its local budget', () {
        // Genuine offline use stays working: the local counter is a cache of
        // the server floor once we have heard from it at least once.
        expect(
          decideGuestScan(
            serverAnswered: false,
            serverAllowed: false,
            hasServerBaseline: true,
            localCanScan: true,
          ),
          GuestScanDecision.allowed,
        );
      });

      test('a previously synced install with an exhausted local counter '
          'gets the paywall', () {
        expect(
          decideGuestScan(
            serverAnswered: false,
            serverAllowed: false,
            hasServerBaseline: true,
            localCanScan: false,
          ),
          GuestScanDecision.blockedByLimit,
        );
      });
    });

    test('serverAllowed is ignored when the server did not answer', () {
      // Guards the call site: `server?.allowed ?? false` must not be able to
      // smuggle a stale "true" past the offline checks.
      expect(
        decideGuestScan(
          serverAnswered: false,
          serverAllowed: true,
          hasServerBaseline: false,
          localCanScan: true,
        ),
        GuestScanDecision.blockedByNetwork,
      );
    });
  });
}
