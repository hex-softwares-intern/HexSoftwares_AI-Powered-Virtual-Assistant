import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:vosk_flutter/vosk_flutter.dart';
import 'audio_recorder_base.dart';

class AudioRecorderWindowsService implements AudioRecorderServiceBase {
  final _record = AudioRecorder();
  final _vosk = VoskFlutterPlugin.instance();

  Model? _model;
  Recognizer? _recognizer;
  StreamSubscription? _wakeWordStreamSub;
  StreamSubscription? _ampStreamSub;
  bool _modelLoaded = false;
  String? _selectedDeviceId;

  final _amplitudeController = StreamController<double>.broadcast();
  final _wakeWordController =
      StreamController<Map<String, dynamic>>.broadcast();

  bool _isRecording = false;
  bool _isWakeWordActive = false;

  @override
  bool get isRecording => _isRecording;
  @override
  bool get isWakeWordActive => _isWakeWordActive;
  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;
  @override
  Stream<Map<String, dynamic>> get onWakeWord => _wakeWordController.stream;

  void setDeviceId(String id) {
    _selectedDeviceId = id;
    print('[Windows] 🎤 Mic set to: $id');
  }

  Future<InputDevice?> _getRealMic() async {
    final devices = await _record.listInputDevices();
    if (_selectedDeviceId != null) {
      final selected = devices.firstWhere(
        (d) => d.id == _selectedDeviceId,
        orElse: () => devices.first,
      );
      print('[Windows] 🎤 Using user-selected mic: ${selected.label}');
      return selected;
    }
    print('[Windows] 🎤 Using Windows default mic');
    return null;
  }

  @override
  Future<void> init() async {
    if (_modelLoaded) return;
    try {
      String modelPath = p.join(Directory.current.path, 'assets', 'vosk-model');
      if (!Directory(modelPath).existsSync()) {
        modelPath = p.join(
          Directory.current.path,
          'data',
          'flutter_assets',
          'assets',
          'vosk-model',
        );
      }
      print('[Windows] 📂 Loading Vosk: $modelPath');
      _model = await _vosk.createModel(modelPath);
      _recognizer = await _vosk.createRecognizer(
        model: _model!,
        sampleRate: 16000,
        grammar: [
          "hey jarvis",
          "ok jarvis",
          "okay jarvis",
          "hey aria",
          "ok aria",
          "[unk]",
        ],
      );
      _modelLoaded = true;
      print('[Windows] Vosk Ready ✅');
    } catch (e) {
      print('[Windows] ❌ Init Error: $e');
    }
  }

  @override
  Future<void> startWakeWordDetection() async {
    if (_isWakeWordActive || _recognizer == null) return;
    _isWakeWordActive = true;

    final mic = await _getRealMic();
    print('[Windows] 👂 Wake word mic: ${mic?.label ?? "Windows default"}');

    final stream = await _record.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        device: mic,
      ),
    );

    _wakeWordStreamSub = stream.listen((Uint8List chunk) async {
      if (!_isWakeWordActive) return;
      final resultReady = await _recognizer!.acceptWaveformBytes(chunk);
      if (resultReady) {
        final jsonStr = await _recognizer!.getResult();
        final result = jsonDecode(jsonStr);
        final text = (result['text'] ?? '').toLowerCase();
        if (text.isNotEmpty) print('[Vosk] Heard: "$text"');
        if (text.contains("jarvis") || text.contains("aria")) {
          print("🔥 WAKE WORD DETECTED!");
          _wakeWordController.add({"phrase": text, "type": "vosk"});
        }
      }
    });
  }

  @override
  Future<void> stopWakeWordDetection() async {
    _isWakeWordActive = false;
    await _wakeWordStreamSub?.cancel();
    await _record.stop();
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<String> startRecording() async {
    if (_isWakeWordActive) await stopWakeWordDetection();
    if (_isRecording) await stopRecording();

    final mic = await _getRealMic();
    print('[Windows] 🎤 Recording with: ${mic?.label ?? "Windows default"}');

    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      'rec_${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    await _record.start(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        device: mic,
      ),
      path: path,
    );

    _isRecording = true;
    _startAmplitudeTimer();
    return path;
  }

  void _startAmplitudeTimer() {
    _ampStreamSub?.cancel();

    // Use a secondary AudioRecorder just for amplitude monitoring
    final ampRecorder = AudioRecorder();
    Timer? timer;

    timer = Timer.periodic(const Duration(milliseconds: 80), (t) async {
      if (!_isRecording) {
        t.cancel();
        await ampRecorder.dispose();
        return;
      }
      try {
        final amp = await _record.getAmplitude();
        double value = amp.current;

        // Handle -Infinity from Windows
        if (value.isInfinite || value.isNaN || value < -100) value = -100.0;

        // Map -100..0 dB → 0..100 for VadService
        final mapped = value + 100; // now 0..100
        if (!_amplitudeController.isClosed) {
          _amplitudeController.add(mapped);
        }
      } catch (_) {}
    });

    // Store timer reference for cleanup
    _ampTimer = timer;
  }

  Timer? _ampTimer;

  @override
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    _isRecording = false;
    _ampTimer?.cancel();
    _ampStreamSub?.cancel();
    return await _record.stop();
  }

  @override
  void startContinuousLoop({required Function(String path) onCommandReady}) {}
  @override
  Future<void> stopContinuousLoop() async => await stopRecording();

  @override
  Future<void> dispose() async {
    await _wakeWordStreamSub?.cancel();
    _ampTimer?.cancel();
    _ampStreamSub?.cancel();
    await _record.dispose();
    await _recognizer?.dispose();
    if (!_amplitudeController.isClosed) await _amplitudeController.close();
    if (!_wakeWordController.isClosed) await _wakeWordController.close();
  }
}
