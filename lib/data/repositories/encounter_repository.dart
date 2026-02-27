import '../db/local_database.dart';
import '../models/encounter.dart';

class EncounterRepository {
  EncounterRepository(this._database);

  final LocalDatabase _database;

  Future<void> save(Encounter encounter) => _database.insertEncounter(encounter);

  Future<List<Encounter>> getAll() => _database.fetchEncounters();
}
