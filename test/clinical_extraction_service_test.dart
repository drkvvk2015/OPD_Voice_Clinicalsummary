import 'package:flutter_test/flutter_test.dart';
import 'package:rxnova_clinical_ai/ai/llama/llama_extractor.dart';
import 'package:rxnova_clinical_ai/services/extraction_service/clinical_extraction_service.dart';
import 'package:rxnova_clinical_ai/services/extraction_service/structured_extraction_validator.dart';

void main() {
  test('extracts comprehensive case-sheet fields from dictated transcript',
      () async {
    final service = ClinicalExtractionService(
        LlamaExtractor(), StructuredExtractionValidator());

    final result = await service.extract(
      'My name is Ramesh Kumar. I am 42 years old male. '
      'Fever and cough for 3 days. On examination throat congestion. '
      'BP 120/80 pulse 96 temperature 101 F spo2 98. '
      'Lab report shows WBC 12000 and hemoglobin 12.5. '
      'Order CBC, CRP and chest xray. Refer to cardiology consult. '
      'Start symptomatic treatment and follow up after 2 days.',
    );

    expect(result.patientName, 'Ramesh Kumar');
    expect(result.patientAge, 42);
    expect(result.patientGender, 'Male');
    expect(result.chiefComplaints, contains('Fever'));
    expect(result.vitals.join(' '), contains('120/80'));
    expect(result.labReports, isNotEmpty);
    expect(result.investigations, isNotEmpty);
    expect(result.referralConsultations, isNotEmpty);
    expect(result.medicalPlan, isNotEmpty);
  });

  test('detects local language complaint terms and normalizes complaints',
      () async {
    final service = ClinicalExtractionService(
        LlamaExtractor(), StructuredExtractionValidator());

    final result = await service.extract(
      'Patient says bukhar and khansi since 2 din, also sar dard. '
      'BP 130/90 pulse 98. prescribe tablet PCM and follow up.',
    );

    expect(result.detectedLanguage, contains('Hindi'));
    expect(
        result.chiefComplaints,
        containsAll(<String>[
          'Fever',
          'Cough',
          'Headache',
        ]));
  });
}
