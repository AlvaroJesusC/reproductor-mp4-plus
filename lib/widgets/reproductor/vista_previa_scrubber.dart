import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../constantes/colores_app.dart';
import '../../modelos/modelo_video.dart';

/// Estado reactivo e inmutable de la burbuja de vista previa sobre la barra de progreso.
class EstadoVistaPreviaScrubber {
  final bool visible;
  final double ratio;
  final int posicionMs;
  final int duracionMs;
  final bool motorListo;
  final bool enBusquedaFina;

  const EstadoVistaPreviaScrubber({
    this.visible = false,
    this.ratio = 0.0,
    this.posicionMs = 0,
    this.duracionMs = 0,
    this.motorListo = false,
    this.enBusquedaFina = false,
  });

  EstadoVistaPreviaScrubber copiarCon({
    bool? visible,
    double? ratio,
    int? posicionMs,
    int? duracionMs,
    bool? motorListo,
    bool? enBusquedaFina,
  }) {
    return EstadoVistaPreviaScrubber(
      visible: visible ?? this.visible,
      ratio: ratio ?? this.ratio,
      posicionMs: posicionMs ?? this.posicionMs,
      duracionMs: duracionMs ?? this.duracionMs,
      motorListo: motorListo ?? this.motorListo,
      enBusquedaFina: enBusquedaFina ?? this.enBusquedaFina,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is EstadoVistaPreviaScrubber &&
            other.visible == visible &&
            other.ratio == ratio &&
            other.posicionMs == posicionMs &&
            other.duracionMs == duracionMs &&
            other.motorListo == motorListo &&
            other.enBusquedaFina == enBusquedaFina);
  }

  @override
  int get hashCode => Object.hash(
        visible,
        ratio,
        posicionMs,
        duracionMs,
        motorListo,
        enBusquedaFina,
      );
}

/// Controlador modular para la vista previa en tiempo real al deslizar la barra
/// de progreso (Seekbar Thumbnail Preview + Fine Scrubbing).
///
/// Utiliza un motor secundario ultra-ligero de libmpv (sin audio, sin subtítulos,
/// por software y búsqueda exclusiva por keyframes) para no competir con el
/// decodificador hardware del reproductor principal y mantener 144Hz fluidos.
class ControladorVistaPreviaScrubber {
  static const int _throttleSeekMs = 70;
  static const int _delayPrecalentamientoMs = 600;
  static const double _umbralActivarFinoPx = 38.0;
  static const double _umbralDesactivarFinoPx = 20.0;

  final ValueNotifier<EstadoVistaPreviaScrubber> estado = ValueNotifier(
    const EstadoVistaPreviaScrubber(),
  );
  final ValueNotifier<VideoController?> controladorVideo = ValueNotifier(null);

  Player? _reproductorPreview;
  StreamSubscription<int?>? _subscripcionAncho;
  Timer? _temporizadorPrecalentamiento;
  Timer? _temporizadorSeekFinal;

  String? _rutaVideoActual;
  String? _rutaAbiertaEnMotor;
  bool _inicializandoMotor = false;
  bool _desechado = false;

  // Control de arrastre y búsqueda fina (Fine Scrubbing)
  bool _arrastrando = false;
  double _punteroInicioY = 0.0;
  double _ultimoRatioCrudo = 0.0;
  double _ratioEfectivo = 0.0;
  int _ultimoSeekMsTimestamp = 0;
  int _ultimoObjetivoSeekMs = -1;

  /// Prepara el controlador para un video nuevo tras abrir el reproductor principal.
  /// El calentamiento se difiere brevemente para no sumar latencia al arranque.
  void prepararParaVideo(String rutaVideo, {int duracionInicialMs = 0}) {
    if (_desechado) return;
    _temporizadorPrecalentamiento?.cancel();
    _temporizadorSeekFinal?.cancel();
    _rutaVideoActual = rutaVideo;

    final mismoArchivo = _rutaAbiertaEnMotor == rutaVideo && _reproductorPreview != null;
    estado.value = EstadoVistaPreviaScrubber(
      visible: false,
      duracionMs: duracionInicialMs,
      motorListo: mismoArchivo && estado.value.motorListo,
    );

    if (mismoArchivo) return;

    _temporizadorPrecalentamiento = Timer(
      const Duration(milliseconds: _delayPrecalentamientoMs),
      () {
        if (!_desechado && _rutaVideoActual == rutaVideo) {
          unawaited(_asegurarMotorYAbrir(rutaVideo));
        }
      },
    );
  }

  /// Actualiza la duración conocida si el motor principal la resuelve después.
  void actualizarDuracion(int duracionMs) {
    if (_desechado || duracionMs <= 0) return;
    if (estado.value.duracionMs != duracionMs) {
      estado.value = estado.value.copiarCon(duracionMs: duracionMs);
    }
  }

  /// Registra la coordenada vertical inicial del puntero al tocar la barra.
  void registrarInicioPunteroY(double punteroY) {
    _punteroInicioY = punteroY;
  }

  /// Evalúa el desplazamiento vertical para activar/desactivar búsqueda precisa.
  void alMoverPuntero(double punteroY) {
    if (_desechado || !_arrastrando) return;
    final subida = _punteroInicioY - punteroY;
    final actualFino = estado.value.enBusquedaFina;

    if (!actualFino && subida >= _umbralActivarFinoPx) {
      unawaited(HapticFeedback.selectionClick());
      estado.value = estado.value.copiarCon(enBusquedaFina: true);
    } else if (actualFino && subida <= _umbralDesactivarFinoPx) {
      unawaited(HapticFeedback.selectionClick());
      estado.value = estado.value.copiarCon(enBusquedaFina: false);
    }
  }

  /// Inicia el arrastre de la barra de progreso mostrando la burbuja de vista previa.
  void alIniciarArrastre(double ratioSliderCrudo, int duracionMs) {
    if (_desechado) return;
    _temporizadorPrecalentamiento?.cancel();
    _temporizadorSeekFinal?.cancel();

    _arrastrando = true;
    _ultimoRatioCrudo = ratioSliderCrudo.clamp(0.0, 1.0);
    _ratioEfectivo = _ultimoRatioCrudo;
    _ultimoObjetivoSeekMs = -1;

    final ruta = _rutaVideoActual;
    if (ruta != null && _rutaAbiertaEnMotor != ruta) {
      unawaited(_asegurarMotorYAbrir(ruta));
    }

    final objetivoMs = duracionMs > 0
        ? (_ratioEfectivo * duracionMs).round()
        : 0;
    estado.value = estado.value.copiarCon(
      visible: true,
      ratio: _ratioEfectivo,
      posicionMs: objetivoMs,
      duracionMs: duracionMs,
      enBusquedaFina: false,
    );
    _programarSeekPreview(objetivoMs, inmediato: true);
  }

  /// Actualiza la posición de la vista previa a 144Hz y devuelve el ratio efectivo.
  double alCambiarProgreso(double ratioSliderCrudo, int duracionMs) {
    if (_desechado) return ratioSliderCrudo;
    if (!_arrastrando) {
      alIniciarArrastre(ratioSliderCrudo, duracionMs);
    }

    final ratioClampeado = ratioSliderCrudo.clamp(0.0, 1.0);
    final deltaCrudo = ratioClampeado - _ultimoRatioCrudo;
    _ultimoRatioCrudo = ratioClampeado;

    if (estado.value.enBusquedaFina && duracionMs > 0) {
      final ventanaFinaMs = math.min(duracionMs, 45000);
      final factorSensibilidad = (ventanaFinaMs / duracionMs).clamp(0.05, 0.35);
      _ratioEfectivo = (_ratioEfectivo + deltaCrudo * factorSensibilidad).clamp(
        0.0,
        1.0,
      );
    } else {
      _ratioEfectivo = ratioClampeado;
    }

    final objetivoMs = duracionMs > 0
        ? (_ratioEfectivo * duracionMs).round()
        : 0;

    estado.value = estado.value.copiarCon(
      visible: true,
      ratio: _ratioEfectivo,
      posicionMs: objetivoMs,
      duracionMs: duracionMs,
    );

    _programarSeekPreview(objetivoMs);
    return _ratioEfectivo;
  }

  /// Finaliza el arrastre, oculta la burbuja y retorna el tiempo final en ms.
  int alFinalizarArrastre({
    required double ratioFallback,
    required int duracionMs,
  }) {
    _temporizadorSeekFinal?.cancel();
    final ratioFinal = _arrastrando
        ? _ratioEfectivo
        : ratioFallback.clamp(0.0, 1.0);
    _arrastrando = false;

    if (!_desechado) {
      estado.value = estado.value.copiarCon(
        visible: false,
        enBusquedaFina: false,
      );
    }

    if (duracionMs <= 0) return 0;
    return (ratioFinal * duracionMs).round().clamp(0, duracionMs);
  }

  /// Cancela una interacción interrumpida sin dejar la burbuja flotando.
  void cancelarArrastreSiActivo() {
    if (!_arrastrando || _desechado) return;
    _arrastrando = false;
    _temporizadorSeekFinal?.cancel();
    estado.value = estado.value.copiarCon(
      visible: false,
      enBusquedaFina: false,
    );
  }

  Future<void> _asegurarMotorYAbrir(String rutaVideo) async {
    if (_desechado || _inicializandoMotor) return;
    _inicializandoMotor = true;

    try {
      if (_reproductorPreview == null) {
        final player = Player(
          configuration: const PlayerConfiguration(bufferSize: 2 * 1024 * 1024),
        );
        _reproductorPreview = player;

        try {
          final dynamic platform = player.platform;
          if (platform != null) {
            await platform.setProperty('aid', 'no');
            await platform.setProperty('sid', 'no');
            await platform.setProperty('hr-seek', 'no');
            await platform.setProperty('hwdec', 'no');
            await platform.setProperty('vd-lavc-fast', 'yes');
            await platform.setProperty('vd-lavc-threads', '2');
          }
        } catch (_) {}

        final controller = VideoController(
          player,
          configuration: const VideoControllerConfiguration(
            vo: 'gpu',
            hwdec: 'no',
            enableHardwareAcceleration: false,
          ),
        );

        if (_desechado) {
          await player.dispose();
          return;
        }

        controladorVideo.value = controller;

        _subscripcionAncho = player.stream.width.listen((ancho) {
          if (_desechado) return;
          if ((ancho ?? 0) > 0 && !estado.value.motorListo) {
            estado.value = estado.value.copiarCon(motorListo: true);
          }
        });
      }

      if (_desechado || _rutaVideoActual != rutaVideo) return;

      _rutaAbiertaEnMotor = rutaVideo;
      estado.value = estado.value.copiarCon(motorListo: false);

      await _reproductorPreview!.open(Media(rutaVideo), play: false);
      if (_desechado) return;

      await _reproductorPreview!.pause();
      if (_arrastrando && _ultimoObjetivoSeekMs >= 0) {
        unawaited(
          _reproductorPreview!.seek(
            Duration(milliseconds: _ultimoObjetivoSeekMs),
          ),
        );
      }
    } catch (_) {
      // Fallback silencioso: la burbuja seguirá mostrando el tiempo exacto.
    } finally {
      _inicializandoMotor = false;
      // Si el usuario cambió de video mientras el motor terminaba de abrir, cargar el último.
      if (!_desechado &&
          _rutaVideoActual != null &&
          _rutaVideoActual != _rutaAbiertaEnMotor) {
        unawaited(_asegurarMotorYAbrir(_rutaVideoActual!));
      }
    }
  }

  void _programarSeekPreview(int objetivoMs, {bool inmediato = false}) {
    _ultimoObjetivoSeekMs = objetivoMs;
    final player = _reproductorPreview;
    if (player == null || _rutaAbiertaEnMotor != _rutaVideoActual) return;

    final ahora = DateTime.now().millisecondsSinceEpoch;
    final transcurrido = ahora - _ultimoSeekMsTimestamp;

    if (inmediato || transcurrido >= _throttleSeekMs) {
      _ultimoSeekMsTimestamp = ahora;
      _temporizadorSeekFinal?.cancel();
      unawaited(player.seek(Duration(milliseconds: objetivoMs)));
      return;
    }

    // Si el dedo se detiene entre ticks del throttle, garantiza el fotograma final.
    _temporizadorSeekFinal?.cancel();
    _temporizadorSeekFinal = Timer(
      const Duration(milliseconds: _throttleSeekMs + 15),
      () {
        if (_desechado || !_arrastrando) return;
        final p = _reproductorPreview;
        if (p != null && _ultimoObjetivoSeekMs >= 0) {
          _ultimoSeekMsTimestamp = DateTime.now().millisecondsSinceEpoch;
          unawaited(p.seek(Duration(milliseconds: _ultimoObjetivoSeekMs)));
        }
      },
    );
  }

  /// Libera el decodificador secundario de inmediato (ej. al minimizar a PiP).
  void liberarRecursos() {
    _temporizadorPrecalentamiento?.cancel();
    _temporizadorSeekFinal?.cancel();
    _subscripcionAncho?.cancel();
    _subscripcionAncho = null;
    _arrastrando = false;
    _rutaAbiertaEnMotor = null;

    controladorVideo.value = null;
    final player = _reproductorPreview;
    _reproductorPreview = null;
    if (player != null) {
      unawaited(player.dispose());
    }

    if (!_desechado) {
      estado.value = const EstadoVistaPreviaScrubber();
    }
  }

  /// Cierre definitivo al destruir PantallaReproductor.
  void dispose() {
    if (_desechado) return;
    _desechado = true;
    liberarRecursos();
    estado.dispose();
    controladorVideo.dispose();
  }
}

/// Burbuja flotante 16:9 tipo YouTube que sigue el thumb del scrubber a 144Hz.
class BurbujaVistaPreviaScrubber extends StatelessWidget {
  final ControladorVistaPreviaScrubber controlador;
  final double anchoPista;
  final double paddingHorizontalPista;
  final bool esHorizontal;

  const BurbujaVistaPreviaScrubber({
    super.key,
    required this.controlador,
    required this.anchoPista,
    this.paddingHorizontalPista = 14.0,
    this.esHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final anchoTarjeta = esHorizontal ? 176.0 : 148.0;
    final anchoTotalContenedor = math.max(anchoTarjeta, 224.0);
    final anchoRecorrido = math.max(
      1.0,
      anchoPista - (paddingHorizontalPista * 2),
    );

    return ValueListenableBuilder<EstadoVistaPreviaScrubber>(
      valueListenable: controlador.estado,
      builder: (context, estado, _) {
        final centroThumbX =
            paddingHorizontalPista + (estado.ratio * anchoRecorrido);
        final izquierdaIdeal = centroThumbX - (anchoTotalContenedor / 2);

        // Permite alinear la tarjeta hasta los bordes de la fila completa sin recortar
        final limiteIzquierdo = -36.0;
        final limiteDerecho = math.max(
          limiteIzquierdo,
          anchoPista - anchoTotalContenedor + 40.0,
        );
        final izquierdaClampeada = izquierdaIdeal.clamp(
          limiteIzquierdo,
          limiteDerecho,
        );

        return Positioned(
          bottom: 40,
          left: izquierdaClampeada,
          width: anchoTotalContenedor,
          child: IgnorePointer(
            child: Visibility(
              visible: estado.visible,
              maintainState: true,
              child: RepaintBoundary(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _EtiquetaModoPrecision(
                      enBusquedaFina: estado.enBusquedaFina,
                    ),
                    const SizedBox(height: 6),
                    _TarjetaVideoPreview(
                      ancho: anchoTarjeta,
                      controladorVideoNotifier: controlador.controladorVideo,
                      motorListo: estado.motorListo,
                      enBusquedaFina: estado.enBusquedaFina,
                    ),
                    const SizedBox(height: 6),
                    _PastillaTiempoPreview(
                      tiempoFormateado: ModeloVideo.formatearTiempo(
                        estado.posicionMs,
                      ),
                      enBusquedaFina: estado.enBusquedaFina,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EtiquetaModoPrecision extends StatelessWidget {
  final bool enBusquedaFina;

  const _EtiquetaModoPrecision({required this.enBusquedaFina});

  @override
  Widget build(BuildContext context) {
    if (enBusquedaFina) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
        decoration: BoxDecoration(
          color: ColoresApp.acentoPrimario.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune_rounded, color: Colors.white, size: 12),
            SizedBox(width: 4),
            Text(
              'Búsqueda precisa',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.keyboard_double_arrow_up_rounded,
          color: Colors.white70,
          size: 13,
        ),
        SizedBox(width: 3),
        Flexible(
          child: Text(
            'Desliza arriba para precisión',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
            ),
          ),
        ),
      ],
    );
  }
}

class _TarjetaVideoPreview extends StatelessWidget {
  final double ancho;
  final ValueNotifier<VideoController?> controladorVideoNotifier;
  final bool motorListo;
  final bool enBusquedaFina;

  const _TarjetaVideoPreview({
    required this.ancho,
    required this.controladorVideoNotifier,
    required this.motorListo,
    required this.enBusquedaFina,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ancho,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: enBusquedaFina
              ? ColoresApp.acentoPrimario
              : Colors.white.withValues(alpha: 0.85),
          width: enBusquedaFina ? 2.0 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xAA000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.5),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ValueListenableBuilder<VideoController?>(
            valueListenable: controladorVideoNotifier,
            builder: (context, controller, _) {
              if (controller == null) {
                return const _PlaceholderPreview();
              }

              return Stack(
                fit: StackFit.expand,
                children: [
                  Video(
                    controller: controller,
                    fit: BoxFit.cover,
                    fill: Colors.black,
                    controls: NoVideoControls,
                    wakelock: false,
                    pauseUponEnteringBackgroundMode: false,
                    resumeUponEnteringForegroundMode: false,
                  ),
                  if (!motorListo) const _PlaceholderPreview(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PlaceholderPreview extends StatelessWidget {
  const _PlaceholderPreview();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: ColoresApp.fondoTarjeta,
      child: Center(
        child: Icon(
          Icons.movie_outlined,
          color: Colors.white38,
          size: 24,
        ),
      ),
    );
  }
}

class _PastillaTiempoPreview extends StatelessWidget {
  final String tiempoFormateado;
  final bool enBusquedaFina;

  const _PastillaTiempoPreview({
    required this.tiempoFormateado,
    required this.enBusquedaFina,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: enBusquedaFina
            ? ColoresApp.acentoPrimario
            : const Color(0xD90A0D14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 0.8,
        ),
      ),
      child: Text(
        tiempoFormateado,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
