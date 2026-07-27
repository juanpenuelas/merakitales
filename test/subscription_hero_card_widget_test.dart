import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/components/subscription_hero_card_widget.dart';

void main() {
  testWidgets('SubscriptionHeroCardWidget shows Premium info when isPremium is true',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('es'),
        supportedLocales: [Locale('es'), Locale('en')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SubscriptionHeroCardWidget(
            isPremium: true,
            expirationDate: '15/08/2026',
          ),
        ),
      ),
    );

    expect(find.text('Suscripción Premium Activa'), findsOneWidget);
    expect(find.text('Se renueva el 15/08/2026'), findsOneWidget);
    expect(find.byIcon(Icons.workspace_premium), findsOneWidget);
  });

  // El bug que motiva este test: los textos premium estaban escritos a fuego en
  // espanol y no cambiaban con el idioma. Un solo caso en ingles demuestra que
  // el mecanismo funciona; los ternarios de los demas widgets son identicos.
  testWidgets('SubscriptionHeroCardWidget renders English copy under an English locale',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        supportedLocales: [Locale('es'), Locale('en')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SubscriptionHeroCardWidget(
            isPremium: true,
            expirationDate: '15/08/2026',
          ),
        ),
      ),
    );

    expect(find.text('Premium Subscription Active'), findsOneWidget);
    expect(find.text('Renews on 15/08/2026'), findsOneWidget);
    expect(find.text('Suscripción Premium Activa'), findsNothing);
  });

  testWidgets('SubscriptionHeroCardWidget shows Plan Gratuito info when isPremium is false',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('es'),
        supportedLocales: [Locale('es'), Locale('en')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SubscriptionHeroCardWidget(
            isPremium: false,
          ),
        ),
      ),
    );

    expect(find.text('Plan Gratuito'), findsOneWidget);
    expect(find.byIcon(Icons.stars_outlined), findsOneWidget);
  });

  testWidgets(
      'SubscriptionHeroCardWidget shows Premium info without expirationDate when isPremium is true but expirationDate is null',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('es'),
        supportedLocales: [Locale('es'), Locale('en')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SubscriptionHeroCardWidget(
            isPremium: true,
          ),
        ),
      ),
    );

    expect(find.text('Suscripción Premium Activa'), findsOneWidget);
    expect(find.byIcon(Icons.workspace_premium), findsOneWidget);
    expect(find.textContaining('Se renueva el'), findsNothing);
  });
}
