import '../../data/models/encounter.dart';

class DigitalTwinService {
  String simulatePlan(Encounter encounter) {
    if (encounter.diagnoses.isEmpty) {
      return 'Digital twin: insufficient data for trajectory simulation.';
    }

    final top = encounter.diagnoses.first;
    return 'Digital twin projection: with current plan, likely symptom improvement in 48-72 hours for ${top.name.toLowerCase()}.';
  }
}
