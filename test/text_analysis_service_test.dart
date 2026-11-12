
import 'package:flutter_test/flutter_test.dart';
import 'package:smartwrite_ai_pro/text_analysis_service.dart';

void main() {
  const service = TextAnalysisService();

  test('اكتشاف الكلمة العربية المكررة', () {
    final issues = service.analyze('هذا هذا نص');
    expect(issues.length, 1);
    expect(issues.first.category, 'تكرار');
    expect(issues.first.replacement, 'هذا');
  });

  test('اكتشاف الكلمة الإنجليزية المكررة', () {
    final issues = service.analyze('hello hello world');
    expect(issues.length, 1);
    expect(issues.first.replacement, 'hello');
  });

  test('اكتشاف المسافات الزائدة', () {
    final issues = service.analyze('مرحبا  بالعالم');
    expect(issues.length, 1);
    expect(issues.first.category, 'مسافات');
    expect(issues.first.replacement, ' ');
  });

  test('اكتشاف غياب المسافة بعد الترقيم', () {
    final issues = service.analyze('مرحبا،كيف حالك؟');
    expect(issues.length, 1);
    expect(issues.first.category, 'ترقيم');
    expect(
      service.apply('مرحبا،كيف حالك؟', issues.first),
      'مرحبا، كيف حالك؟',
    );
  });

  test('رفض الاقتراح القديم بعد تعديل النص', () {
    final issue = service.analyze('هذا هذا نص').first;
    const changedText = 'هذه هذه نص';

    expect(
      service.apply(changedText, issue),
      changedText,
    );
  });

  test('حساب الكلمات', () {
    expect(service.wordCount(''), 0);
    expect(service.wordCount('مرحبا بالعالم'), 2);
    expect(service.wordCount('one two three'), 3);
  });
}
