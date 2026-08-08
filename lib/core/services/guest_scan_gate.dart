/// What the guest scan gate decided.
enum GuestScanDecision {
  /// There is budget left — consume one and proceed.
  allowed,

  /// Allowed on the one-off offline courtesy scan. The caller must record it
  /// as spent, or it stops being one-off.
  allowedOnGoodwill,

  /// The lifetime budget is genuinely spent → show the register upsell.
  blockedByLimit,

  /// The server could not be reached AND this install has never heard from
  /// it, so there is no trustworthy count to spend from. Not a paywall —
  /// the user is told to get online.
  blockedByNetwork,
}

/// Decides whether a guest may consume a scan.
///
/// The local counter is a *cache of the server's device-keyed count*, never an
/// independent source of truth. That distinction is the whole point: a guest
/// who clears app data gets a local counter of zero, which is byte-identical
/// to a genuine first launch. The server (keyed by device hash, which survives
/// a data clear) is what tells the two apart.
///
/// So when the server is unreachable, spending from the local counter is only
/// legitimate if this install has synced with it at least once — otherwise the
/// app hands a fresh five-scan budget to anyone who scans with the network
/// off, repeatable forever, which is exactly the abuse the device-hash check
/// was built to stop. Fail closed there, the way the authenticated path does.
///
/// A never-synced install still gets ONE courtesy scan, but only when the
/// scan can actually succeed offline ([scanWorksOffline] — the barcode path,
/// which can answer from the on-device product data). Meal analysis is a
/// server call that cannot complete without a network, so spending the
/// courtesy there would burn it and still show the user an error.
///
/// That restriction is also what keeps the courtesy from re-opening the hole
/// it sits next to. [goodwillAvailable] lives in app storage, so a data clear
/// refills it — unavoidable, since the durable store is the very server we
/// could not reach. What stops it from mattering is that each clear-and-go-
/// offline cycle now buys exactly one lookup against product data already on
/// the device: no server call, no model spend. The loop is not slowed down,
/// it is made worthless.
///
/// [serverAllowed] is ignored unless [serverAnswered] is true.
GuestScanDecision decideGuestScan({
  required bool serverAnswered,
  required bool serverAllowed,
  required bool hasServerBaseline,
  required bool localCanScan,
  required bool goodwillAvailable,
  required bool scanWorksOffline,
}) {
  if (serverAnswered) {
    return serverAllowed
        ? GuestScanDecision.allowed
        : GuestScanDecision.blockedByLimit;
  }
  if (hasServerBaseline) {
    return localCanScan
        ? GuestScanDecision.allowed
        : GuestScanDecision.blockedByLimit;
  }
  if (scanWorksOffline && goodwillAvailable) {
    return GuestScanDecision.allowedOnGoodwill;
  }
  return GuestScanDecision.blockedByNetwork;
}
