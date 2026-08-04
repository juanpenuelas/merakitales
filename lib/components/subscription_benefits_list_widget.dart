import 'package:flutter/material.dart';

class SubscriptionBenefitsListWidget extends StatelessWidget {
  const SubscriptionBenefitsListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isSpanish = Localizations.localeOf(context).languageCode == 'es';
    // Solo lo que la app hace de verdad: "modo offline" nunca existio y ya no
    // hay anuncios que quitar.
    final benefits = isSpanish
        ? const ['Acceso a todos los cuentos', 'Apoyas a Abuela Meraki']
        : const ['Access to every story', 'You support Abuela Meraki'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: benefits.map((benefit) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                benefit,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
