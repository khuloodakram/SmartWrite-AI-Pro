import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Word-level suggestions from a small, locally bundled character CNN.
/// This is NOT a grammar checker or a general-purpose language model.
class NeuralSuggestion {
  final int start;
  final int end;
  final String replacement;
  final double confidence;
  const NeuralSuggestion(this.start, this.end, this.replacement, this.confidence);
}

class NeuralSpellService {
  Interpreter? _interpreter;
  Map<String, int> _charToId = {};
  List<String> _labels = [];
  int _maxLen = 28;
  double _threshold = 0.85;

  bool get isReady => _interpreter != null;

  Future<void> load() async {
    try {
      final metadataText = await rootBundle.loadString(
          'assets/models/smartwrite_spell_metadata.json');
      final metadata = jsonDecode(metadataText) as Map<String, dynamic>;
      final chars = Map<String, int>.from(metadata['char_to_id'] as Map);
      final labels = List<String>.from(metadata['labels'] as List);
      final maxLen = metadata['max_len'] as int;
      final threshold = (metadata['confidence_threshold'] as num).toDouble();
      final interpreter = await Interpreter.fromAsset(
          'assets/models/smartwrite_spell_v1.tflite');
      final inputShape = interpreter.getInputTensor(0).shape;
      final outputShape = interpreter.getOutputTensor(0).shape;
      if (inputShape.length != 2 || inputShape[0] != 1 ||
          inputShape[1] != maxLen || outputShape.length != 2 ||
          outputShape[0] != 1 || outputShape[1] != labels.length) {
        interpreter.close();
        throw StateError('Model input/output shape does not match metadata');
      }
      _charToId = chars;
      _labels = labels;
      _maxLen = maxLen;
      _threshold = threshold;
      _interpreter = interpreter;
    } catch (_) {
      _interpreter?.close();
      _interpreter = null;
    }
  }

  String _normalize(String token) => token
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
      .trim();

  /// Optimal-string-alignment distance: neighboring transpositions count as one.
  int _distance(String a, String b) {
    final x = a.runes.toList();
    final y = b.runes.toList();
    final d = List.generate(x.length + 1,
        (_) => List<int>.filled(y.length + 1, 0));
    for (var i = 0; i <= x.length; i++) { d[i][0] = i; }
    for (var j = 0; j <= y.length; j++) { d[0][j] = j; }
    for (var i = 1; i <= x.length; i++) {
      for (var j = 1; j <= y.length; j++) {
        final cost = x[i - 1] == y[j - 1] ? 0 : 1;
        var best = d[i - 1][j] + 1;
        if (d[i][j - 1] + 1 < best) best = d[i][j - 1] + 1;
        if (d[i - 1][j - 1] + cost < best) best = d[i - 1][j - 1] + cost;
        if (i > 1 && j > 1 && x[i - 1] == y[j - 2] &&
            x[i - 2] == y[j - 1] && d[i - 2][j - 2] + 1 < best) {
          best = d[i - 2][j - 2] + 1;
        }
        d[i][j] = best;
      }
    }
    return d[x.length][y.length];
  }

  List<NeuralSuggestion> suggest(String text) {
    final interpreter = _interpreter;
    if (interpreter == null) return [];
    final suggestions = <NeuralSuggestion>[];
    final tokens = RegExp(r'[\p{L}\p{M}]+', unicode: true).allMatches(text);
    var examined = 0;
    for (final match in tokens) {
      if (examined++ >= 120) break; // avoid excessive synchronous work
      final original = match.group(0)!;
      final normalized = _normalize(original);
      final chars = normalized.runes.toList();
      if (chars.length < 3 || chars.length > _maxLen) continue;
      final ids = List<int>.filled(_maxLen, 0);
      var supported = true;
      for (var i = 0; i < chars.length; i++) {
        final id = _charToId[String.fromCharCode(chars[i])];
        if (id == null) { supported = false; break; }
        ids[i] = id;
      }
      if (!supported) continue;
      final output = [List<double>.filled(_labels.length, 0.0)];
      try {
        interpreter.run([ids], output);
      } catch (_) {
        return suggestions; // rule-based engine remains available
      }
      var bestIndex = 0;
      var confidence = output[0][0];
      for (var i = 1; i < _labels.length; i++) {
        if (output[0][i] > confidence) {
          confidence = output[0][i];
          bestIndex = i;
        }
      }
      final replacement = _labels[bestIndex];
      if (replacement == '__KEEP__' || confidence < _threshold ||
          _normalize(replacement) == normalized) continue;
      final distance = _distance(normalized, _normalize(replacement));
      final maxDistance = chars.length <= 5 ? 1 : 2;
      if (distance > maxDistance) continue;
      suggestions.add(NeuralSuggestion(
          match.start, match.end, replacement, confidence));
    }
    return suggestions;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
