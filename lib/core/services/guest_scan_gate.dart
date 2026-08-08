/// What the guest scan gate decided.
enum GuestScanDecision {
  /// There is budget left — consume one and proceed.
  allowed,

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
/// [serverAllowed] is ignored unless [serverAnswered] is true.
GuestScanDecision decideGuestScan({
  required bool serverAnswered,
  required bool serverAllowed,
  required bool hasServerBaseline,
  required bool localCanScan,
}) {
  if (serverAnswered) {
    return serverAllowed
        ? GuestScanDecision.allowed
        : GuestScanDecision.blockedByLimit;
  }
  if (!hasServerBaseline) return GuestScanDecision.blockedByNetwork;
  return localCanScan
      ? GuestScanDecision.allowed
      : GuestScanDecision.blockedByLimit;
}
