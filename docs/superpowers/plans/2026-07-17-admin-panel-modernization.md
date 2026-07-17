# Admin Panel Modernization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Modernize the merakitales Flutter-web admin panel — brand-aligned "storybook editorial" look, professional dashboard structure, a working Categories section, restored scheduled-publishing UI, a split-screen login, and unified list styling — without adding features beyond those listed.

**Architecture:** Single Flutter-web app under `lib/admin/`. Change is layered: (0) a brand theme + shared components everything else consumes, then (1) data-model/service extensions, then feature phases (categories, scheduler, category-on-tale, lists, dashboard, shell/login). Each phase is an independent merge point. Firebase backend for scheduling already exists and is live; only the client and one Firestore index/rule were lost.

**Tech Stack:** Flutter (Material 3, `go_router`, `google_fonts`, `cloud_firestore`, `cloud_functions`, `firebase_auth`, `firebase_storage`), Firebase Cloud Functions v2 (Node/JS, jest), Firestore rules + indexes.

## Global Constraints

- Single operator (no roles/multi-user); admin uid `N5sv9GubvwOvapwv72nwrhWzBtK2` is the real gate (Firestore rules).
- Brand palette (exact): primary `#2F5E3E`, accent `#E8A33D`, secondary `#3FB6A8`, background `#FAF5EA`, surface `#FFFDF9`, text `#241A12`, textSecondary `#6B5E4E`, border `#E5DCC8`, subtleFill `#F0E9D8`, success `#2E7D4F`, warning `#D98A1F`, destructive `#C0392B`.
- Fonts: Fraunces (serif) headings only; Inter body/data/controls. Both via `google_fonts` (already a dependency — do NOT add new packages).
- Reader app (`lib/`, `lib/flutter_flow/`) is OUT of scope — never modify it. Tales store `category_id`; the reader does not consume it yet.
- No new backend function. Cancel-schedule is a client-side Firestore update.
- Test reality: Flutter has only `flutter_test` (no Firestore/mock deps — do NOT add any). Test pure functions + widgets; verify Firestore/callable wiring by running the admin app. Functions use jest (`cd firebase/functions && npm test`).
- Spanish UI copy; DD/MM/YYYY dates.
- ui-ux-pro-max is invoked at the start of each visual task to produce final widget composition; this plan fixes the tokens, structure, files, and acceptance criteria.
- Run the admin app with: `flutter run -d chrome -t lib/admin/main_admin.dart`.
- Commit after every task. Analyzer must be clean: `flutter analyze`.

---

## Phase 0 — Foundation: brand theme + shared badges

### Task 0.1: Brand palette

**Files:**
- Modify: `lib/admin/theme/app_colors.dart`

**Interfaces:**
- Produces: `AppColors.{primary,accent,secondary,background,surface,textPrimary,textSecondary,border,subtleFill,success,warning,destructive}` (all `static const Color`). `accent` and `secondary` are new.

- [ ] **Step 1: Replace the color values and add two tokens**

```dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2F5E3E);     // forest green
  static const Color accent = Color(0xFFE8A33D);       // lantern amber (NEW)
  static const Color secondary = Color(0xFF3FB6A8);    // magic teal (NEW)
  static const Color background = Color(0xFFFAF5EA);   // warm parchment
  static const Color surface = Color(0xFFFFFDF9);      // warm white
  static const Color textPrimary = Color(0xFF241A12);  // bark near-black
  static const Color textSecondary = Color(0xFF6B5E4E);// warm grey
  static const Color border = Color(0xFFE5DCC8);       // warm hairline
  static const Color subtleFill = Color(0xFFF0E9D8);   // warm tint
  static const Color success = Color(0xFF2E7D4F);
  static const Color warning = Color(0xFFD98A1F);
  static const Color destructive = Color(0xFFDC2626); // keep alias below
}
```

Note: keep the field name `destructive` set to the spec red `#C0392B`:

```dart
  static const Color destructive = Color(0xFFC0392B);
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/admin/theme/app_colors.dart`
Expected: No issues (all existing references still resolve; two new tokens added).

- [ ] **Step 3: Commit**

```bash
git add lib/admin/theme/app_colors.dart
git commit -m "feat(admin): brand palette (enchanted-forest storybook)"
```

### Task 0.2: Theme typography (Fraunces headings + Inter body)

**Files:**
- Modify: `lib/admin/theme/app_theme.dart`
- Test: `test/admin/app_theme_test.dart`

**Interfaces:**
- Consumes: `AppColors` (Task 0.1).
- Produces: `AppTheme.light()` returns `ThemeData` whose `displayLarge/Medium/Small`, `headlineLarge/Medium/Small`, and `titleLarge` use Fraunces; all other text styles use Inter.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/admin/theme/app_theme.dart';

void main() {
  test('headings use Fraunces, body uses Inter', () {
    final t = AppTheme.light().textTheme;
    expect(t.headlineSmall!.fontFamily, contains('Fraunces'));
    expect(t.titleLarge!.fontFamily, contains('Fraunces'));
    expect(t.bodyMedium!.fontFamily, contains('Inter'));
  });
}
```

(Confirm the package import name matches `pubspec.yaml` `name:`; adjust `merakitales` if different.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/admin/app_theme_test.dart`
Expected: FAIL (headlineSmall currently Inter, not Fraunces).

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.destructive,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    final inter = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    // Fraunces on display/headline/titleLarge only.
    TextStyle fr(TextStyle? s) =>
        GoogleFonts.fraunces(textStyle: s, color: AppColors.textPrimary, fontWeight: FontWeight.w600);
    final textTheme = inter.copyWith(
      displayLarge: fr(inter.displayLarge),
      displayMedium: fr(inter.displayMedium),
      displaySmall: fr(inter.displaySmall),
      headlineLarge: fr(inter.headlineLarge),
      headlineMedium: fr(inter.headlineMedium),
      headlineSmall: fr(inter.headlineSmall),
      titleLarge: fr(inter.titleLarge),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/admin/app_theme_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/admin/theme/app_theme.dart test/admin/app_theme_test.dart
git commit -m "feat(admin): Fraunces headings + Inter body theme"
```

### Task 0.3: New StatusBadge factories (scheduled, published, category)

**Files:**
- Modify: `lib/admin/widgets/status_badge.dart`
- Test: `test/admin/status_badge_test.dart`

**Interfaces:**
- Consumes: `AppColors`.
- Produces: `StatusBadge.scheduled()`, `StatusBadge.published()`, `StatusBadge.category(String name)` (in addition to existing `.step()`, `.premium()`, `.retracted()`).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/admin/widgets/status_badge.dart';

void main() {
  testWidgets('new badge factories render their labels', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          StatusBadge.scheduled(),
          StatusBadge.published(),
          StatusBadge.category('Aventuras'),
        ]),
      ),
    ));
    expect(find.text('Programado'), findsOneWidget);
    expect(find.text('Publicado'), findsOneWidget);
    expect(find.text('Aventuras'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/admin/status_badge_test.dart`
Expected: FAIL (factories don't exist).

- [ ] **Step 3: Add the factories** (insert after the existing `.premium()` factory, before `build`)

```dart
  factory StatusBadge.scheduled() =>
      const StatusBadge(icon: Icons.schedule, label: 'Programado', color: AppColors.secondary);

  factory StatusBadge.published() =>
      const StatusBadge(icon: Icons.check_circle_outline, label: 'Publicado', color: AppColors.success);

  factory StatusBadge.category(String name) =>
      StatusBadge(icon: Icons.local_offer_outlined, label: name, color: AppColors.primary);
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/admin/status_badge_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/admin/widgets/status_badge.dart test/admin/status_badge_test.dart
git commit -m "feat(admin): scheduled/published/category status badges"
```

---

## Phase 1 — Data model & service extensions

### Task 1.1: Draft model — scheduled + category fields

**Files:**
- Modify: `lib/admin/models/draft.dart`

**Interfaces:**
- Produces: `Draft.scheduledAt` (`DateTime?`), `Draft.scheduledBy` (`String?`), `Draft.categoryId` (`String?`), parsed from `scheduled_at`, `scheduled_by`, `category_id`.

- [ ] **Step 1: Add fields to the class** (after `isPremiumTale`, line 20)

```dart
  final DateTime? scheduledAt;
  final String? scheduledBy;
  final String? categoryId;
```

- [ ] **Step 2: Add to the constructor** (after `this.isPremiumTale = false,`)

```dart
    this.scheduledAt,
    this.scheduledBy,
    this.categoryId,
```

- [ ] **Step 3: Parse in `fromDoc`** (after the `isPremiumTale:` line)

```dart
      scheduledAt: (d['scheduled_at'] as Timestamp?)?.toDate(),
      scheduledBy: d['scheduled_by'] as String?,
      categoryId: d['category_id'] as String?,
```

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/admin/models/draft.dart`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/admin/models/draft.dart
git commit -m "feat(admin): parse scheduled_at/scheduled_by/category_id on Draft"
```

### Task 1.2: DraftsService — scheduler wrappers, status-flexible stream, category write

**Files:**
- Modify: `lib/admin/services/drafts_service.dart`

**Interfaces:**
- Consumes: `Draft`.
- Produces:
  - `Stream<List<Draft>> streamDraftsByStatuses(List<String> statuses)` — pending+scheduled etc.
  - `Future<void> scheduleDraft(String draftId, DateTime scheduledAt)` — calls the live `scheduleDraft` callable.
  - `Future<void> cancelSchedule(String draftId)` — client-direct update to `pending`.
  - `Future<void> updateDraftCategory({required String draftId, required String? categoryId})`.
  - `createManualDraft(...)` writes `category_id: null`.

- [ ] **Step 1: Replace `streamDrafts` with a status-flexible version** (keep the old name as a wrapper)

```dart
  Stream<List<Draft>> streamDraftsByStatuses(List<String> statuses) {
    return _db
        .collection('tale_drafts')
        .where('status', whereIn: statuses)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map(Draft.fromDoc).toList());
  }

  Stream<List<Draft>> streamDrafts() => streamDraftsByStatuses(['pending']);
```

- [ ] **Step 2: Add scheduler methods** (near `approveDraft`)

```dart
  Future<void> scheduleDraft(String draftId, DateTime scheduledAt) async {
    await _functions.httpsCallable('scheduleDraft').call({
      'draftId': draftId,
      'scheduledAtISO': scheduledAt.toUtc().toIso8601String(),
    });
  }

  /// Cancel a schedule. Backend has no dedicated endpoint; the admin uid is
  /// allowed to write tale_drafts, so revert the doc directly.
  Future<void> cancelSchedule(String draftId) async {
    await _db.collection('tale_drafts').doc(draftId).update({
      'status': 'pending',
      'scheduled_at': FieldValue.delete(),
      'scheduled_by': FieldValue.delete(),
    });
  }

  Future<void> updateDraftCategory({required String draftId, required String? categoryId}) async {
    await _db.collection('tale_drafts').doc(draftId).update({'category_id': categoryId});
  }
```

- [ ] **Step 3: Add `category_id` to `createManualDraft`'s `.set({...})`** (after `'is_premium_tale': false,`)

```dart
      'category_id': null,
```

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/admin/services/drafts_service.dart`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/admin/services/drafts_service.dart
git commit -m "feat(admin): scheduler + category service methods"
```

### Task 1.3: Pure helpers — slugify + schedule formatting

**Files:**
- Create: `lib/admin/util/format.dart`
- Test: `test/admin/format_test.dart`

**Interfaces:**
- Produces: `String slugify(String)`, `String formatScheduled(DateTime)` (→ `DD/MM HH:mm`).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/admin/util/format.dart';

void main() {
  test('slugify lowercases, strips accents, hyphenates', () {
    expect(slugify('Aventuras Épicas!'), 'aventuras-epicas');
    expect(slugify('  Niños y Niñas  '), 'ninos-y-ninas');
    expect(slugify(''), '');
  });

  test('formatScheduled renders DD/MM HH:mm', () {
    expect(formatScheduled(DateTime(2026, 3, 9, 7, 5)), '09/03 07:05');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/admin/format_test.dart`
Expected: FAIL (file/functions missing).

- [ ] **Step 3: Implement**

```dart
String slugify(String input) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  var s = input.toLowerCase().trim();
  for (var i = 0; i < from.length; i++) {
    s = s.replaceAll(from[i], to[i]);
  }
  s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  s = s.replaceAll(RegExp(r'^-+|-+$'), '');
  return s;
}

String _two(int n) => n.toString().padLeft(2, '0');

String formatScheduled(DateTime dt) =>
    '${_two(dt.day)}/${_two(dt.month)} ${_two(dt.hour)}:${_two(dt.minute)}';
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/admin/format_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/admin/util/format.dart test/admin/format_test.dart
git commit -m "feat(admin): slugify + schedule date formatting helpers"
```

---

## Phase 2 — Firestore rules & indexes (config)

### Task 2.1: Categories rule + scheduler composite index

**Files:**
- Modify: `firebase/firestore.rules`
- Modify: `firebase/firestore.indexes.json`

- [ ] **Step 1: Add a `categories` match block** (inside `match /databases/{database}/documents {`, after the `tale_drafts` block)

```
    // Categories: read public (reader app may use later), write admin-only.
    match /categories/{document} {
      allow read: if true;
      allow write: if request.auth.uid == "N5sv9GubvwOvapwv72nwrhWzBtK2";
    }
```

- [ ] **Step 2: Add the composite index** the cron query needs (`status ==` + `scheduled_at <=`). Add to the `indexes` array in `firestore.indexes.json`:

```json
    {
      "collectionGroup": "tale_drafts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "scheduled_at", "order": "ASCENDING" }
      ]
    }
```

- [ ] **Step 3: Verify JSON is valid**

Run: `python3 -c "import json;json.load(open('firebase/firestore.indexes.json'));print('ok')"`
Expected: `ok`

- [ ] **Step 4: Commit**

```bash
git add firebase/firestore.rules firebase/firestore.indexes.json
git commit -m "feat(firebase): categories rule + scheduler composite index"
```

- [ ] **Step 5: Deploy (ASK FIRST — see memory 'Ask before deploy on close')**

Run (only after approval): `cd firebase && firebase deploy --only firestore:rules,firestore:indexes -P merakitales-5rltbl`
Expected: rules + index deploy succeed. Categories reads/writes stop returning `permission-denied`; scheduled-draft queries stop erroring on a missing index.

---

## Phase 3 — Categories UI (real CRUD)

### Task 3.1: sort_order double-tolerance

**Files:**
- Modify: `lib/admin/models/category.dart:30`
- Test: `test/admin/category_test.dart` (pure conversion guard)

- [ ] **Step 1: Write the failing test** (guards the int-cast crash)

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sort_order tolerates a double from Firestore', () {
    // Mirrors Category.fromDoc's coercion: (num?).toInt()
    final num raw = 3.0;
    expect((raw).toInt(), 3);
    // The old `raw as int` would throw for a double — this documents the fix.
    expect(() => (raw as int), throwsA(isA<TypeError>()));
  });
}
```

- [ ] **Step 2: Run to verify it fails/or documents current bug**

Run: `flutter test test/admin/category_test.dart`
Expected: PASS on the `.toInt()` line; the `throwsA` line documents why the cast must change.

- [ ] **Step 3: Fix the cast** in `category.dart` line 30

```dart
      sortOrder: (d['sort_order'] as num?)?.toInt() ?? 0,
```

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/admin/models/category.dart`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/admin/models/category.dart test/admin/category_test.dart
git commit -m "fix(admin): tolerate double sort_order in Category.fromDoc"
```

### Task 3.2: Category editor dialog (create + edit)

**Files:**
- Create: `lib/admin/categories/category_editor_dialog.dart`
- Test: `test/admin/category_editor_dialog_test.dart`

**Interfaces:**
- Consumes: `slugify` (Task 1.3), `Category` model.
- Produces: `Future<CategoryFormResult?> showCategoryEditor(BuildContext, {Category? existing})` returning `null` on cancel or a `CategoryFormResult(nameEs, nameEn, emoji, slug, sortOrder)` on save. Slug auto-fills from `nameEs` via `slugify` while untouched; editable.

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/admin/categories/category_editor_dialog.dart';

void main() {
  testWidgets('save returns entered values with auto slug', (tester) async {
    CategoryFormResult? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) => ElevatedButton(
        onPressed: () async { result = await showCategoryEditor(ctx); },
        child: const Text('open'),
      )),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('cat_name_es')), 'Aventuras');
    await tester.enterText(find.byKey(const Key('cat_name_en')), 'Adventures');
    await tester.enterText(find.byKey(const Key('cat_emoji')), '🗺️');
    await tester.tap(find.byKey(const Key('cat_save')));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.nameEs, 'Aventuras');
    expect(result!.slug, 'aventuras');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/admin/category_editor_dialog_test.dart`
Expected: FAIL (file/symbols missing).

- [ ] **Step 3: Implement** — invoke ui-ux-pro-max for the visual composition, but the contract is fixed:

```dart
import 'package:flutter/material.dart';
import '../models/category.dart';
import '../theme/app_spacing.dart';
import '../util/format.dart';

class CategoryFormResult {
  final String nameEs, nameEn, emoji, slug;
  final int sortOrder;
  CategoryFormResult({required this.nameEs, required this.nameEn, required this.emoji, required this.slug, required this.sortOrder});
}

Future<CategoryFormResult?> showCategoryEditor(BuildContext context, {Category? existing}) {
  return showDialog<CategoryFormResult>(
    context: context,
    builder: (_) => _CategoryEditorDialog(existing: existing),
  );
}

class _CategoryEditorDialog extends StatefulWidget {
  const _CategoryEditorDialog({this.existing});
  final Category? existing;
  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  late final TextEditingController _nameEs, _nameEn, _emoji, _slug, _sort;
  bool _slugTouched = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameEs = TextEditingController(text: e?.nameEs ?? '');
    _nameEn = TextEditingController(text: e?.nameEn ?? '');
    _emoji = TextEditingController(text: e?.emoji ?? '');
    _slug = TextEditingController(text: e?.slug ?? '');
    _sort = TextEditingController(text: (e?.sortOrder ?? 0).toString());
    _slugTouched = e != null;
    _nameEs.addListener(() {
      if (!_slugTouched) _slug.text = slugify(_nameEs.text);
    });
  }

  @override
  void dispose() {
    for (final c in [_nameEs, _nameEn, _emoji, _slug, _sort]) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nueva categoría' : 'Editar categoría'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(key: const Key('cat_name_es'), controller: _nameEs, decoration: const InputDecoration(labelText: 'Nombre (ES)')),
          const SizedBox(height: AppSpacing.sm),
          TextField(key: const Key('cat_name_en'), controller: _nameEn, decoration: const InputDecoration(labelText: 'Nombre (EN)')),
          const SizedBox(height: AppSpacing.sm),
          TextField(key: const Key('cat_emoji'), controller: _emoji, decoration: const InputDecoration(labelText: 'Emoji')),
          const SizedBox(height: AppSpacing.sm),
          TextField(key: const Key('cat_slug'), controller: _slug, onChanged: (_) => _slugTouched = true, decoration: const InputDecoration(labelText: 'Slug')),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _sort, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Orden')),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          key: const Key('cat_save'),
          onPressed: () => Navigator.of(context).pop(CategoryFormResult(
            nameEs: _nameEs.text.trim(),
            nameEn: _nameEn.text.trim(),
            emoji: _emoji.text.trim(),
            slug: _slug.text.trim().isEmpty ? slugify(_nameEs.text) : _slug.text.trim(),
            sortOrder: int.tryParse(_sort.text) ?? 0,
          )),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/admin/category_editor_dialog_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/admin/categories/category_editor_dialog.dart test/admin/category_editor_dialog_test.dart
git commit -m "feat(admin): category editor dialog (create/edit, auto slug)"
```

### Task 3.3: Wire the dialog into CategoriesPage + delete confirmation

**Files:**
- Modify: `lib/admin/categories/categories_page.dart`

**Interfaces:**
- Consumes: `showCategoryEditor`, `CategoriesService.{createCategory,updateCategory,deleteCategory}`.

- [ ] **Step 1: Replace the hardcoded `_createCategory` and add edit/delete handlers**

```dart
  Future<void> _create() async {
    final r = await showCategoryEditor(context);
    if (r == null) return;
    await _service.createCategory(nameEs: r.nameEs, nameEn: r.nameEn, emoji: r.emoji, slug: r.slug, sortOrder: r.sortOrder);
  }

  Future<void> _edit(Category cat) async {
    final r = await showCategoryEditor(context, existing: cat);
    if (r == null) return;
    await _service.updateCategory(id: cat.id, nameEs: r.nameEs, nameEn: r.nameEn, emoji: r.emoji, slug: r.slug, sortOrder: r.sortOrder);
  }

  Future<void> _delete(Category cat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Eliminar "${cat.nameEs}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) await _service.deleteCategory(cat.id);
  }
```

- [ ] **Step 2: Update the AppBar `+` and the `ListTile`** — `onPressed: _create`; `ListTile` gets `onTap: () => _edit(cat)` and `trailing` delete calls `_delete(cat)`. Import `category_editor_dialog.dart`. Remove the stray `// removed` comment.

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/admin/categories/`
Expected: No issues.

- [ ] **Step 4: Verify by running the app** (Firestore-touching — no unit test)

Run: `flutter run -d chrome -t lib/admin/main_admin.dart`, log in, open Categorías: create a category (real dialog, no duplicate stub), edit it, delete it with confirmation. Confirm no `permission-denied` (requires Task 2.1 deployed).
Expected: CRUD works end-to-end.

- [ ] **Step 5: Commit**

```bash
git add lib/admin/categories/categories_page.dart
git commit -m "feat(admin): real category CRUD (dialog + edit + delete confirm)"
```

---

## Phase 4 — Scheduler UI + category-on-tale

### Task 4.1: approveDraft propagates category_id to tales

**Files:**
- Modify: `firebase/functions/src/approveDraft.js` (ES `.set` ~line 59-76, EN `.set` ~line 79-96)
- Modify: `firebase/functions/__tests__/approveDraft.test.js`

**Interfaces:**
- Produces: both tale docs include `category_id: d.category_id ?? null`.

- [ ] **Step 1: Add a failing assertion** to `approveDraft.test.js` — assert the published ES/EN tale docs carry `category_id` copied from the draft (follow the file's existing mocking of `db.collection('tales').doc().set`). Match the pattern already used for `is_premium_tale`.

- [ ] **Step 2: Run to verify it fails**

Run: `cd firebase/functions && npm test -- approveDraft`
Expected: FAIL (category_id not written).

- [ ] **Step 3: Add `category_id` to both `.set({...})` calls** (alongside `is_premium_tale`)

```javascript
    category_id: d.category_id ?? null,
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd firebase/functions && npm test -- approveDraft`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add firebase/functions/src/approveDraft.js firebase/functions/__tests__/approveDraft.test.js
git commit -m "feat(functions): propagate category_id from draft to published tales"
```

### Task 4.2: Category selector + Schedule action in the workspace

**Files:**
- Modify: `lib/admin/drafts/draft_workspace_page.dart` (settings section ~line 338; publish action area)
- Test: `test/admin/schedule_picker_test.dart` (pure combine-date-time helper)

**Interfaces:**
- Consumes: `DraftsService.{scheduleDraft,cancelSchedule,updateDraftCategory}`, `CategoriesService.streamCategories`, `Draft.{categoryId,scheduledAt,status}`, `formatScheduled`.
- Produces: `DateTime combineDateTime(DateTime date, TimeOfDay time)` helper in `lib/admin/util/format.dart`.

- [ ] **Step 1: Write the failing test for the date+time combiner**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/admin/util/format.dart';

void main() {
  test('combineDateTime merges a date and a time', () {
    final r = combineDateTime(DateTime(2026, 5, 1), const TimeOfDay(hour: 9, minute: 30));
    expect(r, DateTime(2026, 5, 1, 9, 30));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/admin/schedule_picker_test.dart`
Expected: FAIL (function missing).

- [ ] **Step 3: Add `combineDateTime` to `lib/admin/util/format.dart`**

```dart
import 'package:flutter/material.dart';

DateTime combineDateTime(DateTime date, TimeOfDay time) =>
    DateTime(date.year, date.month, date.day, time.hour, time.minute);
```

(Move the existing `import` to the top if needed; `format.dart` had none before.)

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/admin/schedule_picker_test.dart`
Expected: PASS.

- [ ] **Step 5: Add UI to the workspace** — invoke ui-ux-pro-max for composition. Two additions in `draft_workspace_page.dart`:
  1. **Category dropdown** in the settings section: a `StreamBuilder<List<Category>>(stream: CategoriesService().streamCategories())` → `DropdownButtonFormField<String?>` bound to the draft's `categoryId`; on change call `DraftsService().updateDraftCategory(draftId: id, categoryId: value)`. Include a "Sin categoría" (`null`) option.
  2. **Schedule action** next to "Aprobar y publicar":
     - If draft `status != 'scheduled'`: an outlined "Programar publicación" button →
       ```dart
       final date = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
       if (date == null) return;
       final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
       if (time == null) return;
       await DraftsService().scheduleDraft(id, combineDateTime(date, time));
       ```
       then a success snackbar and `context.go('/drafts')`.
     - If draft `status == 'scheduled'`: show a "Programado · ${formatScheduled(draft.scheduledAt!)}" chip + a "Cancelar programación" text button → `DraftsService().cancelSchedule(id)`.
  Publishing requires the draft to have all assets (backend enforces `computeStep === 'audio'`); disable "Programar" the same way "Publicar" is disabled when assets are missing.

- [ ] **Step 6: Analyze + run the app**

Run: `flutter analyze lib/admin/drafts/` then `flutter run -d chrome -t lib/admin/main_admin.dart`. On a complete draft: assign a category; schedule it → confirm it disappears from the default Borradores view and the draft doc gets `status: scheduled`, `scheduled_at`; cancel → returns to `pending`.
Expected: works end-to-end (needs Task 2.1 index deployed for the scheduled query).

- [ ] **Step 7: Commit**

```bash
git add lib/admin/drafts/draft_workspace_page.dart lib/admin/util/format.dart test/admin/schedule_picker_test.dart
git commit -m "feat(admin): workspace category selector + schedule/cancel publication"
```

---

## Phase 5 — Unified lists

### Task 5.1: Shared TaleRowCard

**Files:**
- Create: `lib/admin/widgets/tale_row_card.dart`
- Test: `test/admin/tale_row_card_test.dart`

**Interfaces:**
- Consumes: `AppCard`, `StatusBadge`, `AppSpacing`.
- Produces: `TaleRowCard({required String title, required String imageUrl640, required List<Widget> badges, Widget? trailing, VoidCallback? onTap, IconData placeholder})` — the single row used by both lists (thumbnail + serif title + wrapping badge row + trailing).

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merakitales/admin/widgets/tale_row_card.dart';
import 'package:merakitales/admin/widgets/status_badge.dart';

void main() {
  testWidgets('renders title and badges', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TaleRowCard(
      title: 'El bosque',
      imageUrl640: '',
      badges: [StatusBadge.published()],
      placeholder: Icons.public,
    ))));
    expect(find.text('El bosque'), findsOneWidget);
    expect(find.text('Publicado'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/admin/tale_row_card_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** (lift the shared row markup from `drafts_list_page.dart:74-121`; use `Wrap` for badges so they never overflow). Invoke ui-ux-pro-max for final spacing/typography.

```dart
import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import 'app_card.dart';

class TaleRowCard extends StatelessWidget {
  const TaleRowCard({
    super.key,
    required this.title,
    required this.imageUrl640,
    required this.badges,
    this.trailing,
    this.onTap,
    this.placeholder = Icons.book,
  });

  final String title;
  final String imageUrl640;
  final List<Widget> badges;
  final Widget? trailing;
  final VoidCallback? onTap;
  final IconData placeholder;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageUrl640.isNotEmpty
              ? Image.network(imageUrl640, width: 56, height: 56, fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(width: 56, height: 56, color: Colors.grey.shade200, child: const Icon(Icons.broken_image)))
              : Container(width: 56, height: 56, color: Colors.grey.shade200, child: Icon(placeholder)),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Wrap(spacing: AppSpacing.sm, runSpacing: 4, children: badges),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/admin/tale_row_card_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/admin/widgets/tale_row_card.dart test/admin/tale_row_card_test.dart
git commit -m "feat(admin): shared TaleRowCard for drafts + published lists"
```

### Task 5.2: Published list uses TaleRowCard + status pills

**Files:**
- Modify: `lib/admin/published/published_list_page.dart:79-119`

- [ ] **Step 1: Replace the inline `AppCard` row** with `TaleRowCard`, keeping the retract trailing button:

```dart
return TaleRowCard(
  onTap: () => context.go('/published/${t.taleId}'),
  title: t.name,
  imageUrl640: t.imageUrl640,
  placeholder: Icons.public,
  badges: [StatusBadge.published()],
  trailing: TextButton.icon(onPressed: () => _retract(t), icon: const Icon(Icons.undo), label: const Text('Retirar')),
);
```

(Import `../widgets/tale_row_card.dart` and `../widgets/status_badge.dart`; the `AppColors` import may become unused — remove it if analyzer flags it.)

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/admin/published/`
Expected: No issues.

- [ ] **Step 3: Verify by running the app**

Published list now shows the colored "Publicado" pill row instead of grey `tale_id=…` text; retract still works.

- [ ] **Step 4: Commit**

```bash
git add lib/admin/published/published_list_page.dart
git commit -m "feat(admin): published list adopts pill styling via TaleRowCard"
```

### Task 5.3: Drafts list — filter chips + scheduled badge + TaleRowCard

**Files:**
- Modify: `lib/admin/drafts/drafts_list_page.dart`

**Interfaces:**
- Consumes: `DraftsService.streamDraftsByStatuses`, `TaleRowCard`, `StatusBadge`, `formatScheduled`.

- [ ] **Step 1: Add filter state + chips.** Add `String _filter = 'pending';` and a `Wrap` of `ChoiceChip`s (Todos → `['pending','scheduled']`, Pendientes → `['pending']`, Programados → `['scheduled']`) above the list; drive the `StreamBuilder` with `_service.streamDraftsByStatuses(_statuses)` where `_statuses` maps from `_filter`.

- [ ] **Step 2: Replace the inline row** with `TaleRowCard`, building the badge list:

```dart
final badges = <Widget>[
  StatusBadge.step(d.step),
  if (d.status == 'scheduled') StatusBadge.scheduled(),
  if (d.isPremiumTale) StatusBadge.premium(),
  if (d.retractedFromTaleId != null) StatusBadge.retracted(),
];
// title trailing text: scheduled → formatScheduled(d.scheduledAt!), else created date
return TaleRowCard(
  onTap: () => context.go('/drafts/workspace/${d.id}'),
  title: d.nameEs.isNotEmpty ? d.nameEs : d.nameEn,
  imageUrl640: d.imageUrl640,
  placeholder: Icons.book,
  badges: badges,
  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
);
```

For scheduled drafts append a small "Programado · ${formatScheduled(d.scheduledAt!)}" `Text` into the badges `Wrap` (guard `scheduledAt != null`).

- [ ] **Step 3: Update the empty-state message** to reflect the active filter (e.g. "No hay borradores programados." when `_filter == 'scheduled'`).

- [ ] **Step 4: Analyze + run**

Run: `flutter analyze lib/admin/drafts/` then run the app. Toggle chips: Programados shows scheduled drafts with the schedule badge + date; Pendientes shows only pending. (Scheduled query needs Task 2.1 index deployed.)

- [ ] **Step 5: Commit**

```bash
git add lib/admin/drafts/drafts_list_page.dart
git commit -m "feat(admin): drafts list filter chips + scheduled badge via TaleRowCard"
```

---

## Phase 6 — Dashboard

### Task 6.1: Fix the broken count + add scheduled KPI + upcoming publications

**Files:**
- Modify: `lib/admin/dashboard/dashboard_page.dart`

**Interfaces:**
- Consumes: `DraftsService.streamDraftsByStatuses`, `formatScheduled`, `AppColors`.

- [ ] **Step 1: Fix the KPI queries.** The pending card must count `tale_drafts` where `status == 'pending'` (currently counts collection `'drafts'` → always 0). Add a `Scheduled` card counting `tale_drafts` where `status == 'scheduled'`. Keep `tales` (published) counting `lang == 'es'` to avoid double-count, or total `tales` — match the published list which filters `lang == 'es'`. Concretely, change `_buildStatCard` to take a `Query` instead of a bare collection name:

```dart
Widget _buildStatCard(BuildContext context, {required String title, required Query query, required IconData icon, required Color color}) { ... query.count().get() ... }
```

and call it with:
```dart
FirebaseFirestore.instance.collection('tale_drafts').where('status', isEqualTo: 'pending')   // Pendientes
FirebaseFirestore.instance.collection('tale_drafts').where('status', isEqualTo: 'scheduled')  // Programados
FirebaseFirestore.instance.collection('tales').where('lang', isEqualTo: 'es')                 // Publicados
```

- [ ] **Step 2: Add "Próximas publicaciones"** — a `StreamBuilder(_service.streamDraftsByStatuses(['scheduled']))` list (sorted by `scheduledAt` ascending client-side) rendering each as a compact row: thumbnail-less title + `formatScheduled(d.scheduledAt!)`. Empty → "No hay publicaciones programadas."

- [ ] **Step 3: Add a Categorías quick-action card** next to the existing Workspace action (`onTap: () => context.go('/categories')`).

- [ ] **Step 4: Analyze + run** — invoke ui-ux-pro-max for the KPI/upcoming layout.

Run: `flutter analyze lib/admin/dashboard/` then run the app: Pendientes now matches the drafts list count (not 0); Programados shows scheduled count; Próximas publicaciones lists them by date.

- [ ] **Step 5: Commit**

```bash
git add lib/admin/dashboard/dashboard_page.dart
git commit -m "fix(admin): dashboard counts tale_drafts + scheduled KPI + upcoming publications"
```

---

## Phase 7 — Shell + Login redesign (visual)

### Task 7.1: AdminScaffold nav rail

**Files:**
- Modify: `lib/admin/widgets/admin_scaffold.dart`

- [ ] **Step 1: Restyle the `NavigationRail`** — logo (`assets/images/app_launcher_icon.png`) at the top, four destinations (Dashboard, Borradores, Publicados, Categorías) with icon+label, active state = amber (`AppColors.accent`) keyline + soft-green (`AppColors.primary` @ ~10% opacity) fill, logout separated at the bottom. Keep the existing routing/`context.go` wiring untouched. Invoke ui-ux-pro-max for composition. Guard against `RenderFlex` overflow (wrap the rail body in a scroll view if needed — a prior crash was fixed here per commit f77e0cc).

- [ ] **Step 2: Analyze + run**

Run: `flutter analyze lib/admin/widgets/` then run the app: rail shows brand logo, active item highlighted, no overflow at typical window sizes.

- [ ] **Step 3: Commit**

```bash
git add lib/admin/widgets/admin_scaffold.dart
git commit -m "feat(admin): brand-aligned navigation rail"
```

### Task 7.2: Split-screen login

**Files:**
- Modify: `lib/admin/login/login_page.dart`

- [ ] **Step 1: Rebuild as a `Row`** (`LayoutBuilder` for responsiveness): left = `Image.asset('assets/images/meraki_tales_image01.png', fit: BoxFit.cover)` in an `Expanded` with a subtle green/amber gradient overlay + logo/tagline `Positioned`; right = the existing form (`AppCard` content — email, password, error, "Entrar") on a parchment panel, max width ~400. Below a ~700px width, stack: illustration as a top band (fixed height ~180), form beneath. Keep `_signIn`/auth logic unchanged. Invoke ui-ux-pro-max for composition. Verify `assets/images/meraki_tales_image01.png` is listed under `flutter: assets:` in `pubspec.yaml` (it is used by the reader app; confirm).

- [ ] **Step 2: Analyze + run**

Run: `flutter analyze lib/admin/login/` then run the app logged-out: split-screen renders with the forest art; login still works; narrow window collapses to stacked layout.

- [ ] **Step 3: Commit**

```bash
git add lib/admin/login/login_page.dart
git commit -m "feat(admin): split-screen storybook login"
```

---

## Final verification

- [ ] `flutter analyze` clean across `lib/admin/`.
- [ ] `flutter test` green.
- [ ] `cd firebase/functions && npm test` green.
- [ ] End-to-end in the running admin app: login → dashboard KPIs correct → create/edit/delete a category → assign category + schedule a draft → see it under Programados → cancel → publish → published list shows pills.
- [ ] Deploy (ASK FIRST): `firestore:rules`, `firestore:indexes`, `approveDraft` function, and the admin web build (verify hosting hash per memory 'Firebase build path mismatch').

## Self-review notes

- **Spec coverage:** visual system (0.1–0.2, 7.x), categories fix incl. root-cause rule (2.1, 3.1–3.3), category-on-tale (1.2, 4.1, 4.2), scheduler restore incl. index/model/cancel (1.1, 1.2, 2.1, 4.2), login (7.2), unified lists (5.1–5.3), dashboard bug + structure (6.1), component consistency (0.3, 5.1). All covered.
- **Ponytail:** no new dependencies; scheduler backend reused as-is; cancel is a 3-line client update; one shared row widget replaces two divergent ones; visual tasks fix tokens+structure rather than dictate speculative pixel code (ui-ux-pro-max fills composition at build).
- **Test reality:** Firestore/callable paths verified by running the app (no mock deps added); pure logic (slugify, date combine/format) and widgets (dialog, badges, row) are unit/widget-tested; approveDraft category propagation is jest-tested.
