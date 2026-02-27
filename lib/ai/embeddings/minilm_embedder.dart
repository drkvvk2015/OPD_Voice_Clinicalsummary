class MiniLmEmbedder {
  List<double> encode(String text) {
    return text.codeUnits.take(16).map((c) => c / 255.0).toList(growable: false);
  }
}
