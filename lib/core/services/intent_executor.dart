// lib/core/services/intent_executor.dart

import 'dart:io';
import 'intent_service.dart';
import 'android_platform_service.dart';

class IntentExecutor {
  // 🔥 UPDATED PACKAGE MAPPER: Uses exact Android Package IDs to bypass the "Chooser"
  static final Map<String, String> _knownPackages = {
    // BlackHole variants
    'blackhole': 'com.shadow.blackhole',
    'black hole': 'com.shadow.blackhole',
    'fawazapp': 'com.fawazapp.blackhole',

    // YMusic variants
    'ymusic': 'com.kapp.youtube.final',
    'y music': 'com.kapp.youtube.final',
    'ytmusic': 'app.ytmusic.youtube.ymusic',

    // Standard fallbacks
    'spotify': 'com.spotify.music',
    'youtube music': 'com.google.android.apps.youtube.music',
    'yt music': 'com.google.android.apps.youtube.music',
    'retro music': 'code.name.monkey.retromusic',
  };

  // 🚀 Windows URI Mapper
  static final Map<String, String> _windowsURIs = {
    'spotify': 'spotify:',
    'youtube': 'https://www.youtube.com',
    'calendar': 'outlookcal:',
    'schedule': 'outlookcal:',
    'alarm': 'ms-clock:',
    'clock': 'ms-clock:',
    'timer': 'ms-clock:',
    'calculator': 'calc:',
    'settings': 'ms-settings:',
  };

  static Future<bool> execute(DetectedIntent intent) async {
    // 1. CLEAN THE INPUT FOR KEYWORD MATCHING
    final raw = intent.rawText.trim().toLowerCase();

    print(
      '[IntentExecutor] 🔍 Analyzing text: "$raw" on ${Platform.operatingSystem}',
    );

    // 🚀 NEW: WINDOWS BRANCH
    if (Platform.isWindows) {
      return await _executeWindows(intent, raw);
    }

    // 2. STRICT KEYWORD JUMPS (Local Execution / Fallback) - ANDROID
    if (intent.type == IntentType.none) {
      final isExplicitAction =
          raw.startsWith("open") ||
          raw.startsWith("launch") ||
          raw.startsWith("show") ||
          raw.startsWith("go to");

      if (isExplicitAction) {
        // Dialer/Phone
        if (raw.contains("dialer") ||
            raw.contains("phone") ||
            raw.contains("keypad")) {
          await AndroidPlatformService.makeCall("");
          return true;
        }

        // SMS
        if (raw.contains("message") ||
            raw.contains("sms") ||
            raw.contains("text app")) {
          await AndroidPlatformService.sendSMS(number: "", message: "");
          return true;
        }

        // Clock/Alarms
        if (raw.contains("alarm") ||
            raw.contains("clock") ||
            raw.contains("timer")) {
          await AndroidPlatformService.showAlarms();
          return true;
        }

        // Calendar
        if (raw.contains("calendar") || raw.contains("schedule")) {
          await AndroidPlatformService.viewCalendar();
          return true;
        }

        // WhatsApp
        if (raw.contains("whatsapp")) {
          await AndroidPlatformService.whatsappAction(
            number: "",
            message: "",
            type: "message",
          );
          return true;
        }

        // 🔥 GENERIC APP LAUNCHER (Updated with Package Mapper)
        final List<String> triggerWords = ["open", "launch", "go to", "show"];
        String appToOpen = "";

        for (var word in triggerWords) {
          if (raw.startsWith(word)) {
            appToOpen = raw.replaceFirst(word, "").trim();
            break;
          }
        }

        if (appToOpen.isNotEmpty) {
          print(
            '[IntentExecutor] 🚀 Keyword Fallback: Opening "$appToOpen"...',
          );
          final package = _knownPackages[appToOpen.toLowerCase()];
          await AndroidPlatformService.openApp(package ?? appToOpen);
          return true;
        }
      }

      return false;
    }

    // 3. TAGGED INTENT HANDLER (AI-Driven Logic) - ANDROID
    print('[IntentExecutor] 🤖 Executing AI Intent: ${intent.type}');

    try {
      switch (intent.type) {
        case IntentType.openApp:
          await _handleOpenApp(intent.params);
          return true;
        case IntentType.setAlarm:
          await _handleAlarm(intent.params);
          return true;
        case IntentType.playMusic:
          await _handleMusic(intent.params);
          return true;
        case IntentType.createCalendarEvent:
          await _handleCalendar(intent.params);
          return true;
        case IntentType.viewCalendar:
          await AndroidPlatformService.viewCalendar();
          return true;
        case IntentType.fetchCalendar:
          await AndroidPlatformService.getSystemStats();
          return true;
        case IntentType.call:
          await _handleCall(intent.params);
          return true;
        case IntentType.whatsapp:
          await _handleWhatsApp(intent.params);
          return true;
        case IntentType.sendSms:
          await _handleSMS(intent.params);
          return true;
        case IntentType.batteryInfo:
        case IntentType.weatherInfo:
          await AndroidPlatformService.getSystemStats();
          return true;
        // Windows-only intents handled in _executeWindows
        case IntentType.setVolume:
        case IntentType.setBrightness:
        case IntentType.mute:
          return false;
        case IntentType.none:
          return false;
      }
    } catch (e) {
      print('[IntentExecutor] ❌ Execution Error: $e');
      return false;
    }
  }

  static Future<bool> _executeWindows(DetectedIntent intent, String raw) async {
    final text = raw.toLowerCase();
    print(
      '[IntentExecutor] 🪟 Windows Execution Mode: $text (Intent: ${intent.type})',
    );

    // 🚀 NEW: HANDLE AI-TAGGED INTENTS FIRST
    if (intent.type == IntentType.mute) {
      await Process.run('powershell', [
        '-Command',
        "(New-Object -ComObject WScript.Shell).SendKeys([char]173)",
      ], runInShell: true);
      return true;
    }

    if (intent.type == IntentType.setVolume) {
      final levelParam = intent.params['level'];
      if (levelParam != null) {
        int vol =
            int.tryParse(levelParam.replaceAll(RegExp(r'[^0-9]'), '')) ?? 50;
        // PowerShell Logic to set absolute volume (0-100)
        await Process.run('powershell', [
          '-Command',
          r'$obj = New-Object -ComObject WScript.Shell; for($i=0; $i -lt 50; $i++) {$obj.SendKeys([char]174)}; for($i=0; $i -lt ' +
              (vol / 2).toStringAsFixed(0) +
              r'; $i++) {$obj.SendKeys([char]175)}',
        ], runInShell: true);
        return true;
      }
    }

    if (intent.type == IntentType.setBrightness) {
      final levelParam = intent.params['level'];
      int level =
          int.tryParse(levelParam?.replaceAll(RegExp(r'[^0-9]'), '') ?? '50') ??
          50;
      await Process.run('powershell', [
        '-Command',
        "(Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightnessMethods).WmiSetBrightness(1,$level)",
      ], runInShell: true);
      return true;
    }

    // 🔊 FALLBACK: KEYWORD VOLUME CONTROL (Mute, Unmute, and +/- 10% Steps)
    if (text.contains("mute") || text.contains("unmute")) {
      await Process.run('powershell', [
        '-Command',
        "(New-Object -ComObject WScript.Shell).SendKeys([char]173)",
      ], runInShell: true);
      return true;
    }

    if (text.contains("volume")) {
      int change = 0;
      if (text.contains("decrease") ||
          text.contains("down") ||
          text.contains("lower") ||
          text.contains("reduce")) {
        change = -5;
      } else if (text.contains("increase") ||
          text.contains("up") ||
          text.contains("higher") ||
          text.contains("raise")) {
        change = 5;
      }

      if (change != 0) {
        String key = change > 0 ? "[char]175" : "[char]174";
        await Process.run('powershell', [
          '-Command',
          "for(\$i=0; \$i -lt ${change.abs()}; \$i++) {(New-Object -ComObject WScript.Shell).SendKeys($key)}",
        ], runInShell: true);
        return true;
      }
    }

    // 🌐 WEB URLS (WhatsApp, Instagram, etc.)
    if (text.contains("whatsapp")) {
      await Process.run('start', [
        'https://web.whatsapp.com',
      ], runInShell: true);
      return true;
    }
    if (text.contains("instagram")) {
      await Process.run('start', [
        'https://www.instagram.com',
      ], runInShell: true);
      return true;
    }

    // ✅ FIXED REGEX FOR URLS
    if (text.contains("www.") ||
        text.contains(".com") ||
        text.contains(".net") ||
        text.contains(".org")) {
      final urlRegExp = RegExp(
        r'''((https?:\/\/)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*))''',
      );
      final urlMatch = urlRegExp.firstMatch(text);
      if (urlMatch != null) {
        String url = urlMatch.group(0)!;
        if (!url.startsWith('http')) url = 'https://$url';
        await Process.run('start', [url], runInShell: true);
        return true;
      }
    }

    // 🔄 WINDOWS UPDATES
    if (text.contains("windows update")) {
      await Process.run('start', [
        'ms-settings:windowsupdate',
      ], runInShell: true);
      return true;
    }

    // ⏰ ALARM / CALENDAR
    if (text.contains("set alarm") ||
        text.contains("open clock") ||
        text.contains("open alarm")) {
      await Process.run('start', ['ms-clock:'], runInShell: true);
      return true;
    }
    if (text.contains("open calendar") ||
        text.contains("my schedule") ||
        text.contains("view calendar")) {
      await Process.run('start', ['outlookcal:'], runInShell: true);
      return true;
    }

    // 🚀 OLD URI MAPPING (Remains Intact)
    for (var entry in _windowsURIs.entries) {
      if (text.contains(entry.key)) {
        await Process.run('start', [entry.value], runInShell: true);
        return true;
      }
    }

    return false;
  }

  // ── ANDROID SPECIFIC HELPERS ─────────────────────

  static Future<void> _handleOpenApp(Map<String, String> p) async {
    final name = (p['name'] ?? p['app'] ?? '').toLowerCase();
    if (name.isNotEmpty) {
      final package = _knownPackages[name];
      await AndroidPlatformService.openApp(package ?? name);
    }
  }

  static Future<void> _handleCall(Map<String, String> p) async {
    final target = p['target'] ?? p['number'] ?? '';
    if (target.isNotEmpty) {
      await AndroidPlatformService.makeCall(target);
    }
  }

  static Future<void> _handleSMS(Map<String, String> p) async {
    final number = p['number'] ?? p['target'] ?? '';
    final message = p['message'] ?? '';
    await AndroidPlatformService.sendSMS(number: number, message: message);
  }

  static Future<void> _handleWhatsApp(Map<String, String> p) async {
    final number = p['number'] ?? p['target'] ?? '';
    final message = p['message'] ?? '';
    final type = p['type']?.toLowerCase() ?? 'message';
    await AndroidPlatformService.whatsappAction(
      number: number,
      message: message,
      type: type,
    );
  }

  static Future<void> _handleAlarm(Map<String, String> p) async {
    String rawHour = p['hour']?.toString() ?? '7';
    String rawMin = p['minute']?.toString() ?? '0';

    final hour = int.tryParse(rawHour.replaceAll(RegExp(r'[^0-9]'), '')) ?? 7;
    final minute = int.tryParse(rawMin.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final label = p['label'] ?? p['title'] ?? 'ARIA Alarm';

    await AndroidPlatformService.setAlarm(
      hour: hour,
      minute: minute,
      label: label,
    );
  }

  static Future<void> _handleMusic(Map<String, String> p) async {
    final query = p['query'] ?? '';
    final appInput = (p['app'] ?? p['name'] ?? '').toLowerCase().trim();

    final package = _knownPackages[appInput];

    if (query.isEmpty && package != null) {
      await AndroidPlatformService.openApp(package);
    } else {
      await AndroidPlatformService.playMusic(
        query: query.isNotEmpty ? query : 'trending music',
        app: package ?? appInput,
      );
    }
  }

  static Future<void> _handleCalendar(Map<String, String> p) async {
    final title = p['title'] ?? 'New Event';
    final description = p['description'] ?? '';

    int startMs = DateTime.now().millisecondsSinceEpoch;
    final rawTime = p['startMs'] ?? p['time'] ?? p['date'];

    if (rawTime != null) {
      startMs = int.tryParse(rawTime.toString()) ?? startMs;
    }

    await AndroidPlatformService.createCalendarEvent(
      title: title,
      description: description,
      startMs: startMs,
    );
  }
}
