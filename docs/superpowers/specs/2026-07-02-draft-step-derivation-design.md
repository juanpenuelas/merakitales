# `step` deja de guardarse: se deriva siempre al leer

**Fecha:** 2026-07-02
**Estado:** Aprobado (pendiente de plan de implementación)
**Proyecto:** merakitales
**Specs relacionadas:** `2026-06-30-3step-pipeline-withdraw-design.md` (introdujo `step`), `2026-07-01-manual-tale-creation-design.md` (donde se detectó el primer bug de `step`)

## Contexto

El campo `step` (`"text" | "image" | "audio"`) en `tale_drafts` marca hasta dónde ha llegado un borrador, y se usa para decidir si el botón "Aprobar y publicar" debe estar activo. Hoy lo escriben 6 sitios distintos (4 Cloud Functions del pipeline de IA + 2 puntos del flujo manual), cada uno con su propia lógica:

- `generateTaleText.js`, `generateTaleImage.js`: fijan un valor constante (`"text"`, `"image"`) sin comprobar nada más.
- `generateTaleAudio.js`: fija `step:"audio"` **en cuanto se genera un solo idioma**, sin esperar al otro — el mismo bug que se corrigió ayer en el flujo manual (commit `9f43a31`), pero sigue vivo aquí. No ha causado fallos visibles porque `draft_detail_page.dart` y `approveDraft.js` **además** comprueban los audios por separado — una doble comprobación que compensa la falta de fiabilidad de `step`, en vez de arreglarla.
- `resizeDraftImage.js`, `saveManualDraftAudioUrl` (Dart): ya arreglados ayer con una transacción que deriva `step` del estado real antes de escribirlo — funciona, pero es una solución local (Opción A del brainstorming) que sigue dependiendo de que cada futura escritura recuerde usar la misma disciplina.

No hay una única fuente de verdad. El sistema solo funciona hoy porque hay comprobaciones redundantes por todas partes tapando el problema de fondo.

## Objetivo

Eliminar la categoría de bug por completo: `step` deja de ser un campo persistido. Se deriva siempre, en el momento de leer, a partir de qué campos existen realmente (`image_url`, `audio_url_es`, `audio_url_en`). Al no guardarse nunca, es estructuralmente imposible que quede desincronizado con la realidad — no depende de que cada función recuerde actualizarlo bien.

## No incluido en esta versión

- Migración de datos: los documentos existentes conservan su campo `step` guardado de antes, pero deja de leerse — queda como dato muerto e inofensivo, no se borra ni se toca Firestore.
- Unificar `draft_create_page.dart` (asistente de IA) para que también lea `d.step` en su botón de publicar — hoy comprueba `audioUrlEs`/`audioUrlEn` directamente y funciona correctamente; no se toca por YAGNI, salvo que se pida explícitamente.
- Cambiar la semántica del caso límite "ambos audios subidos sin imagen" (ver más abajo) — se documenta como comportamiento aceptado, no se rediseña un estado más granular.

## La fórmula

Misma lógica, implementada una vez en JS y una vez en Dart (duplicación mínima e inevitable por ser dos lenguajes distintos; no se espera que cambie):

```
si imagen Y audio_es Y audio_en → "audio"
si no, si imagen → "image"
si no → "text"
```

**Caso límite documentado**: si existen ambos audios pero no la imagen, el resultado es `"text"`, no un estado intermedio. Es una simplificación consciente — lo que importa comunicar es "todavía no publicable, falta la imagen", no un conteo de archivos subidos. Este caso es posible en ambos flujos (ninguna función exige la imagen como precondición para generar/subir audio), no es exclusivo del flujo manual.

## Arquitectura

### Backend (Cloud Functions)

Nuevo módulo `firebase/functions/src/draftStep.js`:
```js
function computeStep({ image_url, audio_url_es, audio_url_en }) {
  if (image_url && audio_url_es && audio_url_en) return "audio";
  if (image_url) return "image";
  return "text";
}
module.exports = { computeStep };
```

**Dejan de escribir `step`:**
- `generateTaleText.js`: elimina `step: "text"` del documento inicial.
- `generateTaleImage.js`: elimina `step: "image"` de su `update`.
- `generateTaleAudio.js`: elimina `step: "audio"` de su `update`. El código pasa de:
  ```js
  const update = lang === "es" ? { audio_url_es: audioUrl } : { audio_url_en: audioUrl };
  await draftRef.update({ ...update, step: "audio" });
  ```
  a:
  ```js
  const update = lang === "es" ? { audio_url_es: audioUrl } : { audio_url_en: audioUrl };
  await draftRef.update(update);
  ```
- `retractTale.js`: elimina `step: "audio"` del documento que crea.
- `resizeDraftImage.js`: se revierte la transacción añadida ayer — vuelve a ser un `update()` simple de `image_url`/`image_url_640px`, ya que no hay ningún campo derivado que sincronizar.

**Pasa a calcularlo:**
- `approveDraft.js`: su guardia de publicación cambia de leer `d.step` a llamar `computeStep(d)`:
  ```js
  if (computeStep(d) !== "audio") {
    throw new HttpsError("failed-precondition", "Draft is missing image/audio assets and cannot be published yet");
  }
  ```
  Sustituye tanto la lectura de `d.step` como la comprobación redundante de `!d.audio_url_es || !d.audio_url_en` — `computeStep` ya cubre ambas cosas en un solo sitio.

### Frontend (Dart)

**`DraftsService`:**
- `createManualDraft`: elimina `'step': 'text'` del documento inicial.
- `saveManualDraftAudioUrl`: se simplifica de vuelta a un `.update()` de un solo campo, sin transacción — ya no hay ningún campo derivado que proteger de condiciones de carrera:
  ```dart
  Future<void> saveManualDraftAudioUrl({
    required String draftId,
    required String lang,
    required String url,
  }) async {
    await _db.collection('tale_drafts').doc(draftId).update({'audio_url_$lang': url});
  }
  ```

**`lib/admin/models/draft.dart`:** `step` deja de leerse de Firestore (`d['step']`) y pasa a ser un getter calculado sobre los campos ya presentes en el modelo:
```dart
String get step {
  if (imageUrl.isNotEmpty && audioUrlEs.isNotEmpty && audioUrlEn.isNotEmpty) return 'audio';
  if (imageUrl.isNotEmpty) return 'image';
  return 'text';
}
```
Al mantenerse como una propiedad `step` con el mismo nombre y tipo (`String`), **ningún código que ya lea `d.step`** (lista de borradores, pantalla de detalle, pantalla de creación manual) necesita cambiar una sola línea — solo cambia de dónde viene el valor.

**`draft_detail_page.dart`:** el gating de "Aprobar y publicar" se simplifica de `step=='audio' && d.audioUrlEs.isNotEmpty && d.audioUrlEn.isNotEmpty` a solo `step=='audio'` — la comprobación doble deja de aportar nada una vez que `step` vuelve a ser fiable por construcción, y mantenerla solo confundiría a quien lea el código preguntándose por qué se comprueba dos veces lo mismo.

## Testing

- **`draftStep.test.js`** (nuevo, puro, sin mocks): casos vacío→`"text"`, solo imagen→`"image"`, imagen+un audio→`"image"`, imagen+ambos audios→`"audio"`, ambos audios sin imagen→`"text"` (el caso límite documentado).
- **Tests existentes que se actualizan** (ya no afirman que se escriba `step`, sino que la guardia de publicación decide bien): `generateTaleImage.test.js`, `generateTaleAudio.test.js`, `retractTale.test.js`, `approveDraft.test.js`, `resizeDraftImage.test.js`. Se elimina el mock de `db.runTransaction` añadido ayer en `resizeDraftImage.test.js` (ya no hace falta).
- **Dart**: sin tests automatizados, como el resto de `lib/admin` — verificación con `flutter analyze` + prueba manual (crear borrador manual con audios antes que imagen, confirmar que no se puede publicar hasta subir la imagen; confirmar que subir imagen después "arregla" el estado en vez de quedarse atascado).

## Compatibilidad hacia atrás

Sin migración. Los documentos existentes conservan su campo `step` guardado de antes de este cambio, pero deja de leerse en cualquier punto del código — queda como dato muerto e inofensivo. No se toca Firestore directamente, no hay script de migración, no hay riesgo de leer un valor viejo incorrecto porque ya no se lee en absoluto.
