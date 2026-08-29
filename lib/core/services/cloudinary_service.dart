import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  static const String _cloudName = 'v1qkujav';
  static const String _uploadPreset = 'my_app_images';

  final CloudinaryPublic _cloudinary = CloudinaryPublic(
    _cloudName,
    _uploadPreset,
    cache: false,
  );

  // حماية: الحد الأقصى للحجم (15MB) لتقليل إساءة استخدام الـ unsigned preset.
  static const int _maxBytes = 15 * 1024 * 1024;
  static const Set<String> _allowedExt = {
    'jpg', 'jpeg', 'png', 'webp', 'gif',
    'mp4', 'mov', 'webm', 'm4v',
    'm4a', 'mp3', 'wav', 'aac', 'ogg',
  };

  Future<String?> uploadFile(File file, {CloudinaryResourceType resourceType = CloudinaryResourceType.Auto}) async {
    try {
      final size = await file.length();
      if (size > _maxBytes) {
        debugPrint('Cloudinary Upload Error: file too large ($size bytes)');
        return null;
      }
      final ext = file.path.split('.').last.toLowerCase();
      if (!_allowedExt.contains(ext)) {
        debugPrint('Cloudinary Upload Error: unsupported file type .$ext');
        return null;
      }
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: resourceType,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      debugPrint('Cloudinary Upload Error: $e');
      return null;
    }
  }

  // Keep this for backward compatibility if needed, but route to uploadFile
  Future<String?> uploadImage(File file) => uploadFile(file, resourceType: CloudinaryResourceType.Image);
}
