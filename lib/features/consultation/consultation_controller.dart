import 'package:flutter/foundation.dart';

import '../../ai/llama/llama_extractor.dart';
import '../../ai/whisper/whisper_cpp_adapter.dart';
import '../../ai/whisper/whisper_engine.dart';
import '../../data/db/local_database.dart';
import '../../data/models/encounter.dart';
import '../../data/models/patient.dart';
import '../../data/repositories/encounter_repository.dart';
import '../../services/audio_service/audio_service.dart';
import '../../services/diagnosis_service/diagnosis_service.dart';
import '../../services/extraction_service/clinical_extraction_service.dart';
import '../../services/extraction_service/structured_extraction_validator.dart';
import '../../services/prescription_parser/prescription_parse_result.dart';
import '../../services/prescription_parser/prescription_parser_service.dart';
import '../../services/sync_service/sync_queue_service.dart';

class ConsultationController extends ChangeNotifier {
  ConsultationController({
    required AudioService audioService,
    required WhisperEngine whisperEngine,
    required ClinicalExtractionService extractionService,
    required DiagnosisService diagnosisService,
    required PrescriptionParserService prescriptionParserService,
    required EncounterRepository encounterRepository,
    required SyncQueueService syncQueueService,
  })  : _audioService = audioService,
        _whisperEngine = whisperEngine,
        _extractionService = extractionService,
        _diagnosisService = diagnosisService,
        _prescriptionParserService = prescriptionParserService,
        _encounterRepository = encounterRepository,
        _syncQueueService = syncQueueService;

  factory ConsultationController.bootstrap() {
    final database = LocalDatabase();
    return ConsultationController(
      audioService: AudioService(),
      whisperEngine: WhisperEngine(WhisperCppAdapter()),
      extractionService: ClinicalExtractionService(
        LlamaExtractor(),
        StructuredExtractionValidator(),
      ),
      diagnosisService: DiagnosisService(),
      prescriptionParserService: PrescriptionParserService(),
      encounterRepository: EncounterRepository(database),
      syncQueueService: SyncQueueService(),
    );
  }

  final AudioService _audioService;
  final WhisperEngine _whisperEngine;
  final ClinicalExtractionService _extractionService;
  final DiagnosisService _diagnosisService;
  final PrescriptionParserService _prescriptionParserService;
  final EncounterRepository _encounterRepository;
  final SyncQueueService _syncQueueService;

  bool _isBusy = false;
  bool _isSyncing = false;
  String _transcript = '';
  String? _errorMessage;
  Encounter? _latestEncounter;
  List<Encounter> _history = const [];
  List<String> _clinicalWarnings = const [];
  List<String> _interactionWarnings = const [];

  bool get isBusy => _isBusy;
  bool get isSyncing => _isSyncing;
  bool get isRecording => _audioService.isRecording;
  String get transcript => _transcript;
  String? get errorMessage => _errorMessage;
  Encounter? get latestEncounter => _latestEncounter;
  List<Encounter> get history => _history;
  List<String> get clinicalWarnings => _clinicalWarnings;
  List<String> get interactionWarnings => _interactionWarnings;
  int get pendingSyncCount => _syncQueueService.pending.length;

  Future<void> init() async {
    _history = await _encounterRepository.getAll();
    notifyListeners();
  }

  Future<void> toggleRecording() async {
    _errorMessage = null;
    if (_audioService.isRecording) {
      await _stopAndProcess();
      return;
    }

    await _audioService.startRecording();
    notifyListeners();
  }

  Future<void> _stopAndProcess() async {
    _isBusy = true;
    notifyListeners();

    try {
      final sessionId = await _audioService.stopRecording();
      if (sessionId == null) {
        throw StateError('No active recording session found.');
      }

      _transcript = await _whisperEngine.transcribe(sessionId, languageHint: 'en');
      await _generateEncounter(_transcript);
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> _generateEncounter(String transcript) async {
    final structured = await _extractionService.extract(transcript);
    final diagnoses = _diagnosisService.suggest(transcript);
    final PrescriptionParseResult parseResult = _prescriptionParserService.parse(transcript);

    final needsReview = diagnoses.any((d) => d.requiresConfirmation) || structured.warnings.isNotEmpty;

    final encounter = Encounter(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patient: const Patient(id: 'P001', name: 'Walk-in Patient', age: 36, gender: 'Unknown'),
      createdAt: DateTime.now(),
      transcript: transcript,
      chiefComplaints: structured.chiefComplaints,
      history: structured.history,
      examination: structured.examination,
      diagnoses: diagnoses,
      investigations: structured.investigations,
      prescriptions: parseResult.rows,
      requiresClinicalReview: needsReview,
    );

    await _encounterRepository.save(encounter);
    await _syncQueueService.enqueue(encounter);

    _clinicalWarnings = structured.warnings;
    _interactionWarnings = parseResult.warnings;
    _latestEncounter = encounter;
    _history = await _encounterRepository.getAll();
  }

  Future<void> flushSyncQueue() async {
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _syncQueueService.flush();
    } catch (error) {
      _errorMessage = 'Sync failed: $error';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
