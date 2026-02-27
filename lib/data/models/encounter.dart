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
}
