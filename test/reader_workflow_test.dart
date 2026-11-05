import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:living_library_ai/main.dart';
import 'package:living_library_ai/features/ai_film/story_studio.dart';
void main() {
  testWidgets('stored book opens and personal note persists', (tester) async {
    SharedPreferences.setMockInitialValues({'library_books_v1': jsonEncode([{'title':'Test book','content':'## Kapitulli 1\n\nTeksti i librit për lexim.'}])});
    await tester.pumpWidget(const LibraryApp()); await tester.pumpAndSettle();
    await tester.tap(find.text('Biblioteka').last); await tester.pumpAndSettle();
    await tester.tap(find.text('Test book')); await tester.pumpAndSettle();
    expect(find.text('## Kapitulli 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Shënim personal')); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Shënimi im');
    await tester.tap(find.text('Ruaj')); await tester.pumpAndSettle();
    expect(find.text('Shënimi im'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    final key = 'reader_v2_${base64Url.encode(utf8.encode('Test book'))}';
    expect(prefs.getString(key), contains('Shënimi im'));
  });
  testWidgets('studio builds editable scenes from any supplied story', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: StoryStudio(initialTitle:'New story', initialText:'First scene.\n\nSecond scene.')));
    await tester.pumpAndSettle();
    expect(find.text('Skena 1'),findsOneWidget); expect(find.text('Skena 2'),findsOneWidget);
    await tester.tap(find.byTooltip('Ruaj')); await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('story_studio_v1'), contains('Second scene.'));
  });
}
