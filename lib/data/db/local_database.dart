import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/constants/app_constants.dart';
import '../../core/security/encrypted_field_codec.dart';
import '../models/diagnosis_suggestion.dart';
import '../models/encounter.dart';
import '../models/patient.dart';
import '../models/prescription_row.dart';

class LocalDatabase {
  LocalDatabase({EncryptedFieldCodec? codec})
      : _codec = codec ?? EncryptedFieldCodec(AppConstants.localCipherSecret);

  final EncryptedFieldCodec _codec;
  Database? _db;

  Future<Database> _database() async {
    if (_db != null) {
      return _db!;
    }

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final documents = await getApplicationDocumentsDirectory();
    final dbPath = p.join(documents.path, AppConstants.dbName);

    _db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppConstants.dbVersion,
        onCreate: (db, version) async => _createSchema(db),
        onUpgrade: (db, oldVersion, newVersion) async => _migrate(db, oldVersion, newVersion),
      ),
    );

    return _db!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE patient(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        age INTEGER NOT NULL,
        gender TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE encounter(
        id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        transcript_cipher TEXT NOT NULL,
        history_cipher TEXT NOT NULL,
        examination TEXT NOT NULL,
        complaints_json TEXT NOT NULL,
        investigations_json TEXT NOT NULL,
        requires_clinical_review INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(patient_id) REFERENCES patient(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE diagnosis(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        encounter_id TEXT NOT NULL,
        name TEXT NOT NULL,
        icd_code TEXT NOT NULL,
        confidence REAL NOT NULL,
        requires_confirmation INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(encounter_id) REFERENCES encounter(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE prescription(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        encounter_id TEXT NOT NULL,
        drug TEXT NOT NULL,
        dose TEXT NOT NULL,
        frequency TEXT NOT NULL,
        duration TEXT NOT NULL,
        route TEXT NOT NULL,
        FOREIGN KEY(encounter_id) REFERENCES encounter(id)
      );
    ''');
  }

  Future<void> _migrate(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 1) {
      await _createSchema(db);
    }
    if (newVersion > oldVersion) {
      // Reserved for future migrations.
    }
  }

  Future<void> insertEncounter(Encounter encounter) async {
    final db = await _database();

    await db.transaction((txn) async {
      await txn.insert('patient', encounter.patient.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      await txn.insert('encounter', {
        'id': encounter.id,
        'patient_id': encounter.patient.id,
        'created_at': encounter.createdAt.toIso8601String(),
        'transcript_cipher': _codec.encrypt(encounter.transcript),
        'history_cipher': _codec.encrypt(encounter.history),
        'examination': encounter.examination,
        'complaints_json': jsonEncode(encounter.chiefComplaints),
        'investigations_json': jsonEncode(encounter.investigations),
        'requires_clinical_review': encounter.requiresClinicalReview ? 1 : 0,
      });

      for (final diagnosis in encounter.diagnoses) {
        await txn.insert('diagnosis', {
          'encounter_id': encounter.id,
          'name': diagnosis.name,
          'icd_code': diagnosis.icdCode,
          'confidence': diagnosis.confidence,
          'requires_confirmation': diagnosis.requiresConfirmation ? 1 : 0,
        });
      }

      for (final prescription in encounter.prescriptions) {
        await txn.insert('prescription', {
          'encounter_id': encounter.id,
          ...prescription.toMap(),
        });
      }
    });
  }

  Future<List<Encounter>> fetchEncounters() async {
    final db = await _database();
    final encounterRows = await db.query('encounter', orderBy: 'created_at DESC');

    final encounters = <Encounter>[];
    for (final row in encounterRows) {
      final patientRows = await db.query('patient', where: 'id = ?', whereArgs: [row['patient_id']]);
      final diagnosisRows = await db.query('diagnosis', where: 'encounter_id = ?', whereArgs: [row['id']]);
      final prescriptionRows = await db.query('prescription', where: 'encounter_id = ?', whereArgs: [row['id']]);

      if (patientRows.isEmpty) {
        continue;
      }

      encounters.add(
        Encounter(
          id: row['id'] as String,
          patient: Patient.fromMap(patientRows.first),
          createdAt: DateTime.parse(row['created_at'] as String),
          transcript: _codec.decrypt(row['transcript_cipher'] as String),
          chiefComplaints: List<String>.from(jsonDecode(row['complaints_json'] as String) as List<dynamic>),
          history: _codec.decrypt(row['history_cipher'] as String),
          examination: row['examination'] as String,
          diagnoses: diagnosisRows
              .map(
                (item) => DiagnosisSuggestion(
                  name: item['name'] as String,
                  icdCode: item['icd_code'] as String,
                  confidence: (item['confidence'] as num).toDouble(),
                  requiresConfirmation: (item['requires_confirmation'] as int) == 1,
                ),
              )
              .toList(growable: false),
          investigations: List<String>.from(jsonDecode(row['investigations_json'] as String) as List<dynamic>),
          prescriptions: prescriptionRows.map(PrescriptionRow.fromMap).toList(growable: false),
          requiresClinicalReview: (row['requires_clinical_review'] as int) == 1,
        ),
      );
    }

    return encounters;
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  Future<void> clearForDebug() async {
    final db = await _database();
    await db.delete('diagnosis');
    await db.delete('prescription');
    await db.delete('encounter');
    await db.delete('patient');

    final dbPath = db.path;
    await close();
    final file = File(dbPath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
