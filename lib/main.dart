import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdfrx/pdfrx.dart';
import 'features/ai_film/pilot_story.dart';
import 'features/ai_film/pilot_assets.dart';
import 'features/ai/ai_connection.dart';
import 'features/ai_film/story_studio.dart';
import 'features/library/book_card.dart';

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
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: gold,
            selectionColor: gold.withValues(alpha: 0.28),
            selectionHandleColor: gold,
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: panel,
            indicatorColor: gold.withValues(alpha: 0.20),
            iconTheme: WidgetStateProperty.resolveWith((states) =>
              IconThemeData(color: states.contains(WidgetState.selected) ? gold : const Color(0xFFB7C2D0))),
            labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              color: states.contains(WidgetState.selected) ? gold : const Color(0xFFB7C2D0),
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            )),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0D2A24),
            foregroundColor: Color(0xFFE2BE72),
            centerTitle: false,
            elevation: 0,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF0D2A24),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF31594D)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF31594D)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2BE72), width: 1.5),
            ),
          ),
          snackBarTheme: SnackBarThemeData(
            backgroundColor: const Color(0xFF0D2A24),
            contentTextStyle: const TextStyle(color: Colors.white),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: panel,
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: gold,
              minimumSize: const Size(48, 48),
              side: BorderSide(color: gold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
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
    List<PlatformFile> files;
    try {
      files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['txt', 'md', 'markdown', 'pdf', 'zip']);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zgjedhja e skedarit dështoi. Provo përsëri.')));
      return;
    }
    if (!mounted || files.isEmpty) return;
    final file = files.single;
    // Some Android document providers omit PlatformFile.extension.
    // Derive it from the selected filename so supported imports still work.
    final filename = file.name.toLowerCase();
    final extension = (file.extension?.trim().isNotEmpty == true
            ? file.extension!.toLowerCase()
            : (filename.contains('.') ? filename.split('.').last : ''));
    if (!['txt', 'md', 'markdown', 'pdf', 'zip'].contains(extension)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Format i pambështetur. Zgjidh TXT, Markdown, PDF ose ZIP me ilustrime.')));
      return;
    }
    if (extension == 'zip') {
      try {
        if (file.path != null && await File(file.path!).length() > 80 * 1024 * 1024) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paketa ZIP tejkalon 80 MiB. Importimi u ndal për të mbrojtur memorien e telefonit.')));
          return;
        }
        final zipBytes = await file.readAsBytes();
        if (zipBytes.length > 80 * 1024 * 1024) throw const FormatException('ZIP tejkalon 80 MiB');
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
    if (['txt', 'md', 'markdown', 'pdf'].contains(extension)) {
      String content;
      try {
        if (file.path != null && await File(file.path!).length() > 10 * 1024 * 1024) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Libri është mbi 10 MB. Për të mbrojtur bibliotekën lokale, përdor një skedar më të vogël.')));
          return;
        }
        final bytes = await file.readAsBytes();
        if (bytes.length > 10 * 1024 * 1024) throw const FormatException('Libri tejkalon 10 MB');
        if (extension == 'pdf') {
          await pdfrxFlutterInitialize();
          final document = await PdfDocument.openData(bytes);
          try {
            if (document.pages.length > 300) throw const FormatException('PDF-ja ka mbi 300 faqe. Ndaje në pjesë më të vogla për importim të sigurt.');
            if (document.permissions?.allowsCopying == false) throw const FormatException('PDF-ja nuk lejon nxjerrjen e tekstit.');
            final pages = <String>[];
            for (final page in document.pages) {
              final text = await page.loadText();
              if (text != null && text.fullText.trim().isNotEmpty) {
                pages.add('## Faqja ${page.pageNumber}\n\n${text.fullText}');
                if (pages.fold<int>(0, (total, part) => total + part.length) > 10 * 1024 * 1024) {
                  throw const FormatException('Teksti i PDF-së është tepër i madh. Ndaje librin në pjesë më të vogla.');
                }
              }
            }
            content = pages.join('\n\n');
            if (content.trim().isEmpty) throw const FormatException('PDF-ja nuk ka shtresë teksti. Skanimet kërkojnë OCR, që nuk është konfiguruar.');
          } finally { await document.dispose(); }
        } else {
          try {
            content = utf8.decode(bytes, allowMalformed: false).replaceFirst(RegExp(r'^\uFEFF'), '');
          } on FormatException {
            throw const FormatException('Teksti nuk është UTF-8 i vlefshëm. Ruaje skedarin si UTF-8 dhe provo përsëri.');
          }
        }
      } on FormatException catch (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
        return;
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Importimi nuk përfundoi. Kontrollo formatin dhe madhësinë e skedarit.')));
        return;
      }
      if (utf8.encode(content).length > 10 * 1024 * 1024) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teksti i nxjerrë tejkalon 10 MB. Ndaje librin në pjesë më të vogla.'))); return; }
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
            : throw const FormatException('Invalid library root');
        if (decoded.length != library.length) {
          throw const FormatException('Invalid stored book entries');
        }
      } on Object catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biblioteka e ruajtur ka të dhëna të dëmtuara. Importimi u ndal për të mos fshirë librat ekzistues.')));
        return;
      }
      // Preserve earlier imports with the same filename instead of overwriting them.
      var uniqueTitle = file.name;
      var duplicateIndex = 2;
      final dot = file.name.lastIndexOf('.');
      final stem = dot > 0 ? file.name.substring(0, dot) : file.name;
      final suffix = dot > 0 ? file.name.substring(dot) : '';
      while (library.any((entry) => (entry['title'] as String).trim().toLowerCase() == uniqueTitle.trim().toLowerCase())) {
        uniqueTitle = '$stem ($duplicateIndex)$suffix';
        duplicateIndex++;
      }
      // SharedPreferences is not intended for an unlimited collection of large books.
      // Refuse an import that would exceed the practical local JSON storage budget.
      library.insert(0, {'title': uniqueTitle, 'content': content});
      final encodedLibrary = jsonEncode(library);
      if (utf8.encode(encodedLibrary).length > 20 * 1024 * 1024) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biblioteka ka arritur kufirin lokal 20 MB. Librat ekzistues nuk u ndryshuan.')));
        return;
      }
      final saved = await prefs.setString('library_books_v1', encodedLibrary);
      if (!saved) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ruajtja e librit dështoi. Provo përsëri.')));
        return;
      }
      await prefs.setString('imported_book_title', uniqueTitle);
      await prefs.setString('imported_book_text', content);
      if (!mounted) return;
      setState(() => selectedBook = uniqueTitle);
      await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _TextReaderPage(title: uniqueTitle, content: content)));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Formati ${extension.isEmpty ? 'i zgjedhur' : extension.toUpperCase()} nuk mbështetet ende për lexim. Përdor TXT, Markdown ose PDF me tekst.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        bottomNavigationBar: NavigationBar(
          selectedIndex: 0,
          onDestinationSelected: (index) {
            if (index == 1) {
              Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const _SavedDraftPage()));
            } else if (index == 2) {
              Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const StoryStudio()));
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
                  _PremiumAction(title: 'Importo libër ose ilustrime', subtitle: selectedBook ?? 'TXT • Markdown • PDF tekstual • ZIP ilustrimesh', icon: Icons.library_books_outlined, onTap: _import),
                  _PremiumAction(title: 'Shkruaj librin', subtitle: 'Draft privat në telefon', icon: Icons.edit_note_outlined, onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const _WritingPage()))),
                  _PremiumAction(title: 'Studio e tregimeve', subtitle: 'Skena • narracion • ilustrime', icon: Icons.movie_filter_outlined, onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const StoryStudio()))),
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
              _MiniPill('Lexo tregimin'), SizedBox(width: 8), _MiniPill('Shiko skenat'), SizedBox(width: 8), _MiniPill('22 ilustrime'),
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
  @override Widget build(BuildContext context) => FutureBuilder<SharedPreferences>(future: SharedPreferences.getInstance(), builder: (context, snapshot) {
    final books = _safeBooks(snapshot.data?.getString('library_books_v1'));
    if (books.isEmpty) return Card(child: ListTile(onTap: onTap, leading: const Icon(Icons.library_books_outlined, color: gold), title: const Text('Biblioteka jote'), subtitle: const Text('Importo librin tënd ose shkruaj një draft.')));
    return Column(children: [for (final book in books.take(3)) BookCard(key: ValueKey(book['title']), title: book['title'] as String, onOpen: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _TextReaderPage(title: book['title'] as String, content: book['content'] as String)))), TextButton(onPressed: onTap, child: Text('Shiko bibliotekën • ${books.length} libra'))]);
  });
}

class _RecentReading extends StatelessWidget {
  const _RecentReading();
  @override Widget build(BuildContext context) => FutureBuilder<SharedPreferences>(future: SharedPreferences.getInstance(), builder: (context, snapshot) {
    final title = snapshot.data?.getString('reader_last_title');
    if (title == null) return const Text('Leximet e tua të fundit do të shfaqen këtu.', style: TextStyle(color: Color(0xFF9DB4AA)));
    return Card(child: ListTile(leading: const Icon(Icons.history, color: gold), title: Text(title), subtitle: const Text('Pozicioni i leximit ruhet në pajisje.'), onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const _SavedDraftPage()))));
  });
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Importimi dështoi. Kontrollo që ZIP të përmbajë 22 ilustrimet e duhura dhe provo përsëri.')));
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
        const Text('22 ilustrimet janë të përfshira në aplikacion. Mund t’i zëvendësosh me një paketë ZIP.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: busy ? null : _import,
          icon: const Icon(Icons.folder_zip_outlined),
          label: Text(busy ? 'Duke importuar...' : 'Zëvendëso ilustrimet me ZIP'),
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
        appBar: AppBar(title: Text('Skena ${index + 1} • ${scene.title}'), actions: [IconButton(tooltip: 'Redakto skenën', icon: const Icon(Icons.edit), onPressed: () async { final file = await PilotAssets.frame(scene.referenceImagePaths.first); if (!context.mounted) return; await Navigator.push(context, MaterialPageRoute(builder: (_) => StorySceneEditor(storageKey: 'pilot_scene_${scene.id}', scene: {'title': scene.title, 'text': scene.storyText, 'characters': scene.characterIds.join(', '), 'narration': scene.narration, 'motion': scene.motionInstructions, 'image': file?.path ?? ''}))); })]),
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
  Future<void> _exportDraft({required bool markdown}) async {
    final title = titleController.text.trim();
    final body = textController.text;
    if (body.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shkruaj tekstin e librit përpara eksportimit.')));
      return;
    }
    final safeName = (title.isEmpty ? 'Libri_im' : title)
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final output = markdown && title.isNotEmpty ? '# $title\n\n$body' : body;
    try {
      final result = await FilePicker.saveFile(
        dialogTitle: 'Eksporto librin',
        fileName: '$safeName.${markdown ? 'md' : 'txt'}',
        bytes: utf8.encode(output),
      );
      if (mounted && result != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Libri u eksportua.')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Eksportimi dështoi. Drafti mbetet në editor.')));
    }
  }
  @override
  void dispose() { titleController.dispose(); textController.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Shkruaj librin tim'), actions: [PopupMenuButton<bool>(tooltip: 'Eksporto librin', onSelected: (markdown) => _exportDraft(markdown: markdown), itemBuilder: (_) => const [PopupMenuItem(value: false, child: Text('Eksporto TXT')), PopupMenuItem(value: true, child: Text('Eksporto Markdown'))])]), body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Titulli', border: OutlineInputBorder())), const SizedBox(height: 14), Expanded(child: TextField(controller: textController, expands: true, maxLines: null, minLines: null, textAlignVertical: TextAlignVertical.top, decoration: const InputDecoration(labelText: 'Teksti i librit', alignLabelWithHint: true, border: OutlineInputBorder()))), const SizedBox(height: 12), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _saveDraft, icon: const Icon(Icons.save_outlined), label: const Text('Ruaj draftin')))])));
}

class _TextReaderPage extends StatefulWidget {
  const _TextReaderPage({required this.title, required this.content});
  final String title, content;
  @override
  State<_TextReaderPage> createState() => _TextReaderPageState();
}
class _TextReaderPageState extends State<_TextReaderPage> {
  double fontSize = 18, speechRate = 0.45;
  bool speaking = false, speechStarting = false, aiBusy = false;
  String language = 'sq-AL', query = '';
  int current = 0, activeWordStart = -1, activeWordEnd = -1;
  final FlutterTts _tts = FlutterTts();
  final TextEditingController search = TextEditingController();
  final ScrollController scroll = ScrollController();
  late final List<String> paragraphs;
  late final List<GlobalKey> keys;
  List<int> bookmarks = [];
  Map<String, String> notes = {};
  int session = 0;
  Timer? scrollSave;
  int jumpGeneration = 0;
  bool jumping = false;
  String get storageKey => 'reader_v2_${base64Url.encode(utf8.encode(widget.title))}';
  List<int> get matches => query.trim().isEmpty ? [] : [for (var i = 0; i < paragraphs.length; i++) if (paragraphs[i].toLowerCase().contains(query.toLowerCase())) i];
  @override
  void initState() {
    super.initState();
    paragraphs = widget.content.split(RegExp(r'\n\s*\n')).where((p) => p.trim().isNotEmpty).expand((p) sync* {
      // Bound native TTS utterances while keeping all source characters.
      var from = 0;
      while (from < p.length) {
        var end = (from + 2500).clamp(0, p.length);
        if (end < p.length) { final at = p.lastIndexOf(RegExp(r'[.!?\s]'), end); if (at > from + 1000) end = at + 1; }
        yield p.substring(from, end); from = end;
      }
    }).toList();
    keys = List.generate(paragraphs.length, (_) => GlobalKey());
    _load();
    scroll.addListener(() {
      if (!mounted || speaking || jumping) return;
      for (var i = 0; i < keys.length; i++) {
        final box = keys[i].currentContext?.findRenderObject();
        if (box is RenderBox && box.hasSize) {
          final top = box.localToGlobal(Offset.zero).dy;
          if (top + box.size.height <= 250) continue;
          if (current != i) {
            setState(() => current = i);
            scrollSave?.cancel();
            scrollSave = Timer(const Duration(milliseconds: 350), _save);
          }
          break;
        }
      }
    });
    _tts.setProgressHandler((text, start, end, word) { if (mounted && speaking) setState(() { activeWordStart = start; activeWordEnd = end; }); });
    _tts.setErrorHandler((message) { if (mounted) { session++; setState(() => speaking = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Motori TTS nuk mund ta lexojë tekstin. Kontrollo zërat e instaluar.'))); } });
  }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final data = jsonDecode(prefs.getString(storageKey) ?? '{}') as Map;
      if (!mounted) return;
      setState(() {
        current = ((data['position'] as int?) ?? 0).clamp(0, paragraphs.isEmpty ? 0 : paragraphs.length - 1);
        bookmarks = ((data['bookmarks'] as List?) ?? []).whereType<int>().where((i) => i >= 0 && i < paragraphs.length).toList();
        notes = Map<String, String>.from(data['notes'] as Map? ?? {});
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _jump(current));
    } catch (_) { /* Keep source book available if reader preferences are damaged. */ }
  }
  Future<void> _save({bool reportFailure = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reader_last_title', widget.title);
    final ok = await prefs.setString(storageKey, jsonEncode({'position': current, 'bookmarks': bookmarks, 'notes': notes}));
    if (!ok && reportFailure && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pozicioni nuk mund të ruhej.')));
  }
  void _jump(int index) {
    if (!mounted || paragraphs.isEmpty) return;
    setState(() => current = index.clamp(0, paragraphs.length - 1));
    final ctx = keys[current].currentContext;
    if (ctx != null) {
      final generation = ++jumpGeneration;
      jumping = true;
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 200), alignment: .1)
          .whenComplete(() {
        if (generation == jumpGeneration) jumping = false;
      });
    }
    _save();
  }
  Future<void> _note() async {
    final controller = TextEditingController(text: notes['$current'] ?? '');
    final result = await showDialog<String>(context: context, builder: (dialog) => AlertDialog(title: Text('Shënim • pjesa ${current + 1}'), content: TextField(controller: controller, maxLines: 6), actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Anulo')), FilledButton(onPressed: () => Navigator.pop(dialog, controller.text), child: const Text('Ruaj'))]));
    if (result != null && mounted) { setState(() => notes['$current'] = result); await _save(); }
  }
  Future<void> _ai(String operation) async {
    if (paragraphs.isEmpty || !await configureAi(context) || !mounted) return;
    setState(() => aiBusy = true);
    try {
      final result = await aiText(paragraphs[current], operation: operation);
      if (mounted) await showDialog<void>(context: context, builder: (dialog) => AlertDialog(title: Text(operation == 'translate' ? 'Përkthimi AI' : 'Shpjegimi AI'), content: SingleChildScrollView(child: SelectableText(result)), actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Mbyll'))]));
    } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error'))); }
    finally { if (mounted) setState(() => aiBusy = false); }
  }
  Future<void> _toggleSpeech() async {
    if (speaking || speechStarting) {
      session++;
      setState(() { speaking = false; speechStarting = false; activeWordStart = -1; activeWordEnd = -1; });
      await _tts.stop();
      return;
    }
    if (paragraphs.isEmpty) return;
    final run = ++session;
    setState(() => speechStarting = true);
    try {
      final available = await _tts.isLanguageAvailable(language);
      if (available != true && available != 1) throw const FormatException('Zëri i kësaj gjuhe nuk është i instaluar.');
      await _tts.setLanguage(language); await _tts.setSpeechRate(speechRate); await _tts.awaitSpeakCompletion(true);
      if (!mounted || run != session) return;
      setState(() { speaking = true; speechStarting = false; });
      for (var i = current; i < paragraphs.length && run == session && mounted; i++) {
        _jump(i); setState(() { activeWordStart = -1; activeWordEnd = -1; });
        await _tts.speak(paragraphs[i]);
      }
    } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Leximi u ndal: $error'))); }
    finally { if (mounted && run == session) setState(() { speaking = false; speechStarting = false; }); }
  }
  Widget _text(int index) {
    final text = paragraphs[index];
    final chapter = RegExp(r'^#{1,3}\s|^(Kapitulli|Chapter|Kapitel)\b', caseSensitive: false).hasMatch(text);
    final style = TextStyle(fontSize: chapter ? fontSize + 4 : fontSize, height: 1.65, fontWeight: chapter ? FontWeight.bold : FontWeight.normal, color: Theme.of(context).colorScheme.onSurface);
    var start = -1, end = -1;
    if (speaking && index == current) { start = activeWordStart; end = activeWordEnd; }
    else if (query.isNotEmpty) { start = text.toLowerCase().indexOf(query.toLowerCase()); end = start + query.length; }
    if (start < 0 || end > text.length || end <= start) return Text(text, style: style);
    return RichText(text: TextSpan(style: style, children: [TextSpan(text: text.substring(0, start)), TextSpan(text: text.substring(start, end), style: const TextStyle(backgroundColor: gold, color: emerald)), TextSpan(text: text.substring(end))]));
  }
  @override
  void dispose() {
    if (scrollSave?.isActive ?? false) {
      scrollSave?.cancel();
      _save(reportFailure: false);
    }
    session++;
    _tts.stop();
    search.dispose();
    scroll.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title), actions: [
      IconButton(tooltip: 'Krijo storyboard nga libri', icon: const Icon(Icons.movie_creation_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoryStudio(initialTitle: widget.title, initialText: widget.content)))),
      IconButton(tooltip: 'Madhësia e tekstit', onPressed: () => setState(() => fontSize = fontSize >= 28 ? 16 : fontSize + 2), icon: const Icon(Icons.text_fields)),
      PopupMenuButton<int>(tooltip: 'Kapitujt dhe shënuesit', onSelected: _jump, itemBuilder: (_) => [for (var i = 0; i < paragraphs.length; i++) if (bookmarks.contains(i) || RegExp(r'^#{1,3}\s|^(Kapitulli|Chapter|Kapitel)\b', caseSensitive: false).hasMatch(paragraphs[i])) PopupMenuItem(value: i, child: Text('${bookmarks.contains(i) ? '★ ' : ''}${paragraphs[i].split('\n').first}', maxLines: 2))]),
    ]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: TextField(controller: search, onChanged: (v) => setState(() => query = v), decoration: InputDecoration(labelText: 'Kërko brenda librit', prefixIcon: const Icon(Icons.search), suffixText: '${matches.length}'))),
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
        IconButton(tooltip: 'Gjetja e mëparshme', onPressed: matches.isEmpty ? null : () => _jump(matches.lastWhere((i) => i < current, orElse: () => matches.last)), icon: const Icon(Icons.navigate_before)),
        Text('${paragraphs.isEmpty ? 0 : current + 1}/${paragraphs.length}'),
        IconButton(tooltip: 'Gjetja tjetër', onPressed: matches.isEmpty ? null : () => _jump(matches.firstWhere((i) => i > current, orElse: () => matches.first)), icon: const Icon(Icons.navigate_next)),
        IconButton(tooltip: 'Shënues', onPressed: () { setState(() => bookmarks.contains(current) ? bookmarks.remove(current) : bookmarks.add(current)); _save(); }, icon: Icon(bookmarks.contains(current) ? Icons.bookmark : Icons.bookmark_border)),
        IconButton(tooltip: 'Shënim personal', onPressed: _note, icon: const Icon(Icons.edit_note)),
        PopupMenuButton<String>(tooltip: 'AI për pjesën e zgjedhur', enabled: !aiBusy, onSelected: _ai, itemBuilder: (_) => const [PopupMenuItem(value: 'translate', child: Text('Përkthe pjesën')), PopupMenuItem(value: 'explain', child: Text('Shpjego pjesën'))]),
      ]),
      if (aiBusy) const LinearProgressIndicator(),
      Row(children: [IconButton(tooltip: speaking || speechStarting ? 'Ndalo' : 'Lexo me zë nga kjo pjesë', onPressed: _toggleSpeech, icon: Icon(speaking || speechStarting ? Icons.stop_circle : Icons.volume_up)), DropdownButton<String>(value: language, onChanged: speaking || speechStarting ? null : (v) => setState(() => language = v!), items: const [DropdownMenuItem(value: 'sq-AL', child: Text('SQ')), DropdownMenuItem(value: 'de-DE', child: Text('DE')), DropdownMenuItem(value: 'en-US', child: Text('EN')), DropdownMenuItem(value: 'ar', child: Text('AR')), DropdownMenuItem(value: 'tr-TR', child: Text('TR'))]), Expanded(child: Slider(value: speechRate, min: .2, max: .8, onChanged: (v) { setState(() => speechRate = v); _tts.setSpeechRate(v); }))]),
      Expanded(child: SelectionArea(child: SingleChildScrollView(controller: scroll, padding: const EdgeInsets.all(20), child: Column(children: [for (var i = 0; i < paragraphs.length; i++) GestureDetector(key: keys[i], onTap: () { if (!speaking) _jump(i); }, child: Container(width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: current == i ? panel : Colors.transparent, borderRadius: BorderRadius.circular(12), border: current == i ? Border.all(color: gold.withValues(alpha: .4)) : null), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_text(i), if ((notes['$i'] ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(notes['$i']!, style: const TextStyle(color: gold, fontSize: 13)))])))]))))
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
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Biblioteka ime')), body: loading ? const Center(child: CircularProgressIndicator()) : content.trim().isEmpty && importedText.trim().isEmpty && libraryBooks.isEmpty ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Nuk ka ende draft të ruajtur. Shkruaj librin tënd dhe ruaje.'))) : ListView(padding: const EdgeInsets.all(20), children: [TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Kërko librin', border: OutlineInputBorder()), onChanged: (value) => setState(() => searchQuery = value.trim().toLowerCase())), const SizedBox(height: 12), for (final book in libraryBooks.where((book) => (book['title'] as String? ?? '').toLowerCase().contains(searchQuery))) BookCard(key: ValueKey(book['title']), title: book['title'] as String? ?? 'Libër', onDelete: () => _deleteBook(book['title'] as String? ?? ''), onOpen: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _TextReaderPage(title: book['title'] as String? ?? 'Libër', content: book['content'] as String? ?? '')))), if (libraryBooks.isEmpty && importedText.trim().isNotEmpty && importedTitle.toLowerCase().contains(searchQuery)) Card(child: ListTile(title: Text(importedTitle.isEmpty ? 'Libri i importuar' : importedTitle), subtitle: const Text('TXT/Markdown • ruajtur në telefon'), onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _TextReaderPage(title: importedTitle, content: importedText))))), if (content.trim().isNotEmpty && (title.trim().isEmpty ? 'Libri im' : title).toLowerCase().contains(searchQuery)) Card(child: ListTile(title: Text(title.trim().isEmpty ? 'Libri im' : title), subtitle: const Text('Draft lokal • lexim'), onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _TextReaderPage(title: title.trim().isEmpty ? 'Libri im' : title, content: content)))))]));
}
