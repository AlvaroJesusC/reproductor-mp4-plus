---
trigger: always_on
description: Reglas de optimización, rendimiento de video y mejora de UI/Layout para reproductormp4
---

# Reglas Activas para reproductormp4

1. **Consulta de Skills:**
   Revisar y ejecutar las directrices de las skills en `.agent/skills/` correspondientes a la tarea (especialmente `flutter-performance`, `adaptive-layout`, `widget-composition`, `custom-canvas-and-gestures` y `motion-and-haptics`).

2. **Rendimiento y Cero Jank en Video:**
   - Constructores `const` en todo subárbol estático.
   - Aislar el scrubber de tiempo y barra de progreso; nunca hacer `setState()` global durante la reproducción.
   - Usar `RepaintBoundary` entre la textura del video y el HUD de controles.
   - Liberar de inmediato recursos (`dispose`) de video, wakelock y timers.
   - Decodificar miniaturas de video con tamaño acotado (`cacheWidth`/`cacheHeight`).

3. **Mejora de UI y Layout:**
   - Adaptación fluida a modo horizontal/pantalla completa inmersiva respetando notches.
   - Gestos táctiles de brillo, volumen y búsqueda con OSD limpio y respuesta inmediata.
   - Micro-interacciones suaves con fade in/out no intrusivo para los controles.
