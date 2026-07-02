# Rediseño visual de la zona de administración

**Fecha:** 2026-07-02
**Estado:** Aprobado (pendiente de plan de implementación)
**Proyecto:** merakitales
**Herramienta usada:** ui-ux-pro-max (design-system + domain style/typography/color + stack flutter)

## Contexto

Las 7 páginas de `lib/admin` (login, lista/detalle/creación de borradores ×2, lista/detalle de publicados) usan Material 3 por defecto: un solo color semilla (`colorSchemeSeed: Color(0xFF1D2428)`), sin tipografía personalizada, sin sistema de espaciado consistente (`SizedBox` con números sueltos repartidos por cada archivo), iconos mezclados (emoji 📝🖼️🎵 junto a iconos Material), y widgets ad hoc repetidos con ligeras variaciones entre páginas (tarjetas, listas, badges de estado). El resultado se percibe como genérico y sin pulir, aunque funcionalmente ya está bien resuelto (estados de carga/error, confirmaciones antes de acciones destructivas, etc. ya existen).

Es una herramienta interna de un solo usuario (el admin), no una superficie de cara al usuario final de Meraki Tales — no necesita reflejar la identidad de marca de la app de cuentos.

## Objetivo

Aplicar un sistema de diseño ligero y propio (tokens de color/tipografía/espaciado + un puñado de widgets reutilizables) a las 7 páginas, con estética de "dashboard interno neutro y profesional" (tipo Notion/Linear), sin tocar rutas, lógica de negocio, ni la app de consumidor final (`lib/backend`).

## No incluido en esta versión

- Modo oscuro — solo modo claro. Los tokens de color no se diseñan pensando en un futuro modo oscuro; añadirlo después sería un cambio incremental sobre esta base, no algo que bloquee este trabajo.
- Cualquier cambio de identidad de marca hacia la app de cuentos (colores cálidos, tono infantil) — se descarta explícitamente a favor de una estética neutra de herramienta interna.
- Cambios de flujo, campos de formulario, validaciones o rutas — es un cambio puramente visual/estructural sobre el árbol de widgets existente.
- Gráficas, KPIs o vistas de analítica — esta herramienta es de revisión/creación de contenido, no un dashboard de datos; no se añade nada de eso aunque el estilo "Data-Dense Dashboard" de la búsqueda inicial lo sugiriera.
- Tocar `lib/backend` (la app de consumidor final) de ninguna forma.

## Tokens de diseño

**Paleta** (recomendada por ui-ux-pro-max para herramientas de gestión de contenido/documentación, adaptada):
| Token | Valor | Uso |
|---|---|---|
| Primario | `#2563EB` | Botones principales, enlaces, foco |
| Fondo de página | `#F8FAFC` | `Scaffold.backgroundColor` |
| Superficie/tarjeta | `#FFFFFF` | `AppCard` |
| Texto principal | `#0F172A` | Texto de cuerpo/títulos |
| Texto secundario | `#64748B` | Subtítulos, metadatos |
| Borde | `#E2E8F0` | Borde de `AppCard`, divisores |
| Relleno sutil | `#F1F5F9` | Fondo de `StatusBadge`, hover |
| Éxito | `#059669` | Badge "publicado" |
| Aviso | `#D97706` | Badge "retractado", avisos no bloqueantes |
| Destructivo | `#DC2626` | Botón rechazar/retirar, errores |

**Tipografía**: Inter (títulos y cuerpo) vía el paquete `google_fonts` (nueva dependencia — descarga y cachea la fuente en tiempo de ejecución, es el patrón estándar en Flutter para usar Google Fonts sin empaquetar `.ttf`). Se reutilizan los roles existentes de `TextTheme` de Material 3 (`titleLarge`, `titleMedium`, `bodyMedium`, `labelSmall`, etc.) con Inter como familia y pesos ajustados — no se inventa una escala tipográfica nueva.

**Espaciado**: constantes `AppSpacing` (`xs=4, sm=8, md=16, lg=24, xl=32`) que sustituyen los `SizedBox(height: N)` con números sueltos hoy repartidos por las 7 páginas.

**Radio de esquina**: 8px para tarjetas y botones, 6px para miniaturas de imagen (consistente con lo que ya usa `draft_detail_page.dart` para las miniaturas, se mantiene).

**Tarjetas planas**: fondo blanco + borde de 1px (`--color-border`) en vez de elevación/sombra de Material — más acorde a la estética "herramienta interna" buscada.

## Componentes compartidos

Nuevos widgets en `lib/admin/widgets/`:

1. **`AppCard`** — `Container` con el borde/fondo/radio de la sección anterior y padding interno de `AppSpacing.md` (16px) en los 4 lados. Sustituye los envoltorios de tarjeta ad hoc repetidos hoy en las 6 páginas de contenido (todo salvo login).
2. **`EmptyState`** — icono + mensaje + acción opcional (botón). Sustituye los `Center(child: Text('No hay...'))` actuales en `drafts_list_page.dart` y `published_list_page.dart`.
3. **`StatusBadge`** — pill icono+texto+color para: paso del borrador (texto/imagen/audio), "retractado", "publicado". Sustituye tanto los emoji (📝🖼️🎵, usados hoy como iconos estructurales del paso) como el patrón `Icon`+`Text` repetido a mano en `drafts_list_page.dart`, `draft_detail_page.dart` y `draft_create_page.dart`.

**Limpieza de iconos**: ningún emoji se usa como icono estructural de estado tras este cambio — `StatusBadge` usa iconos Material (p. ej. `Icons.edit_note` para texto, `Icons.image` para imagen, `Icons.graphic_eq` para audio). Los emoji pueden seguir apareciendo como texto decorativo dentro de mensajes (p. ej. el aviso "⚠️ Los cuentos existentes tienen 300-500 palabras" en los formularios), ya que ese uso no es el que se pidió limpiar.

## Aplicación por página

Las 7 páginas reciben el mismo tratamiento (tema global + los 3 widgets compartidos donde aplique):

- **`app.dart`**: solo `ThemeData` — nuevo `ColorScheme`, `google_fonts`, `TextTheme` ajustado. Ningún cambio de rutas.
- **`login_page.dart`**: campos envueltos en un `AppCard` centrado en vez de flotar sueltos sobre el fondo.
- **`drafts_list_page.dart`**: cada fila envuelta en `AppCard`, `StatusBadge` para el paso (sustituye el emoji), `EmptyState` si no hay borradores pendientes.
- **`draft_detail_page.dart`**: cada bloque (imagen, descripción, texto, audio) en su propio `AppCard`; `StatusBadge` para el paso y para "retractado".
- **`draft_create_page.dart`** y **`draft_create_manual_page.dart`**: mismo tratamiento de tarjetas/espaciado en cada sección del asistente (texto ES/EN, imagen, audio ES/EN).
- **`published_list_page.dart`**: `AppCard` por fila + `EmptyState`.
- **`published_tale_detail_page.dart`**: mismo patrón que `draft_detail_page.dart`.

Ningún archivo de lógica (`drafts_service.dart`, `models/`) se toca — este cambio vive enteramente en la capa de widgets.

## Testing y verificación

Como el resto de `lib/admin`, no hay tests automatizados de UI. Verificación:
- `flutter analyze lib/admin` — 0 errores, solo los 5 warnings preexistentes de imports no usados.
- `flutter build web -t lib/admin/main_admin.dart --release` — build sin errores.
- Inspección visual manual de las 7 páginas tras desplegar. Al ser un cambio puramente visual, esta comprobación importa más de lo habitual: si en el momento de implementar la extensión de Claude en Chrome está conectada, se usará para capturar cada página (antes/después) en vez de pedir al usuario que lo haga manualmente; si no está conectada, se deja como paso pendiente explícito, igual que en los planes anteriores.
