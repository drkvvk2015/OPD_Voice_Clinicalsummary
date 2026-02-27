import 'dart:async';
import 'dart:math';

import 'package:speech_to_text/speech_to_text.dart';

class AudioService {
  AudioService({SpeechToText? speechToText})
      : _speechToText = speechToText ?? SpeechToText();

  final SpeechToText _speechToText;
  bool _recording = false;
  String? _activeSessionId;
  double _voiceLevel = 0;
  bool _micCheckInProgress = false;
  DateTime? _recordingStartedAt;
  Timer? _levelTimer;
  final Random _random = Random();
  String _liveTranscript = '';
  String _finalTranscript = '';
  bool _speechAvailable = false;
  String? _lastSpeechError;
  String _status = 'idle';
  String _accumulatedTranscript = '';
  String _partialTranscript = '';
  bool _isRestartingListener = false;

  bool get isRecording => _recording;
  String? get activeSessionId => _activeSessionId;
  double get voiceLevel => _voiceLevel;
  bool get isMicCheckInProgress => _micCheckInProgress;
  String get liveTranscript => _liveTranscript;
  String get finalTranscript => _finalTranscript;
  bool get isSpeechAvailable => _speechAvailable;
  String? get lastSpeechError => _lastSpeechError;
  String get status => _status;

  Future<String> startRecording() async {
    _levelTimer?.cancel();
    _recording = true;
    _activeSessionId = 'audio_session_${DateTime.now().millisecondsSinceEpoch}';
    _recordingStartedAt = DateTime.now();
    _micCheckInProgress = true;
    _voiceLevel = 0;
    _liveTranscript = '';
    _finalTranscript = '';
    _accumulatedTranscript = '';
    _partialTranscript = '';
    _speechAvailable = false;
    _lastSpeechError = null;
    _status = 'starting';
    _isRestartingListener = false;

    final initialized = await _tryInitializeSpeech();
    if (initialized) {
      await _startSpeechRecognition();
    } else {
      _startSimulatedLevelUpdates();
    }
    return _activeSessionId!;
  }

  Future<String?> stopRecording() async {
    _recording = false;
    _isRestartingListener = false;
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
    _levelTimer?.cancel();
    _levelTimer = null;
    _voiceLevel = 0;
    _micCheckInProgress = false;
    _recordingStartedAt = null;
    _status = 'stopped';
    _finalTranscript =
        _mergeTranscript(_accumulatedTranscript, _partialTranscript).trim();
    _liveTranscript = _finalTranscript;
    final session = _activeSessionId;
    _activeSessionId = null;
    return session;
  }

  Future<bool> _tryInitializeSpeech() async {
    try {
      _speechAvailable = await _speechToText.initialize(
        onError: (error) {
          _lastSpeechError = error.errorMsg;
          _status = 'error';
        },
        onStatus: (status) {
          _status = status;
          if (status == 'notListening' || status == 'done') {
            _micCheckInProgress = false;
            if (_recording && _speechAvailable) {
              unawaited(_restartSpeechRecognition());
            }
          }
        },
      );
      return _speechAvailable;
    } catch (error) {
      _lastSpeechError = error.toString();
      _speechAvailable = false;
      return false;
    }
  }

  Future<void> _startSpeechRecognition() async {
    _levelTimer?.cancel();
    _levelTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      if (!_recording) {
        return;
      }
      final elapsed = DateTime.now().difference(_recordingStartedAt!);
      _micCheckInProgress = elapsed < const Duration(seconds: 2);
      if (_voiceLevel <= 0) {
        _voiceLevel = _micCheckInProgress
            ? (0.12 + _random.nextDouble() * 0.15)
            : (0.2 + _random.nextDouble() * 0.35);
      }
    });

    try {
      await _speechToText.listen(
        onResult: (result) {
          final recognized = _normalizeTranscript(result.recognizedWords);
          if (recognized.isEmpty) {
            return;
          }
          if (result.finalResult) {
            _accumulatedTranscript =
                _mergeTranscript(_accumulatedTranscript, recognized);
            _partialTranscript = '';
            _finalTranscript = _accumulatedTranscript.trim();
            _liveTranscript = _finalTranscript;
            return;
          }
          _partialTranscript = recognized;
          _liveTranscript =
              _mergeTranscript(_accumulatedTranscript, recognized);
        },
        onSoundLevelChange: (level) {
          _voiceLevel = _normalizeSoundLevel(level);
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
        ),
      );
      _status = 'listening';
    } catch (error) {
      _lastSpeechError = error.toString();
      _speechAvailable = false;
      _startSimulatedLevelUpdates();
    }
  }

  Future<void> _restartSpeechRecognition() async {
    if (!_recording || _isRestartingListener || _speechToText.isListening) {
      return;
    }
    _isRestartingListener = true;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (_recording && !_speechToText.isListening) {
        await _startSpeechRecognition();
      }
    } finally {
      _isRestartingListener = false;
    }
  }

  void _startSimulatedLevelUpdates() {
    _levelTimer?.cancel();
    _levelTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      if (!_recording) {
        return;
      }
      final elapsed = DateTime.now().difference(_recordingStartedAt!);
      _micCheckInProgress = elapsed < const Duration(seconds: 2);
      if (_micCheckInProgress) {
        _voiceLevel = 0.12 + _random.nextDouble() * 0.25;
      } else {
        _voiceLevel = 0.2 + _random.nextDouble() * 0.75;
      }
    });
  }

  double _normalizeSoundLevel(double rawLevel) {
    // Typical callbacks vary roughly between -2..10 depending on platform/device.
    final normalized = ((rawLevel + 2) / 12).clamp(0, 1);
    return normalized.toDouble();
  }

  String _mergeTranscript(String existing, String incoming) {
    final base = _normalizeTranscript(existing);
    final next = _normalizeTranscript(incoming);
    if (base.isEmpty) {
      return next;
    }
    if (next.isEmpty) {
      return base;
    }
    if (base == next) {
      return base;
    }
    if (next.startsWith(base)) {
      return next;
    }
    if (base.startsWith(next)) {
      return base;
    }

    final baseWords = base.split(' ');
    final nextWords = next.split(' ');
    final maxOverlap = min(baseWords.length, nextWords.length);
    for (var overlap = maxOverlap; overlap > 0; overlap--) {
      final baseTail = baseWords.sublist(baseWords.length - overlap).join(' ');
      final nextHead = nextWords.sublist(0, overlap).join(' ');
      if (baseTail == nextHead) {
        final suffix = nextWords.sublist(overlap).join(' ');
        return suffix.isEmpty ? base : '$base $suffix';
      }
    }
    return '$base $next';
  }

  String _normalizeTranscript(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void dispose() {
    _levelTimer?.cancel();
  }
}
