import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'document_store.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});
  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  DocumentStore? store;
  List<SavedDocument> documents = [];
  String query = '';
  String? error;
  bool loading = true;

  @override
  void initState() { super.initState(); _reload(); }

  Future<void> _reload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final next = DocumentStore(prefs);
      final docs = next.load();
      if (!mounted) return;
      setState(() { store = next; documents = docs; loading = false; error = null; });
    } catch (e) {
      if (mounted) setState(() { loading = false; error = 'تعذر قراءة المستندات. لم يتم حذف البيانات.'; });
    }
  }

  Future<void> _edit([SavedDocument? existing]) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final content = TextEditingController(text: existing?.content ?? '');
    final result = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(existing == null ? 'مستند جديد' : 'تعديل المستند'),
      content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, maxLength: 120, decoration: const InputDecoration(labelText: 'عنوان المستند')),
        const SizedBox(height: 8),
        TextField(controller: content, minLines: 6, maxLines: 12, decoration: const InputDecoration(labelText: 'المحتوى', border: OutlineInputBorder())),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
      ],
    ));
    if (result == true && store != null) {
      try {
        if (existing == null) {
          await store!.create(title.text, content.text);
        } else {
          await store!.update(existing.copyWith(title: title.text.trim().isEmpty ? 'مستند بدون عنوان' : title.text.trim(), content: content.text));
        }
        await _reload();
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ المستند')));
      }
    }
    title.dispose(); content.dispose();
  }

  Future<void> _delete(SavedDocument doc) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('حذف المستند؟'),
      content: Text('سيُحذف «${doc.title}» نهائيًا من الجهاز.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
      ],
    ));
    if (confirmed != true || store == null) return;
    try { await store!.delete(doc.id); await _reload(); }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حذف المستند'))); }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = documents.where((d) =>
      d.title.toLowerCase().contains(query.toLowerCase()) ||
      d.content.toLowerCase().contains(query.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('مستنداتي'), actions: [IconButton(onPressed: _reload, tooltip: 'تحديث', icon: const Icon(Icons.refresh))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: store == null ? null : () => _edit(), icon: const Icon(Icons.add), label: const Text('مستند جديد')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
        const Text('مستندات محفوظة محليًا دون إنترنت', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 12),
        TextField(onChanged: (value) => setState(() => query = value), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'بحث بالعنوان أو المحتوى', border: OutlineInputBorder())),
        const SizedBox(height: 14),
        if (loading) const Center(child: CircularProgressIndicator()),
        if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (!loading && error == null && filtered.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('لا توجد مستندات مطابقة. اضغطي «مستند جديد» للبدء.')),
        for (final doc in filtered) Card(child: ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(doc.content.isEmpty ? 'مستند فارغ' : doc.content, maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () => _edit(doc),
          trailing: PopupMenuButton<String>(onSelected: (value) {
            if (value == 'edit') _edit(doc);
            if (value == 'delete') _delete(doc);
            if (value == 'copy') {
              Clipboard.setData(ClipboardData(text: doc.content));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ المحتوى')));
            }
          }, itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('تعديل')),
            PopupMenuItem(value: 'copy', child: Text('نسخ المحتوى')),
            PopupMenuItem(value: 'delete', child: Text('حذف')),
          ]),
        )),
      ])),
    );
  }
}
