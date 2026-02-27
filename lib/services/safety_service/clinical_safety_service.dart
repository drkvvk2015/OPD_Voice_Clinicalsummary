import '../../data/models/encounter.dart';

class ClinicalSafetyService {
  List<String> evaluate(Encounter encounter) {
    final alerts = <String>[];

    if (encounter.chiefComplaints.any((c) => c.toLowerCase().contains('chest pain'))) {
      alerts.add('Red flag: chest pain detected. Consider urgent ECG/ER referral.');
    }

    if (encounter.prescriptions.isEmpty) {
      alerts.add('No medications parsed. Confirm if treatment plan intentionally non-pharmacologic.');
    }

    if (encounter.investigations.isEmpty) {
      alerts.add('No investigations listed. Verify if watchful waiting is intended.');
    }

    return alerts;
  }
}
