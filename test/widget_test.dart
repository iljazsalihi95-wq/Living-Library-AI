import 'package:flutter_test/flutter_test.dart';
import 'package:living_library_ai/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Home opens and My Library navigates to saved drafts', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const LibraryApp());

    expect(find.byType(LibraryHome), findsOneWidget);
    expect(find.text('Krijo një libër'), findsOneWidget);

    await tester.ensureVisible(find.text('Biblioteka ime'));
    await tester.tap(find.text('Biblioteka ime'));
    await tester.pumpAndSettle();

    expect(find.text('Biblioteka ime'), findsWidgets);
    expect(find.textContaining('Nuk ka ende draft të ruajtur'), findsOneWidget);
  });
}
