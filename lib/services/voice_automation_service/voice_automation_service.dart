class VoiceAutomationService {
  List<String> suggestActions(String transcript) {
    final lower = transcript.toLowerCase();
    final actions = <String>[];

    if (lower.contains('cbc')) {
      actions.add('Create lab order: CBC');
    }
    if (lower.contains('crp')) {
      actions.add('Create lab order: CRP');
    }
    if (lower.contains('xray') || lower.contains('x-ray')) {
      actions.add('Create imaging order: Chest X-ray');
    }

    return actions;
  }
}
