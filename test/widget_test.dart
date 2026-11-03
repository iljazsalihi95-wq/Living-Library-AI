import 'package:flutter_test/flutter_test.dart';
import 'package:living_library_ai/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Premium home opens and My Library navigates to saved drafts', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const LibraryApp());
    await tester.pumpAndSettle();

    expect(find.byType(LibraryHome), findsOneWidget);
    expect(find.text('Living Library AI'), findsOneWidget);
    expect(find.text('Tregimi pilot'), findsOneWidget);

    final myLibrary = find.text('Biblioteka ime');
    expect(myLibrary, findsOneWidget);
    await tester.tap(myLibrary);
    await tester.pumpAndSettle();

    expect(find.text('Biblioteka ime'), findsWidgets);
    expect(find.textContaining('Nuk ka ende draft të ruajtur'), findsOneWidget);
  });
}
