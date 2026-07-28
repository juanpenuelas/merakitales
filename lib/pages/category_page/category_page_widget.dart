import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '/backend/backend.dart';
import '/components/tale_cover_card.dart';
import '/flutter_flow/flutter_flow_ad_banner.dart';
import '/services/subscription_service.dart';
import '/services/tale_opener.dart';

/// Cuadricula de una seccion completa (categoria, Gratis o Novedades).
/// Recibe los cuentos ya cargados por la home: no consulta Firestore.
class CategoryPageWidget extends StatelessWidget {
  const CategoryPageWidget({
    super.key,
    required this.title,
    this.emoji,
    required this.tales,
    this.description,
  });

  final String title;
  final String? emoji;
  final List<TalesRecord> tales;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final isSpanish = Localizations.localeOf(context).languageCode == 'es';
    final isPremiumUser = context.watch<PremiumProvider>().isPremium;
    final noun = isSpanish
        ? (tales.length == 1 ? 'cuento' : 'cuentos')
        : (tales.length == 1 ? 'tale' : 'tales');
    final width = MediaQuery.sizeOf(context).width;
    final columns = width < 479
        ? 2
        : width < 767
            ? 3
            : 4;
    const spacing = 12.0;
    const hPadding = 16.0;
    final cellWidth =
        (width - hPadding * 2 - spacing * (columns - 1)) / columns;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D5A3D),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16.0, 12.0, 16.0, 4.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2D5A3D), Color(0xFF1E4030)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (emoji != null && emoji!.isNotEmpty) ...[
                          Text(emoji!, style: const TextStyle(fontSize: 32.0)),
                          const SizedBox(width: 12.0),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 5.0),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 3.0),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8B04B),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: Text(
                                  '${tales.length} $noun',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF2D3A2E),
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (description != null && description!.isNotEmpty) ...[
                      const SizedBox(height: 10.0),
                      Text(
                        description!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(hPadding),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  mainAxisExtent: cellWidth + 44.0,
                ),
                itemCount: tales.length,
                itemBuilder: (context, index) {
                  final tale = tales[index];
                  return TaleCoverCard(
                    tale: tale,
                    locked: tale.isPremiumTale && !isPremiumUser,
                    size: cellWidth,
                    onTap: () => openTale(context, tale),
                  );
                },
              ),
            ),
            FlutterFlowAdBanner(
              width: MediaQuery.sizeOf(context).width * 1.0,
              height: 50.0,
              showsTestAd: kDebugMode,
              iOSAdUnitID: 'ca-app-pub-6049242703708474/6940127458',
              androidAdUnitID: 'ca-app-pub-6049242703708474/5874457795',
            ),
          ],
        ),
      ),
    );
  }
}
