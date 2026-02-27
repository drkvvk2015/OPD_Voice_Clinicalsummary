import '../../data/models/prescription_row.dart';

class PrescriptionParserService {
  List<PrescriptionRow> parse(String transcript) {
    final lower = transcript.toLowerCase();
    final rows = <PrescriptionRow>[];

    if (lower.contains('paracetamol')) {
      rows.add(const PrescriptionRow(
        drug: 'Paracetamol',
        dose: '650 mg',
        frequency: 'TID',
        duration: '5 days',
      ));
    }

    return rows;
  }
}
