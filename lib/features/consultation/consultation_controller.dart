import 'package:flutter/foundation.dart';

import '../../ai/whisper/whisper_engine.dart';
import '../../data/db/local_database.dart';
import '../../data/models/encounter.dart';
import '../../data/models/patient.dart';
import '../../data/repositories/encounter_repository.dart';
import '../../services/audio_service/audio_service.dart';
import '../../services/diagnosis_service/diagnosis_service.dart';
import '../../services/extraction_service/clinical_extraction_service.dart';
import '../../services/prescription_parser/prescription_parser_service.dart';
import '../../ai/llama/llama_extractor.dart';

class ConsultationController extends ChangeNotifier {
  ConsultationController({
    required AudioService audioService,
    required WhisperEngine whisperEngine,
    required ClinicalExtractionService extractionService,
    required DiagnosisService diagnosisService,
    required PrescriptionParserService prescriptionParserService,
    required EncounterRepository encounterRepository,
  })  : _audioService = audioService,
        _whisperEngine = whisperEngine,
        _extractionService = extractionService,
        _diagnosisService = diagnosisService,
        _prescriptionParserService = prescriptionParserService,
        _encounterRepository = encounterRepository;

  factory ConsultationController.bootstrap() {
    final database = LocalDatabase();
    return ConsultationController(
      audioService: AudioService(),
      whisperEngine: WhisperEngine(),
      extractionService: ClinicalExtractionService(LlamaExtractor()),
      diagnosisService: DiagnosisService(),
      prescriptionParserService: PrescriptionParserService(),
      encounterRepository: EncounterRepository(database),
    );
  }

  final AudioService _audioService;
  final WhisperEngine _whisperEngine;
  final ClinicalExtractionService _extractionService;
  final DiagnosisService _diagnosisService;
  final PrescriptionParserService _prescriptionParserService;
  final EncounterRepository _encounterRepository;

  bool _isBusy = false;
  String _transcript = '';
  Encounter? _latestEncounter;
  List<Encounter> _history = const [];

  bool get isBusy => _isBusy;
  bool get isRecording => _audioService.isRecording;
  String get transcript => _transcript;
  Encounter? get latestEncounter => _latestEncounter;
  List<Encounter> get history => _history;

  Future<void> toggleRecording() async {
    if (_audioService.isRecording) {
      _isBusy = true;
      notifyListeners();

      await _audioService.stopRecording();
      _transcript = await _whisperEngine.transcribe('current_audio');
      await _generateEncounter(_transcript);

      _isBusy = false;
      notifyListeners();
      return;
    }

    await _audioService.startRecording();
    notifyListeners();
  }

  Future<void> _generateEncounter(String transcript) async {
    final structured = _extractionService.extract(transcript);
    final diagnoses = _diagnosisService.suggest(transcript);
    final prescriptions = _prescriptionParserService.parse(transcript);

    final encounter = Encounter(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patient: const Patient(id: 'P001', name: 'Walk-in Patient', age: 36, gender: 'Unknown'),
      createdAt: DateTime.now(),
      transcript: transcript,
      chiefComplaints: List<String>.from(structured['chiefComplaints'] as List<dynamic>),
      history: structured['history'] as String,
      examination: structured['examination'] as String,
      diagnoses: diagnoses,
      investigations: List<String>.from(structured['investigations'] as List<dynamic>),
      prescriptions: prescriptions,
    );

    await _encounterRepository.save(encounter);
    _latestEncounter = encounter;
    _history = await _encounterRepository.getAll();
  }
}
