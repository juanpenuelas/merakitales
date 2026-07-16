import 'package:flutter/material.dart';

class SubscriptionHeroCardWidget extends StatelessWidget {
  final bool isPremium;
  final String? expirationDate;

  const SubscriptionHeroCardWidget({
    super.key,
    required this.isPremium,
    this.expirationDate,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isPremium ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10.0,
            offset: Offset(0, 4),
          ),
        ],
        gradient: LinearGradient(
          colors: isPremium
              ? [const Color(0xFF1E1B4B), const Color(0xFF7C3AED)]
              : [Colors.grey.shade400, Colors.grey.shade300],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPremium ? Icons.workspace_premium : Icons.stars_outlined,
            color: textColor,
            size: 48.0,
          ),
          const SizedBox(height: 16.0),
          Text(
            isPremium ? 'Suscripción Premium Activa' : 'Plan Gratuito',
            style: TextStyle(
              color: textColor,
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (isPremium && expirationDate != null) ...[
            const SizedBox(height: 8.0),
            Text(
              'Se renueva el $expirationDate',
              style: TextStyle(
                color: textColor.withOpacity(0.9),
                fontSize: 14.0,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
