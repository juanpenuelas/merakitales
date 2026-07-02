# Rediseño visual de la zona de administración Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply a lightweight custom design system (color/typography/spacing tokens + 3 shared widgets) across all 7 pages of `lib/admin`, giving the internal admin tool a consistent, professional "neutral dashboard" look, without touching routing, business logic, or the consumer-facing app.

**Architecture:** A small `lib/admin/theme/` package (colors, spacing constants, `ThemeData` assembly) and a small `lib/admin/widgets/` package (`AppCard`, `EmptyState`, `StatusBadge`) are built first, then applied page by page. Pages that are mostly presentational (login, drafts list, draft detail, published list, published tale detail) get full-file rewrites for clarity; the two larger wizard pages (`draft_create_page.dart`, `draft_create_manual_page.dart`) get targeted edits since most of their code is business logic that doesn't change.

**Tech Stack:** Flutter Web (Dart), Material 3, `google_fonts` package (new dependency).

## Global Constraints

- Light mode only — no dark mode support in the color tokens.
- No routing changes, no new/removed fields, no changes to any business logic or Firestore/Storage calls — this is a widget-tree-only visual change.
- Do not touch `lib/backend` (the consumer-facing app) in any way.
- No emoji used as structural status icons after this change (📝🖼️🎵 in `drafts_list_page.dart`/`draft_detail_page.dart` are replaced by `StatusBadge`). Emoji used as decorative text inside a message (e.g. the "⚠️ ..." word-count warning) are not in scope to remove.
- Color tokens (exact values, from the spec): primary `#2563EB`, background `#F8FAFC`, surface `#FFFFFF`, text primary `#0F172A`, text secondary `#64748B`, border `#E2E8F0`, subtle fill `#F1F5F9`, success `#059669`, warning `#D97706`, destructive `#DC2626`.
- Spacing tokens (exact values): `xs=4, sm=8, md=16, lg=24, xl=32`.
- Corner radius: 8px for cards/buttons, 6px for image thumbnails.
- `AppCard` padding: `AppSpacing.md` (16px) on all 4 sides by default.
- This repo has no automated Flutter widget/unit tests for `lib/admin` — verification is via `flutter analyze` + `flutter build web` + manual visual check, per existing convention.

---

### Task 1: Add the `google_fonts` dependency

**Files:**
- Modify: `pubspec.yaml`

**Interfaces:**
- Produces: `package:google_fonts/google_fonts.dart` available for import in Task 2.

- [ ] **Step 1: Add the dependency**

Run from the repo root:
```bash
flutter pub add google_fonts
```

Expected: command exits 0, `pubspec.yaml` gains a `google_fonts: ^<version>` line under `dependencies`, `pubspec.lock` updated.

- [ ] **Step 2: Verify it resolves**

```bash
flutter pub get
```

Expected: `Got dependencies!` with no version conflicts.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add google_fonts for admin panel typography"
```

---

### Task 2: Design tokens and theme

**Files:**
- Create: `lib/admin/theme/app_colors.dart`
- Create: `lib/admin/theme/app_spacing.dart`
- Create: `lib/admin/theme/app_theme.dart`
- Modify: `lib/admin/app.dart`

**Interfaces:**
- Produces: `AppColors` (static color constants), `AppSpacing` (static double constants `xs/sm/md/lg/xl`), `AppTheme.light(): ThemeData` — all consumed by every later task in this plan.

- [ ] **Step 1: Create the color tokens**

Create `lib/admin/theme/app_colors.dart`:

```dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2563EB);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color subtleFill = Color(0xFFF1F5F9);
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color destructive = Color(0xFFDC2626);
}
```

- [ ] **Step 2: Create the spacing tokens**

Create `lib/admin/theme/app_spacing.dart`:

```dart
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}
```

- [ ] **Step 3: Create the theme assembly**

Create `lib/admin/theme/app_theme.dart`:

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
        surface: AppColors.surface,
        error: AppColors.destructive,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
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

- [ ] **Step 4: Wire the theme into `app.dart`**

In `lib/admin/app.dart`, add the import after the existing `firebase_auth` import:
```dart
import 'theme/app_theme.dart';
```

Then change:
```dart
          theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF1D2428)),
```
to:
```dart
          theme: AppTheme.light(),
```

- [ ] **Step 5: Verify it compiles**

```bash
flutter analyze lib/admin
```

Expected: only the 5 pre-existing unused-import warnings, 0 new issues, 0 errors.

- [ ] **Step 6: Commit**

```bash
git add lib/admin/theme lib/admin/app.dart
git commit -m "feat(admin): add design tokens and centralized theme"
```

---

### Task 3: Shared widgets — `AppCard`, `EmptyState`, `StatusBadge`

**Files:**
- Create: `lib/admin/widgets/app_card.dart`
- Create: `lib/admin/widgets/empty_state.dart`
- Create: `lib/admin/widgets/status_badge.dart`

**Interfaces:**
- Consumes: `AppColors`, `AppSpacing` (Task 2).
- Produces (all consumed by Tasks 4-10):
  - `AppCard({Key? key, required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(AppSpacing.md), VoidCallback? onTap})`.
  - `EmptyState({Key? key, required IconData icon, required String message, String? actionLabel, VoidCallback? onAction})`.
  - `StatusBadge({Key? key, required IconData icon, required String label, required Color color})` with factory constructors `StatusBadge.step(String step)`, `StatusBadge.retracted()`.

- [ ] **Step 1: Create `AppCard`**

Create `lib/admin/widgets/app_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create `EmptyState`**

Create `lib/admin/widgets/empty_state.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Create `StatusBadge`**

Create `lib/admin/widgets/status_badge.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  factory StatusBadge.step(String step) {
    switch (step) {
      case 'image':
        return const StatusBadge(icon: Icons.image_outlined, label: 'Imagen', color: AppColors.primary);
      case 'audio':
        return const StatusBadge(icon: Icons.graphic_eq, label: 'Audio', color: AppColors.success);
      case 'text':
      default:
        return const StatusBadge(icon: Icons.edit_note, label: 'Texto', color: AppColors.textSecondary);
    }
  }

  factory StatusBadge.retracted() =>
      const StatusBadge(icon: Icons.history, label: 'Retractado', color: AppColors.warning);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.subtleFill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Verify it compiles**

```bash
flutter analyze lib/admin/widgets
```

Expected: `No issues found!`.

- [ ] **Step 5: Commit**

```bash
git add lib/admin/widgets
git commit -m "feat(admin): add AppCard, EmptyState, StatusBadge shared widgets"
```

---

### Task 4: Apply the design system to `login_page.dart`

**Files:**
- Modify: `lib/admin/login/login_page.dart` (full rewrite)

**Interfaces:**
- Consumes: `AppColors`, `AppSpacing` (Task 2), `AppCard` (Task 3).

- [ ] **Step 1: Rewrite the file**

Write `lib/admin/login/login_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_card.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() { _error = e.message ?? 'Error'; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meraki Tales Admin')),
      body: Center(
        child: SizedBox(
          width: 360,
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _password,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  obscureText: true,
                  onSubmitted: (_) => _signIn(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(_error!, style: const TextStyle(color: AppColors.destructive)),
                ],
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: _loading ? null : _signIn,
                  child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator()) : const Text('Entrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/admin/login/login_page.dart
```

Expected: `No issues found!`.

- [ ] **Step 3: Commit**

```bash
git add lib/admin/login/login_page.dart
git commit -m "feat(admin): restyle login page with AppCard"
```

---

### Task 5: Apply the design system to `drafts_list_page.dart`

**Files:**
- Modify: `lib/admin/drafts/drafts_list_page.dart` (full rewrite)

**Interfaces:**
- Consumes: `AppSpacing` (Task 2), `AppCard`, `EmptyState`, `StatusBadge.step(String)`, `StatusBadge.retracted()` (Task 3).

- [ ] **Step 1: Rewrite the file**

Write `lib/admin/drafts/drafts_list_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/drafts_service.dart';
import '../models/draft.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_badge.dart';

class DraftsListPage extends StatefulWidget {
  const DraftsListPage({super.key});
  @override
  State<DraftsListPage> createState() => _DraftsListPageState();
}

class _DraftsListPageState extends State<DraftsListPage> {
  final _service = DraftsService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Borradores'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: () => context.go('/drafts/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo cuento'),
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => context.go('/drafts/manual'),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Crear a mano'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => context.go('/published'),
                  icon: const Icon(Icons.public),
                  label: const Text('Publicados'),
                ),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Draft>>(
        stream: _service.streamDrafts(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final drafts = snap.data ?? [];
          if (drafts.isEmpty) {
            return const EmptyState(
              icon: Icons.note_add_outlined,
              message: 'No hay borradores pendientes.\nPulsa "Nuevo cuento" para crear uno.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: drafts.length,
            separatorBuilder: (c, i) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (c, i) {
              final d = drafts[i];
              return AppCard(
                onTap: () => context.go('/drafts/${d.id}'),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: d.imageUrl640.isNotEmpty
                          ? Image.network(
                              d.imageUrl640,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(width: 56, height: 56, color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
                            )
                          : Container(width: 56, height: 56, color: Colors.grey.shade200, child: const Icon(Icons.book)),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.nameEs.isNotEmpty ? d.nameEs : d.nameEn, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              StatusBadge.step(d.step),
                              if (d.retractedFromTaleId != null) ...[
                                const SizedBox(width: AppSpacing.sm),
                                StatusBadge.retracted(),
                              ],
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                d.createdAt != null ? d.createdAt!.toLocal().toString() : '',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/admin/drafts/drafts_list_page.dart
```

Expected: `No issues found!`.

- [ ] **Step 3: Commit**

```bash
git add lib/admin/drafts/drafts_list_page.dart
git commit -m "feat(admin): restyle drafts list with AppCard/StatusBadge/EmptyState"
```

---

### Task 6: Apply the design system to `draft_detail_page.dart`

**Files:**
- Modify: `lib/admin/drafts/draft_detail_page.dart` (full rewrite)

**Interfaces:**
- Consumes: `AppColors`, `AppSpacing` (Task 2), `AppCard`, `StatusBadge.step(String)`, `StatusBadge.retracted()` (Task 3).

- [ ] **Step 1: Rewrite the file**

Write `lib/admin/drafts/draft_detail_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/drafts_service.dart';
import '../models/draft.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_card.dart';
import '../widgets/status_badge.dart';

class DraftDetailPage extends StatefulWidget {
  const DraftDetailPage({super.key, required this.draftId});
  final String draftId;
  @override
  State<DraftDetailPage> createState() => _DraftDetailPageState();
}

class _DraftDetailPageState extends State<DraftDetailPage> {
  final _service = DraftsService();
  bool _es = true;
  bool _busy = false;

  Future<void> _approve(String id) async {
    setState(() => _busy = true);
    try {
      final taleId = await _service.approveDraft(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Publicado como tale_id=$taleId')));
        context.go('/drafts');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(String id) async {
    setState(() => _busy = true);
    try {
      await _service.rejectDraft(id);
      if (mounted) context.go('/drafts');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Draft?>(
      stream: _service.streamDraft(widget.draftId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (!snap.hasData || snap.data == null) return const Scaffold(body: Center(child: Text('Borrador no encontrado')));
        final d = snap.data!;
        final name = _es ? d.nameEs : d.nameEn;
        final desc = _es ? d.descriptionEs : d.descriptionEn;
        final spec = _es ? d.specificationsEs : d.specificationsEn;
        final audio = _es ? d.audioUrlEs : d.audioUrlEn;
        return Scaffold(
          appBar: AppBar(
            title: Text(name),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(36),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    StatusBadge.step(d.step),
                    if (d.retractedFromTaleId != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      StatusBadge.retracted(),
                      const SizedBox(width: 4),
                      Text('de tale_id=${d.retractedFromTaleId}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              ToggleButtons(
                isSelected: [_es, !_es],
                onPressed: (i) => setState(() => _es = i == 0),
                children: const [Text('ES'), Text('EN')],
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
          body: _busy
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppCard(
                            padding: EdgeInsets.zero,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                d.imageUrl,
                                errorBuilder: (c, e, s) => Container(
                                  height: 200,
                                  color: Colors.grey.shade200,
                                  child: const Center(child: Icon(Icons.broken_image, size: 48)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Descripción', style: Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 4),
                                Text(desc),
                                const SizedBox(height: AppSpacing.md),
                                Text('Texto del cuento', style: Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 4),
                                Text(spec, style: const TextStyle(fontSize: 18, height: 1.5)),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Audio (${_es ? 'ES' : 'EN'})", style: Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 4),
                                if (audio.isNotEmpty)
                                  InkWell(
                                    onTap: () => launchUrl(Uri.parse(audio)),
                                    child: const Row(children: [Icon(Icons.play_circle, size: 32), SizedBox(width: 8), Text('Reproducir audio')]),
                                  )
                                else
                                  const Text('Sin audio'),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (d.step != 'audio')
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: Text(
                                'Este borrador aún no ha completado los 3 pasos (texto, imagen, audio ES/EN) y no se puede publicar todavía.',
                                style: TextStyle(color: AppColors.warning, fontSize: 12),
                              ),
                            ),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: () => _reject(d.id),
                                style: OutlinedButton.styleFrom(foregroundColor: AppColors.destructive),
                                child: const Text('Rechazar'),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              if (d.step == 'audio')
                                FilledButton.icon(
                                  onPressed: () => _approve(d.id),
                                  icon: const Icon(Icons.publish),
                                  label: const Text('Aprobar y publicar'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
```

Note: `_stepLabel` (the old method mapping step to a Spanish label with a green dot icon) is intentionally removed — `StatusBadge.step` replaces its role entirely.

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/admin/drafts/draft_detail_page.dart
```

Expected: `No issues found!`.

- [ ] **Step 3: Commit**

```bash
git add lib/admin/drafts/draft_detail_page.dart
git commit -m "feat(admin): restyle draft detail page with AppCard/StatusBadge"
```

---

### Task 7: Apply the design system to `draft_create_page.dart`

**Files:**
- Modify: `lib/admin/drafts/draft_create_page.dart`

**Interfaces:**
- Consumes: `AppColors`, `AppSpacing` (Task 2), `AppCard` (Task 3).

- [ ] **Step 1: Add imports**

Change:
```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/drafts_service.dart';
import '../models/draft.dart';
```
to:
```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/drafts_service.dart';
import '../models/draft.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_card.dart';
```

- [ ] **Step 2: Wrap Step 1 in an `AppCard`**

Change:
```dart
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Paso 1: Texto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Tema (opcional) y feedback para la IA (opcional).'),
          const SizedBox(height: 16),
          TextField(
            controller: _themeController,
            decoration: const InputDecoration(labelText: 'Tema', hintText: 'amistad, valentía, naturaleza…'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _feedback1Controller,
            decoration: const InputDecoration(labelText: 'Feedback (opcional)', hintText: 'hazlo más corto, el protagonista debe ser un oso…'),
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _generatingText ? null : _generateText,
            icon: _generatingText
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: const Text('Generar texto'),
          ),
        ],
      ),
    );
  }
```
to:
```dart
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paso 1: Texto', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            const Text('Tema (opcional) y feedback para la IA (opcional).'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _themeController,
              decoration: const InputDecoration(labelText: 'Tema', hintText: 'amistad, valentía, naturaleza…'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _feedback1Controller,
              decoration: const InputDecoration(labelText: 'Feedback (opcional)', hintText: 'hazlo más corto, el protagonista debe ser un oso…'),
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: _generatingText ? null : _generateText,
              icon: _generatingText
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: const Text('Generar texto'),
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 3: Wrap each later step in its own `AppCard`**

Change:
```dart
  Widget _buildLaterSteps() {
    final d = _draft!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text('Cuento: ${d.nameEs}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (d.retractedFromTaleId != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Retractado de tale_id=${d.retractedFromTaleId}', style: const TextStyle(color: Colors.orange)),
            ),
          const Divider(height: 32),

          // Step 1: Text (editable)
          const Text('Paso 1: Texto (editable)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _editableTextField(
            label: 'Cuento en español',
            initial: d.specificationsEs,
            onChanged: (v) => d.specificationsEs.length,
            onSaved: (newText) => _saveDraftText('es', newText),
          ),
          const SizedBox(height: 12),
          _editableTextField(
            label: 'Cuento en inglés',
            initial: d.specificationsEn,
            onChanged: (v) => v.length,
            onSaved: (newText) => _saveDraftText('en', newText),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _feedback1Controller,
            decoration: const InputDecoration(labelText: 'Feedback para regenerar', hintText: 'hazlo más largo, cambia el protagonista…'),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _generatingText ? null : _regenerateText,
            icon: const Icon(Icons.refresh),
            label: const Text('Regenerar texto con feedback'),
          ),

          const Divider(height: 32),

          // Step 2: Image
          const Text('Paso 2: Imagen', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (d.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(d.imageUrl, fit: BoxFit.cover, height: 200, width: double.infinity),
            )
          else
            const Text('(sin imagen aún)'),
          const SizedBox(height: 8),
          TextField(
            controller: _feedback2Controller,
            decoration: const InputDecoration(labelText: 'Feedback para regenerar imagen', hintText: 'más brillante, sin fondo, personaje a la izquierda…'),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (d.imageUrl.isEmpty)
                FilledButton.icon(
                  onPressed: _generatingImage ? null : _approveTextAndGenerateImage,
                  icon: _generatingImage
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.image),
                  label: const Text('Aprobar texto y generar imagen'),
                )
              else
                OutlinedButton.icon(
                  onPressed: _generatingImage ? null : _regenerateImage,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Regenerar imagen'),
                ),
            ],
          ),

          const Divider(height: 32),

          // Step 3: Audio
          const Text('Paso 3: Audio', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _audioRow('es', d.audioUrlEs, _generatingAudioEs),
          const SizedBox(height: 8),
          _audioRow('en', d.audioUrlEn, _generatingAudioEn),
          const SizedBox(height: 16),
          if (d.audioUrlEs.isNotEmpty && d.audioUrlEn.isNotEmpty)
            FilledButton.icon(
              onPressed: _approveAndPublish,
              icon: const Icon(Icons.publish),
              label: const Text('Aprobar y publicar'),
            ),
        ],
      ),
    );
  }
```
to:
```dart
  Widget _buildLaterSteps() {
    final d = _draft!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text('Cuento: ${d.nameEs}', style: Theme.of(context).textTheme.titleMedium),
          if (d.retractedFromTaleId != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Retractado de tale_id=${d.retractedFromTaleId}', style: const TextStyle(color: AppColors.warning)),
            ),
          const SizedBox(height: AppSpacing.md),

          // Step 1: Text (editable)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Paso 1: Texto (editable)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.sm),
                _editableTextField(
                  label: 'Cuento en español',
                  initial: d.specificationsEs,
                  onChanged: (v) => d.specificationsEs.length,
                  onSaved: (newText) => _saveDraftText('es', newText),
                ),
                const SizedBox(height: AppSpacing.sm),
                _editableTextField(
                  label: 'Cuento en inglés',
                  initial: d.specificationsEn,
                  onChanged: (v) => v.length,
                  onSaved: (newText) => _saveDraftText('en', newText),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _feedback1Controller,
                  decoration: const InputDecoration(labelText: 'Feedback para regenerar', hintText: 'hazlo más largo, cambia el protagonista…'),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _generatingText ? null : _regenerateText,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Regenerar texto con feedback'),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Step 2: Image
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Paso 2: Imagen', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.sm),
                if (d.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(d.imageUrl, fit: BoxFit.cover, height: 200, width: double.infinity),
                  )
                else
                  const Text('(sin imagen aún)'),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _feedback2Controller,
                  decoration: const InputDecoration(labelText: 'Feedback para regenerar imagen', hintText: 'más brillante, sin fondo, personaje a la izquierda…'),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    if (d.imageUrl.isEmpty)
                      FilledButton.icon(
                        onPressed: _generatingImage ? null : _approveTextAndGenerateImage,
                        icon: _generatingImage
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.image),
                        label: const Text('Aprobar texto y generar imagen'),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _generatingImage ? null : _regenerateImage,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Regenerar imagen'),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Step 3: Audio
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Paso 3: Audio', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.sm),
                _audioRow('es', d.audioUrlEs, _generatingAudioEs),
                const SizedBox(height: AppSpacing.sm),
                _audioRow('en', d.audioUrlEn, _generatingAudioEn),
                if (d.audioUrlEs.isNotEmpty && d.audioUrlEn.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: _approveAndPublish,
                    icon: const Icon(Icons.publish),
                    label: const Text('Aprobar y publicar'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 4: Update the word-count-warning colors**

Change:
```dart
          Text('${_wordCount(controller.text)} palabras', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (_wordCount(controller.text) < 200 || _wordCount(controller.text) > 600)
            const Text('⚠️ Los cuentos existentes tienen 300-500 palabras', style: TextStyle(fontSize: 12, color: Colors.orange)),
```
to:
```dart
          Text('${_wordCount(controller.text)} palabras', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (_wordCount(controller.text) < 200 || _wordCount(controller.text) > 600)
            const Text('⚠️ Los cuentos existentes tienen 300-500 palabras', style: TextStyle(fontSize: 12, color: AppColors.warning)),
```

- [ ] **Step 5: Verify it compiles**

```bash
flutter analyze lib/admin/drafts/draft_create_page.dart
```

Expected: `No issues found!`.

- [ ] **Step 6: Commit**

```bash
git add lib/admin/drafts/draft_create_page.dart
git commit -m "feat(admin): restyle AI wizard with AppCard per step"
```

---

### Task 8: Apply the design system to `draft_create_manual_page.dart`

**Files:**
- Modify: `lib/admin/drafts/draft_create_manual_page.dart`

**Interfaces:**
- Consumes: `AppColors`, `AppSpacing` (Task 2), `AppCard` (Task 3).

- [ ] **Step 1: Add imports**

Change:
```dart
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/draft.dart';
import '../services/drafts_service.dart';
```
to:
```dart
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/draft.dart';
import '../services/drafts_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_card.dart';
```

- [ ] **Step 2: Wrap each section of `build()` in its own `AppCard`**

Change:
```dart
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Texto — Español', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _textField(label: 'Nombre', controller: _nameEsController),
            _textField(label: 'Descripción', controller: _descriptionEsController, maxLines: 2),
            _textField(label: 'Cuento', controller: _specificationsEsController, maxLines: 10, showWordCount: true),
            const Divider(height: 32),
            const Text('Texto — English', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _textField(label: 'Nombre', controller: _nameEnController),
            _textField(label: 'Descripción', controller: _descriptionEnController, maxLines: 2),
            _textField(label: 'Cuento', controller: _specificationsEnController, maxLines: 10, showWordCount: true),
            const Divider(height: 32),
            const Text('Imagen', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _imageSection(),
            const Divider(height: 32),
            const Text('Audio', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _audioSection('es'),
            _audioSection('en'),
            if (_draft?.step == 'audio')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/drafts/${_draftId!}'),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Ver borrador completo →'),
                ),
              ),
          ],
        ),
      ),
```
to:
```dart
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Texto — Español', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.sm),
                  _textField(label: 'Nombre', controller: _nameEsController),
                  _textField(label: 'Descripción', controller: _descriptionEsController, maxLines: 2),
                  _textField(label: 'Cuento', controller: _specificationsEsController, maxLines: 10, showWordCount: true),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Texto — English', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.sm),
                  _textField(label: 'Nombre', controller: _nameEnController),
                  _textField(label: 'Descripción', controller: _descriptionEnController, maxLines: 2),
                  _textField(label: 'Cuento', controller: _specificationsEnController, maxLines: 10, showWordCount: true),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Imagen', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.sm),
                  _imageSection(),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Audio', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.sm),
                  _audioSection('es'),
                  _audioSection('en'),
                  if (_draft?.step == 'audio')
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: OutlinedButton.icon(
                        onPressed: () => context.go('/drafts/${_draftId!}'),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Ver borrador completo →'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
```

- [ ] **Step 3: Update the word-count-warning colors**

Change:
```dart
            Text('${_wordCount(controller.text)} palabras', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (_wordCount(controller.text) > 0 &&
                (_wordCount(controller.text) < 200 || _wordCount(controller.text) > 600))
              const Text('⚠️ Los cuentos existentes tienen 300-500 palabras', style: TextStyle(fontSize: 12, color: Colors.orange)),
```
to:
```dart
            Text('${_wordCount(controller.text)} palabras', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            if (_wordCount(controller.text) > 0 &&
                (_wordCount(controller.text) < 200 || _wordCount(controller.text) > 600))
              const Text('⚠️ Los cuentos existentes tienen 300-500 palabras', style: TextStyle(fontSize: 12, color: AppColors.warning)),
```

- [ ] **Step 4: Verify it compiles**

```bash
flutter analyze lib/admin/drafts/draft_create_manual_page.dart
```

Expected: `No issues found!`.

- [ ] **Step 5: Commit**

```bash
git add lib/admin/drafts/draft_create_manual_page.dart
git commit -m "feat(admin): restyle manual draft creation with AppCard per section"
```

---

### Task 9: Apply the design system to `published_list_page.dart`

**Files:**
- Modify: `lib/admin/published/published_list_page.dart` (full rewrite)

**Interfaces:**
- Consumes: `AppColors`, `AppSpacing` (Task 2), `AppCard`, `EmptyState` (Task 3).

- [ ] **Step 1: Rewrite the file**

Write `lib/admin/published/published_list_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/drafts_service.dart';
import '../models/published_tale.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';

class PublishedListPage extends StatefulWidget {
  const PublishedListPage({super.key});
  @override
  State<PublishedListPage> createState() => _PublishedListPageState();
}

class _PublishedListPageState extends State<PublishedListPage> {
  final _service = DraftsService();
  bool _retracting = false;

  Future<void> _retract(PublishedTale tale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirar cuento'),
        content: Text('¿Seguro que quieres retirar "${tale.name}"? Volverá a borradores para que puedas editarlo y republicarlo.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Retirar')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _retracting = true);
    try {
      final draftId = await _service.retractTale(tale.taleId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Retractado como draft $draftId')));
      context.go('/drafts');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _retracting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Publicados'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/drafts'),
        ),
      ),
      body: _retracting
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<PublishedTale>>(
              stream: _service.streamPublished(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final tales = snap.data ?? [];
                if (tales.isEmpty) {
                  return const EmptyState(
                    icon: Icons.public_off,
                    message: 'No hay cuentos publicados.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: tales.length,
                  separatorBuilder: (c, i) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (c, i) {
                    final t = tales[i];
                    return AppCard(
                      onTap: () => context.go('/published/${t.taleId}'),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: t.imageUrl640.isNotEmpty
                                ? Image.network(
                                    t.imageUrl640,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => Container(width: 56, height: 56, color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
                                  )
                                : Container(width: 56, height: 56, color: Colors.grey.shade200, child: const Icon(Icons.public)),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.name, style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text(
                                  'tale_id=${t.taleId} · ${t.createdAt != null ? t.createdAt!.toLocal() : ''}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _retract(t),
                            icon: const Icon(Icons.undo),
                            label: const Text('Retirar'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/admin/published/published_list_page.dart
```

Expected: `No issues found!`.

- [ ] **Step 3: Commit**

```bash
git add lib/admin/published/published_list_page.dart
git commit -m "feat(admin): restyle published list with AppCard/EmptyState"
```

---

### Task 10: Apply the design system to `published_tale_detail_page.dart`

**Files:**
- Modify: `lib/admin/published/published_tale_detail_page.dart` (full rewrite)

**Interfaces:**
- Consumes: `AppColors`, `AppSpacing` (Task 2), `AppCard` (Task 3).

- [ ] **Step 1: Rewrite the file**

Write `lib/admin/published/published_tale_detail_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/drafts_service.dart';
import '../models/published_tale.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_card.dart';

class PublishedTaleDetailPage extends StatefulWidget {
  const PublishedTaleDetailPage({super.key, required this.taleId});
  final int taleId;
  @override
  State<PublishedTaleDetailPage> createState() => _PublishedTaleDetailPageState();
}

class _PublishedTaleDetailPageState extends State<PublishedTaleDetailPage> {
  final _service = DraftsService();
  bool _es = true;
  bool _retracting = false;
  late Future<PublishedTaleFull> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getPublishedTale(widget.taleId);
  }

  Future<void> _retract() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirar cuento'),
        content: const Text('¿Seguro que quieres retirarlo? Volverá a borradores para que puedas editarlo y republicarlo.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Retirar')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _retracting = true);
    try {
      final draftId = await _service.retractTale(widget.taleId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Retractado como draft $draftId')));
      context.go('/drafts');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _retracting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PublishedTaleFull>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError || !snap.hasData) {
          return Scaffold(
            appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/published'))),
            body: Center(child: Text('Error: ${snap.error ?? "cuento no encontrado"}')),
          );
        }
        final t = snap.data!;
        final name = _es ? t.nameEs : t.nameEn;
        final desc = _es ? t.descriptionEs : t.descriptionEn;
        final spec = _es ? t.specificationsEs : t.specificationsEn;
        final audio = _es ? t.audioUrlEs : t.audioUrlEn;
        return Scaffold(
          appBar: AppBar(
            title: Text(name.isNotEmpty ? name : 'tale_id=${t.taleId}'),
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/published')),
            actions: [
              ToggleButtons(
                isSelected: [_es, !_es],
                onPressed: (i) => setState(() => _es = i == 0),
                children: const [Text('ES'), Text('EN')],
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
          body: _retracting
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (t.imageUrl.isNotEmpty)
                            AppCard(
                              padding: EdgeInsets.zero,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  t.imageUrl,
                                  errorBuilder: (c, e, s) => Container(
                                    height: 200,
                                    color: Colors.grey.shade200,
                                    child: const Center(child: Icon(Icons.broken_image, size: 48)),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: AppSpacing.md),
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('tale_id=${t.taleId}', style: const TextStyle(color: AppColors.textSecondary)),
                                const SizedBox(height: AppSpacing.sm),
                                Text('Descripción', style: Theme.of(context).textTheme.titleSmall),
                                Text(desc),
                                const SizedBox(height: AppSpacing.md),
                                Text('Texto del cuento', style: Theme.of(context).textTheme.titleSmall),
                                Text(spec, style: const TextStyle(fontSize: 18, height: 1.5)),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Audio (${_es ? 'ES' : 'EN'})", style: Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: AppSpacing.sm),
                                if (audio.isNotEmpty)
                                  InkWell(
                                    onTap: () => launchUrl(Uri.parse(audio)),
                                    child: const Row(children: [Icon(Icons.play_circle, size: 32), SizedBox(width: 8), Text('Reproducir audio')]),
                                  )
                                else
                                  const Text('Sin audio'),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          OutlinedButton.icon(
                            onPressed: _retract,
                            icon: const Icon(Icons.undo),
                            label: const Text('Retirar de la app'),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/admin/published/published_tale_detail_page.dart
```

Expected: `No issues found!`.

- [ ] **Step 3: Commit**

```bash
git add lib/admin/published/published_tale_detail_page.dart
git commit -m "feat(admin): restyle published tale detail with AppCard"
```

---

### Task 11: End-to-end verification

**Files:** none (verification only).

**Interfaces:** none.

- [ ] **Step 1: Run `flutter analyze` on the whole admin app**

```bash
flutter analyze lib/admin
```

Expected: only the 5 pre-existing unused-import warnings, 0 errors.

- [ ] **Step 2: Build the admin web app**

```bash
flutter build web -t lib/admin/main_admin.dart --release
```

Expected: `✓ Built build/web` with no compile errors.

- [ ] **Step 3: Deploy the admin web app (hosting only — no backend functions changed in this plan)**

**Production deploy — requires explicit user confirmation before running**, same pattern as prior plans on this project. Do not run this without the user confirming first in chat.

```bash
firebase deploy --only hosting -P merakitales-5rltbl
```

Expected: deploy succeeds, `Hosting URL: https://merakitales-5rltbl.web.app`.

- [ ] **Step 4: Manual visual check of all 7 pages**

At `https://merakitales-5rltbl.web.app`, verify each page renders with the new design system and no visual regressions:
1. `/login` — centered card, no more floating fields
2. `/drafts` — card rows with status badges (no emoji), empty state if no drafts
3. `/drafts/:id` — card sections for image/description/audio, status badges in the app bar
4. `/drafts/new` — each wizard step in its own card
5. `/drafts/manual` — each section (texto ES/EN, imagen, audio) in its own card
6. `/published` — card rows, empty state if no published tales
7. `/published/:taleId` — card sections matching the draft detail layout

If a connected browser tool is available when this task is executed, use it to capture each page instead of asking the user to do this manually. If not, this step is an explicit pending item — note it rather than skipping it silently.

- [ ] **Step 5: Commit (only if Step 4 surfaced fixes)**

If the visual check required any code fixes, commit them individually with descriptive messages. If no fixes were needed, this step is a no-op — the plan is done as of Task 10's commit.

---

## Self-Review Notes

- **Spec coverage:** every section of `docs/superpowers/specs/2026-07-02-admin-redesign-design.md` maps to a task — Tokens de diseño → Task 2; Componentes compartidos → Task 3; Aplicación por página → Tasks 4-10 (one task per page, exactly matching the spec's page list); Testing y verificación → Task 11.
- **Type consistency checked:** `AppCard`/`EmptyState`/`StatusBadge` constructor signatures defined in Task 3 are used identically in Tasks 4-10 (same parameter names: `child`, `padding`, `onTap`, `icon`, `message`, `actionLabel`, `onAction`). `StatusBadge.step(String)` is called with `d.step`/`t.step` (the computed getter from the earlier step-derivation work, already in the codebase, unchanged by this plan) in every page that shows a draft's progress. Color/spacing token names (`AppColors.*`, `AppSpacing.*`) match exactly between Task 2's definitions and every later task's usage.
- **No placeholders:** confirmed no TBD/TODO markers; every step has complete file content, an exact before/after snippet, or an exact command with expected output.
