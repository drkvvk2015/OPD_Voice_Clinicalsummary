class MultimodalIngestionService {
  String summarizeAssets({required int imageCount, required int pdfCount, required int vitalsCount}) {
    if (imageCount == 0 && pdfCount == 0 && vitalsCount == 0) {
      return 'No multimodal artifacts linked to this consultation.';
    }
    return 'Multimodal context: $imageCount image(s), $pdfCount PDF(s), $vitalsCount vital stream(s).';
  }
}
