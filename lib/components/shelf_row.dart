import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/backend/backend.dart';
import 'tale_cover_card.dart';

/// Estanteria: titulo + carrusel horizontal de portadas (max 10) +
/// "ver mas" cuando la seccion tiene mas de 10 cuentos.
class ShelfRow extends StatelessWidget {
  const ShelfRow({
    super.key,
    required this.title,
    required this.tales,
    required this.isPremiumUser,
    required this.coverSize,
    required this.onTaleTap,
    this.onVerMas,
  });

  static const int kMaxVisible = 10;

  final String title;
  final List<TalesRecord> tales;
  final bool isPremiumUser;
  final double coverSize;
  final void Function(TalesRecord) onTaleTap;
  final VoidCallback? onVerMas;

  @override
  Widget build(BuildContext context) {
    final isSpanish = Localizations.localeOf(context).languageCode == 'es';
    final visibles = tales.take(kMaxVisible).toList();
    // altura = portada + hueco + 2 lineas de titulo (12px * ~1.2 * 2 + margen)
    final rowHeight = coverSize + 44.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16.0, 12.0, 8.0, 6.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17.0,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF101213),
                  ),
                ),
              ),
              if (onVerMas != null && tales.length > kMaxVisible)
                TextButton(
                  onPressed: onVerMas,
                  child: Text(
                    isSpanish ? 'ver más ›' : 'see all ›',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: rowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
            itemCount: min(visibles.length, kMaxVisible),
            separatorBuilder: (_, __) => const SizedBox(width: 10.0),
            itemBuilder: (context, index) {
              final tale = visibles[index];
              return TaleCoverCard(
                tale: tale,
                locked: tale.isPremiumTale && !isPremiumUser,
                size: coverSize,
                onTap: () => onTaleTap(tale),
              );
            },
          ),
        ),
      ],
    );
  }
}
