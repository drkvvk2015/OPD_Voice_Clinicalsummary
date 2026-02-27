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
    if (lower.contains('follow-up') || lower.contains('follow up')) {
      actions.add(
          'Generate bilingual follow-up instruction draft (English + local language).');
    }
    if (lower.contains('discharge')) {
      actions.add(
          'Prepare voice discharge instruction checklist for clinician confirmation.');
    }
    if (lower.contains('cancel order') || lower.contains('stop order')) {
      actions.add(
          'Interruption handled: pause pending orders and request verbal confirmation.');
    }

    return actions;
  }
}
