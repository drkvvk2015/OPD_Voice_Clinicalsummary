import '../../data/models/prescription_row.dart';

class DrugInteractionChecker {
  List<String> check(List<PrescriptionRow> rows) {
    final meds = rows.map((e) => e.drug.toLowerCase()).toSet();
    final warnings = <String>[];

    if (meds.contains('ibuprofen') && meds.contains('diclofenac')) {
      warnings.add('Avoid duplicate NSAID use: Ibuprofen + Diclofenac.');
    }

    return warnings;
  }
}
