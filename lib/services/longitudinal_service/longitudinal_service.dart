import '../../data/models/encounter.dart';

class LongitudinalService {
  String summarize(List<Encounter> history) {
    if (history.length < 2) {
      return 'Need at least 2 encounters for trend analysis.';
    }

    final last = history.first;
    final prev = history[1];
    final overlap = last.chiefComplaints.where(prev.chiefComplaints.contains).toList(growable: false);

    if (overlap.isEmpty) {
      return 'No recurring complaints between recent visits.';
    }

    return 'Recurring complaints across recent visits: ${overlap.join(', ')}.';
  }
}
