import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:merakitales/services/subscription_service.dart';
import 'package:merakitales/components/subscription_hero_card_widget.dart';
import 'package:merakitales/components/subscription_benefits_list_widget.dart';
import 'package:merakitales/components/manage_subscription_bottom_sheet.dart';
import 'package:merakitales/components/parental_gate.dart';
import 'package:merakitales/components/subscription_legal_links.dart';
import 'package:merakitales/pages/paywall_widget.dart';

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

  // Gestionar la suscripcion saca al usuario a los ajustes de la cuenta, asi
  // que en categoria Kids pasa por el parental gate igual que el resto de
  // salidas de la app (guideline 1.3).
  Future<void> _openManagementUrl(BuildContext context, String? url) async {
    if (url == null || url.isEmpty) return;
    if (!await ParentalGate.verify(context)) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Todos los puntos de entrada premium (drawer, badge, cuento bloqueado)
    // llegan aqui. Esta pagina es el estado/gestion de la suscripcion y no
    // tiene camino a la compra, asi que quien no es premium va al paywall.
    // read y NO watch a proposito: el destino se decide al entrar. Con watch,
    // al activarse premium se desmontaba el paywall a mitad de la compra y su
    // dialogo de carga quedaba huerfano girando para siempre. El paywall se
    // cierra solo al terminar.
    if (!context.read<PremiumProvider>().isPremium) {
      return const PaywallWidget();
    }

    final isSpanish = Localizations.localeOf(context).languageCode == 'es';

    return Scaffold(
      appBar: AppBar(
        title: Text(isSpanish ? 'Suscripción' : 'Subscription'),
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
                      final pageContext = context;
                      showModalBottomSheet(
                        context: context,
                        builder: (sheetContext) {
                          return ManageSubscriptionBottomSheet(
                            onCancelPressed: () {
                              Navigator.pop(sheetContext);
                              _openManagementUrl(pageContext, managementUrl);
                            },
                          );
                        },
                      );
                    },
                    child: Text(isSpanish ? 'Gestionar suscripción' : 'Manage subscription'),
                  ),
                ],
                const SizedBox(height: 24.0),
                SubscriptionLegalLinks(isSpanish: isSpanish),
              ],
            ),
          );
        },
      ),
    );
  }
}
