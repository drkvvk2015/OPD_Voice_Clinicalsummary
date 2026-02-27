import '../../data/models/encounter.dart';

class PopulationHealthService {
  String detectSignal(List<Encounter> history) {
    if (history.isEmpty) {
      return 'Population signal: no encounter pool available.';
    }

    final recent = history.take(20).toList(growable: false);
    final feverCount = history
        .where((e) => e.chiefComplaints.any((c) => c.toLowerCase() == 'fever'))
        .length;
    final soreThroatCount = recent
        .where((e) =>
            e.chiefComplaints.any((c) => c.toLowerCase() == 'sore throat'))
        .length;
    final coughCount = recent
        .where((e) => e.chiefComplaints.any((c) => c.toLowerCase() == 'cough'))
        .length;

    if (feverCount >= 3 && soreThroatCount >= 3) {
      return 'Population signal: possible febrile throat-infection cluster in recent encounter window.';
    }

    if (feverCount >= 3 && coughCount >= 3) {
      return 'Population signal: elevated fever+cough cluster trend; monitor for local outbreak pattern.';
    }

    if (feverCount >= 3) {
      return 'Population signal: elevated fever-related visits in recent encounter window.';
    }

    return 'Population signal: no unusual local trend detected.';
  }
}
