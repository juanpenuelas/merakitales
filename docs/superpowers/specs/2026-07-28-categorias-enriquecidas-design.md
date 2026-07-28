# Categorías enriquecidas: descripción + asignación a premium publicados

**Fecha:** 2026-07-28
**Estado:** aprobado por Juan (diseño compacto validado en conversación)
**Alcance:** admin CMS + app móvil (lectura). No toca Cloud Functions, marketing site ni paywall.

## Contexto

Tras el rediseño de la home en estanterías (merge `3b6d8a8`), las categorías son visibles
en la app y son territorio exclusivamente premium (decisión de producto registrada:
los ~30 cuentos gratuitos nunca llevan categoría). Dos huecos detectados:

1. Un cuento premium publicado sin categoría (caso real: *"El faro y la luna"*) solo
   aparece en "Novedades" mientras es reciente; después desaparece de la home. El admin
   hoy no puede asignar categoría a un cuento ya publicado (solo en borradores).
2. Las categorías solo tienen nombre y emoji; una descripción corta enriquecería la
   cabecera de la página de categoría y sirve de guía editorial.

## Decisiones

- **Solo los cuentos premium** (`is_premium_tale == true`) muestran selector de
  categoría en el admin. Los gratuitos no — regla de producto, la UI la respeta.
- La descripción se muestra **solo en la cabecera de la página de categoría** de la
  app; nunca en las estanterías de la home. Gratis y Novedades no llevan descripción.
- Sin cambios en Cloud Functions: el admin escribe Firestore directamente (patrón
  actual de `CategoriesService`).
- **Reglas de Firestore** (decisión de Juan, 2026-07-28, descubierto en implementación):
  `tales` bloqueaba todo write de cliente. Se añade una regla estrecha: el UID admin
  puede hacer `update` de `tales` limitado al campo `category_id`
  (`affectedKeys().hasOnly(['category_id'])`). Requiere
  `firebase deploy --only firestore:rules` al cerrar la rama.

## Diseño — datos (Firestore)

- `categories`: campos nuevos opcionales `description_es`, `description_en`
  (string, default `''`). Documentos existentes sin el campo siguen siendo válidos.
- `tales`: sin campos nuevos (`category_id` ya existe). La asignación escribe
  `category_id` en **los dos documentos** del cuento (ES y EN, localizados por
  `tale_id` + `lang`, igual que `getPublishedTale`). Valor `null` = "Sin categoría".

## Diseño — admin CMS

### Descripción de categoría
- `lib/admin/models/category.dart`: campos `descriptionEs`, `descriptionEn`
  (default `''`) + parseo en `fromDoc`.
- `lib/admin/categories/category_editor_dialog.dart`: dos campos de texto nuevos
  (ES/EN), una línea, opcionales.
- `lib/admin/services/categories_service.dart`: `createCategory`/`updateCategory`
  ganan los dos parámetros y los escriben.

### Categoría en premium publicados
- `lib/admin/models/published_tale.dart`: `PublishedTale` gana `categoryId`
  (String?, parseado de `category_id`).
- `lib/admin/services/drafts_service.dart` (dueño de las operaciones de publicados):
  nuevo método

  ```dart
  Future<void> updatePublishedTaleCategory({
    required int taleId,
    required String? categoryId,
  })
  ```

  que localiza los docs ES y EN por `tale_id`+`lang` (mismo patrón que
  `getPublishedTale`) y actualiza `category_id` en ambos con un `WriteBatch`.
  Si falta uno de los dos docs (no debería), actualiza el que exista.
- `lib/admin/published/published_list_page.dart`: en cada fila de cuento
  **premium**, un `DropdownButton<String?>` compacto junto al botón de retirar,
  con las categorías (emoji + nombre ES, orden `sort_order`, vía
  `CategoriesService.streamCategories()`) más la opción "Sin categoría" (null).
  Valor actual = `categoryId` del cuento; al cambiar llama al método nuevo.
  Si el `categoryId` del cuento no existe ya en la lista de categorías (borrada),
  el dropdown muestra "Sin categoría" y la primera reasignación lo corrige.
  Los cuentos gratuitos no muestran el selector.

## Diseño — app móvil

- `lib/backend/schema/categories_record.dart`: parsear `description_es`,
  `description_en` (mismo patrón de campos existente).
- `lib/pages/library_home/library_home_widget.dart`: `_openShelf` pasa la
  descripción localizada (`description_es`/`description_en` según idioma) a la
  página de categoría; para Gratis/Novedades pasa `null`.
- `lib/pages/category_page/category_page_widget.dart`: parámetro nuevo opcional
  `description` (String?). En la fila de contador, si hay descripción:
  `"N cuentos · descripción"`; si no, `"N cuentos"` como hoy.
- Nada más cambia: la aparición de estanterías al categorizar ya funciona.

## Tests

- Unit (admin, con `fake_cloud_firestore` ya presente en dev_dependencies):
  `updatePublishedTaleCategory` actualiza `category_id` en ambos docs (ES y EN);
  asignar `null` lo limpia; con un solo doc existente no explota.
- Unit (admin): `Category.fromDoc` parsea descripciones y tolera su ausencia.
- Widget (móvil): la cabecera de la página de categoría muestra
  `"N cuentos · descripción"` con descripción y `"N cuentos"` sin ella.
- Los 55 tests existentes siguen en verde.

## Fuera de alcance (deliberado)

Asignación de categorías en lote, avisos al borrar una categoría con cuentos
asignados, selector de categoría para cuentos gratuitos, descripciones en las
estanterías de la home, cambios en Cloud Functions o en el paywall.

## Criterios de aceptación

1. En el admin puedo crear/editar una categoría con descripción ES/EN, y las
   categorías existentes sin descripción siguen funcionando.
2. En la lista de publicados del admin, cada cuento premium tiene un dropdown de
   categoría (con "Sin categoría"); los gratuitos no lo tienen.
3. Cambiar la categoría actualiza los documentos ES y EN del cuento; la estantería
   correspondiente aparece en la home de la app con el cuento dentro.
4. La página de categoría de la app muestra "N cuentos · descripción" cuando la
   categoría tiene descripción en el idioma activo, y "N cuentos" cuando no.
5. `flutter analyze` sin issues nuevos y `flutter test` en verde (55 existentes +
   los nuevos).
