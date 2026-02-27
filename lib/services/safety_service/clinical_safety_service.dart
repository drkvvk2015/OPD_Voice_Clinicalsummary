import '../../data/models/encounter.dart';

class ClinicalSafetyService {
  List<String> evaluate(Encounter encounter) {
    final alerts = <String>[];
    final clinicalText =
        '${encounter.transcript} ${encounter.history}'.toLowerCase();

    if (_containsRedFlagSymptoms(clinicalText)) {
      alerts.add(
          'Red flag symptoms detected. Consider immediate referral/escalation.');
    }

    if (encounter.prescriptions.isEmpty) {
      alerts.add(
          'No medications parsed. Confirm if treatment plan intentionally non-pharmacologic.');
    }

    if (encounter.investigations.isEmpty) {
      alerts.add(
          'No investigations listed. Verify if watchful waiting is intended.');
    }

    _addAllergyAlerts(encounter, clinicalText, alerts);
    _addPregnancyAlerts(encounter, clinicalText, alerts);
    _addRenalHepaticRiskAlerts(encounter, clinicalText, alerts);
    _addDoseRangeAlerts(encounter, alerts);

    return alerts;
  }

  bool _containsRedFlagSymptoms(String text) {
    return text.contains('chest pain') ||
        text.contains('breathlessness') ||
        text.contains('shortness of breath') ||
        text.contains('syncope') ||
        text.contains('seizure') ||
        text.contains('altered sensorium');
  }

  void _addAllergyAlerts(
      Encounter encounter, String text, List<String> alerts) {
    final allergyMatches =
        RegExp(r'allerg(?:y|ic)\s*(?:to)?\s+([a-z]+)').allMatches(text);
    final parsedAllergyTokens = allergyMatches
        .map((m) => m.group(1))
        .whereType<String>()
        .map((s) => s.toLowerCase())
        .toSet();
    final profileAllergyTokens =
        encounter.patient.allergies.map((a) => a.toLowerCase()).toSet();
    final allergyTokens = <String>{
      ...parsedAllergyTokens,
      ...profileAllergyTokens,
    };

    if (allergyTokens.isEmpty) {
      return;
    }

    for (final medication in encounter.prescriptions) {
      final drugLower = medication.drug.toLowerCase();
      if (allergyTokens.any((token) => drugLower.contains(token))) {
        alerts.add(
            'Potential contraindication: documented allergy signal overlaps prescribed drug '
            '(${medication.drug}).');
      }
    }
  }

  void _addPregnancyAlerts(
      Encounter encounter, String text, List<String> alerts) {
    final possiblePregnancy =
        encounter.patient.isPregnant || text.contains('pregnan');
    if (!possiblePregnancy) {
      return;
    }

    for (final medication in encounter.prescriptions) {
      final drugLower = medication.drug.toLowerCase();
      if (drugLower.contains('ibuprofen') || drugLower.contains('diclofenac')) {
        alerts.add(
            'Pregnancy risk check: ${medication.drug} may be unsuitable in pregnancy; '
            'verify trimester-specific guidance.');
      }
    }
  }

  void _addRenalHepaticRiskAlerts(
      Encounter encounter, String text, List<String> alerts) {
    final hasRenalRisk = encounter.patient.hasRenalRisk ||
        text.contains('renal') ||
        text.contains('kidney');
    final hasHepaticRisk = encounter.patient.hasHepaticRisk ||
        text.contains('hepatic') ||
        text.contains('liver');
    if (!hasRenalRisk && !hasHepaticRisk) {
      return;
    }

    for (final medication in encounter.prescriptions) {
      final drugLower = medication.drug.toLowerCase();
      if (drugLower.contains('ibuprofen') || drugLower.contains('diclofenac')) {
        alerts.add(
            'Renal/hepatic caution: NSAID ${medication.drug} in risk context, verify benefit-risk '
            'and monitoring plan.');
      }
    }
  }

  void _addDoseRangeAlerts(Encounter encounter, List<String> alerts) {
    final referenceRanges = <String, ({int min, int max})>{
      'paracetamol': (min: 325, max: 1000),
      'cetirizine': (min: 5, max: 10),
      'ibuprofen': (min: 200, max: 400),
      'diclofenac': (min: 25, max: 50),
      'azithromycin': (min: 250, max: 500),
    };

    for (final medication in encounter.prescriptions) {
      final doseMg = _extractDoseMg(medication.dose);
      if (doseMg == null) {
        continue;
      }

      final key = medication.drug.toLowerCase();
      final range = referenceRanges[key];
      if (range == null) {
        continue;
      }

      if (doseMg < range.min || doseMg > range.max) {
        alerts.add(
            'Dose-range warning: ${medication.drug} $doseMg mg is outside typical single-dose '
            'range ${range.min}-${range.max} mg.');
      }

      if (encounter.patient.age < 12) {
        alerts.add(
            'Pediatric safety check required for ${medication.drug}; confirm weight-based dosing.');
      }
    }
  }

  int? _extractDoseMg(String doseText) {
    final match =
        RegExp(r'(\d+)\s*mg', caseSensitive: false).firstMatch(doseText);
    return int.tryParse(match?.group(1) ?? '');
  }
}
