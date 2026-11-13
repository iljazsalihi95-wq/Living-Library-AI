import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookCard extends StatefulWidget {
  const BookCard({super.key, required this.title, required this.onOpen, this.onDelete});
  final String title;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;
  @override State<BookCard> createState() => _BookCardState();
}
class _BookCardState extends State<BookCard> {
  String category = 'Pa kategori', cover = '';
  String get storageKey => 'book_meta_${base64Url.encode(utf8.encode(widget.title))}';
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BookCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) {
      category = 'Pa kategori';
      cover = '';
      _load();
    }
  }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    try { final data = jsonDecode(prefs.getString(storageKey) ?? '{}') as Map; if (mounted) setState(() { category = data['category'] as String? ?? 'Pa kategori'; cover = data['cover'] as String? ?? ''; }); } catch (_) { /* Book text remains accessible. */ }
  }
  Future<void> _edit() async {
    final text = TextEditingController(text: category);
    final result = await showDialog<String>(context: context, builder: (c) => AlertDialog(title: const Text('Kategoria e librit'), content: TextField(controller: text, decoration: const InputDecoration(labelText: 'Kategori')), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Anulo')), FilledButton(onPressed: () => Navigator.pop(c, text.text.trim()), child: const Text('Ruaj'))]));
    if (result != null && mounted) { setState(() => category = result.isEmpty ? 'Pa kategori' : result); await _save(); }
  }
  Future<void> _image() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty) return;
      final file = files.single;
      final bytes = await file.readAsBytes();
      if (bytes.length > 12 * 1024 * 1024) throw const FormatException('Cover too large');
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/cover_${DateTime.now().microsecondsSinceEpoch}.${file.extension ?? 'jpg'}';
      await File(path).writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      setState(() => cover = path); await _save();
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kopertina nuk mund të ruhej.'))); }
  }
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(storageKey, jsonEncode({'category':category,'cover':cover}));
    if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Të dhënat e kopertinës nuk u ruajtën.')));
  }
  @override Widget build(BuildContext context) => Card(child: ListTile(
    contentPadding: const EdgeInsets.all(12),
    leading: SizedBox(width: 48, height: 68, child: cover.isEmpty ? Container(decoration: BoxDecoration(color: const Color(0xFF153B30), border: Border.all(color: const Color(0xFFE2BE72)), borderRadius: BorderRadius.circular(6)), child: Center(child: Text(widget.title.substring(0, widget.title.length.clamp(0, 2)).toUpperCase(), style: const TextStyle(color: Color(0xFFE2BE72),fontWeight: FontWeight.bold)))) : Image.file(File(cover), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))),
    title: Text(widget.title), subtitle: Text('$category • lexim / audio'), onTap: widget.onOpen,
    trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'cover') _image(); if (v == 'category') _edit(); if (v == 'delete') widget.onDelete?.call(); }, itemBuilder: (_) => [PopupMenuItem(value: 'cover', child: Text('Vendos kopertinën')), PopupMenuItem(value: 'category', child: Text('Ndrysho kategorinë')), if (widget.onDelete != null) const PopupMenuItem(value: 'delete', child: Text('Fshi librin'))]),
  ));
}
