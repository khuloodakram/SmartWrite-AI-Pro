import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedDocument {
  final String id;
  final String title;
  final String content;
  final DateTime updatedAt;

  const SavedDocument({required this.id, required this.title, required this.content, required this.updatedAt});

  SavedDocument copyWith({String? title, String? content}) => SavedDocument(
    id: id, title: title ?? this.title, content: content ?? this.content,
    updatedAt: DateTime.now().toUtc(),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'content': content,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory SavedDocument.fromJson(Map<String, dynamic> json) => SavedDocument(
    id: json['id'] as String,
    title: json['title'] as String,
    content: json['content'] as String,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}

class DocumentStore {
  static const key = 'smartwrite_documents_v1';
  final SharedPreferences prefs;
  DocumentStore(this.prefs);

  List<SavedDocument> load() {
    final raw = prefs.getString(key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) throw const FormatException('Invalid document data');
    final docs = decoded.map((item) => SavedDocument.fromJson(
      Map<String, dynamic>.from(item as Map),
    )).toList();
    docs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return docs;
  }

  Future<void> _save(List<SavedDocument> docs) async {
    final ok = await prefs.setString(key, jsonEncode(docs.map((d) => d.toJson()).toList()));
    if (!ok) throw StateError('Could not save documents');
  }

  Future<SavedDocument> create(String title, String content) async {
    final docs = load();
    final doc = SavedDocument(
      id: '${DateTime.now().microsecondsSinceEpoch}_${docs.length}',
      title: title.trim().isEmpty ? 'مستند بدون عنوان' : title.trim(),
      content: content,
      updatedAt: DateTime.now().toUtc(),
    );
    await _save([doc, ...docs]);
    return doc;
  }

  Future<void> update(SavedDocument doc) async {
    final docs = load();
    final index = docs.indexWhere((d) => d.id == doc.id);
    if (index < 0) throw StateError('Document not found');
    docs[index] = doc.copyWith();
    await _save(docs);
  }

  Future<void> delete(String id) async {
    final docs = load();
    docs.removeWhere((d) => d.id == id);
    await _save(docs);
  }
}
