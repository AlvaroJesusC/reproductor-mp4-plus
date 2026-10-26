# Reglas y Estándares de Optimización y UI/Layout para reproductormp4

> **IMPORTANTE PARA EL AGENTE DE IA (ANTIGRAVITY / COPILOT / CURSOR):**
> Este proyecto cuenta con skills especializadas instaladas localmente en `.agent/skills/`.
> **SIEMPRE**, antes de implementar funcionalidades, optimizar código, diseñar o ajustar pantallas y controles multimedia, DEBES consultar y seguir rigurosamente las directrices de las skills correspondientes.

---

## 🗺️ Mapa de Skills Obligatorias para este Proyecto

| Tarea / Dominio | Skill(s) Obligatoria(s) en `.agent/skills/` |
| :--- | :--- |
| **Picture-in-Picture (PiP Android y Mini-reproductor Flotante In-App)** | `video-picture-in-picture` |
| **Zoom y Paneo Multitáctil (Pinch to Zoom 1.0x-5.0x a 144Hz)** | `video-pinch-to-zoom` |
| **Rendimiento Extremo, Modo 144Hz Turbo y Reproducción Instantánea** | `extreme-multimedia-performance` |
| **Lavado de Cara, Rediseño Cinemático y Anti-AI-Slop** | `cinematic-ui-facelift` |
| **Rendimiento, 60/120/144 FPS, Scrubber/Timeline sin Jank, Isolates** | `flutter-performance` |
| **Layout Adaptativo (Pantalla Completa, Rotación, Notches, Safe Areas)** | `adaptive-layout` |
| **Composición de Widgets (HUD de controles vs Lienzo de Video)** | `widget-composition` |
| **Gestos Táctiles (Volumen, Brillo, Scrubbing OSD, Custom Painters)** | `custom-canvas-and-gestures` |
| **Animaciones, Físicas y Micro-interacciones (Fade OSD, Haptics)** | `motion-and-haptics` |
| **Diseño Visual de Alto Impacto (Tema Oscuro Multimedia, Cards)** | `design-system-structure` |
| **Estados de Buffering, Carga, Error y Playlists Vacías** | `ui-states-and-feedback` |
| **Sintaxis Moderna Dart 3 sin Código Redundante** | `dart3-idioms-and-coding-standards` |
| **Seguridad Asíncrona (Dispose de controladores, mounted checks)** | `async-safety` |
| **Arquitectura Limpia y Modular** | `flutter-architecture`, `project-structure-and-packages` |

---

## ⚡ 1. Directivas de Rendimiento y Optimización (Video & UI)
*Referencia principal: `.agent/skills/flutter-performance/SKILL.md`*

1. **Aislamiento de la Barra de Progreso (Scrubber):**
   - El progreso del video cambia múltiples veces por segundo. **NUNCA** hacer `setState()` a nivel de toda la pantalla del reproductor o del overlay de controles.
   - Aislar el slider y el texto de tiempo (`00:15 / 03:45`) en widgets independientes usando `ValueListenableBuilder` o builders locales con `child:` estático.
2. **RepaintBoundary Quirúrgico:**
   - Envolver el widget del video y el HUD de controles superpuesto en `RepaintBoundary` separados para que las actualizaciones del HUD no fuercen el repintado de la textura del video.
3. **Optimización de Miniaturas y Listas de Videos:**
   - En `servicio_miniaturas_video.dart` y en las tarjetas de video (`tarjeta_video.dart`), usar siempre decodificación ajustada (`cacheWidth` / `cacheHeight` o `ResizeImage`). Nunca decodificar imágenes a resolución completa en grids o listas.
   - Listas de videos y carpetas SIEMPRE con `ListView.builder` / `GridView.builder` perezosos.
4. **Liberación Estricta de Recursos (`dispose`):**
   - Liberar inmediatamente `VideoPlayerController`, timers de auto-ocultamiento de controles HUD, suscripciones y controladores de animación al salir de `pantalla_reproductor.dart`.
5. **Cero operaciones pesadas en el UI Thread:**
   - Escaneo de carpetas de almacenamiento y cálculo de metadatos pesados deben ejecutarse en `compute()` o `Isolate` para evitar micro-congelamientos en la navegación.

---

## 🎨 2. Directivas de UI, Layout y Ergonomía Multimedia
*Referencias: `.agent/skills/adaptive-layout/`, `widget-composition/`, `custom-canvas-and-gestures/`, `motion-and-haptics/`*

1. **Inmersión y Manejo de Orientación:**
   - La pantalla de reproducción debe adaptarse fluidamente entre modo vertical y horizontal/pantalla completa real (ocultando barras del sistema con `SystemChrome.setEnabledSystemUIMode`).
   - Respetar áreas seguras (*cutouts*, *notches*, esquinas redondeadas) para que los controles no queden tapados.
2. **Gestos OSD Suaves e Intuitivos:**
   - Control de brillo (lado izquierdo), volumen (lado derecho) y seek por deslizamiento horizontal con respuesta visual OSD centrada y limpia.
   - Feedback táctil sutil (háptico) al alcanzar valores límite (volumen 100%, brillo máx/mín) o al pausar/reanudar.
3. **Desvanecimiento Fluido de Controles:**
   - Animación de entrada y salida de los controles con curvas naturales (`Curves.easeInOut` o `Curves.fastOutSlowIn`), evitando parpadeos bruscos.
4. **Estados Visuales Claros:**
   - Indicador de carga/buffering centrado no intrusivo; estados de error claros si un códec o archivo está corrupto.
