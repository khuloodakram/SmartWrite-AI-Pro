
class NeuralSuggestion {
  final int start;
  final int end;
  final String replacement;
  final double confidence;

  const NeuralSuggestion({
    required this.start,
    required this.end,
    required this.replacement,
    required this.confidence,
  });
}

class NeuralSpellService {
  bool get isReady => false;

  Future<void> load() async {}

  List<NeuralSuggestion> suggest(String text) {
    return const <NeuralSuggestion>[];
  }

  void dispose() {}
}
