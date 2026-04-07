import 'dart:async';

/// Voice Activity Detection — pure logic, no audio dependencies.
/// Listens to amplitude stream, detects speech start/end.
class VadService {
  // Calibration
  double _noiseFloor = 0.0;
  double _speechLevel = 0.0;
  bool _calibrated = false;
  final _calibSamples = <double>[];

  // State
  bool _isSpeaking = false;
  bool _hasSpeech = false;
  int _silenceMs = 0;
  int _startupMs = 0;

  // Config
  final int calibrationMs; // ms to calibrate noise floor
  final int silenceTriggerMs; // ms of silence to trigger end
  final double speechDeltaDb; // dB above noise floor = speech

  // Callbacks
  final void Function() onSpeechStart;
  final void Function() onSpeechEnd;
  final void Function(double) onAmplitude;

  StreamSubscription? _sub;

  VadService({
    required Stream<double> amplitudeStream,
    required this.onSpeechStart,
    required this.onSpeechEnd,
    required this.onAmplitude,
    this.calibrationMs = 600,
    this.silenceTriggerMs = 2000,
    this.speechDeltaDb = 12.0,
  }) {
    _sub = amplitudeStream.listen(_process);
  }

  bool get hasSpeech => _hasSpeech;
  bool get isSpeaking => _isSpeaking;

  void _process(double db) {
    if (db.isInfinite || db.isNaN) return;
    _startupMs += 80;

    // ── Phase 1: Calibration ─────────────────────────────────────
    if (_startupMs <= calibrationMs) {
      if (db > 0) _calibSamples.add(db);
      onAmplitude(0.05); // gentle pulse during calibration
      return;
    }

    if (!_calibrated) {
      _calibrated = true;
      if (_calibSamples.isNotEmpty) {
        _calibSamples.sort();
        // 75th percentile = stable noise floor
        final idx = (_calibSamples.length * 0.75).round().clamp(
          0,
          _calibSamples.length - 1,
        );
        _noiseFloor = _calibSamples[idx];
        _speechLevel = _noiseFloor + speechDeltaDb;
        print(
          '[VAD] Calibrated: floor=${_noiseFloor.toStringAsFixed(1)} '
          'speech=${_speechLevel.toStringAsFixed(1)}',
        );
      } else {
        // Fallback if no samples
        _noiseFloor = 5.0;
        _speechLevel = 17.0;
      }
    }

    // ── Phase 2: Detection ───────────────────────────────────────
    final isSpeaking = db > _speechLevel;

    // Normalize amplitude for UI (0.0 to 1.0)
    final normalized = _speechLevel > 0
        ? ((db - _noiseFloor) / (_speechLevel * 1.5)).clamp(0.0, 1.0)
        : 0.0;
    onAmplitude(normalized);

    if (isSpeaking) {
      _silenceMs = 0;
      if (!_isSpeaking) {
        _isSpeaking = true;
        if (!_hasSpeech) {
          _hasSpeech = true;
          print('[VAD] Speech started (db=$db)');
          onSpeechStart();
        }
      }
    } else {
      if (_isSpeaking) {
        _isSpeaking = false;
      }
      if (_hasSpeech) {
        _silenceMs += 80;
        if (_silenceMs >= silenceTriggerMs) {
          print('[VAD] Silence ${_silenceMs}ms → trigger end');
          _hasSpeech = false;
          _silenceMs = 0;
          onSpeechEnd();
        }
      }
    }
  }

  void reset() {
    _isSpeaking = false;
    _hasSpeech = false;
    _silenceMs = 0;
    _startupMs = 0;
    _calibrated = false;
    _noiseFloor = 0.0;
    _speechLevel = 0.0;
    _calibSamples.clear();
  }

  void dispose() {
    _sub?.cancel();
  }
}
