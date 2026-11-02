import 'package:flutter_test/flutter_test.dart';
import 'package:living_library_ai/main.dart';

void main() {
  testWidgets('Home opens and My Library navigates to saved drafts', (tester) async {
    await tester.pumpWidget(const LibraryApp());
    expect(find.byType(LibraryHome), findsOneWidget);
    expect(find.text('Krijo një libër'), findsOneWidget);

    await tester.tap(find.text('Biblioteka ime'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Biblioteka ime'), findsWidgets);
    expect(
      find.textContaining('Nuk ka ende draft të ruajtur'),
      findsOneWidget,
    );
  });
}
