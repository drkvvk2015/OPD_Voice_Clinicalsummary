import '../models/encounter.dart';

class LocalDatabase {
  final List<Encounter> _encounters = [];

  Future<void> insertEncounter(Encounter encounter) async {
    _encounters.add(encounter);
  }

  Future<List<Encounter>> fetchEncounters() async {
    return List<Encounter>.unmodifiable(_encounters.reversed);
  }
}
