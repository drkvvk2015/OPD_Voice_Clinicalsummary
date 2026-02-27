import 'structured_extraction.dart';

class StructuredExtractionValidator {
  StructuredExtraction validate(StructuredExtraction extraction) {
    final complaints = extraction.chiefComplaints
        .where((c) => c.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
    final investigations = extraction.investigations
        .where((c) => c.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
    final vitals = extraction.vitals
        .where((v) => v.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
    final labs = extraction.labReports
        .where((v) => v.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
    final referrals = extraction.referralConsultations
        .where((v) => v.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
    final medicalPlan = extraction.medicalPlan
        .where((v) => v.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
    final surgicalPlan = extraction.surgicalPlan
        .where((v) => v.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
    final advice = extraction.advice
        .where((v) => v.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);

    final warnings = <String>[...extraction.warnings];
    if (complaints.isEmpty) {
      warnings
          .add('No chief complaint extracted; clinical confirmation required.');
    }
    if (vitals.isEmpty) {
      warnings.add('No vitals extracted from audio.');
    }
    if (medicalPlan.isEmpty && surgicalPlan.isEmpty) {
      warnings.add('No explicit treatment plan extracted from audio.');
    }

    return StructuredExtraction(
      chiefComplaints: complaints,
      history: extraction.history.trim(),
      examination: extraction.examination.trim(),
      clinicalFindings: extraction.clinicalFindings.trim(),
      vitals: vitals,
      labReports: labs,
      investigations: investigations,
      referralConsultations: referrals,
      medicalPlan: medicalPlan,
      surgicalPlan: surgicalPlan,
      advice: advice,
      warnings: warnings,
      patientName: extraction.patientName?.trim().isEmpty == true
          ? null
          : extraction.patientName?.trim(),
      patientAge: extraction.patientAge,
      patientGender: extraction.patientGender,
      detectedLanguage: extraction.detectedLanguage,
    );
  }
}
