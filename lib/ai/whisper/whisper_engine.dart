import '../contracts/whisper_adapter.dart';

class WhisperEngine {
  WhisperEngine(this._adapter);

  final WhisperAdapter _adapter;

  Future<String> transcribe(String audioSessionId, {String languageHint = 'en'}) {
    return _adapter.transcribe(audioSessionId, languageHint: languageHint);
  }
}
