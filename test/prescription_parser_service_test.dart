import 'package:flutter_test/flutter_test.dart';
import 'package:rxnova_clinical_ai/services/prescription_parser/prescription_parser_service.dart';

void main() {
  test('extracts paracetamol instruction from transcript', () {
    final service = PrescriptionParserService();
    final result = service.parse('Start paracetamol 650 mg thrice daily for 5 days.');

    expect(result.rows.length, 1);
    expect(result.rows.single.drug, 'Paracetamol');
    expect(result.rows.single.frequency, 'TID');
  });

  test('reports nsaid duplicate interaction warning', () {
    final service = PrescriptionParserService();
    final result = service.parse('Start ibuprofen 400 mg bid for 5 days and diclofenac 50 mg bid for 5 days.');

    expect(result.warnings, isNotEmpty);
  });
}
