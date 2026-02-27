import '../contracts/whisper_adapter.dart';

class WhisperCppAdapter implements WhisperAdapter {
  @override
  Future<String> transcribe(String audioSessionId, {String languageHint = 'en'}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return 'Patient reports fever, cough and sore throat for three days. '
        'Temperature recorded 101F. CBC and CRP advised. '
        'Start Tab PCM 650 mg orally TID for 5 days and Cetirizine 10 mg at night.';
  }
}
