import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const SmartWriteApp());

class Correction {
  final String wrong;
  final String right;
  final String reason;
  const Correction(this.wrong, this.right, this.reason);
}

class SmartWriteApp extends StatefulWidget {
  const SmartWriteApp({super.key});

  @override
  State<SmartWriteApp> createState() => _SmartWriteAppState();
}

class _SmartWriteAppState extends State<SmartWriteApp> {
  bool dark = true;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8568FF),
      brightness: dark ? Brightness.dark : Brightness.light,
    );
    return MaterialApp(
      title: 'SmartWrite AI Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: dark
            ? const Color(0xFF0E1020)
            : const Color(0xFFF7F7FB),
      ),
      home: WriterPage(
        dark: dark,
        onToggleTheme: () => setState(() => dark = !dark),
      ),
    );
  }
}

class WriterPage extends StatefulWidget {
  final bool dark;
  final VoidCallback onToggleTheme;
  const WriterPage({
    super.key,
    required this.dark,
    required this.onToggleTheme,
  });

  @override
  State<WriterPage> createState() => _WriterPageState();
}

class _WriterPageState extends State<WriterPage> {
  final controller = TextEditingController(
    text:
        'هذا نص تجريبي. انشاء الله سوف نكتب محتوى رائع. I recieve your mesage.',
  );
  List<Correction> suggestions = [];
  bool scanned = false;

  // قواعد توضيحية فقط. النموذج العصبي المحلي يضاف في مرحلة لاحقة.
  static const rules = <Correction>[
    Correction('انشاء الله', 'إن شاء الله', 'تصحيح عبارة شائعة'),
    Correction('لاكن', 'لكن', 'تصحيح إملائي'),
    Correction('هاذا', 'هذا', 'تصحيح إملائي'),
    Correction('مسؤل', 'مسؤول', 'تصحيح إملائي'),
    Correction('recieve', 'receive', 'English spelling'),
    Correction('mesage', 'message', 'English spelling'),
    Correction('teh', 'the', 'English spelling'),
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void scan() {
    final text = controller.text.toLowerCase();
    setState(() {
      suggestions = rules
          .where((item) => text.contains(item.wrong.toLowerCase()))
          .toList();
      scanned = true;
    });
  }

  void apply(Correction item) {
    final source = controller.text;
    final exp = RegExp(RegExp.escape(item.wrong), caseSensitive: false);
    final match = exp.firstMatch(source);
    if (match == null) return;
    final changed = source.replaceRange(match.start, match.end, item.right);
    setState(() {
      controller.value = TextEditingValue(
        text: changed,
        selection: TextSelection.collapsed(
          offset: match.start + item.right.length,
        ),
      );
      suggestions.remove(item);
    });
  }

  void applyAll() {
    var text = controller.text;
    for (final rule in rules) {
      text = text.replaceAll(
        RegExp(RegExp.escape(rule.wrong), caseSensitive: false),
        rule.right,
      );
    }
    setState(() {
      controller.text = text;
      suggestions = [];
      scanned = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final raw = controller.text.trim();
    final words = raw.isEmpty ? 0 : raw.split(RegExp(r'\s+')).length;
    final surface = widget.dark ? const Color(0xFF191C32) : Colors.white;
    final border = widget.dark
        ? const Color(0xFF30344E)
        : const Color(0xFFE4E5ED);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'SmartWrite AI Pro',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            tooltip: 'تغيير المظهر',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6D56D9), Color(0xFF3A8BD8)],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'مساعد الكتابة الذكي',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'اكتب، راجع، وحسّن نصوصك. هذه نسخة أولية بمحرك قواعد يعمل محليًا.',
                    style: TextStyle(color: Colors.white, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'محرر النصوص',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Row(
                  children: [
                    Icon(
                      Icons.offline_bolt_outlined,
                      color: Color(0xFF54CB9B),
                      size: 18,
                    ),
                    SizedBox(width: 4),
                    Text('محلي / بدون إنترنت', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: controller,
                    minLines: 8,
                    maxLines: 14,
                    textDirection: TextDirection.rtl,
                    decoration: const InputDecoration(
                      hintText: 'اكتب نصك هنا...',
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {
                      scanned = false;
                      suggestions = [];
                    }),
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Text('$words كلمة', style: theme.textTheme.bodySmall),
                      const SizedBox(width: 12),
                      Text(
                        '${controller.text.length} حرف',
                        style: theme.textTheme.bodySmall,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'نسخ النص',
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: controller.text),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم نسخ النص')),
                          );
                        },
                        icon: const Icon(Icons.copy_outlined),
                      ),
                      IconButton(
                        tooltip: 'مسح النص',
                        onPressed: () => setState(() {
                          controller.clear();
                          suggestions = [];
                          scanned = false;
                        }),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text(
                  'فحص النص',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: scan,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Text(
                  'نتائج الفحص',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (suggestions.isNotEmpty)
                  TextButton(
                    onPressed: applyAll,
                    child: const Text('تطبيق الكل'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!scanned)
              const Text('اضغط «فحص النص» لرؤية الاقتراحات التجريبية.'),
            if (scanned && suggestions.isEmpty)
              const Text(
                'لم تُكتشف أخطاء ضمن القواعد التجريبية المتاحة. هذا لا يعني أن النص خالٍ من الأخطاء.',
              ),
            ...suggestions.map(
              (s) => Card(
                color: surface,
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.reason, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            s.wrong,
                            style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Color(0xFFFF7777),
                            ),
                          ),
                          const Icon(Icons.arrow_forward, size: 17),
                          Text(
                            s.right,
                            style: const TextStyle(
                              color: Color(0xFF54CB9B),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => apply(s),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('تطبيق التصحيح'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Center(
              child: Text(
                'v0.1 • Prototype • Rule-based Offline',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
