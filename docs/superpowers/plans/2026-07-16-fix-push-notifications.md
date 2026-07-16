# Plan: Fix Push Notifications (2026-07-16)

## Context & Root Cause Analysis

Implemented FCM push notifications this week (commits c998876..49109b2), but notifications
are NOT delivered when a new tale is published. Analysis identified 4 root causes.

### Root Cause 1 — CRITICAL: `requestPermissionsAndSubscribe` called in `dispose()`
- Files: `lib/components/tale_detail_mobile_component_widget.dart` (line 272)
         `lib/components/tale_detail_tablet_component_widget.dart` (line ~272)
- `dispose()` runs when the widget is being destroyed; the context is gone.
- The Future is launched unawaited -> fails silently.
- The FCM permission dialog NEVER appears on iOS.
- The device NEVER subscribes to the topic -> server sends to no devices.

### Root Cause 2 — CRITICAL: iOS `Info.plist` missing `UIBackgroundModes: remote-notification`
- File: `ios/Runner/Info.plist`
- Apple requires `remote-notification` in `UIBackgroundModes` to receive FCM push in background.
- Without it, iOS silently drops background push notifications.

### Root Cause 3 — MODERATE: `publishScheduledTales.js` has a stale TODO
- File: `firebase/functions/src/publishScheduledTales.js` (line 30)
- Comment says "TODO: Here is where we will trigger Push Notifications to users in the future"
- BUT: `publishDraft()` already includes the FCM send block since commit 49109b2.
- The TODO is stale/misleading. Action: remove it, add clarifying comment.

### Root Cause 4 — MODERATE: Functions not redeployed after notification code was added
- The `approveDraft` Cloud Function may still be running the OLD version (without FCM send).
- Must be verified and redeployed.

## Branch

`fix/push-notifications`

## Tasks

### Task 1 — Fix notification subscription trigger in mobile widget
Scope: `lib/components/tale_detail_mobile_component_widget.dart`
- Remove `NotificationService().requestPermissionsAndSubscribe()` from `dispose()`
- Add a `_hasRequestedPermissions` static bool flag to `NotificationService` to ensure
  the permission dialog only appears once per app session (idempotent).
- Call `NotificationService().requestPermissionsAndSubscribe()` in `initState()`,
  inside the existing `addPostFrameCallback`, after the weekly limit check block.
- Must be unawaited (fire-and-forget) and guarded by the static flag.
- No other changes to the widget.

### Task 2 — Fix notification subscription trigger in tablet widget
Scope: `lib/components/tale_detail_tablet_component_widget.dart`
- Same fix as Task 1, mirrored for the tablet component.
- Read the tablet file first to confirm it mirrors the mobile widget structure.

### Task 3 — Add `UIBackgroundModes: remote-notification` to iOS Info.plist
Scope: `ios/Runner/Info.plist`
- Add the `UIBackgroundModes` key with array value containing `remote-notification`.
- This is required for iOS to wake the app and display FCM notifications in background/killed state.
- Place the key near the top of the dict, after existing `CFBundleShortVersionString`.

### Task 4 — Clean up stale TODO in `publishScheduledTales.js`
Scope: `firebase/functions/src/publishScheduledTales.js`
- Remove the stale TODO comment (FCM is already handled inside `publishDraft()`).
- Replace with a comment: "FCM push notifications are dispatched inside publishDraft()."
- No logic changes.

### Task 5 — Deploy Cloud Functions and verify
Scope: Deploy + verification
- Create git branch `fix/push-notifications` before Task 1.
- Commit after each task.
- After Task 4: redeploy `approveDraft` and `publishScheduledTales` functions.
- Check Firebase Console logs for `Push notifications dispatch completed` message.

## Success Criteria
- Device subscribed to `new_tales_es` (or `en`) topic after first opening a tale detail.
- Firebase logs show `Push notifications dispatch completed` on tale publication.
- iOS device in background receives push notification within ~30s of publication.

## Out of Scope
- Notification tap handling / deep linking to the new tale (future work).
- `onMessage` foreground notification handling (future work).
- Android-specific notification channel setup (FCM default is sufficient).
