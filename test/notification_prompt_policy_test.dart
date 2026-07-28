import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:merakitales/services/notification_prompt_policy.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('sin historial: no ofrece en la 1a apertura, si al volver de la 2a',
      () async {
    final policy = NotificationPromptPolicy();

    await policy.recordTaleOpen();
    expect(await policy.shouldOfferNow(), isFalse);

    await policy.recordTaleOpen();
    expect(await policy.shouldOfferNow(), isTrue);
  });

  test('"Ahora no": siguiente oferta exactamente 5 aperturas despues',
      () async {
    final policy = NotificationPromptPolicy();

    await policy.recordTaleOpen();
    await policy.recordTaleOpen();
    expect(await policy.shouldOfferNow(), isTrue);
    await policy.recordOfferShown(); // "Ahora no"

    for (var i = 3; i <= 6; i++) {
      await policy.recordTaleOpen();
      expect(await policy.shouldOfferNow(), isFalse,
          reason: 'no deberia ofrecer todavia en la apertura $i');
    }

    await policy.recordTaleOpen(); // 7a apertura: 2 + 5
    expect(await policy.shouldOfferNow(), isTrue);
  });

  test('tope: tras 3 ofertas rechazadas, nunca mas', () async {
    final policy = NotificationPromptPolicy();

    // Oferta 1 en la apertura 2.
    await policy.recordTaleOpen();
    await policy.recordTaleOpen();
    expect(await policy.shouldOfferNow(), isTrue);
    await policy.recordOfferShown();

    // Oferta 2 en la apertura 7 (2 + 5).
    for (var i = 0; i < 5; i++) {
      await policy.recordTaleOpen();
    }
    expect(await policy.shouldOfferNow(), isTrue);
    await policy.recordOfferShown();

    // Oferta 3 en la apertura 12 (7 + 5).
    for (var i = 0; i < 5; i++) {
      await policy.recordTaleOpen();
    }
    expect(await policy.shouldOfferNow(), isTrue);
    await policy.recordOfferShown();

    // Tope alcanzado: aunque pasen otras 5 aperturas (apertura 17), silencio.
    for (var i = 0; i < 5; i++) {
      await policy.recordTaleOpen();
    }
    expect(await policy.shouldOfferNow(), isFalse);
  });

  test('markDone: no ofrece aunque queden ofertas disponibles', () async {
    final policy = NotificationPromptPolicy();

    await policy.recordTaleOpen();
    await policy.recordTaleOpen();
    expect(await policy.shouldOfferNow(), isTrue);

    await policy.markDone();

    expect(await policy.shouldOfferNow(), isFalse);
    expect(await policy.isDone(), isTrue);
  });

  test('los contadores persisten entre instancias del servicio (misma prefs)',
      () async {
    final policyA = NotificationPromptPolicy();
    await policyA.recordTaleOpen();
    await policyA.recordTaleOpen();

    final policyB = NotificationPromptPolicy();
    expect(await policyB.shouldOfferNow(), isTrue);

    await policyB.recordOfferShown();

    final policyC = NotificationPromptPolicy();
    expect(await policyC.isDone(), isFalse);
    expect(await policyC.shouldOfferNow(), isFalse);
  });
}
