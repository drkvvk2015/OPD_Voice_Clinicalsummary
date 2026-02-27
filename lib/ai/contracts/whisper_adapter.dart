abstract class WhisperAdapter {
  Future<String> transcribe(String audioSessionId, {String languageHint = 'en'});
}
