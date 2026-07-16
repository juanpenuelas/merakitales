import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/subscription_service.dart';
import '../pages/subscription_page/subscription_page_widget.dart';

class PremiumBadgeWidget extends StatelessWidget {
  const PremiumBadgeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<PremiumProvider>().isPremium;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SubscriptionPageWidget(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: isPremium 
              ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)])
              : const LinearGradient(colors: [Color(0xFFE0E0E0), Color(0xFFBDBDBD)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPremium ? const Color(0xFFDAA520) : const Color(0xFF9E9E9E),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isPremium ? const Color(0xFFFFD700) : const Color(0xFF9E9E9E)).withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPremium ? Icons.workspace_premium : Icons.stars,
              color: isPremium ? Colors.white : Colors.black54,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              isPremium ? 'PREMIUM' : 'FREE',
              style: TextStyle(
                color: isPremium ? Colors.white : Colors.black54,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
