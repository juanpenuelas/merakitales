# Pipeline de cuentos con IA + Web Admin

**Fecha:** 2026-06-30
**Estado:** Aprobado (pendiente revisión final)
**Proyecto:** merakitales

## Contexto

Meraki Tales es una app Flutter (FlutterFlow) de cuentos infantiles bilingües (ES/EN). Estado actual:

- **100 usuarios** (40 Android, 60 iPhone), **1€/mes** de ingresos AdMob.
- **30 cuentos únicos** bilingües (60 documentos en `tales`), todos con narración de audio. Catálogo finito — los usuarios lo agotan y no vuelven.
- **Monetización 100% AdMob**: banner fijo, native ads cada 2 cuentos, native ad en detalle, interstitial cada 5 lecturas.
- **Cloud Functions vacías** (`index.js` con 3 líneas), pero `package.json` ya incluye `@onesignal/node-onesignal`, `@langchain/openai` y `axios`.
- **App publicada en stores** con permisos específicos; no se quiere modificar para no reenviar a revisión.

## Objetivo

Crear un pipeline que genere **cuentos nuevos con IA de forma automatizada**, con **aprobación humana** antes de publicar, sin tocar la app móvil. Esto convierte el "cuento nuevo cada semana" en el gancho de retención y marketing.

## No incluido en esta versión (next version)

- **Push notifications** (OneSignal ya en dependencias, listo para activar en v2).
- **Panel admin dentro de la app móvil** (requeriría reenvío a stores).
- **Schedule automático (cron)** — la generación es on-demand por ahora.

## Arquitectura general

Tres componentes, sin tocar la app móvil:

```
┌─────────────────────┐      ┌──────────────────────────┐      ┌─────────────────┐
│  Web Admin (Flutter │      │  Cloud Functions (Node)  │      │   OpenRouter    │
│  web → Firebase     │─────▶│                          │─────▶│   API (única)   │
│  Hosting)           │ HTTP │  • generateTaleDraft     │      │  texto+img+TTS  │
│                     │      │  • approveDraft          │      └─────────────────┘
│  • Login Firebase   │      │  • rejectDraft           │
│    Auth (solo tú)   │      │  (admin SDK → Firestore) │      ┌─────────────────┐
│  • Lista de drafts  │◀─────│                          │─────▶│  Firebase       │
│  • Preview + botones│      │                          │      │  Storage        │
└─────────────────────┘      └──────────────────────────┘      │  (img + audio)  │
                                                                └─────────────────┘
                                         │
                                         ▼
                                 ┌───────────────┐
                                 │  Firestore    │
                                 │  • tales (r/o)│  ◀── app móvil lee aquí
                                 │  • tale_drafts│      (sin cambios)
                                 │  • tales_common│
                                 └───────────────┘
```

### Flujo

1. Admin abre la web admin, pulsa **"Generar"** (con tema opcional) → llama a `generateTaleDraft`.
2. La función orquesta 4 pasos en OpenRouter: texto (ES+EN en 1 llamada) → imagen → TTS ES → TTS EN. Sube imagen y audios a Storage. Guarda todo en `tale_drafts` con estado `pending`.
3. En la web, el admin ve el draft: título, descripción, texto completo, imagen y reproductores de audio ES/EN. Pulsar **Aprobar** o **Rechazar**.
4. **Aprobar** → `approveDraft` calcula `tale_id = max+1` en transacción, escribe en `tales` (2 docs ES/EN) + `tales_common_data`, mueve archivos de Storage a `tales/{taleId}/`. El cuento aparece en la app **al instante**.
5. **Rechazar** → `rejectDraft` borra draft + archivos de Storage.

### Principios clave

- **App móvil = 0 cambios.** Solo lee `tales`. Los cuentos aprobados aparecen automáticamente (la app ya lee `tales` ordenado por `tale_id` desc).
- **Reglas Firestore bloqueadas.** El web admin nunca escribe directo; siempre vía Cloud Functions con admin SDK. `tales`/`tales_common_data` se quedan en `create: false, write: false` para la app.
- **Un proveedor (OpenRouter)** para texto, imagen y TTS → una API key, una base URL (`https://openrouter.ai/api/v1`), una factura.
- **Quality gate humano obligatorio.** Nada se publica sin aprobación — crítico para contenido infantil.

## Modelo de datos

### Colección nueva: `tale_drafts`

```js
tale_drafts/{draftId} {
  // metadata
  status: "pending" | "approved" | "rejected",
  created_at: Timestamp,
  decided_at: Timestamp | null,
  decided_by: String | null,                      // uid del admin

  // contenido ES (obligatorio)
  name_es: String,
  description_es: String,                          // descripción corta (lista)
  specifications_es: String,                        // texto completo del cuento (detalle)
  audio_url_es: String,                            // https URL en Storage
  audio_duration_es: number | null,                // segundos, opcional
  image_prompt_es: String,                         // prompt que generó la imagen (auditoría)

  // contenido EN (obligatorio)
  name_en: String,
  description_en: String,
  specifications_en: String,
  audio_url_en: String,
  audio_duration_en: number | null,
  image_prompt_en: String,

  // imagen (compartida ES/EN)
  image_url: String,                               // Storage URL (1024px)
  image_url_640px: String,                         // Storage URL (640px)

  // asignación al aprobar
  assigned_tale_id: number | null,                 // se rellena en approveDraft
}
```

**Decisión ES/EN:** se generan 2 versiones del texto del cuento (ES nativo + EN traducción/adaptación) pero **una sola imagen compartida**. Las imágenes IA son el cuello de botella de coste (~$0.04-0.05€/cada), y una buena ilustración de cuento es independiente del idioma. Los 30 cuentos actuales siguen este mismo patrón (misma imagen para ES y EN, solo cambia `lang` y el texto).

### Colecciones existentes (sin cambios de schema)

Al aprobar, `approveDraft` escribe en los schemas **existentes**:

- `tales/{id}` — 2 documentos (uno `lang: "es"`, otro `lang: "en"`), con campos: `name`, `description`, `specifications`, `image_url`, `image_url_640px`, `audio_url`, `lang`, `tale_id`, `tale_common_data_ref`, `created_at`, `modified_at`. Los campos `price`, `on_sale`, `sale_price`, `quantity` se rellenan con defaults (0/false) — están en el schema pero no se usan en la app.
- `tales_common_data/{id}` — 1 documento con `tale_id`, `image_url_1024px`, `image_url_640px`.

### Estructura en Storage

```
gs://merakitales-5rltbl.appspot.com/
  drafts/{draftId}/image_1024.png
  drafts/{draftId}/image_640.png
  drafts/{draftId}/audio_es.mp3
  drafts/{draftId}/audio_en.mp3
```

Al aprobar, `approveDraft` **mueve** los archivos a `tales/{taleId}/` y actualiza las URLs en los documentos de `tales`.

## Cloud Functions

3 endpoints **Callable** (`onCall`) con Firebase Auth. El SDK de Flutter pasa el token automáticamente; las functions reciben `context.auth.uid`. La app móvil no tiene estas functions en su código → no las puede llamar.

| Función | Qué hace |
|---------|----------|
| `generateTaleDraft` | Orquesta generación IA → draft `pending` |
| `approveDraft` | Mueve draft → `tales` + `tales_common_data`, mueve archivos Storage, borra draft |
| `rejectDraft` | Borra draft + archivos Storage |

**Autenticación:** las funciones verifican `context.auth.uid === ADMIN_UID`. Sin token o uid incorrecto → `permission-denied`.

### `generateTaleDraft` — orquestación (4 pasos secuenciales)

```
1. TEXTO (OpenRouter POST /chat/completions)
   ├── Prompt → 1 llamada que devuelve JSON:
   │   {name_es, description_es, specifications_es,
   │    name_en, description_en, specifications_en,
   │    image_prompt}
   └── Modelo: NVIDIA Nemotron o Llama (vía build.nvidia.com/OpenRouter)

2. IMAGEN (OpenRouter POST /images)
   ├── Usa image_prompt del paso 1
   ├── Genera 1 imagen a 1024px (model: bytedance-seed/seedream-4.5 o similar)
   └── Se redimensiona a 640px en la función (sharp) → 2 archivos en Storage

3. TTS ES (OpenRouter POST /audio/speech)
   ├── Input: specifications_es
   ├── Model: openai/gpt-4o-mini-tts (o mistralai/voxtral-mini-tts)
   └── Output: audio_es.mp3 en Storage

4. TTS EN (OpenRouter POST /audio/speech)
   ├── Input: specifications_en
   └── Output: audio_en.mp3 en Storage
```

**Manejo de errores:** si cualquier paso falla, la función borra lo creado hasta ese momento (draft parcial + archivos) y devuelve error. No dejamos drafts rotos.

**Timeout:** 120s (la generación secuencial tarda 20-40s).

### `approveDraft` — transacción

1. Transacción Firestore: leer `max(tale_id)` de `tales`, asignar `tale_id = max+1`.
2. Escribir 2 documentos en `tales` (ES, EN) + 1 en `tales_common_data`.
3. Mover archivos en Storage de `drafts/{draftId}/` a `tales/{taleId}/`.
4. Actualizar `tale_drafts/{draftId}`: `status: "approved"`, `decided_at`, `decided_by`, `assigned_tale_id`.
5. Si cualquier paso falla, revertir (borrar docs creados, devolver archivos).

### `rejectDraft`

1. Borrar draft de `tale_drafts`.
2. Borrar archivos de Storage en `drafts/{draftId}/`.

## Web Admin (Flutter web)

### Stack y despliegue

- **Flutter web**, entrypoint separado (`lib/admin/main_admin.dart`). Mismo `pubspec.yaml`, mismo proyecto, build web independiente.
- **Firebase Hosting** (`firebase.json` ya existe). Build con `flutter build web --target lib/admin/main_admin.dart` → `build/web`.
- **Firebase Auth** email/password — 1 usuario (admin). No hay registro, solo login.

### Pantallas (3)

**`/login`** — formulario email/password. Botón "Entrar".

**`/drafts`** (lista) —
- Botón **"+ Generar nuevo cuento"** (con input opcional de tema: "amistad", "valentía", etc.).
- Lista de drafts pendientes ordenados por `created_at` desc.
- Cada item: miniatura de imagen, nombre ES/EN, tiempo relativo, botón "Ver detalle".

**`/drafts/{id}`** (detalle/preview) —
- Imagen 1024px grande.
- Toggle ES/EN.
- Campos: nombre, descripción, texto completo (specifications).
- 2 audio players (ES, EN) para validar narración.
- Botones: **"Rechazar"** (rojo) y **"Aprobar y publicar"** (verde).

### Estado de los drafts en la UI

- `pending` → visibles en la lista, botones aprobar/rechazar.
- `approved`/`rejected` → desaparecen de la lista (sección "historial" colapsable opcional, fuera de v1).

## Configuración y secretos

Vía Firebase Secret Manager (`functions.config()` o `runWithSecrets`):

- `OPENROUTER_API_KEY` — API key de OpenRouter (nunca en el cliente).
- `ADMIN_UID` — uid del usuario admin.

Constantes al principio de `index.js` (iterables fácilmente):

- `TEXT_MODEL` (ej: `nvidia/llama-3.1-nemotron-70b-instruct`)
- `IMAGE_MODEL` (ej: `bytedance-seed/seedream-4.5`)
- `TTS_MODEL` (ej: `openai/gpt-4o-mini-tts`)
- `TTS_VOICE` (ej: `alloy`)
- `OPENROUTER_BASE_URL` = `https://openrouter.ai/api/v1`

## Reglas de seguridad

### Firestore (`firestore.rules`)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /tales/{document} {
      allow create: if false;
      allow read: if true;
      allow write: if false;
      allow delete: if false;
    }
    match /tales_common_data/{document} {
      allow create: if false;
      allow read: if true;
      allow write: if false;
      allow delete: if false;
    }
    // drafts: solo legibles por admin autenticado
    match /tale_drafts/{document} {
      allow read, write: if request.auth.uid == ADMIN_UID;
    }
  }
}
```

(Las Cloud Functions usan admin SDK → bypassan estas reglas.)

### Storage (`storage.rules`)

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /drafts/{allPaths=**} {
      allow read, write: if request.auth.uid == ADMIN_UID;
    }
    match /tales/{allPaths=**} {
      allow read: if true;
      allow write: if false;
    }
  }
}
```

## Costes estimados

| Recurso | Modelo OpenRouter | Coste aprox por cuento |
|---------|-------------------|------------------------|
| Texto (ES+EN en 1 llamada) | Nemotron/Llama (~$0.20/M tokens) | ~$0.005 |
| Imagen 1024px (1 unidad) | `bytedance-seed/seedream-4.5` | ~$0.05 |
| TTS ES (~800 caracteres) | `openai/gpt-4o-mini-tts` (~$0.015/min) | ~$0.003 |
| TTS EN (~800 caracteres) | `openai/gpt-4o-mini-tts` | ~$0.003 |
| **Total por cuento** | | **~$0.06 (≈0.055€)** |

- **2 cuentos/semana** → ~0.50€/mes en OpenRouter.
- **Firebase**: Functions ( gratuitas), Firestore (escrituras mínimas), Storage (<1GB) → 0-2€/mes.
- **Total operativo**: <5€/mes.

## Seguridad

| Vector | Mitigación |
|--------|-----------|
| Web admin accesible públicamente | Firebase Auth obligatorio en Hosting rewrite rules. Solo cuenta admin. |
| Llamadas maliciosas a `generateTaleDraft` | Callable Functions verifican `context.auth.uid === ADMIN_UID`. Sin token → 403. |
| La app móvil llama a las functions | Las functions no existen en el código móvil; aunque alguien las llamara, el check de uid bloquea. |
| API key de OpenRouter en el cliente | Nunca. Solo en Cloud Functions vía Secret Manager. El web admin no la toca. |
| Contenido inapropiado generado por IA | Quality gate humano obligatorio + system prompt con instrucciones explícitas de "contenido infantil apto, sin violencia, sin temas adultos". |
| Imágenes inadecuadas | Modelo de imagen con safety settings al máximo + preview humano antes de publicar. |
| Borrado accidental de cuentos aprobados | `approveDraft` no borra el draft hasta confirmar que `tales` se escribió correctamente (transacción). |
| `tale_id` duplicado por concurrencia | `max(tale_id)+1` calculado en transacción Firestore. |

## Riesgos técnicos

1. **Calidad del TTS en español** — los modelos TTS varían en calidad entre idiomas. *Mitigación:* la primera semana genera 3-5 cuentos de prueba (sin publicar) y valida que la voz es aceptable. Si no, probar `mistralai/voxtral-mini-tts` como alternativa.
2. **Calidad de las imágenes IA** — pueden ser raras o no aptas. *Mitigación:* prompt muy específico ("children's book illustration, soft colors, friendly, no text") + preview obligatorio.
3. **Coherencia texto-imagen** — la imagen puede no representar el cuento. *Mitigación:* el LLM genera el `image_prompt` a partir del título/descripción, no usamos el cuento completo.
4. **Límites de Cloud Functions** — generación tarda 20-40s (secuencial). *Mitigación:* timeout de función a 120s. Si crece, paralelizar TTS ES/EN con `Promise.all`.
5. **`tale_id` consistente** — calcular `max(tale_id)+1` en transacción para evitar duplicados si apruebas 2 drafts a la vez.

## Plan de validación (iterativo)

### Fase 0 — Esqueleto (sin IA real)

- Web admin con login, lista vacía, botón "Generar" que crea un draft mock.
- Deploy a Firebase Hosting + functions de stub.
- *Objetivo:* validar el flujo web→functions→firestore sin APIs de IA.

### Fase 1 — Pipeline IA real

- Implementar `generateTaleDraft` completo.
- Generar 3-5 drafts de prueba. **No publicar.**
- *Objetivo:* validar calidad de texto, imagen y audio. Ajustar prompts/modelos.

### Fase 2 — Publicación

- Implementar `approveDraft` + `rejectDraft` con transacción de `tale_id`.
- Publicar 1 cuento. Verificar que aparece en la app móvil sin cambios.
- *Objetivo:* pipeline end-to-end real.

### Fase 3 — Cadencia

- Generar 2 cuentos/semana. Medir descargas/retención tras 1 mes.
- *Objetivo:* validar que "cuento nuevo cada semana" mueve la aguja de retención.

## Fuera de scope (explícito)

- Push notifications (next version; OneSignal ya en `package.json`).
- Panel admin dentro de la app móvil (requeriría reenvío a stores).
- Schedule automático (cron) — on-demand por ahora.
- Programmatic SEO / página de marketing.
- Cambios en monetización (AdMob se queda como está).
- Cambios en la app móvil (0 modificaciones).
