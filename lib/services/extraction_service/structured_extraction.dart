class StructuredExtraction {
  const StructuredExtraction({
    required this.chiefComplaints,
    required this.history,
    required this.examination,
    required this.clinicalFindings,
    required this.vitals,
    required this.labReports,
    required this.investigations,
    required this.referralConsultations,
    required this.medicalPlan,
    required this.surgicalPlan,
    required this.advice,
    required this.warnings,
    this.patientName,
    this.patientAge,
    this.patientGender,
    this.detectedLanguage,
  });

  final List<String> chiefComplaints;
  final String history;
  final String examination;
  final String clinicalFindings;
  final List<String> vitals;
  final List<String> labReports;
  final List<String> investigations;
  final List<String> referralConsultations;
  final List<String> medicalPlan;
  final List<String> surgicalPlan;
  final List<String> advice;
  final List<String> warnings;
  final String? patientName;
  final int? patientAge;
  final String? patientGender;
  final String? detectedLanguage;
}
