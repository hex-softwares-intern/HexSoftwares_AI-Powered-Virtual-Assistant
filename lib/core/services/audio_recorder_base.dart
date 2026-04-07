import 'dart:async';

abstract class AudioRecorderServiceBase {
  bool get isRecording;
  bool get isWakeWordActive;
  Stream<double> get amplitudeStream;
  Stream<Map<String, dynamic>> get onWakeWord;

  Future<void> init();
  void startContinuousLoop({required Function(String path) onCommandReady});
  Future<void> stopContinuousLoop();
  Future<void> startWakeWordDetection();
  Future<void> stopWakeWordDetection();
  Future<String> startRecording();
  Future<String?> stopRecording();
  Future<void> dispose();
}
