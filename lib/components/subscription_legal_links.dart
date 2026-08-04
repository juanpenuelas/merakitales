import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:merakitales/components/parental_gate.dart';

/// Enlaces a privacidad y terminos que la guideline 3.1.2(c) exige dentro del
/// propio flujo de suscripcion, no solo en la ficha de la App Store.
///
/// Pasan por el parental gate porque la app esta en categoria Kids y abrir algo
/// fuera de la app necesita permiso de un adulto (guideline 1.3).
class SubscriptionLegalLinks extends StatelessWidget {
  const SubscriptionLegalLinks({
    super.key,
    required this.isSpanish,
    this.color,
  });

  final bool isSpanish;
  final Color? color;

  static const String _base = 'https://merakitales-5rltbl.web.app';

  static String urlFor({required bool isSpanish, required String page}) =>
      isSpanish ? '$_base/$page' : '$_base/en/$page';

  Future<void> _open(BuildContext context, String page) async {
    if (!await ParentalGate.verify(context)) return;
    await launchUrl(Uri.parse(urlFor(isSpanish: isSpanish, page: page)));
  }

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.readexPro(
      color: color ?? Theme.of(context).colorScheme.primary,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      decoration: TextDecoration.underline,
      decorationColor: color ?? Theme.of(context).colorScheme.primary,
    );

    Widget link(String label, String page) => InkWell(
          onTap: () => _open(context, page),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(label, style: style),
          ),
        );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        link(
          isSpanish ? 'Política de privacidad' : 'Privacy Policy',
          'privacy.html',
        ),
        Text('·', style: style.copyWith(decoration: TextDecoration.none)),
        link(
          isSpanish ? 'Términos de uso (EULA)' : 'Terms of Use (EULA)',
          'terms.html',
        ),
      ],
    );
  }
}
