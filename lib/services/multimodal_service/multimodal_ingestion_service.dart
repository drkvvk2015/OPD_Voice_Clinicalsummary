class MultimodalIngestionService {
  String summarizeAssets({
    required int imageCount,
    required int pdfCount,
    required int vitalsCount,
    bool labOcrEnabled = true,
    bool prescriptionPhotoParsing = true,
  }) {
    if (imageCount == 0 && pdfCount == 0 && vitalsCount == 0) {
      return 'No multimodal artifacts linked to this consultation.';
    }

    final enabled = <String>[
      if (labOcrEnabled && pdfCount > 0) 'lab OCR',
      if (prescriptionPhotoParsing && imageCount > 0)
        'prescription photo parser',
      if (vitalsCount > 0) 'vitals trend fusion',
    ];

    return 'Multimodal context: $imageCount image(s), $pdfCount PDF(s), $vitalsCount vital stream(s). '
        'Fusion modules: ${enabled.isEmpty ? 'none' : enabled.join(', ')}.';
  }
}
