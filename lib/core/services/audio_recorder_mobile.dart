import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

import 'vad_service.dart';
import 'audio_recorder_base.dart';

class AudioRecorderService implements AudioRecorderServiceBase {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  static const _wakeMethodChannel = MethodChannel(
    'com.yourname.ai_assistant/wake_word',
  );
  static const _wakeEventChannel = EventChannel(
    'com.yourname.ai_assistant/wake_word_events',
  );

  StreamSubscription? _wakeWordSub;
  final _wakeWordController =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get onWakeWord => _wakeWordController.stream;

  bool _isRecording = false;
  bool _isInitialized = false;
  bool _wakeWordActive = false;
  String? _currentPath;

  StreamSubscription? _progressSub;
  final _amplitudeController = StreamController<double>.broadcast();

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;
  @override
  bool get isRecording => _isRecording;
  @override
  bool get isWakeWordActive => _wakeWordActive;

  VadService? _vad;
  StreamSubscription? _loopSub;
  Timer? _noSpeechTimeout;

  @override
  Future<void> init() async {
    if (_isInitialized) return;
    if (Platform.isAndroid) {
      final mic = await Permission.microphone.request();
      if (!mic.isGranted) throw Exception('Microphone permission denied');
    }
    _isInitialized = true;
    print('[Recorder] Initialized ✅');
  }

  @override
  void startContinuousLoop({
    required Function(String path) onCommandReady,
  }) async {
    if (!Platform.isAndroid) return;
    await _loopSub?.cancel();
    _loopSub = onWakeWord.listen((event) async {
      if (event.containsKey('keyword')) {
        print('[Loop] Wake word recognized. Switching to Command Mode...');
        await startRecording();

        _vad?.dispose();
        _vad = VadService(
          amplitudeStream: amplitudeStream,
          onSpeechStart: () {
            print('[Loop] User started talking...');
            _noSpeechTimeout?.cancel();
          },
          // ✅ EXACT FIX: Added the required onAmplitude callback
          onAmplitude: (double amp) {
            // Satisfies required parameter without changing VadService
          },
          onSpeechEnd: () async {
            print('[Loop] Silence detected. Ending command.');
            final path = await stopRecording();
            if (path != null) onCommandReady(path);

            print('[Loop] Returning to Wake Word detection...');
            await startWakeWordDetection();
          },
        );

        _noSpeechTimeout?.cancel();
        _noSpeechTimeout = Timer(const Duration(seconds: 5), () async {
          if (!(_vad?.hasSpeech ?? false)) {
            print('[Loop] Timeout: No speech detected after wake word.');
            await stopRecording();
            await startWakeWordDetection();
          }
        });
      }
    });
    await startWakeWordDetection();
  }

  @override
  Future<void> stopContinuousLoop() async {
    _noSpeechTimeout?.cancel();
    await _loopSub?.cancel();
    _loopSub = null;
    await stopWakeWordDetection();
    if (_isRecording) await stopRecording();
  }

  @override
  Future<void> startWakeWordDetection() async {
    if (!Platform.isAndroid || _wakeWordActive) return;
    if (_isRecording) await stopRecording();

    if (_isInitialized) {
      try {
        await _recorder.closeRecorder();
      } catch (_) {}
      _isInitialized = false;
    }

    _wakeWordSub?.cancel();
    _wakeWordSub = _wakeEventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map && !_wakeWordController.isClosed) {
        final data = Map<String, dynamic>.from(event);
        if (data.containsKey('keyword')) _wakeWordController.add(data);
      }
    });

    await _wakeMethodChannel.invokeMethod('start');
    _wakeWordActive = true;
    print('[WakeWord] Listening... 👂');
  }

  @override
  Future<void> stopWakeWordDetection() async {
    if (!Platform.isAndroid || !_wakeWordActive) return;
    await _wakeMethodChannel.invokeMethod('stop');
    _wakeWordActive = false;
    _wakeWordSub?.cancel();
    print('[WakeWord] Stopped ❌');
  }

  @override
  Future<String> startRecording() async {
    if (!Platform.isAndroid) return 'bypass_path';
    if (_isRecording) await stopRecording();
    if (_wakeWordActive) await stopWakeWordDetection();
    if (!_isInitialized) await init();

    await _recorder.openRecorder();
    await _recorder.setSubscriptionDuration(const Duration(milliseconds: 80));

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/aria_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.startRecorder(
      toFile: path,
      codec: Codec.pcm16WAV,
      sampleRate: 16000,
      numChannels: 1,
    );

    _currentPath = path;
    _isRecording = true;

    _progressSub = _recorder.onProgress?.listen((e) {
      if (e.decibels != null && !_amplitudeController.isClosed) {
        _amplitudeController.add(e.decibels!);
      }
    });

    print('[Recorder] Recording started 🎤: $path');
    return path;
  }

  @override
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    _isRecording = false;
    _progressSub?.cancel();

    try {
      final path = await _recorder.stopRecorder();
      await _recorder.closeRecorder();
      _isInitialized = false;
      return path ?? _currentPath;
    } catch (e) {
      print('[Recorder] Stop error: $e');
      return _currentPath;
    }
  }

  @override
  Future<void> dispose() async {
    await stopContinuousLoop();
    _vad?.dispose();

    if (Platform.isAndroid && _wakeWordActive) {
      await _wakeMethodChannel.invokeMethod('stop').catchError((_) {});
    }

    _wakeWordSub?.cancel();
    if (!_wakeWordController.isClosed) await _wakeWordController.close();
    if (!_amplitudeController.isClosed) await _amplitudeController.close();

    if (Platform.isAndroid) {
      try {
        await _recorder.closeRecorder();
      } catch (_) {}
    }
  }
}
