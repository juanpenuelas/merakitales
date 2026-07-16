import 'package:flutter/material.dart';

class SubscriptionBenefitsListWidget extends StatelessWidget {
  const SubscriptionBenefitsListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    const benefits = [
      'Historias ilimitadas',
      'Modo offline',
      'Sin anuncios',
    ];

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
