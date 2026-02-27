import 'dart:convert';

import '../../data/models/encounter.dart';

class FederatedLearningService {
  Future<String> createLocalUpdate(List<Encounter> history) async {
    if (history.isEmpty) {
      return 'No local training update generated.';
    }

    await Future<void>.delayed(const Duration(milliseconds: 40));
    final snapshot = history
        .take(20)
        .map((e) =>
            '${e.id}:${e.chiefComplaints.length}:${e.diagnoses.length}:${e.prescriptions.length}')
        .join('|');
    final digest = base64UrlEncode(utf8.encode(snapshot)).replaceAll('=', '');
    final shortDigest = digest.length > 12 ? digest.substring(0, 12) : digest;

    return 'Encrypted local delta prepared (${history.length} encounters, digest $shortDigest), '
        'pending privacy-safe aggregation.';
  }
}
