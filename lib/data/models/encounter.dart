import 'diagnosis_suggestion.dart';
import 'patient.dart';
import 'prescription_row.dart';

class Encounter {
  const Encounter({
    required this.id,
    required this.patient,
    required this.createdAt,
    required this.transcript,
    required this.chiefComplaints,
    required this.history,
    required this.examination,
    required this.diagnoses,
    required this.investigations,
    required this.prescriptions,
    this.clinicalFindings = '',
    this.vitals = const [],
    this.labReports = const [],
    this.referralConsultations = const [],
    this.medicalPlan = const [],
    this.surgicalPlan = const [],
    this.advice = const [],
    this.requiresClinicalReview = false,
  });

  final String id;
  final Patient patient;
  final DateTime createdAt;
  final String transcript;
  final List<String> chiefComplaints;
  final String history;
  final String examination;
  final List<DiagnosisSuggestion> diagnoses;
  final List<String> investigations;
  final List<PrescriptionRow> prescriptions;
  final String clinicalFindings;
  final List<String> vitals;
  final List<String> labReports;
  final List<String> referralConsultations;
  final List<String> medicalPlan;
  final List<String> surgicalPlan;
  final List<String> advice;
  final bool requiresClinicalReview;
}
