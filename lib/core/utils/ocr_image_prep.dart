import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Prepared image payload ready to send to the Gemini edge function.
///
/// `bytes` are the orientation-baked / downscaled JPEG (kept around so the
/// caller can show a preview) and `base64` is the encoded form the edge
/// function expects in `image_base64`.
class PreparedOcrImage {
  final Uint8List bytes;
  final String base64;

  const PreparedOcrImage({required this.bytes, required this.base64});
}

/// Decode → bake EXIF orientation → downscale → re-encode as JPEG → base64.
///
/// This MUST run on a background isolate via [compute] — the synchronous
/// `image` package operations on a 12 MP camera frame take 1–3 seconds of
/// pure CPU on mid-range Android devices and otherwise block the UI thread
/// long enough to trigger the system "App not responding" dialog.
///
/// Some Android OEMs (especially Samsung in landscape) save camera JPEGs
/// with EXIF orientation set but the pixel data itself unrotated. Gemini
/// sometimes ignores the EXIF hint and reads the image sideways, producing
/// outputs that pick up the wrong region of the package (e.g. the
/// manufacturer address instead of the ingredients list). Baking the
/// orientation into the pixels eliminates that ambiguity.
///
/// 3200 px on the long edge keeps small/curved package text legible without
/// forcing the user to crop in close, and roughly halves the upload size
/// vs the raw 12 MP capture.
Future<PreparedOcrImage> prepareOcrImage(Uint8List bytes) {
  return compute(_prepareOcrImageSync, bytes);
}

PreparedOcrImage _prepareOcrImageSync(Uint8List bytes) {
  Uint8List outputBytes = bytes;
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded != null) {
      final upright = img.bakeOrientation(decoded);
      const maxEdge = 1600;
      final longestSide =
          upright.width > upright.height ? upright.width : upright.height;
      final resized = longestSide > maxEdge
          ? img.copyResize(
              upright,
              width: upright.width >= upright.height ? maxEdge : null,
              height: upright.height > upright.width ? maxEdge : null,
              interpolation: img.Interpolation.cubic,
            )
          : upright;
      outputBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 85));
    }
  } catch (_) {
    // Fall back to the raw bytes — the OCR may still succeed and we'd
    // rather try than abort. The caller logs nothing here because we're
    // on a worker isolate without access to the app's logger.
    outputBytes = bytes;
  }

  return PreparedOcrImage(
    bytes: outputBytes,
    base64: base64Encode(outputBytes),
  );
}
