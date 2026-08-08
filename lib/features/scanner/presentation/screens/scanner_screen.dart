import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/barcode_validator.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/providers/monetization_provider.dart';
import '../../../../core/services/guest_scan_counter.dart';
import '../../../../core/services/scan_limit_service.dart';
import '../../../../core/session/app_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/scanner_mode_provider.dart';
import '../widgets/scanner_overlay.dart';
import '../../../auth/presentation/widgets/guest_register_sheet.dart';
import '../../../premium/presentation/widgets/scan_limit_sheet.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with WidgetsBindingObserver {
  // Manual lifecycle: we start/stop the camera in response to app state,
  // tab-mode changes, and navigation. `autoStart: false` + stream
  // subscription is the canonical v7 pattern (see mobile_scanner README
  // "Advanced > Lifecycle changes").
  //
  // `DetectionSpeed.noDuplicates` dramatically cuts wasted callbacks vs
  // `.normal`: the camera feed still runs at native frame rate but the
  // decoder only fires when the barcode value changes. Combined with the
  // format allow-list below this reduces CPU/heat noticeably — the
  // earlier `.normal` setting processed every frame even when the user
  // was just pointing at the package.
  //
  // `formats` restriction: product barcodes on food packaging are almost
  // exclusively EAN/UPC, plus QR for the occasional smart-label. Not
  // accepting PDF417/Aztec/Data Matrix/etc. saves the decoder a bunch of
  // per-frame work.
  final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.qrCode,
    ],
  );

  StreamSubscription<BarcodeCapture>? _subscription;

  DateTime? _lastScanTime;
  String? _lastBarcode;
  bool _isNavigating = false;

  /// Guards [_restartBarcodeScanner] against overlapping restarts (e.g. a
  /// route-return and an app-resume firing back to back).
  bool _restarting = false;

  /// 0 = Barcode mode, 1 = AI Analysis mode.
  /// Default = AI analysis: most users open the scanner to log a meal,
  /// barcode scanning is the secondary flow.
  int _scanMode = 1;

  /// Native camera handle used in AI mode for one-tap photo capture.
  /// mobile_scanner can't grab stills, so we swap to this controller
  /// whenever the user is in AI mode. Only one of the two cameras is
  /// alive at any moment — see [_setScanMode] for the hand-off.
  CameraController? _aiCamera;
  bool _capturing = false;

  /// Set once [_initAiCamera] has exhausted its retries; drives the AI-mode
  /// error/retry view. Null while initialising and once the preview is live.
  Object? _aiCameraError;

  /// Bumped by every [_disposeAiCamera] so an in-flight [_initAiCamera] can
  /// tell it has been superseded (backgrounding, mode switch, screen pop) and
  /// must drop the controller it just built instead of leaking a camera that
  /// nobody will dispose.
  int _aiCameraGeneration = 0;

  /// True while an init ladder is running. Two overlapping ladders are the
  /// root cause of the field's most common camera failure: the OS permission
  /// sheet puts the app in `inactive`, dismissing it fires `resumed`, and the
  /// resulting second `initialize()` hits the plugin's `ongoing` guard and
  /// throws `CameraPermissionsRequestOngoing` while the *first* call is still
  /// legitimately waiting for the user's answer.
  bool _aiCameraStarting = false;

  /// A start was asked for while a ladder was already running. The running
  /// ladder re-runs itself once it unwinds, so a superseded attempt never
  /// leaves the preview permanently dark.
  bool _aiCameraRestartPending = false;

  /// Sticky once the OS has refused camera access. Retrying cannot change the
  /// answer, and without this the screen re-enters the ladder ~10×/second:
  /// while the preview is dark Android oscillates inactive↔resumed, and every
  /// resume asks for the camera again. Cleared by an explicit retry tap or by
  /// a real background round trip (the user going to Settings and back) — see
  /// [_lastLifecycleState].
  bool _aiCameraDenied = false;

  /// Latched when the app actually leaves the foreground (`paused`, `hidden`
  /// or `detached`), cleared on the next `resumed`. A latch rather than a
  /// "previous state" comparison because Android does not hand us
  /// `paused` → `resumed`: it interleaves `inactive`, so the state right
  /// before a resume is always `inactive` and the comparison never fired.
  /// `inactive` on its own must not count — a dark preview makes the OS
  /// oscillate inactive↔resumed, and only a real background trip can mean
  /// "the user went to Settings and may have granted the permission".
  bool _wentToBackground = false;

  // Per-visit funnel flags. Split into two so a camera that comes up *after*
  // a reported failure (user granted at the OS prompt, we recovered on
  // resume) still records `scan_camera_ready`. With the previous single flag
  // the first failure permanently masked the recovery — which is exactly the
  // outcome the retry fix is meant to produce, and would have made the fix
  // look like it did nothing.
  bool _cameraReadyTracked = false;
  bool _cameraFailureTracked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Open in whichever mode the caller asked for, so the screen the user
    // came from decides what the camera is pointed at: the meal diary wants
    // AI analysis, the product history wants the barcode reader. Landing in
    // the wrong mode costs a tap and a full camera hand-off.
    final requestedMode = ref.read(pendingScannerModeProvider);
    if (requestedMode != null) {
      _scanMode = requestedMode;
      // Clear immediately — this is a one-shot request, and leaving it set
      // would pin every later visit to the same mode.
      Future.microtask(
        () => ref.read(pendingScannerModeProvider.notifier).state = null,
      );
    }
    // Initialise the camera package that matches the resolved mode. This is
    // also what triggers the OS camera-permission prompt, which is why the
    // app no longer lands here straight from onboarding — the prompt should
    // follow a deliberate "scan" tap, not greet a first-time visitor.
    ref
        .read(analyticsServiceProvider)
        .track(
          FunnelEvents.scannerOpened,
          props: {
            'mode': _scanMode == 1 ? 'food' : 'barcode',
            // False means the user arrived via the nav bar rather than a
            // scan CTA on a specific screen — the CTAs were added to fix
            // activation, so their share is the thing to watch.
            'requested_mode': requestedMode != null,
          },
        );
    if (_scanMode == 1) {
      _initAiCamera();
    } else {
      _startScanning();
    }
    // Reconcile the guest badge/counter with the server's device-keyed total
    // so a cache/data clear that reset the local counter to 0 gets corrected.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reconcileGuestBudget(),
    );
  }

  /// Pulls the authoritative guest scan count from the server (device-hash
  /// keyed) and raises the local fallback counter to match. No-op for
  /// non-guests or when offline.
  Future<void> _reconcileGuestBudget() async {
    if (!ref.read(isGuestProvider)) return;
    final remaining = await ref
        .read(guestScanLimitServiceProvider)
        .peekRemaining();
    if (remaining == null || !mounted) return;
    await ref
        .read(guestScanCounterProvider.notifier)
        .syncFromServer(GuestScanCounter.lifetimeLimit - remaining);
  }

  /// Server-authoritative guest scan gate with an offline local fallback.
  /// Returns true if the scan may proceed (and consumes one); on hard-block
  /// it shows the register sheet (and navigates to /register if chosen).
  Future<bool> _consumeGuestScan() async {
    final server = await ref
        .read(guestScanLimitServiceProvider)
        .checkAndIncrement();
    final counter = ref.read(guestScanCounterProvider.notifier);

    bool allowed;
    int remaining;
    if (server != null) {
      // Server already incremented; mirror its count into the local fallback.
      await counter.syncFromServer(
        GuestScanCounter.lifetimeLimit - server.remaining,
      );
      allowed = server.allowed;
      remaining = server.remaining;
    } else {
      // Offline: fall back to the local counter.
      allowed = counter.canScan;
      remaining = allowed
          ? GuestScanCounter.lifetimeLimit - (await counter.increment())
          : 0;
    }

    if (!allowed) {
      if (!mounted) return false;
      // Guest hit the lifetime scan cap → the register-upsell sheet is their
      // paywall. Tracked here (shared by barcode + food paths) so "blocked by
      // limit" stops looking like a plain drop-off.
      ref
          .read(analyticsServiceProvider)
          .track(
            FunnelEvents.paywallShown,
            props: {'trigger': 'scan_limit', 'guest': true},
          );
      final wantsRegister = await GuestRegisterSheet.showScanLimitReached(
        context,
      );
      if (mounted && wantsRegister) context.go('/register');
      return false;
    }

    if (remaining == 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.guestLastFreeScan),
          duration: const Duration(seconds: 4),
        ),
      );
    }
    return true;
  }

  /// Returns true when the scan may proceed after a limit check.
  Future<bool> _handleAuthenticatedScanLimit(ScanCheckResult scanResult) async {
    if (scanResult.allowed) return true;
    if (!mounted) return false;

    if (scanResult.reason == 'network_error') {
      // The limit check failing blocks the scan outright, so it belongs in the
      // funnel next to the other refusals — otherwise it is indistinguishable
      // from "user opened the scanner and lost interest". `detail` carries the
      // real cause (expired JWT vs actual transport failure).
      ref
          .read(analyticsServiceProvider)
          .track(
            FunnelEvents.scanLookupFailed,
            props: {
              'reason': 'limit_network',
              if (scanResult.detail != null) 'detail': scanResult.detail,
            },
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.scanLimitNetworkError),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return false;
    }

    // Real paywall (out of free scans, not a transient network error, which
    // returned above). Shared by barcode + food paths.
    ref
        .read(analyticsServiceProvider)
        .track(
          FunnelEvents.paywallShown,
          props: {'trigger': 'scan_limit', 'guest': false},
        );
    final granted = await ScanLimitSheet.show(context);
    return granted;
  }

  @override
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    _subscription = null;
    final ai = _aiCamera;
    _aiCamera = null;
    super.dispose();
    // try/catch: a HAL-cycle ([_restartBarcodeScanner]) may be mid-flight
    // when the screen is torn down, so guard against disposing twice.
    if (ai != null) {
      try {
        await ai.dispose();
      } catch (_) {}
    }
    try {
      await _controller.dispose();
    } catch (_) {}
  }

  /// How long we keep waiting while the OS permission sheet is on screen.
  /// The plugin reports `CameraPermissionsRequestOngoing` for as long as that
  /// sheet is up, and a person needs seconds to read and tap it — the old
  /// ladder (3 tries, 350ms apart) gave up after 700ms and left a
  /// permanently black preview that only an app restart cleared.
  static const _permissionWaitBudget = Duration(seconds: 25);
  static const _permissionPollDelay = Duration(milliseconds: 400);

  /// Backoff for ordinary transient failures — the camera is typically still
  /// held by a client that is mid-release.
  static const _transientRetryDelay = Duration(milliseconds: 350);
  static const _transientRetryLimit = 3;

  /// Boot the native camera for AI mode. Picks the back camera, lowest
  /// reasonable resolution that still works for meal analysis. Audio
  /// is disabled — we never record video here, just take stills.
  ///
  /// Retries are split by failure kind, because they need very different
  /// budgets:
  ///
  ///  * `CameraPermissionsRequestOngoing` — either the OS sheet is up and the
  ///    user hasn't answered yet, or a second init raced the first. Poll until
  ///    [_permissionWaitBudget]; the first call resolves as soon as the user
  ///    taps and the next poll then succeeds.
  ///  * A hard denial — retrying cannot help, so stop immediately and show the
  ///    "enable camera access" view rather than spinning behind a black rect.
  ///  * Anything else (camera busy) — the original short backoff still applies.
  Future<void> _initAiCamera() async {
    if (_aiCamera != null) return; // already alive
    if (_aiCameraDenied) return; // see [_aiCameraDenied]
    if (_aiCameraStarting) {
      // Never run two ladders at once — see [_aiCameraStarting]. Remember the
      // request so the running ladder re-runs if it turns out to be stale.
      _aiCameraRestartPending = true;
      return;
    }
    _aiCameraStarting = true;

    // `_restartBarcodeScanner` also calls this, in barcode mode, purely to
    // cycle CameraX. That path is awaited inline, so it must stay a single
    // fast attempt — a retry ladder there would stall the barcode restart —
    // and it is plumbing, not a step the user took, so it reports nothing.
    final forFoodMode = _scanMode == 1;
    final generation = _aiCameraGeneration;
    final permissionDeadline = DateTime.now().add(_permissionWaitBudget);
    var transientAttempt = 0;

    try {
      while (true) {
        if (!mounted || generation != _aiCameraGeneration) return;
        // Held outside the try so the `finally` can drop a controller we
        // never took ownership of. The permission poll can now run dozens of
        // times, so a controller leaked per failed `initialize()` would add
        // up instead of being a one-off.
        CameraController? pending;
        try {
          final cameras = await availableCameras();
          if (cameras.isEmpty) {
            if (forFoodMode) {
              _failAiCamera(
                CameraException('cameraNotFound', 'No cameras reported'),
              );
            }
            return;
          }
          final back = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
            orElse: () => cameras.first,
          );
          pending = CameraController(
            back,
            ResolutionPreset.high, // ~1280x720 — plenty for Claude vision
            enableAudio: false,
            imageFormatGroup: ImageFormatGroup.jpeg,
          );
          await pending.initialize();
          // A teardown may have landed while `initialize()` was in flight —
          // leaving `pending` set hands it to the finally below.
          if (!mounted || generation != _aiCameraGeneration) return;
          _aiCamera = pending;
          pending = null; // ownership transferred to _aiCamera
          if (forFoodMode) _trackCameraOutcome(ready: true);
          setState(() => _aiCameraError = null);
          return;
        } catch (e) {
          debugPrint('[Scanner] AI camera init failed: $e');
          if (!mounted) return;
          // Barcode-mode HAL cycle: one shot, no retry, no error UI.
          if (!forFoodMode) return;

          // Checked before the generation guard on purpose: a refusal is the
          // OS's answer to this app, not to this attempt, so a newer
          // generation would only be told the same thing. Bailing here on a
          // stale generation is what left the preview stuck on a spinner
          // while lifecycle churn bumped the counter ~10×/second.
          if (e is CameraException && _isHardCameraDenial(e)) {
            _aiCameraDenied = true;
            _failAiCamera(e);
            return;
          }

          if (generation != _aiCameraGeneration) return;

          final isPermissionWait =
              e is CameraException &&
              e.code == 'CameraPermissionsRequestOngoing';
          if (isPermissionWait) {
            if (DateTime.now().isAfter(permissionDeadline)) {
              _failAiCamera(e);
              return;
            }
            await Future<void>.delayed(_permissionPollDelay);
            continue;
          }

          transientAttempt++;
          if (transientAttempt >= _transientRetryLimit) {
            _failAiCamera(e);
            return;
          }
          await Future<void>.delayed(_transientRetryDelay);
        } finally {
          if (pending != null) {
            try {
              await pending.dispose();
            } catch (_) {}
          }
        }
      }
    } finally {
      _aiCameraStarting = false;
      if (_aiCameraRestartPending) {
        _aiCameraRestartPending = false;
        // Only food mode auto-restarts: in barcode mode the only caller is
        // the HAL cycle, which drives its own teardown straight after.
        if (mounted && _scanMode == 1 && _aiCamera == null) {
          unawaited(_initAiCamera());
        }
      }
    }
  }

  /// Retrying cannot help once the user (or an MDM policy) has said no, so
  /// these codes go straight to the settings prompt.
  static bool _isHardCameraDenial(CameraException e) => switch (e.code) {
    'CameraAccessDenied' ||
    'CameraAccessDeniedWithoutPrompt' ||
    'CameraAccessRestricted' ||
    'cameraPermission' => true,
    _ => false,
  };

  /// Give up on the AI camera: record it once for the funnel and surface a
  /// retry view. Without this the AI branch rendered `SizedBox.shrink()` — a
  /// black rectangle with no message and nothing to tap.
  void _failAiCamera(Object error) {
    if (!mounted) return;
    _trackCameraOutcome(ready: false, error: error);
    setState(() => _aiCameraError = error);
  }

  /// Clear a previous give-up and try again. Used by the retry view and by a
  /// return from the background — the user may have just flipped the
  /// permission in Settings.
  void _retryAiCamera() {
    if (!mounted) return;
    _aiCameraDenied = false;
    setState(() => _aiCameraError = null);
    unawaited(_initAiCamera());
  }

  Future<void> _disposeAiCamera() async {
    final c = _aiCamera;
    _aiCamera = null;
    _aiCameraGeneration++;
    if (c != null) {
      try {
        await c.dispose();
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  /// Subscribe to the barcode stream and start the camera.
  ///
  /// Safe to call multiple times: `_subscription` is guarded, and
  /// `controller.start()` is a no-op when already running.
  void _startScanning() {
    _subscription ??= _controller.barcodes.listen(_handleBarcode);
    unawaited(
      _controller
          .start()
          .then((_) => _trackCameraOutcome(ready: true))
          .catchError(
            (Object error) => _trackCameraOutcome(ready: false, error: error),
          ),
    );
  }

  /// Records whether the camera actually came up, once per visit to this
  /// screen.
  ///
  /// This is the step the old data could never see: a denied permission, a
  /// camera held by another app, and a user who simply backed out all look
  /// like "opened the scanner, never scanned" from `scan_history` alone.
  /// [_startScanning] runs again on every resume, so the flag keeps a single
  /// visit from reporting the same outcome repeatedly.
  void _trackCameraOutcome({required bool ready, Object? error}) {
    if (!mounted) return;
    final mode = _scanMode == 1 ? 'food' : 'barcode';
    final analytics = ref.read(analyticsServiceProvider);
    if (ready) {
      if (_cameraReadyTracked) return;
      _cameraReadyTracked = true;
      analytics.track(FunnelEvents.scanCameraReady, props: {'mode': mode});
      return;
    }
    if (_cameraFailureTracked) return;
    _cameraFailureTracked = true;
    analytics.track(
      FunnelEvents.scanCameraFailed,
      props: {'mode': mode, 'reason': _cameraFailureReason(error)},
    );
  }

  static String _cameraFailureReason(Object? error) {
    if (error is MobileScannerException) {
      return switch (error.errorCode) {
        MobileScannerErrorCode.permissionDenied => 'permission_denied',
        MobileScannerErrorCode.unsupported => 'unsupported',
        _ => 'error',
      };
    }
    // The AI (food) path uses the `camera` plugin, whose CameraException
    // carries a machine `code` — the whole reason every one of the field
    // failures logged a useless generic 'error'. Normalise the permission
    // codes, pass the rest through verbatim so we finally see what breaks
    // (e.g. 'CameraAccessRestricted', 'cameraPermission', a platform code).
    if (error is CameraException) {
      return switch (error.code) {
        'CameraAccessDenied' ||
        'CameraAccessDeniedWithoutPrompt' ||
        'cameraPermission' ||
        'AVFoundationErrorDomain' => 'permission_denied',
        'CameraAccessRestricted' => 'restricted',
        _ => 'cam_${error.code}',
      };
    }
    return 'error';
  }

  /// Tear down the barcode subscription and stop the camera.
  ///
  /// Releases the camera while the scanner is covered (product detail) or
  /// the app is backgrounded. Pair the *return* with [_restartBarcodeScanner]
  /// rather than a bare [_startScanning]: re-acquiring the camera on the
  /// same controller after a stop() is unreliable on many devices.
  Future<void> _stopScanning() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller.stop();
  }

  /// Revive the barcode preview when returning to the scanner (or resuming
  /// the app) by forcing a full camera HAL reset.
  ///
  /// Root cause (reproduced on Samsung One UI): mobile_scanner and the
  /// `camera` plugin both bind to CameraX's singleton ProcessCameraProvider.
  /// A mobile_scanner-only stop()→start() — even with a brand-new controller
  /// — does NOT make CameraX rebind, so the preview comes back black. The
  /// ONLY thing that revives it is the `camera` plugin opening and closing
  /// the camera, which forces CameraX to unbind/rebind the session. That's
  /// exactly why the user's manual workaround (toggle to AI mode and back)
  /// works. This replicates that toggle in code: stop mobile_scanner → boot
  /// + dispose the `camera` plugin (the HAL cycle) → start mobile_scanner.
  Future<void> _restartBarcodeScanner() async {
    if (_restarting || !mounted) return;
    _restarting = true;
    try {
      await _subscription?.cancel();
      _subscription = null;
      await _controller.stop();

      // Cycle the `camera` plugin to force CameraX to rebind — same effect
      // as the AI↔barcode toggle. _initAiCamera/_disposeAiCamera are the
      // exact calls that toggle makes, so behaviour is identical.
      await _initAiCamera();
      await _disposeAiCamera();
      if (!mounted) return;

      _subscription = _controller.barcodes.listen(_handleBarcode);
      await _controller.start();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[Scanner] barcode restart failed: $e');
    } finally {
      _restarting = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permission dialogs trigger lifecycle changes before the controller
    // has a real camera handle — guard against that per mobile_scanner
    // docs.
    //
    // Barcode mode only: `hasCameraPermission` is `isInitialized && not
    // denied`, so it reads false for the whole time we're in AI mode (that
    // path never starts mobile_scanner — the `camera` plugin owns the
    // hardware). Applying the guard to the entire handler meant
    // backgrounding while in AI mode never released that camera; its next
    // ImageReader frame then reached an already-detached engine and killed
    // the process with "Cannot execute operation because FlutterJNI is not
    // attached to native".
    if (_scanMode == 0 && !_controller.value.hasCameraPermission) return;

    switch (state) {
      case AppLifecycleState.resumed:
        final cameBackFromBackground = _wentToBackground;
        _wentToBackground = false;
        if (!_isNavigating) {
          if (_scanMode == 0) {
            // Background did a full stop(); rebuild a fresh controller
            // rather than restart this one (same unreliable round-trip).
            unawaited(_restartBarcodeScanner());
          } else if (_aiCameraDenied && cameBackFromBackground) {
            // Only a genuine background trip clears a denial — the user may
            // have just granted the permission in Settings. Plain `inactive`
            // churn must not, or we are back to hammering the OS for an
            // answer it already gave.
            _retryAiCamera();
          } else {
            _initAiCamera();
          }
        }
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // Only these three mean the app really left the foreground.
        _wentToBackground = true;
        continue release;
      release:
      case AppLifecycleState.inactive:
        if (_scanMode == 0) {
          unawaited(_stopScanning());
        } else {
          _disposeAiCamera();
        }
        break;
    }
  }

  Future<void> _processBarcode(String value) async {
    if (_isNavigating) return;

    // Reject URLs and non-barcode values that would break routing.
    // Logic lives in `BarcodeValidator` so it can be unit-tested.
    if (!BarcodeValidator.isValidBarcode(value)) {
      debugPrint('[Scanner] rejected — not a valid barcode');
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.invalidBarcode),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    _isNavigating = true;

    final analytics = ref.read(analyticsServiceProvider);
    // No barcode value in the props: joined to a device hash it would turn
    // an anonymous funnel table into a per-device consumption profile, and
    // the funnel only needs to know that a scan resolved.
    analytics.track(
      FunnelEvents.scanBarcodeDetected,
      props: {'mode': 'barcode', 'guest': ref.read(isGuestProvider)},
    );

    // Guest mode has its own lifetime cap (5 scans), now enforced
    // server-side by device hash (survives a cache/data clear) with a local
    // counter fallback when offline. Authenticated users go through the
    // per-user Supabase RPC instead.
    if (ref.read(isGuestProvider)) {
      if (!await _consumeGuestScan()) {
        analytics.track(
          FunnelEvents.scanLookupFailed,
          props: {'reason': 'guest_limit'},
        );
        if (mounted) setState(() => _isNavigating = false);
        return;
      }
    } else {
      // Check scan limit
      final scanLimitService = ref.read(scanLimitServiceProvider);
      final scanResult = await scanLimitService.checkAndIncrement(
        localPremium: ref.read(isPremiumProvider),
      );
      if (!scanResult.allowed) {
        final granted = await _handleAuthenticatedScanLimit(scanResult);
        if (!granted) {
          analytics.track(
            FunnelEvents.scanLookupFailed,
            props: {'reason': 'scan_limit'},
          );
          if (mounted) setState(() => _isNavigating = false);
          return;
        }
      }
    }

    if (!mounted) return;

    HapticFeedback.mediumImpact();

    debugPrint('[Scanner] navigating to /product/$value');
    // Release the camera while the product detail covers the scanner (the
    // scanner route stays mounted underneath). On return we rebuild the
    // controller from scratch instead of restarting this one — a
    // same-instance stop()→start() leaves the preview frozen/black or throws
    // on many devices ("won't scan a second time until app restart").
    //
    // Awaited (not fire-and-forget): pushing the new route while the native
    // camera view is still mid-teardown races the widget tree unmount and
    // trips a framework assertion ('_dependents.isEmpty' in framework.dart) —
    // reproduced by scanning/entering a barcode and immediately crashing on
    // the product route.
    await _stopScanning();
    if (!mounted) return;
    context.push('/product/$value').then((_) async {
      if (!mounted) return;
      _isNavigating = false;
      if (_scanMode == 0) {
        await _restartBarcodeScanner();
      }
    });
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isNavigating || _scanMode != 0) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final value = barcode.rawValue;
    if (value == null || value.isEmpty) return;

    final now = DateTime.now();
    if (_lastBarcode == value && _lastScanTime != null) {
      final elapsed = now.difference(_lastScanTime!).inMilliseconds;
      if (elapsed < AppConstants.scanDebounceMs) return;
    }

    _lastBarcode = value;
    _lastScanTime = now;

    debugPrint('[Scanner] scanned: "$value" (format: ${barcode.format})');

    await _processBarcode(value);
  }

  Future<void> _showManualBarcodeDialog() async {
    final barcode = await showDialog<String>(
      context: context,
      builder: (_) => const _ManualBarcodeDialog(),
    );

    if (barcode != null && barcode.isNotEmpty && mounted) {
      await _processBarcode(barcode);
    }
  }

  Future<void> _captureForAi() async {
    if (_capturing) return;
    final camera = _aiCamera;
    if (camera == null || !camera.value.isInitialized) return;
    setState(() => _capturing = true);
    try {
      // One-tap shutter: grab the current frame directly from the
      // live viewfinder. No second camera UI, no confirmation screen.
      final xFile = await camera.takePicture();
      if (!mounted) return;
      HapticFeedback.lightImpact();
      final Uint8List imageBytes = await xFile.readAsBytes();

      if (!mounted) return;

      // The shutter produced a frame. Fire before the scan-limit gate so a
      // device that tapped-but-was-blocked is separable from one that never
      // tapped — both otherwise stall at `scan_camera_ready`.
      ref
          .read(analyticsServiceProvider)
          .track(FunnelEvents.scanPhotoCaptured, props: {'mode': 'food'});

      // Guest mode: same server-authoritative gate as the barcode path.
      if (ref.read(isGuestProvider)) {
        if (!await _consumeGuestScan()) return;
      } else {
        // Check scan limit
        final scanLimitService = ref.read(scanLimitServiceProvider);
        final scanResult = await scanLimitService.checkAndIncrement(
          localPremium: ref.read(isPremiumProvider),
        );
        if (!scanResult.allowed) {
          if (!await _handleAuthenticatedScanLimit(scanResult)) return;
        }
      }

      if (!mounted) return;
      await context.push('/food-result', extra: imageBytes);
      // Returned from food-result — the AI camera survives across
      // the push/pop, so nothing to restart. If user backgrounded
      // the app while away didChangeAppLifecycleState reinitialises.
      //
      // Packaged-product detection: food-result may ask us to switch to
      // barcode mode ("Bu paketli bir ürün, barkodunu okut"). Honour that
      // one-shot request now that we're back on the scanner.
      if (!mounted) return;
      final pendingMode = ref.read(pendingScannerModeProvider);
      if (pendingMode != null) {
        ref.read(pendingScannerModeProvider.notifier).state = null;
        if (pendingMode != _scanMode) await _setScanMode(pendingMode);
      }
    } catch (e) {
      debugPrint('[Scanner] AI capture error: $e');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  /// Toggle scanning mode and swap the underlying camera package.
  ///
  /// Barcode (0) uses mobile_scanner — it's tuned for fast format
  /// detection and feeds a stream of decoded values.
  /// AI (1) uses the `camera` package — it's the only way to grab a
  /// still in one tap. iOS rejects two simultaneous camera clients,
  /// so we always tear the previous one down before booting the next.
  Future<void> _setScanMode(int mode) async {
    if (_scanMode == mode) return;
    setState(() => _scanMode = mode);
    if (mode == 1) {
      _stopScanning();
      await _initAiCamera();
    } else {
      await _disposeAiCamera();
      _startScanning();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview. Two implementations, swapped by mode:
          //   - barcode: MobileScanner, decoded via `controller.barcodes`
          //     stream (no onDetect — canonical v7 manual lifecycle).
          //   - AI: `camera` package preview, lets _captureForAi grab
          //     a still in one tap. While the controller is still coming
          //     up we show a spinner, and once it has given up a retry
          //     view — this branch used to render `SizedBox.shrink()` for
          //     both, i.e. an unexplained black screen with nothing to tap.
          if (_scanMode == 0)
            MobileScanner(
              controller: _controller,
              errorBuilder: (context, error) {
                return _buildCameraError(context, error);
              },
            )
          else if (_aiCamera?.value.isInitialized ?? false)
            Positioned.fill(child: CameraPreview(_aiCamera!))
          else if (_aiCameraError != null)
            Positioned.fill(child: _buildAiCameraError(context))
          else
            const Positioned.fill(
              child: Center(
                child: CircularProgressIndicator(color: Colors.white54),
              ),
            ),

          // Barcode mode: overlay + hint
          if (_scanMode == 0) ...[
            const ScannerOverlay(),
            const ScannerOverlayBorder(),
            Positioned(
              bottom: 130,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(
                    l10n.alignBarcodeInFrame,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],

          // AI mode: hint + capture button. Suppressed once the camera has
          // given up — "frame the food" and a shutter button on top of a
          // "camera access denied" panel is both unreadable and a lie.
          if (_scanMode == 1 && _aiCameraError == null) ...[
            // Semi-transparent overlay
            Container(color: Colors.black.withValues(alpha: 0.3)),
            // Hint text
            Positioned(
              top: MediaQuery.of(context).size.height * 0.35,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(
                    l10n.aiAnalysisHint,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            // Capture button
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _captureForAi,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: colors.primaryGradient,
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Top bar with logo + flash + mode tabs
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                gradient: colors.primaryGradient,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.eco_rounded,
                                color: Colors.black,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'NutriLens',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Flash & Manual entry buttons — barcode mode only.
                      if (_scanMode == 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: _showManualBarcodeDialog,
                              child: Container(
                                // 14 vertical (not 8) so the pill clears
                                // the 48dp minimum touch target with a
                                // 20dp icon; at 8 it was only 36dp tall.
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(50),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.keyboard_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ValueListenableBuilder<MobileScannerState>(
                              valueListenable: _controller,
                              builder: (context, state, child) {
                                final isOn = state.torchState == TorchState.on;
                                return GestureDetector(
                                  // Guard the brief windows where the controller
                                  // isn't initialized yet (initial boot, and the
                                  // HAL-cycle restart in _restartBarcodeScanner) —
                                  // toggleTorch() throws otherwise.
                                  onTap: state.isInitialized
                                      ? () => _controller.toggleTorch()
                                      : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isOn
                                          ? colors.primary.withValues(
                                              alpha: 0.25,
                                            )
                                          : Colors.black.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(50),
                                      border: Border.all(
                                        color: isOn
                                            ? colors.primary.withValues(
                                                alpha: 0.6,
                                              )
                                            : Colors.white.withValues(
                                                alpha: 0.15,
                                              ),
                                      ),
                                    ),
                                    child: Icon(
                                      isOn
                                          ? Icons.flash_on_rounded
                                          : Icons.flash_off_rounded,
                                      color: isOn
                                          ? colors.primary
                                          : Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // Mode tab bar
                const SizedBox(height: 8),
                _buildModeTabBar(l10n, colors),

                // Guest budget badge — remaining lifetime scan quota, so
                // the limit is visible before it's hit. Hidden once
                // registered (isGuest=false).
                //
                // Laid out here rather than absolutely positioned in the
                // root Stack: it used to be Positioned(top, right) and
                // collided with the flash/manual-entry buttons, which
                // occupy the same corner in barcode mode. The three pills
                // together are wider than a 360dp screen, so they cannot
                // share a row — giving the badge its own line is what
                // actually removes the overlap rather than relocating it.
                if (ref.watch(isGuestProvider)) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _GuestScanBadge(
                        remaining:
                            ((GuestScanCounter.lifetimeLimit -
                                        ref.watch(guestScanCounterProvider))
                                    .clamp(0, GuestScanCounter.lifetimeLimit))
                                .toInt(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabBar(dynamic l10n, AppColorsExtension colors) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 48),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          _buildModeTab(
            label: l10n.tabBarcode,
            icon: Icons.qr_code_scanner_rounded,
            isSelected: _scanMode == 0,
            colors: colors,
            onTap: () => _setScanMode(0),
          ),
          _buildModeTab(
            label: l10n.tabAiAnalysis,
            icon: Icons.auto_awesome_rounded,
            isSelected: _scanMode == 1,
            colors: colors,
            onTap: () => _setScanMode(1),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required AppColorsExtension colors,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(50),
            border: isSelected
                ? Border.all(color: colors.primary.withValues(alpha: 0.4))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? colors.primary : Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? colors.primary : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraError(BuildContext context, MobileScannerException error) {
    // Only an actual permission denial should send the user to settings.
    // Other errors (e.g. the camera failed to re-acquire after returning to
    // the scanner) are transient — show a tappable retry that rebuilds the
    // controller instead of the misleading "permission denied" message.
    return _buildCameraErrorView(
      context,
      isPermissionDenied:
          error.errorCode == MobileScannerErrorCode.permissionDenied,
      onRetry: () => unawaited(_restartBarcodeScanner()),
    );
  }

  /// AI-mode counterpart of [_buildCameraError]. Different plugin, different
  /// exception type and a different recovery call, but the user sees exactly
  /// the same thing. Returning from Settings also self-heals without a tap:
  /// `resumed` re-runs [_initAiCamera] while `_aiCamera` is still null.
  Widget _buildAiCameraError(BuildContext context) {
    final error = _aiCameraError;
    return _buildCameraErrorView(
      context,
      isPermissionDenied: error is CameraException && _isHardCameraDenial(error),
      onRetry: _retryAiCamera,
      // Unlike barcode mode, keep the tap-to-retry even on a denial: this is
      // the default mode and the whole screen is otherwise a dead end, so the
      // user needs a way back that doesn't require guessing that returning
      // from Settings is what re-arms it.
      alwaysAllowRetry: true,
    );
  }

  Widget _buildCameraErrorView(
    BuildContext context, {
    required bool isPermissionDenied,
    required VoidCallback onRetry,
    bool alwaysAllowRetry = false,
  }) {
    final l10n = context.l10n;

    final view = Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: context.colors.surfaceCard,
                shape: BoxShape.circle,
                border: Border.all(color: context.colors.border),
              ),
              child: Icon(
                isPermissionDenied
                    ? Icons.no_photography_outlined
                    : Icons.refresh_rounded,
                size: 44,
                color: context.colors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isPermissionDenied ? l10n.cameraAccessDenied : l10n.tryAgain,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (isPermissionDenied) ...[
              const SizedBox(height: 8),
              Text(
                l10n.enableCameraPermission,
                style: TextStyle(fontSize: 14, color: context.colors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Without this the denial screen is a dead end: it asks
              // the user to go change a system setting and offers
              // nothing to tap. Typing the barcode needs no camera at
              // all, so the whole app stays usable either way.
              AppButton(
                label: l10n.enterBarcodeManually,
                icon: Icons.keyboard_alt_outlined,
                expand: false,
                onPressed: () => unawaited(_showManualBarcodeDialog()),
              ),
            ],
          ],
        ),
      ),
    );

    if (isPermissionDenied && !alwaysAllowRetry) return view;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onRetry,
      child: view,
    );
  }
}

/// Manual barcode entry dialog.
///
/// Stateful (rather than an inline `builder:` closure) so the
/// [TextEditingController] is owned by the dialog's own element and torn down
/// in its [State.dispose] — i.e. after the route is unmounted. Disposing it in
/// the caller right after `showDialog` returns is too early: that future
/// completes on `pop()`, while the dialog subtree keeps animating out and
/// re-subscribes to the controller (`_AnimatedState.didUpdateWidget`). The
/// resulting "used after being disposed" throw aborts an in-flight element
/// update and leaves an InheritedElement holding stale dependents, which
/// surfaces one frame later as the red-screen `'_dependents.isEmpty'`
/// assertion when the user backs out of the scanner.
class _ManualBarcodeDialog extends StatefulWidget {
  const _ManualBarcodeDialog();

  @override
  State<_ManualBarcodeDialog> createState() => _ManualBarcodeDialogState();
}

class _ManualBarcodeDialogState extends State<_ManualBarcodeDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final l10n = context.l10n;

    return AlertDialog(
      backgroundColor: colors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border),
      ),
      title: Text(
        l10n.enterBarcodeManually,
        style: TextStyle(color: colors.textPrimary),
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.search,
          onFieldSubmitted: (_) => _submit(),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(13),
          ],
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: l10n.barcodeInputHint,
            labelText: l10n.barcodeInputLabel,
          ),
          validator: (v) {
            if (v == null || v.isEmpty) {
              return l10n.enterBarcodeManually;
            }
            if (!BarcodeValidator.isValidBarcode(v)) {
              return l10n.invalidBarcode;
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel, style: TextStyle(color: colors.textMuted)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            l10n.search,
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

/// Floating badge in the top-right of the scanner that shows how many
/// scans the guest has left out of [GuestScanCounter.lifetimeLimit].
/// Updates automatically because `guestScanCounterProvider` is a
/// Notifier — every `increment()` call re-emits the count.
class _GuestScanBadge extends StatelessWidget {
  final int remaining;

  const _GuestScanBadge({required this.remaining});

  @override
  Widget build(BuildContext context) {
    final isEmpty = remaining == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: isEmpty
              ? Colors.redAccent.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isEmpty
                ? Icons.lock_outline_rounded
                : Icons.qr_code_scanner_rounded,
            color: isEmpty ? Colors.redAccent : Colors.white,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            context.l10n.guestScanCounter(remaining),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
