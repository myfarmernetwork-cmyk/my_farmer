import 'package:easy_localization/easy_localization.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload-uje sliku i vraća njen javni URL
  Future<String?> uploadProductImage(File imageFile) async {
    try {
      // Kreiramo unikatan naziv fajla koristeći timestamp
      String fileName = path.basename(imageFile.path);
      String destination = 'products/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      Reference ref = _storage.ref().child(destination);
      UploadTask uploadTask = ref.putFile(imageFile);

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('Greška prilikom uploada slike: $e');
      return null;
    }
  }
}