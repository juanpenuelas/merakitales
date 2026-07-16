import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/components/subscription_benefits_list_widget.dart';

void main() {
  testWidgets('SubscriptionBenefitsListWidget displays benefits with checkmarks', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SubscriptionBenefitsListWidget(),
      ),
    ));

    expect(find.text('Historias ilimitadas'), findsOneWidget);
    expect(find.text('Modo offline'), findsOneWidget);
    expect(find.text('Sin anuncios'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
  });
}
