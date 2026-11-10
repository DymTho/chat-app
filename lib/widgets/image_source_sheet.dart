import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_palette.dart';

/// Asks camera vs gallery, then returns a small compressed JPEG (or null).
Future<Uint8List?> pickAvatarImage(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) {
      final palette = ctx.palette;
      Widget option(IconData icon, String label, ImageSource src) => Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.pop(ctx, src),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: palette.spec.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Icon(icon, color: palette.spec.primary, size: 30),
                    const SizedBox(height: 8),
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Profile picture',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Row(
                children: [
                  option(Icons.photo_camera_rounded, 'Camera', ImageSource.camera),
                  const SizedBox(width: 14),
                  option(Icons.photo_library_rounded, 'Gallery', ImageSource.gallery),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  if (source == null) return null;

  try {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 320,
      maxHeight: 320,
      imageQuality: 70,
      preferredCameraDevice: CameraDevice.front,
    );
    if (file == null) return null;
    return await file.readAsBytes();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${source.name}: $e')),
      );
    }
    return null;
  }
}
