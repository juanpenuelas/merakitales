import 'package:flutter/material.dart';

class ManageSubscriptionBottomSheet extends StatelessWidget {
  final VoidCallback onCancelPressed;

  const ManageSubscriptionBottomSheet({
    super.key,
    required this.onCancelPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isSpanish = Localizations.localeOf(context).languageCode == 'es';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isSpanish ? 'Gestionar Suscripción' : 'Manage Subscription',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            isSpanish
                ? 'Si cancelas ahora, perderás el acceso a todos los cuentos al terminar tu periodo de facturación actual.'
                : 'If you cancel now, you will lose access to every story at the end of your current billing period.',
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onCancelPressed,
              child: Text(isSpanish ? 'Entendido, cancelar de todos modos' : 'Got it, cancel anyway'),
            ),
          ),
        ],
      ),
    );
  }
}
