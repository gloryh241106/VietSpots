import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Builds an [ImageProvider] from a stored avatar string.
///
/// FACT (from codebase): `UserModel.avatarUrl` was originally used with
/// `NetworkImage(...)` everywhere. After adding "Change Avatar" from gallery,
/// we also need to support local file paths.
///
/// Behavior:
/// - If value starts with http/https => [NetworkImage]
/// - Else (local path):
///   - Web: image_picker returns a blob URL => still [NetworkImage]
///   - Mobile/Desktop: use [FileImage]
ImageProvider? avatarImageProvider(String? avatarValue) {
  if (avatarValue == null || avatarValue.trim().isEmpty) return null;

  final value = avatarValue.trim();
  final uri = Uri.tryParse(value);
  final isNetwork =
      uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

  if (isNetwork) return NetworkImage(value);

  if (kIsWeb) {
    // On web, image_picker provides a blob URL.
    return NetworkImage(value);
  }

  return FileImage(File(value));
}
