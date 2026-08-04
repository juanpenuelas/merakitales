import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/components/subscription_legal_links.dart';

/// Guideline 3.1.2(c): el flujo de suscripcion tiene que llevar enlaces
/// funcionales a privacidad y a los terminos (EULA). Si estos se rompen,
/// Apple rechaza la version.
Widget _wrap(Widget child, Locale locale) => MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );

void main() {
  test('cada idioma apunta a su pagina legal publicada', () {
    const base = 'https://merakitales-5rltbl.web.app';

    expect(
      SubscriptionLegalLinks.urlFor(isSpanish: true, page: 'privacy.html'),
      '$base/privacy.html',
    );
    expect(
      SubscriptionLegalLinks.urlFor(isSpanish: true, page: 'terms.html'),
      '$base/terms.html',
    );
    expect(
      SubscriptionLegalLinks.urlFor(isSpanish: false, page: 'privacy.html'),
      '$base/en/privacy.html',
    );
    expect(
      SubscriptionLegalLinks.urlFor(isSpanish: false, page: 'terms.html'),
      '$base/en/terms.html',
    );
  });

  testWidgets('muestra los dos enlaces en espanol', (tester) async {
    await tester.pumpWidget(
      _wrap(const SubscriptionLegalLinks(isSpanish: true), const Locale('es')),
    );

    expect(find.text('Política de privacidad'), findsOneWidget);
    expect(find.text('Términos de uso (EULA)'), findsOneWidget);
  });

  testWidgets('muestra los dos enlaces en ingles', (tester) async {
    await tester.pumpWidget(
      _wrap(const SubscriptionLegalLinks(isSpanish: false), const Locale('en')),
    );

    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Use (EULA)'), findsOneWidget);
  });

  testWidgets('tocar un enlace abre antes el parental gate', (tester) async {
    await tester.pumpWidget(
      _wrap(const SubscriptionLegalLinks(isSpanish: true), const Locale('es')),
    );

    await tester.tap(find.text('Términos de uso (EULA)'));
    await tester.pumpAndSettle();

    // Guideline 1.3: en categoria Kids no se sale de la app sin permiso adulto.
    expect(find.text('Solo para adultos'), findsOneWidget);
  });
}
