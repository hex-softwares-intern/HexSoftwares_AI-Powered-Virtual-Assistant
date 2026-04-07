// lib/features/assistant/assistant_provider.dart

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:ai_assistant/core/services/audio_recorder_windows.dart';
import 'package:ai_assistant/core/services/audio_recorder_base.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:location/location.dart' as loc;
import 'package:record/record.dart';
import 'package:ai_assistant/core/models/assistant_state.dart';
import 'package:ai_assistant/core/services/whisper_service.dart';
import 'package:ai_assistant/core/services/groq_service.dart';
import 'package:ai_assistant/core/services/audio_recorder_io.dart';
import 'package:ai_assistant/core/services/vad_service.dart';
import 'package:ai_assistant/core/services/intent_service.dart';
import 'package:ai_assistant/core/services/intent_executor.dart';
import 'package:ai_assistant/core/services/android_platform_service.dart';
import 'package:ai_assistant/core/services/windows_platform_service.dart'; // 🚀 Added
import 'package:ai_assistant/core/services/weather_service.dart';

part 'assistant_provider.g.dart';

class AssistantData {
  final AssistantState state;
  final String? responseText;
  final String? transcribedText;
  final List<double> waveAmplitudes;
  final bool isSpeechActive;

  const AssistantData({
    this.state = AssistantState.idle,
    this.responseText,
    this.transcribedText,
    this.waveAmplitudes = const [],
    this.isSpeechActive = false,
  });

  AssistantData copyWith({
    AssistantState? state,
    Object? responseText = _s,
    Object? transcribedText = _s,
    List<double>? waveAmplitudes,
    bool? isSpeechActive,
  }) {
    return AssistantData(
      state: state ?? this.state,
      isSpeechActive: isSpeechActive ?? this.isSpeechActive,
      responseText: responseText == _s
          ? this.responseText
          : responseText as String?,
      transcribedText: transcribedText == _s
          ? this.transcribedText
          : transcribedText as String?,
      waveAmplitudes: waveAmplitudes ?? this.waveAmplitudes,
    );
  }
}

const Object _s = Object();

enum _Mode { idle, wakeWord, listening, thinking }

@riverpod
class Assistant extends _$Assistant {
  final _storage = const FlutterSecureStorage();

  late WhisperService _whisper;
  late AudioRecorderServiceBase _recorder;
  final _weatherService = WeatherService();

  GroqService? _groq;
  VadService? _vad;

  StreamSubscription? _wakeWordSub;
  _Mode _mode = _Mode.idle;

  String? _selectedDeviceId;
  bool _isInitializing = false;

  bool _intentHandledLocally = false;
  final List<Map<String, String>> _history = [];

  @override
  AssistantData build() {
    Future.microtask(_init);
    ref.onDispose(_dispose);
    return const AssistantData();
  }

  // ── INIT ─────────────────────────────────────────────────────

  Future<void> _init() async {
    if (_isInitializing) return;
    _isInitializing = true;

    if (Platform.isAndroid) {
      await [
        Permission.microphone,
        Permission.contacts,
        Permission.phone,
        Permission.sms,
        Permission.calendarFullAccess,
        Permission.scheduleExactAlarm,
        Permission.location,
      ].request();

      try {
        loc.Location locationService = loc.Location();
        bool serviceEnabled = await locationService.serviceEnabled();
        if (!serviceEnabled) {
          serviceEnabled = await locationService.requestService();
        }
      } catch (e) {
        print('[Assistant] GPS hardware prompt error: $e');
      }
    }

    final apiKey = await _getApiKey();
    _whisper = WhisperService(apiKey: apiKey);
    _groq = GroqService(apiKey: apiKey);
    _recorder = createRecorder();

    if (Platform.isAndroid) {
      await _recorder.init();
      _wakeWordSub = _recorder.onWakeWord.listen((_) => _onWakeWordDetected());
      await _startWakeWord();
    } else if (Platform.isWindows) {
      final savedMic = await _storage.read(key: 'selected_mic_id');
      if (savedMic != null && savedMic.isNotEmpty) {
        print('[Assistant] Found saved Mic. Forwarding to Windows Engine.');
        await initializeWindowsEngine(savedMic);
      } else {
        print(
          '[Assistant] No saved Mic found. Waiting for user to select one.',
        );
      }
    }
    _isInitializing = false;
  }

  // ── WINDOWS SPECIFIC BRIDGE ──────────────────────────────────

  Future<List<InputDevice>> getAvailableMicrophones() async {
    try {
      return await (_recorder as dynamic).getDevices();
    } catch (e) {
      final record = AudioRecorder();
      final devices = await record.listInputDevices();
      record.dispose();
      return devices;
    }
  }

  Future<void> initializeWindowsEngine(String deviceId) async {
    if (!Platform.isWindows) return;
    if (_selectedDeviceId == deviceId) return;

    try {
      print('[Assistant] Initializing Windows Engine: $deviceId');
      await _storage.write(key: 'selected_mic_id', value: deviceId);
      _selectedDeviceId = deviceId;

      if (_recorder.isWakeWordActive) await _recorder.stopWakeWordDetection();

      if (_recorder is AudioRecorderWindowsService) {
        (_recorder as AudioRecorderWindowsService).setDeviceId(deviceId);
      }

      await _recorder.init();

      _wakeWordSub?.cancel();
      _wakeWordSub = _recorder.onWakeWord.listen((_) => _onWakeWordDetected());

      await _startWakeWord();
      print('[Assistant] Windows Engine Ready ✅');
    } catch (e) {
      print('[Assistant] Windows Init Failed: $e');
    }
  }

  // ── API KEY ──────────────────────────────────────────────────

  Future<String> _getApiKey() async {
    String? key = await _storage.read(key: 'groq_api_key');
    if (key == null || key.isEmpty || key == 'YOUR_FALLBACK_KEY') {
      return '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';
    }
    return key;
  }

  // ── WAKE WORD ────────────────────────────────────────────────

  Future<void> _startWakeWord() async {
    if (_mode != _Mode.idle) return;
    _mode = _Mode.wakeWord;

    if (_recorder.isRecording) await _recorder.stopRecording();

    await _recorder.startWakeWordDetection();
    state = state.copyWith(state: AssistantState.idle);
  }

  void _onWakeWordDetected() {
    if (_mode != _Mode.wakeWord) return;
    print('[Assistant] 🚦 Wake Word caught!');
    startListening();
  }

  // ── LISTENING ────────────────────────────────────────────────

  Future<void> startListening() async {
    if (_mode == _Mode.listening) return;

    _vad?.dispose();
    _vad = null;

    if (_recorder.isWakeWordActive) {
      await _recorder.stopWakeWordDetection();
      if (Platform.isWindows) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    _mode = _Mode.listening;
    state = const AssistantData(state: AssistantState.listening);

    try {
      await _recorder.startRecording();
      await Future.delayed(const Duration(milliseconds: 250));

      _vad = VadService(
        amplitudeStream: _recorder.amplitudeStream,
        calibrationMs: 800,
        silenceTriggerMs: 1500,
        speechDeltaDb: 12.0,
        onSpeechStart: () => print('[Assistant] VAD: Speech Started'),
        onSpeechEnd: () => stopListening(),
        onAmplitude: (normalized) {
          double display = Platform.isWindows
              ? (normalized * 5.0).clamp(0.0, 1.0)
              : normalized;

          if (Random().nextDouble() < 0.05) {
            print(
              '[VAD Debug] 🎤 Mic Level: ${(display * 100).toStringAsFixed(1)}%',
            );
          }

          if (state.state != AssistantState.listening) return;

          final rng = Random();
          state = state.copyWith(
            waveAmplitudes: List.generate(6, (i) {
              final base = display.clamp(0.1, 1.0);
              return (base * (0.7 + rng.nextDouble() * 0.3)).clamp(0.1, 1.0);
            }),
          );
        },
      );
    } catch (e) {
      print('[Assistant] Hardware Crash Prevented: $e');
      _resetToIdle();
    }
  }

  // ── STOP LISTENING ───────────────────────────────────────────

  Future<void> stopListening() async {
    if (_mode != _Mode.listening) return;
    _mode = _Mode.thinking;

    _vad?.dispose();
    _vad = null;

    state = state.copyWith(
      state: AssistantState.thinking,
      waveAmplitudes: const [],
    );

    final path = await _recorder.stopRecording();
    if (path == null || path.isEmpty) {
      _resetToIdle();
      return;
    }

    final text = await _whisper.transcribe(path);

    final cleanText = text?.trim().toLowerCase() ?? '';
    if (cleanText.isEmpty ||
        cleanText == "thank you." ||
        cleanText == "thanks for watching." ||
        cleanText == "thank you") {
      print('[Assistant] 🤫 Silence/Hallucination detected, ignoring...');
      _resetToIdle();
      return;
    }

    // 🚀 SPEED FIX: Immediate UI update so the user knows we're processing
    state = state.copyWith(transcribedText: text, responseText: "Thinking...");

    final actionWords = [
      'open',
      'launch',
      'set',
      'increase',
      'decrease',
      'mute',
      'unmute',
      'go to',
      'check for',
      'reduce',
      'raise',
    ];
    bool isAction = actionWords.any((word) => cleanText.startsWith(word));

    if (isAction) {
      final directIntent = DetectedIntent(
        type: IntentType.none,
        rawText: text!,
      );
      _intentHandledLocally = await IntentExecutor.execute(directIntent);

      if (_intentHandledLocally) {
        print('[Assistant] ✅ Handled locally, skipping AI stream.');
        state = state.copyWith(
          state: AssistantState.idle,
          responseText: "Command Executed.",
        );
        _resetToIdle();
        return;
      }
    } else {
      _intentHandledLocally = false;
    }

    _history.add({'role': 'user', 'content': text!});
    await _streamResponse();
  }

  // ── AI RESPONSE (Unified Windows & Android) ─────────────────

  Future<void> _streamResponse() async {
    try {
      final userMessage = _history.last['content']!;
      String fullResponse = '';
      String systemContext = "System Status: Online.";

      try {
        if (Platform.isAndroid) {
          final stats = await AndroidPlatformService.getSystemStats();
          final batteryLevel = stats['battery']?['level'] ?? "unknown";
          final chargingStatus = stats['battery']?['isCharging'] == true
              ? "charging"
              : "not charging";

          String weatherText = "Location unknown.";
          if (stats['location'] != null) {
            weatherText = await _weatherService.getWeather(
              stats['location']['lat'],
              stats['location']['lon'],
            );
          }

          systemContext =
              """
Current Date: ${DateTime.now().toLocal().toString().split(' ')[0]}
Current Time: ${DateTime.now().toLocal().toString().split(' ')[1].substring(0, 5)}
Device Battery: $batteryLevel% ($chargingStatus).
Current Weather: $weatherText
""";
        } else if (Platform.isWindows) {
          final stats = await WindowsPlatformService.getSystemStats();
          final ram = stats['ram'] ?? "Unknown";
          final battLevel = stats['battery']?['level'] ?? "100";
          final isCharging = stats['battery']?['isCharging'] == true
              ? "Plugged in"
              : "On Battery";

          String weatherText = "Location unavailable.";
          if (stats['location'] != null && stats['location']['lat'] != 0.0) {
            try {
              weatherText = await _weatherService.getWeather(
                stats['location']['lat'],
                stats['location']['lon'],
              );
            } catch (e) {
              print('[Assistant] Weather Fetch Error: $e');
              weatherText = "Weather service error.";
            }
          }

          systemContext =
              """
Current Time: ${DateTime.now().toLocal().toString().split(' ')[1].substring(0, 5)}
System: Windows Desktop
RAM Available: $ram
Battery: $battLevel% ($isCharging)
Current Weather: $weatherText
Status: All systems nominal.
IMPORTANT: When the user asks for status, describe the info above. DO NOT include [INTENT] tags to open apps unless specifically asked to "OPEN" something.
""";
        }
      } catch (e) {
        print('[Assistant] System Context Error: $e');
        systemContext = "System stats temporarily unavailable.";
      }

      // ── START GROQ STREAM ──
      await for (final chunk in _groq!.chatStream(
        userMessage: userMessage,
        systemContext: systemContext,
        history: _history.sublist(0, _history.length - 1),
      )) {
        fullResponse += chunk;

        final partialClean = fullResponse
            .replaceAll(RegExp(r'\[INTENT:[^\]]*\]?'), '')
            .trim();

        state = state.copyWith(
          state: AssistantState.speaking,
          responseText: partialClean,
        );
      }

      // ── PARSE & EXECUTE INTENTS ──
      final parsed = IntentService.parse(fullResponse);
      _history.add({'role': 'assistant', 'content': parsed.cleanText});

      if (_history.length > 20) _history.removeRange(0, _history.length - 20);

      state = state.copyWith(
        state: AssistantState.idle,
        responseText: parsed.cleanText,
      );

      if (!_intentHandledLocally && parsed.intent.type != IntentType.none) {
        await IntentExecutor.execute(parsed.intent);
      }

      await Future.delayed(const Duration(milliseconds: 1500));
      _resetToIdle();
    } catch (e) {
      print('[Assistant] Stream Response Error: $e');
      state = state.copyWith(
        state: AssistantState.idle,
        responseText: 'Connection lost. Retrying...',
      );
      _resetToIdle();
    }
  }

  // ── HELPERS ──────────────────────────────────────────────────

  Future<void> _resetToIdle() async {
    _mode = _Mode.idle;
    await Future.delayed(const Duration(milliseconds: 500));
    await _startWakeWord();
  }

  Future<void> toggleListening() async {
    if (_mode == _Mode.listening) {
      await stopListening();
    } else {
      if (_recorder.isWakeWordActive) await _recorder.stopWakeWordDetection();
      _mode = _Mode.idle;
      await startListening();
    }
  }

  Future<void> handleTextInput(String text) async {
    if (_recorder.isWakeWordActive) await _recorder.stopWakeWordDetection();
    _mode = _Mode.thinking;
    _intentHandledLocally = false;
    state = state.copyWith(
      state: AssistantState.thinking,
      transcribedText: text,
      responseText: "Thinking...",
    );
    _history.add({'role': 'user', 'content': text});
    await _streamResponse();
  }

  void clearResponse() {
    if (state.state != AssistantState.speaking) {
      state = state.copyWith(responseText: null, transcribedText: null);
    }
  }

  Future<void> _dispose() async {
    _wakeWordSub?.cancel();
    _vad?.dispose();
    await _recorder.dispose();
  }
}
