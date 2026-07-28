import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/backend/backend.dart';

/// Portada cuadrada con candado (premium bloqueado), badge NUEVO (<= 7 dias)
/// y titulo en dos lineas. Widget tonto: quien lo usa decide `locked`.
class TaleCoverCard extends StatelessWidget {
  const TaleCoverCard({
    super.key,
    required this.tale,
    required this.locked,
    required this.size,
    required this.onTap,
  });

  final TalesRecord tale;
  final bool locked;
  final double size;
  final VoidCallback onTap;

  bool get _isNew =>
      tale.createdAt != null &&
      DateTime.now().difference(tale.createdAt!).inDays <= 7;

  @override
  Widget build(BuildContext context) {
    final isSpanish = Localizations.localeOf(context).languageCode == 'es';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.0),
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10.0),
                  child: Image.network(
                    tale.imageUrl640px,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: size,
                      height: size,
                      color: const Color(0xFFE0E0E0),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: Colors.white,
                        size: 32.0,
                      ),
                    ),
                  ),
                ),
                if (locked)
                  Positioned(
                    top: 4.0,
                    right: 4.0,
                    child: Container(
                      padding: const EdgeInsets.all(3.0),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: 12.0,
                      ),
                    ),
                  ),
                if (_isNew)
                  Positioned(
                    top: 4.0,
                    left: 4.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      child: Text(
                        isSpanish ? 'NUEVO' : 'NEW',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 8.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4.0),
            Text(
              tale.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF101213),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
