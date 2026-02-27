import 'package:flutter_test/flutter_test.dart';
import 'package:rxnova_clinical_ai/services/diagnosis_service/diagnosis_service.dart';

void main() {
  test('returns respiratory diagnosis for fever and cough transcript', () {
    final service = DiagnosisService();
    final result = service.suggest('Patient has fever and cough for two days.');

    expect(result.isNotEmpty, isTrue);
    expect(result.first.icdCode, 'J06.9');
  });
}
