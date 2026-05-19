import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nutrilens/core/utils/ocr_image_prep.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('keeps OCR image payload at the default 1600px long edge', () async {
    final source = _jpeg(width: 2400, height: 1600);

    final prepared = await prepareOcrImage(source);
    final decoded = img.decodeImage(base64Decode(prepared.base64));

    expect(decoded, isNotNull);
    expect(decoded!.width, 1600);
    expect(decoded.height, 1067);
  });

  test(
    'keeps meal analysis image payload at a clearer 2048px long edge',
    () async {
      final source = _jpeg(width: 2400, height: 1600);

      final prepared = await prepareMealAnalysisImage(source);
      final decoded = img.decodeImage(base64Decode(prepared.base64));

      expect(decoded, isNotNull);
      expect(decoded!.width, 2048);
      expect(decoded.height, 1365);
    },
  );
}

Uint8List _jpeg({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(180, 120, 60));
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}
