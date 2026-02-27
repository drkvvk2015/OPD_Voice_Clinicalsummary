import 'package:flutter_test/flutter_test.dart';
import 'package:rxnova_clinical_ai/data/models/diagnosis_suggestion.dart';
import 'package:rxnova_clinical_ai/data/models/encounter.dart';
import 'package:rxnova_clinical_ai/data/models/patient.dart';
import 'package:rxnova_clinical_ai/data/models/prescription_row.dart';
import 'package:rxnova_clinical_ai/services/coding_service/coding_billing_service.dart';
import 'package:rxnova_clinical_ai/services/personalization_service/personalization_service.dart';
import 'package:rxnova_clinical_ai/services/voice_automation_service/voice_automation_service.dart';

void main() {
  Encounter buildEncounter({required List<String> complaints}) {
    return Encounter(
      id: '1',
      patient: const Patient(id: 'p1', name: 'Test', age: 30, gender: 'M'),
      createdAt: DateTime(2026, 1, 1),
      transcript: 'Advise CBC and CRP',
      chiefComplaints: complaints,
      history: 'H',
      examination: 'E',
      diagnoses: const [
        DiagnosisSuggestion(name: 'Upper respiratory tract infection', icdCode: 'J06.9', confidence: 0.8),
      ],
      investigations: const ['CBC'],
      prescriptions: const [
        PrescriptionRow(drug: 'Paracetamol', dose: '650 MG', frequency: 'TID', duration: '5 days'),
      ],
    );
  }

  test('personalization service suggests template from frequent complaint', () {
    final service = PersonalizationService();
    final suggestion = service.suggestTemplate([
      buildEncounter(complaints: const ['Fever']),
      buildEncounter(complaints: const ['Fever', 'Cough']),
    ]);

    expect(suggestion.toLowerCase(), contains('fever'));
  });

  test('coding billing service returns icd suggestion', () {
    final service = CodingBillingService();
    final result = service.buildSuggestion(
      const [DiagnosisSuggestion(name: 'Upper respiratory tract infection', icdCode: 'J06.9', confidence: 0.9)],
    );

    expect(result, contains('J06.9'));
  });

  test('voice automation service creates actions for CBC and CRP', () {
    final service = VoiceAutomationService();
    final actions = service.suggestActions('Order CBC and CRP today');

    expect(actions.length, 2);
  });
}
