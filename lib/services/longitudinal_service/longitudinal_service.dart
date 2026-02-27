import '../../data/models/encounter.dart';

class LongitudinalService {
  String summarize(List<Encounter> history) {
    if (history.length < 2) {
      return 'Need at least 2 encounters for trend analysis.';
    }

    final last = history.first;
    final prev = history[1];
    final overlap = last.chiefComplaints
        .where(prev.chiefComplaints.contains)
        .toList(growable: false);

    if (overlap.isEmpty) {
      return 'No recurring complaints between recent visits.';
    }

    return 'Recurring complaints across recent visits: ${overlap.join(', ')}. '
        'Trend-aware plan recommended.';
  }

  List<String> detectDeviationAlerts(List<Encounter> history) {
    if (history.length < 3) {
      return const [];
    }

    final recent = history.take(6).toList(growable: false);
    final alerts = <String>[];

    final antibioticCount = recent
        .expand((e) => e.prescriptions)
        .where((p) => _isAntibiotic(p.drug))
        .length;
    if (antibioticCount >= 3) {
      alerts.add(
          'Deviation alert: frequent antibiotic exposure in recent encounters; '
          'review antimicrobial stewardship.');
    }

    final recurringComplaintCounts = <String, int>{};
    for (final complaint in recent.expand((e) => e.chiefComplaints)) {
      final key = complaint.toLowerCase();
      recurringComplaintCounts[key] = (recurringComplaintCounts[key] ?? 0) + 1;
    }
    for (final entry in recurringComplaintCounts.entries) {
      if (entry.value >= 4) {
        alerts.add(
            'Deviation alert: persistent complaint "${entry.key}" across ${entry.value} recent records.');
      }
    }

    return alerts;
  }

  String buildFollowUpPlan(List<Encounter> history) {
    if (history.isEmpty) {
      return 'No follow-up plan generated.';
    }

    final latest = history.first;
    final hasRedFlags = latest.chiefComplaints.any(
      (c) =>
          c.toLowerCase().contains('chest pain') ||
          c.toLowerCase().contains('breathlessness'),
    );
    if (hasRedFlags) {
      return 'Schedule urgent follow-up within 24 hours and ensure escalation pathway is documented.';
    }

    final hasFever =
        latest.chiefComplaints.any((c) => c.toLowerCase() == 'fever');
    if (hasFever) {
      return 'Follow-up in 48-72 hours for fever trend, hydration status, and vitals reassessment.';
    }

    return 'Routine follow-up in 5-7 days with symptom progression review.';
  }

  bool _isAntibiotic(String drugName) {
    final lower = drugName.toLowerCase();
    return lower.contains('azithromycin') ||
        lower.contains('amoxicillin') ||
        lower.contains('cef') ||
        lower.contains('doxy');
  }
}
