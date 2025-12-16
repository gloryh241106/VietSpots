import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:vietspots/providers/localization_provider.dart';

Future<String?> showAvatarCropDialog({
  required BuildContext context,
  required Uint8List imageBytes,
}) {
  return showDialog<String?>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final controller = CropController();

      bool isCropping = false;

      Future<void> saveCropped(Uint8List croppedBytes) async {
        final dir = await getTemporaryDirectory();
        final file = File(
          '${dir.path}${Platform.pathSeparator}avatar_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await file.writeAsBytes(croppedBytes, flush: true);
        if (dialogContext.mounted) {
          Navigator.pop(dialogContext, file.path);
        }
      }

      return StatefulBuilder(
        builder: (ctx, setState) {
          final loc = Provider.of<LocalizationProvider>(ctx, listen: false);
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Crop avatar',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: isCropping
                              ? null
                              : () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  AspectRatio(
                    aspectRatio: 1,
                    child: Crop(
                      image: imageBytes,
                      controller: controller,
                      aspectRatio: 1,
                      withCircleUi: true,
                      onCropped: (result) async {
                        if (result is CropSuccess) {
                          await saveCropped(result.croppedImage);
                          return;
                        }

                        if (ctx.mounted) {
                          setState(() => isCropping = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                loc.translate('could_not_crop_image'),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isCropping
                                ? null
                                : () => Navigator.pop(ctx),
                            child: Text(loc.translate('cancel')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isCropping
                                ? null
                                : () {
                                    setState(() => isCropping = true);
                                    controller.crop();
                                  },
                            child: isCropping
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(loc.translate('done')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
