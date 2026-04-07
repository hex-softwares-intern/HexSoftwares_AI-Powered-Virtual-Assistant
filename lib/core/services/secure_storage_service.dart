// lib/core/services/secure_storage_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  static const _groqKey = 'groq_api_key';

  static Future<void> saveGroqKey(String key) async {
    await _storage.write(key: _groqKey, value: key);
  }

  static Future<String?> getGroqKey() async {
    return await _storage.read(key: _groqKey);
  }
}
