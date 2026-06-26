// Riverpod 3 moved StateProvider/StateController to the legacy library.
import 'package:flutter_riverpod/legacy.dart';

/// One-shot request to put the scanner into a specific mode (0 = barcode,
/// 1 = AI) the next time it resumes.
///
/// Set by the food-result screen's "Scan barcode" action when a packaged
/// product is detected ("this is a packaged product — scan its barcode"),
/// just before popping back to the scanner. The scanner reads and clears it
/// on return so it fires exactly once.
final pendingScannerModeProvider = StateProvider<int?>((ref) => null);
