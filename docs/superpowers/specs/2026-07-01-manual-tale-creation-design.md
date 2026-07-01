# Creación manual de cuentos (sin IA)

**Fecha:** 2026-07-01
**Estado:** Aprobado (pendiente de plan de implementación)
**Proyecto:** merakitales
**Specs relacionadas:** `2026-06-30-3step-pipeline-withdraw-design.md` (pipeline de IA que este diseño reutiliza)

## Contexto

El admin tiene hoy un único camino para crear un cuento: el asistente de 3 pasos (`draft_create_page.dart`) que genera texto, imagen y audio con IA. El admin quiere poder crear un cuento **enteramente por su cuenta** — escribiendo el texto, dibujando/consiguiendo la imagen y grabando los audios fuera de la app — y simplemente subir ese contenido ya terminado al mismo pipeline de revisión y publicación.

## Objetivo

Añadir un segundo camino de creación, "Crear a mano", que:
- Reutiliza el modelo de datos `Draft` y el flujo de revisión/publicación (`draft_detail_page.dart`, `approveDraft.js`) sin ningún cambio en ellos
- Permite escribir directamente el nombre, descripción y texto del cuento en ES y EN
- Permite subir una imagen (PNG/JPG) y los dos audios (MP3 ES/EN) desde el selector de archivos del navegador
- Genera automáticamente la miniatura de 640px a partir de la imagen subida, igual que hace el pipeline de IA

## No incluido en esta versión

- Edición de la miniatura recortada manualmente (se genera siempre automáticamente a partir de la imagen completa)
- Conversión/transcodificación de formatos distintos a PNG/JPG (imagen) y MP3 (audio) — se rechazan con un mensaje claro
- Un modo "mixto" (p. ej. texto e imagen manuales pero audio con IA) — cada draft es 100% manual o 100% IA en esta versión; nada impide técnicamente mezclarlos más adelante, pero no se construye UI para ello ahora
- Cambios en la app móvil (0 cambios)
- Distinguir en el modelo de datos si un draft es "manual" o "de IA" (no hay ninguna pantalla que lo necesite)

## Arquitectura general

```
┌──────────────────────────────────────────────────────────────────┐
│  WEB ADMIN (Flutter web → Firebase Hosting)                       │
│                                                                    │
│  /drafts                                                          │
│  ┌──────────────────┐  ┌──────────────────┐                      │
│  │ [+ Nuevo cuento]  │  │ [Crear a mano]   │  ← nuevo botón       │
│  │  → asistente IA   │  │  → formulario    │                      │
│  └──────────────────┘  └──────────────────┘                      │
│                                  │                                │
│                                  ▼                                │
│                     PANTALLA "Crear a mano" (1 sola pantalla)    │
│                     ┌────────────────────────────────┐           │
│                     │ Texto ES: nombre/desc/cuento *  │           │
│                     │ Texto EN: nombre/desc/cuento *  │           │
│                     │ [Subir imagen]                  │           │
│                     │ [Subir audio ES] [Subir audio EN]│          │
│                     │ [Guardar borrador]               │          │
│                     └────────────────────────────────┘           │
│                                  │                                │
│                                  ▼                                │
│              /drafts/{id} (draft_detail_page.dart, SIN CAMBIOS)  │
│              → "Aprobar y publicar" cuando step=='audio'          │
└──────────────────────────────────────────────────────────────────┘
```

Igual que en el pipeline de IA, un draft manual pasa por `tale_drafts` → revisión en `draft_detail_page.dart` → `approveDraft.js` lo mueve a `tales`/`tales_common_data`. Ninguno de esos dos archivos cambia.

## Modelo de datos

**Sin cambios de esquema.** El draft manual usa exactamente los mismos campos que uno de IA (`name_es/en`, `description_es/en`, `specifications_es/en`, `image_url`, `image_url_640px`, `audio_url_es/en`, `step`, `status`, etc.). No se añade ningún campo `origin`/`source` — ninguna pantalla existente necesita distinguir el origen del draft.

`step` se deriva de qué campos están rellenos, calculado en el cliente tras cada guardado (no en una Cloud Function):
- `"text"` — nombre + descripción + cuento presentes en ES y EN
- `"image"` — además, imagen subida
- `"audio"` — además, ambos audios subidos

Rutas de Storage: exactamente las que ya espera `approveDraft.js` — `drafts/{draftId}/image_1024.png`, `image_640.png`, `audio_es.mp3`, `audio_en.mp3`.

## Cloud Functions

### Función nueva

| Función | Qué hace | Notas |
|---------|----------|-------|
| `resizeDraftImage({draftId})` | Lee `drafts/{draftId}/image_1024.png`, genera `image_640.png` con `resizeToWidth` (reutilizado de `storage.js`), sube ambas URLs y hace `draftRef.update({step:'image', image_url, image_url_640px})` | Reutiliza la misma lógica de resize que ya usa `generateTaleImage.js`; solo cambia el origen de la imagen (subida manual en vez de generada) |

Errores: `not-found` si el draft no existe, `invalid-argument` si falta `draftId`, error claro si `drafts/{id}/image_1024.png` no existe todavía en Storage (subida no completada).

### Funciones existentes — sin cambios

- `approveDraft`, `rejectDraft`, `retractTale`, `updateDraftText` — ninguna se modifica

### Sin Cloud Function para creación/edición de texto ni para subida de archivos

`firestore.rules` ya permite que el admin (`request.auth.uid == ADMIN_UID`) lea y escriba `tale_drafts` directamente, y `storage.rules` ya permite que el admin escriba en `drafts/**`. El cliente Flutter:
- Genera el `draftId` con `db.collection('tale_drafts').doc().id`
- Escribe/actualiza el documento del draft directamente vía el SDK de Firestore
- Sube los archivos directamente vía el SDK de Storage (`FirebaseStorage.instance.ref(...).putData(bytes)`)

## UI y componentes

**Entrada**: botón `OutlinedButton.icon` "Crear a mano" junto a "Nuevo cuento" en `drafts_list_page.dart` → navega a `/drafts/manual`.

**Nueva página `draft_create_manual_page.dart`** (acepta un `draftId` opcional) — formulario de una sola pantalla (`SingleChildScrollView`, no wizard por pasos), con label visible en cada campo (no solo placeholder) y asterisco en los obligatorios:

1. **Texto — Español**: `*Nombre`, `*Descripción` corta, `*Cuento` (con contador de palabras y aviso no bloqueante de rango 200-600, igual que el asistente de IA)
2. **Texto — English**: mismos 3 campos
3. **Imagen**: zona de subida con vista previa tras subir; mientras sube, barra de progreso determinada (Storage SDK expone bytes transferidos) + botón deshabilitado
4. **Audio ES** / **Audio EN**: un botón de subida por idioma, con nombre de archivo una vez subido y opción de reemplazar

**Botón "Guardar borrador"**, fijo en un `bottomNavigationBar` del `Scaffold` (siempre visible sin necesidad de hacer scroll), habilitado solo si el texto ES+EN está completo:
- 1ª vez → crea el doc en Firestore con el `draftId` generado en cliente, navega a `/drafts/manual/{id}` (ruta propia de esta pantalla, distinta de `/drafts/{id}` que ya usa `draft_detail_page.dart` solo para revisar/publicar) para persistir el estado en la URL — recargar la página reabre esta misma pantalla de edición con el draft precargado, no la de solo-lectura
- Siguientes veces → actualiza el doc existente
- Mientras guarda: botón deshabilitado + spinner inline (no bloquea toda la pantalla)
- Al terminar: `SnackBar` de confirmación ("Borrador guardado")
- Si el primer guardado falla (red, permisos), el `draftId` ya generado en cliente se reutiliza en el reintento — no se genera uno nuevo, así no quedan ids huérfanos sin doc asociado

**Rutas:** `/drafts/manual` (nuevo draft, sin id) y `/drafts/manual/:id` (continuar uno existente) apuntan al mismo widget `DraftCreateManualPage(draftId: ...)` con `draftId` nulo o no. `/drafts/manual` es un segmento literal bajo `/drafts`, así que no choca con el `GoRoute(path: ':id')` que ya usa `draft_detail_page.dart` — mismo patrón que ya usa `new` para el asistente de IA.

"Aprobar y publicar" **no** aparece en esta pantalla — una vez el draft llega a `step:'audio'`, el admin va a `/drafts/{id}` (`draft_detail_page.dart`, sin cambios) para revisar y publicar, exactamente igual que un draft de IA. Un enlace "Ver borrador completo →" en esta pantalla facilita ese salto una vez todo está subido.

## Flujo de datos

**Guardar texto (1ª vez):**
1. Cliente genera `draftId = db.collection('tale_drafts').doc().id`
2. Escribe: `{status:'pending', step:'text', created_at, name_es, description_es, specifications_es, name_en, description_en, specifications_en, image_url:'', image_url_640px:'', audio_url_es:'', audio_url_en:'', image_prompt:'', assigned_tale_id:null, retracted_from_tale_id:null}`
3. Navega a `/drafts/manual/{draftId}`

**Guardar texto (ediciones siguientes):** `update()` directo del mismo doc.

**Subir imagen:**
1. `FirebaseStorage.instance.ref('drafts/$id/image_1024.png').putData(bytes)` con listener de progreso
2. Al terminar, llama a `resizeDraftImage({draftId})`
3. Cliente refresca el draft vía el stream ya existente (`streamDraft`)

**Subir audio (ES o EN):**
1. `FirebaseStorage.instance.ref('drafts/$id/audio_es.mp3').putData(bytes)` (o `_en`)
2. Cliente actualiza directo: `draftRef.update({audio_url_es: url})` (o `_en`), y si ambos audios quedan presentes, incluye `step:'audio'` en el mismo update

**Publicar:** sin cambios — `draft_detail_page.dart` + `approveDraft.js`.

## Validación y manejo de errores

**Antes de guardar texto:**
- Nombre/descripción/cuento ES y EN no vacíos → si falta alguno, "Guardar borrador" permanece deshabilitado con texto de ayuda ("Completa ambos idiomas para guardar") en vez de fallar tras pulsar
- Aviso de rango de palabras (200-600) no bloqueante

**Al subir archivos:**
- Imagen: solo `.png`/`.jpg`/`.jpeg`, rechazo temprano con mensaje claro si no
- Audio: solo `.mp3`, mismo rechazo temprano
- Tamaño máximo razonable (15MB imagen, 30MB audio) para evitar subidas colgadas

**Fallos durante la subida:**
- Si `putData` falla → `SnackBar` con el error y opción de reintentar; el campo vuelve a su estado "sin subir"
- Si `resizeDraftImage` falla → error claro; `image_1024.png` queda subido en Storage pero el draft no avanza a `step:'image'` hasta que el resize tenga éxito, así se puede reintentar sin volver a subir la imagen completa

**Guardado de texto:** sin reintentos automáticos silenciosos; error visible y el texto permanece en los controllers aunque falle el guardado (no se pierde lo escrito).

## Testing

**Backend (`resizeDraftImage`)** — único código de servidor nuevo, mismo patrón que `approveDraft.test.js`/`generateTaleImage.test.js`:
- Redimensiona correctamente y escribe `image_url`/`image_url_640px`/`step:'image'` en el draft
- `requireAuth` se llama con la request
- Lanza `not-found` si el draft no existe
- Lanza `invalid-argument` si falta `draftId`
- Lanza error claro si `drafts/{id}/image_1024.png` no existe en Storage

**Frontend (Flutter)**: sin tests automatizados de UI (el proyecto no los tiene hoy en `lib/admin`, se valida con `flutter analyze` + prueba manual). Verificación manual end-to-end antes de dar por cerrada la implementación: crear texto → subir imagen → subir audios → aprobar → ver en Publicados.

**Regresión**: como `approveDraft.js`, `draft_detail_page.dart` y `retractTale.js` no cambian, los 43 tests existentes de `firebase/functions` deben seguir pasando sin modificación.
