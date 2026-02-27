import 'package:flutter_test/flutter_test.dart';
import 'package:rxnova_clinical_ai/services/audio_service/audio_service.dart';

void main() {
  test(
      'audio service emits mic checking and non-zero voice level while recording',
      () async {
    final service = AudioService();

    await service.startRecording();
    await Future<void>.delayed(const Duration(milliseconds: 250));

    expect(service.isRecording, isTrue);
    expect(service.voiceLevel, greaterThan(0));
    expect(service.isMicCheckInProgress, isTrue);

    await Future<void>.delayed(const Duration(seconds: 3));
    expect(service.isMicCheckInProgress, isFalse);

    await service.stopRecording();
    expect(service.isRecording, isFalse);
    expect(service.voiceLevel, equals(0));
  });
}
