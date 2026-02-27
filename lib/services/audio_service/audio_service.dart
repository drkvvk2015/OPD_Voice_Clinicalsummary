class AudioService {
  bool _recording = false;

  bool get isRecording => _recording;

  Future<String> startRecording() async {
    _recording = true;
    return 'audio_session_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> stopRecording() async {
    _recording = false;
  }
}
