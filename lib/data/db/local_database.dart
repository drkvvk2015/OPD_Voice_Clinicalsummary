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
        onUpgrade: (db, oldVersion, newVersion) async =>
            _migrate(db, oldVersion, newVersion),
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
        gender TEXT NOT NULL,
        allergies_json TEXT NOT NULL DEFAULT '[]',
        is_pregnant INTEGER NOT NULL DEFAULT 0,
        renal_risk INTEGER NOT NULL DEFAULT 0,
        hepatic_risk INTEGER NOT NULL DEFAULT 0
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
        clinical_findings TEXT NOT NULL DEFAULT '',
        complaints_json TEXT NOT NULL,
        vitals_json TEXT NOT NULL DEFAULT '[]',
        lab_reports_json TEXT NOT NULL DEFAULT '[]',
        investigations_json TEXT NOT NULL,
        referrals_json TEXT NOT NULL DEFAULT '[]',
        medical_plan_json TEXT NOT NULL DEFAULT '[]',
        surgical_plan_json TEXT NOT NULL DEFAULT '[]',
        advice_json TEXT NOT NULL DEFAULT '[]',
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
    if (oldVersion < 2) {
      await db.execute(
          "ALTER TABLE patient ADD COLUMN allergies_json TEXT NOT NULL DEFAULT '[]';");
      await db.execute(
          'ALTER TABLE patient ADD COLUMN is_pregnant INTEGER NOT NULL DEFAULT 0;');
      await db.execute(
          'ALTER TABLE patient ADD COLUMN renal_risk INTEGER NOT NULL DEFAULT 0;');
      await db.execute(
          'ALTER TABLE patient ADD COLUMN hepatic_risk INTEGER NOT NULL DEFAULT 0;');
    }
    if (oldVersion < 3) {
      await db.execute(
          "ALTER TABLE encounter ADD COLUMN clinical_findings TEXT NOT NULL DEFAULT '';");
      await db.execute(
          "ALTER TABLE encounter ADD COLUMN vitals_json TEXT NOT NULL DEFAULT '[]';");
      await db.execute(
          "ALTER TABLE encounter ADD COLUMN lab_reports_json TEXT NOT NULL DEFAULT '[]';");
      await db.execute(
          "ALTER TABLE encounter ADD COLUMN referrals_json TEXT NOT NULL DEFAULT '[]';");
      await db.execute(
          "ALTER TABLE encounter ADD COLUMN medical_plan_json TEXT NOT NULL DEFAULT '[]';");
      await db.execute(
          "ALTER TABLE encounter ADD COLUMN surgical_plan_json TEXT NOT NULL DEFAULT '[]';");
      await db.execute(
          "ALTER TABLE encounter ADD COLUMN advice_json TEXT NOT NULL DEFAULT '[]';");
    }
    if (newVersion > oldVersion) {
      // Reserved for future migrations.
    }
  }

  Future<void> insertEncounter(Encounter encounter) async {
    final db = await _database();

    await db.transaction((txn) async {
      await txn.insert('patient', encounter.patient.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

      await txn.insert('encounter', {
        'id': encounter.id,
        'patient_id': encounter.patient.id,
        'created_at': encounter.createdAt.toIso8601String(),
        'transcript_cipher': _codec.encrypt(encounter.transcript),
        'history_cipher': _codec.encrypt(encounter.history),
        'examination': encounter.examination,
        'clinical_findings': encounter.clinicalFindings,
        'complaints_json': jsonEncode(encounter.chiefComplaints),
        'vitals_json': jsonEncode(encounter.vitals),
        'lab_reports_json': jsonEncode(encounter.labReports),
        'investigations_json': jsonEncode(encounter.investigations),
        'referrals_json': jsonEncode(encounter.referralConsultations),
        'medical_plan_json': jsonEncode(encounter.medicalPlan),
        'surgical_plan_json': jsonEncode(encounter.surgicalPlan),
        'advice_json': jsonEncode(encounter.advice),
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
    final encounterRows =
        await db.query('encounter', orderBy: 'created_at DESC');

    final encounters = <Encounter>[];
    for (final row in encounterRows) {
      final patientRows = await db
          .query('patient', where: 'id = ?', whereArgs: [row['patient_id']]);
      final diagnosisRows = await db.query('diagnosis',
          where: 'encounter_id = ?', whereArgs: [row['id']]);
      final prescriptionRows = await db.query('prescription',
          where: 'encounter_id = ?', whereArgs: [row['id']]);

      if (patientRows.isEmpty) {
        continue;
      }

      encounters.add(
        Encounter(
          id: row['id'] as String,
          patient: Patient.fromMap(patientRows.first),
          createdAt: DateTime.parse(row['created_at'] as String),
          transcript: _codec.decrypt(row['transcript_cipher'] as String),
          chiefComplaints: List<String>.from(
              jsonDecode(row['complaints_json'] as String) as List<dynamic>),
          history: _codec.decrypt(row['history_cipher'] as String),
          examination: row['examination'] as String,
          clinicalFindings: (row['clinical_findings'] as String?) ?? '',
          vitals: _decodeJsonList(row['vitals_json']),
          labReports: _decodeJsonList(row['lab_reports_json']),
          diagnoses: diagnosisRows
              .map(
                (item) => DiagnosisSuggestion(
                  name: item['name'] as String,
                  icdCode: item['icd_code'] as String,
                  confidence: (item['confidence'] as num).toDouble(),
                  requiresConfirmation:
                      (item['requires_confirmation'] as int) == 1,
                ),
              )
              .toList(growable: false),
          investigations: List<String>.from(
              jsonDecode(row['investigations_json'] as String)
                  as List<dynamic>),
          referralConsultations: _decodeJsonList(row['referrals_json']),
          medicalPlan: _decodeJsonList(row['medical_plan_json']),
          surgicalPlan: _decodeJsonList(row['surgical_plan_json']),
          advice: _decodeJsonList(row['advice_json']),
          prescriptions: prescriptionRows
              .map(PrescriptionRow.fromMap)
              .toList(growable: false),
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

  List<String> _decodeJsonList(dynamic raw) {
    if (raw is! String || raw.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList(growable: false);
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }
}
