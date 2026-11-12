/// Deterministic offline text quality checks.
/// Complements, but does not replace, the existing TFLite spelling model.
class TextQualityIssue {
  final int start;
  final int end;
  final String original;
  final String replacement;
  final String category;
  final String explanation;

  const TextQualityIssue({
    required this.start,
    required this.end,
    required this.original,
    required this.replacement,
    required this.category,
    required this.explanation,
  });
}

class TextAnalysisService {
  const TextAnalysisService();

  List<TextQualityIssue> analyze(String text) {
    final candidates = <TextQualityIssue>[];
    void add(int start, int end, String replacement, String category, String explanation) {
      if (start < 0 || end > text.length || start >= end) return;
      final original = text.substring(start, end);
      if (original == replacement) return;
      candidates.add(TextQualityIssue(
        start: start, end: end, original: original,
        replacement: replacement, category: category, explanation: explanation,
      ));
    }

    // Whitespace after punctuation, without changing URLs or decimal numbers.
    final punctuation = RegExp(r'([،؛؟!?])([^\s\r\n\d،؛؟!?])', unicode: true);
    for (final match in punctuation.allMatches(text)) {
      final next = match.group(2)!;
      add(match.start, match.end, '${match.group(1)} $next',
          'ترقيم', 'يُفضّل وضع مسافة بعد علامة الترقيم.');
    }

    // Multiple spaces inside a line; never touch indentation at line starts.
    final spaces = RegExp(r'(?<=\S) {2,}(?=\S)');
    for (final match in spaces.allMatches(text)) {
      add(match.start, match.end, ' ', 'مسافات', 'استخدمي مسافة واحدة بين الكلمات.');
    }

    // Immediately repeated words, Arabic and English, case-insensitive.
    final repeated = RegExp(r'(?<![\p{L}\p{N}])([\p{L}\p{M}]+)([ \t]+)\1(?![\p{L}\p{N}])',
        unicode: true, caseSensitive: false);
    for (final match in repeated.allMatches(text)) {
      add(match.start, match.end, match.group(1)!,
          'تكرار', 'الكلمة مكررة مرتين متتاليتين؛ راجعي إن كان التكرار مقصودًا.');
    }

    // Do not display conflicting underlines for the same characters.
    candidates.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart != 0 ? byStart : (b.end - b.start).compareTo(a.end - a.start);
    });
    final result = <TextQualityIssue>[];
    var lastEnd = -1;
    for (final issue in candidates) {
      if (issue.start < lastEnd) continue;
      result.add(issue);
      lastEnd = issue.end;
    }
    return result;
  }

  String apply(String text, TextQualityIssue issue) {
    if (issue.start < 0 || issue.end > text.length || issue.start >= issue.end ||
        text.substring(issue.start, issue.end) != issue.original) {
      return text; // Reject stale suggestions after user edits.
    }
    return text.replaceRange(issue.start, issue.end, issue.replacement);
  }

  int wordCount(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;
  }
}
