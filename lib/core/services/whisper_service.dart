import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class WhisperService {
  static const _url = 'https://api.groq.com/openai/v1/audio/transcriptions';

  final Dio _dio;

  WhisperService({required String apiKey})
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Authorization': 'Bearer $apiKey'},
        ),
      );

  /// Transcribes the audio file at [filePath] using Groq's Whisper API.
  Future<String?> transcribe(String filePath) async {
    // 1. Guard for non-supported platforms if necessary
    // (Whisper is API based, so it works on Windows, but the FILE might not exist)
    final file = File(filePath);

    if (!await file.exists()) {
      print('[Whisper] ❌ File not found: $filePath');
      return null;
    }

    final size = await file.length();
    print('[Whisper] ⬆️ Sending ${size}b');

    // Prevent sending empty or tiny noise files (3KB threshold)
    if (size < 3000) {
      print('[Whisper] ⚠️ File too small — skipping');
      _safeDelete(file);
      return null;
    }

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: 'audio.wav'),
        'model': 'whisper-large-v3-turbo',
        'language': 'en',
      });

      final response = await _dio.post(_url, data: formData);
      final data = response.data;

      String text;

      if (data is Map && data['text'] != null) {
        text = data['text'].toString();
      } else if (data is String) {
        text = data;
      } else {
        print('[Whisper] ❌ Unexpected response format: $data');
        return null;
      }

      final result = text.trim();
      print('[Whisper] Result: "$result"');
      return result.isEmpty ? null : result;
    } catch (e) {
      print('[Whisper] ❌ Transcription Error: $e');
      return null;
    } finally {
      // Always clean up the temporary audio file
      await _safeDelete(file);
    }
  }

  /// Helper to delete files safely, especially on Windows where file hooks
  /// might stay active for a few milliseconds after Dio finishes.
  Future<void> _safeDelete(File file) async {
    try {
      if (await file.exists()) {
        // Windows often needs a tiny breather before deleting a file just used in a request
        if (!kIsWeb && Platform.isWindows) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
        await file.delete();
        print('[Whisper] 🗑️ Temp file deleted.');
      }
    } catch (e) {
      print('[Whisper] ⚠️ Could not delete temp file: $e');
    }
  }
}
