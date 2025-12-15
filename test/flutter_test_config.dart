import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> testExecutable(Future<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Avoid network calls and missing manifest issues in widget tests.
  GoogleFonts.config.allowRuntimeFetching = false;

  ServicesBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    'flutter/assets',
    (ByteData? message) async {
      if (message == null) return null;

      final String assetKey = utf8.decode(message.buffer.asUint8List());

      if (assetKey == 'AssetManifest.bin') {
        return const StandardMessageCodec().encodeMessage(<String, dynamic>{});
      }

      if (assetKey == 'AssetManifest.json' || assetKey == 'FontManifest.json') {
        final bytes = utf8.encode('{}');
        return ByteData.view(Uint8List.fromList(bytes).buffer);
      }

      if (assetKey.endsWith('.png')) {
        // 1x1 transparent PNG
        final pngBytes = base64.decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+X2ZcAAAAASUVORK5CYII=',
        );
        return ByteData.view(Uint8List.fromList(pngBytes).buffer);
      }

      return null;
    },
  );

  await testMain();
}
