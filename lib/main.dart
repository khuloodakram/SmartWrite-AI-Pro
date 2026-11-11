import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'services/neural_spell_service.dart';

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
    theme: ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorSchemeSeed: purple,
      scaffoldBackgroundColor: dark ? navy : const Color(0xFFF6F4FD),
    ),
    home: EditorPage(
      dark: dark,
      toggleTheme: () => setState(() => dark = !dark),
    ),
  );
}

class CorrectionRule {
  final String before, after, category, explanation;
  const CorrectionRule(this.before, this.after, this.category, this.explanation);
}

class TextIssue {
  final int start, end;
  final CorrectionRule rule;
  const TextIssue(this.start, this.end, this.rule);
}

// Demonstration rules. This is NOT a trained AI model.
const correctionRules = <CorrectionRule>[
  CorrectionRule('انشاء الله', 'إن شاء الله', 'كتابة', 'تُكتب العبارة «إن شاء الله» من ثلاث كلمات.'),
  CorrectionRule('ان شاء الله', 'إن شاء الله', 'همزات', 'تُكتب همزة «إن» تحت الألف.'),
  CorrectionRule('لاكن', 'لكن', 'إملائي', 'الصواب «لكن» دون ألف بعد اللام.'),
  CorrectionRule('هاذا', 'هذا', 'إملائي', 'اسم الإشارة الصحيح هو «هذا».'),
  CorrectionRule('هاذه', 'هذه', 'إملائي', 'اسم الإشارة الصحيح هو «هذه».'),
  CorrectionRule('مسؤليه', 'مسؤولية', 'إملائي', 'الصواب «مسؤولية».'),
  CorrectionRule('الى', 'إلى', 'همزات', 'همزة «إلى» تحت الألف.'),
  CorrectionRule('الان', 'الآن', 'همزات', 'الصواب «الآن».'),
  CorrectionRule('definately', 'definitely', 'English spelling', 'The correct spelling is definitely.'),
  CorrectionRule('recieve', 'receive', 'English spelling', 'The correct spelling is receive.'),
  CorrectionRule('teh', 'the', 'English spelling', 'The letters are transposed.'),
];

bool _isWordCharacter(String char) {
  if (char.isEmpty) return false;
  return RegExp(r'[\p{L}\p{M}\p{N}_]', unicode: true).hasMatch(char);
}

List<TextIssue> findIssues(String text) {
  final result = <TextIssue>[];
  final covered = List<bool>.filled(text.length, false);
  final ordered = [...correctionRules]..sort((a, b) => b.before.length.compareTo(a.before.length));
  for (final rule in ordered) {
    final regex = RegExp(RegExp.escape(rule.before), caseSensitive: false, unicode: true);
    for (final match in regex.allMatches(text)) {
      if (match.start > 0 && _isWordCharacter(text.substring(match.start - 1, match.start))) continue;
      if (match.end < text.length && _isWordCharacter(text.substring(match.end, match.end + 1))) continue;
      if (covered.getRange(match.start, match.end).any((x) => x)) continue;
      for (var i = match.start; i < match.end; i++) { covered[i] = true; }
      result.add(TextIssue(match.start, match.end, rule));
    }
  }
  result.sort((a, b) => a.start.compareTo(b.start));
  return result;
}

/// Renders proofreading marks while keeping TextField fully editable.
class ProofreadingController extends TextEditingController {
  List<TextIssue> issues = [];
  bool marked = false;
  ProofreadingController() : super();

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (!marked || issues.isEmpty) return TextSpan(style: style, text: text);
    final pieces = <TextSpan>[];
    var position = 0;
    for (final issue in issues) {
      if (issue.end > text.length || issue.start < position) continue;
      if (position < issue.start) pieces.add(TextSpan(text: text.substring(position, issue.start)));
      pieces.add(TextSpan(
        text: text.substring(issue.start, issue.end),
        style: const TextStyle(
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.wavy,
          decorationColor: Color(0xFFFF6B8B),
          decorationThickness: 2,
          backgroundColor: Color(0x335A2B58),
        ),
      ));
      position = issue.end;
    }
    if (position < text.length) pieces.add(TextSpan(text: text.substring(position)));
    return TextSpan(style: style, children: pieces);
  }

  void updateIssues(List<TextIssue> newIssues, {bool showMarks = true}) {
    issues = newIssues;
    marked = showMarks;
    notifyListeners();
  }
}

class EditorPage extends StatefulWidget {
  final bool dark;
  final VoidCallback toggleTheme;
  const EditorPage({super.key, required this.dark, required this.toggleTheme});
  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> with WidgetsBindingObserver {
  final controller = ProofreadingController();
  final history = <String>[];
  List<TextIssue> suggestions = [];
  int tab = 0;
  bool checked = false;
  bool storageReady = false;
  final NeuralSpellService neural = NeuralSpellService();
  bool neuralReady = false;
  String neuralStatus = 'جاري تحميل النموذج العصبي...';
  Timer? _saveTimer;

  Future<void> _loadSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedHistory = prefs.getStringList('smartwrite_history_v1') ?? <String>[];
      final savedDraft = prefs.getString('smartwrite_draft_v1') ?? '';
      if (!mounted) return;
      setState(() {
        if (history.isEmpty) history.addAll(savedHistory.take(30));
        if (controller.text.isEmpty && savedDraft.isNotEmpty) {
          controller.value = TextEditingValue(
            text: savedDraft,
            selection: TextSelection.collapsed(offset: savedDraft.length),
          );
        }
        storageReady = true;
      });
    } catch (_) {
      if (mounted) setState(() => storageReady = false);
    }
  }

  Future<void> _saveNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('smartwrite_draft_v1', controller.text);
      await prefs.setStringList('smartwrite_history_v1', history);
      if (mounted && !storageReady) setState(() => storageReady = true);
    } catch (_) {
      if (mounted && storageReady) setState(() => storageReady = false);
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _saveNow);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveTimer?.cancel();
      _saveNow();
    }
  }

  @override
  void initState() {
    super.initState();
    controller.addListener(_refresh);
    WidgetsBinding.instance.addObserver(this);
    _loadSavedState();
    _loadNeuralModel();
  }

  Future<void> _loadNeuralModel() async {
    await neural.load();
    if (!mounted) return;
    setState(() {
      neuralReady = neural.isReady;
      neuralStatus = neural.isReady
          ? 'النموذج العصبي جاهز • دون إنترنت'
          : 'تعذّر تحميل النموذج • التصحيح بالقواعد متاح';
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    neural.dispose();
    controller.removeListener(_refresh);
    controller.dispose();
    super.dispose();
  }

  void inspect() {
    final text = controller.text;
    final found = findIssues(text);
    // Run the on-device neural model; retain the existing rules as fallback.
    if (neural.isReady) {
      for (final suggestion in neural.suggest(text)) {
        final overlaps = found.any((issue) =>
            suggestion.start < issue.end && suggestion.end > issue.start);
        if (overlaps) continue;
        final original = text.substring(suggestion.start, suggestion.end);
        final percent = (suggestion.confidence * 100).toStringAsFixed(0);
        found.add(TextIssue(
          suggestion.start,
          suggestion.end,
          CorrectionRule(original, suggestion.replacement, 'AI • إملائي',
              'اقتراح من نموذج عصبي محلي، بثقة $percent٪. راجعي التصحيح قبل تطبيقه.'),
        ));
      }
      found.sort((a, b) => a.start.compareTo(b.start));
    }
    setState(() {
      checked = true;
      suggestions = found;
      tab = 0;
    });
    controller.updateIssues(found);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(found.isEmpty
          ? 'لا توجد اقتراحات ضمن نطاق القواعد والنموذج المحدود'
          : 'تم العثور على ${found.length} اقتراحات (${neural.isReady ? 'AI + قواعد' : 'قواعد فقط'}).'),
    ));
  }

  void _onTextChanged(String _) {
    _scheduleSave();
    if (!checked) return;
    final latest = findIssues(controller.text);
    suggestions = latest;
    controller.updateIssues(latest);
  }

  void apply(TextIssue issue) {
    final original = controller.text;
    if (issue.start < 0 || issue.end > original.length) return;
    final found = original.substring(issue.start, issue.end);
    if (found.toLowerCase() != issue.rule.before.toLowerCase()) return;
    history.insert(0, original);
    if (history.length > 30) history.removeLast();
    _saveTimer?.cancel();
    final updated = original.replaceRange(issue.start, issue.end, issue.rule.after);
    controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: issue.start + issue.rule.after.length),
    );
    final refreshed = findIssues(updated);
    suggestions = refreshed;
    controller.updateIssues(refreshed);
    _saveNow();
    setState(() {});
  }

  void restore(String previous) {
    controller.value = TextEditingValue(
      text: previous,
      selection: TextSelection.collapsed(offset: previous.length),
    );
    final next = findIssues(previous);
    suggestions = next;
    checked = true;
    controller.updateIssues(next);
    _saveTimer?.cancel();
    _saveNow();
    setState(() => tab = 0);
  }

  void showSuggestion(TextIssue issue) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 26),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(issue.rule.category, style: const TextStyle(color: cyan, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text('${controller.text.substring(issue.start, issue.end)}  ←  ${issue.rule.after}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            const SizedBox(height: 10),
            Text(issue.rule.explanation),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: () { Navigator.pop(sheetContext); apply(issue); },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('تطبيق التصحيح'),
            )),
          ]),
        ),
      ),
    );
  }

  void inspectCursor() {
    if (!checked || suggestions.isEmpty) return;
    final selection = controller.selection;
    if (!selection.isValid) return;
    final offset = selection.extentOffset;
    for (final issue in suggestions) {
      if (offset >= issue.start && offset <= issue.end) {
        FocusManager.instance.primaryFocus?.unfocus();
        showSuggestion(issue);
        return;
      }
    }
  }

  Widget pill(String label, IconData icon, int index) => OutlinedButton.icon(
    onPressed: () => setState(() => tab = index),
    icon: Icon(icon, size: 17), label: Text(label),
    style: OutlinedButton.styleFrom(
      backgroundColor: tab == index ? purple.withValues(alpha: .17) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final surface = widget.dark ? const Color(0xFF1C1B38) : Colors.white;
    final theme = Theme.of(context);
    final count = controller.text.trim().isEmpty ? 0 : controller.text.trim().split(RegExp(r'\s+')).length;
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('SmartWrite AI Pro', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(
          tooltip: 'تبديل المظهر',
          onPressed: widget.toggleTheme,
          icon: Icon(widget.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
        )],
      ),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(18), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF6D3CE0), Color(0xFF253B94)]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Row(children: [
            Icon(Icons.auto_awesome, color: Colors.white, size: 39),
            SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('اكتبي بثقة وإبداع', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('تصحيح تفاعلي • نموذج CNN + قواعد محلية', style: TextStyle(color: Colors.white70)),
            ])),
          ]),
        ),
        const SizedBox(height: 22),
        Row(children: [
          const Text('محرر النصوص', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Spacer(), const Icon(Icons.lock_outline, size: 16, color: cyan),
          const SizedBox(width: 5), const Text('يعمل بدون نت', style: TextStyle(color: cyan, fontSize: 12)),
        ]),
        const SizedBox(height: 6),
        Text(neuralStatus, style: TextStyle(fontSize: 12, color: neuralReady ? cyan : theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: surface, borderRadius: BorderRadius.circular(22),
            border: Border.all(color: purple.withValues(alpha: .4)),
          ),
          child: Column(children: [
            TextField(
              controller: controller,
              minLines: 8, maxLines: 14,
              onChanged: _onTextChanged,
              onTap: inspectCursor,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                hintText: 'اكتبي نصك هنا...\nمثال: هاذا النص يحتاج الى تصحيح',
                border: InputBorder.none, contentPadding: EdgeInsets.all(18),
              ),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 10), child: Row(children: [
              Text('$count كلمة • ${controller.text.length} حرف',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
              const Spacer(),
              IconButton(tooltip: 'نسخ', onPressed: () {
                Clipboard.setData(ClipboardData(text: controller.text));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ النص')));
              }, icon: const Icon(Icons.copy_outlined)),
              IconButton(tooltip: 'مسح', onPressed: () {
                controller.clear();
                suggestions = [];
                checked = false;
                controller.updateIssues([], showMarks: false);
                _saveTimer?.cancel();
                _saveNow();
                setState(() {});
              }, icon: const Icon(Icons.delete_outline)),
            ])),
          ]),
        ),
        const SizedBox(height: 9),
        if (checked && suggestions.isNotEmpty)
          Text('الكلمات المسطّرة بالأحمر تحمل اقتراحات. اضغطي عليها لعرض التفاصيل.',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: inspect,
          style: FilledButton.styleFrom(backgroundColor: purple, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 17)),
          icon: const Icon(Icons.auto_fix_high),
          label: const Text('فحص النص', style: TextStyle(fontWeight: FontWeight.bold)),
        )),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 4, children: [
          pill('الاقتراحات', Icons.fact_check_outlined, 0),
          pill('السجل المحفوظ', Icons.history, 1),
          pill('القادم', Icons.auto_awesome_motion, 2),
        ]),
        const SizedBox(height: 15),
        if (tab == 0) ...[
          Text('الاقتراحات (${suggestions.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (suggestions.isEmpty) Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(18)),
            child: const Text('اضغطي «فحص النص» لرؤية اقتراحات القواعد المحدودة. لا يمثل هذا تدقيقًا لغويًا شاملًا.'),
          ),
          for (final issue in suggestions) Card(
            color: surface,
            margin: const EdgeInsets.only(bottom: 9),
            child: ListTile(
              contentPadding: const EdgeInsets.all(13),
              title: Text('${controller.text.substring(issue.start, issue.end)}  ←  ${issue.rule.after}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Padding(padding: const EdgeInsets.only(top: 6),
                child: Text('${issue.rule.category} • ${issue.rule.explanation}')),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => showSuggestion(issue),
            ),
          ),
        ] else if (tab == 1) ...[
          const Text('النسخ السابقة المحفوظة على الهاتف', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (history.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('لا توجد تصحيحات مطبقة بعد')),
          for (final previous in history) ListTile(
            title: Text(previous, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.restore), onTap: () => restore(previous),
          ),
        ] else Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(18)),
          child: const Text('إعادة الصياغة والترجمة والتلخيص تحتاج دمج نموذج ذكاء اصطناعي محلي واختباره لاحقًا.'),
        ),
        const SizedBox(height: 22),
        Center(child: Text(
          storageReady
              ? 'SmartWrite AI Pro • V5 • نموذج CNN محلي + حفظ'
              : 'SmartWrite AI Pro • V5 • التخزين المحلي غير متاح',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        )),
      ])),
    ));
  }
}
