import 'dart:io';
import 'dart:typed_data';

import 'package:record/record.dart';

class RecordingPermissionException implements Exception {
  RecordingPermissionException(this.message);

  final String message;

  @override
  String toString() => 'RecordingPermissionException: $message';
}

class VoiceRecorder {
  VoiceRecorder({AudioRecorder? recorder}) : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  bool _isRecording = false;
  Directory? _workingDirectory;
  String? _recordingPath;

  bool get isRecording => _isRecording;

  Future<void> initialise() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw RecordingPermissionException('Microphone permission not granted');
    }
  }

  Future<void> start() async {
    if (_isRecording) {
      return;
    }
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw RecordingPermissionException('Microphone permission not granted');
    }
    final directory = await Directory.systemTemp.createTemp('dream_recorder_');
    final path = '${directory.path}/capture.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    _workingDirectory = directory;
    _recordingPath = path;
    _isRecording = true;
  }

  Future<Uint8List?> stop() async {
    if (!_isRecording) {
      return null;
    }
    final path = await _recorder.stop() ?? _recordingPath;
    _isRecording = false;
    _recordingPath = null;
    if (path == null) {
      return null;
    }
    final file = File(path);
    final bytes = await file.readAsBytes();
    await file.delete();
    final directory = _workingDirectory;
    _workingDirectory = null;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
    return Uint8List.fromList(bytes);
  }
}
