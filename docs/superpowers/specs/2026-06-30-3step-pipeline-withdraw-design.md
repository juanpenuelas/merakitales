# Pipeline de cuentos por pasos + retirada de publicados

**Fecha:** 2026-06-30
**Estado:** Aprobado (pendiente revisión final)
**Proyecto:** merakitales
**Spec anterior:** `2026-06-30-ia-tale-pipeline-design.md` (one-shot)

## Contexto

El pipeline actual genera cuentos en **un solo paso** (texto + imagen + audio) y tarda 1-2 minutos. El cuento generado en la validación E2E (tale_id=31) salió bien en imagen, correcto en audio inglés (Kokoro), pero el audio en español sonó a "alguien hablando en inglés pero español" — Kokoro es un modelo pequeño entrenado en inglés que no maneja bien el español. Además el cuento fue "extremadamente corto" comparado con los 30 cuentos existentes (promedio 402 palabras, 1800-2600 chars, con estructura inicio/desarrollo/lección/cierre).

El admin quiere control total en cada paso del pipeline y poder:
1. Ver y editar el texto antes de generar la imagen
2. Regenerar imagen/texto/audio con feedback a la IA
3. Retirar cuentos ya publicados para editarlos y volver a publicarlos
4. Tener un TTS en español nativo (no Kokoro fonética inglesa)

## Análisis de los cuentos existentes (ES)

Leídos de Firestore (30 cuentos en español):
- **Longitud**: 300-450 palabras, 1800-2600 caracteres
- **Estructura**: introducción (presentar personaje y lugar mágico) → desarrollo (aventura/conflicto con valores positivos) → resolución con lección moral → cierre con "El fin."
- **Valores**: amabilidad, valentía, curiosidad, amistad
- **Personajes**: niños de 4-12 años, con nombres humanos

## Objetivo

Reemplazar el pipeline one-shot por un **flujo de 3 pasos con feedback** que permite al admin:
- Aprobar/editar/regenerar el texto antes de gastar en imagen y audio
- Aprobar/editar/regenerar la imagen antes de gastar en audio
- Aprobar/regenerar los audios (ES y EN por separado) antes de publicar
- Retirar un cuento publicado para editarlo y volver a publicarlo
- Usar un TTS nativo en español (Azure MAI-Voice-2) en lugar de Kokoro

## No incluido en esta versión

- Notificaciones push (sigue siendo next version)
- Eliminación permanente de cuentos publicados (botón se añade, pero solo accesible desde lista; no en flujo principal de retractación)
- Schedule automático (cron) — sigue siendo on-demand
- Cambios en la app móvil (0 cambios)

## Arquitectura general

Tres componentes, sin tocar la app móvil:

```
┌─────────────────────────────────────────────────────────────────┐
│  WEB ADMIN (Flutter web → Firebase Hosting)                      │
│                                                                  │
│  /drafts (pendientes)        /published (publicados)             │
│  ┌────────────────────┐      ┌──────────────────────┐           │
│  │ [+ Nuevo cuento]   │      │ tale_id=31 [Retirar] │           │
│  │  → creación 3 p.   │      │ tale_id=30 [Retirar] │           │
│  └────────────────────┘      └──────────────────────┘           │
│            │                            │                        │
│            ▼                            ▼                        │
│  PANTALLA DE CREACIÓN (3 pasos):   Retirar → mueve a drafts     │
│                                                                  │
│  Paso 1: TEXTO            Paso 2: IMAGEN        Paso 3: AUDIO   │
│  ┌─────────────┐          ┌─────────────┐       ┌──────────┐  │
│  │ Tema: [___] │          │ [feedback]  │       │ [regen   │  │
│  │ [Generar]   │  ──OK──▶ │ [Generar]   │ ─OK─▶ │  ES/EN]  │  │
│  │ ↓           │          │ ↓           │       │ ↓        │  │
│  │ Editor de   │          │ Preview     │       │ Player   │  │
│  │ texto       │          │ +feedback   │       │ +regen   │  │
│  │ +regenerar  │          │             │       │          │  │
│  └─────────────┘          └─────────────┘       └──────────┘  │
│                                                                  │
│  + [feedback prompt opcional a la IA en cada regenerar]          │
└─────────────────────────────────────────────────────────────────┘
```

### Flujo de creación paso a paso

1. Admin abre `/drafts` → "+ Nuevo cuento" → entra a la pantalla de creación (paso 1)
2. **Paso 1 — Texto**: tema opcional + "Generar texto" → `generateTaleText` crea draft con `step: "text"`. El texto aparece en un editor multilínea (editable a mano). Botones: "Regenerar con feedback" (abre input para feedback prompt) o "Aprobar texto y generar imagen"
3. **Paso 2 — Imagen**: muestra imagen actual (o placeholder). Botones: "Regenerar con feedback" o "Aprobar imagen y generar audio". `generateTaleImage` actualiza el draft con `step: "image"`
4. **Paso 3 — Audio**: muestra ambos audios con player. Botones individuales: "Regenerar audio ES" o "Regenerar audio EN" (cada uno con feedback opcional). `generateTaleAudio` actualiza el draft con `step: "audio"`
5. "Aprobar y publicar" → `approveDraft` (ya existe, sin cambios) → cuento aparece en la app móvil

### Flujo de retractación

1. Admin abre `/published` → ve la lista de cuentos en `tales` (filtrados por `lang: "es"`, ordenados por `tale_id` desc)
2. Click "Retirar" en un cuento → confirmación → `retractTale` mueve el cuento a `tale_drafts` con `status: "pending"`, `step: "audio"` (ya tiene todo, solo pendiente de publicar)
3. El cuento desaparece de la app móvil y aparece en `/drafts`
4. Admin puede: editar texto, regenerar imagen, regenerar audios, y volver a publicar (recibirá un nuevo `tale_id`)

## Modelo de datos

### Cambios en `tale_drafts`

Campos nuevos:
- `step: "text" | "image" | "audio"` (default `"text"`) — fase del pipeline
- `image_prompt: String` — prompt que generó la imagen actual (auditoría)
- `audio_feedback_es: String | null` — feedback pendiente para regenerar audio ES
- `audio_feedback_en: String | null` — feedback pendiente para regenerar audio EN
- `retracted_from_tale_id: number | null` — si fue retractado, qué `tale_id` tenía originalmente

Campos existentes que se mantienen:
- Todos los del spec anterior (`name_es`, `name_en`, `description_es/en`, `specifications_es/en`, `audio_url_es/en`, `image_url`, `image_url_640px`, `status`, etc.)

### Sin cambios en `tales` y `tales_common_data`

La app móvil lee `tales` ordenado por `tale_id` desc — sin cambios.

## Cloud Functions

### Funciones nuevas (reemplazan a `generateTaleDraft`)

| Función | Qué hace | Tiempo | Coste aprox |
|---------|----------|--------|-------------|
| `generateTaleText({theme?, feedback?})` | Crea/regenera texto del draft. Devuelve `{draftId}`. | 20-40s | ~$0.005 |
| `generateTaleImage({draftId, feedback?})` | Genera imagen (1024 + 640) y actualiza draft. | 15-30s | ~$0.05 |
| `generateTaleAudio({draftId, lang, feedback?})` | Genera audio (ES: Azure, EN: Kokoro) y actualiza draft. | 10-20s | ~$0.01 ES, ~$0.003 EN |
| `retractTale({taleId})` | Mueve cuento de `tales` a `tale_drafts`. Devuelve `{draftId}`. | 5-10s | $0 |

### Funciones existentes (sin cambios)

- `approveDraft({draftId})` — publica un draft (ya existe)
- `rejectDraft({draftId})` — elimina un draft (ya existe)

### Función eliminada

- `generateTaleDraft` — se elimina (reemplazada por las 3 funciones nuevas). El botón "Generar" del admin ahora abre la pantalla de creación paso 1 (que llama a `generateTaleText`).

### `retractTale` — detalle

1. Lee `tales/{taleId}_es`, `tales/{taleId}_en`, y `tales_common_data/{taleId}`
2. Crea nuevo doc en `tale_drafts` con todos los campos copiados + `status: "pending"`, `step: "audio"`, `retracted_from_tale_id: taleId`, `assigned_tale_id: null`
3. Mueve archivos Storage: `tales/{taleId}/*` → `drafts/{newDraftId}/*`
4. Borra docs de `tales` (ES+EN) + `tales_common_data`
5. Devuelve `{draftId}` para redirigir a `/drafts`

## TTS (Text-to-Speech)

| Idioma | Modelo | Voz | Razón |
|--------|--------|-----|-------|
| ES | `microsoft/mai-voice-2` (Azure) | `es-MX-Valeria:MAI-Voice-2` | Nativa, expresiva, ideal para cuentos infantiles. Kokoro no maneja bien el español. |
| EN | `hexgrad/kokoro-82m` | `am_adam` | Ya funciona bien (verificado por el admin) |

Ambas voces devuelven MP3 directamente — no hace falta transcodificar.

## Prompt del sistema (`firebase/functions/src/prompts.js`)

Actualizado con la estructura y longitud de los cuentos existentes:

```
You are a children's book author writing for ages 4-8.
Write a COMPLETE, original bedtime story. Rules:
- Safe, gentle, age-appropriate. No violence, weapons, death, or adult themes.
- Positive values (kindness, courage, friendship, curiosity).
- LENGTH: 300-500 words per language.
- STRUCTURE:
  1. Introduction: introduce the child protagonist and the magical/interesting setting
  2. Development: an adventure or small conflict resolved through positive values
  3. Resolution with a clear moral lesson
  4. Close with the words "El fin." at the end
- Provide BOTH Spanish (es) and English (en) versions. The English version must be a natural adaptation (not literal translation).
- Generate a short "image_prompt" (one sentence in English) describing a single warm, friendly illustration that captures the story's mood.
- "description" is a 1-2 sentence teaser for the list view.
- "name" is the story title.

[If feedback provided, append: "USER FEEDBACK: {feedback}"]

Respond ONLY with a JSON object matching: {name_es, description_es, specifications_es, name_en, description_en, specifications_en, image_prompt}
```

## Web Admin (Flutter web)

### Pantallas nuevas

- `/published` — lista de cuentos en `tales`, con botón "Retirar" en cada uno
- `/drafts/create` — pantalla de creación de 3 pasos (reemplaza el botón "Generar" actual)

### Pantallas existentes (sin cambios)

- `/login` — login (existente)
- `/drafts` — lista de borradores (existente)
- `/drafts/:id` — vista detalle (existente, se actualiza para mostrar botones de "Retirar a drafts" si el cuento fue retractado, y muestra `step` del draft)

## Reglas de seguridad (sin cambios)

- `tales` y `tales_common_data`: read-only para clientes (los callables usan admin SDK)
- `tale_drafts` y `drafts/`: solo admin uid (ya configurado)

## Costes operativos

| Concepto | Modelo | Coste/cuento |
|----------|--------|--------------|
| Texto (ES+EN) | `openai/gpt-4o-mini` | ~$0.005 |
| Imagen (1024+640) | `bytedance-seed/seedream-4.5` 2K | ~$0.05 |
| Audio ES | `microsoft/mai-voice-2` | ~$0.01 |
| Audio EN | `hexgrad/kokoro-82m` | ~$0.003 |
| **Total por cuento final** (sin iteraciones) | | **~$0.068** |
| **Con 2 iteraciones de texto + 1 de imagen** | | **~$0.078** |

## Seguridad

| Vector | Mitigación |
|--------|-----------|
| Llamadas no autorizadas a los callables | `requireAuth(req)` verifica `req.auth.uid === ADMIN_UID` (secret) |
| API key expuesta | Solo en Cloud Functions vía Secret Manager |
| Borrado accidental de un cuento retractado | `retractTale` no borra hasta que Storage move se completa con éxito |
| Doble retractación del mismo cuento | `retractTale` verifica que el cuento existe en `tales` antes de actuar |
| Edición manual del admin en el editor de texto | Se guarda como el nuevo `specifications_es/en`; el prompt original se preserva en logs (no en Firestore, para ahorrar espacio) |

## Riesgos técnicos

1. **Calidad del TTS Azure con texto largo**: el cuento tiene ~400 palabras (~2400 chars) — Azure puede tardar o fallar con textos muy largos. *Mitigación:* si falla, fallback a Kokoro con `af_bella` (voz más neutra). Si también falla, el draft queda con `audio_url_es: null` y el admin puede reintentar.
2. **Retractación falla a mitad**: si se mueve el draft a `tale_drafts` pero no se borra de `tales`, hay duplicación. *Mitigación:* `retractTale` usa transacción de Firestore para borrar `tales` + `tales_common_data` y crear el draft en `tale_drafts` atómicamente. Los archivos de Storage se mueven ANTES de la transacción (si fallan, el cuento queda en estado inconsistente — admin puede reintentar).
3. **Editor de texto y longitud**: si el admin edita el texto a mano y lo deja en 50 palabras o 2000 palabras, no hay validación. *Mitigación:* mostrar un contador de palabras junto al editor, advertir si <200 o >600.
4. **Feedback prompt malicioso o vacío**: el admin puede escribir lo que quiera en el feedback. *Mitigación:* si el feedback está vacío, no se concatena al prompt. Si tiene >500 chars, se trunca.
5. **`tale_id` gaps**: al retractar y republicar, el nuevo `tale_id` será el siguiente disponible, no el original. Aceptable: la app móvil no nota la diferencia (el cuento simplemente reaparece).

## Plan de validación

### Fase 1 — Refactor de functions existentes
- Mantener `generateTaleDraft` como deprecated, añadir `generateTaleText/Image/Audio` con tests
- Desplegar, verificar E2E que el flujo por pasos funciona

### Fase 2 — UI de creación
- Implementar pantalla de creación de 3 pasos con feedback
- Verificar manualmente: crear un cuento, iterar en cada paso, publicar

### Fase 3 — Retractación
- Implementar `retractTale` + lista de publicados
- Verificar manualmente: publicar un cuento → retractar → editar → republicar (con nuevo `tale_id`)

### Fase 4 — TTS Azure
- Cambiar TTS ES de Kokoro a `mai-voice-2` con `es-MX-Valeria`
- Verificar manualmente: calidad del audio en español

## Fuera de scope (explícito)

- Notificaciones push (sigue siendo next version; OneSignal ya en `package.json`)
- Schedule automático (cron)
- Eliminación permanente de cuentos (botón secundario, no en flujo principal)
- Programmatic SEO / marketing
- Cambios en la app móvil
- Cambios en AdMob / monetización
