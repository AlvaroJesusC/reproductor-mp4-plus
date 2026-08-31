import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../constantes/colores_app.dart';
import '../modelos/modelo_opciones_reproduccion.dart';
import '../modelos/modelo_video.dart';
import '../servicios/servicio_preferencias.dart';
import '../widgets/reproductor/controles_reproductor.dart';
import '../widgets/reproductor/indicador_gesto_osd.dart';
import '../widgets/reproductor/modal_aspecto.dart';
import '../widgets/reproductor/modal_pistas_audio_subtitulos.dart';
import '../widgets/reproductor/modal_velocidad.dart';

class _EstadoInterfazReproductor {
  final bool reproduciendo;
  final bool cargando;
  final int posicionMs;
  final int duracionMs;
  final int bufferMs;

  const _EstadoInterfazReproductor({
    this.reproduciendo = false,
    this.cargando = false,
    this.posicionMs = 0,
    this.duracionMs = 0,
    this.bufferMs = 0,
  });

  _EstadoInterfazReproductor copiarCon({
    bool? reproduciendo,
    bool? cargando,
    int? posicionMs,
    int? duracionMs,
    int? bufferMs,
  }) {
    return _EstadoInterfazReproductor(
      reproduciendo: reproduciendo ?? this.reproduciendo,
      cargando: cargando ?? this.cargando,
      posicionMs: posicionMs ?? this.posicionMs,
      duracionMs: duracionMs ?? this.duracionMs,
      bufferMs: bufferMs ?? this.bufferMs,
    );
  }
}

/// Pantalla del reproductor de video con soporte universal y transición suave sin distorsión al salir.
class PantallaReproductor extends StatefulWidget {
  final ModeloVideo video;

  const PantallaReproductor({super.key, required this.video});

  /// Abre la pantalla del reproductor con transición suave de desvanecimiento (evita distorsión de rotación).
  static Future<void> abrir(BuildContext context, ModeloVideo video) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) =>
            PantallaReproductor(video: video),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 180),
      ),
    );
  }

  @override
  State<PantallaReproductor> createState() => _PantallaReproductorState();
}

class _PantallaReproductorState extends State<PantallaReproductor>
    with WidgetsBindingObserver {
  late final Player _reproductor;
  late final VideoController _controladorVideo;
  final List<StreamSubscription> _suscripciones = [];
  final ValueNotifier<_EstadoInterfazReproductor> _estadoInterfaz =
      ValueNotifier(const _EstadoInterfazReproductor());
  final ValueNotifier<int> _versionOSD = ValueNotifier(0);

  bool _reproductorCreado = false;
  bool _estaInicializado = false;
  bool _tieneError = false;
  String _mensajeError = '';
  bool _reintentadoConSoftware = false;
  bool _estaSaliendo = false;

  // Estado de interfaz
  bool _mostrarControles = true;
  bool _pantallaBloqueada = false;
  Timer? _temporizadorOcultarControles;
  bool _esHorizontal = true;

  // Opciones de reproducción
  double _velocidadActual = 1.0;
  ModoRelacionAspecto _aspectoActual = ModoRelacionAspecto.ajustar;

  // Estado de gestos táctiles (OSD)
  TipoGestoOSD _tipoGestoActual = TipoGestoOSD.ninguno;
  double _valorBrilloActual = 0.5;
  double _valorVolumenActual = 0.5;

  // Búsqueda precisa por deslizamiento horizontal (Seek Gesture)
  double _posicionInicialTouchX = 0.0;
  int _posicionInicialSeekMs = 0;
  int _posicionSeekArrastreMs = 0;
  int _diferenciaSeekSegundos = 0;
  Timer? _temporizadorOcultarOSD;

  // Optimización de I/O en disco (Throttling)
  int _ultimoGuardadoTimestamp = 0;
  int _ultimaPosicionMs = 0;
  bool _progresoFinalizadoLimpiado = false;

  // Gestión de volumen
  final VolumeController _controladorVolumen = VolumeController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _configurarModoInmersivo();
    _inicializarBrilloYVolumen();
    _inicializarMotorReproduccion();
  }

  /// Configura pantalla completa inmersiva y rotación horizontal.
  Future<void> _configurarModoInmersivo() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await WakelockPlus.enable();
  }

  /// Inicializa los niveles de brillo y volumen actuales del dispositivo.
  Future<void> _inicializarBrilloYVolumen() async {
    try {
      _valorBrilloActual = await ScreenBrightness.instance.application;
    } catch (_) {
      _valorBrilloActual = 0.5;
    }

    try {
      _valorVolumenActual = await _controladorVolumen.getVolume();
      _controladorVolumen.showSystemUI = false;
    } catch (_) {
      _valorVolumenActual = 0.5;
    }
  }

  /// Inicializa el motor multimedia basado en libmpv con fallback automático.
  Future<void> _inicializarMotorReproduccion() async {
    try {
      final archivo = File(widget.video.ruta);
      if (!await archivo.exists()) {
        setState(() {
          _tieneError = true;
          _mensajeError = 'El archivo de video no existe o no se puede leer.';
        });
        return;
      }

      _reproductor = Player(
        configuration: const PlayerConfiguration(bufferSize: 32 * 1024 * 1024),
      );
      _reproductorCreado = true;

      try {
        final dynamic platform = _reproductor.platform;
        if (platform != null) {
          await platform.setProperty('hwdec', 'auto-safe');
          await platform.setProperty('hwdec-codecs', 'all');
          await platform.setProperty('sub-auto', 'all');
          await platform.setProperty('audio-file-auto', 'fuzzy');
          await platform.setProperty('demuxer-mkv-subtitle-preroll', 'yes');
        }
      } catch (_) {}

      _controladorVideo = VideoController(
        _reproductor,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
          androidAttachSurfaceAfterVideoParameters: true,
        ),
      );

      _velocidadActual = await ServicioPreferencias.obtenerVelocidadPreferida();
      await _reproductor.setRate(_velocidadActual);

      // 1. Escuchar posición
      _suscripciones.add(
        _reproductor.stream.position.listen((pos) {
          if (!mounted || _estaSaliendo) return;
          final posMs = pos.inMilliseconds;
          final durMs = _reproductor.state.duration.inMilliseconds;

          final videoCompletado = _esVideoCompletado(posMs, durMs);
          widget.video.posicionGuardadaMs = videoCompletado ? 0 : posMs;
          widget.video.duracionTotalMs = durMs;
          if (!videoCompletado) {
            _progresoFinalizadoLimpiado = false;
          }

          if (_mostrarControles) {
            if ((posMs - _ultimaPosicionMs).abs() >= 450 ||
                !_reproductor.state.playing) {
              _ultimaPosicionMs = posMs;
              _actualizarEstadoInterfaz(
                posicionMs: posMs,
                duracionMs: durMs,
                bufferMs: _reproductor.state.buffer.inMilliseconds,
              );
            }
          }

          // Throttling de disco cada 5s
          final ahora = DateTime.now().millisecondsSinceEpoch;
          if (ahora - _ultimoGuardadoTimestamp >= 5000 &&
              _reproductor.state.playing) {
            _ultimoGuardadoTimestamp = ahora;
            if (videoCompletado) {
              if (!_progresoFinalizadoLimpiado) {
                _progresoFinalizadoLimpiado = true;
                ServicioPreferencias.borrarProgresoVideo(widget.video.ruta);
              }
            } else {
              ServicioPreferencias.guardarProgresoVideo(
                rutaVideo: widget.video.ruta,
                posicionMs: posMs,
                duracionTotalMs: durMs,
              );
            }
          }
        }),
      );

      // 2. Escuchar estado de reproducción
      _suscripciones.add(
        _reproductor.stream.playing.listen((reproduciendo) {
          if (mounted && !_estaSaliendo) {
            _actualizarEstadoInterfaz(reproduciendo: reproduciendo);
          }
        }),
      );

      // 3. Escuchar buffering
      _suscripciones.add(
        _reproductor.stream.buffering.listen((cargando) {
          if (mounted && !_estaSaliendo) {
            _actualizarEstadoInterfaz(cargando: cargando);
          }
        }),
      );

      // 4. Escuchar duración
      _suscripciones.add(
        _reproductor.stream.duration.listen((dur) {
          if (mounted && dur > Duration.zero && !_estaSaliendo) {
            widget.video.duracionTotalMs = dur.inMilliseconds;
            _actualizarEstadoInterfaz(duracionMs: dur.inMilliseconds);
          }
        }),
      );

      // 5. Escuchar errores del reproductor con auto-fallback
      _suscripciones.add(
        _reproductor.stream.error.listen((error) async {
          if (!mounted || _estaSaliendo) return;

          if (!_reintentadoConSoftware &&
              (error.toLowerCase().contains('codec') ||
                  error.toLowerCase().contains('format') ||
                  error.toLowerCase().contains('open') ||
                  error.toLowerCase().contains('exceeds'))) {
            _reintentadoConSoftware = true;
            try {
              final dynamic platform = _reproductor.platform;
              if (platform != null) {
                await platform.setProperty('hwdec', 'no');
              }
              await _reproductor.open(Media(widget.video.ruta), play: true);
              return;
            } catch (_) {}
          }

          setState(() {
            _tieneError = true;
            _mensajeError = error;
          });
        }),
      );

      // Abrir el medio
      await _reproductor.open(Media(widget.video.ruta), play: false);

      final posicionGuardada = widget.video.posicionGuardadaMs > 0
          ? widget.video.posicionGuardadaMs
          : await ServicioPreferencias.obtenerPosicionGuardada(
              widget.video.ruta,
            );

      if (posicionGuardada > 5000) {
        await _reproductor.seek(Duration(milliseconds: posicionGuardada));
      }

      await _reproductor.play();

      if (!mounted) return;
      _actualizarEstadoInterfaz(
        reproduciendo: _reproductor.state.playing,
        cargando: _reproductor.state.buffering,
        posicionMs: _reproductor.state.position.inMilliseconds,
        duracionMs: _reproductor.state.duration.inMilliseconds,
        bufferMs: _reproductor.state.buffer.inMilliseconds,
      );
      setState(() {
        _estaInicializado = true;
      });

      _reiniciarTemporizadorOcultarControles();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tieneError = true;
        _mensajeError = 'Error al decodificar el video: $e';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _guardarProgresoInmediato();
      if (_estaInicializado && _reproductor.state.playing) {
        _reproductor.pause();
      }
    }
  }

  bool _esVideoCompletado(int posicionMs, int duracionMs) {
    return duracionMs > 0 && posicionMs >= (duracionMs * 0.95);
  }

  Future<void> _guardarProgresoInmediato() async {
    if (!_estaInicializado) return;

    final posMs = _reproductor.state.position.inMilliseconds;
    final durMs = _reproductor.state.duration.inMilliseconds;
    if (_esVideoCompletado(posMs, durMs)) {
      widget.video.posicionGuardadaMs = 0;
      _progresoFinalizadoLimpiado = true;
      await ServicioPreferencias.borrarProgresoVideo(widget.video.ruta);
      return;
    }

    await ServicioPreferencias.guardarProgresoVideo(
      rutaVideo: widget.video.ruta,
      posicionMs: posMs,
      duracionTotalMs: durMs,
    );
  }

  /// Manejo limpio, instantáneo y sin distorsión al salir del reproductor.
  Future<void> _manejarSalida() async {
    if (_estaSaliendo) return;
    _estaSaliendo = true;

    // 1. Pausar y guardar inmediatamente
    if (_estaInicializado) {
      try {
        await _reproductor.pause();
      } catch (_) {}
      await _guardarProgresoInmediato();
    }

    // 2. Restaurar barras y orientación vertical de forma limpia
    try {
      ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {}
    WakelockPlus.disable();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // 3. Regresar limpiamente
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _actualizarEstadoInterfaz({
    bool? reproduciendo,
    bool? cargando,
    int? posicionMs,
    int? duracionMs,
    int? bufferMs,
  }) {
    if (!mounted || _estaSaliendo) return;
    _estadoInterfaz.value = _estadoInterfaz.value.copiarCon(
      reproduciendo: reproduciendo,
      cargando: cargando,
      posicionMs: posicionMs,
      duracionMs: duracionMs,
      bufferMs: bufferMs,
    );
  }

  void _sincronizarEstadoInterfaz() {
    if (!_reproductorCreado) return;
    _actualizarEstadoInterfaz(
      reproduciendo: _reproductor.state.playing,
      cargando: _reproductor.state.buffering,
      posicionMs: _reproductor.state.position.inMilliseconds,
      duracionMs: _reproductor.state.duration.inMilliseconds,
      bufferMs: _reproductor.state.buffer.inMilliseconds,
    );
  }

  void _notificarCambioOSD() {
    if (!mounted || _estaSaliendo) return;
    _versionOSD.value++;
  }

  /// Alterna play y pause.
  void _alternarPlayPause() {
    if (!_estaInicializado || _estaSaliendo) return;
    _reproductor.playOrPause();
    if (!_reproductor.state.playing) {
      _guardarProgresoInmediato();
    }
    _reiniciarTemporizadorOcultarControles();
  }

  /// Salto rápido de +10 segundos con animación visual.
  Future<void> _saltarAdelante() async {
    if (!_estaInicializado || _estaSaliendo) return;
    final nuevaPos = _reproductor.state.position + const Duration(seconds: 10);
    final limite = _reproductor.state.duration;
    final destino = nuevaPos > limite ? limite : nuevaPos;
    await _reproductor.seek(destino);
    _mostrarOSDSeek(10, destino.inMilliseconds);
    _reiniciarTemporizadorOcultarControles();
  }

  /// Salto rápido de -10 segundos.
  Future<void> _saltarAtras() async {
    if (!_estaInicializado || _estaSaliendo) return;
    final nuevaPos = _reproductor.state.position - const Duration(seconds: 10);
    final destino = nuevaPos < Duration.zero ? Duration.zero : nuevaPos;
    await _reproductor.seek(destino);
    _mostrarOSDSeek(-10, destino.inMilliseconds);
    _reiniciarTemporizadorOcultarControles();
  }

  /// Cambia la posición mediante la barra de deslizamiento.
  Future<void> _cambiarProgreso(double ratio) async {
    if (!_estaInicializado || _estaSaliendo) return;
    final duracionMs = _reproductor.state.duration.inMilliseconds;
    final objetivoMs = (ratio * duracionMs).round();
    _posicionSeekArrastreMs = objetivoMs;
    _actualizarEstadoInterfaz(posicionMs: objetivoMs);
  }

  Future<void> _finalizarCambioProgreso(double ratio) async {
    if (!_estaInicializado || _estaSaliendo) return;
    final duracionMs = _reproductor.state.duration.inMilliseconds;
    final objetivoMs = (ratio * duracionMs).round();
    await _reproductor.seek(Duration(milliseconds: objetivoMs));
    _reiniciarTemporizadorOcultarControles();
  }

  /// Temporizador para ocultar automáticamente los controles tras inactividad.
  void _reiniciarTemporizadorOcultarControles() {
    _temporizadorOcultarControles?.cancel();
    if (_mostrarControles && !_pantallaBloqueada && !_estaSaliendo) {
      _temporizadorOcultarControles = Timer(const Duration(seconds: 4), () {
        if (mounted && !_estaSaliendo) {
          setState(() {
            _mostrarControles = false;
          });
        }
      });
    }
  }

  void _alternarVisibilidadControles() {
    if (_estaSaliendo || _pantallaBloqueada) return;
    setState(() {
      _mostrarControles = !_mostrarControles;
    });
    if (_mostrarControles) {
      _sincronizarEstadoInterfaz();
      _reiniciarTemporizadorOcultarControles();
    }
  }

  /// Alterna el modo de orientación horizontal / vertical.
  Future<void> _alternarOrientacion() async {
    _esHorizontal = !_esHorizontal;
    if (_esHorizontal) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
    setState(() {});
  }

  /// Cambia la velocidad de reproducción.
  Future<void> _cambiarVelocidad(double nuevaVelocidad) async {
    if (!_estaInicializado || _estaSaliendo) return;
    await _reproductor.setRate(nuevaVelocidad);
    await ServicioPreferencias.guardarVelocidadPreferida(nuevaVelocidad);
    setState(() {
      _velocidadActual = nuevaVelocidad;
    });
  }

  /// Cambia el modo de aspecto visual del video.
  void _cambiarAspecto(ModoRelacionAspecto nuevoAspecto) {
    setState(() {
      _aspectoActual = nuevoAspecto;
    });
  }

  /// Muestra el modal para cambiar de subtítulos y pistas de audio incrustadas.
  void _mostrarModalPistas() {
    if (!_estaInicializado || _estaSaliendo) return;
    showDialog(
      context: context,
      builder: (_) => ModalPistasAudioSubtitulos(
        pistas: _reproductor.state.tracks,
        pistaAudioActual: _reproductor.state.track.audio,
        pistaSubtituloActual: _reproductor.state.track.subtitle,
        alSeleccionarAudio: (track) => _reproductor.setAudioTrack(track),
        alSeleccionarSubtitulo: (track) => _reproductor.setSubtitleTrack(track),
      ),
    );
  }

  /// Alterna bloqueo de pantalla.
  void _alternarBloqueo() {
    setState(() {
      _pantallaBloqueada = !_pantallaBloqueada;
      _mostrarControles = !_pantallaBloqueada;
    });
    if (!_pantallaBloqueada) {
      _sincronizarEstadoInterfaz();
      _reiniciarTemporizadorOcultarControles();
    }
  }

  // =================== GESTOS TÁCTILES ===================

  void _alIniciarArrastreVertical(
    DragStartDetails details,
    BoxConstraints constraints,
  ) {
    if (_pantallaBloqueada || _estaSaliendo) return;
    _temporizadorOcultarOSD?.cancel();
  }

  void _alActualizarArrastreVertical(
    DragUpdateDetails details,
    BoxConstraints constraints,
  ) {
    if (_pantallaBloqueada || _estaSaliendo) return;
    final anchoPantalla = constraints.maxWidth;
    final esLadoIzquierdo = details.localPosition.dx < (anchoPantalla / 2);
    final deltaSensibilidad = details.primaryDelta != null
        ? -details.primaryDelta! / 200.0
        : 0.0;

    if (esLadoIzquierdo) {
      _valorBrilloActual = (_valorBrilloActual + deltaSensibilidad).clamp(
        0.0,
        1.0,
      );
      try {
        ScreenBrightness.instance.setApplicationScreenBrightness(
          _valorBrilloActual,
        );
      } catch (_) {}
      _tipoGestoActual = TipoGestoOSD.brillo;
      _notificarCambioOSD();
    } else {
      _valorVolumenActual = (_valorVolumenActual + deltaSensibilidad).clamp(
        0.0,
        1.0,
      );
      try {
        _controladorVolumen.setVolume(_valorVolumenActual);
      } catch (_) {}
      _tipoGestoActual = TipoGestoOSD.volumen;
      _notificarCambioOSD();
    }
  }

  void _alFinalizarArrastreVertical(DragEndDetails details) {
    _programarOcultarOSD();
  }

  // ===== BÚSQUEDA FLUIDA POR DESLIZAMIENTO HORIZONTAL =====

  void _alIniciarArrastreHorizontal(DragStartDetails details) {
    if (_pantallaBloqueada || !_estaInicializado || _estaSaliendo) return;
    _temporizadorOcultarOSD?.cancel();
    _posicionInicialTouchX = details.localPosition.dx;
    _posicionInicialSeekMs = _reproductor.state.position.inMilliseconds;
    _diferenciaSeekSegundos = 0;
    _posicionSeekArrastreMs = _posicionInicialSeekMs;
  }

  void _alActualizarArrastreHorizontal(
    DragUpdateDetails details,
    BoxConstraints constraints,
  ) {
    if (_pantallaBloqueada || !_estaInicializado || _estaSaliendo) return;
    final duracionTotalMs = _reproductor.state.duration.inMilliseconds;
    if (duracionTotalMs <= 0) return;

    final deltaX = details.localPosition.dx - _posicionInicialTouchX;
    final factorSegundos = 120.0 / constraints.maxWidth;
    final segundos = (deltaX * factorSegundos).round();

    _diferenciaSeekSegundos = segundos;
    _posicionSeekArrastreMs = (_posicionInicialSeekMs + (segundos * 1000))
        .clamp(0, duracionTotalMs);

    _tipoGestoActual = TipoGestoOSD.posicionTiempo;
    _notificarCambioOSD();
  }

  Future<void> _alFinalizarArrastreHorizontal(DragEndDetails details) async {
    if (_pantallaBloqueada || !_estaInicializado || _estaSaliendo) return;
    await _reproductor.seek(Duration(milliseconds: _posicionSeekArrastreMs));
    _programarOcultarOSD();
    _reiniciarTemporizadorOcultarControles();
  }

  void _mostrarOSDSeek(int seg, int posObjetivoMs) {
    _temporizadorOcultarOSD?.cancel();
    _tipoGestoActual = TipoGestoOSD.posicionTiempo;
    _diferenciaSeekSegundos = seg;
    _posicionSeekArrastreMs = posObjetivoMs;
    _notificarCambioOSD();
    _programarOcultarOSD();
  }

  void _programarOcultarOSD() {
    _temporizadorOcultarOSD?.cancel();
    _temporizadorOcultarOSD = Timer(const Duration(milliseconds: 1400), () {
      if (mounted && !_estaSaliendo) {
        _tipoGestoActual = TipoGestoOSD.ninguno;
        _notificarCambioOSD();
      }
    });
  }

  void _alHacerDobleToque(TapDownDetails details, BoxConstraints constraints) {
    if (_pantallaBloqueada || _estaSaliendo) return;
    final puntoX = details.localPosition.dx;
    if (puntoX > (constraints.maxWidth / 2)) {
      _saltarAdelante();
    } else {
      _saltarAtras();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _temporizadorOcultarControles?.cancel();
    _temporizadorOcultarOSD?.cancel();

    for (final s in _suscripciones) {
      s.cancel();
    }
    _estadoInterfaz.dispose();
    _versionOSD.dispose();

    try {
      ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {}
    WakelockPlus.disable();

    if (_reproductorCreado) {
      _reproductor.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _manejarSalida();
        }
      },
      child: _estaSaliendo
          ? const Scaffold(
              backgroundColor: Colors.black,
              body: SizedBox.expand(),
            )
          : _construirCuerpoReproductor(context),
    );
  }

  Widget _construirCuerpoReproductor(BuildContext context) {
    if (_tieneError) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: ColoresApp.acentoPrimario,
                  size: 56,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No se pudo reproducir el video',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _mensajeError,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ColoresApp.textoSecundario,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColoresApp.acentoPrimario,
                  ),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Regresar',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: _manejarSalida,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _alternarVisibilidadControles,
            onDoubleTapDown: (details) =>
                _alHacerDobleToque(details, constraints),
            onVerticalDragStart: (d) =>
                _alIniciarArrastreVertical(d, constraints),
            onVerticalDragUpdate: (d) =>
                _alActualizarArrastreVertical(d, constraints),
            onVerticalDragEnd: _alFinalizarArrastreVertical,
            onHorizontalDragStart: _alIniciarArrastreHorizontal,
            onHorizontalDragUpdate: (d) =>
                _alActualizarArrastreHorizontal(d, constraints),
            onHorizontalDragEnd: _alFinalizarArrastreHorizontal,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. RENDERIZADO DEL VIDEO NATIVO CON MEDIA_KIT (LIBMPV)
                if (_estaInicializado)
                  RepaintBoundary(child: Center(child: _construirCajaVideo()))
                else
                  const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ColoresApp.acentoPrimario,
                      ),
                    ),
                  ),

                // 2. El OSD se actualiza sin reconstruir la superficie de video.
                ValueListenableBuilder<int>(
                  valueListenable: _versionOSD,
                  builder: (context, _, child) {
                    return RepaintBoundary(
                      child: IndicadorGestoOSD(
                        tipoGesto: _tipoGestoActual,
                        valor: _tipoGestoActual == TipoGestoOSD.brillo
                            ? _valorBrilloActual
                            : _valorVolumenActual,
                        diferenciaSegundos: _diferenciaSeekSegundos,
                        posicionObjetivoMs: _posicionSeekArrastreMs,
                        duracionTotalMs: widget.video.duracionTotalMs,
                      ),
                    );
                  },
                ),

                // 3. Solo los controles reaccionan a posición, buffer y play/pause.
                if ((_mostrarControles || _pantallaBloqueada) &&
                    _estaInicializado)
                  ValueListenableBuilder<_EstadoInterfazReproductor>(
                    valueListenable: _estadoInterfaz,
                    builder: (context, estado, child) {
                      return RepaintBoundary(
                        child: ControlesReproductor(
                          tituloVideo: widget.video.nombreSinExtension,
                          estaReproduciendo: estado.reproduciendo,
                          estaCargando: estado.cargando,
                          pantallaBloqueada: _pantallaBloqueada,
                          posicionActualMs: estado.posicionMs,
                          duracionTotalMs: estado.duracionMs,
                          posicionBufferMs: estado.bufferMs,
                          velocidadActual: _velocidadActual,
                          aspectoActual: _aspectoActual,
                          esPantallaCompletaHorizontal: _esHorizontal,
                          alAlternarPlayPause: _alternarPlayPause,
                          alCambiarProgreso: _cambiarProgreso,
                          alFinalizarCambioProgreso: _finalizarCambioProgreso,
                          alRegresar: _manejarSalida,
                          alAlternarBloqueo: _alternarBloqueo,
                          alMostrarModalVelocidad: () {
                            showDialog(
                              context: context,
                              builder: (_) => ModalVelocidad(
                                velocidadActual: _velocidadActual,
                                alSeleccionarVelocidad: _cambiarVelocidad,
                              ),
                            );
                          },
                          alMostrarModalAspecto: () {
                            showDialog(
                              context: context,
                              builder: (_) => ModalAspecto(
                                aspectoActual: _aspectoActual,
                                alSeleccionarAspecto: _cambiarAspecto,
                              ),
                            );
                          },
                          alMostrarModalPistas: _mostrarModalPistas,
                          alAlternarOrientacion: _alternarOrientacion,
                          alSaltarAdelante: _saltarAdelante,
                          alSaltarAtras: _saltarAtras,
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Construye el widget de video según la relación de aspecto seleccionada.
  Widget _construirCajaVideo() {
    BoxFit fit = BoxFit.contain;

    switch (_aspectoActual) {
      case ModoRelacionAspecto.ajustar:
        fit = BoxFit.contain;
        break;
      case ModoRelacionAspecto.rellenar:
        fit = BoxFit.cover;
        break;
      case ModoRelacionAspecto.dieciseisNueve:
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: Video(
            controller: _controladorVideo,
            fit: BoxFit.fill,
            controls: NoVideoControls,
          ),
        );
      case ModoRelacionAspecto.cuatroTres:
        return AspectRatio(
          aspectRatio: 4 / 3,
          child: Video(
            controller: _controladorVideo,
            fit: BoxFit.fill,
            controls: NoVideoControls,
          ),
        );
      case ModoRelacionAspecto.original:
        fit = BoxFit.none;
        break;
    }

    return Video(
      controller: _controladorVideo,
      fit: fit,
      controls: NoVideoControls,
    );
  }
}
