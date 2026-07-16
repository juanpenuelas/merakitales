import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:merakitales/services/subscription_service.dart';
import 'package:merakitales/components/subscription_hero_card_widget.dart';
import 'package:merakitales/components/subscription_benefits_list_widget.dart';
import 'package:merakitales/components/manage_subscription_bottom_sheet.dart';

class SubscriptionPageWidget extends StatelessWidget {
  const SubscriptionPageWidget({super.key});

  String? _formatDate(String? isoDate) {
    if (isoDate == null) return null;
    try {
      final date = DateTime.parse(isoDate);
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;
      return '$day/$month/$year';
    } catch (e) {
      return null;
    }
  }

  void _openManagementUrl(String? url) async {
    if (url != null && url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suscripción'),
      ),
      body: Consumer<PremiumProvider>(
        builder: (context, provider, child) {
          final isPremium = provider.isPremium;
          final expirationDateRaw = provider.customerInfo?.latestExpirationDate;
          final managementUrl = provider.customerInfo?.managementURL;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SubscriptionHeroCardWidget(
                  isPremium: isPremium,
                  expirationDate: _formatDate(expirationDateRaw),
                ),
                const SizedBox(height: 24.0),
                const SubscriptionBenefitsListWidget(),
                if (isPremium) ...[
                  const SizedBox(height: 24.0),
                  TextButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) {
                          return ManageSubscriptionBottomSheet(
                            onCancelPressed: () {
                              _openManagementUrl(managementUrl);
                              Navigator.pop(context);
                            },
                          );
                        },
                      );
                    },
                    child: const Text('Gestionar suscripción'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
