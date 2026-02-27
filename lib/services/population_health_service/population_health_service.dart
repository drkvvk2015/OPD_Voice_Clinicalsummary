import '../../data/models/encounter.dart';

class PopulationHealthService {
  String detectSignal(List<Encounter> history) {
    final feverCount = history.where((e) => e.chiefComplaints.any((c) => c.toLowerCase() == 'fever')).length;
    if (feverCount >= 3) {
      return 'Population signal: elevated fever-related visits in recent encounter window.';
    }
    return 'Population signal: no unusual local trend detected.';
  }
}
