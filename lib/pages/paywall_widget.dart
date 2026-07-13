import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:merakitales/components/parental_gate.dart';
import 'package:merakitales/services/subscription_service.dart';

class PaywallWidget extends StatefulWidget {
  const PaywallWidget({super.key});

  static String routeName = 'Paywall';
  static String routePath = '/paywall';

  @override
  State<PaywallWidget> createState() => _PaywallWidgetState();
}

class _PaywallWidgetState extends State<PaywallWidget> {
  bool _isProcessingGatedAction = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<PremiumProvider>(context, listen: false);
      if (provider.offerings == null && !provider.isLoadingOfferings) {
        provider.loadOfferings();
      }
    });
  }

  Future<void> _handlePurchase(BuildContext context, PremiumProvider provider, Package package) async {
    if (_isProcessingGatedAction) return;
    _isProcessingGatedAction = true;
    try {
      final verified = await ParentalGate.verify(context);
      if (!verified) return;

      if (!context.mounted) return;
      
      // Show a loading overlay
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const PopScope(
          canPop: false,
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
            ),
          ),
        ),
      );

      final success = await provider.purchasePackage(package);
      
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Dismiss loading overlay

      final languageCode = Localizations.localeOf(context).languageCode;
      final isSpanish = languageCode == 'es';

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isSpanish ? '¡Gracias por hacerte Premium!' : 'Thank you for upgrading to Premium!',
              style: GoogleFonts.readexPro(),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // Pop paywall screen
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isSpanish ? 'La compra no se pudo completar.' : 'The purchase could not be completed.',
              style: GoogleFonts.readexPro(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isProcessingGatedAction = false;
    }
  }

  Future<void> _handleRestore(BuildContext context, PremiumProvider provider) async {
    if (_isProcessingGatedAction) return;
    _isProcessingGatedAction = true;
    try {
      final verified = await ParentalGate.verify(context);
      if (!verified) return;

      if (!context.mounted) return;

      // Show a loading overlay
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const PopScope(
          canPop: false,
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
            ),
          ),
        ),
      );

      final success = await provider.restorePurchases();

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Dismiss loading overlay

      final languageCode = Localizations.localeOf(context).languageCode;
      final isSpanish = languageCode == 'es';

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isSpanish ? '¡Compras restauradas con éxito!' : 'Purchases restored successfully!',
              style: GoogleFonts.readexPro(),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // Pop paywall screen
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isSpanish ? 'No se encontraron compras premium anteriores.' : 'No previous premium purchases found.',
              style: GoogleFonts.readexPro(),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      _isProcessingGatedAction = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PremiumProvider>(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final isSpanish = languageCode == 'es';

    final mediaQuery = MediaQuery.of(context);
    final isWide = mediaQuery.size.width >= 768;

    // Title / Header Texts
    final headerTitle = isSpanish ? 'Hazte Premium' : 'Upgrade to Premium';
    final headerSubtitle = isSpanish 
        ? 'Desbloquea la experiencia completa de Abuela Meraki' 
        : 'Unlock the full Abuela Meraki experience';

    // Benefits list
    final List<Map<String, String>> benefits = [
      {
        'title': isSpanish ? 'Sin anuncios' : 'Ad-Free experience',
        'desc': isSpanish ? 'Disfruta de tus cuentos sin interrupciones' : 'Enjoy your stories without any interruptions',
        'icon': 'no_ads',
      },
      {
        'title': isSpanish ? 'Apoya a Abuela Meraki' : 'Support future stories',
        'desc': isSpanish ? 'Ayúdanos a crear más cuentos mágicos para niños' : 'Help us create more magical tales for children',
        'icon': 'favorite',
      },
      {
        'title': isSpanish ? 'Acceso ilimitado' : 'Unlimited access',
        'desc': isSpanish ? 'Escucha y lee todos los cuentos disponibles' : 'Listen and read all available stories',
        'icon': 'auto_awesome',
      }
    ];

    // Determine the monthly package
    Package? monthlyPackage;
    String formattedPrice = '\$1.99'; // Default mockup price
    
    if (provider.offerings != null && provider.offerings!.current != null) {
      monthlyPackage = provider.offerings!.current!.monthly;
      if (monthlyPackage != null) {
        formattedPrice = monthlyPackage.storeProduct.priceString;
      }
    }

    final priceText = isSpanish 
        ? '$formattedPrice / mes' 
        : '$formattedPrice / month';

    return Scaffold(
      backgroundColor: const Color(0xFF0B0914), // Deep premium dark background
      body: SafeArea(
        child: Stack(
          children: [
            // Background glowing gradient blobs
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF7C3AED).withOpacity(0.15),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.15),
                      blurRadius: 100,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -100,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      blurRadius: 100,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),
            
            // Close Button
            Positioned(
              top: 16,
              left: 16,
              child: ClipOval(
                child: Material(
                  color: const Color(0xFF1E1B4B).withOpacity(0.6),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),

            // Main Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                children: [
                  const SizedBox(height: 60), // Space for close button
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          // Header
                          Text(
                            headerTitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: isWide ? 38 : 30,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            headerSubtitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.readexPro(
                              color: const Color(0xFF94A3B8),
                              fontSize: isWide ? 18 : 15,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Responsive content block
                          isWide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: _buildBenefitsList(benefits),
                                    ),
                                    const SizedBox(width: 32),
                                    Expanded(
                                      flex: 4,
                                      child: _buildPurchaseCard(
                                        context: context,
                                        provider: provider,
                                        monthlyPackage: monthlyPackage,
                                        formattedPrice: formattedPrice,
                                        priceText: priceText,
                                        isSpanish: isSpanish,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    _buildBenefitsList(benefits),
                                    const SizedBox(height: 24),
                                    _buildPurchaseCard(
                                      context: context,
                                      provider: provider,
                                      monthlyPackage: monthlyPackage,
                                      formattedPrice: formattedPrice,
                                      priceText: priceText,
                                      isSpanish: isSpanish,
                                    ),
                                  ],
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitsList(List<Map<String, String>> benefits) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: benefits.map((benefit) {
        IconData iconData = Icons.star;
        if (benefit['icon'] == 'no_ads') iconData = Icons.block;
        if (benefit['icon'] == 'favorite') iconData = Icons.favorite;
        if (benefit['icon'] == 'auto_awesome') iconData = Icons.auto_awesome;

        return Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1E1B4B).withOpacity(0.8),
                  border: Border.all(color: const Color(0xFF4338CA).withOpacity(0.6)),
                ),
                child: Icon(
                  iconData,
                  color: const Color(0xFF818CF8),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      benefit['title'] ?? '',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      benefit['desc'] ?? '',
                      style: GoogleFonts.readexPro(
                        color: const Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPurchaseCard({
    required BuildContext context,
    required PremiumProvider provider,
    required Package? monthlyPackage,
    required String formattedPrice,
    required String priceText,
    required bool isSpanish,
  }) {
    if (provider.isPremium) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF1E1B4B).withOpacity(0.4),
          border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Color(0xFF22C55E),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              isSpanish ? '¡Ya eres miembro Premium!' : 'You are already a Premium member!',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSpanish
                  ? 'Disfruta de todos los beneficios premium en tu dispositivo.'
                  : 'Enjoy all premium features on your device.',
              textAlign: TextAlign.center,
              style: GoogleFonts.readexPro(
                color: const Color(0xFF94A3B8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (provider.isLoadingOfferings) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
        ),
      );
    }

    final isPreviewOnly = kIsWeb || monthlyPackage == null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1E1B4B).withOpacity(0.4),
        border: Border.all(color: const Color(0xFF4338CA).withOpacity(0.8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Crown design
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFFC7D2FE)],
              ),
            ),
            child: const Icon(
              Icons.workspace_premium,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          
          // Package details
          Text(
            isSpanish ? 'Suscripción Mensual' : 'Monthly Subscription',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          Text(
            priceText,
            style: GoogleFonts.outfit(
              color: const Color(0xFF818CF8),
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          if (isPreviewOnly && kIsWeb)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                isSpanish
                    ? 'Nota: Las compras en la aplicación no están soportadas en Web. Mostrando vista previa.'
                    : 'Note: In-app purchases are not supported on Web. Showing preview.',
                textAlign: TextAlign.center,
                style: GoogleFonts.readexPro(
                  color: const Color(0xFFF59E0B),
                  fontSize: 12,
                ),
              ),
            ),

          if (isPreviewOnly && !kIsWeb)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                isSpanish
                    ? 'No se pudieron cargar los precios actualizados. Por favor, comprueba tu conexión.'
                    : 'Failed to load live store prices. Please check your connection.',
                textAlign: TextAlign.center,
                style: GoogleFonts.readexPro(
                  color: const Color(0xFFEF4444),
                  fontSize: 12,
                ),
              ),
            ),

          // Purchase Button
          InkWell(
            onTap: isPreviewOnly
                ? null
                : () => _handlePurchase(context, provider, monthlyPackage),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: isPreviewOnly
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: isPreviewOnly ? Colors.grey.withOpacity(0.2) : null,
              ),
              alignment: Alignment.center,
              child: Text(
                isSpanish ? 'Obtener Premium' : 'Get Premium',
                style: GoogleFonts.outfit(
                  color: isPreviewOnly ? Colors.white38 : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Restore Purchases Button
          TextButton(
            onPressed: isPreviewOnly
                ? null
                : () => _handleRestore(context, provider),
            child: Text(
              isSpanish ? 'Restaurar Compras' : 'Restore Purchases',
              style: GoogleFonts.readexPro(
                color: isPreviewOnly ? Colors.white38 : const Color(0xFFC7D2FE),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
