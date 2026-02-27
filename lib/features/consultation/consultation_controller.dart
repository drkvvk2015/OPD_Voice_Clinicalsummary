import 'package:flutter/foundation.dart';

import '../../ai/llama/llama_extractor.dart';
import '../../ai/whisper/whisper_cpp_adapter.dart';
import '../../ai/whisper/whisper_engine.dart';
import '../../data/db/local_database.dart';
import '../../data/models/encounter.dart';
import '../../data/models/future/future_insights.dart';
import '../../data/models/patient.dart';
import '../../data/repositories/encounter_repository.dart';
import '../../services/audio_service/audio_service.dart';
import '../../services/coding_service/coding_billing_service.dart';
import '../../services/diagnosis_service/diagnosis_service.dart';
import '../../services/digital_twin_service/digital_twin_service.dart';
import '../../services/extraction_service/clinical_extraction_service.dart';
import '../../services/extraction_service/structured_extraction_validator.dart';
import '../../services/federated_service/federated_learning_service.dart';
import '../../services/longitudinal_service/longitudinal_service.dart';
import '../../services/multimodal_service/multimodal_ingestion_service.dart';
import '../../services/personalization_service/personalization_service.dart';
import '../../services/population_health_service/population_health_service.dart';
import '../../services/prescription_parser/prescription_parse_result.dart';
import '../../services/prescription_parser/prescription_parser_service.dart';
import '../../services/qa_service/documentation_qa_service.dart';
import '../../services/safety_service/clinical_safety_service.dart';
import '../../services/sync_service/sync_queue_service.dart';
import '../../services/voice_automation_service/voice_automation_service.dart';

class ConsultationController extends ChangeNotifier {
  ConsultationController({
    required AudioService audioService,
    required WhisperEngine whisperEngine,
    required ClinicalExtractionService extractionService,
    required DiagnosisService diagnosisService,
    required PrescriptionParserService prescriptionParserService,
    required EncounterRepository encounterRepository,
    required SyncQueueService syncQueueService,
    required PersonalizationService personalizationService,
    required LongitudinalService longitudinalService,
    required ClinicalSafetyService clinicalSafetyService,
    required DocumentationQaService documentationQaService,
    required FederatedLearningService federatedLearningService,
    required MultimodalIngestionService multimodalIngestionService,
    required CodingBillingService codingBillingService,
    required PopulationHealthService populationHealthService,
    required VoiceAutomationService voiceAutomationService,
    required DigitalTwinService digitalTwinService,
  })  : _audioService = audioService,
        _whisperEngine = whisperEngine,
        _extractionService = extractionService,
        _diagnosisService = diagnosisService,
        _prescriptionParserService = prescriptionParserService,
        _encounterRepository = encounterRepository,
        _syncQueueService = syncQueueService,
        _personalizationService = personalizationService,
        _longitudinalService = longitudinalService,
        _clinicalSafetyService = clinicalSafetyService,
        _documentationQaService = documentationQaService,
        _federatedLearningService = federatedLearningService,
        _multimodalIngestionService = multimodalIngestionService,
        _codingBillingService = codingBillingService,
        _populationHealthService = populationHealthService,
        _voiceAutomationService = voiceAutomationService,
        _digitalTwinService = digitalTwinService;

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
      personalizationService: PersonalizationService(),
      longitudinalService: LongitudinalService(),
      clinicalSafetyService: ClinicalSafetyService(),
      documentationQaService: DocumentationQaService(),
      federatedLearningService: FederatedLearningService(),
      multimodalIngestionService: MultimodalIngestionService(),
      codingBillingService: CodingBillingService(),
      populationHealthService: PopulationHealthService(),
      voiceAutomationService: VoiceAutomationService(),
      digitalTwinService: DigitalTwinService(),
    );
  }

  final AudioService _audioService;
  final WhisperEngine _whisperEngine;
  final ClinicalExtractionService _extractionService;
  final DiagnosisService _diagnosisService;
  final PrescriptionParserService _prescriptionParserService;
  final EncounterRepository _encounterRepository;
  final SyncQueueService _syncQueueService;
  final PersonalizationService _personalizationService;
  final LongitudinalService _longitudinalService;
  final ClinicalSafetyService _clinicalSafetyService;
  final DocumentationQaService _documentationQaService;
  final FederatedLearningService _federatedLearningService;
  final MultimodalIngestionService _multimodalIngestionService;
  final CodingBillingService _codingBillingService;
  final PopulationHealthService _populationHealthService;
  final VoiceAutomationService _voiceAutomationService;
  final DigitalTwinService _digitalTwinService;

  bool _isBusy = false;
  bool _isSyncing = false;
  String _transcript = '';
  String? _errorMessage;
  Encounter? _latestEncounter;
  List<Encounter> _history = const [];
  List<String> _clinicalWarnings = const [];
  List<String> _interactionWarnings = const [];
  FutureInsights _futureInsights = FutureInsights.empty();

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
  FutureInsights get futureInsights => _futureInsights;

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
    await _buildFutureInsights(encounter);
  }

  Future<void> _buildFutureInsights(Encounter encounter) async {
    final safetyAlerts = _clinicalSafetyService.evaluate(encounter);
    final qaFindings = _documentationQaService.audit(encounter);
    final federatedStatus = await _federatedLearningService.createLocalUpdate(_history);

    _futureInsights = FutureInsights(
      personalizedTemplate: _personalizationService.suggestTemplate(_history),
      longitudinalSummary: _longitudinalService.summarize(_history),
      safetyAlerts: safetyAlerts,
      qaFindings: qaFindings,
      federatedStatus: federatedStatus,
      multimodalSummary: _multimodalIngestionService.summarizeAssets(imageCount: 0, pdfCount: 0, vitalsCount: 0),
      billingSummary: _codingBillingService.buildSuggestion(encounter.diagnoses),
      populationSignal: _populationHealthService.detectSignal(_history),
      voiceActions: _voiceAutomationService.suggestActions(encounter.transcript),
      digitalTwinPlan: _digitalTwinService.simulatePlan(encounter),
    );
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
