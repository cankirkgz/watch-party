import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class MediaService {
  MediaService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadMessageMedia({
    required String roomId,
    required String userId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    if (bytes.length >= 20 * 1024 * 1024) {
      throw const MediaUploadException('Dosya 20 MB sınırını aşıyor.');
    }
    final safeExtension = extension.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final fileName = '${const Uuid().v4()}.$safeExtension';
    final reference = _storage.ref('room_media/$roomId/$userId/$fileName');
    try {
      await reference.putData(
          bytes, SettableMetadata(contentType: contentType));
      return await reference.getDownloadURL();
    } on FirebaseException catch (error) {
      if (error.code == 'unknown' ||
          error.code == 'bucket-not-found' ||
          error.code == 'quota-exceeded') {
        throw MediaUploadException(
          'Cloud Storage erişilemiyor (${error.code}). Firebase projesinde Blaze planını, Storage bucketını ve Storage Rules ayarlarını kontrol et.',
        );
      }
      if (error.code == 'unauthorized') {
        throw const MediaUploadException(
          'Storage izni reddedildi. Oturum ve Storage Rules ayarlarını kontrol et.',
        );
      }
      throw MediaUploadException(error.message ?? error.code);
    }
  }
}

class MediaUploadException implements Exception {
  const MediaUploadException(this.message);
  final String message;

  @override
  String toString() => message;
}
