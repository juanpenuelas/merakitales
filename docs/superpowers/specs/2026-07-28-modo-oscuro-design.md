# Modo oscuro: bosque nocturno

**Fecha:** 2026-07-28
**Estado:** aprobado por Juan
**Alcance:** app móvil. No toca admin, Functions ni reglas. Sin rebrand del tema claro
(el primary morado de FlutterFlow queda como está en claro; rebrand = otro día).

## Objetivo

Leer de noche sin deslumbrar. La fontanería ya existe (`main.dart`: `themeMode` +
`darkTheme` + persistencia; por defecto sigue al sistema): falta afinar la paleta
oscura, barrer los colores a fuego de las pantallas nuevas y dar un toggle manual.

## 1. Paleta oscura (clase `DarkModeTheme` en `flutter_flow_theme.dart`)

Solo cambian estos seis valores (bosque de noche, cálido — no gris azulado):

| token | valor actual | nuevo |
|---|---|---|
| `primaryBackground` (página) | 0xFF1D2428 | **0xFF121814** |
| `secondaryBackground` (tarjetas/hojas/drawer) | 0xFF14181B | **0xFF1C2620** |
| `alternate` (bordes/placeholders) | 0xFF262D34 | **0xFF2E3B33** |
| `primaryText` | 0xFFFFFFFF | **0xFFF3EDE0** (pergamino) |
| `secondaryText` | 0xFF95A1AC | **0xFFAAB8AC** (salvia) |
| `accent4` (velos) | 0xB2262D34 | **0xB2121814** |

`primary`, `secondary`, `tertiary`, `accent1-3`, `success/warning/error/info`:
intactos. Verificar que `main.dart` construye `darkTheme: ThemeData(brightness:
Brightness.dark, ...)` para que diálogos/snackbars/menus del sistema adapten solos.

## 2. Barrido de colores a fuego → tokens del tema

Regla general: superficies blancas → `secondaryBackground`; texto casi-negro →
`primaryText`; texto gris medio → `secondaryText`; placeholders gris claro →
`alternate`. Los elementos de MARCA no cambian con el tema: verde 0xFF2D5A3D
(cabeceras/gradientes), ámbar 0xFFE8B04B (pastillas/CTA), tarjetas con gradiente
verde (upsell, cabecera de categoría) y todo texto blanco que viva SOBRE esos verdes.

| archivo | qué cambia |
|---|---|
| `library_home_widget.dart` | scaffold `0xFFF1F4F8` → `primaryBackground`; cabecera verde intacta |
| `shelf_row.dart` | título `0xFF101213` → `primaryText` |
| `tale_cover_card.dart` | título `0xFF101213` → `primaryText`; placeholder `0xFFE0E0E0` → `alternate` |
| `category_page_widget.dart` | scaffold `0xFFF1F4F8` → `primaryBackground`; AppBar y tarjeta-gradiente intactas |
| `premium_upsell_card.dart` | intacta (gradiente de marca, independiente del modo) |
| `notification_offer_dialog.dart` | textos con literal oscuro (si los hay) → tokens; superficie del diálogo ya adapta vía `darkTheme` |
| `drawer_component_widget.dart` | `color: Colors.white` del Container → `secondaryBackground`; título y "Idioma" `0xFF15161E` → `primaryText`; icono idioma `0xFF57636C` → `secondaryText`; barrer el resto de literales de texto/superficie del archivo con la regla general |
| `tale_detail_mobile/_tablet_component_widget.dart` | bottom sheet del límite semanal: `Colors.white` → `secondaryBackground`, título `Colors.black` → `primaryText`, cuerpo `Colors.black54` → `secondaryText`; barrer el resto de literales de texto/superficie de ambos archivos con la regla general (los colores de badges NUEVO/PREMIUM, ads y botones sobre verde/primary quedan) |

## 3. Toggle en el drawer

Fila nueva bajo el selector de idioma, mismo patrón visual:
`Icons.dark_mode_outlined` (color `secondaryText`) + texto "Tema"/"Theme" +
`SegmentedButton<ThemeMode>` con `showSelectedIcon: false` y tres segmentos SOLO
icono: `Icons.light_mode` (ThemeMode.light), `Icons.brightness_auto`
(ThemeMode.system), `Icons.dark_mode` (ThemeMode.dark).
`selected: {FlutterFlowTheme.themeMode}` y `onSelectionChanged: (s) =>
MyApp.of(context).setThemeMode(s.first)` (accessor en `main.dart:54`; `setThemeMode`
ya persiste — verificar que `saveThemeMode(ThemeMode.system)` limpia la preferencia,
como hace FlutterFlow de serie).

## Tests y verificación

- Sin tests nuevos (feature visual). Los 68 existentes en verde y `flutter analyze`
  en 27 (los widget tests bombean tema claro por defecto; los tokens no cambian los
  `find.text`).
- Verificación visual: simulador en apariencia oscura (`xcrun simctl ui booted
  appearance dark`) — capturas de home, página de categoría, detalle/lectura, drawer
  y diálogo de notificaciones; y regresión rápida en claro.

## Fuera de alcance

Rebrand del tema claro (primary morado → verde), modo sepia/lectura tipográfica,
admin en oscuro, ajuste de brillo de portadas en oscuro.

## Criterios de aceptación

1. Con el móvil en modo oscuro (ajuste "auto"), home, categoría, lectura, drawer y
   diálogos salen en paleta bosque nocturno; nada blanco deslumbrante.
2. El toggle del drawer cambia claro/auto/oscuro al instante y persiste tras matar la
   app.
3. En claro todo se ve EXACTAMENTE como hoy (regresión cero).
4. La pantalla de lectura de noche: fondo oscuro cálido, texto pergamino legible.
5. `flutter analyze` 27; suite 68/68.
