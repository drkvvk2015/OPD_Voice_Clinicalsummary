class AudioService {
  bool _recording = false;
  String? _activeSessionId;

  bool get isRecording => _recording;
  String? get activeSessionId => _activeSessionId;

  Future<String> startRecording() async {
    _recording = true;
    _activeSessionId = 'audio_session_${DateTime.now().millisecondsSinceEpoch}';
    return _activeSessionId!;
  }

  Future<String?> stopRecording() async {
    _recording = false;
    final session = _activeSessionId;
    _activeSessionId = null;
    return session;
  }
}
