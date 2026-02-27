class WhisperEngine {
  Future<String> transcribe(String rawAudioTag) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return 'Patient reports fever for 3 days with cough and sore throat. '
        'On exam temperature 101F, throat congestion present. '
        'Plan CBC test and prescribe paracetamol 650 mg thrice daily for 5 days.';
  }
}
