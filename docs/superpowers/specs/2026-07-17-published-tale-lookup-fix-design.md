# Diseño: Fix de búsqueda de cuentos publicados por ID adivinado

**Fecha**: 2026-07-17
**Alcance**: solo la búsqueda de documentos de `tales` en el detalle del admin y en `retractTale`. Sin migración de datos, sin cambios en la app móvil (`lib/backend`), sin rediseño visual.

## Contexto

Cada cuento publicado se guarda como dos documentos en la colección `tales` de Firestore (uno con `lang: 'es'`, otro con `lang: 'en'`), más un documento de metadatos compartidos en `tales_common_data`. `approveDraft.js` (la función que publica un borrador) crea estos documentos con IDs deterministas: `tales/{taleId}_es`, `tales/{taleId}_en`, `tales_common_data/{taleId}`.

Dos puntos de lectura asumen que ese patrón de ID siempre existe, adivinando el nombre del documento en vez de consultarlo:

- `lib/admin/services/drafts_service.dart` → `getPublishedTale(taleId)` (usada por `published_tale_detail_page.dart`).
- `firebase/functions/src/retractTale.js` → `retractTaleHandler`.

Se confirmó consultando Firestore en producción (proyecto `merakitales-5rltbl`) que **los 30 cuentos publicados hoy tienen IDs de documento aleatorios** en `tales` y `tales_common_data` — fueron creados antes de que existiera esta convención de ID en el admin. El campo `tale_common_data_ref` (una referencia de Firestore) sí está presente y correctamente enlazado en los 30 documentos, tanto legacy como futuros, porque `approveDraft.js` siempre lo escribe.

Consecuencia: `getPublishedTale` no encuentra ningún documento para ningún cuento publicado real → el detalle se muestra con nombre/descripción/audio vacíos (solo el fallback `tale_id=X`). `retractTaleHandler` fallaría con `not-found` para cualquiera de los 30 cuentos.

La app móvil (`lib/backend/schema/tales_record.dart`, vía `queryTalesRecord`) consulta `tales` por campos (no por ID de documento), así que nunca dependió de este patrón y no se ve afectada por el bug ni por el fix.

## Solución

Sustituir la búsqueda por ID adivinado por una consulta por campos (`tale_id` + `lang`), igual que ya hace `streamPublished()` (que sí funciona hoy). Una consulta con dos filtros de igualdad no requiere índice compuesto adicional en Firestore (solo se necesitan para combinaciones con `orderBy`/desigualdad en campo distinto, que no es el caso aquí).

### `lib/admin/services/drafts_service.dart`

`getPublishedTale(taleId)` pasa de:
```dart
final snaps = await Future.wait([
  _db.collection('tales').doc('${taleId}_es').get(),
  _db.collection('tales').doc('${taleId}_en').get(),
]);
```
a:
```dart
Future<Map<String, dynamic>?> fetchByLang(String lang) async {
  final q = await _db.collection('tales')
      .where('tale_id', isEqualTo: taleId)
      .where('lang', isEqualTo: lang)
      .limit(1)
      .get();
  return q.docs.isEmpty ? null : q.docs.first.data();
}
final snaps = await Future.wait([fetchByLang('es'), fetchByLang('en')]);
```
`PublishedTaleFull.fromDocs(taleId: taleId, esData: snaps[0], enData: snaps[1])` no cambia de firma — sigue recibiendo `Map<String, dynamic>?`.

### `firebase/functions/src/retractTale.js`

Sustituir las dos búsquedas `.doc().get()` por queries equivalentes:
```js
const esQuery = await db.collection("tales").where("tale_id", "==", taleId).where("lang", "==", "es").limit(1).get();
const enQuery = await db.collection("tales").where("tale_id", "==", taleId).where("lang", "==", "en").limit(1).get();

if (esQuery.empty || enQuery.empty) {
  throw new HttpsError("not-found", "Tale not found");
}
const esSnap = esQuery.docs[0];
const enSnap = enQuery.docs[0];
const es = esSnap.data();
const en = enSnap.data();

const commonSnap = es.tale_common_data_ref ? await es.tale_common_data_ref.get() : null;
```
Y en el `batch`, usar las referencias reales devueltas por la query en vez de reconstruir el ID:
```js
batch.delete(esSnap.ref);
batch.delete(enSnap.ref);
if (commonSnap && commonSnap.exists) {
  batch.delete(commonSnap.ref);
}
```
Se elimina por completo el guessing de ID en este archivo: la búsqueda de `tales_common_data` ya no adivina `tales_common_data/{taleId}`, sigue la referencia real (`tale_common_data_ref`), presente en el 100% de los documentos existentes.

### Storage (sin cambios)

El movimiento de ficheros en Storage (`moveIfExists` en `retractTale.js`) ya asume rutas `tales/{taleId}/...` que tampoco coinciden con la estructura real de los cuentos legacy (sus ficheros viven en otras rutas). Esto ya está cubierto por el `try/catch` existente: si el move falla, se usa como fallback la URL original (`audioUrlEs || es.audio_url`, etc.), así que el borrador resultante sigue teniendo audio/imagen funcionales, solo que sin reubicar el fichero físicamente. No es parte de este fix — es un comportamiento tolerante que ya existe y sigue igual.

## Manejo de errores

- Si algún día faltara el documento ES o EN para un `tale_id` (no ocurre hoy, pero es una posibilidad razonable): `getPublishedTale` sigue devolviendo el mismo fallback visual que ya existe (nombre vacío → se muestra `tale_id=X`); `retractTaleHandler` sigue lanzando `not-found`, igual que antes del fix.
- No se toca `firestore.rules` ni `firestore.indexes.json` — la regla de lectura de `tales` (`allow read: if true`) y el índice existente (`lang` ASC + `tale_id` DESC, usado por `streamPublished`) ya cubren esta query.

## Verificación

Sin tests de UI en `lib/admin`. Verificación:
1. `flutter analyze lib/admin` — sin errores nuevos.
2. Abrir en el admin desplegado el detalle de un cuento publicado real (p. ej. `tale_id=30`) y confirmar que se ven nombre, descripción, texto y audio en ambos idiomas (ES/EN).
3. Pulsar "Retirar de la app" sobre ese mismo cuento y confirmar que se crea el borrador correctamente (sin `not-found`) y que el cuento desaparece de `Publicados`.

En `firebase/functions`:
- `firebase/functions/__tests__/retractTale.test.js` ya existe y mockea `db.collection(name).doc(id).get()` directamente; hay que extender ese mock para soportar `.where().where().limit().get()` devolviendo `{ empty, docs: [{ data, ref }] }`, y añadir `tale_common_data_ref` (un objeto con `.get()`) a los documentos ES/EN de prueba. Se mantienen los mismos casos existentes (creación de borrador, `not-found`, propagación de `is_premium_tale`) más uno nuevo: los documentos de prueba deben tener **IDs distintos de `31_es`/`31_en`** (IDs "aleatorios", como en producción) para que el test cubra explícitamente el caso legacy que motivó este fix.
- `npm test` dentro de `firebase/functions` tras el cambio.

## Fuera de alcance

- Migrar los 30 documentos legacy a un esquema de ID distinto, o rediseñar el esquema (un solo documento por cuento en vez de `_es`/`_en` + `tales_common_data`) — se descartó explícitamente: requeriría migrar datos en producción y coordinar cambios en la app móvil, un proyecto mucho más grande y arriesgado que el bug real (decisión tomada junto al usuario).
- Cualquier rediseño visual del panel de admin — el sistema de diseño de julio (`2026-07-02-admin-redesign-design.md`) ya está implementado y es suficiente; una vez los datos se cargan bien, la página ya usa `AppCard`/tipografía consistente.
- Exponer `is_premium_tale` en la vista de publicados — spec aparte (`2026-07-16-draft-premium-flag-design.md`), no relacionado con este bug.
