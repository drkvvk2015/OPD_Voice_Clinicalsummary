import '../../data/models/encounter.dart';

class PersonalizationService {
  String suggestTemplate(List<Encounter> history) {
    if (history.isEmpty) {
      return 'Default OPD template (General Medicine).';
    }

    final frequentComplaint = history
        .expand((e) => e.chiefComplaints)
        .fold<Map<String, int>>({}, (acc, item) {
      acc[item] = (acc[item] ?? 0) + 1;
      return acc;
    }).entries
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (frequentComplaint.isEmpty) {
      return 'Template: structured HPI + vitals + exam checklist.';
    }

    return 'Template tuned for frequent complaint: ${frequentComplaint.first.key}.';
  }
}
