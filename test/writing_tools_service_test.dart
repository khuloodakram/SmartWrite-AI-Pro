import 'package:flutter_test/flutter_test.dart';
import 'package:smartwrite_ai_pro/writing_tools_service.dart';

void main() {
  const tools = WritingToolsService();
  test('empty input', () {
    final result = tools.analyze('');
    expect(result.words, 0);
    expect(result.sentences, 0);
    expect(result.improved, '');
  });
  test('removes repeated Arabic words', () {
    expect(tools.analyze('هذا هذا نص').improved, 'هذا نص');
  });
  test('normalizes spaces', () {
    expect(tools.analyze('مرحبا  بالعالم').improved, 'مرحبا بالعالم');
  });
  test('inserts punctuation spacing', () {
    expect(tools.analyze('مرحبا،كيف حالك؟').improved, 'مرحبا، كيف حالك؟');
  });
  test('does not change valid text', () {
    expect(tools.analyze('نص صحيح').improved, 'نص صحيح');
  });
}
