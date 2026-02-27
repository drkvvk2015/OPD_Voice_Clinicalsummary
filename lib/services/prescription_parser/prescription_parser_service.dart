import '../../data/models/prescription_row.dart';
import 'drug_interaction_checker.dart';
import 'prescription_parse_result.dart';

class PrescriptionParserService {
  PrescriptionParserService({DrugInteractionChecker? interactionChecker})
      : _interactionChecker = interactionChecker ?? DrugInteractionChecker();

  final DrugInteractionChecker _interactionChecker;

  static final _drugMap = <String, String>{
    'pcm': 'Paracetamol',
    'paracetamol': 'Paracetamol',
    'cetirizine': 'Cetirizine',
    'azithromycin': 'Azithromycin',
    'ibuprofen': 'Ibuprofen',
    'diclofenac': 'Diclofenac',
  };

  PrescriptionParseResult parse(String transcript) {
    final lower = transcript.toLowerCase();
    final rows = <PrescriptionRow>[];

    for (final entry in _drugMap.entries) {
      if (!lower.contains(entry.key)) {
        continue;
      }

      final dose = _extractDose(lower, entry.key) ?? 'Standard dose';
      final frequency = _extractFrequency(lower);
      final duration = _extractDuration(lower);
      final route = _extractRoute(lower);

      rows.add(
        PrescriptionRow(
          drug: entry.value,
          dose: dose,
          frequency: frequency,
          duration: duration,
          route: route,
        ),
      );
    }

    final deduped = {
      for (final row in rows) '${row.drug}-${row.dose}-${row.frequency}-${row.duration}-${row.route}': row,
    }.values.toList(growable: false);

    return PrescriptionParseResult(rows: deduped, warnings: _interactionChecker.check(deduped));
  }

  String? _extractDose(String text, String token) {
    final pattern = RegExp('$token[^0-9]{0,12}([0-9]{2,4}\\s?(mg|ml))');
    final match = pattern.firstMatch(text);
    return match?.group(1)?.toUpperCase();
  }

  String _extractFrequency(String text) {
    if (text.contains('tid') || text.contains('thrice daily')) return 'TID';
    if (text.contains('bid') || text.contains('twice daily')) return 'BID';
    if (text.contains('od') || text.contains('once daily')) return 'OD';
    if (text.contains('sos')) return 'SOS';
    return 'As directed';
  }

  String _extractDuration(String text) {
    final match = RegExp(r'for\s+(\d+)\s+(day|days|week|weeks)').firstMatch(text);
    if (match != null) {
      return '${match.group(1)} ${match.group(2)}';
    }
    return 'Until follow-up';
  }

  String _extractRoute(String text) {
    if (text.contains('iv') || text.contains('intravenous')) return 'IV';
    if (text.contains('im') || text.contains('intramuscular')) return 'IM';
    return 'Oral';
  }
}
