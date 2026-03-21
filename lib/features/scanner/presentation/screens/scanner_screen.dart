import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/scanner_overlay.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  DateTime? _lastScanTime;
  String? _lastBarcode;
  bool _isNavigating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isNavigating) return;

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
    _isNavigating = true;

    HapticFeedback.mediumImpact();

    context.push('/product/$value').then((_) {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return _buildCameraError(context, error);
            },
          ),

          // Overlay
          const ScannerOverlay(),
          const ScannerOverlayBorder(),

          // Bottom hint pill
          Positioned(
            bottom: 130,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8,
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
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            gradient: context.colors.primaryGradient,
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

                  // Flash toggle pill button
                  ValueListenableBuilder<MobileScannerState>(
                    valueListenable: _controller,
                    builder: (context, state, child) {
                      final isOn = state.torchState == TorchState.on;
                      return GestureDetector(
                        onTap: () => _controller.toggleTorch(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isOn
                                ? context.colors.primary.withValues(alpha: 0.25)
                                : Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: isOn
                                  ? context.colors.primary.withValues(alpha: 0.6)
                                  : Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Icon(
                            isOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            color: isOn ? context.colors.primary : Colors.white,
                            size: 20,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
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
              width: 96, height: 96,
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
              style: TextStyle(
                fontSize: 14,
                color: context.colors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}