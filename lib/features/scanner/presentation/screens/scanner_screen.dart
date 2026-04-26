import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/providers/monetization_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/scanner_overlay.dart';
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

  /// 0 = Barcode mode, 1 = AI Analysis mode
  int _scanMode = 0;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startScanning();
  }

  @override
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
    await _controller.dispose();
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
  /// This is the hot path for battery savings: when the app is backgrounded
  /// or the user switches to AI mode / navigates to a product detail, we
  /// release the camera so it isn't streaming frames into a decoder whose
  /// output we're discarding anyway.
  void _stopScanning() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    unawaited(_controller.stop());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permission dialogs trigger lifecycle changes before the controller
    // has a real camera handle — guard against that per mobile_scanner
    // docs.
    if (!_controller.value.hasCameraPermission) return;

    switch (state) {
      case AppLifecycleState.resumed:
        // Only resume scanning if we're on the barcode tab and not
        // waiting on a pushed navigation. `inactive` fires any time a
        // system dialog/sheet appears, so a benign interruption (e.g.
        // permission prompt finishing) shouldn't wake scanning when the
        // user has already switched to AI mode.
        if (_scanMode == 0 && !_isNavigating) {
          _startScanning();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _stopScanning();
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

    // Reject URLs and non-barcode values that would break routing
    if (!_isValidBarcode(value)) {
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

    if (!mounted) return;

    HapticFeedback.mediumImpact();

    debugPrint('[Scanner] navigating to /product/$value');
    // Release the camera while the product detail is on top — the scanner
    // route is still mounted underneath but the preview + decoder would
    // otherwise keep streaming frames we can never see.
    _stopScanning();
    context.push('/product/$value').then((_) {
      if (!mounted) return;
      setState(() => _isNavigating = false);
      if (_scanMode == 0) _startScanning();
    });
  }

  /// Returns true if the value looks like a product barcode.
  bool _isValidBarcode(String value) {
    if (value.contains('://') || value.contains('/')) return false;
    if (value.startsWith('http') || value.startsWith('www.')) return false;
    return true;
  }

  Future<void> _captureForAi() async {
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (xFile == null || !mounted) return;

      final Uint8List imageBytes = await xFile.readAsBytes();

      if (!mounted) return;

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

      if (!mounted) return;
      await context.push('/food-result', extra: imageBytes);
    } catch (e) {
      debugPrint('[Scanner] AI capture error: $e');
    }
  }

  /// Toggle scanning mode. In AI mode we stop the camera because the
  /// capture button launches `image_picker` (which uses the system
  /// camera). Leaving `MobileScanner` streaming frames while the user
  /// hasn't tapped capture is pure wasted CPU — the decoder was already
  /// discarding results for us via the `_scanMode != 0` guard.
  void _setScanMode(int mode) {
    if (_scanMode == mode) return;
    setState(() => _scanMode = mode);
    if (mode == 0) {
      _startScanning();
    } else {
      _stopScanning();
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
          // Camera preview. We read barcodes via `controller.barcodes`
          // (see `_startScanning`) so `onDetect` is intentionally omitted
          // — that's the canonical v7 pattern for manual lifecycle
          // management.
          MobileScanner(
            controller: _controller,
            errorBuilder: (context, error) {
              return _buildCameraError(context, error);
            },
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

                      // Flash toggle
                      ValueListenableBuilder<MobileScannerState>(
                        valueListenable: _controller,
                        builder: (context, state, child) {
                          final isOn = state.torchState == TorchState.on;
                          return GestureDetector(
                            onTap: () => _controller.toggleTorch(),
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

    return Center(
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
                Icons.no_photography_outlined,
                size: 44,
                color: context.colors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.cameraAccessDenied,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.enableCameraPermission,
              style: TextStyle(fontSize: 14, color: context.colors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
