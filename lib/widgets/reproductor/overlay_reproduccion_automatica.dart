import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../../constantes/colores_app.dart';
import '../../modelos/modelo_video.dart';
import '../../servicios/servicio_miniaturas_video.dart';

/// Superposición moderna estilo YouTube que aparece al terminar un video si hay
/// otro en la lista de reproducción, mostrando cuenta regresiva de 5 segundos,
/// miniatura de fondo atenuada, información del siguiente capítulo y controles de acción.
class OverlayReproduccionAutomatica extends StatelessWidget {
  final ModeloVideo siguienteVideo;
  final int segundosRestantes;
  final int totalSegundos;
  final bool reproduccionAutomaticaActiva;
  final VoidCallback alReproducirAhora;
  final VoidCallback alCancelar;
  final ValueChanged<bool> alAlternarAutoPlay;

  const OverlayReproduccionAutomatica({
    super.key,
    required this.siguienteVideo,
    required this.segundosRestantes,
    this.totalSegundos = 5,
    required this.reproduccionAutomaticaActiva,
    required this.alReproducirAhora,
    required this.alCancelar,
    required this.alAlternarAutoPlay,
  });

  @override
  Widget build(BuildContext context) {
    final progreso = totalSegundos > 0
        ? (segundosRestantes / totalSegundos).clamp(0.0, 1.0)
        : 0.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Fondo: Miniatura del siguiente video con desenfoque suave
        _construirFondoMiniatura(),

        // 2. Capa oscura de baja opacidad para legibilidad OLED
        Container(color: Colors.black.withValues(alpha: 0.76)),

        // 3. Contenido principal interactivo
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final esHorizontal =
                    constraints.maxWidth > constraints.maxHeight;

                return Column(
                  children: [
                    // Barra superior: Encabezado y Switch de Autoplay
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.queue_play_next_rounded,
                                color: ColoresApp.acentoPrimario,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'A continuación',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Interruptor de reproducción automática
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Reproducción auto.',
                              style: TextStyle(
                                color: reproduccionAutomaticaActiva
                                    ? Colors.white
                                    : Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: reproduccionAutomaticaActiva,
                                activeThumbColor: ColoresApp.acentoPrimario,
                                activeTrackColor: ColoresApp.acentoPrimario
                                    .withValues(alpha: 0.4),
                                inactiveThumbColor: const Color(0xFF8B949E),
                                inactiveTrackColor: const Color(0xFF21262D),
                                onChanged: alAlternarAutoPlay,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Tarjeta central: Contador y vista previa
                    if (esHorizontal)
                      _construirContenidoHorizontal(progreso)
                    else
                      _construirContenidoVertical(progreso),

                    const Spacer(),

                    // Barra inferior de botones: Cancelar y Reproducir ahora
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Botón Cancelar
                        OutlinedButton.icon(
                          onPressed: alCancelar,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.2,
                            ),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.08,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text(
                            'Cancelar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Botón Reproducir ahora
                        ElevatedButton.icon(
                          onPressed: alReproducirAhora,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColoresApp.acentoPrimario,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: const Text(
                            'Reproducir ahora',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Fondo con la miniatura del video y desenfoque cinematográfico
  Widget _construirFondoMiniatura() {
    final enMemoria = ServicioMiniaturasVideo.obtenerMiniaturaEnMemoria(
      siguienteVideo,
    );
    if (enMemoria != null) {
      return ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Image.file(
          File(enMemoria),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: 320,
          cacheHeight: 180,
          filterQuality: FilterQuality.low,
          errorBuilder: (context, error, stackTrace) => _fondoLiso(),
        ),
      );
    }

    return FutureBuilder<String?>(
      future: ServicioMiniaturasVideo.obtenerMiniatura(siguienteVideo),
      builder: (context, snapshot) {
        final ruta = snapshot.data;
        if (ruta == null) return _fondoLiso();
        return ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Image.file(
            File(ruta),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            cacheWidth: 320,
            cacheHeight: 180,
            filterQuality: FilterQuality.low,
            errorBuilder: (context, error, stackTrace) => _fondoLiso(),
          ),
        );
      },
    );
  }

  Widget _fondoLiso() {
    return Container(color: const Color(0xFF0D1117));
  }

  /// Diseño optimizado para pantalla vertical
  Widget _construirContenidoVertical(double progreso) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Indicador circular con contador de segundos
        _construirIndicadorCircular(progreso),
        const SizedBox(height: 16),

        Text(
          'El siguiente video comenzará en $segundosRestantes ${segundosRestantes == 1 ? 'segundo' : 'segundos'}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),

        // Tarjeta de vista previa de miniatura y título
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Miniatura
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 96,
                  height: 54,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _construirMiniaturaPreview(),
                      if (siguienteVideo.duracionTotalMs > 0)
                        Positioned(
                          bottom: 3,
                          right: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              siguienteVideo.duracionTotalLegible,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Datos del siguiente video
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      siguienteVideo.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      siguienteVideo.tamanoLegible,
                      style: const TextStyle(
                        color: Color(0xFF8B949E),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Diseño optimizado para pantalla horizontal (Landscape)
  Widget _construirContenidoHorizontal(double progreso) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 540),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Miniatura con duración
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 128,
              height: 72,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _construirMiniaturaPreview(),
                  if (siguienteVideo.duracionTotalMs > 0)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          siguienteVideo.duracionTotalLegible,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Título y cuenta regresiva
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'El siguiente video comenzará en $segundosRestantes s',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  siguienteVideo.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  siguienteVideo.tamanoLegible,
                  style: const TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Anillo de progreso con segundos en el centro
          _construirIndicadorCircular(progreso),
        ],
      ),
    );
  }

  /// Anillo de cuenta regresiva animado
  Widget _construirIndicadorCircular(double progreso) {
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Fondo del anillo
          SizedBox(
            width: 54,
            height: 54,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withValues(alpha: 0.15),
              ),
            ),
          ),
          // Anillo activo
          SizedBox(
            width: 54,
            height: 54,
            child: CircularProgressIndicator(
              value: progreso,
              strokeWidth: 4,
              strokeCap: StrokeCap.round,
              valueColor: const AlwaysStoppedAnimation<Color>(
                ColoresApp.acentoPrimario,
              ),
            ),
          ),
          // Número de segundos
          Text(
            '$segundosRestantes',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Miniatura frontal nítida dentro de la tarjeta
  Widget _construirMiniaturaPreview() {
    final enMemoria = ServicioMiniaturasVideo.obtenerMiniaturaEnMemoria(
      siguienteVideo,
    );
    if (enMemoria != null) {
      return Image.file(
        File(enMemoria),
        fit: BoxFit.cover,
        cacheWidth: 320,
        cacheHeight: 180,
        filterQuality: FilterQuality.low,
        errorBuilder: (context, error, stackTrace) => _fallbackMiniatura(),
      );
    }

    return FutureBuilder<String?>(
      future: ServicioMiniaturasVideo.obtenerMiniatura(siguienteVideo),
      builder: (context, snapshot) {
        final ruta = snapshot.data;
        if (ruta == null) return _fallbackMiniatura();
        return Image.file(
          File(ruta),
          fit: BoxFit.cover,
          cacheWidth: 320,
          cacheHeight: 180,
          filterQuality: FilterQuality.low,
          errorBuilder: (context, error, stackTrace) => _fallbackMiniatura(),
        );
      },
    );
  }

  Widget _fallbackMiniatura() {
    return Container(
      color: const Color(0xFF21262D),
      child: const Center(
        child: Icon(Icons.movie_rounded, color: Color(0xFF8B949E), size: 26),
      ),
    );
  }
}
