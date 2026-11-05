import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ai/ai_connection.dart';

class StoryStudio extends StatefulWidget {
  const StoryStudio({super.key, this.initialText = '', this.initialTitle = ''});
  final String initialText, initialTitle;
  @override State<StoryStudio> createState() => _StoryStudioState();
}
class _StoryStudioState extends State<StoryStudio> {
  final title = TextEditingController();
  final story = TextEditingController();
  List<Map<String, dynamic>> scenes = [];
  bool busy = false;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (widget.initialText.isNotEmpty) { title.text = widget.initialTitle; story.text = widget.initialText; _build(); return; }
    try {
      final data = jsonDecode(prefs.getString('story_studio_v1') ?? '{}') as Map;
      setState(() { title.text = data['title'] as String? ?? ''; story.text = data['story'] as String? ?? ''; scenes = ((data['scenes'] as List?) ?? []).map((s) => Map<String,dynamic>.from(s as Map)).toList(); });
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Projekti i studios është i dëmtuar. Libri origjinal ruhet në bibliotekë.'))); }
  }
  void _build() {
    if (story.text.trim().isEmpty) return;
    final chunks = story.text.split(RegExp(r'\n\s*\n')).where((s) => s.trim().isNotEmpty).toList();
    setState(() => scenes = [for (var i = 0; i < chunks.length; i++) {'title': 'Skena ${i+1}', 'text': chunks[i], 'narration': chunks[i], 'characters': '', 'motion': '', 'image': ''}]);
  }
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString('story_studio_v1', jsonEncode({'title': title.text, 'story': story.text, 'scenes': scenes}));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Storyboard-i u ruajt në pajisje.' : 'Ruajtja dështoi.')));
  }
  Future<void> _export() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final archive = Archive();
      final exported = <Map<String, dynamic>>[];
      for (var i = 0; i < scenes.length; i++) {
        final scene = Map<String,dynamic>.from(scenes[i]);
        final path = scene['image'] as String? ?? '';
        if (path.isNotEmpty) {
          final bytes = await File(path).readAsBytes();
          final name = 'images/scene_${i+1}.${path.split('.').last}';
          archive.addFile(ArchiveFile(name, bytes.length, bytes)); scene['image'] = name;
        }
        exported.add(scene);
      }
      final manifest = utf8.encode(jsonEncode({'format': 'living-library-storyboard', 'version': 1, 'title': title.text, 'videoGenerated': false, 'scenes': exported}));
      archive.addFile(ArchiveFile('storyboard.json', manifest.length, manifest));
      final result = await FilePicker.saveFile(fileName: 'storyboard.zip', bytes: Uint8List.fromList(ZipEncoder().encode(archive)));
      if (mounted && result != null) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Materialet ZIP u eksportuan: skenat, narracioni tekst dhe ilustrimet.')));
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Eksporti dështoi. Kontrollo ilustrimet dhe hapësirën e lirë.'))); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override void dispose() { title.dispose(); story.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Studio e tregimeve'), actions: [IconButton(tooltip: 'Ruaj', onPressed: _save, icon: const Icon(Icons.save)), IconButton(tooltip: 'Eksporto materialet ZIP', onPressed: busy ? null : _export, icon: const Icon(Icons.archive_outlined))]), body: ListView(padding: const EdgeInsets.all(18), children: [
    TextField(controller: title, decoration: const InputDecoration(labelText: 'Titulli i projektit')),
    TextField(controller: story, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: 'Tregimi • paragrafët ndahen në skena')),
    FilledButton.icon(onPressed: () async { if (scenes.isNotEmpty) { final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Rindërto skenat?'), content: const Text('Redaktimet aktuale të skenave do të zëvendësohen nga teksti i tregimit.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Anulo')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Rindërto'))])); if (yes != true || !mounted) return; } _build(); }, icon: const Icon(Icons.view_agenda_outlined), label: const Text('Ndërto storyboard-in')),
    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Storyboard dhe materiale për prodhim. Gjenerimi i videos kërkon shërbim image-to-video të konfiguruar.')),
    for (var i = 0; i < scenes.length; i++) Card(child: ListTile(leading: (scenes[i]['image'] as String? ?? '').isEmpty ? Text('${i+1}') : Image.file(File(scenes[i]['image'] as String), width: 60, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)), title: Text(scenes[i]['title'] as String), subtitle: Text(scenes[i]['text'] as String, maxLines: 2, overflow: TextOverflow.ellipsis), onTap: () async { final result = await Navigator.push<Map<String,dynamic>>(context, MaterialPageRoute(builder: (_) => StorySceneEditor(scene: scenes[i]))); if (result != null && mounted) { setState(() => scenes[i] = result); await _save(); } }, trailing: IconButton(tooltip: 'Fshi skenën', onPressed: () => setState(() => scenes.removeAt(i)), icon: const Icon(Icons.delete_outline)))),
  ]));
}
class StorySceneEditor extends StatefulWidget {
  const StorySceneEditor({super.key, required this.scene, this.storageKey});
  final String? storageKey;
  final Map<String,dynamic> scene;
  @override State<StorySceneEditor> createState() => _StorySceneEditorState();
}
class _StorySceneEditorState extends State<StorySceneEditor> {
  late final Map<String, TextEditingController> fields;
  late String imagePath;
  final FlutterTts tts = FlutterTts();
  bool playing = false, busy = false;
  @override void initState() { super.initState(); fields = {for (final k in ['title','text','characters','narration','motion']) k: TextEditingController(text: widget.scene[k] as String? ?? '')}; imagePath = widget.scene['image'] as String? ?? ''; _restore(); tts.setCompletionHandler(() { if (mounted) setState(() => playing = false); }); }
  Future<void> _restore() async {
    if (widget.storageKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    try { final saved = jsonDecode(prefs.getString(widget.storageKey!) ?? '{}') as Map; if (!mounted) return; setState(() { for (final e in fields.entries) { if (saved[e.key] is String) e.value.text = saved[e.key]; } if (saved['image'] is String) imagePath = saved['image']; }); } catch (_) { /* Keep original scene. */ }
  }
  Future<void> _saveScene() async {
    final result = {for (final e in fields.entries) e.key: e.value.text, 'image': imagePath};
    if (widget.storageKey != null) { final prefs = await SharedPreferences.getInstance(); final ok = await prefs.setString(widget.storageKey!, jsonEncode(result)); if (!ok) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ruajtja e skenës dështoi.'))); return; } }
    if (mounted) Navigator.pop(context, result);
  }
  Future<void> _image() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty) return;
      final file = files.single;
      final bytes = await file.readAsBytes();
      if (bytes.length > 12 * 1024 * 1024) throw const FormatException('Ilustrimi tejkalon 12 MiB.');
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/scene_${DateTime.now().microsecondsSinceEpoch}.${file.extension ?? 'jpg'}';
      await File(path).writeAsBytes(bytes, flush: true);
      if (mounted) setState(() => imagePath = path);
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ilustrimi nuk mund të importohej.'))); }
  }
  Future<void> _plan() async {
    if (!await configureAi(context) || !mounted) return;
    setState(() => busy = true);
    try { final result = await aiText(fields['text']!.text, path: '/v1/scene-plan'); if (mounted) fields['motion']!.text = result; }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> _speak() async {
    if (playing) { await tts.stop(); if (mounted) setState(() => playing = false); return; }
    try { await tts.setLanguage('sq-AL'); await tts.awaitSpeakCompletion(true); if (!mounted) return; setState(() => playing = true); final text = fields['narration']!.text; for (var from = 0; from < text.length && mounted && playing; from += 2500) { await tts.speak(text.substring(from, (from+2500).clamp(0,text.length))); } }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Narracioni nuk mund të lexohej. Kontrollo zërin shqip TTS.'))); }
    finally { if (mounted) setState(() => playing = false); }
  }
  @override void dispose() { tts.stop(); for (final c in fields.values) { c.dispose(); } super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Redakto skenën'), actions: [IconButton(tooltip: 'Ruaj skenën', onPressed: _saveScene, icon: const Icon(Icons.check))]), body: ListView(padding: const EdgeInsets.all(18), children: [
    if (imagePath.isNotEmpty) Image.file(File(imagePath), height: 200, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Text('Ilustrimi nuk gjendet.')),
    OutlinedButton.icon(onPressed: _image, icon: const Icon(Icons.image_outlined), label: const Text('Lidh ilustrimin origjinal')),
    for (final e in fields.entries) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: TextField(controller: e.value, minLines: e.key == 'title' ? 1 : 2, maxLines: 8, decoration: InputDecoration(border: const OutlineInputBorder(), labelText: const {'title':'Titulli','text':'Përmbajtja','characters':'Personazhet','narration':'Narracioni','motion':'Lëvizja dhe kamera'}[e.key]))),
    Wrap(spacing: 8, children: [FilledButton.icon(onPressed: _speak, icon: Icon(playing ? Icons.stop : Icons.volume_up), label: const Text('Narracioni')), OutlinedButton.icon(onPressed: busy ? null : _plan, icon: const Icon(Icons.auto_awesome), label: const Text('Plan AI i skenës'))]),
  ]));
}
