import '../../data/models/encounter.dart';

class DigitalTwinService {
  String simulatePlan(Encounter encounter) {
    if (encounter.diagnoses.isEmpty) {
      return 'Digital twin: insufficient data for trajectory simulation.';
    }

    final top = encounter.diagnoses.first;
    final confidenceBand = top.confidence >= 0.85
        ? 'high confidence'
        : top.confidence >= 0.70
            ? 'moderate confidence'
            : 'low confidence';
    final intervention = encounter.investigations.isEmpty
        ? 'consider targeted baseline investigations'
        : 'continue current workup and symptom tracking';

    return 'Digital twin projection: expected symptom improvement in 48-72 hours for ${top.name.toLowerCase()} '
        '($confidenceBand). High-yield next step: $intervention.';
  }
}
