import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/components/subscription_hero_card_widget.dart';

void main() {
  testWidgets('SubscriptionHeroCardWidget shows Premium info when isPremium is true', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
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

  testWidgets('SubscriptionHeroCardWidget shows Plan Gratuito info when isPremium is false', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
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

  testWidgets('SubscriptionHeroCardWidget shows Premium info without expirationDate when isPremium is true but expirationDate is null', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
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
