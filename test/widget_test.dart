import 'package:flutter_test/flutter_test.dart';
import 'package:living_library_ai/main.dart';

void main() {
  testWidgets('Home opens and inactive library card explains status', (tester) async {
    await tester.pumpWidget(const LibraryApp());
    expect(find.byType(LibraryHome), findsOneWidget);
    expect(find.text('Krijo një libër'), findsOneWidget);
    await tester.tap(find.text('Biblioteka ime'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ky modul është në zhvillim'), findsOneWidget);
    await tester.tap(find.text('Mbyll'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ky modul është në zhvillim'), findsNothing);
  });
}
