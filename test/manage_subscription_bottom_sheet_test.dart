import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/components/manage_subscription_bottom_sheet.dart';

void main() {
  testWidgets('ManageSubscriptionBottomSheet displays correctly and handles tap', (WidgetTester tester) async {
    bool cancelPressed = false;
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ManageSubscriptionBottomSheet(
            onCancelPressed: () {
              cancelPressed = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Gestionar Suscripción'), findsOneWidget);
    expect(find.textContaining('perderás tu acceso a historias ilimitadas'), findsOneWidget);
    expect(find.text('Entendido, cancelar de todos modos'), findsOneWidget);

    await tester.tap(find.text('Entendido, cancelar de todos modos'));
    await tester.pumpAndSettle();
    
    expect(cancelPressed, isTrue);
  });
}
