import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/ai_film/pilot_story.dart';

const gold = Color(0xFFE2BE72);
const emerald = Color(0xFF071B17);
const panel = Color(0xFF0D2A24);

void main() => runApp(const LibraryApp());

class LibraryApp extends StatelessWidget {
  const LibraryApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Living Library AI',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: emerald,
          colorScheme: ColorScheme.fromSeed(seedColor: gold, brightness: Brightness.dark),
          useMaterial3: true,
        ),
        home: const LibraryHome(),
      );
}

class LibraryHome extends StatefulWidget {
  const LibraryHome({super.key});
  @override
  State<LibraryHome> createState() => _LibraryHomeState();
}

class _LibraryHomeState extends State<LibraryHome> {
  String? selectedBook;

  Future<void> _import() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'epub', 'txt', 'jpg', 'jpeg', 'png']);
    if (!mounted || files.isEmpty) return;
    final file = files.single;
    setState(() => selectedBook = file.name);
    if (file.extension?.toLowerCase() == 'txt') {
      final content = utf8.decode(await file.readAsBytes(), allowMalformed: true);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _TextReaderPage(title: file.name, content: content)));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('U zgjodh ${file.name}. Importi i këtij formati po përgatitet.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        bottomNavigationBar: NavigationBar(
          selectedIndex: 0,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Ballina'),
            NavigationDestination(icon: Icon(Icons.auto_stories_outlined), label: 'Biblioteka'),
            NavigationDestination(icon: Icon(Icons.movie_creation_outlined), label: 'Studio AI'),
            NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profili'),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              const _PremiumHeader(),
              const SizedBox(height: 22),
              const Text('Lexo • Krijo • Dëgjo • Mëso', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              const Text('Biblioteka jote private që i kthen librat dhe tregimet në përvojë interaktive.', style: TextStyle(color: Color(0xFFB8CCC3), height: 1.45)),
              const SizedBox(height: 22),
              _PilotHero(onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const _PilotStoryPage()))),
              const SizedBox(height: 24),
              const _SectionTitle('Krijo & lexo'),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.12,
                children: [
                  _PremiumAction(title: 'Krijo libër', subtitle: selectedBook ?? 'PDF • EPUB • TXT • foto', icon: Icons.add_photo_alternate_outlined, onTap: _import),
                  _PremiumAction(title: 'Shkruaj librin', subtitle: 'Draft privat në telefon', icon: Icons.edit_note_outlined, onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const _WritingPage()))),
                  _PremiumAction(title: 'Film AI', subtitle: 'Storyboard • skena • preview', icon: Icons.movie_filter_outlined, onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const _PilotStoryPage()))),
                  _PremiumAction(title: 'Biblioteka ime', subtitle: 'Rafti personal', icon: Icons.auto_stories_outlined, onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const _SavedDraftPage()))),
                ],
              ),
              const SizedBox(height: 25),
              const _SectionTitle('Biblioteka Ime'),
              const SizedBox(height: 12),
              _BookShelf(onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const _PilotStoryPage()))),
              const SizedBox(height: 22),
              const _SectionTitle('Leximet e fundit'),
              const SizedBox(height: 10),
              const _RecentReading(),
            ],
          ),
        ),
      );
}

class _PremiumHeader extends StatelessWidget {
  const _PremiumHeader();
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            gradient: const LinearGradient(colors: [Color(0xFF1D5747), Color(0xFF0A2921)]),
            border: Border.all(color: gold),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8))],
          ),
          child: const Icon(Icons.auto_stories_rounded, color: gold, size: 34),
        ),
        const SizedBox(width: 14),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Living Library AI', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          SizedBox(height: 3),
          Text('YOUR BOOKS • ALIVE', style: TextStyle(color: gold, letterSpacing: 1.4, fontSize: 10)),
        ])),
        const Icon(Icons.lock_outline, color: Color(0xFF9DB4AA)),
      ]);
}

class _PilotHero extends StatelessWidget {
  const _PilotHero({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(colors: [Color(0xFF174B3E), Color(0xFF0B2D25)]),
            border: Border.all(color: gold.withValues(alpha: .7)),
          ),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(Icons.movie_creation_outlined, color: gold), SizedBox(width: 8), Text('Tregimi pilot', style: TextStyle(color: gold, fontWeight: FontWeight.w800))]),
            SizedBox(height: 14),
            Text('Vlera e namazit me xhemat', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            SizedBox(height: 8),
            Text('12 skena • 2 personazhe • editor Film AI', style: TextStyle(color: Color(0xFFC0D2CA))),
            SizedBox(height: 18),
            Row(children: [
              _MiniPill('Lexo tregimin'), SizedBox(width: 8), _MiniPill('Shiko filmin'), SizedBox(width: 8), _MiniPill('Krijo Film AI'),
            ]),
          ]),
        ),
      );
}

class _MiniPill extends StatelessWidget {
  const _MiniPill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Flexible(child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7), decoration: BoxDecoration(color: const Color(0x22000000), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0x557F9F91))), child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFE8EEE9)));
}

class _PremiumAction extends StatelessWidget {
  const _PremiumAction({required this.title, required this.subtitle, required this.icon, required this.onTap});
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: panel,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: gold.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: gold)),
          const Spacer(),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF9DB4AA))),
        ]))),
      );
}

class _BookShelf extends StatelessWidget {
  const _BookShelf({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: 150,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          decoration: BoxDecoration(color: const Color(0xFF0B251F), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF285347))),
          child: Column(children: [
            Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: const [
              _BookSpine('Tregimi\npilot', 74, Color(0xFF7B392C)), SizedBox(width: 7),
              _BookSpine('Libri\nim', 92, Color(0xFF275D50)), SizedBox(width: 7),
              _BookSpine('Shënime', 64, Color(0xFF8B6A31)), SizedBox(width: 7),
              _BookSpine('AI\nStudio', 82, Color(0xFF3B456D)),
            ])),
            Container(height: 9, decoration: BoxDecoration(color: const Color(0xFF6B4728), borderRadius: BorderRadius.circular(3), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 7, offset: Offset(0, 4))])),
          ]),
        ),
      );
}

class _BookSpine extends StatelessWidget {
  const _BookSpine(this.text, this.height, this.color);
  final String text;
  final double height;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(width: 49, height: height, padding: const EdgeInsets.all(5), alignment: Alignment.center, decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(5)), border: Border.all(color: gold.withValues(alpha: .35))), child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)));
}

class _RecentReading extends StatelessWidget {
  const _RecentReading();
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18)), child: const Row(children: [Icon(Icons.history, color: gold), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Vlera e namazit me xhemat', style: TextStyle(fontWeight: FontWeight.w700)), SizedBox(height: 3), Text('Tregimi pilot • 12 skena', style: TextStyle(color: Color(0xFF9DB4AA), fontSize: 12))])), Icon(Icons.chevron_right, color: gold)]));
}

class _PilotStoryPage extends StatelessWidget {
  const _PilotStoryPage();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(livingLibraryPilot.title)),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: gold.withValues(alpha: .45))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('FILM AI • STORYBOARD', style: TextStyle(color: gold, fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 11)),
            const SizedBox(height: 10),
            Text(livingLibraryPilot.storyText, style: const TextStyle(fontSize: 15, height: 1.5)),
            const SizedBox(height: 15),
            const Wrap(spacing: 8, runSpacing: 8, children: [_StatusChip('12 skena'), _StatusChip('2 personazhe'), _StatusChip('Image → Video')]),
          ])),
          const SizedBox(height: 18),
          const Text('Skenat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...livingLibraryPilot.scenes.asMap().entries.map((entry) => _SceneCard(index: entry.key, scene: entry.value)),
          const SizedBox(height: 18),
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF102A24), borderRadius: BorderRadius.circular(16)), child: const Text('Gjenerimi real i videos nuk simulohet: butoni i renderimit aktivizohet vetëm pasi provider-i image-to-video të lidhet në Worker. Kredencialet nuk futen në APK.', style: TextStyle(color: Color(0xFFADC1B8), height: 1.4))),
        ]),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Chip(label: Text(text), side: BorderSide(color: gold.withValues(alpha: .35)), backgroundColor: const Color(0xFF0A211C));
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({required this.index, required this.scene});
  final int index;
  final dynamic scene;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 11),
        color: panel,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _SceneEditorPage(index: index, scene: scene))),
          child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
            Container(width: 48, height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: gold.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)), child: Text('${index + 1}', style: const TextStyle(color: gold, fontSize: 18, fontWeight: FontWeight.w900))),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(scene.title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text(scene.storyText, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFAEC1B9), fontSize: 12))])),
            const Icon(Icons.chevron_right, color: gold),
          ])),
        ),
      );
}

class _SceneEditorPage extends StatelessWidget {
  const _SceneEditorPage({required this.index, required this.scene});
  final int index;
  final dynamic scene;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Skena ${index + 1} • ${scene.title}')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          Container(height: 190, decoration: BoxDecoration(color: const Color(0xFF102E27), borderRadius: BorderRadius.circular(22), border: Border.all(color: gold.withValues(alpha: .45))), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.image_outlined, size: 48, color: gold), SizedBox(height: 10), Text('Frame reference i skenës', style: TextStyle(fontWeight: FontWeight.w800)), SizedBox(height: 5), Text('Imazhi i miratuar lidhet këtu', style: TextStyle(color: Color(0xFF9DB4AA), fontSize: 12))])),
          const SizedBox(height: 16),
          _EditorBlock(title: 'Ngjarja', text: scene.storyText),
          _EditorBlock(title: 'Lëvizja & kamera', text: scene.motionInstructions),
          _EditorBlock(title: 'Personazhet', text: scene.characterIds.join(' • ')),
          _EditorBlock(title: 'Dialogu / Narratori', text: (scene.dialogue as String).isEmpty && (scene.narration as String).isEmpty ? 'Pa tekst të shtuar — ruhet materiali origjinal.' : '${scene.dialogue}\n${scene.narration}'),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.play_arrow), label: const Text('Preview'))), const SizedBox(width: 10), Expanded(child: FilledButton.icon(onPressed: null, icon: const Icon(Icons.auto_awesome), label: const Text('Gjenero skenën')))]),
          const SizedBox(height: 10),
          const Text('Renderimi është i çaktivizuar derisa Worker-i të ketë provider real image-to-video. Nuk krijohet slideshow i rremë.', style: TextStyle(color: Color(0xFF8FA69C), fontSize: 11, height: 1.35)),
        ]),
      );
}

class _EditorBlock extends StatelessWidget {
  const _EditorBlock({required this.title, required this.text});
  final String title, text;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: gold, fontWeight: FontWeight.w800, fontSize: 12)), const SizedBox(height: 7), Text(text, style: const TextStyle(height: 1.4))]));
}

class _WritingPage extends StatefulWidget {
  const _WritingPage();
  @override
  State<_WritingPage> createState() => _WritingPageState();
}

class _WritingPageState extends State<_WritingPage> {
  final titleController = TextEditingController();
  final textController = TextEditingController();
  @override
  void initState() { super.initState(); _loadDraft(); }
  Future<void> _loadDraft() async { final prefs = await SharedPreferences.getInstance(); if (!mounted) return; titleController.text = prefs.getString('book_draft_title') ?? ''; textController.text = prefs.getString('book_draft_text') ?? ''; }
  Future<void> _saveDraft() async { final prefs = await SharedPreferences.getInstance(); await prefs.setString('book_draft_title', titleController.text); await prefs.setString('book_draft_text', textController.text); if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Drafti u ruajt në këtë pajisje.'))); }
  @override
  void dispose() { titleController.dispose(); textController.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Shkruaj librin tim')), body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Titulli', border: OutlineInputBorder())), const SizedBox(height: 14), Expanded(child: TextField(controller: textController, expands: true, maxLines: null, minLines: null, textAlignVertical: TextAlignVertical.top, decoration: const InputDecoration(labelText: 'Teksti i librit', alignLabelWithHint: true, border: OutlineInputBorder()))), const SizedBox(height: 12), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _saveDraft, icon: const Icon(Icons.save_outlined), label: const Text('Ruaj draftin')))]));
}

class _TextReaderPage extends StatefulWidget {
  const _TextReaderPage({required this.title, required this.content});
  final String title, content;
  @override
  State<_TextReaderPage> createState() => _TextReaderPageState();
}
class _TextReaderPageState extends State<_TextReaderPage> {
  double fontSize = 18;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.title), actions: [IconButton(icon: const Icon(Icons.text_decrease), onPressed: () => setState(() => fontSize = (fontSize - 2).clamp(14, 32))), IconButton(icon: const Icon(Icons.text_increase), onPressed: () => setState(() => fontSize = (fontSize + 2).clamp(14, 32)))]), body: SelectionArea(child: ListView(padding: const EdgeInsets.all(24), children: [Text(widget.content, style: TextStyle(fontSize: fontSize, height: 1.65))])));
}

class _SavedDraftPage extends StatefulWidget {
  const _SavedDraftPage();
  @override
  State<_SavedDraftPage> createState() => _SavedDraftPageState();
}
class _SavedDraftPageState extends State<_SavedDraftPage> {
  String title = '', content = '';
  bool loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { final prefs = await SharedPreferences.getInstance(); if (!mounted) return; setState(() { title = prefs.getString('book_draft_title') ?? ''; content = prefs.getString('book_draft_text') ?? ''; loading = false; }); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Biblioteka ime')), body: loading ? const Center(child: CircularProgressIndicator()) : content.trim().isEmpty ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Nuk ka ende draft të ruajtur. Shkruaj librin tënd dhe ruaje.'))) : ListView(padding: const EdgeInsets.all(20), children: [Card(child: ListTile(title: Text(title.trim().isEmpty ? 'Libri im' : title), subtitle: const Text('Draft lokal • lexim'), onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _TextReaderPage(title: title.trim().isEmpty ? 'Libri im' : title, content: content)))))]));
}
