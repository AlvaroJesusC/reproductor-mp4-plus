---
name: cinematic-ui-facelift
description: Enforces the cinematic visual redesign and UI facelift for reproductormp4 — modern 16:9 thumbnails, YouTube/Netflix-style duration pills, hero showcase for recent videos, clean media collection folders, vector-based chip filters without emojis, refined glassmorphic header, and non-intrusive floating action button, all while preserving 100% of underlying business logic, isolates, RepaintBoundary, and 60/120 FPS performance. Use when redesigning or refreshing the app UI, polishing video cards, modernizing tabs, eliminating AI slop, or upgrading visual hierarchy.
---

# Cinematic UI Facelift & Anti-AI-Slop Standard

Directrices obligatorias para la modernización visual completa del **Reproductor MP4**. Transforma la interfaz de un prototipo genérico básico a una experiencia cinemática premium (estilo Infuse / Plex / YouTube Mobile), manteniendo inalterada la lógica de datos y el rendimiento nativo a 60/120 FPS.

---

## 🚫 Reglas No Negociables (Preservación de Rendimiento y Lógica)

1. **Cero cambios en la capa de lógica y servicios:**
   - **NO** alterar firmas ni funcionamiento de:
     - `ServicioAlmacenamientoVideo`
     - `ServicioPreferencias`
     - `ServicioMiniaturasVideo`
     - `ModeloVideo`, `ModeloCarpetaVideo`
     - Navegación al reproductor: `PantallaReproductor.abrir(...)`
2. **Cero Jank y 60/120 FPS en el hilo principal:**
   - Mantener constructores `const` en todo subárbol sin estado dinámico.
   - Cada tarjeta de video o carpeta en `ListView.builder` o `GridView.builder` DEBE estar envuelta en un `RepaintBoundary`.
   - **Decodificación acotada de miniaturas:**
     - En vistas de lista (miniatura 16:9 compacta de ~104x58 px): usar `cacheWidth: 260`, `cacheHeight: 146` (ratio 16:9 exacto).
     - En vistas de cuadrícula o Hero Card: usar `cacheWidth: 640`, `cacheHeight: 360`.
     - Nunca decodificar a resolución nativa ni eliminar los límites de caché.
3. **Persistencia en memoria con `IndexedStack`:**
   - La pantalla principal DEBE mantener `IndexedStack` para las 3 pestañas (`Continuar`, `Videos`, `Carpetas`). Prohibido destruir el estado de las pestañas al navegar entre ellas.
4. **Prohibición de `BackdropFilter` masivo dentro de listas:**
   - Los efectos de "Glassmorphism" dentro de elementos repetitivos de listas o grids se logran mediante `BoxDecoration` con opacidades sutiles (`withValues(alpha: ...)`) y micro-bordes (`Border.all(color: Colors.white10)`), **NUNCA** con `BackdropFilter` o `ImageFiltered` repetidos dentro de cada item, ya que provocarían caídas severas en el Raster Thread.

---

## 🎨 Principios de Diseño Visual Anti-AI-Slop

### 1. Eliminación del "Triple Verde" y Badges Redundantes
- **Problema previo:** Borde verde + icono verde flotante + icono verde en texto + etiqueta "Completado".
- **Solución:** Un único indicador discreto y elegante:
  - En la miniatura: una sutil barra de progreso 100% en la base o un pequeño check estilizado translúcido.
  - En el texto: una línea de metadatos limpia con tipografía secundaria (`Completado • 23:40`).

### 2. Miniaturas 16:9 y Pastilla de Duración (Estilo YouTube/Netflix)
- **Problema previo:** Cuadrados de 48x48 tipo avatar de mensajería con una barra naranja tosca que cruzaba toda la fila.
- **Solución:**
  - Miniatura con proporción 16:9 (`width: 104`, `height: 58.5`) con `BorderRadius.circular(8)`.
  - Pastilla de duración oscura semitransparente (`Color(0xCC000000)`) con texto blanco nítido (`12:34`) en la esquina inferior derecha de la imagen.
  - Barra de progreso delgada (2 px) incrustada en el borde inferior **de la miniatura**, no flotando debajo del título.

### 3. Prohibición de Emojis Unicode en Chips y Botones
- **Problema previo:** Chips con texto `Favoritos ⭐`, `En progreso ⏳`, `Completados ✅` y carpetas con `📁` y `📄`.
- **Solución:** Iconos vectoriales limpios de Material Icons:
  - `Icons.star_rounded`
  - `Icons.timelapse_rounded`
  - `Icons.check_circle_rounded`
  - `Icons.fiber_new_rounded`
  - Badges tipográficos en lugar de texto plano con emojis: `37 videos`, `2 carpetas`.

### 4. Rediseño del Floating Action Button (FAB)
- **Problema previo:** Bloque rojo brillante gigante que tapaba el contenido inferior.
- **Solución:**
  - Transformar el botón "Abrir Archivo" en un FAB circular flotante minimalista (`FloatingActionButton(elevation: 4, child: Icon(Icons.folder_open_rounded))`) o integrarlo como acción directa y elegante en el `AppBar`.

---

## 🛠️ Especificación por Archivos del Proyecto

### 1. `lib/constantes/colores_app.dart` y `lib/constantes/temas_app.dart` (Rediseño de Paleta Completo)

La paleta actual sufre del síndrome "GitHub Dark genérico": fondos grisáceos azulados planos (`#0D1117`), verdes fosforescentes chillones (`#00E676`) y rojos planos. Se sustituye por una paleta cinemática **OLED Obsidian Studio**:

| Token en `ColoresApp` | Valor Anterior | Nuevo Valor Cinemático | Justificación de Diseño |
| :--- | :--- | :--- | :--- |
| `fondoPrincipal` | `0xFF0D1117` | `0xFF0A0D14` | Negro Obsidian profundo; máximo contraste OLED sin ser un negro muerto. |
| `fondoSecundario` | `0xFF161B22` | `0xFF121622` | Superficie elegante para AppBar, buscador y barras inferiores. |
| `fondoTarjeta` | `0xFF21262D` | `0xFF181E2B` | Elevación sutil con profundidad y calidez multimedia. |
| `acentoPrimario` | `0xFFE50914` | `0xFFFF2A54` | Carmesí cinemático vibrante con micro-resplandor moderno (estilo Apple TV / Plex). |
| `acentoVerde` | `0xFF00E676` | `0xFF10B981` | Verde esmeralda moderno; elimina el verde neón chillón que saturaba la vista. |
| `acentoAmbar` | `0xFFFFB300` | `0xFFF59E0B` | Ámbar dorado cálido para barras de progreso y tiempo guardado. |
| `textoPrincipal` | `0xFFF0F6FC` | `0xFFF8FAFC` | Blanco slate nítido y legible. |
| `textoSecundario` | `0xFF8B949E` | `0xFF94A3B8` | Gris pizarra refinado con mejor balance de contraste. |
| `textoAtenuado` | `0xFF484F58` | `0xFF64748B` | Atenuado para badges y metadatos secundarios. |
| `bordeSutil` | *(Nuevo)* | `0x1AFFFFFF` | Micro-borde translúcido (10% blanco) para dar acabado premium sin sombras pesadas. |
| `fondoPastillaTiempo`| *(Nuevo)* | `0xCC000000` | Pastilla oscura semitransparente sobre la miniatura para la duración. |

### 2. `lib/widgets/tarjeta_video.dart`
- **`TarjetaVideo` (Modo Lista):**
  - Dimensiones de miniatura: 104x58 px (16:9).
  - Stack en miniatura con:
    1. Imagen recortada (`ClipRRect(borderRadius: BorderRadius.circular(8))`).
    2. Barra de progreso incrustada abajo (`LinearProgressIndicator` de 2 px de alto con esquinas redondeadas).
    3. Pastilla de tiempo `Container` con fondo `0xCC000000`, padding `symmetric(horizontal: 4, vertical: 2)`, borde `BorderRadius.circular(4)` y texto en 10 px `FontWeight.w600`.
  - Columna derecha con título (máximo 2 líneas legibles o 1 línea con elipsis según densidad) y metadatos elegantes (`23:40  •  120 MB`).
  - Menú de 3 puntos (⋮) con micro-efecto táctil.
- **`TarjetaVideoCuadricula` (Modo Grid):**
  - Aspect ratio uniforme de 16:9 en miniatura.
  - Título limpio a 2 líneas con espacio vertical respirable.
  - Duración sobrepuesta en la imagen.

### 3. `lib/pantallas/pestanas/pestana_recientes.dart`
- **Hero Showcase para el último video:**
  - Card destacada superior con miniatura 16:9 a todo el ancho (o margen generoso).
  - Superposición con gradiente suave inferior a superior (`Colors.transparent` a `0xDD0A0E17`).
  - Botón circular translúcido central de "Continuar" con icono `Icons.play_arrow_rounded`.
  - Título en `FontWeight.bold`, indicador de "Continuar viendo" y barra de progreso cinemática con tiempo restante legible (ej: *"Faltan 14 min"*).
- **Lista/Carrusel de otros videos pendientes:**
  - Si hay más de 1 video en progreso, mostrarlos abajo en tarjetas 16:9 ordenadas y legibles.
- **Empty State:**
  - Ilustración minimalista centrada con icono moderno `Icons.movie_filter_outlined` y tipografía clara.

### 4. `lib/pantallas/pestanas/pestana_todos_los_videos.dart`
- **Buscador:**
  - `TextField` dentro de contenedor con esquinas de 14 px, micro-borde sutil y fondo `#161C28`.
- **Selector de Filtros:**
  - Chips estilizados con `FilterChip` o `ChoiceChip` usando iconos vectoriales sutiles:
    - *Todos*: `Icons.apps_rounded`
    - *Favoritos*: `Icons.star_rounded`
    - *En progreso*: `Icons.timelapse_rounded`
    - *Completados*: `Icons.check_circle_rounded`
    - *No vistos*: `Icons.fiber_new_rounded`
  - Micro-animación en cambio de filtro sin rebuild innecesario.
- **Header de conteo:**
  - Texto limpio: `"299 videos"` estilizado discretamente junto a los botones de orden y vista.

### 5. `lib/widgets/tarjeta_carpeta.dart` y `pestana_carpetas.dart`
- **Tarjeta de Carpeta:**
  - Contenedor con bordes redondeados (`BorderRadius.circular(12)`).
  - Icono de carpeta moderna con fondo en gradiente oscuro y acento azul o ambar sutil.
  - Resumen en badge estilizado: un `Container` compacto tipo pastilla que dice `"37 videos"`.
- **Migas de pan (Breadcrumbs):**
  - Chips horizontales con separadores discretos `Icons.chevron_right_rounded`.

### 6. `lib/pantallas/pantalla_principal.dart`
- **AppBar:**
  - Monograma o icono moderno de reproductor (estilo cinemático, no el botón rojo plano de YouTube de los 2010s).
  - Título con tipografía nítida y tracking moderno.
  - Indicador de sincronización/recarga animado suavemente.
- **Navegación Inferior (`NavigationBar`):**
  - Selector con indicador píldora sutil (`ColoresApp.acentoPrimario.withValues(alpha: 0.15)`).
  - Badges numéricos refinados que no desalineen los iconos.
- **FAB:**
  - FAB circular compacto flotante (`FloatingActionButton(mini: false, child: Icon(Icons.file_open_outlined))`) con sombra suave y posición que no tape el último elemento de la lista (asegurando `padding: EdgeInsets.only(bottom: 80)` en los `ListView.builder`).

---

## ⚡ Guía de Ejecución Paso a Paso para el Agente

Cuando el usuario pida iniciar la ejecución:
1. **Fase 1 (Colores y Tema Base):** Ajustar `colores_app.dart` y `temas_app.dart` para establecer el fondo Obsidian, superficies limpias y micro-bordes.
2. **Fase 2 (Componentes de Video):** Rediseñar `tarjeta_video.dart` (`TarjetaVideo` y `TarjetaVideoCuadricula`) aplicando miniaturas 16:9, duración sobrepuesta y eliminando el triple verde y la barra naranja desalineada.
3. **Fase 3 (Pestaña Continuar):** Crear el Hero Showcase en `pestana_recientes.dart` con la miniatura 16:9 destacada y botón directo de reproducción.
4. **Fase 4 (Pestaña Videos y Filtros):** Pulir buscador, sustituir emojis por iconos vectoriales en los chips de `pestana_todos_los_videos.dart` y optimizar la cuadrícula.
5. **Fase 5 (Pestaña Carpetas):** Modernizar `tarjeta_carpeta.dart` y `pestana_carpetas.dart` con estilo de colección multimedia.
6. **Fase 6 (Pantalla Principal y AppBar):** Refinar el AppBar, navegación y sustituir el FAB tosco por un botón circular ergonómico en `pantalla_principal.dart`.
7. **Verificación:** Ejecutar análisis estático (`flutter analyze` o comprobación de tipos) y verificar que no haya regresiones en FPS ni en la persistencia con `IndexedStack`.
