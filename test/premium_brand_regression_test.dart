import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_library_ai/main.dart';

void main() {
  testWidgets('Premium dark branding remains consistent on Android', (tester) async {
    await tester.pumpWidget(const LibraryApp());
    final context = tester.element(find.byType(Scaffold).first);
    final theme = Theme.of(context);

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF071B17));
    expect(theme.colorScheme.primary, isNot(equals(Colors.blue)));
    expect(theme.appBarTheme.foregroundColor, const Color(0xFFE2BE72));
    expect(theme.useMaterial3, isTrue);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
