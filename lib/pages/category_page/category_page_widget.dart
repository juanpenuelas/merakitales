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
  });

  final String title;
  final String? emoji;
  final List<TalesRecord> tales;

  @override
  Widget build(BuildContext context) {
    final isSpanish = Localizations.localeOf(context).languageCode == 'es';
    final isPremiumUser = context.watch<PremiumProvider>().isPremium;
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
        title: Text(
          [if (emoji != null && emoji!.isNotEmpty) emoji, title].join(' '),
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 18.0,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsetsDirectional.fromSTEB(16.0, 10.0, 16.0, 0.0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  '${tales.length} ${isSpanish ? 'cuentos' : 'tales'}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.0,
                    color: const Color(0xFF57636C),
                    fontWeight: FontWeight.w600,
                  ),
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
