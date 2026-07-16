# Flag "Premium" en Borradores — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir marcar un borrador de cuento como "premium" desde el editor del admin, y propagar ese estado automáticamente al cuento publicado cuando se aprueba el borrador.

**Architecture:** El campo `is_premium_tale` (bool) ya existe en el modelo de cuento publicado (`TalesRecord`) y ya lo consume la app móvil para mostrar el teaser premium. Este plan cierra el hueco del lado admin: añade el mismo campo al modelo de borrador, un toggle en el editor que escribe directo a Firestore (mismo patrón que el resto del admin, sin Cloud Function nueva), un badge en el listado, y la propagación del campo dentro de la Cloud Function `approveDraft` que ya copia el resto de campos del borrador al publicar.

**Tech Stack:** Flutter (admin web, `lib/admin/`), Cloud Firestore, Cloud Functions Node.js/Jest (`firebase/functions/`).

## Global Constraints

- Nombre del campo: `is_premium_tale` en Firestore (snake_case), `isPremiumTale` en Dart (camelCase) — mismo nombre que ya usa `TalesRecord`, no se introduce un nombre nuevo.
- Sin Cloud Function nueva para escribir el flag: se usa escritura directa a Firestore desde el cliente admin (mismo patrón que `updateManualDraftText`).
- Sin cambios en `firebase/firestore.rules` (el admin ya tiene `read, write` completo sobre `tale_drafts`).
- Sin cambios en la app móvil (ya consume `is_premium_tale` en los cuentos publicados).
- Sin dependencias nuevas en `pubspec.yaml` ni en `firebase/functions/package.json`.
- Alcance limitado a borradores y a su propagación al publicar; el editor de cuentos ya publicados queda fuera de este plan.
- Reutilizar `AppColors.warning` (`0xFFD97706`) para el badge premium — no se añade un color nuevo a la paleta.

---

### Task 1: Data layer — modelo `Draft` y `DraftsService`

**Files:**
- Modify: `lib/admin/models/draft.dart`
- Modify: `lib/admin/services/drafts_service.dart`

**Interfaces:**
- Produces: `Draft.isPremiumTale` (bool, no-nullable, default `false`) — leído por las Tasks 2 y 3.
- Produces: `DraftsService.updateDraftPremium({required String draftId, required bool isPremiumTale}) → Future<void>` — usado por la Task 3.
- `DraftsService.createManualDraft(...)` (firma sin cambios) ahora escribe también `is_premium_tale: false` en el documento nuevo.

- [ ] **Step 1: Añadir el campo `isPremiumTale` al modelo `Draft`**

Reemplaza el contenido completo de `lib/admin/models/draft.dart` por:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Draft {
  final String id;
  final String status;
  final DateTime? createdAt;
  final String nameEs;
  final String descriptionEs;
  final String specificationsEs;
  final String audioUrlEs;
  final String nameEn;
  final String descriptionEn;
  final String specificationsEn;
  final String audioUrlEn;
  final String imageUrl;
  final String imageUrl640;
  final String imagePrompt;
  final int? assignedTaleId;
  final int? retractedFromTaleId;
  final bool isPremiumTale;

  Draft({
    required this.id,
    required this.status,
    this.createdAt,
    required this.nameEs,
    required this.descriptionEs,
    required this.specificationsEs,
    required this.audioUrlEs,
    required this.nameEn,
    required this.descriptionEn,
    required this.specificationsEn,
    required this.audioUrlEn,
    required this.imageUrl,
    required this.imageUrl640,
    required this.imagePrompt,
    this.assignedTaleId,
    this.retractedFromTaleId,
    this.isPremiumTale = false,
  });

  /// Derived purely from which assets exist — never stored, so it can
  /// never disagree with the draft's actual Firestore fields.
  String get step {
    if (imageUrl.isNotEmpty && audioUrlEs.isNotEmpty && audioUrlEn.isNotEmpty) return 'audio';
    if (imageUrl.isNotEmpty) return 'image';
    return 'text';
  }

  factory Draft.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Draft(
      id: doc.id,
      status: d['status'] as String? ?? 'pending',
      createdAt: (d['created_at'] as Timestamp?)?.toDate(),
      nameEs: d['name_es'] as String? ?? '',
      descriptionEs: d['description_es'] as String? ?? '',
      specificationsEs: d['specifications_es'] as String? ?? '',
      audioUrlEs: d['audio_url_es'] as String? ?? '',
      nameEn: d['name_en'] as String? ?? '',
      descriptionEn: d['description_en'] as String? ?? '',
      specificationsEn: d['specifications_en'] as String? ?? '',
      audioUrlEn: d['audio_url_en'] as String? ?? '',
      imageUrl: d['image_url'] as String? ?? '',
      imageUrl640: d['image_url_640px'] as String? ?? '',
      imagePrompt: d['image_prompt'] as String? ?? '',
      assignedTaleId: d['assigned_tale_id'] as int?,
      retractedFromTaleId: d['retracted_from_tale_id'] as int?,
      isPremiumTale: d['is_premium_tale'] as bool? ?? false,
    );
  }
}
```

- [ ] **Step 2: Escribir `is_premium_tale: false` al crear un borrador manual**

En `lib/admin/services/drafts_service.dart`, dentro de `createManualDraft`, sustituye:

```dart
      'image_url': '',
      'image_url_640px': '',
      'assigned_tale_id': null,
      'retracted_from_tale_id': null,
    });
    return ref.id;
  }
```

por:

```dart
      'image_url': '',
      'image_url_640px': '',
      'assigned_tale_id': null,
      'retracted_from_tale_id': null,
      'is_premium_tale': false,
    });
    return ref.id;
  }
```

- [ ] **Step 3: Añadir `updateDraftPremium` al servicio**

En el mismo archivo, justo después del cierre del método `updateManualDraftText` (después de la línea `}` que sigue a `});`) e inmediatamente antes de `UploadTask uploadDraftImage(...)`, inserta:

```dart
  Future<void> updateDraftPremium({required String draftId, required bool isPremiumTale}) async {
    await _db.collection('tale_drafts').doc(draftId).update({'is_premium_tale': isPremiumTale});
  }

```

- [ ] **Step 4: Verificar con `flutter analyze`**

Run: `flutter analyze lib/admin`
Expected: `7 issues found.` — las mismas 7 preexistentes (imports sin usar en `app.dart`/`main_admin.dart`, `withOpacity` deprecado en `admin_scaffold.dart`/`skeleton_loader.dart`). Ninguna debe referenciar `draft.dart` ni `drafts_service.dart`. Si aparece algún issue nuevo en esos dos archivos, corrígelo antes de continuar.

- [ ] **Step 5: Commit**

```bash
git add lib/admin/models/draft.dart lib/admin/services/drafts_service.dart
git commit -m "feat(admin): add is_premium_tale field to Draft model and service"
```

---

### Task 2: Badge "Premium" en el listado de borradores

**Files:**
- Modify: `lib/admin/widgets/status_badge.dart`
- Modify: `lib/admin/drafts/drafts_list_page.dart`

**Interfaces:**
- Consumes: `Draft.isPremiumTale` (Task 1).
- Produces: `StatusBadge.premium()` factory — no se consume fuera de `drafts_list_page.dart` en este plan.

- [ ] **Step 1: Añadir el factory `StatusBadge.premium()`**

En `lib/admin/widgets/status_badge.dart`, sustituye:

```dart
  factory StatusBadge.retracted() =>
      const StatusBadge(icon: Icons.history, label: 'Retractado', color: AppColors.warning);

  @override
```

por:

```dart
  factory StatusBadge.retracted() =>
      const StatusBadge(icon: Icons.history, label: 'Retractado', color: AppColors.warning);

  factory StatusBadge.premium() =>
      const StatusBadge(icon: Icons.star, label: 'Premium', color: AppColors.warning);

  @override
```

- [ ] **Step 2: Mostrar el badge en el listado de borradores**

En `lib/admin/drafts/drafts_list_page.dart`, sustituye:

```dart
                          Row(
                            children: [
                              StatusBadge.step(d.step),
                              if (d.retractedFromTaleId != null) ...[
                                const SizedBox(width: AppSpacing.sm),
                                StatusBadge.retracted(),
                              ],
                              const SizedBox(width: AppSpacing.sm),
```

por:

```dart
                          Row(
                            children: [
                              StatusBadge.step(d.step),
                              if (d.isPremiumTale) ...[
                                const SizedBox(width: AppSpacing.sm),
                                StatusBadge.premium(),
                              ],
                              if (d.retractedFromTaleId != null) ...[
                                const SizedBox(width: AppSpacing.sm),
                                StatusBadge.retracted(),
                              ],
                              const SizedBox(width: AppSpacing.sm),
```

- [ ] **Step 3: Verificar con `flutter analyze`**

Run: `flutter analyze lib/admin`
Expected: `7 issues found.` (mismo baseline que en la Task 1), ninguno en `status_badge.dart` ni `drafts_list_page.dart`.

- [ ] **Step 4: Commit**

```bash
git add lib/admin/widgets/status_badge.dart lib/admin/drafts/drafts_list_page.dart
git commit -m "feat(admin): show premium badge in drafts list"
```

---

### Task 3: Toggle "Premium" en el editor de borradores

**Files:**
- Modify: `lib/admin/drafts/draft_workspace_page.dart`

**Interfaces:**
- Consumes: `Draft.isPremiumTale`, `DraftsService.updateDraftPremium` (Task 1).
- Produces: sección `_buildSettingsSection()` y método `_toggleIsPremium(bool)` — internos a la página, no se reutilizan en otras tasks.

- [ ] **Step 1: Añadir el estado `_savingPremium`**

En `lib/admin/drafts/draft_workspace_page.dart`, sustituye:

```dart
  Draft? _draft;
  String? _draftId;
  bool _loading = false;
  bool _saving = false;
```

por:

```dart
  Draft? _draft;
  String? _draftId;
  bool _loading = false;
  bool _saving = false;
  bool _savingPremium = false;
```

- [ ] **Step 2: Añadir la acción `_toggleIsPremium`**

Sustituye:

```dart
  int _wordCount(String s) => s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;

  // --- ACTIONS: TEXT ---
```

por:

```dart
  int _wordCount(String s) => s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;

  // --- ACTIONS: SETTINGS ---

  Future<void> _toggleIsPremium(bool value) async {
    if (_draftId == null) return;
    setState(() => _savingPremium = true);
    try {
      await _service.updateDraftPremium(draftId: _draftId!, isPremiumTale: value);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Premium actualizado')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _savingPremium = false);
    }
  }

  // --- ACTIONS: TEXT ---
```

Nota: no hace falta revertir manualmente el valor si la escritura falla — el switch está enlazado a `_draft?.isPremiumTale`, y `_draft` se actualiza solo a través del `Stream` de `streamDraft` (ver `_loadDraft`). Si `updateDraftPremium` falla, Firestore nunca cambió, así que `_draft` nunca cambió, y el switch vuelve a mostrar su valor real sin ningún estado local que revertir.

- [ ] **Step 3: Insertar la sección "Ajustes" al principio del body**

Sustituye:

```dart
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildTextSection()),
```

por:

```dart
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            _buildSettingsSection(),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildTextSection()),
```

- [ ] **Step 4: Implementar `_buildSettingsSection()`**

Sustituye:

```dart
  Widget _buildTextSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.text_fields, color: AppColors.primary),
              SizedBox(width: 8),
              Text('1. Textos del Cuento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
```

por:

```dart
  Widget _buildSettingsSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Ajustes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const Divider(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cuento Premium'),
            subtitle: const Text('Solo visible para usuarios con suscripción'),
            value: _draft?.isPremiumTale ?? false,
            onChanged: (_draft == null || _savingPremium) ? null : _toggleIsPremium,
          ),
        ],
      ),
    );
  }

  Widget _buildTextSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.text_fields, color: AppColors.primary),
              SizedBox(width: 8),
              Text('1. Textos del Cuento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
```

- [ ] **Step 5: Verificar con `flutter analyze`**

Run: `flutter analyze lib/admin`
Expected: `7 issues found.` (mismo baseline), ninguno en `draft_workspace_page.dart`.

- [ ] **Step 6: Verificar que compila para web**

Run: `flutter build web -t lib/admin/main_admin.dart --no-pub`
Expected: termina con `✓ Built build/web` y sin errores.

- [ ] **Step 7: Commit**

```bash
git add lib/admin/drafts/draft_workspace_page.dart
git commit -m "feat(admin): add premium toggle to draft workspace settings section"
```

---

### Task 4: Propagar `is_premium_tale` al publicar (Cloud Function)

**Files:**
- Modify: `firebase/functions/src/approveDraft.js`
- Modify: `firebase/functions/__tests__/approveDraft.test.js`

**Interfaces:**
- Consumes: nada de las tasks anteriores (Node.js, codebase independiente de Flutter).
- Produces: campo `is_premium_tale` en `tales/{taleId}_es` y `tales/{taleId}_en` — consumido por la Task 5 (verificación manual) y por la app móvil (ya existente, sin cambios).

- [ ] **Step 1: Escribir los tests que fallan**

En `firebase/functions/__tests__/approveDraft.test.js`, dentro del bloque `describe("approveDraft", ...)`, justo antes del `});` final (después del último test, `"throws failed-precondition when the draft is missing an asset..."`), añade:

```js

  // __sets acumula entradas de TODOS los tests anteriores en este archivo
  // (el mock de admin no resetea el array entre tests), así que cada test
  // aquí sólo mira las 2 últimas entradas "tales" — las que genera su propia
  // llamada a approveDraftHandler.
  test("propagates is_premium_tale: true from draft to both published tales", async () => {
    const admin = require("../src/admin");
    admin.__setDraft("pending", true);
    admin.__setDraftOverrides({ is_premium_tale: true });

    await approveDraftHandler({ data: { draftId: "d1" }, auth: { uid: "admin" } });

    const talesSets = admin.__sets.filter((s) => s.name === "tales").slice(-2);
    expect(talesSets[0].d.is_premium_tale).toBe(true);
    expect(talesSets[1].d.is_premium_tale).toBe(true);
    admin.__setDraftOverrides({});
  });

  test("defaults is_premium_tale to false when the draft has no such field", async () => {
    const admin = require("../src/admin");
    admin.__setDraft("pending", true);

    await approveDraftHandler({ data: { draftId: "d1" }, auth: { uid: "admin" } });

    const talesSets = admin.__sets.filter((s) => s.name === "tales").slice(-2);
    expect(talesSets[0].d.is_premium_tale).toBe(false);
    expect(talesSets[1].d.is_premium_tale).toBe(false);
  });
```

- [ ] **Step 2: Ejecutar los tests y confirmar que fallan**

Run: `cd firebase/functions && npx jest __tests__/approveDraft.test.js`
Expected: `Tests: 2 failed, 6 passed, 8 total` — los dos tests nuevos fallan con `expect(received).toBe(true)` / `toBe(false)` recibiendo `undefined` (el campo aún no se escribe).

- [ ] **Step 3: Implementar la propagación**

En `firebase/functions/src/approveDraft.js`, sustituye:

```js
    lang: "es",
    tale_id: taleId,
    tale_common_data_ref: commonRef,
    audio_url: audioUrlEs,
  });
```

por:

```js
    lang: "es",
    tale_id: taleId,
    tale_common_data_ref: commonRef,
    audio_url: audioUrlEs,
    is_premium_tale: d.is_premium_tale ?? false,
  });
```

y sustituye:

```js
    lang: "en",
    tale_id: taleId,
    tale_common_data_ref: commonRef,
    audio_url: audioUrlEn,
  });
```

por:

```js
    lang: "en",
    tale_id: taleId,
    tale_common_data_ref: commonRef,
    audio_url: audioUrlEn,
    is_premium_tale: d.is_premium_tale ?? false,
  });
```

- [ ] **Step 4: Ejecutar los tests y confirmar que pasan**

Run: `cd firebase/functions && npx jest __tests__/approveDraft.test.js`
Expected: `Tests: 8 passed, 8 total`

- [ ] **Step 5: Commit**

```bash
cd firebase/functions
git add src/approveDraft.js __tests__/approveDraft.test.js
git commit -m "feat(functions): propagate is_premium_tale from draft to published tale on approve"
```

---

### Task 5: Verificación manual end-to-end

**Files:** ninguno (solo verificación, sin cambios de código).

**Interfaces:**
- Consumes: todo lo producido en las Tasks 1-4.

- [ ] **Step 1: Levantar el admin en local**

Run: `flutter run -t lib/admin/main_admin.dart -d chrome`
Espera a que cargue en el navegador y hacer login como admin.

- [ ] **Step 2: Verificar el toggle en un borrador existente**

Abrir `/drafts`, entrar en un borrador existente. Confirmar que aparece la tarjeta "Ajustes" arriba del todo, con el switch "Cuento Premium" en apagado por defecto.

- [ ] **Step 3: Activar el switch y verificar persistencia**

Activar el switch. Confirmar el `SnackBar` "Premium actualizado". Recargar la página (F5) y confirmar que el switch sigue activado (se releyó de Firestore).

- [ ] **Step 4: Verificar el badge en el listado**

Volver a `/drafts`. Confirmar que el borrador marcado muestra el badge "Premium" (icono de estrella, color ámbar) junto al badge de estado.

- [ ] **Step 5: Publicar y verificar la propagación**

Completar el borrador (imagen + audio ES/EN) si no lo tiene, y pulsar "Aprobar y Publicar Cuento". En la consola de Firebase (Firestore), abrir `tales/{taleId}_es` y `tales/{taleId}_en` y confirmar que ambos tienen `is_premium_tale: true`.

- [ ] **Step 6: Verificar el teaser premium en la app móvil**

Abrir la app móvil (o el mismo proyecto Firebase en un simulador/emulador) con una cuenta sin suscripción activa, navegar al cuento recién publicado, y confirmar que se muestra el teaser premium (`showPremiumTeaser` en `tale_detail_mobile_component_widget.dart` / `tale_detail_tablet_component_widget.dart`).

- [ ] **Step 7: Verificar el caso negativo**

Repetir el flujo completo (Steps 2-6) con un borrador que se deja sin marcar como premium. Confirmar que se publica con `is_premium_tale: false`, sin badge en el listado y sin teaser en la app móvil.
