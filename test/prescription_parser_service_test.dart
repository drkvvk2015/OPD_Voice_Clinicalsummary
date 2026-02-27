import 'package:flutter_test/flutter_test.dart';
import 'package:rxnova_clinical_ai/services/prescription_parser/prescription_parser_service.dart';

void main() {
  test('extracts paracetamol instruction from transcript', () {
    final service = PrescriptionParserService();
    final rows = service.parse('Start paracetamol 650 mg thrice daily for 5 days.');

    expect(rows.length, 1);
    expect(rows.single.drug, 'Paracetamol');
  });
}
