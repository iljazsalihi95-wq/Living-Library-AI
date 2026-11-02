import 'package:flutter/material.dart';
void main() => runApp(const StudioApp());
class StudioApp extends StatelessWidget {
  const StudioApp({super.key});
  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE5BB69);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Living Library AI',
      theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF0C1728), colorScheme: ColorScheme.fromSeed(seedColor: gold, brightness: Brightness.dark), useMaterial3: true),
      home: const HomePage(),
    );
  }
}
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE5BB69);
    return Scaffold(
      appBar: AppBar(title: const Text('Living Library AI'), backgroundColor: Colors.transparent),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        const Icon(Icons.auto_stories_outlined, size: 84, color: gold),
        const SizedBox(height: 20),
        Text('Biblioteka jote interaktive', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        const Text('Libra • Audio • Shpjegime AI', textAlign: TextAlign.center),
        const SizedBox(height: 30),
        const _FeatureTile(icon: Icons.add_photo_alternate_outlined, title: 'Krijo libër', subtitle: 'Fotografi, PDF dhe dokumente'),
        const _FeatureTile(icon: Icons.menu_book, title: 'Lexuesi', subtitle: 'Faqe, shënime dhe përmbajtje'),
        const _FeatureTile(icon: Icons.record_voice_over, title: 'Audio & AI', subtitle: 'Lexim dhe shpjegime'),
        const SizedBox(height: 20),
        const Text('Versioni 0.1 — ndërfaqe fillestare; funksionet AI nuk janë lidhur ende.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
      ])),
    );
  }
}
class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF17263B),
    margin: const EdgeInsets.symmetric(vertical: 7),
    child: ListTile(leading: Icon(icon, color: const Color(0xFFE5BB69)), title: Text(title), subtitle: Text(subtitle)),
  );
}
