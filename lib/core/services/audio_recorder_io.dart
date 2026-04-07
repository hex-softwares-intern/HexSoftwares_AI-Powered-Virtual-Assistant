import 'dart:io';
import 'audio_recorder_base.dart';
import 'audio_recorder_mobile.dart';
import 'audio_recorder_windows.dart';

AudioRecorderServiceBase createRecorder() {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    return AudioRecorderWindowsService();
  }
  return AudioRecorderService();
}
