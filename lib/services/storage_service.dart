import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadProfileImage({
    required String uid,
    required File image,
  }) async {
    final ref = _storage.ref().child('profile_images/$uid.jpg');

    await ref.putFile(image);

    return await ref.getDownloadURL();
  }
}
