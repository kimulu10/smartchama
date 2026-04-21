import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageService {
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
}
