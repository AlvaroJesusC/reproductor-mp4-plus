---
name: video-pinch-to-zoom
description: Enforces interactive multi-touch pinch-to-zoom (1.0x to 5.0x) and pan translation for reproductormp4's video player canvas without breaking existing single-finger OSD gestures (volume, brightness, seek) or causing raster stutter at 144Hz. Includes OSD zoom percentage pill, quick double-tap reset, and smooth boundary clamping.
---

# Video Pinch-to-Zoom & Pan Interactive Standard

Guía técnica y arquitectónica para implementar zoom libre multitáctil (*Pinch-to-Zoom*) y paneo libre (*Pan*) en el lienzo de video de **`pantalla_reproductor.dart`**, replicando el comportamiento de **MX Player Pro** y **YouTube**.

---

## 🎯 1. Desambiguación de Gestos (1 Dedo vs 2 Dedos)

El mayor desafío técnico es evitar conflictos con los gestos de 1 solo dedo ya existentes:
- **1 dedo en borde izquierdo:** Brillo (vertical).
- **1 dedo en borde derecho:** Volumen (vertical).
- **1 dedo en zona central:** Búsqueda / Seek (horizontal).
- **2 dedos en cualquier zona:** **Pinch-to-Zoom y Paneo libre (Zoom de 1.0x a 5.0x)**.

### Regla de Desambiguación con `onScaleUpdate`:
En Flutter, `GestureDetector` unifica el arrastre y el zoom dentro del evento `onScale`:
1. `details.pointerCount == 1`:
   - Si el zoom actual es `1.0x` (modo normal), se delega al control de **Brillo**, **Volumen** o **Seek** según la posición inicial.
   - Si el zoom actual es `> 1.0x` (el usuario ya hizo zoom), el arrastre de 1 dedo mueve el video (*pan*) para explorar los bordes.
2. `details.pointerCount >= 2`:
   - Se anulan inmediatamente los OSD de volumen, brillo o seek.
   - Se calcula el nuevo factor de escala: `(escalaAnterior * details.scale).clamp(1.0, 5.0)`.
   - Se actualiza la matriz de transformación `Matrix4`.

---

## ⚡ 2. Cero Jank a 144Hz con `ValueNotifier<Matrix4>`

Para no provocar caídas de frames al pellizcar o mover el video a 144 FPS:
- **PROHIBIDO** llamar a `setState()` durante los eventos de `onScaleUpdate`.
- El lienzo de video debe estar aislado en un `ValueListenableBuilder<Matrix4>` o `Transform` reactivo:

```dart
// En el State de PantallaReproductor:
final ValueNotifier<Matrix4> _matrizTransformacionZoom = ValueNotifier(Matrix4.identity());
final ValueNotifier<double> _nivelZoomNotifier = ValueNotifier(1.0);

// En el build() de la pantalla:
ValueListenableBuilder<Matrix4>(
  valueListenable: _matrizTransformacionZoom,
  builder: (context, matriz, child) {
    return Transform(
      transform: matriz,
      alignment: Alignment.center,
      child: child,
    );
  },
  child: RepaintBoundary(
    child: _LienzoVideo(
      controlador: _controladorVideo,
      aspecto: _aspectoActual,
    ),
  ),
)
```

> **Por qué esto vuela a 144 FPS:** La textura de video decodificada por hardware no se reconstruye; la GPU de Android aplica la matriz de transformación en un pase de shader nativo instantáneo.

---

## 🔍 3. Indicador OSD de Zoom (Estilo YouTube)

Cuando el usuario hace zoom, debe aparecer una pastilla flotante centrada en la parte superior:
- Muestra el porcentaje actual con icono: `🔍 145%` o `🔍 220%`.
- Si el zoom vuelve al 100%, muestra: `Ajuste Original (100%)`.
- Fondo con `ColoresApp.fondoOSD` y desvanecimiento tras 1.2 segundos sin interacción.

---

## 🔄 4. Restablecimiento Rápido (Reset)

1. **Doble toque inteligente:**
   - Si el video tiene zoom activo (`_nivelZoom > 1.05`), el doble toque en el centro **restablece el zoom a 1.0x suavemente con animación**, en lugar de adelantar/retroceder 10 segundos.
   - Si el video está en `1.0x`, el doble toque en los laterales mantiene su función original de saltar +/- 10s.
2. **Al cambiar orientación o aspecto:**
   - Al rotar la pantalla o cambiar el modo de aspecto (16:9, rellenar, etc.), la matriz se restablece automáticamente a `Matrix4.identity()`.
3. **Botón en el Panel Lateral:**
   - Añadir una opción en `PanelLateralOpciones`: *"Restablecer Zoom (100%)"*, visible únicamente cuando el zoom está activo.

---

## 🛠️ Archivos a Modificar

1. **`lib/pantallas/pantalla_reproductor.dart`:**
   - Incorporar `_matrizTransformacionZoom` y lógica de cálculo de escala y desplazamiento.
   - Adaptar `GestureDetector` para manejar `onScaleStart`, `onScaleUpdate`, `onScaleEnd`.
   - Envolver el lienzo en `Transform`.
2. **`lib/widgets/reproductor/indicador_gesto_osd.dart`:**
   - Añadir el caso visual para el OSD de Zoom (`Icons.zoom_in_rounded` + porcentaje).
3. **`lib/widgets/reproductor/panel_lateral_opciones.dart`:**
   - Agregar botón rápido de restablecimiento de zoom.
