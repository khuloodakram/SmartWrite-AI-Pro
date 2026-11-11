import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const SmartWriteApp());

const navy = Color(0xFF101027);
const purple = Color(0xFF8657F6);
const cyan = Color(0xFF37D5F3);

class SmartWriteApp extends StatefulWidget {
  const SmartWriteApp({super.key});
  @override
  State<SmartWriteApp> createState() => _SmartWriteAppState();
}

class _SmartWriteAppState extends State<SmartWriteApp> {
  bool dark = true;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'SmartWrite AI Pro',
    theme: ThemeData(useMaterial3: true, brightness: dark ? Brightness.dark : Brightness.light,
      colorSchemeSeed: purple, scaffoldBackgroundColor: dark ? navy : const Color(0xFFF6F4FD),
      fontFamily: 'Roboto'),
    home: EditorPage(dark: dark, toggleTheme: () => setState(() => dark = !dark)),
  );
}

class Correction {
  final String before, after, explanation;
  const Correction(this.before, this.after, this.explanation);
}

// Explicitly rule-based offline demo, not a trained AI model.
List<Correction> checkText(String text) {
  const rules = <Correction>[
    Correction('انشاء الله', 'إن شاء الله', 'تصحيح كتابة العبارة'),
    Correction('ان شاء الله', 'إن شاء الله', 'تصحيح الهمزة'),
    Correction('لاكن', 'لكن', 'تصحيح إملائي'),
    Correction('هاذا', 'هذا', 'تصحيح إملائي'),
    Correction('هاذه', 'هذه', 'تصحيح إملائي'),
    Correction('مسؤليه', 'مسؤولية', 'تصحيح إملائي'),
    Correction('الى', 'إلى', 'تصحيح الهمزة'),
    Correction('الان', 'الآن', 'تصحيح الهمزة'),
    Correction('definately', 'definitely', 'English spelling'),
    Correction('recieve', 'receive', 'English spelling'),
    Correction('teh', 'the', 'English spelling'),
  ];
  final found = <Correction>[];
  for (final rule in rules) {
    if (text.contains(rule.before)) found.add(rule);
  }
  return found;
}

class EditorPage extends StatefulWidget {
  final bool dark;
  final VoidCallback toggleTheme;
  const EditorPage({super.key, required this.dark, required this.toggleTheme});
  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final controller = TextEditingController();
  List<Correction> suggestions = [];
  int tab = 0;
  final history = <String>[];
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  void inspect() {
    setState(() { suggestions = checkText(controller.text); tab = 0; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(suggestions.isEmpty ? 'لم يجد الفحص المحلي أخطاء ضمن القواعد المتاحة' : 'تم العثور على ${suggestions.length} اقتراحات')));
  }
  void apply(Correction correction) {
    setState(() {
      history.insert(0, controller.text);
      controller.text = controller.text.replaceAll(correction.before, correction.after);
      suggestions = checkText(controller.text);
    });
  }
  Widget pill(String text, IconData icon, VoidCallback onTap) => OutlinedButton.icon(
    onPressed: onTap, icon: Icon(icon, size: 17), label: Text(text),
    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12)),
  );
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = widget.dark ? const Color(0xFF1C1B38) : Colors.white;
    final count = controller.text.trim().isEmpty ? 0 : controller.text.trim().split(RegExp(r'\s+')).length;
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('SmartWrite  AI Pro', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: .3)),
        actions: [IconButton(tooltip: 'تبديل المظهر', onPressed: widget.toggleTheme, icon: Icon(widget.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined))]),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(18), children: [
        Container(padding: const EdgeInsets.all(19), decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF6D3CE0), Color(0xFF253B94)]), borderRadius: BorderRadius.circular(24)),
          child: Row(children: [const Icon(Icons.auto_awesome, size: 42, color: Colors.white), const SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('اكتب بثقة وإبداع', style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5), Text('محرر احترافي • فحص محلي أولي', style: TextStyle(color: Colors.white.withValues(alpha: .85)))
            ]))])),
        const SizedBox(height: 20),
        Row(children: [const Text('مساحة الكتابة', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const Spacer(), const Icon(Icons.lock_outline, size: 16, color: cyan), const SizedBox(width: 5), const Text('بدون إنترنت', style: TextStyle(fontSize: 12, color: cyan))]),
        const SizedBox(height: 10),
        Container(decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: purple.withValues(alpha: .25))),
          child: Column(children: [
            TextField(controller: controller, minLines: 8, maxLines: 14, onChanged: (_) => setState(() {}),
              textDirection: TextDirection.rtl, decoration: const InputDecoration(
                hintText: 'ابدأ بكتابة نصك هنا...\nمثال: هاذا النص يحتاج الى تصحيح', border: InputBorder.none,
                contentPadding: EdgeInsets.all(18))),
            Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 10), child: Row(children: [
              Text('$count كلمة  •  ${controller.text.length} حرف', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
              const Spacer(), IconButton(tooltip: 'نسخ النص', onPressed: () { Clipboard.setData(ClipboardData(text: controller.text)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ النص'))); }, icon: const Icon(Icons.copy_outlined)),
              IconButton(tooltip: 'مسح', onPressed: () => setState(() { controller.clear(); suggestions = []; }), icon: const Icon(Icons.delete_outline))
            ]))
          ])),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: inspect,
          style: FilledButton.styleFrom(backgroundColor: purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 17)),
          icon: const Icon(Icons.auto_fix_high), label: const Text('فحص النص وعرض الاقتراحات', style: TextStyle(fontWeight: FontWeight.bold)))),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 3, children: [
          pill('اقتراحات', Icons.fact_check_outlined, () => setState(() => tab = 0)),
          pill('السجل', Icons.history, () => setState(() => tab = 1)),
          pill('الأدوات القادمة', Icons.auto_awesome_motion, () => setState(() => tab = 2)),
        ]),
        const SizedBox(height: 12),
        if (tab == 0) ...[
          Text('الاقتراحات (${suggestions.length})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (suggestions.isEmpty) Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(18)),
            child: const Text('اضغط «فحص النص» لرؤية اقتراحات التصحيح المحلي. الفحص الحالي محدود بقواعد محددة.')),
          for (final s in suggestions) Card(color: surface, margin: const EdgeInsets.only(bottom: 9), child: Padding(padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.explanation, style: const TextStyle(color: cyan, fontSize: 12)), const SizedBox(height: 8),
              Text('${s.before}   ←   ${s.after}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => apply(s), icon: const Icon(Icons.check_circle_outline), label: const Text('تطبيق التصحيح')))
            ])))
        ] else if (tab == 1) ...[
          const Text('النسخ السابقة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          if (history.isEmpty) const Padding(padding: EdgeInsets.all(18), child: Text('لا توجد تعديلات بعد')),
          for (final item in history) ListTile(title: Text(item, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.restore), onTap: () => setState(() { controller.text = item; suggestions = checkText(item); tab = 0; }))
        ] else Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(18)),
          child: const Text('إعادة الصياغة، الترجمة، التلخيص والتصحيح السياقي ستُفعّل بعد دمج نموذج ذكاء اصطناعي محلي واختباره.')),
        const SizedBox(height: 20), const Center(child: Text('SmartWrite AI Pro • UI v2 • Offline rules demo', style: TextStyle(fontSize: 11, color: Colors.grey))),
      ])),
    ));
  }
}
