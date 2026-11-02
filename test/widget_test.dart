import 'package:flutter_test/flutter_test.dart';
import 'package:living_library_ai/main.dart';

void main() {
  testWidgets('Living Library opens', (tester) async {
    await tester.pumpWidget(const LibraryApp());
    expect(find.byType(LibraryHome), findsOneWidget);
    expect(find.text('LIVING LIBRARY'), findsOneWidget);
    expect(find.text('Krijo një libër'), findsOneWidget);
  });
}
