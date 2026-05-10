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

class ImagePrepOptions {
  final int maxEdge;
  final int jpegQuality;

  const ImagePrepOptions({
    required this.maxEdge,
    required this.jpegQuality,
  });
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
/// 1600 px on the long edge keeps package OCR payloads small enough for quick
/// upload while preserving readable label text for the direct AI pass.
Future<PreparedOcrImage> prepareOcrImage(Uint8List bytes) {
  return _prepareImage(bytes, const ImagePrepOptions(maxEdge: 1600, jpegQuality: 85));
}

/// Meal analysis benefits from a clearer scene than label OCR: food boundaries,
/// side dishes, and texture cues are visual rather than text-only. Keep the
/// camera-capped 2048 px long edge instead of shrinking it again.
Future<PreparedOcrImage> prepareMealAnalysisImage(Uint8List bytes) {
  return _prepareImage(bytes, const ImagePrepOptions(maxEdge: 2048, jpegQuality: 90));
}

Future<PreparedOcrImage> _prepareImage(
  Uint8List bytes,
  ImagePrepOptions options,
) {
  return compute(
    _prepareOcrImageSync,
    _ImagePrepJob(bytes: bytes, options: options),
  );
}

class _ImagePrepJob {
  final Uint8List bytes;
  final ImagePrepOptions options;

  const _ImagePrepJob({required this.bytes, required this.options});
}

PreparedOcrImage _prepareOcrImageSync(_ImagePrepJob job) {
  Uint8List outputBytes = job.bytes;
  try {
    final decoded = img.decodeImage(job.bytes);
    if (decoded != null) {
      final upright = img.bakeOrientation(decoded);
      final maxEdge = job.options.maxEdge;
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
      outputBytes = Uint8List.fromList(
        img.encodeJpg(resized, quality: job.options.jpegQuality),
      );
    }
  } catch (_) {
    // Fall back to the raw bytes — the OCR may still succeed and we'd
    // rather try than abort. The caller logs nothing here because we're
    // on a worker isolate without access to the app's logger.
    outputBytes = job.bytes;
  }

  return PreparedOcrImage(
    bytes: outputBytes,
    base64: base64Encode(outputBytes),
  );
}
