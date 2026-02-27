import 'structured_extraction.dart';

class StructuredExtractionValidator {
  StructuredExtraction validate(StructuredExtraction extraction) {
    final complaints = extraction.chiefComplaints.where((c) => c.trim().isNotEmpty).toSet().toList(growable: false);
    final investigations = extraction.investigations.where((c) => c.trim().isNotEmpty).toSet().toList(growable: false);

    final warnings = <String>[...extraction.warnings];
    if (complaints.isEmpty) {
      warnings.add('No chief complaint extracted; clinical confirmation required.');
    }

    return StructuredExtraction(
      chiefComplaints: complaints,
      history: extraction.history.trim(),
      examination: extraction.examination.trim(),
      investigations: investigations,
      warnings: warnings,
    );
  }
}
