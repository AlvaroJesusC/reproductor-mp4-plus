import 'package:flutter/material.dart';
import '../../constantes/colores_app.dart';
import '../../modelos/modelo_opciones_reproduccion.dart';
import '../../modelos/modelo_video.dart';
import 'panel_lateral_opciones.dart';

/// Controles cinemáticos, minimalistas y completos con diseño OLED y micro-aislamiento reactivo.
class ControlesReproductor extends StatelessWidget {
  final String tituloVideo;
  final ValueNotifier<EstadoProgresoReproductor> estadoProgreso;
  final ValueNotifier<EstadoReproduccionVideo> estadoReproduccion;
  final bool pantallaBloqueada;
  final double velocidadActual;
  final ModoRelacionAspecto aspectoActual;
  final bool esPantallaCompletaHorizontal;
  final bool esFavorito;
  final bool haySiguiente;
  final bool hayAnterior;
  final int cantidadVideosPlaylist;
  final bool bucleABActivo;

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
  final VoidCallback? alLiberarOrientacion;
  final VoidCallback alSaltarAdelante;
  final VoidCallback alSaltarAtras;
  final VoidCallback? alSiguienteVideo;
  final VoidCallback? alVideoAnterior;
  final VoidCallback? alCapturarPantalla;
  final VoidCallback? alMostrarPlaylist;
  final VoidCallback? alMostrarTemporizadorApagado;
  final VoidCallback? alMostrarSincronizacion;
  final VoidCallback? alAlternarFavorito;
  final VoidCallback? alMarcarPuntoA;
  final VoidCallback? alMarcarPuntoB;
  final VoidCallback? alLimpiarBucle;
  final VoidCallback? alMostrarInfoVideo;

  const ControlesReproductor({
    super.key,
    required this.tituloVideo,
    required this.estadoProgreso,
    required this.estadoReproduccion,
    required this.pantallaBloqueada,
    required this.velocidadActual,
    required this.aspectoActual,
    required this.esPantallaCompletaHorizontal,
    this.esFavorito = false,
    this.haySiguiente = false,
    this.hayAnterior = false,
    this.cantidadVideosPlaylist = 1,
    this.bucleABActivo = false,
    required this.alAlternarPlayPause,
    required this.alCambiarProgreso,
    required this.alFinalizarCambioProgreso,
    required this.alRegresar,
    required this.alAlternarBloqueo,
    required this.alMostrarModalVelocidad,
    required this.alMostrarModalAspecto,
    required this.alMostrarModalPistas,
    required this.alAlternarOrientacion,
    this.alLiberarOrientacion,
    required this.alSaltarAdelante,
    required this.alSaltarAtras,
    this.alSiguienteVideo,
    this.alVideoAnterior,
    this.alCapturarPantalla,
    this.alMostrarPlaylist,
    this.alMostrarTemporizadorApagado,
    this.alMostrarSincronizacion,
    this.alAlternarFavorito,
    this.alMarcarPuntoA,
    this.alMarcarPuntoB,
    this.alLimpiarBucle,
    this.alMostrarInfoVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xB3000000),
            Colors.transparent,
            Colors.transparent,
            Color(0xCC000000),
          ],
          stops: [0.0, 0.25, 0.65, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 1. BARRA SUPERIOR (Regresar, Título, Favorito, Screenshot, Sleep Timer)
            RepaintBoundary(child: _construirBarraSuperior(context)),

            // 2. CONTROLES CENTRALES DESTACADOS (Anterior, -10s, Play/Pause 60px, +10s, Siguiente)
            Expanded(
              child: RepaintBoundary(child: _construirControlesCentrales()),
            ),

            // 3. PANEL DE CONTROLES INFERIORES (TIMELINE + BOTONERA LIMPIA)
            RepaintBoundary(child: _construirPanelInferior(context)),
          ],
        ),
      ),
    );
  }

  /// Barra superior con botones rápidos y título del video.
  Widget _construirBarraSuperior(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          InkWell(
            onTap: alRegresar,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(7),
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
          const SizedBox(width: 12),

          // Título del video
          Expanded(
            child: Text(
              tituloVideo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
                shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
              ),
            ),
          ),

          // Botón rápido Favorito
          if (alAlternarFavorito != null)
            IconButton(
              icon: Icon(
                esFavorito ? Icons.star_rounded : Icons.star_outline_rounded,
                color: esFavorito ? const Color(0xFFFFD700) : Colors.white70,
                size: 22,
              ),
              tooltip: esFavorito
                  ? 'Quitar de favoritos'
                  : 'Añadir a favoritos',
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              onPressed: alAlternarFavorito,
            ),

          // Botón rápido Captura HD (Screenshot)
          if (alCapturarPantalla != null) ...[
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(
                Icons.camera_alt_outlined,
                color: Colors.white70,
                size: 21,
              ),
              tooltip: 'Capturar fotograma HD',
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              onPressed: alCapturarPantalla,
            ),
          ],

          // Botón rápido Sleep Timer
          if (alMostrarTemporizadorApagado != null) ...[
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(
                Icons.bedtime_outlined,
                color: Colors.white70,
                size: 21,
              ),
              tooltip: 'Temporizador de apagado',
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              onPressed: alMostrarTemporizadorApagado,
            ),
          ],
        ],
      ),
    );
  }

  /// Hub central de reproducción con Play/Pausa grande y saltos de 10s y videos.
  Widget _construirControlesCentrales() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Video anterior
          if (alVideoAnterior != null) ...[
            IconButton(
              icon: Icon(
                Icons.skip_previous_rounded,
                color: hayAnterior ? Colors.white : Colors.white24,
                size: 32,
              ),
              tooltip: 'Video anterior',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              onPressed: hayAnterior ? alVideoAnterior : null,
            ),
            const SizedBox(width: 8),
          ],

          // -10 segundos
          IconButton(
            icon: const Icon(
              Icons.replay_10_rounded,
              color: Colors.white,
              size: 34,
            ),
            tooltip: 'Retroceder 10s',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            onPressed: alSaltarAtras,
          ),
          const SizedBox(width: 16),

          // Play / Pause central destacado
          _BotonPlayPauseAislado(
            estadoReproduccion: estadoReproduccion,
            alAlternarPlayPause: alAlternarPlayPause,
            tamano: 60,
          ),
          const SizedBox(width: 16),

          // +10 segundos
          IconButton(
            icon: const Icon(
              Icons.forward_10_rounded,
              color: Colors.white,
              size: 34,
            ),
            tooltip: 'Adelantar 10s',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            onPressed: alSaltarAdelante,
          ),

          // Siguiente video
          if (alSiguienteVideo != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.skip_next_rounded,
                color: haySiguiente ? Colors.white : Colors.white24,
                size: 32,
              ),
              tooltip: 'Siguiente video',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              onPressed: haySiguiente ? alSiguienteVideo : null,
            ),
          ],
        ],
      ),
    );
  }

  /// Panel inferior completo con barra de tiempo y todos los controles agrupados abajo.
  Widget _construirPanelInferior(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // FILA 1: TIEMPOS Y BARRA DE PROGRESO (Aislado reactivamente)
          _BarraProgresoAislada(
            estadoProgreso: estadoProgreso,
            alCambiarProgreso: alCambiarProgreso,
            alFinalizarCambioProgreso: alFinalizarCambioProgreso,
          ),

          const SizedBox(height: 4),

          // FILA 2: BOTONERA DE CONTROLES INFERIORES LIMPIA
          _construirFilaBotonera(context),
        ],
      ),
    );
  }

  Widget _construirFilaBotonera(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // LADO IZQUIERDO: Subtítulos, Playlist y Bloqueo
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.subtitles_outlined,
                color: Colors.white,
                size: 22,
              ),
              tooltip: 'Subtítulos / Audio',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              onPressed: alMostrarModalPistas,
            ),
            if (alMostrarPlaylist != null) ...[
              const SizedBox(width: 12),
              IconButton(
                icon: Badge(
                  isLabelVisible: cantidadVideosPlaylist > 1,
                  label: Text('$cantidadVideosPlaylist'),
                  backgroundColor: ColoresApp.acentoPrimario,
                  child: const Icon(
                    Icons.playlist_play_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                tooltip: 'Lista de videos / Episodios',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                onPressed: alMostrarPlaylist,
              ),
            ],
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(
                Icons.lock_outline_rounded,
                color: Colors.white,
                size: 21,
              ),
              tooltip: 'Bloquear pantalla',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              onPressed: alAlternarBloqueo,
            ),
          ],
        ),

        // LADO DERECHO: Aspecto, Pantalla Completa y Menú Más Opciones (•••)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.aspect_ratio_rounded,
                color: Colors.white,
                size: 22,
              ),
              tooltip: 'Ajuste de pantalla',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              onPressed: alMostrarModalAspecto,
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: Icon(
                esPantallaCompletaHorizontal
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                color: Colors.white,
                size: 25,
              ),
              tooltip: esPantallaCompletaHorizontal
                  ? 'Modo vertical'
                  : 'Pantalla completa',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              onPressed: alAlternarOrientacion,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: Colors.white,
                size: 24,
              ),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              tooltip: 'Más opciones',
              onPressed: () {
                PanelLateralOpciones.mostrar(
                  context,
                  velocidadActual: velocidadActual,
                  esPantallaCompletaHorizontal: esPantallaCompletaHorizontal,
                  alMostrarModalVelocidad: alMostrarModalVelocidad,
                  alMostrarSincronizacion: alMostrarSincronizacion,
                  alMostrarInfoVideo: alMostrarInfoVideo,
                  alAlternarOrientacion: alAlternarOrientacion,
                  alLiberarOrientacion: alLiberarOrientacion,
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// Widget aislado para la barra de progreso y etiquetas de tiempo.
/// Al estar aislado con su propio ValueListenableBuilder y RepaintBoundary, el avance continuo del tiempo
/// redibuja únicamente este componente, dejando estáticos todos los botones y degradados.
class _BarraProgresoAislada extends StatelessWidget {
  final ValueNotifier<EstadoProgresoReproductor> estadoProgreso;
  final ValueChanged<double> alCambiarProgreso;
  final ValueChanged<double> alFinalizarCambioProgreso;

  const _BarraProgresoAislada({
    required this.estadoProgreso,
    required this.alCambiarProgreso,
    required this.alFinalizarCambioProgreso,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<EstadoProgresoReproductor>(
        valueListenable: estadoProgreso,
        builder: (context, estado, _) {
          final duracionTotalMs = estado.duracionMs;
          final posicionActualMs = estado.posicionMs;
          final posicionBufferMs = estado.bufferMs;

          final ratioBuffer = duracionTotalMs > 0
              ? (posicionBufferMs / duracionTotalMs).clamp(0.0, 1.0)
              : 0.0;
          final valorProgreso = duracionTotalMs > 0
              ? (posicionActualMs / duracionTotalMs).clamp(0.0, 1.0)
              : 0.0;
          final restanteMs = (duracionTotalMs - posicionActualMs).clamp(
            0,
            duracionTotalMs,
          );

          return Row(
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
                    // El Slider reserva el radio del thumb en ambos extremos.
                    // Aplicar el mismo margen evita que la pista gris sobresalga.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.5),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: ratioBuffer,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withValues(alpha: 0.4),
                          ),
                          minHeight: 3,
                        ),
                      ),
                    ),
                    SliderTheme(
                      data: const SliderThemeData(
                        trackHeight: 3,
                        activeTrackColor: Color(0xFFFF5722), // Naranja vibrante
                        inactiveTrackColor: Colors.transparent,
                        thumbColor: Color(0xFFFF5722),
                        thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: 6.5,
                        ),
                        overlayColor: Color(0x33FF5722),
                        overlayShape: RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
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
          );
        },
      ),
    );
  }
}

/// Widget aislado para el botón de Play/Pause y carga de buffer.
/// Solo se redibuja cuando cambia el estado de reproducción o buffering.
class _BotonPlayPauseAislado extends StatelessWidget {
  final ValueNotifier<EstadoReproduccionVideo> estadoReproduccion;
  final VoidCallback alAlternarPlayPause;
  final double tamano;

  const _BotonPlayPauseAislado({
    required this.estadoReproduccion,
    required this.alAlternarPlayPause,
    this.tamano = 58.0,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EstadoReproduccionVideo>(
      valueListenable: estadoReproduccion,
      builder: (context, estado, _) {
        if (estado.cargando) {
          return SizedBox(
            width: tamano,
            height: tamano,
            child: const CircularProgressIndicator(
              strokeWidth: 3.0,
              valueColor: AlwaysStoppedAnimation<Color>(
                ColoresApp.acentoPrimario,
              ),
            ),
          );
        }

        return InkWell(
          onTap: alAlternarPlayPause,
          borderRadius: BorderRadius.circular(tamano / 2),
          child: Container(
            width: tamano,
            height: tamano,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.2),
              color: Colors.black.withValues(alpha: 0.4),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              estado.reproduciendo
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: Colors.white,
              size: tamano * 0.58,
            ),
          ),
        );
      },
    );
  }
}
