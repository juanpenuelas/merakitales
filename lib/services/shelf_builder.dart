import '/backend/backend.dart';

enum ShelfType { novedades, gratis, categoria }

class Shelf {
  const Shelf({required this.type, required this.tales, this.category});

  final ShelfType type;

  /// Lista completa de la seccion; la UI muestra como maximo 10 en el
  /// carrusel y pasa la lista entera a "ver mas".
  final List<TalesRecord> tales;

  /// Solo para [ShelfType.categoria].
  final CategoriesRecord? category;
}

const int kNovedadesCount = 10;

/// Agrupa el catalogo en estanterias, ya en orden de pintado.
/// [tales] debe venir filtrado por idioma y ordenado por tale_id desc.
/// [categories] debe venir ordenado por sort_order.
List<Shelf> buildShelves({
  required List<TalesRecord> tales,
  required List<CategoriesRecord> categories,
  required bool isPremiumUser,
}) {
  final novedades = tales.take(kNovedadesCount).toList();
  final gratis = tales.where((t) => !t.isPremiumTale).toList();
  final porCategoria = [
    for (final c in categories)
      Shelf(
        type: ShelfType.categoria,
        category: c,
        tales: tales.where((t) => t.categoryId == c.reference.id).toList(),
      ),
  ].where((s) => s.tales.isNotEmpty);

  return [
    if (novedades.isNotEmpty)
      Shelf(type: ShelfType.novedades, tales: novedades),
    if (!isPremiumUser && gratis.isNotEmpty)
      Shelf(type: ShelfType.gratis, tales: gratis),
    ...porCategoria,
    if (isPremiumUser && gratis.isNotEmpty)
      Shelf(type: ShelfType.gratis, tales: gratis),
  ];
}
