import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Renders a widget off-screen, captures it to a PNG, and opens the OS share
/// sheet. Reusable for any fixed-size card.
class ShareService {
  const ShareService();

  /// [card] is laid out at [logicalSize] in an off-screen Overlay and captured
  /// at [pixelRatio] (e.g. 360 logical × 3.0 = 1080px). Writes [fileName] to the
  /// temp dir and shares it with [caption]. [context] must have an Overlay
  /// (any routed screen does).
  Future<void> captureAndShare({
    required BuildContext context,
    required Widget card,
    required Size logicalSize,
    required double pixelRatio,
    required String fileName,
    required String caption,
  }) async {
    final boundaryKey = GlobalKey();
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        // Park it above the visible viewport: lays out at full size, unseen.
        left: 0,
        top: -logicalSize.height - 100,
        child: Material(
          type: MaterialType.transparency,
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: logicalSize.width,
              height: logicalSize.height,
              child: card,
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    try {
      // Let the off-screen subtree lay out + paint (image decode may need an
      // extra frame; caller precaches network/memory images beforehand).
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;

      // The hosting screen may have been popped while the capture was in
      // flight (user taps share, then navigates away). Guard the lookup so
      // that becomes a catchable error instead of a null-deref crash.
      final renderObject = boundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError(
          'share: capture target disposed before paint ($fileName)',
        );
      }

      final image = await renderObject.toImage(pixelRatio: pixelRatio);
      ByteData? byteData;
      // Ensure the native image handle is freed even if PNG encoding throws.
      try {
        byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      } finally {
        image.dispose();
      }
      if (byteData == null) {
        throw StateError('share: capture produced no bytes ($fileName)');
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: caption),
      );
    } finally {
      entry.remove();
    }
  }
}

final shareServiceProvider = Provider<ShareService>(
  (ref) => const ShareService(),
);
