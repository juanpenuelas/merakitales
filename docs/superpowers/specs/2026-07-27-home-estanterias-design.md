# Rediseño de la home: biblioteca en estanterías

**Fecha:** 2026-07-27
**Estado:** aprobado por Juan (brainstorming con mockups visuales)
**Alcance:** app móvil (lector). No toca admin CMS, marketing site, Cloud Functions ni paywall.

## Contexto y problema

La home actual (`TaleListWidget` → `tale_list_mobile/tablet/large_component_widget`) es un
scroll vertical infinito con todos los cuentos del idioma activo ordenados por `tale_id`
descendente. Con el catálogo que viene, ese formato deja de funcionar:

- **Hoy:** 30 cuentos publicados (ES y EN), todos gratuitos y sin categoría.
- **Plan:** ~100 cuentos nuevos, todos premium y con categoría (~8-10 por categoría,
  ~12 categorías), publicando 1-3 por semana.
- El 77% del catálogo acabará siendo premium: sin secciones claras, el usuario gratuito
  siente la app como una trampa de teasers; con secciones, el catálogo premium visible es
  el mejor escaparate de venta.

La infraestructura de categorías ya existe a medias: el admin gestiona la colección
`categories` (`name_es`, `name_en`, `emoji`, `slug`, `sort_order`), los borradores llevan
`category_id` y la Cloud Function `approveDraft` **ya escribe `category_id` en los
documentos de `tales`**. La app móvil simplemente no lee ese campo.

## Decisiones de producto (validadas)

1. **Estructura elegida: estanterías (patrón Netflix).** Scroll vertical de secciones;
   cada sección es un carrusel horizontal de portadas. Se descartaron: lista actual +
   chips de filtro (esconde categorías, chips interminables) y portada de cuadrícula de
   categorías (cuentos a 2 taps, decepciona con catálogo escaso).
2. **Los 30 cuentos gratuitos actuales no llevan categoría** y forman su propia
   estantería. Las categorías son territorio exclusivamente premium. Sin backfill.
3. **El teaser premium se mantiene tal cual:** 100 palabras + degradado + botón
   "Desbloquear Cuento". El audio sigue siendo solo premium.
4. **Fix del cupo semanal:** abrir un teaser premium NO consume el cupo de 7 lecturas
   gratis/semana ni puede ser bloqueado por el modal de límite. El cupo aplica solo a
   lecturas completas de cuentos gratuitos por usuarios no premium.
5. **Una sola home responsive** que sustituye a las tres variantes duplicadas
   (mobile/tablet/large).
6. **Catálogo premium visible para todos** con candado en la portada; tocar → teaser.

## Diseño de la home

Orden de secciones (usuario **gratuito**):

1. **Cabecera compacta**: hamburguesa (drawer) + marca. Desaparecen la foto de 140px y
   el dropdown de idioma; el selector de idioma se muda al drawer existente.
2. **✨ Novedades**: los 10 cuentos más recientes del idioma (gratis y premium
   mezclados), orden `tale_id` desc. Con 1-3 publicaciones/semana siempre está fresca.
3. **Tarjeta "Hazte Premium"**: una sola vez, solo para usuarios gratuitos. Estilo
   destacado (fondo verde, CTA ámbar), lleva a la página de suscripción actual.
4. **🎁 Cuentos gratis**: los 30 sin categoría (`is_premium_tale == false`).
5. **Una estantería por categoría** con ≥1 cuento, ordenadas por `sort_order` del admin.
   Título = emoji + nombre en el idioma de la app. Las vacías no aparecen: la home
   crece sola.
6. **Anuncio nativo como fila propia** cada 3 estanterías (solo iOS, como hoy). Nunca
   intercalado entre portadas. Banner fijo abajo como hoy.

Usuario **premium**: mismo layout sin candados, sin tarjeta upsell y sin anuncios (los
widgets de ads ya se auto-ocultan con `PremiumProvider`); la estantería "Cuentos gratis"
baja al final (su contenido principal son las categorías).

**Tarjeta de portada** (item de carrusel): imagen cuadrada (las imágenes de cuentos son
1024/640px cuadradas) con esquinas redondeadas + título en 2 líneas máx debajo.
Overlays: candado (premium bloqueado, esquina sup. dcha.) y badge NUEVO (≤7 días,
esquina sup. izda., criterio actual). Cada carrusel muestra como máximo 10 portadas;
si la sección tiene más cuentos, aparece "ver más ›" que abre la sección completa
(relevante sobre todo para "Cuentos gratis", con 30).

## Página de categoría ("ver más")

- Cuadrícula responsive: 2 columnas en móvil, 3-4 en tablet/desktop (breakpoints
  estándar de FlutterFlow ya usados en el proyecto).
- Cabecera con emoji + nombre + nº de cuentos.
- La misma página sirve para categorías, "Cuentos gratis" y "Novedades" (recibe título
  + lista de cuentos).
- Banner ad abajo; sin anuncios nativos intercalados.
- Recibe los cuentos ya cargados vía parámetro de navegación (mismo patrón `extra` que
  ya usa el detalle del cuento). No re-consulta Firestore.

## Diseño técnico

### Datos y consultas

- `TalesRecord`: añadir campo `category_id` (String?, nullable) siguiendo el patrón
  existente del resto de campos.
- Nuevo `CategoriesRecord` en `lib/backend/schema/` (colección `categories`): `name_es`,
  `name_en`, `emoji`, `slug`, `sort_order`. Mismo patrón `FirestoreRecord`.
- La home hace exactamente **2 consultas**:
  1. `categories` orderBy `sort_order` (~12 docs).
  2. `tales` where `lang == <idioma>` orderBy `tale_id` desc — **sin paginación**
     (30 docs hoy, ~130/idioma a un año vista; la caché offline de Firestore abarata
     recargas). Se elimina `infinite_scroll_pagination` de la home.
- **Agrupación en cliente con función pura** (testeable):
  entrada `List<TalesRecord>` + `List<CategoriesRecord>` + `isPremiumUser` → salida de
  estanterías **ya en orden de pintado**: Novedades (10 más recientes), Gratis
  (`!isPremiumTale`, al final si `isPremiumUser`), una por categoría con ≥1 cuento
  (orden `sort_order`). Cada estantería expone su lista completa; el widget corta a 10
  para el carrusel y pasa la completa a "ver más". Cuentos premium con `category_id`
  nulo o desconocido (categoría borrada) no desaparecen: quedan en Novedades mientras
  sean recientes; se acepta que salgan de la home al dejar de serlo (caso residual).

### Archivos

**Nuevos:**
- `lib/pages/library_home/` (widget + model): home de estanterías, responsive.
- `lib/pages/category_page/` (widget + model): cuadrícula reutilizable.
- Widgets pequeños (en `lib/components/`): estantería (título + carrusel horizontal),
  tarjeta de portada, tarjeta upsell premium.
- Helper "abrir cuento" único: contador de intersticial (cada 5 aperturas, lógica
  actual movida sin cambios) + navegación al detalle. Lo usan home y página de
  categoría.

**Eliminados (~1.800 líneas):**
- `lib/tale_list/` (widget + model).
- `lib/components/tale_list_mobile/tablet/large_component_*.dart` (6 archivos).
- `lib/pages/home_page/` (`HomePageWidget`, página vacía de plantilla FlutterFlow sin
  entradas de navegación).

**Modificados:**
- `nav.dart`: ruta `/` → `LibraryHomeWidget`; nueva ruta de página de categoría; fuera
  las rutas de `taleList` y `HomePage`.
- Drawer: añade el selector de idioma (dropdown actual reubicado).
- `tale_detail_mobile/tablet_component_widget.dart`: fix del cupo (abajo).

### Fix del cupo semanal

En el `initState` de ambos detalles, la comprobación pasa de "usuario no premium" a
"usuario no premium **y cuento no bloqueado**": si `isPremiumTale && !isPremium`
(= modo teaser), no se llama ni a `canRead` ni a `recordRead` y no se muestra el modal
de límite. `WeeklyReadLimitService` no cambia.

### Idiomas

- Strings nuevos de UI ("Novedades", "Cuentos gratis", "ver más", textos de la tarjeta
  upsell, mensaje de error de carga…) en `internationalization.dart` (es/en), patrón
  actual.
- Nombres de categoría: `name_es`/`name_en` según idioma activo de la app.

### Errores y estados vacíos

- Primera carga sin datos: spinner (patrón actual) → si la consulta falla, mensaje
  sencillo con botón de reintento.
- Imagen de portada que falla: `errorBuilder` con placeholder gris.
- Categoría sin cuentos: no se renderiza (automático por la agrupación).
- Día 1 (cero premium publicados): home = Novedades + upsell + Gratis. Válida.

### Tests

- Unit test de la función de agrupación: casos con/sin premium, categorías vacías,
  categoría desconocida, orden por `sort_order`.
- Widget test: abrir detalle en modo teaser no registra lectura en el cupo semanal
  (patrón de widget tests existentes, p. ej. `premium_badge_widget_test.dart`).
- Los tests actuales de `weekly_read_limit_service_test.dart` siguen pasando sin
  cambios.

## Fuera de alcance (deliberado)

Búsqueda, favoritos, "seguir leyendo", deep links a categorías, cambios en admin CMS,
cambios en paywall/suscripción, backfill de categorías de los 30 gratuitos, previews de
audio, cambio de longitud del teaser (se queda en 100 palabras).

## Criterios de aceptación

1. La home muestra estanterías en el orden definido para gratuito y premium, en ES y EN.
2. Las categorías aparecen solo cuando tienen cuentos, con emoji + nombre localizados y
   orden del admin.
3. "Ver más" abre la cuadrícula responsive sin consulta adicional.
4. Abrir un teaser premium no consume cupo semanal ni dispara el modal de límite.
5. Un usuario premium no ve candados, ni upsell, ni anuncios.
6. Las 3 variantes duplicadas de lista y la HomePage muerta quedan eliminadas; `flutter
   analyze` limpio y tests en verde.
7. El intersticial sigue saltando cada 5 aperturas de cuento, desde home y desde
   página de categoría.
