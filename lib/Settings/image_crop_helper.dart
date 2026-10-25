import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

/// Shared image-cropping utility used by `displayphoto.dart`, `pfpselect.dart`
/// and `update_profile.dart` so the cropping logic lives in exactly one place.
///
/// Shows platform-specific aspect-ratio presets and UI settings, then returns
/// the cropped file path, or `null` if cropping was cancelled or failed.
/// Callers keep their own `setState` calls to update local state.
Future<String?> cropImage(String sourcePath) async {
  final CroppedFile? croppedFile = await ImageCropper().cropImage(
    sourcePath: sourcePath,
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    uiSettings: [
      AndroidUiSettings(
          toolbarTitle: 'Resize your image',
          toolbarColor: Colors.orange,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          showCropGrid: false),
      IOSUiSettings(
        title: 'Resize Your Image',
      )
    ],
  );
  return croppedFile?.path;
}
