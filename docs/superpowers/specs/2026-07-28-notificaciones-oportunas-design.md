# Notificaciones oportunas: pre-diálogo en el momento bueno

**Fecha:** 2026-07-28
**Estado:** aprobado por Juan (opción recomendada elegida en conversación)
**Alcance:** app móvil. No toca admin, Cloud Functions ni reglas.

## Problema

El permiso de notificaciones se pide hoy con el prompt del sistema, una sola vez por
proceso (`static _hasRequested` en `notification_service.dart:11`), disparado en el
`initState` del detalle del cuento — es decir, justo cuando el usuario acaba de abrir
su primer cuento y quiere leer. Tocar fuera del diálogo lo descarta, la app no vuelve
a intentarlo en esa sesión (y en Android el proceso sobrevive a "cerrar" la app), y no
existe estrategia de reintento. Resultado: casi nadie concede el permiso y Juan quiere
que la gente reciba avisos de cuentos nuevos.

## Decisiones

- **Pre-diálogo propio** de la app en un momento de buena voluntad: **al volver de leer
  un cuento** (cuando el detalle hace pop y se vuelve a la home/cuadrícula).
- **El prompt del sistema solo se dispara si el usuario dice "Sí"** en el pre-diálogo.
  Los dos "No permitir" explícitos que Android tolera se gastan solo con usuarios
  predispuestos.
- **Política de reofertas** (constantes con nombre, ajustables): primera oferta al
  volver de la **2ª** apertura de cuento; si dice "Ahora no", siguiente oferta **+5**
  aperturas después; **máximo 3 ofertas** en total. Concedido el permiso → suscribir
  al topic y no volver a preguntar jamás.
- Si el usuario dice "Sí" pero descarta el prompt del sistema tocando fuera (Android
  devuelve denegado), la política sigue viva: cuenta como oferta hecha y podrá
  reintentarse hasta el tope.
- **Usuarios ya concedidos** (los que aceptaron con el flujo viejo): al arrancar la
  home se comprueba el estado y, si está autorizado, se re-suscribe al topic en
  silencio (paridad con hoy) y se marca la política como completada.
- Cero dependencias nuevas: `AlertDialog`, `SharedPreferences` y `firebase_messaging`
  ya presentes.

## Diseño

### `lib/services/notification_prompt_policy.dart` (nuevo, lógica pura testeable)

```dart
class NotificationPromptPolicy {
  static const int kFirstOfferAtOpens = 2;
  static const int kOpensBetweenOffers = 5;
  static const int kMaxOffers = 3;
  // Claves de SharedPreferences:
  // notif_opens_count (int), notif_offers_made (int),
  // notif_next_offer_at (int), notif_done (bool)

  Future<void> recordTaleOpen();            // incrementa notif_opens_count
  Future<bool> shouldOfferNow();            // reglas de arriba, sin tocar firebase
  Future<void> recordOfferShown();          // offers_made++, next_offer_at = opens + kOpensBetweenOffers
  Future<void> markDone();                  // notif_done = true
  Future<bool> isDone();
}
```

`shouldOfferNow()` es verdadero solo si: `!notif_done` y `offers_made < kMaxOffers` y
`opens_count >= (offers_made == 0 ? kFirstOfferAtOpens : next_offer_at)`.

### `lib/services/notification_service.dart` (refactor)

- Muere el `static _hasRequested` y muere la auto-petición.
- `Future<bool> ensureSubscribedIfAuthorized()`: `getNotificationSettings()`; si
  authorized/provisional → `_subscribeToTopicBasedOnLanguage()` y `true`; si no,
  `false`. Sin prompt.
- `Future<bool> requestPermissionAndSubscribe()`: dispara el prompt del sistema
  (lógica actual de `requestPermission`), suscribe si concede, devuelve si concedió.
- `_subscribeToTopicBasedOnLanguage()` intacto.

### `lib/components/notification_offer_dialog.dart` (nuevo, widget tonto)

`AlertDialog` con estilo de la app: 🔔 grande, título "¿Te avisamos cuando publiquemos
un cuento nuevo?" / "Want a nudge when a new tale arrives?", texto corto "Solo cuentos
nuevos. Nada de ruido." / "New tales only. No noise.", botones `TextButton` "Ahora no"
/ "Not now" y `FilledButton` verde "Sí, avísame" / "Yes, tell me". Devuelve `bool?`
via `Navigator.pop` (patrón `showDialog<bool>`); strings inline `isSpanish`.

### Cableado

- `lib/services/tale_opener.dart` (`openTale`): tras `context.pushNamed` (su Future
  completa al hacer pop), con `context.mounted`: `recordTaleOpen()`; si
  `shouldOfferNow()` → `recordOfferShown()` + mostrar el diálogo; si "Sí" →
  `requestPermissionAndSubscribe()`; si concedió → `markDone()`.
- `lib/pages/library_home/library_home_widget.dart` (`initState`, post-frame):
  `if (await NotificationService().ensureSubscribedIfAuthorized()) markDone();`
- `lib/components/tale_detail_mobile/tablet_component_widget.dart`: eliminar la
  llamada a `NotificationService().requestPermissionsAndSubscribe()` (y su comentario).

## Tests (TDD sobre la política; el resto se verifica manual)

`test/notification_prompt_policy_test.dart` con `SharedPreferences.setMockInitialValues`:
1. Sin historial: no ofrece en la 1ª apertura, sí al volver de la 2ª.
2. "Ahora no": siguiente oferta exactamente 5 aperturas después, no antes.
3. Tope: tras 3 ofertas, nunca más.
4. `markDone`: no ofrece aunque queden ofertas.
5. Los contadores persisten entre instancias del servicio (misma prefs).

Suite completa en verde (63 actuales + los nuevos); `flutter analyze` 27 baseline.

## Fuera de alcance

Deep-link a ajustes del sistema cuando Android bloquea permanentemente (2 "No
permitir" explícitos), notificaciones locales/programadas, cambios en el envío de
notificaciones (Cloud Functions), pantalla de ajustes de notificaciones en la app.

## Criterios de aceptación

1. Instalación limpia: leer 1 cuento no ofrece nada; al volver del 2º aparece el
   pre-diálogo.
2. "Sí, avísame" → prompt del sistema; concedido → suscrito al topic del idioma y no
   se vuelve a preguntar nunca (ni tras reinstalar el proceso).
3. "Ahora no" → reaparece tras 5 aperturas más; a la 3ª oferta rechazada, silencio
   definitivo.
4. Usuario con permiso ya concedido: arranca la app → re-suscripción silenciosa, cero
   diálogos.
5. El detalle del cuento ya no dispara ningún prompt.
6. `flutter analyze` sin issues nuevos; `flutter test` verde.
