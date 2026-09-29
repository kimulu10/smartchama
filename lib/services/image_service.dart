import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

enum ImageUploadPath {
  profileImages,
  chamaLogos,
  organizationLogos,
}

class ImageService {
  static final ImagePicker _picker = ImagePicker();

  static Future<File?> compressImage({
    required File file,
    int quality = 80,
    int maxWidth = 1080,
    int maxHeight = 1080,
  }) async {
    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        '${file.path}_compressed.jpg',
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
      );

      if (result != null) {
        return File(result.path);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<int>?> compressImageToBytes({
    required File file,
    int quality = 80,
    int maxWidth = 1080,
    int maxHeight = 1080,
  }) async {
    try {
      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
      );
      return result;
    } catch (e) {
      return null;
    }
  }

  static Future<File?> pickAndCompressImage({
    required String imagePath,
    int quality = 80,
  }) async {
    final file = File(imagePath);
    if (!await file.exists()) return null;
    return compressImage(file: file, quality: quality);
  }

  static Future<XFile?> pickImage({
    ImageSource source = ImageSource.gallery,
    int maxWidth = 1080,
    int maxHeight = 1080,
    int imageQuality = 80,
  }) async {
    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: imageQuality,
      );
    } catch (e) {
      return null;
    }
  }

  static String _getStoragePath(ImageUploadPath path, String identifier) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    switch (path) {
      case ImageUploadPath.profileImages:
        return 'profile_images/$identifier/${identifier}_$timestamp.jpg';
      case ImageUploadPath.chamaLogos:
        return 'chama_logos/${identifier}_$timestamp.jpg';
      case ImageUploadPath.organizationLogos:
        return 'organization_logos/${identifier}_$timestamp.jpg';
    }
  }

  static Future<String?> uploadImage({
    required File file,
    required ImageUploadPath path,
    required String identifier,
    int quality = 80,
    int maxWidth = 1080,
    int maxHeight = 1080,
  }) async {
    try {
      final compressedFile = await compressImage(
        file: file,
        quality: quality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );

      final fileToUpload = compressedFile ?? file;
      final storagePath = _getStoragePath(path, identifier);
      final ref = firebase_storage.FirebaseStorage.instance.ref().child(storagePath);

      final uploadTask = ref.putFile(fileToUpload);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  static Future<String?> pickAndUploadImage({
    required ImageUploadPath path,
    required String identifier,
    ImageSource source = ImageSource.gallery,
    int quality = 80,
    int maxWidth = 1080,
    int maxHeight = 1080,
  }) async {
    final pickedFile = await pickImage(
      source: source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: quality,
    );

    if (pickedFile == null) return null;

    final file = File(pickedFile.path);
    return uploadImage(
      file: file,
      path: path,
      identifier: identifier,
      quality: quality,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }
}
