import 'package:flutter/material.dart';

class ManageSubscriptionBottomSheet extends StatelessWidget {
  final VoidCallback onCancelPressed;

  const ManageSubscriptionBottomSheet({
    super.key,
    required this.onCancelPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gestionar Suscripción',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Si cancelas ahora, perderás tu acceso a historias ilimitadas y el modo offline al terminar tu periodo de facturación actual.',
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onCancelPressed,
              child: const Text('Entendido, cancelar de todos modos'),
            ),
          ),
        ],
      ),
    );
  }
}
