import 'dart:io';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/ai_film/pilot_story.dart';
import 'features/ai_film/pilot_assets.dart';

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
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['txt', 'md', 'markdown', 'zip']);
    if (!mounted || files.isEmpty) return;
    final file = files.single;
    if (file.extension?.toLowerCase() == 'zip') {
      try {
        final zipBytes = await file.readAsBytes();
        final zipSize = zipBytes.length;
        if (zipSize > 100 * 1024 * 1024) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paketa ZIP tejkalon 100 MB. Importimi u ndal për të mbrojtur memorien e telefonit.')));
          return;
        }
        final imported = await PilotAssets.importZip(zipBytes: zipBytes);
        // Same filenames are reused after reimport; discard decoded old images.
        imageCache.clear();
        imageCache.clearLiveImages();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$imported/22 ilustrime u importuan në tregimin pilot.')));
        await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const _PilotStoryPage()));
      } on FormatException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ZIP i pavlefshëm: ${error.message}')));
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Importimi i ilustrimeve dështoi. Kontrollo arkivin ZIP.')));
      }
      return;
    }
    if (['txt', 'md', 'markdown'].contains(file.extension?.toLowerCase())) {
      if ((file.path != null && File(file.path!).lengthSync() > 10 * 1024 * 1024)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Libri është mbi 10 MB. Për të mbrojtur bibliotekën lokale, përdor një skedar më të vogël.')));
        return;
      }
      final content = utf8.decode(await file.readAsBytes(), allowMalformed: true);
      if (content.trim().isEmpty) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Skedari nuk ka tekst për lexim.'))); return; }
      final prefs = await SharedPreferences.getInstance();
      late final List<Map<String, dynamic>> library;
      try {
        final decoded = jsonDecode(prefs.getString('library_books_v1') ?? '[]');
        library = decoded is List
            ? decoded.whereType<Map>()
                .where((item) => item.keys.every((key) => key is String))
                .map((item) => Map<String, dynamic>.from(item))
                .where((item) => item['title'] is String && item['content'] is String)
                .toList()
            : <Map<String, dynamic>>[];
      } on FormatException {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biblioteka e ruajtur ka të dhëna të dëmtuara. Importimi u ndal për të mos fshirë librat ekzistues.')));
        return;
      }
      library.removeWhere((entry) => entry['title'] == file.name);
      library.insert(0, {'title': file.name, 'content': content});
      final saved = await prefs.setString('library_books_v1', jsonEncode(library));
      if (!saved) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ruajtja e librit dështoi. Provo përsëri.')));
        return;
      }
      await prefs.setString('imported_book_title', file.name);
      await prefs.setString('imported_book_text', content);
      if (!mounted) return;
      setState(() => selectedBook = file.name);
      await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _TextReaderPage(title: file.name, content: content)));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Formati ${file.extension?.toUpperCase() ?? 'i zgjedhur'} nuk mbështetet ende për lexim. Përdor TXT ose Markdown.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        bottomNavigationBar: NavigationBar(
          selectedIndex: 0,
          onDestinationSelected: (index) {
            if (index == 1) {
              Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const _SavedDraftPage()));
            } else if (index == 2) {
              Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const _PilotStoryPage()));
            } else if (index == 3) {
              showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (sheetContext) => SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Profili privat', style: Theme.of(sheetContext).textTheme.headlineSmall), const SizedBox(height: 12), const Text('Aplikacioni është për testim personal. Nuk kërkohet llogari për draftet lokale.'), const SizedBox(height: 18), FilledButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Mbyll'))]))));
            }
          },
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
                  _PremiumAction(title: 'Importo libër', subtitle: selectedBook ?? 'TXT / Markdown • lexim me zë', icon: Icons.library_books_outlined, onTap: _import),
                  _PremiumAction(title: 'Shkruaj librin', subtitle: 'Draft privat në telefon', icon: Icons.edit_note_outlined, onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const _WritingPage()))),
                  _PremiumAction(title: 'Film AI', subtitle: 'Storyboard • skena • preview', icon: Icons.movie_filter_outlined, onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const _PilotStoryPage()))),
                  _PremiumAction(title: 'Biblioteka ime', subtitle: 'Rafti personal', icon: Icons.auto_stories_outlined, onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const _SavedDraftPage()))),
                ],
              ),
              const SizedBox(height: 25),
              const _SectionTitle('Biblioteka Ime'),
              const SizedBox(height: 12),
              _BookShelf(onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const _SavedDraftPage()))),
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
            Text('12 skena • 2 personazhe • storyboard pa video', style: TextStyle(color: Color(0xFFC0D2CA))),
            SizedBox(height: 18),
            Row(children: [
              _MiniPill('Lexo tregimin'), SizedBox(width: 8), _MiniPill('Shiko skenat'), SizedBox(width: 8), _MiniPill('Importo ilustrimet'),
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

class _PilotStoryPage extends StatefulWidget {
  const _PilotStoryPage();
  @override
  State<_PilotStoryPage> createState() => _PilotStoryPageState();
}

class _PilotStoryPageState extends State<_PilotStoryPage> {
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(livingLibraryPilot.title), actions: [IconButton(tooltip: 'Dëgjo tregimin', icon: const Icon(Icons.volume_up_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _TextReaderPage(title: livingLibraryPilot.title, content: livingLibraryPilot.storyText))))]),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: gold.withValues(alpha: .45))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('FILM AI • STORYBOARD', style: TextStyle(color: gold, fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 11)),
            const SizedBox(height: 10),
            Text(livingLibraryPilot.storyText, style: const TextStyle(fontSize: 15, height: 1.5)),
            const SizedBox(height: 15),
            const Wrap(spacing: 8, runSpacing: 8, children: [_StatusChip('12 skena'), _StatusChip('2 personazhe'), _StatusChip('Storyboard • pa renderim video')]),
          ])),
          const SizedBox(height: 18),
          _PilotImportControl(onImported: () => setState(() {})),
          const SizedBox(height: 18),
          const Text('Skenat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...livingLibraryPilot.scenes.asMap().entries.map((entry) => _SceneCard(index: entry.key, scene: entry.value)),
          const SizedBox(height: 18),
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF102A24), borderRadius: BorderRadius.circular(16)), child: const Text('Gjenerimi real i videos nuk simulohet: butoni i renderimit aktivizohet vetëm pasi provider-i image-to-video të lidhet në Worker. Kredencialet nuk futen në APK.', style: TextStyle(color: Color(0xFFADC1B8), height: 1.4))),
        ]),
      );
}

class _PilotImportControl extends StatefulWidget {
  const _PilotImportControl({required this.onImported});
  final VoidCallback onImported;
  @override
  State<_PilotImportControl> createState() => _PilotImportControlState();
}

class _PilotImportControlState extends State<_PilotImportControl> {
  int count = 0;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    _refresh();
  }
  Future<void> _refresh() async {
    final value = await PilotAssets.installedCount();
    if (mounted) setState(() => count = value);
  }
  Future<void> _import() async {
    setState(() => busy = true);
    try {
      final imported = await PilotAssets.importZip();
      if (imported > 0) {
        imageCache.clear();
        imageCache.clearLiveImages();
      }
      await _refresh();
      if (mounted && imported > 0) {
        widget.onImported();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$imported ilustrime u importuan në telefon.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Importi dështoi: $error')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => Card(
    color: panel,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ilustrimet e tregimit: $count/22', style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Importo paketën ZIP me ilustrimet e tregimit. Skedarët ruhen vetëm në këtë pajisje.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: busy ? null : _import,
          icon: const Icon(Icons.folder_zip_outlined),
          label: Text(busy ? 'Duke importuar...' : 'Importo 22 ilustrimet'),
        ),
      ]),
    ),
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
            SizedBox(width: 64, height: 56, child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FutureBuilder(
                future: PilotAssets.frame(scene.referenceImagePaths.first),
                builder: (context, snapshot) => snapshot.hasData && snapshot.data != null
                    ? Image.file(snapshot.data!, fit: BoxFit.cover)
                    : Container(color: gold.withValues(alpha: .12),
                        alignment: Alignment.center,
                        child: Text('${index + 1}', style: const TextStyle(color: gold, fontSize: 18, fontWeight: FontWeight.w900))),
              ),
            )),
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
          SizedBox(height: 190, child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: scene.referenceImagePaths.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, frameIndex) => ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 235,
                color: const Color(0xFF102E27),
                child: FutureBuilder<File?>(
                  future: PilotAssets.frame(scene.referenceImagePaths[frameIndex]),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return Image.file(snapshot.data!, fit: BoxFit.cover);
                    }
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.folder_zip_outlined, color: gold, size: 38),
                          SizedBox(height: 8),
                          Text('Importo paketën origjinale ZIP nga faqja e pilotit',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFFB6C6BD), fontSize: 12)),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ),
          )),
          const SizedBox(height: 16),
          _EditorBlock(title: 'Ngjarja', text: scene.storyText),
          _EditorBlock(title: 'Lëvizja & kamera', text: scene.motionInstructions),
          _EditorBlock(title: 'Personazhet', text: scene.characterIds.join(' • ')),
          _EditorBlock(title: 'Dialogu / Narratori', text: (scene.dialogue as String).isEmpty && (scene.narration as String).isEmpty ? 'Pa tekst të shtuar — ruhet materiali origjinal.' : '${scene.dialogue}\n${scene.narration}'),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _SceneFramesPage(scene: scene, index: index))), icon: const Icon(Icons.photo_library_outlined), label: const Text('Shiko ilustrimet'))), const SizedBox(width: 10), Expanded(child: FilledButton.icon(onPressed: null, icon: const Icon(Icons.auto_awesome), label: const Text('Gjenero skenën')))]),
          const SizedBox(height: 10),
          const Text('Renderimi është i çaktivizuar derisa Worker-i të ketë provider real image-to-video. Nuk krijohet slideshow i rremë.', style: TextStyle(color: Color(0xFF8FA69C), fontSize: 11, height: 1.35)),
        ]),
      );
}

/// Shows the actual imported frames, not a simulated generated video.
class _SceneFramesPage extends StatelessWidget {
  const _SceneFramesPage({required this.scene, required this.index});
  final dynamic scene;
  final int index;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Ilustrimet • Skena ${index + 1}')),
    body: PageView.builder(
      itemCount: scene.referenceImagePaths.length,
      itemBuilder: (context, frameIndex) => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(children: [
          Text('${frameIndex + 1} / ${scene.referenceImagePaths.length} • ${scene.title}',
              style: const TextStyle(color: gold, fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),
          Expanded(child: FutureBuilder<File?>(
            future: PilotAssets.frame(scene.referenceImagePaths[frameIndex]),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text('Ilustrimi nuk mund të lexohet.'));
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final file = snapshot.data;
              if (file == null) {
                return const Center(child: Text('Ilustrimi mungon. Importo ZIP-in origjinal në Studio AI.'));
              }
              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: Center(child: Image.file(file, fit: BoxFit.contain)),
              );
            },
          )),
          const SizedBox(height: 14),
          const Text('Rrëshqit majtas ose djathtas për ilustrimin tjetër.',
              style: TextStyle(color: Color(0xFFB6C6BD))),
        ]),
      ),
    ),
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
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Shkruaj librin tim')), body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Titulli', border: OutlineInputBorder())), const SizedBox(height: 14), Expanded(child: TextField(controller: textController, expands: true, maxLines: null, minLines: null, textAlignVertical: TextAlignVertical.top, decoration: const InputDecoration(labelText: 'Teksti i librit', alignLabelWithHint: true, border: OutlineInputBorder()))), const SizedBox(height: 12), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _saveDraft, icon: const Icon(Icons.save_outlined), label: const Text('Ruaj draftin')))])));
}

class _TextReaderPage extends StatefulWidget {
  const _TextReaderPage({required this.title, required this.content});
  final String title, content;
  @override
  State<_TextReaderPage> createState() => _TextReaderPageState();
}
class _TextReaderPageState extends State<_TextReaderPage> {
  double fontSize = 18;
  double speechRate = 0.45;
  bool speaking = false;
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _searchController = TextEditingController();
  String _readerQuery = '';
  int get _matchCount {
    final q = _readerQuery.trim().toLowerCase();
    if (q.isEmpty) return 0;
    final text = widget.content.toLowerCase();
    var count = 0;
    var from = 0;
    while (true) {
      final index = text.indexOf(q, from);
      if (index < 0) return count;
      count++;
      from = index + q.length;
    }
  }

  Widget _readerText() {
    final query = _readerQuery.trim();
    final style = TextStyle(fontSize: fontSize, height: 1.65);
    if (query.isEmpty) return Text(widget.content, style: style);
    final lower = widget.content.toLowerCase();
    final needle = query.toLowerCase();
    final spans = <TextSpan>[];
    var from = 0;
    var matches = 0;
    while (matches < 200) {
      final at = lower.indexOf(needle, from);
      if (at < 0) break;
      if (at > from) spans.add(TextSpan(text: widget.content.substring(from, at)));
      spans.add(TextSpan(
        text: widget.content.substring(at, at + query.length),
        style: const TextStyle(backgroundColor: Color(0xFFE2BE72), color: Color(0xFF071B17), fontWeight: FontWeight.bold),
      ));
      from = at + query.length;
      matches++;
    }
    if (from < widget.content.length) spans.add(TextSpan(text: widget.content.substring(from)));
    return RichText(text: TextSpan(style: style.copyWith(color: Theme.of(context).colorScheme.onSurface), children: spans));
  }

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('sq-AL');
    _tts.setSpeechRate(speechRate);
    _tts.setCompletionHandler(() { if (mounted) setState(() => speaking = false); });
    _tts.setCancelHandler(() { if (mounted) setState(() => speaking = false); });
    _tts.setErrorHandler((_) { if (mounted) setState(() => speaking = false); });
  }

  bool _speechCancelled = false;
  int _speechSession = 0;

  Future<void> _toggleSpeech() async {
    if (speaking) {
      _speechCancelled = true;
      _speechSession++;
      await _tts.stop();
      if (mounted) setState(() => speaking = false);
      return;
    }
    final content = widget.content.trim();
    if (content.isEmpty) return;
    _speechCancelled = false;
    final session = ++_speechSession;
    try {
      await _tts.setLanguage('sq-AL');
      await _tts.setSpeechRate(speechRate);
      await _tts.awaitSpeakCompletion(true);
      if (!mounted || _speechCancelled) return;
      setState(() => speaking = true);
      var offset = 0;
      while (offset < content.length && !_speechCancelled && session == _speechSession) {
        var end = offset + 3000;
        if (end >= content.length) {
          end = content.length;
        } else {
          final boundary = content.lastIndexOf(RegExp(r'[.!?\s]'), end);
          if (boundary > offset + 1500) end = boundary + 1;
        }
        await _tts.speak(content.substring(offset, end));
        offset = end;
      }
    } catch (_) {
      if (mounted && !_speechCancelled) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Leximi me zë u ndërpre. Kontrollo motorin TTS dhe zërin shqip.'),
        ));
      }
    } finally {
      if (mounted && session == _speechSession) setState(() => speaking = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _speechCancelled = true;
    _speechSession++;
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title), actions: [
      IconButton(tooltip: 'Zvogëlo shkronjat', icon: const Icon(Icons.text_decrease), onPressed: () => setState(() => fontSize = (fontSize - 2).clamp(14, 32))),
      IconButton(tooltip: 'Zmadho shkronjat', icon: const Icon(Icons.text_increase), onPressed: () => setState(() => fontSize = (fontSize + 2).clamp(14, 32))),
    ]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _readerQuery = value),
        decoration: InputDecoration(prefixIcon: const Icon(Icons.search), labelText: 'Kërko brenda librit',
          suffixText: _readerQuery.isEmpty ? null : '$_matchCount gjetje',
          suffixIcon: IconButton(tooltip: 'Pastro kërkimin', icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() => _readerQuery = ''); }),
          border: const OutlineInputBorder()),
      )),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(children: [
          FilledButton.icon(
            onPressed: _toggleSpeech,
            icon: Icon(speaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined),
            label: Text(speaking ? 'Ndalo leximin' : 'Lexo me zë'),
          ),
          const SizedBox(width: 10),
          const Text('Shpejtësia'),
          Expanded(child: Slider(value: speechRate, min: 0.2, max: 0.8, onChanged: (value) async {
            setState(() => speechRate = value);
            await _tts.setSpeechRate(value);
          })),
        ]),
      ),
      Expanded(child: SelectionArea(child: ListView(
        padding: const EdgeInsets.all(24),
        children: [_readerText()],
      ))),
    ]),
  );
}

List<Map<String, dynamic>> _safeBooks(String? raw) {
  try {
    final decoded = jsonDecode(raw ?? '[]');
    if (decoded is! List) return [];
    return decoded.whereType<Map>().where((item) => item['title'] is String && item['content'] is String).map((item) => {'title': item['title'] as String, 'content': item['content'] as String}).toList();
  } catch (_) {
    return [];
  }
}

class _SavedDraftPage extends StatefulWidget {
  const _SavedDraftPage();
  @override
  State<_SavedDraftPage> createState() => _SavedDraftPageState();
}
class _SavedDraftPageState extends State<_SavedDraftPage> {
  String title = '', content = '', importedTitle = '', importedText = '';
  bool loading = true;
  String searchQuery = '';
  List<Map<String, dynamic>> libraryBooks = [];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { final prefs = await SharedPreferences.getInstance(); if (!mounted) return; setState(() { title = prefs.getString('book_draft_title') ?? ''; content = prefs.getString('book_draft_text') ?? ''; importedTitle = prefs.getString('imported_book_title') ?? ''; importedText = prefs.getString('imported_book_text') ?? ''; libraryBooks = _safeBooks(prefs.getString('library_books_v1')); loading = false; }); }
  Future<void> _deleteBook(String bookTitle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Fshi librin?'),
        content: Text('Libri "$bookTitle" do të hiqet nga biblioteka lokale.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Anulo')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Fshi')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final updated = libraryBooks.where((book) => book['title'] != bookTitle).toList();
    final saved = await prefs.setString('library_books_v1', jsonEncode(updated));
    if (!mounted) return;
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fshirja nuk u ruajt.')));
      return;
    }
    if (importedTitle == bookTitle) {
      await prefs.remove('imported_book_title');
      await prefs.remove('imported_book_text');
    }
    setState(() {
      libraryBooks = updated;
      if (importedTitle == bookTitle) { importedTitle = ''; importedText = ''; }
    });
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Biblioteka ime')), body: loading ? const Center(child: CircularProgressIndicator()) : content.trim().isEmpty && importedText.trim().isEmpty && libraryBooks.isEmpty ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Nuk ka ende draft të ruajtur. Shkruaj librin tënd dhe ruaje.'))) : ListView(padding: const EdgeInsets.all(20), children: [TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Kërko librin', border: OutlineInputBorder()), onChanged: (value) => setState(() => searchQuery = value.trim().toLowerCase())), const SizedBox(height: 12), for (final book in libraryBooks.where((book) => (book['title'] as String? ?? '').toLowerCase().contains(searchQuery))) Card(child: ListTile(leading: const Icon(Icons.menu_book_outlined), title: Text(book['title'] as String? ?? 'Libër'), subtitle: const Text('Libër i ruajtur • lexim me zë'), trailing: IconButton(tooltip: 'Fshi librin', icon: const Icon(Icons.delete_outline), onPressed: () => _deleteBook(book['title'] as String? ?? '')), onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _TextReaderPage(title: book['title'] as String? ?? 'Libër', content: book['content'] as String? ?? ''))))), if (libraryBooks.isEmpty && importedText.trim().isNotEmpty && importedTitle.toLowerCase().contains(searchQuery)) Card(child: ListTile(title: Text(importedTitle.isEmpty ? 'Libri i importuar' : importedTitle), subtitle: const Text('TXT/Markdown • ruajtur në telefon'), onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _TextReaderPage(title: importedTitle, content: importedText))))), if (content.trim().isNotEmpty && (title.trim().isEmpty ? 'Libri im' : title).toLowerCase().contains(searchQuery)) Card(child: ListTile(title: Text(title.trim().isEmpty ? 'Libri im' : title), subtitle: const Text('Draft lokal • lexim'), onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _TextReaderPage(title: title.trim().isEmpty ? 'Libri im' : title, content: content)))))]));
}
