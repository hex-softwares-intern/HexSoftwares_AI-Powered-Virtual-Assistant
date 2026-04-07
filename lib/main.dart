import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart'; // For remembering the Mic
import 'core/theme/app_theme.dart';
import 'app.dart';

// 1. Define the Global Provider for SharedPreferences
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(); // This is overridden in main()
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences early to check for saved Mic
  final prefs = await SharedPreferences.getInstance();
  final String? savedMicId = prefs.getString('selected_mic_id');

  AppTheme.setSystemUI();

  // ─── PLATFORM SPECIFIC PERMISSIONS ───
  if (Platform.isAndroid) {
    print('[Main] Requesting Android-specific permissions...');
    // Keeping all your specific permissions intact
    await [
      Permission.microphone, // For Vosk Wake Word
      Permission.notification, // For Service status
      Permission.phone, // Direct Calling
      Permission.contacts, // Find numbers by name
      Permission.sms, // Sending text messages
      Permission.calendarFullAccess, // Calendar events
      Permission.scheduleExactAlarm, // Precise reminders
      Permission.systemAlertWindow, // Pop up over other apps
    ].request();
  } else if (Platform.isWindows) {
    print('[Main] Windows detected.');
    if (savedMicId == null) {
      print('[Main] ⚠️ No saved microphone found. UI will prompt for one.');
    } else {
      print('[Main] ✅ Saved microphone ID found: $savedMicId');
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        // This makes the 'prefs' object available to any Riverpod provider
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const AiAssistantApp(),
    ),
  );
}
