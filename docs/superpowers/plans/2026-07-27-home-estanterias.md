# Home de Estanterías — Plan de Implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sustituir el scroll cronológico único de la app móvil por una home de estanterías (Novedades / Gratis / una por categoría premium), con página de categoría en cuadrícula, y arreglar que los teasers premium consuman el cupo semanal de lecturas gratis.

**Architecture:** La home hace 2 consultas Firestore (categorías + todos los cuentos del idioma, sin paginación) y una función pura `buildShelves` agrupa en cliente. Widgets nuevos "tontos" (sin modelos FlutterFlow) para portada/estantería/upsell; una página `LibraryHome` con modelo FlutterFlow (por el drawer) reemplaza a `TaleListWidget` y sus 3 variantes duplicadas, que se borran. La página de categoría se abre con `Navigator.push` + `MaterialPageRoute` (mismo patrón que la página de suscripción), sin serialización ni rutas nuevas en go_router.

**Tech Stack:** Flutter (proyecto FlutterFlow), cloud_firestore 5.6.9, provider, google_mobile_ads, go_router 12. Test: flutter_test + fake_cloud_firestore (dev dep nueva).

**Spec:** `docs/superpowers/specs/2026-07-27-home-estanterias-design.md`

## Global Constraints

- Rama de trabajo: `feature/home-estanterias` (ya creada). Commits en español sin acentos, estilo conventional (`feat(...)`, `fix(...)`), como el historial del repo.
- Strings nuevos de UI: patrón inline del código reciente del repo — `final isSpanish = Localizations.localeOf(context).languageCode == 'es';` + ternario. NO tocar `internationalization.dart` (sus claves son generadas por FlutterFlow).
- Cero dependencias nuevas de runtime. `fake_cloud_firestore` solo en `dev_dependencies`.
- `infinite_scroll_pagination` NO se elimina de pubspec: `lib/backend/backend.dart` (generado) la usa en helpers genéricos. Solo mueren sus usos en los componentes borrados.
- IDs de anuncios (copiar tal cual, son los actuales):
  - Interstitial: `"ca-app-pub-6049242703708474/2634885084"` (Android), `"ca-app-pub-6049242703708474/1026289941"` (iOS)
  - Banner: iOS `'ca-app-pub-6049242703708474/6940127458'`, Android `'ca-app-pub-6049242703708474/5874457795'`
- Breakpoints responsive: móvil `< 479`, tablet `< 767`, escritorio `>= 767` (los estándar FlutterFlow del proyecto).
- Después de cada task: `flutter analyze` sin issues nuevos y `flutter test` en verde antes de commitear.
- Los cuentos premium se identifican con `is_premium_tale == true`; el usuario premium con `context.watch<PremiumProvider>().isPremium` (import `'/services/subscription_service.dart'`).

---

### Task 1: Schema — `category_id` en TalesRecord + CategoriesRecord + query helper

**Files:**
- Modify: `lib/backend/schema/tales_record.dart`
- Create: `lib/backend/schema/categories_record.dart`
- Modify: `lib/backend/backend.dart`

**Interfaces:**
- Produces: `TalesRecord.categoryId` (`String get categoryId`, `''` si nulo), `CategoriesRecord` (`nameEs`, `nameEn`, `emoji`, `slug`, `sortOrder`, `reference.id` como id de categoría), `Stream<List<CategoriesRecord>> queryCategoriesRecord({queryBuilder, limit, singleRecord})`.

- [ ] **Step 1: Añadir `category_id` a TalesRecord (4 sitios, patrón exacto de los campos existentes)**

En `lib/backend/schema/tales_record.dart`, tras el bloque del campo `is_premium_tale` (línea ~96):

```dart
  // "category_id" field.
  String? _categoryId;
  String get categoryId => _categoryId ?? '';
  bool hasCategoryId() => _categoryId != null;
```

En `_initializeFields()`, tras la línea de `_isPremiumTale`:

```dart
    _categoryId = snapshotData['category_id'] as String?;
```

En `createTalesRecordData(...)`: añadir parámetro `String? categoryId,` y en el mapa `'category_id': categoryId,`.

En `TalesRecordDocumentEquality`: añadir `e1?.categoryId == e2?.categoryId` al `&&` final de `equals`, y `e?.categoryId` al final de la lista de `hash`.

- [ ] **Step 2: Crear `lib/backend/schema/categories_record.dart`**

Archivo completo (patrón calcado de `tales_common_data_record.dart`):

```dart
import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class CategoriesRecord extends FirestoreRecord {
  CategoriesRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "name_es" field.
  String? _nameEs;
  String get nameEs => _nameEs ?? '';
  bool hasNameEs() => _nameEs != null;

  // "name_en" field.
  String? _nameEn;
  String get nameEn => _nameEn ?? '';
  bool hasNameEn() => _nameEn != null;

  // "emoji" field.
  String? _emoji;
  String get emoji => _emoji ?? '';
  bool hasEmoji() => _emoji != null;

  // "slug" field.
  String? _slug;
  String get slug => _slug ?? '';
  bool hasSlug() => _slug != null;

  // "sort_order" field.
  int? _sortOrder;
  int get sortOrder => _sortOrder ?? 0;
  bool hasSortOrder() => _sortOrder != null;

  void _initializeFields() {
    _nameEs = snapshotData['name_es'] as String?;
    _nameEn = snapshotData['name_en'] as String?;
    _emoji = snapshotData['emoji'] as String?;
    _slug = snapshotData['slug'] as String?;
    _sortOrder = castToType<int>(snapshotData['sort_order']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('categories');

  static Stream<CategoriesRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => CategoriesRecord.fromSnapshot(s));

  static Future<CategoriesRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => CategoriesRecord.fromSnapshot(s));

  static CategoriesRecord fromSnapshot(DocumentSnapshot snapshot) =>
      CategoriesRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static CategoriesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      CategoriesRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'CategoriesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is CategoriesRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createCategoriesRecordData({
  String? nameEs,
  String? nameEn,
  String? emoji,
  String? slug,
  int? sortOrder,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'name_es': nameEs,
      'name_en': nameEn,
      'emoji': emoji,
      'slug': slug,
      'sort_order': sortOrder,
    }.withoutNulls,
  );

  return firestoreData;
}

class CategoriesRecordDocumentEquality implements Equality<CategoriesRecord> {
  const CategoriesRecordDocumentEquality();

  @override
  bool equals(CategoriesRecord? e1, CategoriesRecord? e2) {
    return e1?.nameEs == e2?.nameEs &&
        e1?.nameEn == e2?.nameEn &&
        e1?.emoji == e2?.emoji &&
        e1?.slug == e2?.slug &&
        e1?.sortOrder == e2?.sortOrder;
  }

  @override
  int hash(CategoriesRecord? e) => const ListEquality()
      .hash([e?.nameEs, e?.nameEn, e?.emoji, e?.slug, e?.sortOrder]);

  @override
  bool isValidKey(Object? o) => o is CategoriesRecord;
}
```

- [ ] **Step 3: Registrar en `lib/backend/backend.dart`**

Tras `import 'schema/tales_common_data_record.dart';` añadir:

```dart
import 'schema/categories_record.dart';
```

Tras `export 'schema/tales_common_data_record.dart';` añadir:

```dart
export 'schema/categories_record.dart';
```

Al final del archivo, siguiendo el patrón exacto de `queryTalesRecord` (mismo helper genérico `queryCollection`):

```dart
/// Functions to query CategoriesRecords (as a Stream and as a Future).
Future<int> queryCategoriesRecordCount({
  Query Function(Query)? queryBuilder,
  int limit = -1,
}) =>
    queryCollectionCount(
      CategoriesRecord.collection,
      queryBuilder: queryBuilder,
      limit: limit,
    );

Stream<List<CategoriesRecord>> queryCategoriesRecord({
  Query Function(Query)? queryBuilder,
  int limit = -1,
  bool singleRecord = false,
}) =>
    queryCollection(
      CategoriesRecord.collection,
      CategoriesRecord.fromSnapshot,
      queryBuilder: queryBuilder,
      limit: limit,
      singleRecord: singleRecord,
    );
```

Nota: abrir `backend.dart` y copiar la firma REAL de `queryTalesRecord`/`queryTalesRecordOnce` (líneas ~20-60); si existe `queryTalesRecordOnce`, crear también `queryCategoriesRecordOnce` idéntico. No inventar parámetros: espejo exacto.

- [ ] **Step 4: Verificar**

Run: `flutter analyze`
Expected: `No issues found!` (o exactamente los mismos issues preexistentes que en main, ninguno nuevo).

- [ ] **Step 5: Commit**

```bash
git add lib/backend/schema/tales_record.dart lib/backend/schema/categories_record.dart lib/backend/backend.dart
git commit -m "feat(data): leer category_id y anadir CategoriesRecord"
```

---

### Task 2: Cupo semanal — el teaser premium no consume ni bloquea (TDD)

**Files:**
- Modify: `lib/services/weekly_read_limit_service.dart`
- Modify: `lib/components/tale_detail_mobile_component_widget.dart:56-141`
- Modify: `lib/components/tale_detail_tablet_component_widget.dart` (mismo bloque, ~línea 55-140)
- Test: `test/weekly_read_limit_service_test.dart` (añadir grupo nuevo, no tocar los tests existentes)

**Interfaces:**
- Consumes: `WeeklyReadLimitService.canRead(int taleId)`, `recordRead(int taleId)` (existentes).
- Produces: `Future<bool> registerOpenAndCheckAllowed({required int taleId, required bool userIsPremium, required bool taleIsPremium})` — true = mostrar cuento (completo o teaser); false = bloquear con modal de límite.

Nota de desviación del spec: el spec pedía un widget test de "abrir el detalle en modo teaser no registra lectura". El detalle arranca Firebase Messaging y anuncios nativos en initState (plugins imposibles de bombear en un widget test sin mocking pesado), así que la regla completa se centraliza en el servicio y se cubre con unit tests exhaustivos; los widgets quedan como delegación de una línea verificada en la prueba manual de Task 9.

- [ ] **Step 1: Escribir los tests que fallan**

En `test/weekly_read_limit_service_test.dart`, dentro de `main()`, añadir al final (usar los mismos imports/patrones del archivo — ya usa `SharedPreferences.setMockInitialValues`; leer el archivo antes para replicar su setup exacto):

```dart
  group('registerOpenAndCheckAllowed', () {
    late WeeklyReadLimitService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = WeeklyReadLimitService();
    });

    test('usuario premium: siempre permitido y no registra lectura', () async {
      final allowed = await service.registerOpenAndCheckAllowed(
          taleId: 1, userIsPremium: true, taleIsPremium: false);
      expect(allowed, true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('weekly_read_tales') ?? [], isEmpty);
    });

    test('teaser premium (usuario no premium): permitido y no registra',
        () async {
      final allowed = await service.registerOpenAndCheckAllowed(
          taleId: 2, userIsPremium: false, taleIsPremium: true);
      expect(allowed, true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('weekly_read_tales') ?? [], isEmpty);
    });

    test('cuento gratis bajo el limite: permitido y registra', () async {
      final allowed = await service.registerOpenAndCheckAllowed(
          taleId: 3, userIsPremium: false, taleIsPremium: false);
      expect(allowed, true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('weekly_read_tales'), ['3']);
    });

    test('cuento gratis con limite alcanzado: bloqueado', () async {
      for (var i = 1; i <= 7; i++) {
        await service.registerOpenAndCheckAllowed(
            taleId: i, userIsPremium: false, taleIsPremium: false);
      }
      final allowed = await service.registerOpenAndCheckAllowed(
          taleId: 99, userIsPremium: false, taleIsPremium: false);
      expect(allowed, false);
    });

    test('releer un cuento ya leido esta semana con limite lleno: permitido',
        () async {
      for (var i = 1; i <= 7; i++) {
        await service.registerOpenAndCheckAllowed(
            taleId: i, userIsPremium: false, taleIsPremium: false);
      }
      final allowed = await service.registerOpenAndCheckAllowed(
          taleId: 1, userIsPremium: false, taleIsPremium: false);
      expect(allowed, true);
    });

    test('teaser premium con limite lleno: sigue permitido', () async {
      for (var i = 1; i <= 7; i++) {
        await service.registerOpenAndCheckAllowed(
            taleId: i, userIsPremium: false, taleIsPremium: false);
      }
      final allowed = await service.registerOpenAndCheckAllowed(
          taleId: 100, userIsPremium: false, taleIsPremium: true);
      expect(allowed, true);
    });
  });
```

Nota: si el archivo de test usa otra clave interna distinta de `'weekly_read_tales'`, mirar `_readTalesKey` en el servicio (es `'weekly_read_tales'`) y usar esa.

- [ ] **Step 2: Correr y ver el fallo**

Run: `flutter test test/weekly_read_limit_service_test.dart`
Expected: FAIL — `registerOpenAndCheckAllowed` no existe (error de compilación del test).

- [ ] **Step 3: Implementar el método en el servicio**

En `lib/services/weekly_read_limit_service.dart`, al final de la clase:

```dart
  /// Registra la apertura de un cuento y devuelve si puede mostrarse.
  /// Reglas: usuario premium nunca tiene cupo; un cuento premium abierto por
  /// un usuario no premium es un teaser y no consume ni bloquea; solo las
  /// lecturas de cuentos gratis por usuarios no premium cuentan.
  Future<bool> registerOpenAndCheckAllowed({
    required int taleId,
    required bool userIsPremium,
    required bool taleIsPremium,
  }) async {
    if (userIsPremium || taleIsPremium) {
      return true;
    }
    if (!await canRead(taleId)) {
      return false;
    }
    await recordRead(taleId);
    return true;
  }
```

- [ ] **Step 4: Correr los tests en verde**

Run: `flutter test test/weekly_read_limit_service_test.dart`
Expected: PASS todos (los nuevos y los preexistentes).

- [ ] **Step 5: Usar el método en el detalle móvil**

En `lib/components/tale_detail_mobile_component_widget.dart`, el bloque del `initState` (líneas 56-141) que hoy es:

```dart
      final isPremium = context.read<PremiumProvider>().isPremium;
      if (!isPremium && widget.taleDetailParameter != null) {
        final taleId = widget.taleDetailParameter!.taleId;
        final service = WeeklyReadLimitService();
        final canRead = await service.canRead(taleId);

        if (canRead) {
          await service.recordRead(taleId);
        } else {
          showModalBottomSheet(
            ...
          );
        }
      }
```

pasa a:

```dart
      final isPremium = context.read<PremiumProvider>().isPremium;
      if (widget.taleDetailParameter != null) {
        final allowed =
            await WeeklyReadLimitService().registerOpenAndCheckAllowed(
          taleId: widget.taleDetailParameter!.taleId,
          userIsPremium: isPremium,
          taleIsPremium: widget.taleDetailParameter!.isPremiumTale,
        );

        if (!allowed) {
          showModalBottomSheet(
            ...
          );
        }
      }
```

El `showModalBottomSheet(...)` interior se conserva EXACTAMENTE igual (mismo contenido, botones y navegación); solo cambia la condición que lo envuelve. Cuidado con re-indentar bien los cierres.

- [ ] **Step 6: Repetir el mismo cambio en el detalle tablet**

`lib/components/tale_detail_tablet_component_widget.dart` tiene el mismo bloque (buscar `WeeklyReadLimitService` ~línea 61). Aplicar la transformación idéntica del Step 5.

- [ ] **Step 7: Verificar**

Run: `flutter analyze && flutter test`
Expected: analyze limpio, tests todos en verde.

- [ ] **Step 8: Commit**

```bash
git add lib/services/weekly_read_limit_service.dart lib/components/tale_detail_mobile_component_widget.dart lib/components/tale_detail_tablet_component_widget.dart test/weekly_read_limit_service_test.dart
git commit -m "fix(cuentos): el teaser premium no consume el cupo semanal"
```

---

### Task 3: `buildShelves` — agrupador puro de estanterías (TDD)

**Files:**
- Modify: `pubspec.yaml` (dev_dependencies)
- Create: `lib/services/shelf_builder.dart`
- Test: `test/shelf_builder_test.dart`

**Interfaces:**
- Consumes: `TalesRecord` (`.isPremiumTale`, `.categoryId`, orden de entrada = `tale_id` desc), `CategoriesRecord` (`.reference.id`, orden de entrada = `sort_order`).
- Produces:

```dart
enum ShelfType { novedades, gratis, categoria }

class Shelf {
  const Shelf({required this.type, required this.tales, this.category});
  final ShelfType type;
  final List<TalesRecord> tales;   // lista completa; la UI capa a 10
  final CategoriesRecord? category; // solo para ShelfType.categoria
}

const int kNovedadesCount = 10;

List<Shelf> buildShelves({
  required List<TalesRecord> tales,
  required List<CategoriesRecord> categories,
  required bool isPremiumUser,
});
```

- [ ] **Step 1: Añadir fake_cloud_firestore a dev_dependencies**

En `pubspec.yaml`, dentro de `dev_dependencies:` (tras `flutter_test:`/`sdk: flutter`):

```yaml
  fake_cloud_firestore: ^3.1.0
```

Run: `flutter pub get`
Expected: resuelve sin conflictos (compatible con cloud_firestore 5.6.9). Si la versión exacta no resuelve, usar la última 3.x que resuelva.

- [ ] **Step 2: Escribir los tests que fallan**

Crear `test/shelf_builder_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/backend/backend.dart';
import 'package:merakitales/services/shelf_builder.dart';

Future<TalesRecord> makeTale(
  FakeFirebaseFirestore db, {
  required int id,
  bool premium = false,
  String? categoryId,
}) async {
  final ref = db.collection('tales').doc('tale_$id');
  await ref.set({
    'name': 'Cuento $id',
    'lang': 'es',
    'tale_id': id,
    'is_premium_tale': premium,
    if (categoryId != null) 'category_id': categoryId,
  });
  return TalesRecord.fromSnapshot(await ref.get());
}

Future<CategoriesRecord> makeCategory(
  FakeFirebaseFirestore db, {
  required String id,
  required int sortOrder,
}) async {
  final ref = db.collection('categories').doc(id);
  await ref.set({
    'name_es': 'Cat $id',
    'name_en': 'Cat $id EN',
    'emoji': '⭐',
    'slug': id,
    'sort_order': sortOrder,
  });
  return CategoriesRecord.fromSnapshot(await ref.get());
}

void main() {
  late FakeFirebaseFirestore db;

  setUp(() {
    db = FakeFirebaseFirestore();
  });

  test('usuario gratuito: novedades, gratis y categorias por sort_order',
      () async {
    final catA = await makeCategory(db, id: 'aventuras', sortOrder: 1);
    final catB = await makeCategory(db, id: 'humor', sortOrder: 2);
    final tales = [
      await makeTale(db, id: 5, premium: true, categoryId: 'humor'),
      await makeTale(db, id: 4, premium: true, categoryId: 'aventuras'),
      await makeTale(db, id: 3),
      await makeTale(db, id: 2),
      await makeTale(db, id: 1),
    ];

    final shelves = buildShelves(
        tales: tales, categories: [catA, catB], isPremiumUser: false);

    expect(shelves.map((s) => s.type).toList(), [
      ShelfType.novedades,
      ShelfType.gratis,
      ShelfType.categoria,
      ShelfType.categoria,
    ]);
    expect(shelves[1].tales.map((t) => t.taleId), [3, 2, 1]);
    expect(shelves[2].category!.reference.id, 'aventuras');
    expect(shelves[2].tales.single.taleId, 4);
    expect(shelves[3].category!.reference.id, 'humor');
  });

  test('usuario premium: gratis va al final', () async {
    final cat = await makeCategory(db, id: 'aventuras', sortOrder: 1);
    final tales = [
      await makeTale(db, id: 2, premium: true, categoryId: 'aventuras'),
      await makeTale(db, id: 1),
    ];

    final shelves =
        buildShelves(tales: tales, categories: [cat], isPremiumUser: true);

    expect(shelves.map((s) => s.type).toList(), [
      ShelfType.novedades,
      ShelfType.categoria,
      ShelfType.gratis,
    ]);
  });

  test('novedades se limita a 10 y conserva el orden de entrada', () async {
    final tales = [
      for (var id = 15; id >= 1; id--) await makeTale(db, id: id),
    ];

    final shelves =
        buildShelves(tales: tales, categories: [], isPremiumUser: false);

    final novedades = shelves.firstWhere((s) => s.type == ShelfType.novedades);
    expect(novedades.tales.length, 10);
    expect(novedades.tales.first.taleId, 15);
    expect(novedades.tales.last.taleId, 6);
  });

  test('categoria sin cuentos no aparece', () async {
    final vacia = await makeCategory(db, id: 'vacia', sortOrder: 1);
    final tales = [await makeTale(db, id: 1)];

    final shelves =
        buildShelves(tales: tales, categories: [vacia], isPremiumUser: false);

    expect(shelves.where((s) => s.type == ShelfType.categoria), isEmpty);
  });

  test('cuento premium con category_id desconocido solo sale en novedades',
      () async {
    final cat = await makeCategory(db, id: 'aventuras', sortOrder: 1);
    final tales = [
      await makeTale(db, id: 2, premium: true, categoryId: 'borrada'),
      await makeTale(db, id: 1, premium: true, categoryId: 'aventuras'),
    ];

    final shelves =
        buildShelves(tales: tales, categories: [cat], isPremiumUser: false);

    final categoria = shelves.where((s) => s.type == ShelfType.categoria);
    expect(categoria.single.tales.single.taleId, 1);
    final novedades = shelves.firstWhere((s) => s.type == ShelfType.novedades);
    expect(novedades.tales.map((t) => t.taleId), [2, 1]);
  });

  test('catalogo vacio devuelve cero estanterias', () async {
    final shelves =
        buildShelves(tales: [], categories: [], isPremiumUser: false);
    expect(shelves, isEmpty);
  });

  test('sin cuentos gratis no hay estanteria gratis', () async {
    final cat = await makeCategory(db, id: 'aventuras', sortOrder: 1);
    final tales = [
      await makeTale(db, id: 1, premium: true, categoryId: 'aventuras'),
    ];

    final shelves =
        buildShelves(tales: tales, categories: [cat], isPremiumUser: false);

    expect(shelves.where((s) => s.type == ShelfType.gratis), isEmpty);
  });
}
```

- [ ] **Step 3: Correr y ver el fallo**

Run: `flutter test test/shelf_builder_test.dart`
Expected: FAIL — no existe `lib/services/shelf_builder.dart`.

- [ ] **Step 4: Implementar `lib/services/shelf_builder.dart`**

```dart
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
```

- [ ] **Step 5: Correr los tests en verde**

Run: `flutter test test/shelf_builder_test.dart`
Expected: PASS los 7 tests.

- [ ] **Step 6: Verificar y commitear**

Run: `flutter analyze && flutter test`
Expected: limpio y todo verde.

```bash
git add pubspec.yaml pubspec.lock lib/services/shelf_builder.dart test/shelf_builder_test.dart
git commit -m "feat(home): agrupador de estanterias con tests"
```

---

### Task 4: Widgets de UI — TaleCoverCard, ShelfRow y PremiumUpsellCard

**Files:**
- Create: `lib/components/tale_cover_card.dart`
- Create: `lib/components/shelf_row.dart`
- Create: `lib/components/premium_upsell_card.dart`
- Test: `test/tale_cover_card_test.dart`

**Interfaces:**
- Consumes: `TalesRecord` (Task 1), `SubscriptionPageWidget` (existente, import `'/pages/subscription_page/subscription_page_widget.dart'`).
- Produces:

```dart
class TaleCoverCard extends StatelessWidget {
  const TaleCoverCard({super.key, required this.tale, required this.locked,
      required this.size, required this.onTap});
  final TalesRecord tale; final bool locked; final double size;
  final VoidCallback onTap;
}

class ShelfRow extends StatelessWidget {
  const ShelfRow({super.key, required this.title, required this.tales,
      required this.isPremiumUser, required this.coverSize,
      required this.onTaleTap, this.onVerMas});
  final String title; final List<TalesRecord> tales;
  final bool isPremiumUser; final double coverSize;
  final void Function(TalesRecord) onTaleTap;
  final VoidCallback? onVerMas; // se pinta solo si tales.length > 10
  static const int kMaxVisible = 10;
}

class PremiumUpsellCard extends StatelessWidget {
  const PremiumUpsellCard({super.key});
}
```

- [ ] **Step 1: Crear `lib/components/tale_cover_card.dart`**

```dart
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
```

- [ ] **Step 2: Crear `lib/components/shelf_row.dart`**

```dart
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
```

- [ ] **Step 3: Crear `lib/components/premium_upsell_card.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/pages/subscription_page/subscription_page_widget.dart';

/// Tarjeta "Hazte Premium" de la home. Solo se pinta para usuarios
/// gratuitos (decide quien la usa). Lleva a la pagina de suscripcion.
class PremiumUpsellCard extends StatelessWidget {
  const PremiumUpsellCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isSpanish = Localizations.localeOf(context).languageCode == 'es';
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16.0, 10.0, 16.0, 4.0),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SubscriptionPageWidget(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2D5A3D), Color(0xFF1E4030)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Row(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 22.0)),
              const SizedBox(width: 10.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSpanish ? 'Hazte Premium' : 'Go Premium',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isSpanish
                          ? 'Todos los cuentos, con audio y sin anuncios'
                          : 'Every tale, with audio and no ads',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 11.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10.0, vertical: 6.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8B04B),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  isSpanish ? 'VER' : 'VIEW',
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
      ),
    );
  }
}
```

- [ ] **Step 4: Widget test de TaleCoverCard**

Crear `test/tale_cover_card_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/backend/backend.dart';
import 'package:merakitales/components/tale_cover_card.dart';

Future<TalesRecord> makeTale({DateTime? createdAt}) async {
  final db = FakeFirebaseFirestore();
  final ref = db.collection('tales').doc('t1');
  await ref.set({
    'name': 'El dragon dormilon',
    'lang': 'es',
    'tale_id': 1,
    'is_premium_tale': true,
    'image_url_640px': 'https://example.com/x.png',
    if (createdAt != null) 'created_at': createdAt,
  });
  return TalesRecord.fromSnapshot(await ref.get());
}

Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('muestra candado cuando locked y el titulo del cuento',
      (tester) async {
    final tale = await makeTale();
    await tester.pumpWidget(wrap(TaleCoverCard(
      tale: tale,
      locked: true,
      size: 120,
      onTap: () {},
    )));
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(find.text('El dragon dormilon'), findsOneWidget);
  });

  testWidgets('sin candado cuando locked es false', (tester) async {
    final tale = await makeTale();
    await tester.pumpWidget(wrap(TaleCoverCard(
      tale: tale,
      locked: false,
      size: 120,
      onTap: () {},
    )));
    expect(find.byIcon(Icons.lock_rounded), findsNothing);
  });

  testWidgets('badge NUEVO solo con created_at reciente', (tester) async {
    final nuevo = await makeTale(createdAt: DateTime.now());
    await tester.pumpWidget(wrap(TaleCoverCard(
      tale: nuevo,
      locked: false,
      size: 120,
      onTap: () {},
    )));
    expect(find.text('NEW'), findsOneWidget); // MaterialApp de test va en 'en'

    final viejo =
        await makeTale(createdAt: DateTime.now().subtract(const Duration(days: 30)));
    await tester.pumpWidget(wrap(TaleCoverCard(
      tale: viejo,
      locked: false,
      size: 120,
      onTap: () {},
    )));
    expect(find.text('NEW'), findsNothing);
  });
}
```

Nota: `Image.network` en tests falla la petición HTTP y activa el `errorBuilder`; es esperado y no rompe los asserts (no se asserta la imagen).

- [ ] **Step 5: Correr tests y verificar**

Run: `flutter test test/tale_cover_card_test.dart && flutter analyze`
Expected: 3 tests PASS, analyze limpio.

- [ ] **Step 6: Commit**

```bash
git add lib/components/tale_cover_card.dart lib/components/shelf_row.dart lib/components/premium_upsell_card.dart test/tale_cover_card_test.dart
git commit -m "feat(home): widgets de portada, estanteria y upsell"
```

---

### Task 5: `openTale` — helper único de apertura con intersticial

**Files:**
- Create: `lib/services/tale_opener.dart`

**Interfaces:**
- Consumes: `FFAppState().TalesReadSinceLastIntersticialAdd`, `admob.showInterstitialAd()`, `admob.loadInterstitialAd(String, String, bool)`, `TailDetailWidget.routeName`, `serializeParam`.
- Produces: `Future<void> openTale(BuildContext context, TalesRecord tale)`.

- [ ] **Step 1: Crear `lib/services/tale_opener.dart`**

La lógica del contador es la que hoy vive en `tale_list_mobile_component_widget.dart:299-325` (movida tal cual, con guard de `context.mounted` tras el await):

```dart
import 'package:flutter/material.dart';

import '/app_state.dart';
import '/backend/backend.dart';
import '/flutter_flow/admob_util.dart' as admob;
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';

/// Abre el detalle de un cuento contando la apertura para el intersticial
/// (uno cada 5 aperturas), logica movida sin cambios desde la antigua lista.
Future<void> openTale(BuildContext context, TalesRecord tale) async {
  FFAppState().TalesReadSinceLastIntersticialAdd =
      FFAppState().TalesReadSinceLastIntersticialAdd + 1;
  if (FFAppState().TalesReadSinceLastIntersticialAdd >= 5) {
    final success = await admob.showInterstitialAd();

    admob.loadInterstitialAd(
      "ca-app-pub-6049242703708474/2634885084",
      "ca-app-pub-6049242703708474/1026289941",
      false,
    );

    if (success) {
      FFAppState().TalesReadSinceLastIntersticialAdd = 0;
    }
  }

  if (!context.mounted) return;
  context.pushNamed(
    TailDetailWidget.routeName,
    queryParameters: {
      'taleParameter': serializeParam(
        tale,
        ParamType.Document,
      ),
    }.withoutNulls,
    extra: <String, dynamic>{
      'taleParameter': tale,
    },
  );
}
```

- [ ] **Step 2: Verificar**

Run: `flutter analyze`
Expected: limpio. (Sin test: es un movimiento mecánico de código existente cuya única lógica — el contador — depende de estáticos de AdMob no testeables sin plataforma; queda cubierto por la verificación manual de Task 8.)

- [ ] **Step 3: Commit**

```bash
git add lib/services/tale_opener.dart
git commit -m "refactor(ads): helper unico para abrir cuentos con intersticial"
```

---

### Task 6: Página de categoría en cuadrícula

**Files:**
- Create: `lib/pages/category_page/category_page_widget.dart`

**Interfaces:**
- Consumes: `TaleCoverCard` (Task 4), `openTale` (Task 5), `PremiumProvider`, `FlutterFlowAdBanner`.
- Produces: `CategoryPageWidget({required String title, String? emoji, required List<TalesRecord> tales})` — se abre con `Navigator.push(MaterialPageRoute(...))`, recibe los cuentos ya cargados (no consulta Firestore).

- [ ] **Step 1: Crear `lib/pages/category_page/category_page_widget.dart`**

```dart
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
```

- [ ] **Step 2: Verificar**

Run: `flutter analyze && flutter test`
Expected: limpio y verde. (La página se prueba manualmente en Task 8 al navegar desde la home; no tiene lógica propia más allá del cálculo de columnas.)

- [ ] **Step 3: Commit**

```bash
git add lib/pages/category_page/category_page_widget.dart
git commit -m "feat(home): pagina de categoria en cuadricula responsive"
```

---

### Task 7: LibraryHome — la nueva home de estanterías + ruta `/`

**Files:**
- Create: `lib/pages/library_home/library_home_model.dart`
- Create: `lib/pages/library_home/library_home_widget.dart`
- Modify: `lib/flutter_flow/nav/nav.dart` (2 sitios donde se instancia `TaleListWidget()` + nueva FFRoute)
- Modify: `lib/index.dart`

**Interfaces:**
- Consumes: `buildShelves`/`Shelf`/`ShelfType` (Task 3), `ShelfRow`/`PremiumUpsellCard` (Task 4), `openTale` (Task 5), `CategoryPageWidget` (Task 6), `queryTalesRecord`/`queryCategoriesRecord` (Task 1), `DrawerComponentWidget`, `NativeAdListTile` (import `'/flutter_flow/flutter_flow_native_ad.dart'`), `FlutterFlowAdBanner`, `admob.loadInterstitialAd`.
- Produces: `LibraryHomeWidget` con `static String routeName = 'libraryHome'; static String routePath = '/libraryHome';` — pantalla inicial de la app.

- [ ] **Step 1: Crear `lib/pages/library_home/library_home_model.dart`**

```dart
import '/components/drawer_component_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/backend/backend.dart';
import 'library_home_widget.dart' show LibraryHomeWidget;
import 'package:flutter/material.dart';

class LibraryHomeModel extends FlutterFlowModel<LibraryHomeWidget> {
  // Model for drawerComponent component.
  late DrawerComponentModel drawerComponentModel;

  // Streams cacheados para no recrear la consulta en cada build.
  // Se regeneran solo cuando cambia el idioma.
  Stream<List<TalesRecord>>? _talesStream;
  String? _talesStreamLang;
  Stream<List<CategoriesRecord>>? _categoriesStream;

  Stream<List<TalesRecord>> talesStreamFor(String lang) {
    if (_talesStream == null || _talesStreamLang != lang) {
      _talesStreamLang = lang;
      _talesStream = queryTalesRecord(
        queryBuilder: (q) => q
            .where('lang', isEqualTo: lang)
            .orderBy('tale_id', descending: true),
      );
    }
    return _talesStream!;
  }

  Stream<List<CategoriesRecord>> categoriesStream() {
    _categoriesStream ??= queryCategoriesRecord(
      queryBuilder: (q) => q.orderBy('sort_order'),
    );
    return _categoriesStream!;
  }

  /// Fuerza la recreacion de streams (boton reintentar).
  void resetStreams() {
    _talesStream = null;
    _categoriesStream = null;
  }

  @override
  void initState(BuildContext context) {
    drawerComponentModel = createModel(context, () => DrawerComponentModel());
  }

  @override
  void dispose() {
    drawerComponentModel.dispose();
  }
}
```

- [ ] **Step 2: Crear `lib/pages/library_home/library_home_widget.dart`**

```dart
import 'dart:async';

import 'package:flutter/foundation.dart'
    show kDebugMode, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '/backend/backend.dart';
import '/components/drawer_component_widget.dart';
import '/components/premium_upsell_card.dart';
import '/components/shelf_row.dart';
import '/flutter_flow/admob_util.dart' as admob;
import '/flutter_flow/flutter_flow_ad_banner.dart';
import '/flutter_flow/flutter_flow_native_ad.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/category_page/category_page_widget.dart';
import '/services/shelf_builder.dart';
import '/services/subscription_service.dart';
import '/services/tale_opener.dart';
import 'library_home_model.dart';
export 'library_home_model.dart';

class LibraryHomeWidget extends StatefulWidget {
  const LibraryHomeWidget({super.key});

  static String routeName = 'libraryHome';
  static String routePath = '/libraryHome';

  @override
  State<LibraryHomeWidget> createState() => _LibraryHomeWidgetState();
}

class _LibraryHomeWidgetState extends State<LibraryHomeWidget> {
  late LibraryHomeModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LibraryHomeModel());

    // Precarga del intersticial, igual que hacia la antigua TaleListWidget.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      unawaited(
        () async {
          admob.loadInterstitialAd(
            "ca-app-pub-6049242703708474/2634885084",
            "ca-app-pub-6049242703708474/1026289941",
            false,
          );
        }(),
      );
    });
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  String _shelfTitle(Shelf shelf, bool isSpanish) {
    switch (shelf.type) {
      case ShelfType.novedades:
        return isSpanish ? '✨ Novedades' : '✨ New arrivals';
      case ShelfType.gratis:
        return isSpanish ? '🎁 Cuentos gratis' : '🎁 Free tales';
      case ShelfType.categoria:
        final c = shelf.category!;
        final name = isSpanish ? c.nameEs : c.nameEn;
        return c.emoji.isEmpty ? name : '${c.emoji} $name';
    }
  }

  void _openShelf(Shelf shelf, bool isSpanish) {
    String title;
    String? emoji;
    switch (shelf.type) {
      case ShelfType.novedades:
        title = isSpanish ? 'Novedades' : 'New arrivals';
        emoji = '✨';
        break;
      case ShelfType.gratis:
        title = isSpanish ? 'Cuentos gratis' : 'Free tales';
        emoji = '🎁';
        break;
      case ShelfType.categoria:
        title = isSpanish ? shelf.category!.nameEs : shelf.category!.nameEn;
        emoji = shelf.category!.emoji.isEmpty ? null : shelf.category!.emoji;
        break;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryPageWidget(
          title: title,
          emoji: emoji,
          tales: shelf.tales,
        ),
      ),
    );
  }

  Widget _loading() => Center(
        child: SizedBox(
          width: 50.0,
          height: 50.0,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              FlutterFlowTheme.of(context).primary,
            ),
          ),
        ),
      );

  Widget _error(bool isSpanish) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isSpanish
                  ? 'No se pudieron cargar los cuentos'
                  : 'Could not load the tales',
              style: GoogleFonts.plusJakartaSans(fontSize: 14.0),
            ),
            const SizedBox(height: 8.0),
            ElevatedButton(
              onPressed: () => setState(() => _model.resetStreams()),
              child: Text(isSpanish ? 'Reintentar' : 'Retry'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final isSpanish = Localizations.localeOf(context).languageCode == 'es';
    final lang = FFLocalizations.of(context).languageCode;
    final isPremiumUser = context.watch<PremiumProvider>().isPremium;
    final width = MediaQuery.sizeOf(context).width;
    final coverSize = width < 479
        ? 120.0
        : width < 767
            ? 140.0
            : 160.0;

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: const Color(0xFFF1F4F8),
      drawer: Drawer(
        elevation: 16.0,
        child: wrapWithModel(
          model: _model.drawerComponentModel,
          updateCallback: () => safeSetState(() {}),
          child: DrawerComponentWidget(),
        ),
      ),
      body: SafeArea(
        top: true,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFF2D5A3D),
              padding:
                  const EdgeInsetsDirectional.fromSTEB(4.0, 6.0, 16.0, 6.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu,
                        color: Colors.white, size: 28.0),
                    onPressed: () => scaffoldKey.currentState?.openDrawer(),
                  ),
                  Text(
                    'Meraki Tales',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 20.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<CategoriesRecord>>(
                stream: _model.categoriesStream(),
                builder: (context, catSnap) {
                  return StreamBuilder<List<TalesRecord>>(
                    stream: _model.talesStreamFor(lang),
                    builder: (context, talesSnap) {
                      if (catSnap.hasError || talesSnap.hasError) {
                        return _error(isSpanish);
                      }
                      if (!catSnap.hasData || !talesSnap.hasData) {
                        return _loading();
                      }
                      final shelves = buildShelves(
                        tales: talesSnap.data!,
                        categories: catSnap.data!,
                        isPremiumUser: isPremiumUser,
                      );

                      final rows = <Widget>[];
                      var shelvesPintadas = 0;
                      for (final shelf in shelves) {
                        rows.add(ShelfRow(
                          title: _shelfTitle(shelf, isSpanish),
                          tales: shelf.tales,
                          isPremiumUser: isPremiumUser,
                          coverSize: coverSize,
                          onTaleTap: (tale) => openTale(context, tale),
                          onVerMas: () => _openShelf(shelf, isSpanish),
                        ));
                        shelvesPintadas++;
                        if (shelvesPintadas == 1 && !isPremiumUser) {
                          rows.add(const PremiumUpsellCard());
                        }
                        if (shelvesPintadas % 3 == 0 &&
                            defaultTargetPlatform != TargetPlatform.android) {
                          rows.add(const NativeAdListTile());
                        }
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        itemCount: rows.length,
                        itemBuilder: (context, index) => rows[index],
                      );
                    },
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
```

- [ ] **Step 3: Registrar en navegación y exports**

En `lib/index.dart`, añadir:

```dart
export '/pages/library_home/library_home_widget.dart' show LibraryHomeWidget;
```

En `lib/flutter_flow/nav/nav.dart`:
1. Los DOS sitios que instancian `TaleListWidget()` (el `errorBuilder` del GoRouter ~línea 47 y el builder de la ruta `_initialize` ~línea 62) pasan a `LibraryHomeWidget()`.
2. Añadir la FFRoute nueva junto a las demás (después de la de HomePage):

```dart
        FFRoute(
          name: LibraryHomeWidget.routeName,
          path: LibraryHomeWidget.routePath,
          builder: (context, params) => LibraryHomeWidget(),
        ),
```

NO borrar todavía las rutas de `TaleListWidget`/`HomePageWidget` (eso es Task 8).

- [ ] **Step 4: Verificar**

Run: `flutter analyze && flutter test`
Expected: limpio y verde.

- [ ] **Step 5: Prueba de humo en simulador**

Run: `flutter run` (dispositivo/simulador que haya disponible; preguntar al usuario si hay duda).
Expected: la app arranca en la nueva home; se ve ✨ Novedades y 🎁 Cuentos gratis con los 30 cuentos actuales; tocar un cuento abre el detalle; el banner sale abajo (test ad en debug).

- [ ] **Step 6: Commit**

```bash
git add lib/pages/library_home/ lib/flutter_flow/nav/nav.dart lib/index.dart
git commit -m "feat(home): nueva home de estanterias responsive como pantalla inicial"
```

---

### Task 8: Selector de idioma al drawer + borrado del código muerto

**Files:**
- Modify: `lib/components/drawer_component_widget.dart`
- Modify: `lib/components/drawer_component_model.dart` (si hace falta campo para el dropdown)
- Delete: `lib/tale_list/tale_list_widget.dart`, `lib/tale_list/tale_list_model.dart`
- Delete: `lib/components/tale_list_mobile_component_widget.dart`, `tale_list_mobile_component_model.dart`, `tale_list_tablet_component_widget.dart`, `tale_list_tablet_component_model.dart`, `tale_list_large_component_widget.dart`, `tale_list_large_component_model.dart`
- Delete: `lib/pages/home_page/home_page_widget.dart`, `lib/pages/home_page/home_page_model.dart`
- Modify: `lib/flutter_flow/nav/nav.dart`, `lib/index.dart`

**Interfaces:**
- Consumes: `setAppLanguage(context, lang)` (`flutter_flow_util.dart:286`), `FFAppState().updateLanguage`.
- Produces: nada nuevo; deja el árbol sin referencias a los widgets borrados.

- [ ] **Step 1: Añadir selector de idioma al drawer**

En `lib/components/drawer_component_widget.dart`, después del bloque del botón premium (el `Padding` que termina ~línea 155, verificar cierre exacto), añadir como siguiente hijo del `Column`:

```dart
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 12.0),
              child: Row(
                children: [
                  const Icon(Icons.language_rounded,
                      color: Color(0xFF57636C), size: 22.0),
                  const SizedBox(width: 10.0),
                  Text(
                    isSpanish ? 'Idioma' : 'Language',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF15161E),
                    ),
                  ),
                  const Spacer(),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'es', label: Text('ES')),
                      ButtonSegment(value: 'en', label: Text('EN')),
                    ],
                    selected: {
                      Localizations.localeOf(context).languageCode == 'es'
                          ? 'es'
                          : 'en'
                    },
                    onSelectionChanged: (selection) {
                      setAppLanguage(context, selection.first);
                      FFAppState().updateLanguage =
                          FFAppState().updateLanguage + 1;
                      FFAppState().update(() {});
                    },
                  ),
                ],
              ),
            ),
```

Notas: el widget ya define `isSpanish` para el botón premium (verificar el nombre exacto de la variable local; si no existe en ese scope, declararla igual que arriba). Comprobar que los imports de `flutter_flow_util.dart` (para `setAppLanguage`), `app_state.dart` y `google_fonts` ya están en el archivo; añadirlos si faltan.

- [ ] **Step 2: Buscar referencias vivas antes de borrar**

Run: `grep -rn "TaleListWidget\|taleList\|HomePageWidget\|tale_list_mobile\|tale_list_tablet\|tale_list_large" lib/ --include="*.dart" | grep -v "lib/tale_list/\|tale_list_mobile_component\|tale_list_tablet_component\|tale_list_large_component\|lib/pages/home_page/"`

Expected: solo `nav.dart` y `lib/index.dart` (que se limpian en el paso siguiente). Si aparece CUALQUIER otro sitio (p. ej. el drawer navegando a `taleList`), sustituir esa navegación por `context.goNamed(LibraryHomeWidget.routeName)` antes de borrar nada.

- [ ] **Step 3: Borrar archivos y limpiar referencias**

```bash
git rm lib/tale_list/tale_list_widget.dart lib/tale_list/tale_list_model.dart
git rm lib/components/tale_list_mobile_component_widget.dart lib/components/tale_list_mobile_component_model.dart
git rm lib/components/tale_list_tablet_component_widget.dart lib/components/tale_list_tablet_component_model.dart
git rm lib/components/tale_list_large_component_widget.dart lib/components/tale_list_large_component_model.dart
git rm lib/pages/home_page/home_page_widget.dart lib/pages/home_page/home_page_model.dart
```

En `lib/flutter_flow/nav/nav.dart`: eliminar las FFRoute de `TaleListWidget` y `HomePageWidget` enteras.

En `lib/index.dart`: eliminar los exports de `home_page_widget.dart` y `tale_list_widget.dart`. Queda:

```dart
// Export pages
export '/pages/library_home/library_home_widget.dart' show LibraryHomeWidget;
export '/tail_detail/tail_detail_widget.dart' show TailDetailWidget;
```

Revisar también `test/widget_test.dart`: si referencia alguno de los widgets borrados, actualizarlo para apuntar a `LibraryHomeWidget` o eliminar el test si es el contador de plantilla de Flutter.

- [ ] **Step 4: Verificar**

Run: `flutter analyze && flutter test`
Expected: limpio y verde, sin referencias rotas.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore(home): selector de idioma al drawer y borrado de las listas antiguas"
```

---

### Task 9: Verificación final contra los criterios del spec

**Files:**
- Ninguno nuevo (correcciones menores si la verificación las destapa).

- [ ] **Step 1: Suite completa**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` y todos los tests PASS.

- [ ] **Step 2: Verificación manual con el usuario (checklist del spec)**

Run: `flutter run` y repasar con Juan:

1. La home muestra estanterías en el orden definido (Novedades → upsell → Gratis → categorías) en ES; cambiar idioma desde el drawer y comprobar EN.
2. Las categorías con cuentos aparecen con emoji + nombre localizado; las vacías no salen. (Si aún no hay cuentos premium con categoría en Firestore, comprobar que la home se ve bien solo con Novedades + Gratis.)
3. "ver más" (solo visible si la sección supera 10) abre la cuadrícula y se ve bien rotando/en tablet si hay uno a mano.
4. Abrir un cuento premium como usuario gratuito muestra el teaser y NO consume cupo (abrir 8 teasers seguidos: ninguno bloquea; luego un cuento gratis sigue abriéndose).
5. Tocar cuentos gratis descuenta cupo con normalidad (comportamiento previo intacto).
6. El intersticial salta aproximadamente cada 5 aperturas (con test ads en debug).
7. El banner inferior aparece en home y página de categoría (test ad en debug).

- [ ] **Step 3: Cierre de rama**

Al terminar la verificación, usar la skill `superpowers:finishing-a-development-branch` (merge a main + push + limpieza de rama, y preguntar a Juan si toca desplegar, según su protocolo).
