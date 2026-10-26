---
name: video-picture-in-picture
description: Enforces a modular, isolated architecture for Picture-in-Picture (PiP) and in-app YouTube-style floating miniplayer for reproductormp4. Includes Android OS PiP (system floating window) and In-App Docked Miniplayer above bottom navigation, encapsulated in lib/modulos/pip/ without bloating existing screens or degrading 144Hz performance.
---

# Picture-in-Picture (PiP) & Mini-Reproductor Flotante In-App

Guía y estándares técnicos para implementar el sistema dual de Picture-in-Picture en **`reproductormp4`**:
1. **Mini-Reproductor Flotante In-App (Estilo YouTube):** Permite seguir viendo el video en una mini-tarjeta acoplada mientras el usuario explora carpetas y la biblioteca dentro de la app.
2. **Picture-in-Picture Nativo de Android (Ventana Flotante del Sistema):** Permite que el video flote sobre otras aplicaciones (WhatsApp, navegador, escritorio).

Para mantener el código limpio y no inflar `pantalla_reproductor.dart` ni `pantalla_principal.dart`, **toda la funcionalidad debe residir en su propio módulo independiente: `lib/modulos/pip/`**.

---

## 📁 1. Arquitectura Modular Aislada (`lib/modulos/pip/`)

Estructura de archivos del módulo:

```
lib/modulos/pip/
├── gestor_pip_global.dart         # Singleton / Notifier del estado de reproducción flotante
├── mini_reproductor_flotante.dart  # Widget de la mini-ventana acoplada (video 16:9, título, controles)
├── servicio_pip_nativo.dart       # Integración con el PiP de Android (paquete floating)
└── envoltorio_pip_scaffold.dart   # Wrapper para superponer el mini-reproductor sin re-renderizar pantallas
```

### Responsabilidades de cada archivo:

1. **`gestor_pip_global.dart`:**
   - Mantiene la referencia al video activo (`ModeloVideo`), el `Player` y el `VideoController` de `media_kit`.
   - Expone un `ValueNotifier<EstadoPip>` con los estados: `cerrado`, `reproductorCompleto`, `minimizadoInApp`, `pipNativoSistema`.
   - Métodos: `minimizar()`, `expandir()`, `cerrar()`, `alternarPlayPause()`.
   - Al cerrar (`cerrar()`), guarda automáticamente la posición y duración en `ServicioPreferencias` y detiene el reproductor.

2. **`mini_reproductor_flotante.dart`:**
   - Tarjeta flotante acoplada en la parte inferior (justo encima de la barra de navegación `NavigationBar`).
   - Dimensiones: alto de 64 px con esquinas redondeadas (`BorderRadius.circular(12)`), fondo `ColoresApp.fondoTarjeta` con micro-borde sutil.
   - Distribución interna:
     - Izquierda: Miniatura en vivo 16:9 del video (`ClipRRect` con `Video(controller: ...)`).
     - Centro: Título del video con elipsis a 1 línea en blanco nítido.
     - Derecha: Botón Play/Pause circular y botón Cerrar (`X`).
   - Al tocar el cuerpo de la tarjeta: invoca `gestor.expandir()`, abriendo nuevamente la pantalla completa sin re-cargar el video.

3. **`servicio_pip_nativo.dart`:**
   - Gestiona el paquete `floating` (`Floating().enable(...)`).
   - Configura el aspect ratio (16:9) para la ventana flotante del sistema Android.

4. **`envoltorio_pip_scaffold.dart`:**
   - Envuelve el `Scaffold` o cuerpo de `PantallaPrincipal`.
   - Utiliza un `Stack` con `ValueListenableBuilder<EstadoPip>` para mostrar `MiniReproductorFlotante` animado con `SlideTransition` únicamente cuando el estado es `minimizadoInApp`.

---

## 🤖 2. Configuración en Android (`AndroidManifest.xml`)

En `android/app/src/main/AndroidManifest.xml`, dentro de la etiqueta `<activity android:name=".MainActivity" ...>`:

```xml
<activity
    android:name=".MainActivity"
    android:supportsPictureInPicture="true"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
    ... >
```

Añadir en `pubspec.yaml`:
```yaml
dependencies:
  floating: ^2.0.1
```

---

## ⚡ 3. Directivas de Rendimiento a 144Hz

1. **`RepaintBoundary` Obligatorio:**
   - El widget `MiniReproductorFlotante` DEBE estar envuelto en un `RepaintBoundary` para que el renderizado de la textura del video a 60/144 FPS no fuerce repintar la lista de videos o carpetas que están detrás.
2. **Cero `setState()` en `PantallaPrincipal`:**
   - La aparición, contracción o actualización de tiempo del mini-reproductor se maneja 100% mediante `ValueNotifier` / `ValueListenableBuilder`. Las listas y la navegación de pestañas (`IndexedStack`) no sufren ningún rebuild.
3. **Físicas y Animación Suave:**
   - Animación de deslizamiento de entrada y salida con duración de 250ms y curva `Curves.easeOutCubic`.
