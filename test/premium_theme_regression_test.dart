import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_library_ai/main.dart';

void main() {
  testWidgets('Premium library theme keeps its original emerald and gold palette', (tester) async {
    await tester.pumpWidget(const LibraryApp());
    final theme = Theme.of(tester.element(find.byType(Scaffold).first));
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF071B17));
    expect(theme.appBarTheme.foregroundColor, const Color(0xFFE2BE72));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
