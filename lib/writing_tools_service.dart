import 'text_analysis_service.dart';

class WritingAnalysis {
  final String original;
  final String improved;
  final int words;
  final int characters;
  final int sentences;
  final int suggestions;
  const WritingAnalysis(this.original, this.improved, this.words, this.characters, this.sentences, this.suggestions);
}

class WritingToolsService {
  const WritingToolsService();
  WritingAnalysis analyze(String input) {
    const analyzer = TextAnalysisService();
    var result = input;
    var changes = 0;
    // Re-analyze after each edit so offsets remain valid.
    // Cap iterations to prevent accidental infinite loops.
    for (var round = 0; round < 100; round++) {
      final issues = analyzer.analyze(result);
      if (issues.isEmpty) break;
      final next = analyzer.apply(result, issues.first);
      if (next == result) break;
      result = next;
      changes++;
    }
    final trimmed = input.trim();
    final sentenceParts = trimmed.isEmpty ? <String>[] : trimmed.split(RegExp(r'[.!?؟\n]+')).where((part) => part.trim().isNotEmpty).toList();
    return WritingAnalysis(input, result, analyzer.wordCount(input), input.runes.length, sentenceParts.length, changes);
  }
}
