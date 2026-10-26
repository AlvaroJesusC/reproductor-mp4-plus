---
trigger: always_on
description: Reglas de optimización, rendimiento de video y mejora de UI/Layout para reproductormp4
---

# Reglas Activas para reproductormp4

1. **Consulta de Skills:**
   Revisar y ejecutar las directrices de las skills en `.agent/skills/` correspondientes a la tarea (especialmente `video-picture-in-picture`, `video-pinch-to-zoom`, `extreme-multimedia-performance`, `cinematic-ui-facelift`, `flutter-performance`, `adaptive-layout`, `widget-composition`, `custom-canvas-and-gestures` y `motion-and-haptics`).

2. **Módulo Picture-in-Picture y Mini-Reproductor In-App (`video-picture-in-picture`):**
   - Encapsular la lógica en `lib/modulos/pip/` para mantener el código desacoplado y limpio.
   - Modo dual: ventana flotante del sistema Android (PiP) y mini-ventana acoplada dentro de la app tipo YouTube.
   - Envolver el mini-reproductor en `RepaintBoundary` y usar `ValueNotifier` para cero rebuilds en la biblioteca.

3. **Pinch-to-Zoom Multitáctil a 144Hz (`video-pinch-to-zoom`):**
   - Desambiguar gestos: 1 dedo controla brillo/volumen/seek; 2 dedos escalan y paneant el lienzo del video.
   - Usar `ValueListenableBuilder<Matrix4>` con `Transform` para que la transformación ocurra en GPU sin reconstruir el reproductor.
   - OSD visual de porcentaje de zoom (`🔍 145%`) y restablecimiento por doble toque o botón lateral.

3. **Rendimiento Extremo a 144Hz y Cero Jank en Video (`extreme-multimedia-performance`):**
   - Forzar el modo de alta tasa de refresco a 144Hz con `flutter_displaymode`.
   - Fast-Seeking por keyframes en arrastre de scrubber para evitar congelamiento de CPU.
   - Pre-warmed Player Pool para arranque de video instantáneo (<50ms).
   - Constructores `const` en todo subárbol estático.
   - Aislar el scrubber de tiempo y barra de progreso; nunca hacer `setState()` global durante la reproducción.
   - Usar `RepaintBoundary` entre la textura del video y el HUD de controles, y en cada elemento de lista o grid.
   - Liberar de inmediato recursos (`dispose`) de video, wakelock y timers.
   - Decodificar miniaturas de video con tamaño acotado (`cacheWidth`/`cacheHeight`).
   - Cero cambios a la lógica de negocio o servicios de almacenamiento/preferencias.

3. **Mejora de UI, Rediseño Cinemático y Anti-AI-Slop (`cinematic-ui-facelift`):**
   - Miniaturas panorámicas 16:9 con duración sobrepuesta estilo YouTube/Netflix.
   - Eliminación del triple verde redundante y barras de progreso desalineadas.
   - Reemplazo de emojis unicode (`⭐`, `⏳`, `📁`) por iconos vectoriales sutiles.
   - Hero Card en pestaña "Continuar" para reanudar al instante.
   - FAB minimalista y no obstructivo que no tape elementos de la lista.
   - Adaptación fluida a modo horizontal/pantalla completa inmersiva respetando notches.
   - Gestos táctiles de brillo, volumen y búsqueda con OSD limpio y respuesta inmediata.
   - Micro-interacciones suaves con fade in/out no intrusivo para los controles.
