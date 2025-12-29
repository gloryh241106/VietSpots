import 'package:flutter/foundation.dart';

/// Local OCR stub used as a fallback when no backend OCR is available.
/// This intentionally returns an empty string but logs a debug message so
/// the app can continue to function. Replace with a real OCR integration
/// (Tesseract, cloud OCR API) for production.
Future<String> mockOcrFromBytes(Uint8List bytes) async {
  debugPrint('OCR stub called: returning empty text (replace with real OCR)');
  await Future.delayed(const Duration(milliseconds: 50));
  return '';
}
