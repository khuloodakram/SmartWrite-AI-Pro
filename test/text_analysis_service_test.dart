import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartwrite_ai_pro/document_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('create, update, search data and delete persist', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = DocumentStore(prefs);
    expect(store.load(), isEmpty);
    final doc = await store.create('تجربة', 'هذا نص محفوظ');
    expect(store.load().single.content, 'هذا نص محفوظ');
    await store.update(doc.copyWith(content: 'نص معدل'));
    expect(store.load().single.content, 'نص معدل');
    await store.delete(doc.id);
    expect(store.load(), isEmpty);
  });

  test('corrupt data is not overwritten', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(DocumentStore.key, '{invalid');
    final store = DocumentStore(prefs);
    expect(store.load, throwsFormatException);
    expect(prefs.getString(DocumentStore.key), '{invalid');
  });
}
