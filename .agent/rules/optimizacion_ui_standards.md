---
trigger: always_on
description: Reglas de optimización, rendimiento de video y mejora de UI/Layout para reproductormp4
---

# Reglas Activas para reproductormp4

1. **Consulta de Skills:**
   Revisar y ejecutar las directrices de las skills en `.agent/skills/` correspondientes a la tarea (especialmente `cinematic-ui-facelift`, `flutter-performance`, `adaptive-layout`, `widget-composition`, `custom-canvas-and-gestures` y `motion-and-haptics`).

2. **Rendimiento y Cero Jank en Video:**
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
