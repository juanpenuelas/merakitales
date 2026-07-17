# Admin Panel Modernization — Design Spec

**Date:** 2026-07-17
**Status:** Approved (brainstorming complete)
**Scope owner:** Juan (single-user CMS)

## Context

The merakitales admin panel is a standalone Flutter web app under `lib/admin/`
(entry `lib/admin/main_admin.dart`, `go_router` + `NavigationRail` shell). It is
used by **one trusted operator** to manage children's tales ("cuentos"). Backend
is Firebase Cloud Functions (`firebase/functions/`, region `europe-west1`).

This effort modernizes the panel's look and structure to feel like a professional,
brand-aligned dashboard, fixes the broken Categories section, restores the lost
scheduled-publishing UI, and redesigns the login — **without adding features
beyond those listed**. Existing functionality is preserved; it is restructured
and re-skinned.

ui-ux-pro-max is applied during implementation. Ponytail governs: laziest working
solution, reuse before build, native before dependency.

## Goals

1. Brand-aligned "storybook editorial" visual system replacing the cold Tailwind blue.
2. Professional dashboard structure & component consistency across all screens.
3. Fix Categories (currently non-functional) — real CRUD + assign category to tales.
4. Restore the scheduled-publishing UI (backend already live).
5. Redesign login as a split-screen with storybook art.
6. Unify the published-tales list to use the richer draft-style status pills.

## Non-goals

- No changes to the consumer/reader app (tales store `category_id`, but the reader
  does not yet consume it).
- No search feature, no analytics charts, no roles/multi-user (single operator).
- No new backend function for scheduling or cancellation (backend exists; cancel is
  a client-side Firestore update permitted by admin rules).

---

## 1. Visual system

### Palette (from the app icon / hero art — enchanted forest)

| Role | Hex | Source |
|---|---|---|
| Primary | `#2F5E3E` (forest green) | moss / foliage |
| Accent | `#E8A33D` (lantern amber) | lit windows / lanterns |
| Secondary (sparing) | `#3FB6A8` (magic teal) | icon border |
| Background | `#FAF5EA` (warm parchment) | replaces cold slate |
| Surface | `#FFFDF9` (warm white) | cards |
| Text primary | `#241A12` (near-black bark brown) | — |
| Success / Warning / Error | `#2E7D4F` / `#D98A1F` / `#C0392B` | semantic |

Replaces the values in `lib/admin/theme/app_colors.dart`. Serif never used for red
error text; amber/green never used as body text.

### Typography

- **Headings:** Fraunces (serif, editorial/storybook warmth) via `google_fonts`.
- **Body / data / tables / forms / buttons:** Inter (already in use).
- Rule: serif only in headings; data and controls stay Inter.

Updates `lib/admin/theme/app_theme.dart` (add a `displayTextTheme`/heading style
using Fraunces; keep Inter for the rest).

### Shell

- `NavigationRail` (left) redesigned: logo top; items icon+label; active state =
  amber keyline + soft-green fill; logout separated at bottom.
- Consistent page header on every screen: serif title + subtitle/breadcrumb +
  right-aligned actions. One hierarchy per page.
- Parchment background, warm-white cards, hairline borders, soft radius, very
  subtle shadows.
- Fix pre-existing `RenderFlex`-prone layout patterns only if touched.

Files: `lib/admin/widgets/admin_scaffold.dart`, `app_theme.dart`, `app_colors.dart`,
`lib/admin/theme/app_spacing.dart`.

---

## 2. Login (split-screen)

File: `lib/admin/login/login_page.dart`.

- **Left:** `assets/images/meraki_tales_image01.png` full-bleed, subtle green/amber
  overlay, logo + tagline overlaid.
- **Right:** parchment panel, clean form — small logo, "Entrar", email + password
  (amber focus ring), inline error, primary green button, spinner while loading.
- Responsive: narrow widths collapse the illustration into a top band.
- Auth unchanged: `signInWithEmailAndPassword`; uid-lock in rules is the real gate.

---

## 3. Dashboard

File: `lib/admin/dashboard/dashboard_page.dart`.

- **KPI row** (consistent cards): Published · Pending · Scheduled · (optional) Premium.
- 🔴 **Bug fix:** current code counts collection `'drafts'`; drafts live in
  `'tale_drafts'` (`drafts_service.dart:15`). Count the correct collection; pending =
  `status == 'pending'`, scheduled = `status == 'scheduled'`.
- **"Upcoming publications":** compact list of `scheduled` drafts ordered by
  `scheduled_at` asc.
- **Quick actions:** New tale (workspace) · Categories.
- No charts (YAGNI).

---

## 4. Lists — Drafts + Published (unified)

- **Shared row card:** 56×56 thumbnail, short serif title, colored status-pill row
  reusing `lib/admin/widgets/status_badge.dart` (`.step()`, `.premium()`, `.retracted()`).
- **Published** (`published_list_page.dart`): gains pills (Published, Premium,
  category) instead of the flat grey `tale_id=… · date` subtitle. "Retirar" action
  keeps its confirm dialog.
- **Drafts** (`drafts_list_page.dart`): add filter chips **Todos / Pendientes /
  Programados**. Query changes from `status == 'pending'` to include `scheduled`;
  filter client-side or per-chip query. Scheduled rows show a "Programado ·
  DD/MM HH:mm" badge (new `StatusBadge.scheduled()` factory).
- Consistent empty states + skeletons on both.

---

## 5. Categories (repair + wire to tales)

Files: `lib/admin/categories/categories_page.dart`,
`lib/admin/services/categories_service.dart`, `lib/admin/models/category.dart`,
`firebase/firestore.rules`, plus workspace + `approveDraft.js` for assignment.

1. 🔴 **Root cause:** `firestore.rules` has no `categories` match block → Firestore
   default-deny → every read/write is `permission-denied`. Add a `categories` block
   allowing read/write for the admin uid (mirror the `tale_drafts` rule).
2. **Real create/edit dialog:** replace the hardcoded "Nueva Categoría" stub
   (`categories_page.dart:16-25`) with a form: name ES, name EN, emoji, slug
   (auto-generated from name, editable), sort order. Reuse the same dialog for edit
   (wires up the currently-dead `updateCategory`).
3. **Delete confirmation** dialog (match tales).
4. **Category on tale:** category selector in the draft workspace; store
   `category_id` on the draft; propagate to both tale docs on publish
   (`firebase/functions/src/approveDraft.js`, in the ES + EN `.set()` calls, same
   pattern as `is_premium_tale`). Reader app untouched.
5. Fix: `Category.fromDoc` `sort_order` tolerant of a double
   (`(d['sort_order'] as num?)?.toInt() ?? 0`).

---

## 6. Scheduler (restore client side)

Backend is live and unchanged: `scheduleDraft` (callable) + `publishScheduledTales`
(cron, every 15 min, `status == 'scheduled' && scheduled_at <= now`).

Lost pieces to restore:

1. **Workspace UI:** next to "Aprobar y publicar", a **"Programar publicación"**
   action → native `showDatePicker` + `showTimePicker` → call the `scheduleDraft`
   callable with `scheduledAtISO`. Draft becomes `scheduled`.
   File: `lib/admin/drafts/draft_workspace_page.dart` (+ `drafts_service.dart` for the
   callable wrapper).
2. **Dart model:** add `scheduled_at` / `scheduled_by` to `lib/admin/models/draft.dart`.
3. **Cancel schedule (client-direct):** a Firestore update setting `status` back to
   `'pending'` and clearing `scheduled_at`/`scheduled_by`, permitted by the admin-uid
   rule on `tale_drafts`. No new backend function.
4. **Composite index:** add `tale_drafts` (`status` ASC, `scheduled_at` ASC) to
   `firebase/firestore.indexes.json` — required by the cron query, currently missing.

---

## 7. Component consistency

Single reusable set, used by every screen: `AppCard`, `StatusBadge` (+ new
`.scheduled()`), filter chips, empty states (`empty_state.dart`), skeletons
(`skeleton_loader.dart`), confirm dialogs, toasts. This uniformity is what makes it
"feel like one product."

---

## Testing

- **Scheduler:** widget/logic test that "Programar" calls the callable with the
  correct ISO timestamp; test that cancel resets status to `pending`. A restored
  self-check for the two backend functions is a bonus (they currently have none).
- **Categories:** test create dialog writes the expected fields; slug auto-generation
  from name.
- **Lists:** the drafts filter selects the right status set per chip.
- **Dashboard:** counts query `tale_drafts`, not `drafts` (guards the fixed bug).
- Follow TDD per the executing plan; keep tests minimal (no frameworks/fixtures beyond
  what the repo already uses).

## Risks / notes

- Firestore composite index must be deployed (`firebase deploy --only firestore:indexes`)
  before scheduled drafts can be queried by the dashboard/cron reliably.
- Fraunces adds one `google_fonts` entry (no new dependency; `google_fonts` already
  present). Verify it renders on Flutter web.
- Deployment touches: Flutter web hosting build, `firestore.rules`, `firestore.indexes.json`,
  and `approveDraft` Cloud Function. Ask before deploying (see memory).
