import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const LibraryApp());
class LibraryApp extends StatelessWidget { const LibraryApp({super.key}); @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,title:'Living Library AI',theme:ThemeData(brightness:Brightness.dark,scaffoldBackgroundColor:const Color(0xFF071B17),colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFFDDBB70),brightness:Brightness.dark),useMaterial3:true),home:const LibraryHome()); }
class LibraryHome extends StatefulWidget { const LibraryHome({super.key}); @override State<LibraryHome> createState()=>_LibraryHomeState(); }
class _LibraryHomeState extends State<LibraryHome> {
 String? selectedBook;
 Future<void> _import() async { try { final files=await FilePicker.pickFiles(type:FileType.custom,allowedExtensions:['pdf','epub','txt','jpg','jpeg','png']); if(!mounted||files.isEmpty)return; final file=files.single; setState(()=>selectedBook=file.name); if(file.extension?.toLowerCase()=='txt'){final bytes=await file.readAsBytes();final content=utf8.decode(bytes,allowMalformed:true);if(!mounted)return;await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>_TextReaderPage(title:file.name,content:content)));return;} if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Skedari u zgjodh: $selectedBook. Importi i këtij formati është në zhvillim.'))); } catch(_){if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Skedari nuk mund të zgjidhej. Provo përsëri.')));} }
 @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(20,18,20,28),children:[const _Header(),const SizedBox(height:30),Text('Biblioteka që lexon me ty.',style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w700)),const SizedBox(height:8),const Text('Shto dokumente nga telefoni dhe ndërto bibliotekën personale pa i dërguar në cloud.',style:TextStyle(color:Color(0xFFB7C9C1),height:1.45)),const SizedBox(height:25),_Shelf(icon:Icons.add_photo_alternate_outlined,title:'Krijo një libër',subtitle:selectedBook??'PDF • EPUB • tekst • imazhe',accent:true,onTap:_import),_Shelf(icon:Icons.edit_note_outlined,title:'Shkruaj librin tim',subtitle:'Krijo faqe dhe shkruaj tekstin tënd',onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const _WritingPage()))),const _Shelf(icon:Icons.mic_none_outlined,title:'Leximi me zërin tim',subtitle:'Regjistrim audio — në përgatitje'),_Shelf(icon:Icons.auto_stories_outlined,title:'Biblioteka ime',subtitle:'Hap draftin e ruajtur në telefon',onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const _SavedDraftPage()))),const _Shelf(icon:Icons.headphones_outlined,title:'Lexim me zë',subtitle:'Audio dhe ndjekje e tekstit'),const _Shelf(icon:Icons.psychology_alt_outlined,title:'Nuk e kuptoj',subtitle:'Shpjegime AI — lidhja vjen më pas'),const _Shelf(icon:Icons.bookmark_outline,title:'Shënime & faqeshënues',subtitle:'Ruaj pjesët që të duhen'),const SizedBox(height:18),const _Privacy()]))); }
class _Header extends StatelessWidget { const _Header(); @override Widget build(BuildContext context)=>const Row(children:[_BookMark(),SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('LIVING LIBRARY',style:TextStyle(fontWeight:FontWeight.w800,letterSpacing:1.5,fontSize:17)),SizedBox(height:3),Text('YOUR BOOKS • ALIVE',style:TextStyle(color:Color(0xFFDDBB70),fontSize:11,letterSpacing:1.2))]))]); }
class _BookMark extends StatelessWidget { const _BookMark(); @override Widget build(BuildContext context)=>Container(width:58,height:58,decoration:BoxDecoration(borderRadius:BorderRadius.circular(16),gradient:const LinearGradient(colors:[Color(0xFF17483B),Color(0xFF0B2B24)]),border:Border.all(color:const Color(0xFFDDBB70),width:1.2)),child:const Stack(alignment:Alignment.center,children:[Icon(Icons.menu_book_rounded,color:Color(0xFFDDBB70),size:35),Positioned(top:8,right:9,child:Icon(Icons.auto_awesome,size:12))])); }
class _Shelf extends StatelessWidget { const _Shelf({required this.icon,required this.title,required this.subtitle,this.accent=false,this.onTap}); final IconData icon;final String title,subtitle;final bool accent;final VoidCallback? onTap;@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:12),child:Material(color:accent?const Color(0xFF123B31):const Color(0xFF0D2A24),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18),side:BorderSide(color:accent?const Color(0xFFDDBB70).withValues(alpha:.65):const Color(0xFF235044))),clipBehavior:Clip.antiAlias,child:ListTile(onTap:onTap??()=>_showStatus(context),contentPadding:const EdgeInsets.symmetric(horizontal:18,vertical:8),leading:Container(width:44,height:44,decoration:BoxDecoration(color:const Color(0xFFDDBB70).withValues(alpha:.10),borderRadius:BorderRadius.circular(13)),child:Icon(icon,color:const Color(0xFFDDBB70))),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text(subtitle,style:const TextStyle(color:Color(0xFF9DB4AA))),trailing:const Icon(Icons.chevron_right,color:Color(0xFFDDBB70)))));void _showStatus(BuildContext context)=>showModalBottomSheet<void>(context:context,showDragHandle:true,builder:(c)=>SafeArea(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:Theme.of(context).textTheme.headlineSmall),const SizedBox(height:12),Text(subtitle),const SizedBox(height:18),const Text('Ky modul është në zhvillim.',style:TextStyle(color:Colors.grey)),const SizedBox(height:18),FilledButton(onPressed:()=>Navigator.pop(c),child:const Text('Mbyll'))])))); }
class _Privacy extends StatelessWidget { const _Privacy();@override Widget build(BuildContext context)=>const Row(children:[Icon(Icons.lock_outline,size:17,color:Color(0xFF829B91)),SizedBox(width:8),Expanded(child:Text('Import lokal • pa kredenciale AI/OCR',style:TextStyle(color:Color(0xFF829B91),fontSize:12)))]); }
class _WritingPage extends StatefulWidget { const _WritingPage();@override State<_WritingPage> createState()=>_WritingPageState(); }
class _WritingPageState extends State<_WritingPage>{final titleController=TextEditingController();final textController=TextEditingController();@override void initState(){super.initState();_loadDraft();}Future<void> _loadDraft()async{final prefs=await SharedPreferences.getInstance();if(!mounted)return;titleController.text=prefs.getString('book_draft_title')??'';textController.text=prefs.getString('book_draft_text')??'';}Future<void> _saveDraft()async{final prefs=await SharedPreferences.getInstance();await prefs.setString('book_draft_title',titleController.text);await prefs.setString('book_draft_text',textController.text);if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Drafti u ruajt në këtë pajisje.')));}@override void dispose(){titleController.dispose();textController.dispose();super.dispose();}@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Shkruaj librin tim')),body:SafeArea(child:Padding(padding:const EdgeInsets.all(20),child:Column(children:[TextField(controller:titleController,textCapitalization:TextCapitalization.sentences,decoration:const InputDecoration(labelText:'Titulli i librit',border:OutlineInputBorder())),const SizedBox(height:16),Expanded(child:TextField(controller:textController,expands:true,maxLines:null,minLines:null,textAlignVertical:TextAlignVertical.top,keyboardType:TextInputType.multiline,decoration:const InputDecoration(labelText:'Shkruaj tekstin e librit',alignLabelWithHint:true,border:OutlineInputBorder()))),const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:_saveDraft,icon:const Icon(Icons.save_outlined),label:const Text('Ruaj draftin në telefon'))),const SizedBox(height:8),const Text('Drafti ruhet lokalisht. Biblioteka me shumë libra dhe eksportimi janë ende në zhvillim.',style:TextStyle(color:Colors.grey))]))));}
class _TextReaderPage extends StatefulWidget{const _TextReaderPage({required this.title,required this.content});final String title,content;@override State<_TextReaderPage> createState()=>_TextReaderPageState();}
class _TextReaderPageState extends State<_TextReaderPage>{double fontSize=18;@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.title),actions:[IconButton(tooltip:'Zvogëlo tekstin',icon:const Icon(Icons.text_decrease),onPressed:()=>setState(()=>fontSize=(fontSize-2).clamp(14.0,32.0))),IconButton(tooltip:'Zmadho tekstin',icon:const Icon(Icons.text_increase),onPressed:()=>setState(()=>fontSize=(fontSize+2).clamp(14.0,32.0)))]),body:SafeArea(child:SelectionArea(child:ListView(padding:const EdgeInsets.all(24),children:[Text(widget.content,style:TextStyle(fontSize:fontSize,height:1.65))]))));}

class _SavedDraftPage extends StatefulWidget {
  const _SavedDraftPage();
  @override
  State<_SavedDraftPage> createState() => _SavedDraftPageState();
}
class _SavedDraftPageState extends State<_SavedDraftPage> {
  String title = '';
  String content = '';
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      title = prefs.getString('book_draft_title') ?? '';
      content = prefs.getString('book_draft_text') ?? '';
      loading = false;
    });
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Biblioteka ime')),
    body: loading
      ? const Center(child: CircularProgressIndicator())
      : content.trim().isEmpty
        ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Nuk ka ende draft të ruajtur. Shkruaj librin tënd dhe ruaje.')))
        : ListView(padding: const EdgeInsets.all(20), children: [
            Card(child: ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(title.trim().isEmpty ? 'Libri im' : title),
              subtitle: const Text('Draft lokal • lexim'),
              onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                builder: (_) => _TextReaderPage(title: title.trim().isEmpty ? 'Libri im' : title, content: content),
              )),
            )),
          ]),
  );
}
