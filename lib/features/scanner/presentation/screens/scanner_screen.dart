import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/barcode_validator.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/providers/monetization_provider.dart';
import '../../../../core/services/guest_scan_counter.dart';
import '../../../../core/session/app_session.dart';
import '../../../../core/theme/app_colors.dart';
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
  Future<void>? _aiCameraInit;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Default mode is AI (_scanMode = 1) so initialise the native
    // camera right away. Barcode mode users will trigger the swap to
    // mobile_scanner when they tap the toggle.
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

  /// Boot the native camera for AI mode. Picks the back camera, lowest
  /// reasonable resolution that still works for meal analysis. Audio
  /// is disabled — we never record video here, just take stills.
  Future<void> _initAiCamera({int attempt = 0}) async {
    if (_aiCamera != null) return; // already alive
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high, // ~1280x720 — plenty for Claude vision
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _aiCamera = controller;
      _aiCameraInit = controller.initialize();
      await _aiCameraInit;
      if (!mounted) {
        await controller.dispose();
        _aiCamera = null;
        return;
      }
      setState(() {});
    } catch (e) {
      debugPrint('[Scanner] AI camera init failed (attempt $attempt): $e');
      _aiCamera = null;
      _aiCameraInit = null;
      // The camera may still be held by a client that's mid-release (e.g.
      // we returned to the scanner the instant the previous controller was
      // torn down). Back off briefly and retry so a transient "camera busy"
      // doesn't leave a permanent black preview that only an app restart
      // clears.
      if (mounted && _scanMode == 1 && attempt < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (mounted && _scanMode == 1 && _aiCamera == null) {
          await _initAiCamera(attempt: attempt + 1);
        }
      }
    }
  }

  Future<void> _disposeAiCamera() async {
    final c = _aiCamera;
    _aiCamera = null;
    _aiCameraInit = null;
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
    unawaited(_controller.start());
  }

  /// Tear down the barcode subscription and stop the camera.
  ///
  /// Releases the camera while the scanner is covered (product detail) or
  /// the app is backgrounded. Pair the *return* with [_restartBarcodeScanner]
  /// rather than a bare [_startScanning]: re-acquiring the camera on the
  /// same controller after a stop() is unreliable on many devices.
  void _stopScanning() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    unawaited(_controller.stop());
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
    if (!_controller.value.hasCameraPermission) return;

    switch (state) {
      case AppLifecycleState.resumed:
        if (!_isNavigating) {
          if (_scanMode == 0) {
            // Background did a full stop(); rebuild a fresh controller
            // rather than restart this one (same unreliable round-trip).
            unawaited(_restartBarcodeScanner());
          } else {
            _initAiCamera();
          }
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (_scanMode == 0) {
          _stopScanning();
        } else {
          _disposeAiCamera();
        }
        break;
    }
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

    // Reject URLs and non-barcode values that would break routing.
    // Logic lives in `BarcodeValidator` so it can be unit-tested.
    if (!BarcodeValidator.isValidBarcode(value)) {
      debugPrint('[Scanner] rejected — not a valid barcode');
      HapticFeedback.heavyImpact();
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
      return;
    }

    _isNavigating = true;

    // Guest mode has its own lifetime cap (5 scans), now enforced
    // server-side by device hash (survives a cache/data clear) with a local
    // counter fallback when offline. Authenticated users go through the
    // per-user Supabase RPC instead.
    if (ref.read(isGuestProvider)) {
      if (!await _consumeGuestScan()) {
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
        if (mounted) {
          final granted = await ScanLimitSheet.show(context);
          if (!granted) {
            setState(() => _isNavigating = false);
            return;
          }
        } else {
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
    _stopScanning();
    context.push('/product/$value').then((_) async {
      if (!mounted) return;
      _isNavigating = false;
      if (_scanMode == 0) {
        await _restartBarcodeScanner();
      }
    });
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
          if (mounted) {
            final granted = await ScanLimitSheet.show(context);
            if (!granted) return;
          } else {
            return;
          }
        }
      }

      if (!mounted) return;
      await context.push('/food-result', extra: imageBytes);
      // Returned from food-result — the AI camera survives across
      // the push/pop, so nothing to restart. If user backgrounded
      // the app while away didChangeAppLifecycleState reinitialises.
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
          //     a still in one tap. While the controller is still
          //     initialising we show a plain black background.
          if (_scanMode == 0)
            MobileScanner(
              controller: _controller,
              errorBuilder: (context, error) {
                return _buildCameraError(context, error);
              },
            )
          else if (_aiCamera?.value.isInitialized ?? false)
            Positioned.fill(child: CameraPreview(_aiCamera!))
          else
            const SizedBox.shrink(),

          // Guest budget badge — visible only while browsing as a
          // guest. Shows the remaining lifetime scan quota so users
          // understand the limit before they hit the hard block.
          // Hidden after registration (isGuest=false).
          if (ref.watch(isGuestProvider))
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: _GuestScanBadge(
                remaining:
                    ((GuestScanCounter.lifetimeLimit -
                                ref.watch(guestScanCounterProvider))
                            .clamp(0, GuestScanCounter.lifetimeLimit))
                        .toInt(),
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

          // AI mode: hint + capture button
          if (_scanMode == 1) ...[
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

                      // Flash toggle — barcode mode only. The torch belongs to
                      // the mobile_scanner controller; in AI mode that
                      // controller isn't running, so the button is hidden
                      // instead of being a no-op that crashed with
                      // controllerUninitialized (Sentry NUTRILENS-2).
                      if (_scanMode == 0)
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
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isOn
                                      ? colors.primary.withValues(alpha: 0.25)
                                      : Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(50),
                                  border: Border.all(
                                    color: isOn
                                        ? colors.primary.withValues(alpha: 0.6)
                                        : Colors.white.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Icon(
                                  isOn
                                      ? Icons.flash_on_rounded
                                      : Icons.flash_off_rounded,
                                  color: isOn ? colors.primary : Colors.white,
                                  size: 20,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),

                // Mode tab bar
                const SizedBox(height: 8),
                _buildModeTabBar(l10n, colors),
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
    final l10n = context.l10n;

    // Only an actual permission denial should send the user to settings.
    // Other errors (e.g. the camera failed to re-acquire after returning to
    // the scanner) are transient — show a tappable retry that rebuilds the
    // controller instead of the misleading "permission denied" message.
    final isPermissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;

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
            ],
          ],
        ),
      ),
    );

    if (isPermissionDenied) return view;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(_restartBarcodeScanner()),
      child: view,
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
