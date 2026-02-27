import '../../data/models/encounter.dart';
import '../../data/models/future/copilot_explainability.dart';

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
        })
        .entries
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (frequentComplaint.isEmpty) {
      return 'Template: structured HPI + vitals + exam checklist.';
    }

    final top = frequentComplaint.first;
    return 'Template tuned for frequent complaint: ${top.key} '
        '(seen ${top.value} times). Why: dominant recurring complaint in local encounter history.';
  }

  List<String> suggestMacros(List<Encounter> history) {
    if (history.isEmpty) {
      return const [];
    }

    final complaintCounts = <String, int>{};
    for (final complaint in history.expand((e) => e.chiefComplaints)) {
      final key = complaint.toLowerCase();
      complaintCounts[key] = (complaintCounts[key] ?? 0) + 1;
    }

    final macros = <String>[];
    if ((complaintCounts['fever'] ?? 0) >= 2) {
      macros.add(
          'Fever follow-up macro: duration + vitals + hydration + red-flag counselling.');
    }
    if ((complaintCounts['cough'] ?? 0) >= 2) {
      macros.add(
          'Cough template macro: severity, sputum, breathlessness, chest exam checklist.');
    }
    if ((complaintCounts['sore throat'] ?? 0) >= 2) {
      macros.add(
          'Sore throat macro: Centor features + symptomatic care + review trigger.');
    }

    return macros;
  }

  CopilotExplainability buildExplainability(List<Encounter> history) {
    if (history.isEmpty) {
      return CopilotExplainability.empty();
    }

    final complaintCounts = <String, int>{};
    for (final complaint in history.expand((e) => e.chiefComplaints)) {
      final key = complaint.trim();
      if (key.isEmpty) {
        continue;
      }
      complaintCounts[key] = (complaintCounts[key] ?? 0) + 1;
    }

    final ranked = complaintCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = ranked.isEmpty ? null : ranked.first;

    return CopilotExplainability(
      templateSuggestion: suggestTemplate(history),
      rationale: top == null
          ? 'No stable complaint pattern detected, using generalized OPD template.'
          : 'Top recurring complaint is "${top.key}" (${top.value} occurrences), so copilot prioritized this pattern.',
      evidenceSignals: ranked
          .take(3)
          .map((entry) => '${entry.key}: ${entry.value} occurrence(s)')
          .toList(growable: false),
      doctorMacros: suggestMacros(history),
    );
  }
}
