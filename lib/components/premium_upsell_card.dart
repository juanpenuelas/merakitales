import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/pages/subscription_page/subscription_page_widget.dart';

/// Tarjeta "Hazte Premium" de la home. Solo se pinta para usuarios
/// gratuitos (decide quien la usa). Lleva a la pagina de suscripcion.
class PremiumUpsellCard extends StatelessWidget {
  const PremiumUpsellCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isSpanish = Localizations.localeOf(context).languageCode == 'es';
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16.0, 10.0, 16.0, 4.0),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SubscriptionPageWidget(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2D5A3D), Color(0xFF1E4030)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Row(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 22.0)),
              const SizedBox(width: 10.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSpanish ? 'Hazte Premium' : 'Go Premium',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isSpanish
                          ? 'Todos los cuentos, con audio y sin anuncios'
                          : 'Every tale, with audio and no ads',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 11.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10.0, vertical: 6.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8B04B),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  isSpanish ? 'VER' : 'VIEW',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF2D3A2E),
                    fontSize: 11.0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
