import '../../data/models/prescription_row.dart';

class PrescriptionParseResult {
  const PrescriptionParseResult({required this.rows, required this.warnings});

  final List<PrescriptionRow> rows;
  final List<String> warnings;
}
