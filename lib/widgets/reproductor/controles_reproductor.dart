import 'package:flutter/material.dart';
import '../../constantes/colores_app.dart';
import '../../modelos/modelo_opciones_reproduccion.dart';
import '../../modelos/modelo_video.dart';

/// Controles minimalistas y limpios con toda la botonera ubicada en la parte inferior (como en la captura).
class ControlesReproductor extends StatelessWidget {
  final String tituloVideo;
  final bool estaReproduciendo;
  final bool estaCargando;
  final bool pantallaBloqueada;
  final int posicionActualMs;
  final int duracionTotalMs;
  final int posicionBufferMs;
  final double velocidadActual;
  final ModoRelacionAspecto aspectoActual;
  final bool esPantallaCompletaHorizontal;

  // Callbacks de interacción
  final VoidCallback alAlternarPlayPause;
  final ValueChanged<double> alCambiarProgreso;
  final ValueChanged<double> alFinalizarCambioProgreso;
  final VoidCallback alRegresar;
  final VoidCallback alAlternarBloqueo;
  final VoidCallback alMostrarModalVelocidad;
  final VoidCallback alMostrarModalAspecto;
  final VoidCallback alMostrarModalPistas;
  final VoidCallback alAlternarOrientacion;
  final VoidCallback alSaltarAdelante;
  final VoidCallback alSaltarAtras;

  const ControlesReproductor({
    super.key,
    required this.tituloVideo,
    required this.estaReproduciendo,
    required this.estaCargando,
    required this.pantallaBloqueada,
    required this.posicionActualMs,
    required this.duracionTotalMs,
    required this.posicionBufferMs,
    required this.velocidadActual,
    required this.aspectoActual,
    required this.esPantallaCompletaHorizontal,
    required this.alAlternarPlayPause,
    required this.alCambiarProgreso,
    required this.alFinalizarCambioProgreso,
    required this.alRegresar,
    required this.alAlternarBloqueo,
    required this.alMostrarModalVelocidad,
    required this.alMostrarModalAspecto,
    required this.alMostrarModalPistas,
    required this.alAlternarOrientacion,
    required this.alSaltarAdelante,
    required this.alSaltarAtras,
  });

  @override
  Widget build(BuildContext context) {
    // Si la pantalla está bloqueada, solo se muestra el botón discreto de desbloqueo en la esquina inferior izquierda
    if (pantallaBloqueada) {
      return Stack(
        children: [
          Positioned(
            bottom: 24,
            left: 24,
            child: SafeArea(
              child: InkWell(
                onTap: alAlternarBloqueo,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white30, width: 1),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: ColoresApp.acentoAmbar,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final ratioBuffer = duracionTotalMs > 0 ? (posicionBufferMs / duracionTotalMs).clamp(0.0, 1.0) : 0.0;
    final valorProgreso = duracionTotalMs > 0 ? (posicionActualMs / duracionTotalMs).clamp(0.0, 1.0) : 0.0;
    final restanteMs = (duracionTotalMs - posicionActualMs).clamp(0, duracionTotalMs);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x99000000),
            Colors.transparent,
            Colors.transparent,
            Color(0xCC000000),
          ],
          stops: [0.0, 0.25, 0.65, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 1. BARRA SUPERIOR LIMPIA (Título y Botón Regresar)
            _construirBarraSuperior(context),

            // Espacio central completamente libre para disfrutar del video
            const Spacer(),

            // 2. PANEL DE CONTROLES INFERIORES APILADOS (TIMELINE + BOTONERA)
            _construirPanelInferior(context, valorProgreso, ratioBuffer, restanteMs),
          ],
        ),
      ),
    );
  }

  /// Barra superior limpia con botón regresar y título del video.
  Widget _construirBarraSuperior(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          InkWell(
            onTap: alRegresar,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Título del video
          Expanded(
            child: Text(
              tituloVideo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
                shadows: [
                  Shadow(color: Colors.black87, blurRadius: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Panel inferior completo con barra de tiempo y todos los controles agrupados abajo.
  Widget _construirPanelInferior(
    BuildContext context,
    double valorProgreso,
    double ratioBuffer,
    int restanteMs,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // FILA 1: TIEMPOS Y BARRA DE PROGRESO CON COLOR NARANJA
          Row(
            children: [
              Text(
                ModeloVideo.formatearTiempo(posicionActualMs),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),

              // Barra de progreso (Slider) con indicador de buffer
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: ratioBuffer,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.4)),
                        minHeight: 3,
                      ),
                    ),
                    SliderTheme(
                      data: const SliderThemeData(
                        trackHeight: 3,
                        activeTrackColor: Color(0xFFFF5722), // Naranja vibrante
                        inactiveTrackColor: Colors.transparent,
                        thumbColor: Color(0xFFFF5722),
                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.5),
                        overlayColor: Color(0x33FF5722),
                        overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
                      ),
                      child: Slider(
                        value: valorProgreso,
                        min: 0.0,
                        max: 1.0,
                        onChanged: alCambiarProgreso,
                        onChangeEnd: alFinalizarCambioProgreso,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Tiempo restante
              Text(
                duracionTotalMs > 0
                    ? '- ${ModeloVideo.formatearTiempo(restanteMs)}'
                    : '00:00',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // FILA 2: BOTONERA DE CONTROLES INFERIORES LIMPIA
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // LADO IZQUIERDO: Subtítulos / Pistas y Bloqueo de pantalla
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.subtitles_outlined, color: Colors.white, size: 22),
                    tooltip: 'Subtítulos / Audio',
                    onPressed: alMostrarModalPistas,
                  ),
                  IconButton(
                    icon: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 22),
                    tooltip: 'Bloquear pantalla',
                    onPressed: alAlternarBloqueo,
                  ),
                ],
              ),

              // CENTRO: BOTÓN PLAY / PAUSE DESTACADO EN CÍRCULO BLANCO
              estaCargando
                  ? const SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5722)),
                      ),
                    )
                  : InkWell(
                      onTap: alAlternarPlayPause,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          color: Colors.black.withValues(alpha: 0.3),
                        ),
                        child: Icon(
                          estaReproduciendo ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),

              // LADO DERECHO: Relación de Aspecto / Pantalla y Menú de opciones (•••)
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.aspect_ratio_rounded, color: Colors.white, size: 22),
                    tooltip: 'Ajuste de pantalla',
                    onPressed: alMostrarModalAspecto,
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 26),
                    color: ColoresApp.fondoTarjeta,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (opcion) {
                      if (opcion == 'velocidad') {
                        alMostrarModalVelocidad();
                      } else if (opcion == 'rotar') {
                        alAlternarOrientacion();
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'velocidad',
                        child: Row(
                          children: [
                            const Icon(Icons.speed_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Text('Velocidad (${velocidadActual}x)'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'rotar',
                        child: Row(
                          children: [
                            Icon(Icons.screen_rotation_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 10),
                            Text('Rotar Orientación'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
