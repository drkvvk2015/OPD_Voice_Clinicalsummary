class EvaluationSample {
  const EvaluationSample({
    required this.transcript,
    required this.expectedComplaints,
    required this.expectedDiagnoses,
    required this.expectedDrugCount,
  });

  final String transcript;
  final List<String> expectedComplaints;
  final List<String> expectedDiagnoses;
  final int expectedDrugCount;
}

class EvaluationReport {
  const EvaluationReport({
    required this.complaintPrecision,
    required this.diagnosisRecall,
    required this.prescriptionAccuracy,
  });

  final double complaintPrecision;
  final double diagnosisRecall;
  final double prescriptionAccuracy;
}
