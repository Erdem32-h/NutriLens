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
            goodwillAvailable: false,
            scanWorksOffline: false,
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
            goodwillAvailable: true,
            scanWorksOffline: true,
          ),
          GuestScanDecision.blockedByLimit,
        );
      });
    });

    group('server unreachable', () {
      test('REGRESSION: a never-synced install does not get a fresh five-scan '
          'budget from the local counter', () {
        // The hole: the old code fell straight through to the local counter
        // here, so clearing app data and turning the network off handed out
        // five more scans — repeatable indefinitely, which is exactly what
        // the device-hash check exists to prevent. At most it is now one
        // courtesy scan, and only on a path that works offline.
        final decision = decideGuestScan(
          serverAnswered: false,
          serverAllowed: false,
          hasServerBaseline: false,
          localCanScan: true,
          goodwillAvailable: true,
          scanWorksOffline: true,
        );
        expect(decision, GuestScanDecision.allowedOnGoodwill);
        expect(decision, isNot(GuestScanDecision.allowed));
      });

      test('the courtesy scan is one-off', () {
        expect(
          decideGuestScan(
            serverAnswered: false,
            serverAllowed: false,
            hasServerBaseline: false,
            localCanScan: true,
            goodwillAvailable: false,
            scanWorksOffline: true,
          ),
          GuestScanDecision.blockedByNetwork,
        );
      });

      test('the courtesy scan is not spent on the AI path, which cannot '
          'succeed offline anyway', () {
        expect(
          decideGuestScan(
            serverAnswered: false,
            serverAllowed: false,
            hasServerBaseline: false,
            localCanScan: true,
            goodwillAvailable: true,
            scanWorksOffline: false,
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
          goodwillAvailable: false,
          scanWorksOffline: true,
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
            goodwillAvailable: false,
            scanWorksOffline: true,
          ),
          GuestScanDecision.allowed,
        );
      });

      test('a synced install spends its real budget, never the courtesy '
          'scan', () {
        // Courtesy must not top up an exhausted budget — otherwise every
        // guest gets six scans and the fifth-scan nudge lands in the wrong
        // place.
        expect(
          decideGuestScan(
            serverAnswered: false,
            serverAllowed: false,
            hasServerBaseline: true,
            localCanScan: false,
            goodwillAvailable: true,
            scanWorksOffline: true,
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
          goodwillAvailable: false,
          scanWorksOffline: false,
        ),
        GuestScanDecision.blockedByNetwork,
      );
    });
  });
}
