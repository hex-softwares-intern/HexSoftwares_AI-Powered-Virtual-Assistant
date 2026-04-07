// lib/core/services/groq_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';

class GroqService {
  static const _baseUrl = 'https://api.groq.com/openai/v1';

  // 🚀 PRIMARY: Use 8b-instant for < 1s response times.
  static const _primaryModel = 'llama-3.1-8b-instant';
  static const _largeModel = 'llama-3.3-70b-versatile';

  final Dio _dio;
  final String _apiKey;

  GroqService({required String apiKey})
    : _apiKey = apiKey,
      _dio = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 60),
          headers: {'Content-Type': 'application/json'},
        ),
      );

  /// Streams response from Groq.
  /// Injects real-time systemContext (Battery, Location, Calendar) into the prompt.
  Stream<String> chatStream({
    required String userMessage,
    String systemContext = '',
    List<Map<String, String>> history = const [],
    bool useLargeModel = false,
  }) async* {
    // Default to the fast model for instant execution
    final model = useLargeModel ? _largeModel : _primaryModel;

    // Clean history to remove previous intent tags so the model doesn't get confused
    final cleanHistory = history.map((m) {
      return {
        'role': m['role']!,
        'content': m['content']!
            .replaceAll(RegExp(r'\[INTENT:[^\]]*\]'), '')
            .trim(),
      };
    }).toList();

    // Keep history lean for performance
    final limitedHistory = cleanHistory.length > 6
        ? cleanHistory.sublist(cleanHistory.length - 6)
        : cleanHistory;

    final messages = [
      {'role': 'system', 'content': _getSystemPrompt(systemContext)},
      ...limitedHistory,
      {'role': 'user', 'content': userMessage},
    ];

    try {
      final response = await _dio.post(
        '/chat/completions',
        options: Options(
          headers: {'Authorization': 'Bearer $_apiKey'},
          responseType: ResponseType.stream,
        ),
        data: {
          'model': model,
          'messages': messages,
          'temperature': 0.6, // Balanced for storytelling and accuracy
          'max_tokens': 1024, // Increased to allow long stories
          'stream': true,
        },
      );

      final Stream<String> lineStream = (response.data.stream as Stream)
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lineStream) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || !trimmed.startsWith('data: ')) continue;

        final data = trimmed.substring(6);
        if (data == '[DONE]') return;

        try {
          final json = jsonDecode(data);
          final choices = json['choices'] as List;
          if (choices.isEmpty) continue;

          final delta = choices[0]['delta']['content'] as String?;
          if (delta != null) yield delta;
        } catch (e) {
          continue;
        }
      }
    } on DioException catch (e) {
      // Manual failover logic removed to keep code exactly as requested,
      // but error handling remains.
      print('[Groq] Connection Error: ${e.message}');
      throw Exception('Groq connection failed');
    }
  }

  /// Constructs the system prompt with hardware status and strict action rules.
  static String _getSystemPrompt(String systemContext) {
    final now = DateTime.now();
    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    return '''You are ARIA, a helpful AI assistant. 
Today is ${_days[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]} ${now.year}. 
Current Time: $timeStr

REAL-TIME SYSTEM DATA:
$systemContext

RULES:
- Be helpful and conversational. No word limit; if asked for a long story, provide it.
- No markdown (no bold, no lists).
- If an action is requested, append EXACTLY ONE tag at the end.
- Use the SYSTEM DATA above to answer battery, weather, or calendar questions.
- MUSIC: For BlackHole, use app=blackhole. For YMusic, use app=ymusic.
- DO NOT add an intent tag for polite phrases like "thank you", "okay", or "bye".

TAGS:
- Volume: [INTENT:SET_VOLUME|level=0-100] (Use this if user asks for specific level or "increase/decrease")
- Mute/Unmute: [INTENT:MUTE]
- Brightness: [INTENT:SET_BRIGHTNESS|level=0-100]
- WhatsApp: [INTENT:WHATSAPP|number=NAME|message=text|type=message]
- Call: [INTENT:CALL|target=NAME]
- Alarm: [INTENT:SET_ALARM|hour=H|minute=M|label=text]
- Calendar: [INTENT:CREATE_CALENDAR|title=text|date=$todayStr|time=HH:mm]
- Music: [INTENT:PLAY_MUSIC|query=text|app=blackhole/ymusic/spotify]
- SMS: [INTENT:SEND_SMS|number=NAME|message=text]
- View Calendar: [INTENT:VIEW_CALENDAR]
- Open App: [INTENT:OPEN_APP|name=APP_NAME]''';
  }

  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
}
