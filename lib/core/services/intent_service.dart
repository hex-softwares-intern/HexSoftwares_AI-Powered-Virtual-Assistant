// lib/core/services/intent_service.dart

enum IntentType {
  setAlarm,
  playMusic,
  createCalendarEvent,
  viewCalendar,
  fetchCalendar, // 🔥 Added to support reading/refreshing events
  call,
  whatsapp,
  sendSms,
  openApp,
  batteryInfo,
  weatherInfo,
  setVolume, // 🚀 Added
  setBrightness, // 🚀 Added
  mute, // 🚀 Added
  none,
}

class DetectedIntent {
  final IntentType type;
  final Map<String, String> params;
  final String rawText;

  const DetectedIntent({
    required this.type,
    this.params = const {},
    this.rawText = '',
  });

  static const DetectedIntent none = DetectedIntent(type: IntentType.none);

  @override
  String toString() => 'DetectedIntent($type, $params)';
}

class IntentService {
  // Enhanced Regex: Handles optional spaces and the [INTENT:NAME|params] format
  static final _intentRegex = RegExp(
    r'\[INTENT:\s*([A-Z_]+)(?:[|]?\s*([^\]]*))?\]',
    caseSensitive: false,
  );

  static ParsedResponse parse(String raw) {
    try {
      // Find the first valid intent tag
      final match = _intentRegex.firstMatch(raw);

      // Clean the text for UI: remove ALL potential [INTENT:...] tags from the displayed string
      final clean = raw.replaceAll(RegExp(r'\[INTENT:.*?\]'), '').trim();

      if (match == null) {
        return ParsedResponse(
          cleanText: clean,
          intent: DetectedIntent(type: IntentType.none, rawText: raw),
        );
      }

      final typeStr = match.group(1)?.toUpperCase().trim() ?? '';
      final paramStr = match.group(2)?.trim() ?? '';

      final type = _parseType(typeStr);
      final params = _parseParams(paramStr);

      return ParsedResponse(
        cleanText: clean,
        intent: DetectedIntent(type: type, params: params, rawText: raw),
      );
    } catch (e) {
      print('[IntentService] Parse error: $e');
      return ParsedResponse(
        cleanText: raw.replaceAll(RegExp(r'\[INTENT:.*?\]'), '').trim(),
        intent: DetectedIntent.none,
      );
    }
  }

  static IntentType _parseType(String s) {
    switch (s) {
      case 'SET_ALARM':
      case 'ALARM':
      case 'REMINDER':
        return IntentType.setAlarm;
      case 'PLAY_MUSIC':
      case 'MUSIC':
      case 'PLAY':
        return IntentType.playMusic;
      case 'CREATE_CALENDAR':
      case 'CREATE_EVENT':
      case 'ADD_EVENT':
        return IntentType.createCalendarEvent;
      case 'VIEW_CALENDAR':
      case 'SHOW_CALENDAR':
      case 'OPEN_CALENDAR':
        return IntentType.viewCalendar;
      case 'FETCH_CALENDAR':
      case 'READ_CALENDAR':
      case 'GET_EVENTS':
        return IntentType.fetchCalendar;
      case 'CALL':
      case 'DIAL':
      case 'MAKE_CALL':
        return IntentType.call;
      case 'WHATSAPP':
      case 'SEND_WHATSAPP':
      case 'WA':
        return IntentType.whatsapp;
      case 'SEND_SMS':
      case 'SMS':
      case 'MESSAGE':
      case 'TEXT':
        return IntentType.sendSms;
      case 'OPEN_APP':
      case 'LAUNCH_APP':
      case 'OPEN':
      case 'OPEN_WEB':
        return IntentType.openApp;
      case 'BATTERY':
      case 'BATTERY_INFO':
      case 'CHECK_BATTERY':
      case 'GET_BATTERY':
        return IntentType.batteryInfo;
      case 'WEATHER':
      case 'WEATHER_INFO':
      case 'CHECK_WEATHER':
      case 'GET_WEATHER':
        return IntentType.weatherInfo;
      case 'SET_VOLUME': // 🚀 New case
      case 'VOLUME':
      case 'ADJUST_VOLUME':
        return IntentType.setVolume;
      case 'SET_BRIGHTNESS': // 🚀 New case
      case 'BRIGHTNESS':
        return IntentType.setBrightness;
      case 'MUTE': // 🚀 New case
      case 'UNMUTE':
      case 'TOGGLE_MUTE':
        return IntentType.mute;
      default:
        return IntentType.none;
    }
  }

  static Map<String, String> _parseParams(String paramStr) {
    final map = <String, String>{};
    if (paramStr.isEmpty) return map;

    // Split by either | or , (handles LLM formatting variations)
    final segments = paramStr.split(RegExp(r'[|,]'));

    for (final segment in segments) {
      try {
        if (!segment.contains('=')) continue;

        final kv = segment.split('=');
        if (kv.length >= 2) {
          final key = kv[0].trim().toLowerCase();
          // Join the rest in case the value itself contains an '='
          final value = kv.sublist(1).join('=').trim();
          if (key.isNotEmpty) map[key] = value;
        }
      } catch (e) {
        print('[IntentService] Param segment error: $e');
      }
    }
    return map;
  }
}

class ParsedResponse {
  final String cleanText;
  final DetectedIntent intent;
  ParsedResponse({required this.cleanText, required this.intent});
}
