# Diseño: Flag "Premium" en borradores del admin

**Fecha**: 2026-07-16
**Alcance**: solo borradores (`tale_drafts`). Editar `is_premium_tale` en cuentos ya publicados queda fuera de esta fase y se abordará en un spec posterior.

## Contexto

El admin (`lib/admin/`) permite crear, editar y publicar borradores de cuentos (`tale_drafts` en Firestore) desde `draft_workspace_page.dart`. El modelo de cuento **publicado** (`lib/backend/schema/tales_record.dart`) ya tiene un campo `is_premium_tale` (bool) que la app móvil usa activamente para mostrar el teaser premium (`lib/components/tale_detail_mobile_component_widget.dart`, `tale_detail_tablet_component_widget.dart`, y los widgets de listado), en combinación con `PremiumProvider` (`lib/services/subscription_service.dart`).

Ese campo no existe hoy en el modelo de borrador (`lib/admin/models/draft.dart`), ni hay forma de establecerlo desde el editor. El objetivo es cerrar ese hueco: permitir marcar un borrador como premium antes de publicarlo, y que ese valor se traslade automáticamente al cuento publicado, reusando la lógica de teaser premium que ya existe end-to-end en la app móvil (no requiere cambios ahí).

## Modelo de datos

**`lib/admin/models/draft.dart`**
- Nuevo campo `final bool isPremiumTale;`.
- Se parsea desde Firestore como `is_premium_tale`, leyendo `data['is_premium_tale'] ?? false` — los borradores existentes sin el campo se tratan como `false`, sin necesidad de migración/backfill.
- Se añade al constructor y a cualquier `copyWith` existente del modelo.

**`lib/admin/services/drafts_service.dart`**
- Nuevo método:
  ```dart
  Future<void> updateDraftPremium({required String draftId, required bool isPremiumTale}) {
    return FirebaseFirestore.instance
        .collection('tale_drafts')
        .doc(draftId)
        .update({'is_premium_tale': isPremiumTale});
  }
  ```
- Escritura directa a Firestore, mismo patrón que `updateManualDraftText`. No se crea una Cloud Function callable nueva: las reglas de Firestore (`firebase/firestore.rules`, líneas 18-22) ya conceden `read, write` completo sobre `tale_drafts` al uid fijo del admin, así que no hace falta tocar `firestore.rules`.

## Propagación al publicar

**`firebase/functions/src/approveDraft.js`**
- En los dos bloques `.set()` que crean `tales/{taleId}_es` y `tales/{taleId}_en` (dentro de `publishDraft`, líneas ~49-65 y ~68-84), añadir:
  ```js
  is_premium_tale: d.is_premium_tale ?? false,
  ```
- Es un campo más copiado igual que `name_es`/`description_es`/etc. No cambia el resto del flujo de aprobación ni su manejo de errores.

## UI del editor de borradores

**Nueva sección "Ajustes" en `lib/admin/drafts/draft_workspace_page.dart`**
- Nuevo método `_buildSettingsSection()` que devuelve un `AppCard` con la misma cabecera visual que las demás secciones (icono + título "Ajustes"), colocado como **primer elemento** del `Column` del body (`build()`, antes del `Row` con texto/imagen/audio) — visible siempre, independientemente del `step` del borrador.
- Contiene un `SwitchListTile`:
  - `title`: "Cuento Premium"
  - `subtitle`: "Solo visible para usuarios con suscripción"
  - `value: _draft?.isPremiumTale ?? false`
  - `onChanged`: `null` (deshabilitado) si `_draft == null` — no se puede marcar premium un borrador que aún no existe en Firestore (antes del primer guardado de texto).
- Nuevo método `_toggleIsPremium(bool value)`:
  - Actualización optimista: `setState` inmediato con el nuevo valor.
  - Llama a `_service.updateDraftPremium(draftId: _draftId!, isPremiumTale: value)`.
  - Éxito: `ScaffoldMessenger` con `SnackBar` de confirmación ("Premium actualizado").
  - Error: revierte el `setState` al valor anterior y muestra `SnackBar` con el error — mismo patrón que el resto de acciones de la página (`_saveManualText`, `_generateImageAI`, etc.).
- El toggle se guarda al instante, sin depender del botón "Guardar Textos" — es una acción independiente, igual que subir una imagen o generar audio.

## Badge en el listado de borradores

**`lib/admin/widgets/status_badge.dart`**
- Nuevo factory constructor:
  ```dart
  factory StatusBadge.premium() =>
      const StatusBadge(icon: Icons.star, label: 'Premium', color: AppColors.warning);
  ```
  Reutiliza `AppColors.warning` (ámbar, `0xFFD97706`) ya existente en la paleta — no se añade un color nuevo.

**`lib/admin/drafts/drafts_list_page.dart`**
- Dentro del `Row` de badges (línea ~97-109, junto a `StatusBadge.step(d.step)` y `StatusBadge.retracted()`), añadir condicionalmente:
  ```dart
  if (d.isPremiumTale) ...[
    const SizedBox(width: AppSpacing.sm),
    StatusBadge.premium(),
  ],
  ```

## Manejo de errores

- Toggle del editor: optimista con reversión en caso de fallo (ver arriba). Consistente con el resto de acciones de `draft_workspace_page.dart`.
- `approveDraft.js`: sin manejo de errores nuevo — `is_premium_tale` es un campo más dentro de un `.set()` que ya gestiona sus propios errores a nivel de función.
- Borradores sin el campo (`is_premium_tale` ausente): cubierto por `?? false` tanto en la lectura del admin como en la propagación al publicar. No requiere backfill de datos existentes.

## Verificación

No existe suite de tests de UI en el admin; la verificación de la parte Flutter es manual:

1. Abrir un borrador existente en el admin (local, apuntando al proyecto Firebase real). Confirmar que la tarjeta "Ajustes" aparece con el switch en `false` por defecto.
2. Activar el switch, confirmar el `SnackBar` de guardado y que el valor persiste tras recargar la página (relee de Firestore).
3. Verificar en el listado de borradores (`drafts_list_page.dart`) que aparece el badge "Premium" para ese borrador.
4. Completar el flujo hasta "Aprobar y Publicar". Verificar en Firestore que el `tale` publicado resultante (`_es` y `_en`) tiene `is_premium_tale: true`, y en la app móvil que se muestra el teaser premium correspondiente.
5. Repetir el flujo con un borrador sin marcar como premium, confirmando que se publica con `is_premium_tale: false` y sin teaser.

Adicionalmente, existe `firebase/functions/__tests__/approveDraft.test.js`: se debe extender con un caso que verifique que `is_premium_tale: true` en el borrador se propaga a ambos documentos publicados (`_es`/`_en`), y otro que verifique que un borrador sin el campo (o `false`) publica con `is_premium_tale: false`.

## Fuera de alcance

- Edición de `is_premium_tale` en cuentos ya publicados (formulario de publicados) — fase futura.
- Cambios en la app móvil — el consumo de `is_premium_tale` ya existe y no requiere modificación.
- Sistema genérico de flags/settings extensible — se descartó por sobre-ingeniería (YAGNI); solo se implementa el campo `is_premium_tale` concreto.
