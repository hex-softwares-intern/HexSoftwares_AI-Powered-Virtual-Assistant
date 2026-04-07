// lib/core/services/android_platform_service.dart

import 'package:flutter/services.dart';

class AndroidPlatformService {
  // ⚠️ Matches the INTENT_CHANNEL in MainActivity.kt
  static const _channel = MethodChannel(
    'com.yourname.ai_assistant/platform_intents',
  );

  /// Fetches Battery, Location, and Calendar Events from Android.
  /// Result contains:
  /// {
  ///   'battery': {'level': int, 'isCharging': bool},
  ///   'location': {'lat': double, 'lon': double},
  ///   'events': List<Map<String, String>> // Today's schedule
  /// }
  static Future<Map<String, dynamic>> getSystemStats() async {
    try {
      final dynamic result = await _channel.invokeMethod('getSystemStats');

      if (result != null && result is Map) {
        // Deep cast to ensure compatibility with Flutter's type system
        return Map<String, dynamic>.from(
          result.map((key, value) {
            // 1. Handle nested Maps (like battery or location)
            if (value is Map) {
              return MapEntry(key.toString(), Map<String, dynamic>.from(value));
            }

            // 2. Handle Lists (like the new events list) with extra null safety
            if (value is List) {
              return MapEntry(
                key.toString(),
                value
                    .where((e) => e != null) // Filter out nulls
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList(),
              );
            }

            // 3. Handle primitive types (Strings, ints, etc.)
            return MapEntry(key.toString(), value);
          }),
        );
      }
    } catch (e) {
      print('[Platform] ❌ getSystemStats error: $e');
    }
    return {};
  }

  /// Opens an app by name or package identifier
  static Future<void> openApp(String name) async {
    await _safeInvoke('openApp', {'name': name});
  }

  /// Generic helper to invoke platform methods safely
  static Future<dynamic> _safeInvoke(
    String method, [
    Map<String, dynamic>? args,
  ]) async {
    try {
      print('[Platform] Invoking: $method with $args');
      return await _channel.invokeMethod(method, args);
    } on PlatformException catch (e) {
      print('[Platform] ❌ $method error: ${e.message}');
      return null;
    } catch (e) {
      print('[Platform] ❌ Unexpected error in $method: $e');
      return null;
    }
  }

  // --- INTENT LOGIC ---

  static Future<void> makeCall(String target) async {
    await _safeInvoke('makeCall', {'target': target});
  }

  static Future<void> sendSMS({
    required String number,
    required String message,
  }) async {
    await _safeInvoke('sendSMS', {'number': number, 'message': message});
  }

  static Future<void> whatsappAction({
    required String number,
    String? message,
    String type = 'message',
  }) async {
    await _safeInvoke('whatsappAction', {
      'number': number,
      'message': message ?? '',
      'type': type,
    });
  }

  static Future<void> setAlarm({
    required int hour,
    required int minute,
    String label = '',
    bool vibrate = true,
  }) async {
    await _safeInvoke('setAlarm', {
      'hour': hour,
      'minute': minute,
      'title': label,
      'vibrate': vibrate,
    });
  }

  static Future<void> showAlarms() async {
    await _safeInvoke('showAlarms');
  }

  static Future<void> viewCalendar() async {
    await _safeInvoke('viewCalendar');
  }

  static Future<void> playMusic({String query = '', String? app}) async {
    await _safeInvoke('playMusic', {'query': query, 'app': app});
  }

  static Future<void> createCalendarEvent({
    required String title,
    String description = '',
    int? startMs,
  }) async {
    final int startTime = startMs ?? DateTime.now().millisecondsSinceEpoch;
    await _safeInvoke('createCalendarEvent', {
      'title': title,
      'description': description,
      'startMs': startTime,
    });
  }
}
