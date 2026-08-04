import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/components/subscription_benefits_list_widget.dart';

void main() {
  testWidgets('SubscriptionBenefitsListWidget displays benefits with checkmarks',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('es'),
      supportedLocales: [Locale('es'), Locale('en')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: SubscriptionBenefitsListWidget(),
      ),
    ));

    expect(find.text('Acceso a todos los cuentos'), findsOneWidget);
    expect(find.text('Apoyas a Abuela Meraki'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));

    // Guideline 2.3.1: nada de prometer lo que la app no hace. El modo offline
    // nunca existio y la publicidad ya no existe.
    expect(find.textContaining('offline'), findsNothing);
    expect(find.textContaining('anuncios'), findsNothing);
  });
}
