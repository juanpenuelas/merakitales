import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/subscription_service.dart';
import 'premium_status_bottom_sheet_widget.dart';

class PremiumBadgeWidget extends StatelessWidget {
  const PremiumBadgeWidget({super.key});

  void _showPremiumBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const PremiumStatusBottomSheetWidget(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<PremiumProvider>().isPremium;

    if (!isPremium) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: const Icon(Icons.workspace_premium, color: Color(0xFFFFD700)), // Gold color
      tooltip: 'Estado Premium',
      onPressed: () => _showPremiumBottomSheet(context),
    );
  }
}
