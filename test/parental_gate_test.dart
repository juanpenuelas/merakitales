import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/components/parental_gate.dart';

void main() {
  testWidgets('ParentalGate.verify shows dialog, localized in English by default, returns true on correct answer', (WidgetTester tester) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [
          Locale('en'),
          Locale('es'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await ParentalGate.verify(context);
                },
                child: const Text('Verify'),
              );
            },
          ),
        ),
      ),
    );

    // Tap verify button to launch parental gate dialog
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    // Verify dialog is shown
    expect(find.byType(AlertDialog), findsOneWidget);

    // Get the dialog content text to find the numbers
    final textWidgetFinder = find.byWidgetPredicate((widget) =>
        widget is Text && RegExp(r'\d+\s*x\s*\d+').hasMatch(widget.data ?? ''));
    expect(textWidgetFinder, findsOneWidget);
    
    final textWidget = tester.widget<Text>(textWidgetFinder);
    final textContent = textWidget.data ?? '';
    
    // Parse the numbers X and Y from the question
    final match = RegExp(r'(\d+)\s*x\s*(\d+)').firstMatch(textContent);
    expect(match, isNotNull);
    final x = int.parse(match!.group(1)!);
    final y = int.parse(match.group(2)!);
    final correctAnswer = (x * y).toString();

    // Verify it is in English
    expect(textContent.contains('Adults only') || textContent.contains('parent'), true);

    // Enter correct answer in TextField
    await tester.enterText(find.byType(TextField), correctAnswer);
    await tester.pump();

    // Tap submit button
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    // Dialog should be dismissed and result should be true
    expect(find.byType(AlertDialog), findsNothing);
    expect(result, true);
  });

  testWidgets('ParentalGate.verify returns false on incorrect answer', (WidgetTester tester) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: const [
          Locale('en'),
          Locale('es'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await ParentalGate.verify(context);
                },
                child: const Text('Verify'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    // Enter incorrect answer
    await tester.enterText(find.byType(TextField), '999');
    await tester.pump();

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(result, false);
  });

  testWidgets('ParentalGate.verify returns false on cancel', (WidgetTester tester) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: const [
          Locale('en'),
          Locale('es'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await ParentalGate.verify(context);
                },
                child: const Text('Verify'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    // Tap cancel button
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(result, false);
  });

  testWidgets('ParentalGate.verify is localized in Spanish when locale is es', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: const [
          Locale('en'),
          Locale('es'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  ParentalGate.verify(context);
                },
                child: const Text('Verify'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    final textWidgetFinder = find.byWidgetPredicate((widget) =>
        widget is Text && RegExp(r'\d+\s*x\s*\d+').hasMatch(widget.data ?? ''));
    expect(textWidgetFinder, findsOneWidget);
    
    final textWidget = tester.widget<Text>(textWidgetFinder);
    final textContent = textWidget.data ?? '';

    // Verify it is in Spanish
    expect(textContent.contains('Pregunta para adultos'), true);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Enviar'), findsOneWidget);
  });
}
