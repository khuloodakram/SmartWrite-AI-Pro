import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'writing_tools_service.dart';
import 'package:flutter/services.dart';
import 'documents_page.dart';

/// Navigation shell for SmartWrite AI Pro.
/// Existing EditorPage and offline CNN service remain unchanged.
class SmartWriteShell extends StatefulWidget {
  final bool dark;
  final VoidCallback toggleTheme;
  const SmartWriteShell({super.key, required this.dark, required this.toggleTheme});

  @override
  State<SmartWriteShell> createState() => _SmartWriteShellState();
}

class _SmartWriteShellState extends State<SmartWriteShell> {
  int selected = 0;
  

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF8657F6);
    final pages = <Widget>[
      _HomePage(openPage: (index) => setState(() => selected = index)),
      EditorPage(dark: widget.dark, toggleTheme: widget.toggleTheme),
      const _ToolsPage(),
      const DocumentsPage(),
      _SettingsPage(dark: widget.dark, toggleTheme: widget.toggleTheme),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(index: selected, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          indicatorColor: accent.withValues(alpha: 0.22),
          onDestinationSelected: (index) => setState(() => selected = index),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.edit_note_outlined), selectedIcon: Icon(Icons.edit_note), label: 'المحرر'),
            NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'الأدوات'),
            NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'المستندات'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
          ],
        ),
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  final ValueChanged<int> openPage;
  const _HomePage({required this.openPage});

  @override
  Widget build(BuildContext context) => _PageFrame(
    title: 'SmartWrite AI Pro',
    children: [
      const Text('اكتبي بثقة وإبداع', style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('مساحة كتابة خاصة بك، مع محرر وتدقيق محلي دون اتصال بالإنترنت.'),
      const SizedBox(height: 24),
      _FeatureTile(icon: Icons.edit_note, title: 'المحرر الذكي', subtitle: 'كتابة وتدقيق وتصحيح تفاعلي', onTap: () => openPage(1)),
      _FeatureTile(icon: Icons.auto_awesome, title: 'أدوات النصوص', subtitle: 'إحصاءات وأدوات محلية أساسية', onTap: () => openPage(2)),
      _FeatureTile(icon: Icons.folder_open, title: 'المستندات', subtitle: 'المسودات المحفوظة على الجهاز', onTap: () => openPage(3)),
    ],
  );
}

class _ToolsPage extends StatefulWidget {
  const _ToolsPage();
  @override
  State<_ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<_ToolsPage> {
  final controller = TextEditingController();
  WritingAnalysis? analysis;

  @override
  void dispose() { controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return _PageFrame(title: 'أدوات الكتابة', children: [
      const Text('تحسين النص محليًا', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('تصحيح التكرار والمسافات وبعض علامات الترقيم دون اتصال بالإنترنت.'),
      const SizedBox(height: 14),
      TextField(
        controller: controller,
        minLines: 5,
        maxLines: 12,
        onChanged: (_) => setState(() => analysis = null),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          hintText: 'الصقي نصًا لتحليله وتحسينه',
        ),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: controller.text.trim().isEmpty ? null : () => setState(() {
          analysis = const WritingToolsService().analyze(controller.text);
        }),
        icon: const Icon(Icons.auto_fix_high),
        label: const Text('تحليل وتحسين النص'),
      ),
      if (analysis != null) ...[
        const SizedBox(height: 20),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Chip(label: Text('${analysis!.words} كلمة')),
          Chip(label: Text('${analysis!.characters} حرف')),
          Chip(label: Text('${analysis!.sentences} جملة تقريبًا')),
          Chip(label: Text('${analysis!.suggestions} تعديل')),
        ]),
        const SizedBox(height: 16),
        const Text('النص الأصلي', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SelectableText(analysis!.original),
        const Divider(height: 32),
        const Text('النص المحسّن', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SelectableText(analysis!.improved),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: analysis!.improved));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم نسخ النص المحسّن')),
            );
          },
          icon: const Icon(Icons.copy_outlined),
          label: const Text('نسخ النص المحسّن'),
        ),
      ],
      const SizedBox(height: 20),
      const Text('هذه تحسينات محدودة بالقواعد، وليست إعادة صياغة أو تلخيصًا باستخدام نموذج لغوي.', style: TextStyle(fontSize: 12)),
    ]);
  }
}

class _DocumentsPage extends StatefulWidget {
  const _DocumentsPage();
  @override
  State<_DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<_DocumentsPage> {
  String draft = '';
  List<String> history = [];
  bool loading = true;

  @override
  void initState() { super.initState(); reload(); }
  Future<void> reload() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      draft = prefs.getString('smartwrite_draft_v1') ?? '';
      history = prefs.getStringList('smartwrite_history_v1') ?? [];
      loading = false;
    });
  }
  @override
  Widget build(BuildContext context) => _PageFrame(title: 'المستندات', children: [
    FilledButton.tonalIcon(onPressed: reload, icon: const Icon(Icons.refresh), label: const Text('تحديث المحفوظات')),
    const SizedBox(height: 14),
    if (loading) const Center(child: CircularProgressIndicator())
    else if (draft.isEmpty && history.isEmpty) const Text('لا توجد مسودات محفوظة حتى الآن.')
    else ...[
      if (draft.isNotEmpty) _FeatureTile(icon: Icons.description_outlined, title: 'المسودة الحالية', subtitle: draft, onTap: () => _showText(context, draft)),
      for (var i = 0; i < history.length; i++)
        _FeatureTile(icon: Icons.history, title: 'نسخة سابقة ${i + 1}', subtitle: history[i], onTap: () => _showText(context, history[i])),
    ],
    const SizedBox(height: 12),
    const Text('هذه الصفحة تعرض محفوظات المحرر الحالي. إدارة الملفات والمجلدات والتصدير ستضاف في إصدار لاحق.', style: TextStyle(fontSize: 12)),
  ]);

  void _showText(BuildContext context, String text) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('النص المحفوظ'),
      content: SingleChildScrollView(child: SelectableText(text)),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
    ),
  );
}

class _SettingsPage extends StatelessWidget {
  final bool dark;
  final VoidCallback toggleTheme;
  const _SettingsPage({required this.dark, required this.toggleTheme});
  @override
  Widget build(BuildContext context) => _PageFrame(title: 'الإعدادات', children: [
    SwitchListTile(title: const Text('الوضع الداكن'), subtitle: const Text('تغيير مظهر التطبيق'), value: dark, onChanged: (_) => toggleTheme()),
    const _FeatureTile(icon: Icons.lock_outline, title: 'الخصوصية', subtitle: 'المحرر والنموذج الحالي يعملان محليًا على الجهاز.'),
    const _FeatureTile(icon: Icons.info_outline, title: 'حول التطبيق', subtitle: 'SmartWrite AI Pro — نسخة تطويرية متعددة الواجهات'),
  ]);
}

class _PageFrame extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _PageFrame({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => SafeArea(child: CustomScrollView(slivers: [
    SliverAppBar.large(title: Text(title)),
    SliverPadding(padding: const EdgeInsets.all(18), sliver: SliverList(delegate: SliverChildListDelegate(children))),
  ]));
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _FeatureTile({required this.icon, required this.title, required this.subtitle, this.onTap});
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(leading: Icon(icon, color: const Color(0xFF8657F6)), title: Text(title),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: onTap == null ? null : const Icon(Icons.chevron_left), onTap: onTap),
  );
}
