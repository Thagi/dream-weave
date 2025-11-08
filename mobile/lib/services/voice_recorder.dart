import 'dart:io';
import 'dart:typed_data';

import 'package:record/record.dart';

class VoiceRecorder {
  VoiceRecorder({Record? record}) : _record = record ?? Record();

  final Record _record;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  Future<void> initialise() async {
    final hasPermission = await _record.hasPermission();
    if (!hasPermission) {
      throw RecordingPermissionException('Microphone permission not granted');
    }
  }

  Future<void> start() async {
    if (_isRecording) {
      return;
    }
    final hasPermission = await _record.hasPermission();
    if (!hasPermission) {
      throw RecordingPermissionException('Microphone permission not granted');
    }
    await _record.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    _isRecording = true;
  }

  Future<Uint8List?> stop() async {
    if (!_isRecording) {
      return null;
    }
    final path = await _record.stop();
    _isRecording = false;
    if (path == null) {
      return null;
    }
    final file = File(path);
    final bytes = await file.readAsBytes();
    await file.delete();
    return Uint8List.fromList(bytes);
  }
}
