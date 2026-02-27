import 'package:flutter_test/flutter_test.dart';
import 'package:rxnova_clinical_ai/data/models/diagnosis_suggestion.dart';
import 'package:rxnova_clinical_ai/data/models/encounter.dart';
import 'package:rxnova_clinical_ai/data/models/patient.dart';
import 'package:rxnova_clinical_ai/data/models/prescription_row.dart';
import 'package:rxnova_clinical_ai/services/coding_service/coding_billing_service.dart';
import 'package:rxnova_clinical_ai/services/longitudinal_service/longitudinal_service.dart';
import 'package:rxnova_clinical_ai/services/personalization_service/personalization_service.dart';
import 'package:rxnova_clinical_ai/services/qa_service/documentation_qa_service.dart';
import 'package:rxnova_clinical_ai/services/safety_service/clinical_safety_service.dart';
import 'package:rxnova_clinical_ai/services/voice_automation_service/voice_automation_service.dart';

void main() {
  Encounter buildEncounter({
    required List<String> complaints,
    String transcript = 'Advise CBC and CRP',
    String history = 'H',
    String examination = 'E',
    List<DiagnosisSuggestion> diagnoses = const [
      DiagnosisSuggestion(
          name: 'Upper respiratory tract infection',
          icdCode: 'J06.9',
          confidence: 0.8),
    ],
    List<String> investigations = const ['CBC'],
    List<PrescriptionRow> prescriptions = const [
      PrescriptionRow(
          drug: 'Paracetamol',
          dose: '650 MG',
          frequency: 'TID',
          duration: '5 days'),
    ],
  }) {
    return Encounter(
      id: '1',
      patient: const Patient(id: 'p1', name: 'Test', age: 30, gender: 'M'),
      createdAt: DateTime(2026, 1, 1),
      transcript: transcript,
      chiefComplaints: complaints,
      history: history,
      examination: examination,
      diagnoses: diagnoses,
      investigations: investigations,
      prescriptions: prescriptions,
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

  test('personalization service suggests macros for recurring complaints', () {
    final service = PersonalizationService();
    final macros = service.suggestMacros([
      buildEncounter(complaints: const ['Fever']),
      buildEncounter(complaints: const ['Fever', 'Cough']),
      buildEncounter(complaints: const ['Cough']),
    ]);

    expect(macros.any((m) => m.toLowerCase().contains('fever')), isTrue);
  });

  test('personalization explainability includes rationale and evidence', () {
    final service = PersonalizationService();
    final explainability = service.buildExplainability([
      buildEncounter(complaints: const ['Fever']),
      buildEncounter(complaints: const ['Fever', 'Cough']),
      buildEncounter(complaints: const ['Cough']),
    ]);

    expect(explainability.templateSuggestion, isNotEmpty);
    expect(explainability.rationale, contains('Top recurring complaint'));
    expect(explainability.evidenceSignals, isNotEmpty);
  });

  test('coding billing service returns icd suggestion', () {
    final service = CodingBillingService();
    final result = service.buildSuggestion(
      const [
        DiagnosisSuggestion(
            name: 'Upper respiratory tract infection',
            icdCode: 'J06.9',
            confidence: 0.9)
      ],
    );

    expect(result, contains('J06.9'));
    expect(result, contains('Denial risk'));
  });

  test('voice automation service creates actions for CBC and CRP', () {
    final service = VoiceAutomationService();
    final actions = service.suggestActions('Order CBC and CRP today');

    expect(actions.length, 2);
  });

  test('longitudinal service flags repeated antibiotic use', () {
    final service = LongitudinalService();
    final encounters = List<Encounter>.generate(
      4,
      (index) => buildEncounter(
        complaints: const ['Fever'],
        prescriptions: const [
          PrescriptionRow(
              drug: 'Azithromycin',
              dose: '500 MG',
              frequency: 'OD',
              duration: '3 days'),
        ],
      ),
    );

    final alerts = service.detectDeviationAlerts(encounters);
    expect(alerts, isNotEmpty);
  });

  test('clinical safety service detects red flag and allergy overlap', () {
    final service = ClinicalSafetyService();
    final encounter = buildEncounter(
      complaints: const ['Chest pain'],
      transcript: 'Chest pain with breathlessness. Allergy to ibuprofen noted.',
      history: 'Allergy to ibuprofen',
      prescriptions: const [
        PrescriptionRow(
            drug: 'Ibuprofen',
            dose: '400 MG',
            frequency: 'BID',
            duration: '5 days'),
      ],
      investigations: const ['ECG'],
    );

    final alerts = service.evaluate(encounter);
    expect(alerts.any((a) => a.toLowerCase().contains('red flag')), isTrue);
    expect(alerts.any((a) => a.toLowerCase().contains('allergy')), isTrue);
  });

  test('clinical safety service uses patient profile risk flags', () {
    final service = ClinicalSafetyService();
    final encounter = Encounter(
      id: '2',
      patient: const Patient(
        id: 'p2',
        name: 'Profile Risk',
        age: 28,
        gender: 'Female',
        allergies: ['ibuprofen'],
        isPregnant: true,
        hasRenalRisk: true,
      ),
      createdAt: DateTime(2026, 1, 2),
      transcript: 'Follow-up consultation',
      chiefComplaints: const ['Fever'],
      history: 'No explicit risk in transcript',
      examination: 'Stable',
      diagnoses: const [
        DiagnosisSuggestion(
            name: 'Viral fever', icdCode: 'B34.9', confidence: 0.8),
      ],
      investigations: const ['CBC'],
      prescriptions: const [
        PrescriptionRow(
            drug: 'Ibuprofen',
            dose: '400 MG',
            frequency: 'BID',
            duration: '3 days'),
      ],
    );

    final alerts = service.evaluate(encounter);
    expect(alerts.any((a) => a.toLowerCase().contains('allergy')), isTrue);
    expect(alerts.any((a) => a.toLowerCase().contains('pregnancy')), isTrue);
    expect(alerts.any((a) => a.toLowerCase().contains('renal/hepatic caution')),
        isTrue);
  });

  test('documentation QA flags viral diagnosis with antibiotic mismatch', () {
    final service = DocumentationQaService();
    final encounter = buildEncounter(
      complaints: const ['Fever'],
      diagnoses: const [
        DiagnosisSuggestion(
            name: 'Viral fever', icdCode: 'B34.9', confidence: 0.8),
      ],
      prescriptions: const [
        PrescriptionRow(
            drug: 'Azithromycin',
            dose: '500 MG',
            frequency: 'OD',
            duration: '3 days'),
      ],
    );

    final findings = service.audit(encounter);
    expect(findings.any((f) => f.toLowerCase().contains('consistency check')),
        isTrue);
  });
}
