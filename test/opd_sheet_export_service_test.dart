import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rxnova_clinical_ai/data/models/diagnosis_suggestion.dart';
import 'package:rxnova_clinical_ai/data/models/encounter.dart';
import 'package:rxnova_clinical_ai/data/models/patient.dart';
import 'package:rxnova_clinical_ai/data/models/prescription_row.dart';
import 'package:rxnova_clinical_ai/services/export_service/opd_sheet_export_service.dart';

void main() {
  test('exports encounter summary as PDF file', () async {
    final tempDirectory =
        await Directory.systemTemp.createTemp('rxnova_export_test_');
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final service =
        OpdSheetExportService(baseDirectoryPath: tempDirectory.path);
    final encounter = Encounter(
      id: 'enc_test',
      patient:
          const Patient(id: 'p1', name: 'Demo Patient', age: 40, gender: 'F'),
      createdAt: DateTime(2026, 2, 15, 10, 30),
      transcript:
          'Fever and cough for three days. Start paracetamol 650 mg tid for 5 days.',
      chiefComplaints: const ['Fever', 'Cough'],
      history: 'Fever and cough for three days.',
      examination: 'Temp 101 F, mild throat congestion.',
      diagnoses: const [
        DiagnosisSuggestion(
          name: 'Upper respiratory tract infection',
          icdCode: 'J06.9',
          confidence: 0.86,
        ),
      ],
      investigations: const ['Complete blood count (CBC)'],
      prescriptions: const [
        PrescriptionRow(
          drug: 'Paracetamol',
          dose: '650 MG',
          frequency: 'TID',
          duration: '5 days',
          route: 'Oral',
        ),
      ],
    );

    final exportedPath = await service.exportEncounterPdf(encounter);
    final exportedFile = File(exportedPath);

    expect(exportedPath, endsWith('.pdf'));
    expect(await exportedFile.exists(), isTrue);
    expect(await exportedFile.length(), greaterThan(0));
  });
}
