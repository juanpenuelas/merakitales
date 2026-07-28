# Categorías Enriquecidas — Plan de Implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Descripciones ES/EN en categorías (admin + cabecera de página de categoría en la app) y selector de categoría para cuentos premium ya publicados en el admin.

**Architecture:** Admin escribe Firestore directamente (patrón existente de `CategoriesService`/`DraftsService`); la asignación localiza los docs ES y EN por `tale_id`+`lang` y los actualiza en batch. La app móvil solo lee: `CategoriesRecord` gana dos campos y la página de categoría un parámetro opcional. Cero cambios en Cloud Functions.

**Tech Stack:** Flutter, cloud_firestore 5.6.9, fake_cloud_firestore ^3.0.2 (ya en dev_dependencies).

**Spec:** `docs/superpowers/specs/2026-07-28-categorias-enriquecidas-design.md`

## Global Constraints

- Rama de trabajo: `feature/categorias-enriquecidas` (ya creada). Commits en español sin acentos, estilo conventional.
- Decisión de producto: SOLO los cuentos con `is_premium_tale == true` muestran selector de categoría. Los gratuitos jamás.
- Admin UI en español (monolingüe); strings nuevos de la app móvil con patrón inline `isSpanish` + ternario; NO tocar `internationalization.dart`.
- Cero dependencias nuevas (ni runtime ni dev).
- Baselines actuales de main: `flutter analyze` = **27 issues** (cero nuevos permitidos); `flutter test` = **55 tests** en verde.
- TDD donde la tarea lo indique, con evidencia RED/GREEN en el report.
- Campos Firestore exactos: `description_es`, `description_en` (categories), `category_id` (tales).

---

### Task 1: Admin — descripción en Category (modelo + servicio + diálogo)

**Files:**
- Modify: `lib/admin/models/category.dart`
- Modify: `lib/admin/services/categories_service.dart`
- Modify: `lib/admin/categories/category_editor_dialog.dart`
- Modify: `lib/admin/categories/categories_page.dart:17-25` (2 call sites)
- Test: `test/admin/category_editor_dialog_test.dart` (extender el test existente)

**Interfaces:**
- Consumes: `Category`, `CategoryFormResult`, `showCategoryEditor` existentes.
- Produces: `Category.descriptionEs`/`.descriptionEn` (String, `''` por defecto); `CategoryFormResult.descriptionEs`/`.descriptionEn`; `createCategory`/`updateCategory` con parámetros `descriptionEs`/`descriptionEn` requeridos.

- [ ] **Step 1: Extender el test del diálogo (RED)**

En `test/admin/category_editor_dialog_test.dart`, dentro del testWidgets existente, tras la línea `await tester.enterText(find.byKey(const Key('cat_emoji')), '🗺️');` añadir:

```dart
    await tester.enterText(find.byKey(const Key('cat_desc_es')), 'Aventuras y mapas');
    await tester.enterText(find.byKey(const Key('cat_desc_en')), 'Adventures and maps');
```

y tras `expect(result!.slug, 'aventuras');` añadir:

```dart
    expect(result!.descriptionEs, 'Aventuras y mapas');
    expect(result!.descriptionEn, 'Adventures and maps');
```

Y al final del `main()` del mismo archivo, un test nuevo de `Category.fromDoc` (imports nuevos: `package:fake_cloud_firestore/fake_cloud_firestore.dart` y `package:merakitales/admin/models/category.dart`):

```dart
  test('Category.fromDoc parsea descripciones y tolera su ausencia', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('categories').doc('con').set({
      'name_es': 'Mar',
      'name_en': 'Sea',
      'emoji': '🌊',
      'slug': 'mar',
      'sort_order': 1,
      'description_es': 'Aventuras acuáticas',
      'description_en': 'Water adventures',
    });
    await db.collection('categories').doc('sin').set({
      'name_es': 'Humor',
      'name_en': 'Humor',
      'emoji': '😂',
      'slug': 'humor',
      'sort_order': 2,
    });

    final con = Category.fromDoc(await db.collection('categories').doc('con').get());
    final sin = Category.fromDoc(await db.collection('categories').doc('sin').get());

    expect(con.descriptionEs, 'Aventuras acuáticas');
    expect(con.descriptionEn, 'Water adventures');
    expect(sin.descriptionEs, '');
    expect(sin.descriptionEn, '');
  });
```

- [ ] **Step 2: Verificar que falla**

Run: `flutter test test/admin/category_editor_dialog_test.dart`
Expected: FAIL de compilación — `descriptionEs` no existe en `CategoryFormResult`, `cat_desc_es` no existe.

- [ ] **Step 3: Implementar**

`lib/admin/models/category.dart` — añadir a la clase (tras `slug`):

```dart
  final String descriptionEs;
  final String descriptionEn;
```

al constructor: `this.descriptionEs = '', this.descriptionEn = '',` y a `fromDoc` (tras `slug:`):

```dart
      descriptionEs: d['description_es'] as String? ?? '',
      descriptionEn: d['description_en'] as String? ?? '',
```

`lib/admin/categories/category_editor_dialog.dart`:
- `CategoryFormResult`: añadir `final String descriptionEs, descriptionEn;` + parámetros required en el constructor.
- Estado: añadir controllers `_descEs`, `_descEn` inicializados con `e?.descriptionEs ?? ''` / `e?.descriptionEn ?? ''`, incluidos en el dispose loop.
- En el `Column` del diálogo, tras el campo Slug (antes de Orden):

```dart
          const SizedBox(height: AppSpacing.sm),
          TextField(key: const Key('cat_desc_es'), controller: _descEs, decoration: const InputDecoration(labelText: 'Descripción (ES)')),
          const SizedBox(height: AppSpacing.sm),
          TextField(key: const Key('cat_desc_en'), controller: _descEn, decoration: const InputDecoration(labelText: 'Descripción (EN)')),
```

- En el `CategoryFormResult` del botón Guardar: `descriptionEs: _descEs.text.trim(), descriptionEn: _descEn.text.trim(),`

`lib/admin/services/categories_service.dart` — `createCategory` y `updateCategory` ganan `required String descriptionEs, required String descriptionEn,` y escriben `'description_es': descriptionEs, 'description_en': descriptionEn,` en sus mapas.

`lib/admin/categories/categories_page.dart` — en los 2 call sites (líneas 19 y 25) añadir `descriptionEs: r.descriptionEs, descriptionEn: r.descriptionEn,`.

- [ ] **Step 4: Verificar en verde**

Run: `flutter test test/admin/category_editor_dialog_test.dart && flutter analyze && flutter test`
Expected: test del diálogo PASS, analyze 27 (cero nuevos), suite completa verde (55).

- [ ] **Step 5: Commit**

```bash
git add lib/admin/models/category.dart lib/admin/services/categories_service.dart lib/admin/categories/category_editor_dialog.dart lib/admin/categories/categories_page.dart test/admin/category_editor_dialog_test.dart
git commit -m "feat(admin): descripcion ES/EN en categorias"
```

---

### Task 2: Admin — categoryId en PublishedTale + updatePublishedTaleCategory (TDD)

**Files:**
- Modify: `lib/admin/models/published_tale.dart`
- Modify: `lib/admin/services/drafts_service.dart`
- Test: `test/admin/published_tale_category_test.dart` (nuevo)

**Interfaces:**
- Consumes: patrón `getPublishedTale` de `DraftsService` (lookup por `tale_id`+`lang`).
- Produces: `PublishedTale.categoryId` (String?, null si ausente); `DraftsService({FirebaseFirestore? db})` (inyección para tests, default `FirebaseFirestore.instance`); `Future<void> updatePublishedTaleCategory({required int taleId, required String? categoryId})`.

- [ ] **Step 1: Escribir el test (RED)**

Crear `test/admin/published_tale_category_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/admin/models/published_tale.dart';
import 'package:merakitales/admin/services/drafts_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late DraftsService service;

  Future<void> seedTale(int taleId, String lang, {String? categoryId}) async {
    await db.collection('tales').add({
      'tale_id': taleId,
      'lang': lang,
      'name': 'Cuento $taleId $lang',
      'is_premium_tale': true,
      if (categoryId != null) 'category_id': categoryId,
    });
  }

  Future<String?> categoryOf(int taleId, String lang) async {
    final q = await db
        .collection('tales')
        .where('tale_id', isEqualTo: taleId)
        .where('lang', isEqualTo: lang)
        .get();
    return q.docs.first.data()['category_id'] as String?;
  }

  setUp(() {
    db = FakeFirebaseFirestore();
    service = DraftsService(db: db);
  });

  test('asignar categoria actualiza los docs ES y EN', () async {
    await seedTale(7, 'es');
    await seedTale(7, 'en');

    await service.updatePublishedTaleCategory(taleId: 7, categoryId: 'piratas');

    expect(await categoryOf(7, 'es'), 'piratas');
    expect(await categoryOf(7, 'en'), 'piratas');
  });

  test('asignar null limpia la categoria en ambos docs', () async {
    await seedTale(8, 'es', categoryId: 'piratas');
    await seedTale(8, 'en', categoryId: 'piratas');

    await service.updatePublishedTaleCategory(taleId: 8, categoryId: null);

    expect(await categoryOf(8, 'es'), isNull);
    expect(await categoryOf(8, 'en'), isNull);
  });

  test('con un solo doc existente actualiza ese y no lanza', () async {
    await seedTale(9, 'es');

    await service.updatePublishedTaleCategory(taleId: 9, categoryId: 'humor');

    expect(await categoryOf(9, 'es'), 'humor');
  });

  test('PublishedTale.fromDoc parsea category_id y tolera su ausencia',
      () async {
    await seedTale(10, 'es', categoryId: 'humor');
    await seedTale(11, 'es');
    final docs = await db
        .collection('tales')
        .where('lang', isEqualTo: 'es')
        .get();
    final tales = docs.docs.map(PublishedTale.fromDoc).toList();

    expect(tales.firstWhere((t) => t.taleId == 10).categoryId, 'humor');
    expect(tales.firstWhere((t) => t.taleId == 11).categoryId, isNull);
  });
}
```

- [ ] **Step 2: Verificar que falla**

Run: `flutter test test/admin/published_tale_category_test.dart`
Expected: FAIL de compilación — `DraftsService` no acepta `db:`, `updatePublishedTaleCategory` y `categoryId` no existen.

- [ ] **Step 3: Implementar**

`lib/admin/models/published_tale.dart` — en `PublishedTale`: añadir `final String? categoryId;` + `this.categoryId,` en el constructor + en `fromDoc`: `categoryId: d['category_id'] as String?,`.

`lib/admin/services/drafts_service.dart`:
- Cambiar `final _db = FirebaseFirestore.instance;` por:

```dart
  final FirebaseFirestore _db;
  DraftsService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;
```

(Verificar el nombre real del campo en el archivo antes de editar; los call sites existentes `DraftsService()` siguen compilando sin cambios.)
- Añadir junto a `getPublishedTale`:

```dart
  /// Asigna (o limpia, con null) la categoria de un cuento publicado,
  /// actualizando los documentos ES y EN localizados por tale_id+lang.
  Future<void> updatePublishedTaleCategory({
    required int taleId,
    required String? categoryId,
  }) async {
    final q = await _db
        .collection('tales')
        .where('tale_id', isEqualTo: taleId)
        .get();
    final batch = _db.batch();
    for (final doc in q.docs) {
      batch.update(doc.reference, {'category_id': categoryId});
    }
    await batch.commit();
  }
```

- [ ] **Step 4: Verificar en verde**

Run: `flutter test test/admin/published_tale_category_test.dart && flutter analyze && flutter test`
Expected: 4 tests PASS, analyze 27, suite completa verde.

- [ ] **Step 5: Commit**

```bash
git add lib/admin/models/published_tale.dart lib/admin/services/drafts_service.dart test/admin/published_tale_category_test.dart
git commit -m "feat(admin): asignar categoria a cuentos publicados en el servicio"
```

---

### Task 3: Admin — dropdown de categoría en la lista de publicados

**Files:**
- Modify: `lib/admin/published/published_list_page.dart`

**Interfaces:**
- Consumes: `updatePublishedTaleCategory` (Task 2), `PublishedTale.categoryId` (Task 2), `CategoriesService.streamCategories()` y `Category` (existentes; `Category.id`, `.emoji`, `.nameEs`).

- [ ] **Step 1: Implementar**

En `lib/admin/published/published_list_page.dart`:

1. Imports nuevos: `../services/categories_service.dart`, `../models/category.dart`.
2. Estado: añadir `final _categoriesService = CategoriesService();`.
3. Envolver el `StreamBuilder<List<PublishedTale>>` actual con un `StreamBuilder<List<Category>>`:

```dart
          : StreamBuilder<List<Category>>(
              stream: _categoriesService.streamCategories(),
              builder: (context, catSnap) {
                final categories = catSnap.data ?? [];
                return StreamBuilder<List<PublishedTale>>(
                  // ... el StreamBuilder existente, intacto por dentro,
                  // salvo el itemBuilder del paso 4 ...
                );
              },
            ),
```

4. En el `itemBuilder`, el `trailing:` del `TaleRowCard` pasa de `TextButton.icon(...)` a:

```dart
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (t.isPremiumTale) ...[
                            DropdownButton<String?>(
                              key: Key('cat_dd_${t.taleId}'),
                              value: categories.any((c) => c.id == t.categoryId)
                                  ? t.categoryId
                                  : null,
                              hint: const Text('Sin categoría'),
                              underline: const SizedBox.shrink(),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Sin categoría'),
                                ),
                                for (final c in categories)
                                  DropdownMenuItem<String?>(
                                    value: c.id,
                                    child: Text(
                                      '${c.emoji} ${c.nameEs}'.trim(),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (value) => _setCategory(t, value),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                          TextButton.icon(
                            onPressed: () => _retract(t),
                            icon: const Icon(Icons.undo),
                            label: const Text('Retirar'),
                          ),
                        ],
                      ),
```

5. Método nuevo en el State (junto a `_retract`):

```dart
  Future<void> _setCategory(PublishedTale tale, String? categoryId) async {
    try {
      await _service.updatePublishedTaleCategory(
          taleId: tale.taleId, categoryId: categoryId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Categoría actualizada para "${tale.name}"')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
```

Notas: el stream de publicados refresca la fila solo (snapshots). Sin spinner de bloqueo: la escritura es rápida y el snackbar confirma. Los cuentos gratuitos ven solo el botón Retirar, como hoy.

- [ ] **Step 2: Verificar**

Run: `flutter analyze && flutter test`
Expected: analyze 27 (cero nuevos), suite verde. (Sin test propio: cableado de UI sobre el servicio ya testeado en Task 2; verificación manual en Task 5.)

- [ ] **Step 3: Commit**

```bash
git add lib/admin/published/published_list_page.dart
git commit -m "feat(admin): dropdown de categoria en publicados premium"
```

---

### Task 4: Móvil — descripciones en CategoriesRecord y cabecera de categoría

**Files:**
- Modify: `lib/backend/schema/categories_record.dart`
- Modify: `lib/pages/library_home/library_home_widget.dart` (`_openShelf`)
- Modify: `lib/pages/category_page/category_page_widget.dart`
- Test: `test/category_page_header_test.dart` (nuevo)

**Interfaces:**
- Consumes: `CategoriesRecord` (patrón de campos existente), `CategoryPageWidget({title, emoji, tales})`, `Shelf`/`ShelfType`, `PremiumProvider`.
- Produces: `CategoriesRecord.descriptionEs`/`.descriptionEn` (String, `''` default); `CategoryPageWidget` con parámetro nuevo `String? description`.

- [ ] **Step 1: Escribir el test de la cabecera (RED)**

Crear `test/category_page_header_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/pages/category_page/category_page_widget.dart';
import 'package:merakitales/services/subscription_service.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class MockPremiumProvider extends ChangeNotifier implements PremiumProvider {
  @override
  bool isPremium = true; // premium: el banner de ads se auto-oculta y no toca plugins

  @override
  bool get isLoadingOfferings => false;
  @override
  Offerings? get offerings => null;
  @override
  CustomerInfo? get customerInfo => null;
  @override
  Future<void> init() async {}
  @override
  Future<void> loadOfferings() async {}
  @override
  Future<bool> purchasePackage(Package package) async => false;
  @override
  Future<bool> restorePurchases() async => false;
  @override
  Future<void> updatePremiumStatus(bool isPremiumStatus) async {}
}

Widget wrap(Widget child) => ChangeNotifierProvider<PremiumProvider>.value(
      value: MockPremiumProvider(),
      child: MaterialApp(home: child),
    );

void main() {
  testWidgets('cabecera con descripcion: "N tales · descripcion"',
      (tester) async {
    await tester.pumpWidget(wrap(const CategoryPageWidget(
      title: 'Mar y piratas',
      emoji: '🏴‍☠️',
      tales: [],
      description: 'Aventuras acuáticas',
    )));
    expect(find.text('0 tales · Aventuras acuáticas'), findsOneWidget);
  });

  testWidgets('cabecera sin descripcion: solo "N tales"', (tester) async {
    await tester.pumpWidget(wrap(const CategoryPageWidget(
      title: 'Mar y piratas',
      emoji: '🏴‍☠️',
      tales: [],
    )));
    expect(find.text('0 tales'), findsOneWidget);
  });
}
```

Nota: el `MaterialApp` de test corre en locale `en` → el literal esperado usa "tales". `MockPremiumProvider.isPremium = true` evita que `FlutterFlowAdBanner` toque el plugin de ads en el test (se auto-oculta).

- [ ] **Step 2: Verificar que falla**

Run: `flutter test test/category_page_header_test.dart`
Expected: FAIL de compilación — `description` no existe en `CategoryPageWidget`.

- [ ] **Step 3: Implementar**

`lib/backend/schema/categories_record.dart` — añadir los campos `description_es`/`description_en` siguiendo el patrón exacto (4 sitios): bloque de campo con getter `descriptionEs`/`descriptionEn` (default `''`) + `hasDescriptionEs()`/`hasDescriptionEn()`, `_initializeFields`, `createCategoriesRecordData` (parámetros + mapa), y la clase Equality (`equals` y `hash`).

`lib/pages/category_page/category_page_widget.dart`:
- Constructor: añadir `this.description,` y `final String? description;`.
- La fila del contador pasa de `'${tales.length} ${isSpanish ? 'cuentos' : 'tales'}'` a:

```dart
                  (description == null || description!.isEmpty)
                      ? '${tales.length} ${isSpanish ? 'cuentos' : 'tales'}'
                      : '${tales.length} ${isSpanish ? 'cuentos' : 'tales'} · ${description!}',
```

`lib/pages/library_home/library_home_widget.dart` — en `_openShelf`, junto a title/emoji, derivar y pasar la descripción:

```dart
    String? description;
```

en el case `ShelfType.categoria`:

```dart
        final desc = isSpanish
            ? shelf.category!.descriptionEs
            : shelf.category!.descriptionEn;
        description = desc.isEmpty ? null : desc;
```

(novedades y gratis dejan `description` en null) y en el constructor de la página: `description: description,`.

- [ ] **Step 4: Verificar en verde**

Run: `flutter test test/category_page_header_test.dart && flutter analyze && flutter test`
Expected: 2 tests PASS, analyze 27, suite completa verde.

- [ ] **Step 5: Commit**

```bash
git add lib/backend/schema/categories_record.dart lib/pages/category_page/category_page_widget.dart lib/pages/library_home/library_home_widget.dart test/category_page_header_test.dart
git commit -m "feat(app): descripcion de categoria en la cabecera de la cuadricula"
```

---

### Task 5: Verificación final y cierre

**Files:** ninguno nuevo (correcciones menores si la verificación las destapa).

- [ ] **Step 1: Suite completa**

Run: `flutter analyze && flutter test`
Expected: 27 issues (cero nuevos) y todos los tests PASS (55 base + 6 nuevos + el del diálogo extendido).

- [ ] **Step 2: Review final de rama**

Review whole-branch (base = merge-base con main) con foco en: regla premium-only respetada en la UI, batch de escritura ES+EN, retrocompatibilidad de categorías sin descripción, y que la home no muestra descripciones.

- [ ] **Step 3: Verificación manual con el usuario**

1. Admin: editar una categoría existente y añadirle descripción ES/EN; crear una nueva con descripción. Las antiguas sin descripción siguen funcionando.
2. Admin: en Publicados, "El faro y la luna" (premium) muestra el dropdown; asignarle una categoría. Un cuento gratuito no muestra dropdown.
3. App: la estantería de esa categoría aparece en la home con el cuento dentro (con candado); "ver más" muestra "N cuentos · descripción" en ES y EN.
4. Admin: reasignar a "Sin categoría" y comprobar que la estantería desaparece de la app.

- [ ] **Step 4: Cierre de rama**

Usar `superpowers:finishing-a-development-branch` (merge a main + push + borrado de rama; preguntar por deploy — este cambio SÍ toca el admin: si el admin está desplegado en Firebase Hosting, recordar el build de hosting según el protocolo del usuario).
