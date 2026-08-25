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

  Future<String?> uploadFile(File file, {CloudinaryResourceType resourceType = CloudinaryResourceType.Auto}) async {
    try {
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
