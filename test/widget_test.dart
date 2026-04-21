import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Basic app shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('SmartChama'),
        ),
      ),
    );
    expect(find.text('SmartChama'), findsOneWidget);
  });
}
