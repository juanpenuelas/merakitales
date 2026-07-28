import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/flutter_flow/flutter_flow_theme.dart';

/// Pre-dialogo propio de la app, mostrado antes del prompt del sistema.
/// Widget tonto: solo pinta y devuelve la eleccion del usuario via
/// Navigator.pop (patron showDialog<bool>).
class NotificationOfferDialog extends StatelessWidget {
  const NotificationOfferDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final isSpanish = Localizations.localeOf(context).languageCode == 'es';
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔔', style: TextStyle(fontSize: 40.0)),
          const SizedBox(height: 12.0),
          Text(
            isSpanish
                ? '¿Te avisamos cuando publiquemos un cuento nuevo?'
                : 'Want a nudge when a new tale arrives?',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18.0,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: Text(
        isSpanish
            ? 'Solo cuentos nuevos. Nada de ruido.'
            : 'New tales only. No noise.',
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14.0,
          color: FlutterFlowTheme.of(context).secondaryText,
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            isSpanish ? 'Ahora no' : 'Not now',
            style: GoogleFonts.plusJakartaSans(
                color: FlutterFlowTheme.of(context).secondaryText),
          ),
        ),
        FilledButton(
          style:
              FilledButton.styleFrom(backgroundColor: const Color(0xFF2D5A3D)),
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            isSpanish ? 'Sí, avísame' : 'Yes, tell me',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
