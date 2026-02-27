import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rxnova_clinical_ai/data/models/diagnosis_suggestion.dart';
import 'package:rxnova_clinical_ai/data/models/encounter.dart';
import 'package:rxnova_clinical_ai/data/models/patient.dart';
import 'package:rxnova_clinical_ai/data/models/prescription_row.dart';
import 'package:rxnova_clinical_ai/services/ehr_service/ehr_integration_service.dart';

void main() {
  test('writes local EHR payload file when endpoint is empty', () async {
    final tempDirectory =
        await Directory.systemTemp.createTemp('rxnova_ehr_test_');
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final service =
        EhrIntegrationService(baseDirectoryPath: tempDirectory.path);
    final encounter = Encounter(
      id: 'enc_ehr',
      patient: const Patient(id: 'p1', name: 'Demo', age: 42, gender: 'Male'),
      createdAt: DateTime(2026, 2, 20, 11, 30),
      transcript: 'Clinical transcript',
      chiefComplaints: const ['Fever'],
      history: 'Fever for 2 days',
      examination: 'General exam',
      clinicalFindings: 'Throat congestion',
      vitals: const ['BP: 120/80 mmHg'],
      labReports: const ['WBC: 12000'],
      diagnoses: const [
        DiagnosisSuggestion(
          name: 'Upper respiratory tract infection',
          icdCode: 'J06.9',
          confidence: 0.86,
        ),
      ],
      investigations: const ['CBC'],
      referralConsultations: const ['Cardiology consultation'],
      medicalPlan: const ['Medical management initiated'],
      surgicalPlan: const [],
      advice: const ['Follow-up in 2 days'],
      prescriptions: const [
        PrescriptionRow(
          drug: 'Paracetamol',
          dose: '650 MG',
          frequency: 'TID',
          duration: '5 days',
        ),
      ],
    );

    final result = await service.integrateEncounter(
      encounter,
      const EhrIntegrationOptions(
        systemType: EhrSystemType.fhirR4,
        endpointUrl: '',
        apiToken: '',
        includeTranscript: true,
        includePdfLink: false,
      ),
    );

    expect(result.success, isTrue);
    expect(result.payloadPath, isNotNull);
    final file = File(result.payloadPath!);
    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(0));
  });
}
