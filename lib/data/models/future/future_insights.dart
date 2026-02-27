class FutureInsights {
  const FutureInsights({
    required this.personalizedTemplate,
    required this.longitudinalSummary,
    required this.safetyAlerts,
    required this.qaFindings,
    required this.federatedStatus,
    required this.multimodalSummary,
    required this.billingSummary,
    required this.populationSignal,
    required this.voiceActions,
    required this.digitalTwinPlan,
  });

  final String personalizedTemplate;
  final String longitudinalSummary;
  final List<String> safetyAlerts;
  final List<String> qaFindings;
  final String federatedStatus;
  final String multimodalSummary;
  final String billingSummary;
  final String populationSignal;
  final List<String> voiceActions;
  final String digitalTwinPlan;

  factory FutureInsights.empty() {
    return const FutureInsights(
      personalizedTemplate: 'No personalization data yet.',
      longitudinalSummary: 'No longitudinal trend available.',
      safetyAlerts: <String>[],
      qaFindings: <String>[],
      federatedStatus: 'Idle',
      multimodalSummary: 'No multimodal data attached.',
      billingSummary: 'No billing suggestions generated.',
      populationSignal: 'No population signal generated.',
      voiceActions: <String>[],
      digitalTwinPlan: 'No simulation available.',
    );
  }
}
