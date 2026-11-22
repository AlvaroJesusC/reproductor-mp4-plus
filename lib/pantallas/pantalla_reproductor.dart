import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../constantes/colores_app.dart';
import '../modelos/modelo_capitulo_video.dart';
import '../modelos/modelo_opciones_reproduccion.dart';
import '../modelos/modelo_orden_videos.dart';
import '../modelos/modelo_video.dart';
import '../servicios/logica_reanudacion_video.dart';
import '../servicios/servicio_almacenamiento_video.dart';
import '../servicios/servicio_duracion_video.dart';
import '../servicios/servicio_preferencias.dart';
import '../widgets/dialogo_informacion_video.dart';
import '../widgets/reproductor/boton_saltar_capitulo.dart';
import '../widgets/reproductor/controles_reproductor.dart';
import '../widgets/reproductor/hoja_playlist_reproductor.dart';
import '../widgets/reproductor/indicador_gesto_osd.dart';
import '../widgets/reproductor/modal_aspecto.dart';
import '../widgets/reproductor/modal_capitulos.dart';
import '../widgets/reproductor/modal_pistas_audio_subtitulos.dart';
import '../widgets/reproductor/modal_sincronizacion_pistas.dart';
import '../widgets/reproductor/modal_temporizador_apagado.dart';
import '../widgets/reproductor/modal_velocidad.dart';
import '../modulos/pip/gestor_pip_global.dart';
import '../modulos/pip/servicio_pip_nativo.dart';
import '../widgets/reproductor/overlay_reproduccion_automatica.dart';
import '../widgets/reproductor/vista_previa_scrubber.dart';

/// Pantalla del reproductor de video con soporte universal y transición suave sin distorsión al salir.
class PantallaReproductor extends StatefulWidget {
  final ModeloVideo video;
  final List<ModeloVideo>? listaReproduccion;
  final int? indiceInicial;
  final Player? reproductorExistente;
  final VideoController? controladorExistente;

  const PantallaReproductor({
    super.key,
    required this.video,
    this.listaReproduccion,
    this.indiceInicial,
    this.reproductorExistente,
    this.controladorExistente,
  });

  /// Future del último guardado de progreso o completado en SharedPreferences al salir
  static Future<void>? ultimoGuardadoFuture;

  /// Abre el reproductor y restaura la interfaz después de revelar la biblioteca.
  static Future<void> abrir(
    BuildContext context,
    ModeloVideo video, {
    List<ModeloVideo>? listaReproduccion,
    int? indiceInicial,
    Player? reproductorExistente,
    VideoController? controladorExistente,
  }) async {
    // Si el PiP estaba activo con otro video, cerramos la sesión previa
    if (GestorPipGlobal.instancia.estaActivo &&
        GestorPipGlobal.instancia.videoActual?.ruta != video.ruta) {
      await GestorPipGlobal.instancia.cerrar();
      if (!context.mounted) return;
    }

    // Reutilizar el reproductor existente del PiP si no se especificó explícitamente
    Player? rep = reproductorExistente;
    VideoController? ctrl = controladorExistente;
    if (rep == null &&
        GestorPipGlobal.instancia.estaActivo &&
        GestorPipGlobal.instancia.videoActual?.ruta == video.ruta) {
      rep = GestorPipGlobal.instancia.reproductor;
      ctrl = GestorPipGlobal.instancia.controladorVideo;
    }

    await Navigator.of(context).push<void>(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) =>
            PantallaReproductor(
              video: video,
              listaReproduccion: listaReproduccion,
              indiceInicial: indiceInicial,
              reproductorExistente: rep,
              controladorExistente: ctrl,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 180),
        // Al regresar no se mezcla la superficie nativa con la biblioteca.
        reverseTransitionDuration: Duration.zero,
      ),
    );

    // Esperar a que el guardado en SharedPreferences finalice antes de devolver el control a la biblioteca
    if (ultimoGuardadoFuture != null) {
      try {
        await ultimoGuardadoFuture;
      } catch (_) {}
      ultimoGuardadoFuture = null;
    }

    if (!context.mounted) return;
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));

    // El primer frame pertenece completamente a la biblioteca. Solo después se
    // solicita el giro para que sea ella, y no el reproductor, quien se adapte.
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) return;
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  State<PantallaReproductor> createState() => _PantallaReproductorState();
}

/// Modos de gesto para la desambiguación táctil entre 1 dedo y 2 dedos.
enum _ModoGestoTactil {
  ninguno,
  indeterminado,
  brillo,
  volumen,
  seek,
  panConUnDedo,
  zoomYPaneoMultitactil,
  minimizarDeslizando,
}

class _PantallaReproductorState extends State<PantallaReproductor>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late final Player _reproductor;
  late final VideoController _controladorVideo;
  final List<StreamSubscription> _suscripciones = [];
  final ValueNotifier<EstadoProgresoReproductor> _estadoProgreso =
      ValueNotifier(const EstadoProgresoReproductor());
  final ValueNotifier<EstadoReproduccionVideo> _estadoReproduccion =
      ValueNotifier(const EstadoReproduccionVideo());
  final ValueNotifier<int> _segundosRestantesAutoplayNotifier = ValueNotifier(
    5,
  );
  final ValueNotifier<int> _versionOSD = ValueNotifier(0);
  final ValueNotifier<List<CapituloVideo>> _capitulosNotifier = ValueNotifier(
    const [],
  );
  final ValueNotifier<CapituloSaltarActivo?> _capituloSaltarNotifier =
      ValueNotifier(null);
  bool _capitulosConsultadosTrasDuracion = false;

  /// Control reactivo de la opacidad del filtro de atenuación nocturna (sub-cero).
  final ValueNotifier<double> _opacidadFiltroNoche = ValueNotifier(0.0);

  /// Controlador modular para vista previa en tiempo real al arrastrar el scrubber.
  final ControladorVistaPreviaScrubber _controladorVistaPrevia =
      ControladorVistaPreviaScrubber();

  /// Desplazamiento cinemático vertical para minimizar al mini-reproductor estilo YouTube
  final ValueNotifier<double> _offsetDeslizamientoMinimizar = ValueNotifier(0.0);
  AnimationController? _controladorAnimacionMinimizar;

  // Video actual y playlist
  late ModeloVideo _videoActual;
  late List<ModeloVideo> _playlist;
  late int _indiceActual;

  bool _reproductorCreado = false;
  bool _reproductorCedidoAlPip = false;
  bool _estaInicializado = false;
  bool _tieneError = false;
  String _mensajeError = '';
  bool _reintentadoConSoftware = false;
  bool _estaSaliendo = false;
  StreamSubscription<PiPStatus>? _subscripcionPipNativo;
  StreamSubscription<void>? _subscripcionCierrePipNativo;
  Timer? _temporizadorPausaSegundoPlano;

  // Reproducción automática del siguiente video (Autoplay estilo YouTube)
  bool _reproduccionAutomatica = true;
  bool _mostrandoCuentaRegresivaAutoplay = false;
  Timer? _temporizadorAutoplay;
  ModeloVideo? _siguienteVideoAutoplay;

  // Estado de interfaz
  bool _mostrarControles = true;
  bool _pantallaBloqueada = false;
  bool _mostrarBotonDesbloqueo = false;
  Timer? _temporizadorOcultarControles;
  Timer? _temporizadorOcultarBotonDesbloqueo;
  bool _estaEnHorizontal = false;

  // Opciones de reproducción
  double _velocidadActual = 1.0;
  Timer? _temporizadorGuardarVelocidad;
  ModoRelacionAspecto _aspectoActual = ModoRelacionAspecto.ajustar;

  // Velocidad rápida 2x temporal al mantener pulsado (estilo YouTube)
  final ValueNotifier<bool> _velocidadRapida2xActiva = ValueNotifier<bool>(false);
  final ValueNotifier<double> _velocidadRapidaDestino = ValueNotifier<double>(2.0);
  double _velocidadPreviaAlMantener = 1.0;

  // Sincronización y retardo
  double _desfaseSubtitulosSegundos = 0.0;
  double _desfaseAudioSegundos = 0.0;

  // Temporizador de apagado
  Timer? _temporizadorApagadoTimer;
  int? _segundosRestantesApagado;
  bool _apagarAlTerminarVideo = false;

  // Bucle A-B
  int? _buclePuntoA;
  int? _buclePuntoB;

  // Gestos multitáctiles: Pinch-to-Zoom (1.0x a 5.0x) y Paneo libre a 144Hz
  final ValueNotifier<Matrix4> _matrizTransformacionZoom =
      ValueNotifier(Matrix4.identity());
  final ValueNotifier<double> _nivelZoomNotifier = ValueNotifier(1.0);
  Offset _offsetActual = Offset.zero;
  double _escalaBasePellizco = 1.0;
  Offset _offsetBasePellizco = Offset.zero;
  Offset _focalInicial = Offset.zero;
  int _ultimoPointerCount = 0;
  _ModoGestoTactil _modoGestoActivo = _ModoGestoTactil.ninguno;
  AnimationController? _controladorAnimacionResetZoom;

  // Estado de gestos táctiles (OSD)
  TipoGestoOSD _tipoGestoActual = TipoGestoOSD.ninguno;
  // Brillo virtual: 0.0 a 1.0 controla hardware; <0.0 activa atenuación extra por software (Modo Noche)
  double _valorBrilloActual = 0.5;
  double _valorVolumenActual = 0.5;

  // Búsqueda precisa por deslizamiento horizontal (Seek Gesture)
  double _posicionInicialTouchX = 0.0;
  int _posicionInicialSeekMs = 0;
  int _posicionSeekArrastreMs = 0;
  int _diferenciaSeekSegundos = 0;
  String _tituloCapituloOSD = '';
  int _indiceCapituloOSD = 0;
  Timer? _temporizadorOcultarOSD;

  // Fast-Seeking por Keyframes para scrubber y gestos a 144Hz sin micro-congelamientos
  bool _arrastrandoScrubber = false;
  DateTime _ultimoFastSeekTimestamp = DateTime.fromMillisecondsSinceEpoch(0);

  // Optimización de I/O en disco (Throttling) y control de reanudación fiable
  int _ultimoGuardadoTimestamp = 0;
  int _ultimaPosicionMs = 0;
  int _ultimaPosicionValidaMs = 0;
  int _objetivoReanudacionMs = 0;
  int _idCargaVideo = 0;
  bool _progresoFinalizadoLimpiado = false;
  bool _reanudacionAplicada = false;
  bool _usuarioHizoSeekManual = false;
  bool _estabaReproduciendoMotor = false;

  // Gestión de volumen
  final VolumeController _controladorVolumen = VolumeController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _videoActual = widget.video;
    _playlist =
        widget.listaReproduccion != null && widget.listaReproduccion!.isNotEmpty
        ? List<ModeloVideo>.from(widget.listaReproduccion!)
        : [widget.video];
    _indiceActual =
        widget.indiceInicial ??
        _playlist.indexWhere((v) => v.ruta == widget.video.ruta);
    if (_indiceActual < 0) _indiceActual = 0;

    ServicioPreferencias.obtenerReproduccionAutomatica().then((activa) {
      if (mounted) {
        setState(() {
          _reproduccionAutomatica = activa;
        });
      }
    });

    // Escuchar cambios de estado en PiP nativo de Android para ocultar controles o restaurarlos
    _subscripcionPipNativo = ServicioPipNativo.streamEstadoPip.listen((status) {
      if (!mounted) return;
      _temporizadorPausaSegundoPlano?.cancel();
      _temporizadorPausaSegundoPlano = null;

      setState(() {
        if (status == PiPStatus.enabled) {
          _mostrarControles = false;
        } else {
          // Al expandir de PiP al reproductor completo, continuar reproduciendo fluidamente
          _mostrarControles = true;
          _reiniciarTemporizadorOcultarControles();
        }
      });
      _sincronizarModoBarrasSistema();
    });

    _subscripcionCierrePipNativo =
        ServicioPipNativo.streamCierrePip.listen((_) {
      if (!mounted) return;
      if (_estaInicializado && _reproductor.state.playing) {
        _reproductor.pause();
      }
      _guardarProgresoInmediato();
    });

    _configurarModoInmersivo();
    _inicializarBrilloYVolumen();
    _inicializarMotorReproduccion();
  }

  /// Configura pantalla completa inmersiva permitiendo orientación natural.
  Future<void> _configurarModoInmersivo() async {
    _sincronizarModoBarrasSistema();
    // Orientación libre al abrir: el reproductor se adapta a cualquier posición
    // en que se sostenga el teléfono (vertical u horizontal) y rota con los sensores.
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitDown,
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
    _opacidadFiltroNoche.value = 0.0;

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
      // Reutilizar motor y controlador existentes si venimos de expandir el PiP
      if (widget.reproductorExistente != null &&
          widget.controladorExistente != null) {
        _reproductor = widget.reproductorExistente!;
        _controladorVideo = widget.controladorExistente!;
        _reproductorCreado = true;
        _reanudacionAplicada = true;
        _progresoFinalizadoLimpiado = _videoActual.estaCompletado;
        _velocidadActual = _reproductor.state.rate > 0
            ? _reproductor.state.rate
            : 1.0;
        _ultimaPosicionValidaMs = _reproductor.state.position.inMilliseconds > 0
            ? _reproductor.state.position.inMilliseconds
            : _videoActual.posicionGuardadaMs;
        _estabaReproduciendoMotor = _reproductor.state.playing;

        _configurarSuscripcionesMotor();
        _sincronizarEstadoInterfaz();

        GestorPipGlobal.instancia.registrarSesion(
          video: _videoActual,
          reproductor: _reproductor,
          controladorVideo: _controladorVideo,
          playlist: _playlist,
          indiceActual: _indiceActual,
        );
        GestorPipGlobal.instancia.marcarReproductorCompleto();

        if (mounted) {
          setState(() {
            _estaInicializado = true;
          });
        }
        _controladorVistaPrevia.prepararParaVideo(
          _videoActual.ruta,
          duracionInicialMs: _videoActual.duracionTotalMs,
        );
        unawaited(_cargarCapitulosDesdeMetadatos());
        _reiniciarTemporizadorOcultarControles();
        return;
      }

      _reproductor = Player(
        configuration: const PlayerConfiguration(bufferSize: 32 * 1024 * 1024),
      );
      _reproductorCreado = true;

      try {
        final dynamic platform = _reproductor.platform;
        if (platform != null) {
          // Aceleración directa por hardware en GPU (mediacodec en Android)
          if (Platform.isAndroid) {
            await platform.setProperty('hwdec', 'mediacodec');
          } else {
            await platform.setProperty('hwdec', 'auto-safe');
          }
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

      _desfaseSubtitulosSegundos =
          await ServicioPreferencias.obtenerDesfaseSubtitulos();
      _desfaseAudioSegundos = await ServicioPreferencias.obtenerDesfaseAudio();

      await _cargarYReproducirVideo();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tieneError = true;
        _mensajeError = 'Error al inicializar el reproductor: $e';
      });
    }
  }

  /// Configura las escuchas reactivas del reproductor multimedia.
  void _configurarSuscripcionesMotor() {
    for (final s in _suscripciones) {
      s.cancel();
    }
    _suscripciones.clear();

    final idCargaSuscripcion = _idCargaVideo;

    // 1. Escuchar posición
    _suscripciones.add(
      _reproductor.stream.position.listen((pos) {
        if (!mounted ||
            _estaSaliendo ||
            _arrastrandoScrubber ||
            idCargaSuscripcion != _idCargaVideo) {
          return;
        }
        final posMs = pos.inMilliseconds;
        final durMotorMs = _reproductor.state.duration.inMilliseconds;
        final durMs = durMotorMs > 0 ? durMotorMs : _videoActual.duracionTotalMs;

        // Bucle A-B activo
        if (_buclePuntoA != null && _buclePuntoB != null) {
          if (posMs >= _buclePuntoB!) {
            _reproductor.seek(Duration(milliseconds: _buclePuntoA!));
            return;
          }
        }

        // Si aún estamos confirmando la reanudación inicial, detectar si el motor
        // ya aterrizó en el punto objetivo y evitar sobrescribir el progreso con 0.
        if (!_reanudacionAplicada) {
          if (_objetivoReanudacionMs > 0 &&
              LogicaReanudacionVideo.estaReanudacionConfirmada(
                posicionActualMs: posMs,
                objetivoMs: _objetivoReanudacionMs,
              )) {
            _reanudacionAplicada = true;
            _ultimaPosicionValidaMs = posMs;
            _videoActual.posicionGuardadaMs = posMs;
            _videoActual.estaCompletado = false;
            _ultimoGuardadoTimestamp = DateTime.now().millisecondsSinceEpoch;
          } else {
            return;
          }
        }

        if (posMs > 0) {
          _ultimaPosicionValidaMs = posMs;
        }

        final videoCompletado =
            _reproductor.state.completed || _esVideoCompletado(posMs, durMs);
        if (videoCompletado) {
          _videoActual.estaCompletado = true;
          _videoActual.posicionGuardadaMs = 0;
          if (!_progresoFinalizadoLimpiado) {
            _progresoFinalizadoLimpiado = true;
            unawaited(
              ServicioPreferencias.marcarVideoCompletado(
                _videoActual.ruta,
                duracionTotalMs: durMs,
                completado: true,
              ),
            );
          }
        } else {
          // Solo desmarca completado si el usuario rebobina antes del 90% intencionalmente
          if (!_videoActual.estaCompletado ||
              (durMs > 0 &&
                  posMs < durMs * 0.90 &&
                  posMs > 0 &&
                  !_reproductor.state.completed)) {
            _videoActual.estaCompletado = false;
            if (posMs > 0) {
              _videoActual.posicionGuardadaMs = posMs;
            }
            _progresoFinalizadoLimpiado = false;
          }
        }
        if (durMs > 0) {
          _videoActual.duracionTotalMs = durMs;
        }

        if (_mostrarControles) {
          if ((posMs - _ultimaPosicionMs).abs() >= 450 ||
              !_reproductor.state.playing) {
            _ultimaPosicionMs = posMs;
            _actualizarProgreso(
              posicionMs: posMs,
              duracionMs: durMs,
              bufferMs: _reproductor.state.buffer.inMilliseconds,
            );
          }
        }
        _actualizarCapituloSaltar(posMs, durMs);

        // Throttling de disco cada 5s
        final ahora = DateTime.now().millisecondsSinceEpoch;
        if (ahora - _ultimoGuardadoTimestamp >= 5000 &&
            _reproductor.state.playing) {
          _ultimoGuardadoTimestamp = ahora;
          if (videoCompletado || _videoActual.estaCompletado) {
            if (!_progresoFinalizadoLimpiado) {
              _progresoFinalizadoLimpiado = true;
              _videoActual.estaCompletado = true;
              _videoActual.posicionGuardadaMs = 0;
              unawaited(
                ServicioPreferencias.marcarVideoCompletado(
                  _videoActual.ruta,
                  duracionTotalMs: durMs,
                  completado: true,
                ),
              );
            }
          } else if (!_videoActual.estaCompletado &&
              posMs > LogicaReanudacionVideo.umbralMinimoProgresoMs) {
            unawaited(
              ServicioPreferencias.guardarProgresoVideo(
                rutaVideo: _videoActual.ruta,
                posicionMs: posMs,
                duracionTotalMs: durMs,
              ),
            );
          }
        }
      }),
    );

    // 2. Escuchar fin de video y estado de reproducción
    _suscripciones.add(
      _reproductor.stream.completed.listen((completado) async {
        if (!mounted ||
            _estaSaliendo ||
            !completado ||
            idCargaSuscripcion != _idCargaVideo) {
          return;
        }
        if (_velocidadRapida2xActiva.value) {
          _alFinalizarPulsacionLarga();
        }
        final durMotorMs = _reproductor.state.duration.inMilliseconds;
        final durMs = durMotorMs > 0 ? durMotorMs : _videoActual.duracionTotalMs;
        _videoActual.estaCompletado = true;
        _videoActual.posicionGuardadaMs = 0;
        _progresoFinalizadoLimpiado = true;
        await ServicioPreferencias.marcarVideoCompletado(
          _videoActual.ruta,
          duracionTotalMs: durMs,
          completado: true,
        );
        if (!mounted || _estaSaliendo || idCargaSuscripcion != _idCargaVideo) {
          return;
        }
        if (_apagarAlTerminarVideo) {
          _manejarSalida();
          return;
        }
        if (_indiceActual < _playlist.length - 1) {
          if (_reproduccionAutomatica) {
            _iniciarCuentaRegresivaAutoplay();
          } else {
            _actualizarReproduccion(reproduciendo: false);
          }
        }
      }),
    );

    _suscripciones.add(
      _reproductor.stream.playing.listen((reproduciendo) {
        if (!mounted || _estaSaliendo || idCargaSuscripcion != _idCargaVideo) {
          return;
        }
        _actualizarReproduccion(reproduciendo: reproduciendo);
        // Al pausar (botón, foco de audio, auriculares), persistir de inmediato.
        if (_estabaReproduciendoMotor &&
            !reproduciendo &&
            _estaInicializado &&
            _reanudacionAplicada) {
          unawaited(_guardarProgresoInmediato().catchError((_) {}));
        }
        _estabaReproduciendoMotor = reproduciendo;
      }),
    );

    // 3. Escuchar buffering
    _suscripciones.add(
      _reproductor.stream.buffering.listen((cargando) {
        if (mounted && !_estaSaliendo && idCargaSuscripcion == _idCargaVideo) {
          _actualizarReproduccion(cargando: cargando);
        }
      }),
    );

    // 4. Escuchar duración
    _suscripciones.add(
      _reproductor.stream.duration.listen((dur) {
        if (mounted &&
            dur > Duration.zero &&
            !_estaSaliendo &&
            idCargaSuscripcion == _idCargaVideo) {
          ServicioDuracionVideo.registrarDuracionEnMemoria(
            _videoActual,
            dur.inMilliseconds,
          );
          _actualizarProgreso(duracionMs: dur.inMilliseconds);
          _controladorVistaPrevia.actualizarDuracion(dur.inMilliseconds);
          if (!_capitulosConsultadosTrasDuracion &&
              _capitulosNotifier.value.isEmpty) {
            _capitulosConsultadosTrasDuracion = true;
            unawaited(_cargarCapitulosDesdeMetadatos());
          }
        }
      }),
    );

    // 5. Escuchar errores del reproductor con auto-fallback preservando posición
    _suscripciones.add(
      _reproductor.stream.error.listen((error) async {
        if (!mounted || _estaSaliendo || idCargaSuscripcion != _idCargaVideo) {
          return;
        }

        if (!_reintentadoConSoftware &&
            (error.toLowerCase().contains('codec') ||
                error.toLowerCase().contains('format') ||
                error.toLowerCase().contains('open') ||
                error.toLowerCase().contains('exceeds'))) {
          _reintentadoConSoftware = true;
          try {
            final posPreservarMs = _ultimaPosicionValidaMs >
                    LogicaReanudacionVideo.umbralMinimoProgresoMs
                ? _ultimaPosicionValidaMs
                : _objetivoReanudacionMs;
            final dynamic platform = _reproductor.platform;
            if (platform != null) {
              await platform.setProperty('hwdec', 'no');
            }
            final mediaFallback = posPreservarMs >
                    LogicaReanudacionVideo.umbralMinimoProgresoMs
                ? Media(
                    _videoActual.ruta,
                    start: Duration(milliseconds: posPreservarMs),
                  )
                : Media(_videoActual.ruta);
            await _reproductor.open(mediaFallback, play: true);
            if (posPreservarMs >
                    LogicaReanudacionVideo.umbralMinimoProgresoMs &&
                mounted &&
                !_estaSaliendo &&
                idCargaSuscripcion == _idCargaVideo) {
              _reanudacionAplicada = false;
              _objetivoReanudacionMs = posPreservarMs;
              unawaited(
                _verificarReanudacion(posPreservarMs, idCargaSuscripcion),
              );
            }
            return;
          } catch (_) {}
        }

        setState(() {
          _tieneError = true;
          _mensajeError = error;
        });
      }),
    );
  }

  Future<void> _cargarYReproducirVideo() async {
    final idCarga = ++_idCargaVideo;
    _reanudacionAplicada = false;
    _progresoFinalizadoLimpiado = false;
    _objetivoReanudacionMs = 0;
    _ultimaPosicionValidaMs = 0;
    _usuarioHizoSeekManual = false;
    _estabaReproduciendoMotor = false;

    try {
      final archivo = File(_videoActual.ruta);
      if (!await archivo.exists()) {
        if (!mounted || idCarga != _idCargaVideo) return;
        setState(() {
          _tieneError = true;
          _mensajeError = 'El archivo de video no existe o no se puede leer.';
        });
        return;
      }

      // Esperar cualquier guardado pendiente antes de leer el progreso real en disco.
      if (PantallaReproductor.ultimoGuardadoFuture != null) {
        try {
          await PantallaReproductor.ultimoGuardadoFuture;
        } catch (_) {}
      }
      await ServicioPreferencias.esperarEscriturasPendientes();
      if (!mounted || _estaSaliendo || idCarga != _idCargaVideo) return;

      // Aplicar retardos de subtítulos y audio
      try {
        final dynamic platform = _reproductor.platform;
        if (platform != null) {
          if (_desfaseSubtitulosSegundos != 0.0) {
            await platform.setProperty(
              'sub-delay',
              _desfaseSubtitulosSegundos.toStringAsFixed(3),
            );
          }
          if (_desfaseAudioSegundos != 0.0) {
            await platform.setProperty(
              'audio-delay',
              _desfaseAudioSegundos.toStringAsFixed(3),
            );
          }
        }
      } catch (_) {}

      // Fuente única de verdad: leer primero el estado persistido en SharedPreferences
      // para evitar reanudar con copias obsoletas en memoria.
      final estaCompletadoEnDisco = await ServicioPreferencias.esVideoCompletado(
        _videoActual.ruta,
      );
      final posicionDiscoMs = estaCompletadoEnDisco
          ? 0
          : await ServicioPreferencias.obtenerPosicionGuardada(
              _videoActual.ruta,
            );
      final duracionDiscoMs = await ServicioPreferencias.obtenerDuracionGuardada(
        _videoActual.ruta,
      );
      if (!mounted || _estaSaliendo || idCarga != _idCargaVideo) return;

      _videoActual.estaCompletado = estaCompletadoEnDisco;
      if (duracionDiscoMs > 0 && _videoActual.duracionTotalMs <= 0) {
        _videoActual.duracionTotalMs = duracionDiscoMs;
      }
      final duracionConocidaMs = duracionDiscoMs > 0
          ? duracionDiscoMs
          : _videoActual.duracionTotalMs;

      final objetivoInicialMs =
          LogicaReanudacionVideo.calcularObjetivoReanudacionMs(
            posicionDiscoMs: posicionDiscoMs,
            posicionMemoriaMs: _videoActual.posicionGuardadaMs,
            completadoEnDisco: estaCompletadoEnDisco,
            duracionConocidaMs: duracionConocidaMs,
          );
      _objetivoReanudacionMs = objetivoInicialMs;

      if (objetivoInicialMs > 0) {
        _videoActual.posicionGuardadaMs = objetivoInicialMs;
        _actualizarProgreso(
          posicionMs: objetivoInicialMs,
          duracionMs: duracionConocidaMs,
        );
      }

      // Configurar suscripciones reactivas del motor
      _configurarSuscripcionesMotor();

      // Abrir usando `Media.start` nativo de libmpv (hook on_load) para posicionar
      // el demuxer directamente en el minuto guardado sin carreras al iniciar.
      final media = objetivoInicialMs > 0
          ? Media(
              _videoActual.ruta,
              start: Duration(milliseconds: objetivoInicialMs),
            )
          : Media(_videoActual.ruta);

      await _reproductor.open(media, play: false);
      if (!mounted || _estaSaliendo || idCarga != _idCargaVideo) return;

      unawaited(_cargarCapitulosDesdeMetadatos());

      // Cargar subtítulos locales automáticamente si existen
      unawaited(_buscarYCargarSubtitulosLocales());

      final objetivoReanudacionMs = await _aplicarReanudacionInicial(
        objetivoInicialMs,
        idCarga,
      );
      if (!mounted || _estaSaliendo || idCarga != _idCargaVideo) return;

      _objetivoReanudacionMs = objetivoReanudacionMs;
      // Evita que el primer evento del motor escriba 0 sobre el progreso.
      _ultimoGuardadoTimestamp = DateTime.now().millisecondsSinceEpoch;
      _reanudacionAplicada = objetivoReanudacionMs == 0;
      await _reproductor.play();

      if (!mounted || _estaSaliendo || idCarga != _idCargaVideo) return;
      _sincronizarEstadoInterfaz();

      // Registrar sesión en GestorPipGlobal para persistencia en miniplayer
      GestorPipGlobal.instancia.registrarSesion(
        video: _videoActual,
        reproductor: _reproductor,
        controladorVideo: _controladorVideo,
        playlist: _playlist,
        indiceActual: _indiceActual,
      );

      setState(() {
        _estaInicializado = true;
      });
      _controladorVistaPrevia.prepararParaVideo(
        _videoActual.ruta,
        duracionInicialMs: _videoActual.duracionTotalMs,
      );

      if (objetivoReanudacionMs > 0) {
        unawaited(_verificarReanudacion(objetivoReanudacionMs, idCarga));
      }
      _reiniciarTemporizadorOcultarControles();
    } catch (e) {
      if (!mounted || idCarga != _idCargaVideo) return;
      setState(() {
        _tieneError = true;
        _mensajeError = 'Error al decodificar el video: $e';
      });
    }
  }

  Future<int> _aplicarReanudacionInicial(
    int posicionGuardadaMs,
    int idCarga,
  ) async {
    if (posicionGuardadaMs <= LogicaReanudacionVideo.umbralMinimoProgresoMs) {
      return 0;
    }

    var duracion = _reproductor.state.duration;
    if (duracion <= Duration.zero) {
      duracion = await _reproductor.stream.duration
          .firstWhere((valor) => valor > Duration.zero)
          .timeout(
            const Duration(milliseconds: 1500),
            onTimeout: () => Duration.zero,
          );
    }
    if (!mounted || _estaSaliendo || idCarga != _idCargaVideo) return 0;

    final duracionRealMs = duracion.inMilliseconds;
    final objetivoMs = LogicaReanudacionVideo.ajustarObjetivoADuracionReal(
      objetivoMs: posicionGuardadaMs,
      duracionRealMs: duracionRealMs,
    );
    if (objetivoMs <= LogicaReanudacionVideo.umbralMinimoProgresoMs) {
      return 0;
    }

    final posicionActualMs = _reproductor.state.position.inMilliseconds;
    if (!LogicaReanudacionVideo.estaReanudacionConfirmada(
      posicionActualMs: posicionActualMs,
      objetivoMs: objetivoMs,
    )) {
      await _reproductor.seek(Duration(milliseconds: objetivoMs));
    }
    return objetivoMs;
  }

  /// Verifica en varios intentos tras iniciar la reproducción que el motor haya
  /// aterrizado en el punto guardado (cubre decodificadores hardware lentos o
  /// contenedores MKV/MP4 que ignoran el primer seek antes de adjuntar el Surface).
  Future<void> _verificarReanudacion(int objetivoMs, int idCarga) async {
    const intervalosMs = [150, 200, 250, 350, 450, 550, 700];
    var objetivoActual = objetivoMs;

    for (var i = 0; i < intervalosMs.length; i++) {
      await Future<void>.delayed(Duration(milliseconds: intervalosMs[i]));
      if (!mounted ||
          _estaSaliendo ||
          !_reproductorCreado ||
          idCarga != _idCargaVideo ||
          _usuarioHizoSeekManual ||
          _reanudacionAplicada) {
        return;
      }

      final durMs = _reproductor.state.duration.inMilliseconds;
      if (durMs > 0) {
        objetivoActual = LogicaReanudacionVideo.ajustarObjetivoADuracionReal(
          objetivoMs: objetivoMs,
          duracionRealMs: durMs,
        );
        if (objetivoActual <= LogicaReanudacionVideo.umbralMinimoProgresoMs) {
          _reanudacionAplicada = true;
          return;
        }
      }

      final posicionActualMs = _reproductor.state.position.inMilliseconds;
      if (LogicaReanudacionVideo.estaReanudacionConfirmada(
        posicionActualMs: posicionActualMs,
        objetivoMs: objetivoActual,
      )) {
        _reanudacionAplicada = true;
        _ultimaPosicionValidaMs = posicionActualMs;
        _videoActual.posicionGuardadaMs = posicionActualMs;
        _videoActual.estaCompletado = false;
        _ultimoGuardadoTimestamp = DateTime.now().millisecondsSinceEpoch;
        _sincronizarEstadoInterfaz();
        return;
      }

      // Reintentar seek cuando la duración ya está lista o tras el primer intento
      if (durMs > 0 || i >= 1) {
        try {
          await _reproductor.seek(Duration(milliseconds: objetivoActual));
        } catch (_) {}
      }
    }

    if (!mounted ||
        _estaSaliendo ||
        idCarga != _idCargaVideo ||
        _usuarioHizoSeekManual) {
      return;
    }

    final posicionFinalMs = _reproductor.state.position.inMilliseconds;
    _reanudacionAplicada = true;
    if (LogicaReanudacionVideo.estaReanudacionConfirmada(
      posicionActualMs: posicionFinalMs,
      objetivoMs: objetivoActual,
    )) {
      _ultimaPosicionValidaMs = posicionFinalMs;
      _videoActual.posicionGuardadaMs = posicionFinalMs;
    } else {
      _ultimaPosicionValidaMs = objetivoActual;
      _videoActual.posicionGuardadaMs = objetivoActual;
    }
    _ultimoGuardadoTimestamp = DateTime.now().millisecondsSinceEpoch;
    _sincronizarEstadoInterfaz();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _temporizadorPausaSegundoPlano?.cancel();
        _temporizadorPausaSegundoPlano = null;
        break;

      case AppLifecycleState.inactive:
        // IMPORTANTE: Al bajar la barra de notificaciones, abrir ajustes rápidos,
        // panel de volumen o cambiar de app (Recents), Android emite 'inactive'.
        // NUNCA pausar el video aquí, pero sí respaldar el progreso inmediatamente
        // para no perderlo si el sistema mata o cambia de app de golpe.
        unawaited(_guardarProgresoInmediato().catchError((_) {}));
        break;

      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _alFinalizarPulsacionLarga();
        unawaited(_guardarProgresoInmediato().catchError((_) {}));
        // Si no está en PiP, dar una ventana de gracia para permitir la transición a PiP del sistema.
        // Si tras la ventana de gracia sigue en segundo plano y NO está en PiP (ej: pantalla bloqueada),
        // pausar para ahorrar batería y detener el audio.
        _temporizadorPausaSegundoPlano?.cancel();
        if (!ServicioPipNativo.estaEnPip) {
          _temporizadorPausaSegundoPlano =
              Timer(const Duration(milliseconds: 700), () {
            if (!mounted) return;
            if (!ServicioPipNativo.estaEnPip &&
                _estaInicializado &&
                _reproductor.state.playing) {
              unawaited(_guardarProgresoInmediato().catchError((_) {}));
              _reproductor.pause();
            }
          });
        }
        break;

      case AppLifecycleState.detached:
        unawaited(_guardarProgresoInmediato().catchError((_) {}));
        break;
    }
  }

  bool _esVideoCompletado(int posicionMs, int duracionMs) {
    return LogicaReanudacionVideo.esVideoCompletado(
      posicionMs: posicionMs,
      duracionMs: duracionMs,
    );
  }

  Future<void> _guardarProgresoInmediato({int? posicionForzadaMs}) {
    if (!_estaInicializado || !_reproductorCreado) {
      return Future<void>.value();
    }
    if (!_reanudacionAplicada && posicionForzadaMs == null) {
      // Proteger contra sobreescribir con 0 mientras aún no ha aterrizado la reanudación.
      return Future<void>.value();
    }

    // Capturar toda la lectura de estado de forma SINCRÓNICA antes de cualquier await.
    final ruta = _videoActual.ruta;
    final posMs = LogicaReanudacionVideo.resolverPosicionParaGuardar(
      posicionMotorMs: _reproductor.state.position.inMilliseconds,
      ultimaPosicionValidaMs: _ultimaPosicionValidaMs,
      posicionForzadaMs: posicionForzadaMs,
    );
    final durMotorMs = _reproductor.state.duration.inMilliseconds;
    final durMs = durMotorMs > 0 ? durMotorMs : _videoActual.duracionTotalMs;
    final esCompletado = posicionForzadaMs == null &&
        (_videoActual.estaCompletado ||
            _reproductor.state.completed ||
            _esVideoCompletado(posMs, durMs));

    if (esCompletado) {
      _videoActual.posicionGuardadaMs = 0;
      _videoActual.estaCompletado = true;
      if (durMs > 0) _videoActual.duracionTotalMs = durMs;
      _progresoFinalizadoLimpiado = true;
      return ServicioPreferencias.marcarVideoCompletado(
        ruta,
        duracionTotalMs: durMs,
        completado: true,
      );
    }

    if (posMs > LogicaReanudacionVideo.umbralMinimoProgresoMs) {
      _ultimaPosicionValidaMs = posMs;
      _videoActual.posicionGuardadaMs = posMs;
      if (durMs > 0) _videoActual.duracionTotalMs = durMs;
      _videoActual.estaCompletado = false;
      _progresoFinalizadoLimpiado = false;
      return ServicioPreferencias.guardarProgresoVideo(
        rutaVideo: ruta,
        posicionMs: posMs,
        duracionTotalMs: durMs,
      );
    }

    if (durMs > 0) {
      _videoActual.duracionTotalMs = durMs;
      return ServicioPreferencias.guardarDuracionVideo(ruta, durMs);
    }

    return Future<void>.value();
  }

  /// Regresa inmediatamente y deja que la biblioteca absorba la rotación.
  void _manejarSalida() {
    if (_estaSaliendo) return;
    _estaSaliendo = true;
    _idCargaVideo++;
    _cancelarCuentaRegresivaAutoplay();
    _controladorVistaPrevia.liberarRecursos();

    // IMPORTANTE: Capturar y persistir la posición ANTES de limpiar la sesión PiP
    // o disponer el reproductor, evitando leer posición 0 de un motor ya liberado.
    if (_estaInicializado) {
      PantallaReproductor.ultimoGuardadoFuture = _guardarProgresoInmediato();
    }

    // Limpiar la sesión global de PiP SIN disponer el motor (lo liberará dispose()).
    unawaited(
      GestorPipGlobal.instancia.cerrar(
        guardarProgreso: false,
        disponerReproductor: false,
      ),
    );

    try {
      unawaited(ScreenBrightness.instance.resetApplicationScreenBrightness());
    } catch (_) {}
    unawaited(WakelockPlus.disable());
    unawaited(
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
    );
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      ),
    );

    // Cerrar en este mismo frame. `abrir` restaurará barras y orientación
    // después de que la biblioteca vuelva a estar completamente visible.
    Navigator.of(context).pop();
  }

  /// Minimiza el reproductor al mini-reproductor in-app manteniendo la reproducción continua sin cortes.
  void _minimizarAPip() {
    if (_estaSaliendo) return;
    if (!_estaInicializado || _tieneError) {
      _manejarSalida();
      return;
    }

    _estaSaliendo = true;
    _idCargaVideo++;
    _cancelarCuentaRegresivaAutoplay();
    _controladorVistaPrevia.liberarRecursos();
    PantallaReproductor.ultimoGuardadoFuture = _guardarProgresoInmediato();

    try {
      unawaited(ScreenBrightness.instance.resetApplicationScreenBrightness());
    } catch (_) {}
    unawaited(WakelockPlus.disable());
    unawaited(
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
    );
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      ),
    );

    // Registrar y ceder el reproductor al gestor global sin destruirlo
    GestorPipGlobal.instancia.registrarSesion(
      video: _videoActual,
      reproductor: _reproductor,
      controladorVideo: _controladorVideo,
      playlist: _playlist,
      indiceActual: _indiceActual,
    );
    GestorPipGlobal.instancia.minimizar();
    _reproductorCedidoAlPip = true;

    Navigator.of(context).pop();
  }

  void _actualizarProgreso({int? posicionMs, int? duracionMs, int? bufferMs}) {
    if (!mounted || _estaSaliendo) return;
    _estadoProgreso.value = _estadoProgreso.value.copiarCon(
      posicionMs: posicionMs,
      duracionMs: duracionMs,
      bufferMs: bufferMs,
    );
  }

  void _actualizarReproduccion({bool? reproduciendo, bool? cargando}) {
    if (!mounted || _estaSaliendo) return;
    _estadoReproduccion.value = _estadoReproduccion.value.copiarCon(
      reproduciendo: reproduciendo,
      cargando: cargando,
    );
  }

  void _sincronizarEstadoInterfaz() {
    if (!_reproductorCreado) return;
    _actualizarReproduccion(
      reproduciendo: _reproductor.state.playing,
      cargando: _reproductor.state.buffering,
    );
    _actualizarProgreso(
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
    final estabaReproduciendo = _reproductor.state.playing;
    final estabaCompletado = _reproductor.state.completed;

    if (estabaCompletado) {
      // Reabrir sin `start` para que repetir un video completado inicie siempre desde 00:00.
      _usuarioHizoSeekManual = true;
      _reanudacionAplicada = true;
      _objetivoReanudacionMs = 0;
      _ultimaPosicionValidaMs = 0;
      _progresoFinalizadoLimpiado = false;
      _videoActual.estaCompletado = false;
      _videoActual.posicionGuardadaMs = 0;
      unawaited(
        _reproductor.open(Media(_videoActual.ruta), play: true).catchError((_) {}),
      );
      _reiniciarTemporizadorOcultarControles();
      return;
    }

    if (estabaReproduciendo) {
      unawaited(_guardarProgresoInmediato().catchError((_) {}));
    }
    unawaited(_reproductor.playOrPause().catchError((_) {}));
    _reiniciarTemporizadorOcultarControles();
  }

  void _registrarSeekManualYGuardar(int destinoMs) {
    _usuarioHizoSeekManual = true;
    _reanudacionAplicada = true;
    _ultimaPosicionValidaMs = destinoMs;
    _ultimoGuardadoTimestamp = DateTime.now().millisecondsSinceEpoch;
    if (destinoMs > LogicaReanudacionVideo.umbralMinimoProgresoMs) {
      unawaited(
        _guardarProgresoInmediato(posicionForzadaMs: destinoMs)
            .catchError((_) {}),
      );
    }
  }

  /// Salto rápido de +10 segundos con animación visual.
  Future<void> _saltarAdelante() async {
    if (!_estaInicializado || _estaSaliendo) return;
    final nuevaPos = _reproductor.state.position + const Duration(seconds: 10);
    final limite = _reproductor.state.duration;
    final destino = nuevaPos > limite ? limite : nuevaPos;
    await _reproductor.seek(destino);
    _registrarSeekManualYGuardar(destino.inMilliseconds);
    _mostrarOSDSeek(10, destino.inMilliseconds);
    _reiniciarTemporizadorOcultarControles();
  }

  /// Salto rápido de -10 segundos.
  Future<void> _saltarAtras() async {
    if (!_estaInicializado || _estaSaliendo) return;
    final nuevaPos = _reproductor.state.position - const Duration(seconds: 10);
    final destino = nuevaPos < Duration.zero ? Duration.zero : nuevaPos;
    await _reproductor.seek(destino);
    _registrarSeekManualYGuardar(destino.inMilliseconds);
    _mostrarOSDSeek(-10, destino.inMilliseconds);
    _reiniciarTemporizadorOcultarControles();
  }

  /// Ejecuta una búsqueda rápida no bloqueante por fotogramas clave (Keyframes)
  /// con limitador de frecuencia para no saturar el canal C++ / libmpv durante el arrastre a 144Hz.
  void _ejecutarFastSeek(Duration posicion) {
    if (!_estaInicializado || _estaSaliendo) return;
    final ahora = DateTime.now();
    if (ahora.difference(_ultimoFastSeekTimestamp).inMilliseconds >= 60) {
      _ultimoFastSeekTimestamp = ahora;
      // Seek asíncrono no bloqueante: libmpv busca al keyframe más cercano de inmediato
      unawaited(_reproductor.seek(posicion));
    }
  }

  void _iniciarCambioProgreso(double ratio) {
    if (!_estaInicializado || _estaSaliendo) return;
    _arrastrandoScrubber = true;
    _temporizadorOcultarControles?.cancel();
    final duracionMs = _reproductor.state.duration.inMilliseconds;
    _controladorVistaPrevia.alIniciarArrastre(ratio, duracionMs);
  }

  /// Actualiza la burbuja de vista previa en tiempo real sin interrumpir el video principal.
  void _cambiarProgreso(double ratio) {
    if (!_estaInicializado || _estaSaliendo) return;
    _arrastrandoScrubber = true;
    final duracionMs = _reproductor.state.duration.inMilliseconds;
    final ratioEfectivo = _controladorVistaPrevia.alCambiarProgreso(
      ratio,
      duracionMs,
    );
    final objetivoMs = (ratioEfectivo * duracionMs).round();
    _posicionSeekArrastreMs = objetivoMs;
    _actualizarProgreso(posicionMs: objetivoMs);
  }

  Future<void> _finalizarCambioProgreso(double ratio) async {
    if (!_estaInicializado || _estaSaliendo) return;
    _arrastrandoScrubber = false;
    final duracionMs = _reproductor.state.duration.inMilliseconds;
    final objetivoMs = _controladorVistaPrevia.alFinalizarArrastre(
      ratioFallback: ratio,
      duracionMs: duracionMs,
    );
    await _reproductor.seek(Duration(milliseconds: objetivoMs));
    _registrarSeekManualYGuardar(objetivoMs);
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
          _sincronizarModoBarrasSistema();
        }
      });
    }
  }

  /// Sincroniza las barras del sistema (notificaciones superior y navegación inferior)
  /// con la visibilidad de los controles.
  /// Si los controles son visibles, muestra ambas barras del sistema (hora, batería y navegación).
  /// Si los controles se ocultan, entra en inmersión total ocultando ambas barras.
  void _sincronizarModoBarrasSistema() {
    if (_estaSaliendo || ServicioPipNativo.estaEnPip) return;

    if (_mostrarControles && !_pantallaBloqueada) {
      // Mostrar tanto la barra de notificaciones superior como la barra de navegación inferior
      // mientras la interfaz de controles esté visible en pantalla
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );
    } else {
      // Ocultar ambas barras en modo inmersivo completo para máxima inmersión visual
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  bool _obtenerEsHorizontalActual() {
    try {
      final physicalSize = View.of(context).physicalSize;
      if (physicalSize.width > 0 && physicalSize.height > 0) {
        return physicalSize.width > physicalSize.height;
      }
    } catch (_) {}
    try {
      final size = MediaQuery.sizeOf(context);
      if (size.width > 0 && size.height > 0) {
        return size.width > size.height;
      }
    } catch (_) {}
    return _estaEnHorizontal;
  }

  void _alTocarPantalla() {
    if (_estaSaliendo) return;
    if (_pantallaBloqueada) {
      setState(() {
        _mostrarBotonDesbloqueo = !_mostrarBotonDesbloqueo;
      });
      if (_mostrarBotonDesbloqueo) {
        _reiniciarTemporizadorBotonDesbloqueo();
      } else {
        _temporizadorOcultarBotonDesbloqueo?.cancel();
      }
      return;
    }
    _alternarVisibilidadControles();
  }

  void _alternarVisibilidadControles() {
    if (_estaSaliendo || _pantallaBloqueada) return;
    setState(() {
      _mostrarControles = !_mostrarControles;
    });
    _sincronizarModoBarrasSistema();
    if (_mostrarControles) {
      _sincronizarEstadoInterfaz();
      _reiniciarTemporizadorOcultarControles();
    }
  }

  /// Alterna el modo de orientación horizontal / vertical.
  Future<void> _alternarOrientacion() async {
    if (_pantallaBloqueada) return;

    final esLandscape = _obtenerEsHorizontalActual();
    if (esLandscape) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  /// Cambia la velocidad de reproducción en tiempo real sin bloquear el hilo UI.
  void _cambiarVelocidad(double nuevaVelocidad) {
    if (!_estaInicializado || _estaSaliendo) return;
    if ((_velocidadActual - nuevaVelocidad).abs() < 0.001) return;

    _velocidadActual = nuevaVelocidad;
    if (mounted) {
      setState(() {});
    }

    unawaited(
      _reproductor.setRate(nuevaVelocidad).catchError((_) {}),
    );

    _temporizadorGuardarVelocidad?.cancel();
    _temporizadorGuardarVelocidad = Timer(
      const Duration(milliseconds: 250),
      () {
        unawaited(
          ServicioPreferencias.guardarVelocidadPreferida(nuevaVelocidad)
              .catchError((_) {}),
        );
      },
    );
  }

  /// Activa temporalmente la velocidad rápida 2x (o 3x si ya está en 2x) al mantener pulsado estilo YouTube.
  void _alIniciarPulsacionLarga(LongPressStartDetails details) {
    if (_pantallaBloqueada || !_estaInicializado || _estaSaliendo) return;
    if (_reproductor.state.completed) return;
    if (_nivelZoomNotifier.value > 1.05) return;
    if (!_reproductor.state.playing) return;

    _velocidadPreviaAlMantener = _velocidadActual;
    final velocidadDestino = _velocidadActual < 2.0 ? 2.0 : 3.0;
    _velocidadRapidaDestino.value = velocidadDestino;
    _velocidadRapida2xActiva.value = true;

    _reproductor.setRate(velocidadDestino);
    HapticFeedback.mediumImpact();
  }

  /// Restaura la velocidad original al soltar la pulsación larga.
  void _alFinalizarPulsacionLarga() {
    if (!_velocidadRapida2xActiva.value) return;

    _velocidadRapida2xActiva.value = false;
    if (_estaInicializado && !_estaSaliendo) {
      _reproductor.setRate(_velocidadPreviaAlMantener);
    }
    HapticFeedback.lightImpact();
  }

  /// Cambia el modo de aspecto visual del video.
  void _cambiarAspecto(ModoRelacionAspecto nuevoAspecto) {
    _restablecerZoom(animado: false);
    setState(() {
      _aspectoActual = nuevoAspecto;
    });
  }

  /// Muestra el modal para cambiar de subtítulos y pistas de audio incrustadas.
  void _mostrarModalPistas() {
    if (!_estaInicializado || _estaSaliendo) return;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (_) => ModalPistasAudioSubtitulos(
        pistas: _reproductor.state.tracks,
        pistaAudioActual: _reproductor.state.track.audio,
        pistaSubtituloActual: _reproductor.state.track.subtitle,
        alSeleccionarAudio: (track) => _reproductor.setAudioTrack(track),
        alSeleccionarSubtitulo: (track) => _reproductor.setSubtitleTrack(track),
        alCargarSubtituloExterno: _cargarSubtituloExterno,
        alAbrirSincronizacion: _mostrarModalSincronizacion,
      ),
    );
  }

  /// Lee los capítulos/episodios incrustados en los metadatos del archivo mediante libmpv.
  Future<void> _cargarCapitulosDesdeMetadatos() async {
    if (!mounted || _estaSaliendo || !_reproductorCreado) return;
    final rutaObjetivo = _videoActual.ruta;
    try {
      final dynamic platform = _reproductor.platform;
      if (platform == null) return;

      final String rawJson = await platform.getProperty('chapter-list');
      var capitulos = CapituloVideo.parsearDesdeJsonMpv(rawJson);

      if (capitulos.isEmpty) {
        final String countStr = await platform.getProperty('chapters');
        final count = int.tryParse(countStr.trim()) ?? 0;
        if (count > 0) {
          final leidos = <CapituloVideo>[];
          for (int i = 0; i < count; i++) {
            final titleStr = (await platform.getProperty(
              'chapter-list/$i/title',
            )).toString().trim();
            final timeStr = (await platform.getProperty(
              'chapter-list/$i/time',
            )).toString().trim();
            final timeSec = double.tryParse(timeStr);
            if (timeSec == null || timeSec.isNaN || timeSec.isInfinite) {
              continue;
            }
            leidos.add(
              CapituloVideo(
                indice: leidos.length,
                titulo: titleStr.isNotEmpty ? titleStr : 'Capítulo ${i + 1}',
                inicioMs: (timeSec * 1000).round().clamp(0, 1 << 31),
              ),
            );
          }
          capitulos = leidos;
        }
      }

      if (!mounted || _estaSaliendo || _videoActual.ruta != rutaObjetivo) {
        return;
      }
      _capitulosNotifier.value = capitulos;
      _controladorVistaPrevia.actualizarCapitulos(capitulos);
      _actualizarCapituloSaltar(
        _reproductor.state.position.inMilliseconds,
        _reproductor.state.duration.inMilliseconds,
      );
    } catch (_) {}
  }

  void _actualizarCapituloSaltar(int posMs, int durMs) {
    if (!mounted || _estaSaliendo) return;
    final capitulos = _capitulosNotifier.value;
    final nuevo = capitulos.isEmpty
        ? null
        : CapituloVideo.capituloSaltarEnPosicion(
            capitulos: capitulos,
            posicionMs: posMs,
            duracionTotalMs: durMs,
            haySiguienteVideo: _indiceActual < _playlist.length - 1,
          );
    if (_capituloSaltarNotifier.value != nuevo) {
      _capituloSaltarNotifier.value = nuevo;
    }
  }

  /// Ejecuta el salto rápido estilo Crunchyroll (Skip Intro / Outro / Credits).
  void _ejecutarSaltoCapituloEspecial(CapituloSaltarActivo salto) {
    if (!_estaInicializado || _estaSaliendo) return;
    HapticFeedback.lightImpact();
    _capituloSaltarNotifier.value = null;

    if (salto.avanzaASiguienteVideo) {
      _reproducirSiguienteVideo();
      return;
    }

    final destinoMs = salto.destinoMs;
    if (destinoMs == null) return;

    final capitulos = _capitulosNotifier.value;
    final idxSiguiente = salto.capituloOrigen.indice + 1;
    if (idxSiguiente >= 0 &&
        idxSiguiente < capitulos.length &&
        capitulos[idxSiguiente].inicioMs == destinoMs) {
      _irACapitulo(capitulos[idxSiguiente]);
      return;
    }

    unawaited(_saltarATiempoMs(destinoMs));
  }

  Future<void> _saltarATiempoMs(int destinoMs) async {
    if (!_estaInicializado || _estaSaliendo) return;
    try {
      await _reproductor.seek(Duration(milliseconds: destinoMs));
      if (!mounted || _estaSaliendo) return;
      _registrarSeekManualYGuardar(destinoMs);
      _actualizarProgreso(posicionMs: destinoMs);
      _reiniciarTemporizadorOcultarControles();
    } catch (_) {}
  }

  /// Abre la ventana modal "Ir al capítulo..." con todos los episodios del video.
  void _mostrarModalCapitulos() {
    if (!_estaInicializado || _estaSaliendo) return;
    final capitulos = _capitulosNotifier.value;
    final indiceActual = CapituloVideo.indiceEnPosicion(
      capitulos,
      _reproductor.state.position.inMilliseconds,
    );
    ModalCapitulos.mostrar(
      context,
      capitulos: capitulos,
      indiceActual: indiceActual,
      alSeleccionarCapitulo: _irACapitulo,
    );
  }

  /// Salta al capítulo seleccionado sin exponer un Future al árbol de widgets.
  void _irACapitulo(CapituloVideo capitulo) {
    unawaited(_saltarACapitulo(capitulo));
  }

  Future<void> _saltarACapitulo(CapituloVideo capitulo) async {
    if (!_estaInicializado || _estaSaliendo) return;
    try {
      await _reproductor.seek(Duration(milliseconds: capitulo.inicioMs));
      if (!mounted || _estaSaliendo) return;
      _registrarSeekManualYGuardar(capitulo.inicioMs);
      _actualizarProgreso(posicionMs: capitulo.inicioMs);
      _actualizarCapituloSaltar(
        capitulo.inicioMs,
        _reproductor.state.duration.inMilliseconds,
      );
      _mostrarOSDCapitulo(capitulo);
      _reiniciarTemporizadorOcultarControles();
    } catch (_) {}
  }

  /// Avanza directamente al siguiente capítulo disponible en los metadatos.
  void _irASiguienteCapitulo() {
    if (!_estaInicializado || _estaSaliendo) return;
    final capitulos = _capitulosNotifier.value;
    if (capitulos.isEmpty) return;

    final indiceActual = CapituloVideo.indiceEnPosicion(
      capitulos,
      _reproductor.state.position.inMilliseconds,
    );
    final siguienteIndice = indiceActual < 0 ? 0 : indiceActual + 1;
    if (siguienteIndice < capitulos.length) {
      _irACapitulo(capitulos[siguienteIndice]);
    }
  }

  void _mostrarOSDCapitulo(CapituloVideo capitulo) {
    _tipoGestoActual = TipoGestoOSD.capitulo;
    _tituloCapituloOSD = capitulo.titulo;
    _indiceCapituloOSD = capitulo.indice + 1;
    _posicionSeekArrastreMs = capitulo.inicioMs;
    _notificarCambioOSD();
    _programarOcultarOSD();
  }

  /// Alterna el bloqueo de pantalla y ancla o libera la orientación.
  Future<void> _alternarBloqueo() async {
    HapticFeedback.mediumImpact();
    _temporizadorOcultarControles?.cancel();
    _temporizadorOcultarOSD?.cancel();
    _temporizadorOcultarBotonDesbloqueo?.cancel();

    final nuevoEstadoBloqueado = !_pantallaBloqueada;

    if (nuevoEstadoBloqueado) {
      // ANCLAR: Congela la orientación real en que está la pantalla ahora mismo
      final esLandscape = _obtenerEsHorizontalActual();
      if (esLandscape) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      }
    }
    // Al desbloquear: se mantiene la orientación en la que estaba (horizontal o vertical)
    // sin forzar ningún giro, mostrando simplemente los controles de nuevo.

    if (!mounted) return;
    setState(() {
      _pantallaBloqueada = nuevoEstadoBloqueado;
      _mostrarControles = !nuevoEstadoBloqueado;
      _mostrarBotonDesbloqueo = nuevoEstadoBloqueado;
    });
    _sincronizarModoBarrasSistema();

    if (nuevoEstadoBloqueado) {
      _reiniciarTemporizadorBotonDesbloqueo();
    } else {
      _sincronizarEstadoInterfaz();
      _reiniciarTemporizadorOcultarControles();
    }
  }

  void _reiniciarTemporizadorBotonDesbloqueo() {
    _temporizadorOcultarBotonDesbloqueo?.cancel();
    if (_pantallaBloqueada && _mostrarBotonDesbloqueo && !_estaSaliendo) {
      _temporizadorOcultarBotonDesbloqueo = Timer(
        const Duration(milliseconds: 3200),
        () {
          if (mounted && _pantallaBloqueada && !_estaSaliendo) {
            setState(() {
              _mostrarBotonDesbloqueo = false;
            });
          }
        },
      );
    }
  }

  /// Restablece la orientación completamente libre controlada por sensores.
  Future<void> _liberarOrientacion() async {
    if (_pantallaBloqueada) return;
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitDown,
    ]);
  }

  // =================== FUNCIONALIDADES PRO AVANZADAS ===================

  /// Captura instantánea de fotograma con máxima resolución y guardado local.
  Future<void> _capturarPantalla() async {
    if (!_estaInicializado || _estaSaliendo) return;
    try {
      final Uint8List? bytes = await _reproductor.screenshot(
        format: 'image/jpeg',
      );
      if (bytes == null || !mounted) return;

      Directory? directorio;
      if (Platform.isAndroid) {
        directorio = Directory('/storage/emulated/0/Pictures/ReproductorMP4');
        if (!await directorio.exists()) {
          try {
            await directorio.create(recursive: true);
          } catch (_) {
            directorio = await getExternalStorageDirectory();
          }
        }
      } else {
        directorio = await getApplicationDocumentsDirectory();
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final nombreArchivo = 'Captura_$timestamp.jpg';
      final archivoGuardado = File('${directorio!.path}/$nombreArchivo');
      await archivoGuardado.writeAsBytes(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: ColoresApp.acentoPrimario,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Captura guardada en Fotos: $nombreArchivo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: ColoresApp.fondoTarjeta,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al capturar pantalla: $e',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Muestra el modal de temporizador de apagado.
  void _mostrarModalTemporizador() {
    if (_estaSaliendo) return;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (_) => ModalTemporizadorApagado(
        segundosRestantes: _segundosRestantesApagado,
        apagarAlTerminarVideo: _apagarAlTerminarVideo,
        alSeleccionarMinutos: (minutos) {
          _configurarTemporizadorApagado(minutos: minutos);
        },
        alAlternarFinVideo: (activo) {
          _configurarTemporizadorApagado(alFinalizar: activo);
        },
      ),
    );
  }

  void _configurarTemporizadorApagado({
    int? minutos,
    bool alFinalizar = false,
  }) {
    _cancelarTemporizadorApagado();
    if (alFinalizar) {
      setState(() {
        _apagarAlTerminarVideo = true;
        _segundosRestantesApagado = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'La reproducción se detendrá al finalizar el video actual',
          ),
          backgroundColor: ColoresApp.fondoTarjeta,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (minutos != null && minutos > 0) {
      final segundosTotales = minutos * 60;
      setState(() {
        _apagarAlTerminarVideo = false;
        _segundosRestantesApagado = segundosTotales;
      });

      _temporizadorApagadoTimer = Timer.periodic(const Duration(seconds: 1), (
        timer,
      ) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_segundosRestantesApagado == null ||
            _segundosRestantesApagado! <= 1) {
          timer.cancel();
          setState(() {
            _segundosRestantesApagado = null;
          });
          if (_reproductorCreado && _reproductor.state.playing) {
            _reproductor.pause();
          }
          _manejarSalida();
        } else {
          _segundosRestantesApagado = _segundosRestantesApagado! - 1;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Temporizador configurado para $minutos minutos'),
          backgroundColor: ColoresApp.fondoTarjeta,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _cancelarTemporizadorApagado() {
    _temporizadorApagadoTimer?.cancel();
    _temporizadorApagadoTimer = null;
    setState(() {
      _segundosRestantesApagado = null;
      _apagarAlTerminarVideo = false;
    });
  }

  /// Muestra el modal de sincronización fina de audio y subtítulos con fondo translúcido sin tapar el video.
  void _mostrarModalSincronizacion() {
    if (!_estaInicializado || _estaSaliendo) return;
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => ModalSincronizacionPistas(
        desfaseSubtitulosSegundos: _desfaseSubtitulosSegundos,
        desfaseAudioSegundos: _desfaseAudioSegundos,
        alCambiarDesfaseSubtitulos: _cambiarDesfaseSubtitulos,
        alCambiarDesfaseAudio: _cambiarDesfaseAudio,
      ),
    );
  }

  Future<void> _cambiarDesfaseSubtitulos(double desfaseSegundos) async {
    setState(() {
      _desfaseSubtitulosSegundos = desfaseSegundos;
    });
    await ServicioPreferencias.guardarDesfaseSubtitulos(desfaseSegundos);
    try {
      final dynamic platform = _reproductor.platform;
      if (platform != null) {
        await platform.setProperty(
          'sub-delay',
          desfaseSegundos.toStringAsFixed(3),
        );
      }
    } catch (_) {}
  }

  Future<void> _cambiarDesfaseAudio(double desfaseSegundos) async {
    setState(() {
      _desfaseAudioSegundos = desfaseSegundos;
    });
    await ServicioPreferencias.guardarDesfaseAudio(desfaseSegundos);
    try {
      final dynamic platform = _reproductor.platform;
      if (platform != null) {
        await platform.setProperty(
          'audio-delay',
          desfaseSegundos.toStringAsFixed(3),
        );
      }
    } catch (_) {}
  }

  Future<void> _cargarSubtituloExterno() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'vtt', 'ass', 'ssa', 'sub'],
      );
      if (result != null && result.files.single.path != null) {
        final rutaSub = result.files.single.path!;
        final nombreSub = result.files.single.name;
        final track = SubtitleTrack.uri(rutaSub, title: nombreSub);
        await _reproductor.setSubtitleTrack(track);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subtítulo cargado: $nombreSub'),
            backgroundColor: ColoresApp.fondoTarjeta,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar subtítulo: $e'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _buscarYCargarSubtitulosLocales() async {
    try {
      final subtitulos =
          await ServicioAlmacenamientoVideo.buscarSubtitulosLocales(
            _videoActual.ruta,
          );
      if (subtitulos.isNotEmpty) {
        final primerSub = subtitulos.first;
        final nombre = primerSub.path.split(Platform.pathSeparator).last;
        await _reproductor.setSubtitleTrack(
          SubtitleTrack.uri(primerSub.path, title: nombre),
        );
      }
    } catch (_) {}
  }

  void _marcarPuntoBucleA() {
    if (!_estaInicializado || _estaSaliendo) return;
    final posMs = _reproductor.state.position.inMilliseconds;
    setState(() {
      _buclePuntoA = posMs;
      if (_buclePuntoB != null && _buclePuntoB! <= _buclePuntoA!) {
        _buclePuntoB = null;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Punto A marcado en ${_formatearTiempoMs(posMs)}'),
        backgroundColor: ColoresApp.fondoTarjeta,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _marcarPuntoBucleB() {
    if (!_estaInicializado || _estaSaliendo) return;
    final posMs = _reproductor.state.position.inMilliseconds;
    if (_buclePuntoA == null) {
      _marcarPuntoBucleA();
      return;
    }
    if (posMs <= _buclePuntoA!) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('El punto B debe ser posterior al punto A'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _buclePuntoB = posMs;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Bucle A-B activo: ${_formatearTiempoMs(_buclePuntoA!)} ➔ ${_formatearTiempoMs(posMs)}',
        ),
        backgroundColor: ColoresApp.fondoTarjeta,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _limpiarBucleAB() {
    setState(() {
      _buclePuntoA = null;
      _buclePuntoB = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Bucle A-B desactivado'),
        backgroundColor: ColoresApp.fondoTarjeta,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatearTiempoMs(int ms) {
    final d = Duration(milliseconds: ms);
    final horas = d.inHours;
    final minutos = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final segundos = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (horas > 0) {
      return '$horas:$minutos:$segundos';
    }
    return '$minutos:$segundos';
  }

  void _mostrarHojaPlaylist() {
    if (_estaSaliendo) return;
    if (_estaInicializado && _indiceActual >= 0 && _indiceActual < _playlist.length) {
      final posMs = _reproductor.state.position.inMilliseconds;
      final durMs = _reproductor.state.duration.inMilliseconds;
      if (durMs > 0) {
        _videoActual.duracionTotalMs = durMs;
        _playlist[_indiceActual].duracionTotalMs = durMs;
      }
      if (posMs > 0) {
        _videoActual.posicionGuardadaMs = posMs;
        _playlist[_indiceActual].posicionGuardadaMs = posMs;
      }
    }
    HojaPlaylistReproductor.mostrar(
      context,
      listaVideos: _playlist,
      indiceActual: _indiceActual,
      reproduccionAutomatica: _reproduccionAutomatica,
      criterioOrden: ServicioPreferencias.criterioOrdenNotifier.value,
      alSeleccionarVideo: (video, _) {
        _cambiarDeVideo(video);
      },
      alAlternarReproduccionAutomatica: _alternarReproduccionAutomatica,
      alCambiarCriterioOrden: _cambiarOrdenPlaylist,
    );
  }

  void _cambiarOrdenPlaylist(CriterioOrdenVideos nuevoCriterio) {
    OrdenadorVideos.ordenarVideos(_playlist, nuevoCriterio);
    final nuevoIndice = _playlist.indexWhere((v) => v.ruta == _videoActual.ruta);
    setState(() {
      _indiceActual = nuevoIndice >= 0 ? nuevoIndice : 0;
    });
    GestorPipGlobal.instancia.playlist = _playlist;
    GestorPipGlobal.instancia.actualizarVideoActual(_videoActual, _indiceActual);
    unawaited(ServicioPreferencias.guardarCriterioOrdenVideos(nuevoCriterio));
  }

  void _iniciarCuentaRegresivaAutoplay() {
    if (_indiceActual >= _playlist.length - 1) return;
    _cancelarCuentaRegresivaAutoplay();

    final siguiente = _playlist[_indiceActual + 1];
    _siguienteVideoAutoplay = siguiente;
    _segundosRestantesAutoplayNotifier.value = 5;
    setState(() {
      _mostrandoCuentaRegresivaAutoplay = true;
      _mostrarControles = false;
    });

    _temporizadorAutoplay = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _estaSaliendo) {
        timer.cancel();
        return;
      }
      if (_segundosRestantesAutoplayNotifier.value <= 1) {
        timer.cancel();
        _cancelarCuentaRegresivaAutoplay();
        _reproducirSiguienteVideo();
      } else {
        _segundosRestantesAutoplayNotifier.value--;
      }
    });
  }

  void _cancelarCuentaRegresivaAutoplay() {
    _temporizadorAutoplay?.cancel();
    _temporizadorAutoplay = null;
    if (_mostrandoCuentaRegresivaAutoplay) {
      setState(() {
        _mostrandoCuentaRegresivaAutoplay = false;
        _siguienteVideoAutoplay = null;
      });
    }
  }

  void _reproducirAhoraAutoplay() {
    _cancelarCuentaRegresivaAutoplay();
    _reproducirSiguienteVideo();
  }

  Future<void> _alternarReproduccionAutomatica(bool nuevoValor) async {
    await ServicioPreferencias.guardarReproduccionAutomatica(nuevoValor);
    if (mounted) {
      setState(() {
        _reproduccionAutomatica = nuevoValor;
      });
      if (!nuevoValor && _mostrandoCuentaRegresivaAutoplay) {
        _cancelarCuentaRegresivaAutoplay();
      }
    }
  }

  void _reproducirSiguienteVideo() {
    _cancelarCuentaRegresivaAutoplay();
    if (_indiceActual < _playlist.length - 1) {
      _cambiarDeVideo(_playlist[_indiceActual + 1]);
    }
  }

  void _reproducirVideoAnterior() {
    _cancelarCuentaRegresivaAutoplay();
    if (_indiceActual > 0) {
      _cambiarDeVideo(_playlist[_indiceActual - 1]);
    }
  }

  Future<void> _cambiarDeVideo(ModeloVideo nuevoVideo) async {
    if (_estaSaliendo) return;
    _cancelarCuentaRegresivaAutoplay();
    await _guardarProgresoInmediato();
    if (!mounted || _estaSaliendo) return;

    _idCargaVideo++;
    _reanudacionAplicada = false;
    _progresoFinalizadoLimpiado = false;
    _objetivoReanudacionMs = 0;
    _ultimaPosicionValidaMs = 0;
    _usuarioHizoSeekManual = false;
    _estabaReproduciendoMotor = false;

    final nuevoIndice = _playlist.indexWhere((v) => v.ruta == nuevoVideo.ruta);
    _restablecerZoom(animado: false);
    _capitulosConsultadosTrasDuracion = false;
    _capitulosNotifier.value = const [];
    _capituloSaltarNotifier.value = null;
    _controladorVistaPrevia.actualizarCapitulos(const []);
    setState(() {
      _videoActual = nuevoVideo;
      if (nuevoIndice >= 0) _indiceActual = nuevoIndice;
      _estaInicializado = false;
      _tieneError = false;
      _mensajeError = '';
      _reintentadoConSoftware = false;
      _buclePuntoA = null;
      _buclePuntoB = null;
    });

    GestorPipGlobal.instancia.actualizarVideoActual(
      _videoActual,
      nuevoIndice >= 0 ? nuevoIndice : _indiceActual,
    );

    for (final s in _suscripciones) {
      s.cancel();
    }
    _suscripciones.clear();

    await _cargarYReproducirVideo();
  }

  void _mostrarInformacionVideo() {
    if (_estaSaliendo) return;

    // Asegurar duración actualizada del reproductor si el modelo aún no la tenía
    final duracionMs = _reproductor.state.duration.inMilliseconds;
    if (duracionMs > 0 && _videoActual.duracionTotalMs <= 0) {
      _videoActual.duracionTotalMs = duracionMs;
    }

    int? ancho = _reproductor.state.width ??
        _reproductor.state.videoParams.w ??
        _reproductor.state.track.video.w;
    int? alto = _reproductor.state.height ??
        _reproductor.state.videoParams.h ??
        _reproductor.state.track.video.h;
    double? fps = _reproductor.state.track.video.fps;

    if ((fps == null || fps == 0) && _reproductor.state.tracks.video.isNotEmpty) {
      for (final t in _reproductor.state.tracks.video) {
        if (t.fps != null && t.fps! > 0) {
          fps = t.fps;
          break;
        }
      }
    }

    if ((ancho == null || alto == null) &&
        _reproductor.state.tracks.video.isNotEmpty) {
      for (final t in _reproductor.state.tracks.video) {
        if (t.w != null && t.h != null) {
          ancho ??= t.w;
          alto ??= t.h;
          break;
        }
      }
    }

    // Corregir dimensiones si el video tiene rotación física de 90° o 270°
    final rotacion = _reproductor.state.videoParams.rotate;
    if ((rotacion == 90 || rotacion == 270) && ancho != null && alto != null) {
      final temp = ancho;
      ancho = alto;
      alto = temp;
    }

    DialogoInformacionVideo.mostrar(
      context,
      _videoActual,
      ancho: ancho,
      alto: alto,
      fps: fps,
    );
  }

  Future<void> _alternarFavorito() async {
    final esFav = await ServicioPreferencias.alternarFavorito(
      _videoActual.ruta,
    );
    setState(() {
      _videoActual.esFavorito = esFav;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          esFav ? 'Añadido a favoritos ⭐' : 'Eliminado de favoritos',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: ColoresApp.fondoTarjeta,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // =================== GESTOS TÁCTILES Y ZOOM MULTITÁCTIL ===================

  /// Crea una matriz 4x4 para transformación en GPU (escala y traslación) a 144 FPS sin jank.
  Matrix4 _crearMatrizTransformacion(double escala, Offset offset) {
    final matriz = Matrix4.identity();
    matriz.setEntry(0, 0, escala);
    matriz.setEntry(1, 1, escala);
    matriz.setEntry(0, 3, offset.dx);
    matriz.setEntry(1, 3, offset.dy);
    return matriz;
  }

  /// Restablece suavemente (con animación) o de inmediato el zoom a 1.0x y el desplazamiento a cero.
  void _restablecerZoom({bool animado = true}) {
    if (_nivelZoomNotifier.value <= 1.01 && _offsetActual == Offset.zero) return;

    if (!animado) {
      _controladorAnimacionResetZoom?.stop();
      _nivelZoomNotifier.value = 1.0;
      _offsetActual = Offset.zero;
      _matrizTransformacionZoom.value = Matrix4.identity();
      _mostrarOSDZoom(1.0);
      return;
    }

    final escalaInicial = _nivelZoomNotifier.value;
    final offsetInicial = _offsetActual;

    _controladorAnimacionResetZoom?.dispose();
    final controlador = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _controladorAnimacionResetZoom = controlador;

    final animacion = CurvedAnimation(
      parent: controlador,
      curve: Curves.easeOutCubic,
    );

    animacion.addListener(() {
      final t = animacion.value;
      final escalaActual = escalaInicial + (1.0 - escalaInicial) * t;
      final offsetActual = Offset(
        offsetInicial.dx + (0.0 - offsetInicial.dx) * t,
        offsetInicial.dy + (0.0 - offsetInicial.dy) * t,
      );
      _nivelZoomNotifier.value = escalaActual;
      _offsetActual = offsetActual;
      _matrizTransformacionZoom.value =
          _crearMatrizTransformacion(escalaActual, offsetActual);
    });

    controlador.forward().then((_) {
      if (mounted) {
        _nivelZoomNotifier.value = 1.0;
        _offsetActual = Offset.zero;
        _matrizTransformacionZoom.value = Matrix4.identity();
        _mostrarOSDZoom(1.0);
      }
    });
  }

  void _mostrarOSDZoom(double nivel) {
    _temporizadorOcultarOSD?.cancel();
    _tipoGestoActual = TipoGestoOSD.zoom;
    _notificarCambioOSD();
    _programarOcultarOSD();
  }

  void _alIniciarEscala(
    ScaleStartDetails details,
    BoxConstraints constraints,
  ) {
    if (_pantallaBloqueada || _estaSaliendo) return;
    _temporizadorOcultarOSD?.cancel();
    _controladorAnimacionResetZoom?.stop();

    _escalaBasePellizco = _nivelZoomNotifier.value;
    _offsetBasePellizco = _offsetActual;
    _focalInicial = details.localFocalPoint;
    _ultimoPointerCount = details.pointerCount;

    if (details.pointerCount >= 2) {
      _modoGestoActivo = _ModoGestoTactil.zoomYPaneoMultitactil;
      _tipoGestoActual = TipoGestoOSD.zoom;
      _notificarCambioOSD();
    } else {
      if (_nivelZoomNotifier.value > 1.05) {
        _modoGestoActivo = _ModoGestoTactil.panConUnDedo;
      } else {
        _modoGestoActivo = _ModoGestoTactil.indeterminado;
      }
    }
  }

  void _alActualizarEscala(
    ScaleUpdateDetails details,
    BoxConstraints constraints,
  ) {
    if (_pantallaBloqueada || _estaSaliendo) return;

    // Transición dinámica: si se añade un 2do dedo durante un arrastre de 1 dedo
    if (details.pointerCount >= 2 &&
        _modoGestoActivo != _ModoGestoTactil.zoomYPaneoMultitactil) {
      if (_arrastrandoScrubber) {
        _arrastrandoScrubber = false;
      }
      _modoGestoActivo = _ModoGestoTactil.zoomYPaneoMultitactil;
      _escalaBasePellizco = _nivelZoomNotifier.value;
      _offsetBasePellizco = _offsetActual;
      _focalInicial = details.localFocalPoint;
      _ultimoPointerCount = details.pointerCount;
      _tipoGestoActual = TipoGestoOSD.zoom;
      _notificarCambioOSD();
    }

    // Reanclar si cambia la cantidad de dedos para evitar saltos
    if (details.pointerCount >= 2 &&
        details.pointerCount != _ultimoPointerCount) {
      _ultimoPointerCount = details.pointerCount;
      _escalaBasePellizco = _nivelZoomNotifier.value;
      _offsetBasePellizco = _offsetActual;
      _focalInicial = details.localFocalPoint;
    }

    // 1. Zoom multitáctil y paneo libre (2 dedos)
    if (_modoGestoActivo == _ModoGestoTactil.zoomYPaneoMultitactil) {
      final nuevaEscala = (_escalaBasePellizco * details.scale).clamp(1.0, 5.0);
      final deltaFocal = details.localFocalPoint - _focalInicial;
      final nuevoOffset = _offsetBasePellizco + deltaFocal;

      final maxPanX = ((nuevaEscala - 1.0) * constraints.maxWidth / 2.0)
          .clamp(0.0, double.infinity);
      final maxPanY = ((nuevaEscala - 1.0) * constraints.maxHeight / 2.0)
          .clamp(0.0, double.infinity);

      final offsetClampeado = Offset(
        nuevoOffset.dx.clamp(-maxPanX, maxPanX),
        nuevoOffset.dy.clamp(-maxPanY, maxPanY),
      );

      final escalaFinal = nuevaEscala <= 1.01 ? 1.0 : nuevaEscala;
      _nivelZoomNotifier.value = escalaFinal;
      _offsetActual = escalaFinal == 1.0 ? Offset.zero : offsetClampeado;
      _matrizTransformacionZoom.value =
          _crearMatrizTransformacion(escalaFinal, _offsetActual);

      _tipoGestoActual = TipoGestoOSD.zoom;
      _notificarCambioOSD();
      return;
    }

    // 2. Paneo con 1 dedo si el video ya tiene zoom activo (>1.05x)
    if (_modoGestoActivo == _ModoGestoTactil.panConUnDedo) {
      final deltaFocal = details.localFocalPoint - _focalInicial;
      final nuevoOffset = _offsetBasePellizco + deltaFocal;
      final escalaActual = _nivelZoomNotifier.value;

      final maxPanX = ((escalaActual - 1.0) * constraints.maxWidth / 2.0)
          .clamp(0.0, double.infinity);
      final maxPanY = ((escalaActual - 1.0) * constraints.maxHeight / 2.0)
          .clamp(0.0, double.infinity);

      final offsetClampeado = Offset(
        nuevoOffset.dx.clamp(-maxPanX, maxPanX),
        nuevoOffset.dy.clamp(-maxPanY, maxPanY),
      );

      _offsetActual = offsetClampeado;
      _matrizTransformacionZoom.value =
          _crearMatrizTransformacion(escalaActual, offsetClampeado);
      return;
    }

    // 3. 1 dedo en modo normal (zoom 1.0x) -> Deslizar para minimizar, Brillo, Volumen o Seek
    if (_modoGestoActivo == _ModoGestoTactil.indeterminado) {
      final dx = details.localFocalPoint.dx - _focalInicial.dx;
      final dy = details.localFocalPoint.dy - _focalInicial.dy;

      if (dx.abs() > 10.0 || dy.abs() > 10.0) {
        // Deslizamiento hacia abajo para minimizar estilo YouTube:
        // Se activa con arrastre hacia abajo predominante iniciando en la zona superior o franja central.
        final esHaciaAbajo = dy > 12.0 && dy > (dx.abs() * 1.1);
        final enZonaSuperior = _focalInicial.dy < (constraints.maxHeight * 0.40);
        final enFranjaCentral = _focalInicial.dx >= (constraints.maxWidth * 0.25) &&
            _focalInicial.dx <= (constraints.maxWidth * 0.75);

        if (esHaciaAbajo && (enZonaSuperior || enFranjaCentral)) {
          _modoGestoActivo = _ModoGestoTactil.minimizarDeslizando;
          _tipoGestoActual = TipoGestoOSD.ninguno;
          _notificarCambioOSD();
        } else if (dy.abs() > dx.abs()) {
          final esLadoIzquierdo =
              _focalInicial.dx < (constraints.maxWidth / 2.0);
          if (esLadoIzquierdo) {
            _modoGestoActivo = _ModoGestoTactil.brillo;
            _tipoGestoActual = TipoGestoOSD.brillo;
          } else {
            _modoGestoActivo = _ModoGestoTactil.volumen;
            _tipoGestoActual = TipoGestoOSD.volumen;
          }
        } else {
          if (_estaInicializado) {
            _modoGestoActivo = _ModoGestoTactil.seek;
            _arrastrandoScrubber = true;
            _posicionInicialTouchX = details.localFocalPoint.dx;
            _posicionInicialSeekMs =
                _reproductor.state.position.inMilliseconds;
            _diferenciaSeekSegundos = 0;
            _posicionSeekArrastreMs = _posicionInicialSeekMs;
            _tipoGestoActual = TipoGestoOSD.posicionTiempo;
          }
        }
      } else {
        return;
      }
    }

    if (_modoGestoActivo == _ModoGestoTactil.minimizarDeslizando) {
      final deltaY = (details.localFocalPoint.dy - _focalInicial.dy)
          .clamp(0.0, constraints.maxHeight);
      _offsetDeslizamientoMinimizar.value = deltaY;
      return;
    }

    if (_modoGestoActivo == _ModoGestoTactil.brillo) {
      final deltaSensibilidad = -details.focalPointDelta.dy / 200.0;
      _valorBrilloActual =
          (_valorBrilloActual + deltaSensibilidad).clamp(-1.0, 1.0);

      if (_valorBrilloActual >= 0.0) {
        _opacidadFiltroNoche.value = 0.0;
        try {
          ScreenBrightness.instance.setApplicationScreenBrightness(
            _valorBrilloActual,
          );
        } catch (_) {}
      } else {
        _opacidadFiltroNoche.value =
            (-_valorBrilloActual * 0.75).clamp(0.0, 0.75);
        try {
          ScreenBrightness.instance.setApplicationScreenBrightness(0.0);
        } catch (_) {}
      }

      _tipoGestoActual = TipoGestoOSD.brillo;
      _notificarCambioOSD();
    } else if (_modoGestoActivo == _ModoGestoTactil.volumen) {
      final deltaSensibilidad = -details.focalPointDelta.dy / 200.0;
      _valorVolumenActual =
          (_valorVolumenActual + deltaSensibilidad).clamp(0.0, 1.0);
      try {
        _controladorVolumen.setVolume(_valorVolumenActual);
      } catch (_) {}
      _tipoGestoActual = TipoGestoOSD.volumen;
      _notificarCambioOSD();
    } else if (_modoGestoActivo == _ModoGestoTactil.seek) {
      final duracionTotalMs = _reproductor.state.duration.inMilliseconds;
      if (duracionTotalMs <= 0) return;

      final deltaX = details.localFocalPoint.dx - _posicionInicialTouchX;
      final factorSegundos = 120.0 / constraints.maxWidth;
      final segundos = (deltaX * factorSegundos).round();

      _diferenciaSeekSegundos = segundos;
      _posicionSeekArrastreMs = (_posicionInicialSeekMs + (segundos * 1000))
          .clamp(0, duracionTotalMs);

      _tipoGestoActual = TipoGestoOSD.posicionTiempo;
      _notificarCambioOSD();
      _ejecutarFastSeek(Duration(milliseconds: _posicionSeekArrastreMs));
    }
  }

  Future<void> _alFinalizarEscala(ScaleEndDetails details) async {
    if (_modoGestoActivo == _ModoGestoTactil.minimizarDeslizando) {
      final desplazamientoY = _offsetDeslizamientoMinimizar.value;
      final velocidadY = details.velocity.pixelsPerSecond.dy;
      if (desplazamientoY > 110.0 || velocidadY > 800.0) {
        final altura = MediaQuery.sizeOf(context).height;
        _animarYCompletarMinimizacion(altura);
      } else {
        _animarCancelacionMinimizacion();
      }
      _modoGestoActivo = _ModoGestoTactil.ninguno;
      _programarOcultarOSD();
      return;
    }

    if (_modoGestoActivo == _ModoGestoTactil.seek) {
      _arrastrandoScrubber = false;
      await _reproductor.seek(Duration(milliseconds: _posicionSeekArrastreMs));
      _registrarSeekManualYGuardar(_posicionSeekArrastreMs);
      _reiniciarTemporizadorOcultarControles();
    }

    _modoGestoActivo = _ModoGestoTactil.ninguno;
    _programarOcultarOSD();
  }

  void _animarYCompletarMinimizacion(double alturaMaxima) {
    _controladorAnimacionMinimizar?.dispose();
    final controlador = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _controladorAnimacionMinimizar = controlador;
    final inicio = _offsetDeslizamientoMinimizar.value;
    final animacion = Tween<double>(begin: inicio, end: alturaMaxima).animate(
      CurvedAnimation(parent: controlador, curve: Curves.easeInCubic),
    );
    animacion.addListener(() {
      _offsetDeslizamientoMinimizar.value = animacion.value;
    });
    controlador.forward().then((_) {
      if (mounted && !_estaSaliendo) {
        _minimizarAPip();
      }
    });
  }

  void _animarCancelacionMinimizacion() {
    _controladorAnimacionMinimizar?.dispose();
    final controlador = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _controladorAnimacionMinimizar = controlador;
    final inicio = _offsetDeslizamientoMinimizar.value;
    final animacion = Tween<double>(begin: inicio, end: 0.0).animate(
      CurvedAnimation(parent: controlador, curve: Curves.easeOutCubic),
    );
    animacion.addListener(() {
      _offsetDeslizamientoMinimizar.value = animacion.value;
    });
    controlador.forward();
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
    _temporizadorOcultarOSD = Timer(const Duration(milliseconds: 1200), () {
      if (mounted && !_estaSaliendo) {
        _tipoGestoActual = TipoGestoOSD.ninguno;
        _notificarCambioOSD();
      }
    });
  }

  void _alHacerDobleToque(TapDownDetails details, BoxConstraints constraints) {
    if (_pantallaBloqueada || _estaSaliendo) return;

    // Si el video tiene zoom activo (> 1.05x), el doble toque restablece el zoom a 1.0x suavemente
    if (_nivelZoomNotifier.value > 1.05) {
      _restablecerZoom(animado: true);
      return;
    }

    final puntoX = details.localPosition.dx;
    if (puntoX > (constraints.maxWidth / 2)) {
      _saltarAdelante();
    } else {
      _saltarAtras();
    }
  }

  @override
  void dispose() {
    _temporizadorPausaSegundoPlano?.cancel();
    _subscripcionPipNativo?.cancel();
    _subscripcionCierrePipNativo?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _temporizadorOcultarControles?.cancel();
    _temporizadorOcultarOSD?.cancel();
    _temporizadorOcultarBotonDesbloqueo?.cancel();
    _temporizadorApagadoTimer?.cancel();
    _temporizadorAutoplay?.cancel();
    if (_temporizadorGuardarVelocidad?.isActive ?? false) {
      _temporizadorGuardarVelocidad?.cancel();
      unawaited(
        ServicioPreferencias.guardarVelocidadPreferida(_velocidadActual)
            .catchError((_) {}),
      );
    }

    for (final s in _suscripciones) {
      s.cancel();
    }
    _controladorAnimacionResetZoom?.dispose();
    _controladorAnimacionMinimizar?.dispose();
    _offsetDeslizamientoMinimizar.dispose();
    _matrizTransformacionZoom.dispose();
    _nivelZoomNotifier.dispose();
    _alFinalizarPulsacionLarga();
    _velocidadRapida2xActiva.dispose();
    _velocidadRapidaDestino.dispose();
    _estadoProgreso.dispose();
    _estadoReproduccion.dispose();
    _segundosRestantesAutoplayNotifier.dispose();
    _versionOSD.dispose();
    _capitulosNotifier.dispose();
    _capituloSaltarNotifier.dispose();
    _opacidadFiltroNoche.dispose();
    _controladorVistaPrevia.dispose();

    try {
      ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {}
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      ),
    );

    // Si el reproductor fue cedido al PiP, se mantiene vivo para el mini-reproductor
    if (_reproductorCreado && !_reproductorCedidoAlPip) {
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
          if (_mostrandoCuentaRegresivaAutoplay) {
            _cancelarCuentaRegresivaAutoplay();
            return;
          }
          if (_pantallaBloqueada) {
            _alternarBloqueo();
            return;
          }
          final esCompletado = _videoActual.estaCompletado ||
              _reproductor.state.completed ||
              _esVideoCompletado(
                _reproductor.state.position.inMilliseconds,
                _reproductor.state.duration.inMilliseconds,
              );
          if (_estaInicializado && !_tieneError && !esCompletado) {
            _minimizarAPip();
          } else {
            _manejarSalida();
          }
        }
      },
      child: _construirCuerpoReproductor(context),
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

    final esHorizontal =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    // Si la aplicación se encuentra en modo Picture-in-Picture nativo del sistema Android,
    // renderizar ÚNICAMENTE el video puro y limpio sin barras de interfaz, controles ni gestos.
    if (ServicioPipNativo.estaEnPip && _estaInicializado) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: _LienzoVideo(
            controlador: _controladorVideo,
            aspecto: ModoRelacionAspecto.ajustar,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final nuevoHorizontal =
              constraints.maxWidth > constraints.maxHeight;
          if (_estaEnHorizontal != nuevoHorizontal) {
            _estaEnHorizontal = nuevoHorizontal;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _restablecerZoom(animado: false);
            });
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _alTocarPantalla,
            onDoubleTap: () {},
            onDoubleTapDown: (details) =>
                _alHacerDobleToque(details, constraints),
            onScaleStart: (details) =>
                _alIniciarEscala(details, constraints),
            onScaleUpdate: (details) =>
                _alActualizarEscala(details, constraints),
            onScaleEnd: _alFinalizarEscala,
            onLongPressStart: _alIniciarPulsacionLarga,
            onLongPressEnd: (_) => _alFinalizarPulsacionLarga(),
            onLongPressCancel: _alFinalizarPulsacionLarga,
            child: ValueListenableBuilder<double>(
              valueListenable: _offsetDeslizamientoMinimizar,
              builder: (context, offsetY, child) {
                if (offsetY <= 0.0) return child!;
                final progreso =
                    (offsetY / constraints.maxHeight).clamp(0.0, 1.0);
                final escala =
                    (1.0 - (progreso * 0.40)).clamp(0.55, 1.0);
                return Transform.translate(
                  offset: Offset(0, offsetY),
                  child: Transform.scale(
                    scale: escala,
                    alignment: Alignment.topCenter,
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(progreso * 24.0),
                      child: child,
                    ),
                  ),
                );
              },
              child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. RENDERIZADO DEL VIDEO NATIVO CON MEDIA_KIT (LIBMPV) AISLADO CON TRANSFORM
                if (_estaInicializado)
                  ClipRect(
                    child: ValueListenableBuilder<Matrix4>(
                      valueListenable: _matrizTransformacionZoom,
                      builder: (context, matriz, child) {
                        return Transform(
                          transform: matriz,
                          alignment: Alignment.center,
                          child: child,
                        );
                      },
                      child: RepaintBoundary(
                        child: Center(
                          child: _LienzoVideo(
                            controlador: _controladorVideo,
                            aspecto: _aspectoActual,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ColoresApp.acentoPrimario,
                      ),
                    ),
                  ),

                // 1.5 FILTRO DE ATENUACIÓN EXTRA / MODO NOCHE (SUB-CERO)
                // Se coloca sobre el video pero por debajo de los controles y OSD,
                // con IgnorePointer para no bloquear toques ni gestos.
                ValueListenableBuilder<double>(
                  valueListenable: _opacidadFiltroNoche,
                  builder: (context, opacidad, _) {
                    if (opacidad <= 0.0) return const SizedBox.shrink();
                    return RepaintBoundary(
                      child: IgnorePointer(
                        child: Container(
                          color: Colors.black.withValues(alpha: opacidad),
                        ),
                      ),
                    );
                  },
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
                        duracionTotalMs: _videoActual.duracionTotalMs,
                        porcentajeZoom: _nivelZoomNotifier.value,
                        tituloCapitulo: _tituloCapituloOSD,
                        indiceCapitulo: _indiceCapituloOSD,
                        totalCapitulos: _capitulosNotifier.value.length,
                      ),
                    );
                  },
                ),

                // 3. Controles cinemáticos con desvanecimiento fluido (Curves.easeInOut)
                RepaintBoundary(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _velocidadRapida2xActiva,
                    builder: (context, velocidad2x, child) {
                      final visible = _mostrarControles &&
                          !_pantallaBloqueada &&
                          !velocidad2x &&
                          _estaInicializado;
                      return AnimatedOpacity(
                        opacity: visible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: IgnorePointer(
                          ignoring: !visible,
                          child: child,
                        ),
                      );
                    },
                    child: ControlesReproductor(
                        tituloVideo: _videoActual.nombreSinExtension,
                        estadoProgreso: _estadoProgreso,
                        estadoReproduccion: _estadoReproduccion,
                        controladorVistaPrevia: _controladorVistaPrevia,
                        pantallaBloqueada: _pantallaBloqueada,
                        velocidadActual: _velocidadActual,
                        aspectoActual: _aspectoActual,
                        esPantallaCompletaHorizontal: esHorizontal,
                        esFavorito: _videoActual.esFavorito,
                        haySiguiente: _indiceActual < _playlist.length - 1,
                        hayAnterior: _indiceActual > 0,
                        cantidadVideosPlaylist: _playlist.length,
                        bucleABActivo:
                            _buclePuntoA != null || _buclePuntoB != null,
                        esZoomActivo: () => _nivelZoomNotifier.value > 1.05,
                        alRestablecerZoom: () =>
                            _restablecerZoom(animado: true),
                        alAlternarPlayPause: _alternarPlayPause,
                        alIniciarCambioProgreso: _iniciarCambioProgreso,
                        alCambiarProgreso: _cambiarProgreso,
                        alFinalizarCambioProgreso: _finalizarCambioProgreso,
                        alRegresar: () {
                          final esCompletado = _videoActual.estaCompletado ||
                              _reproductor.state.completed ||
                              _esVideoCompletado(
                                _reproductor.state.position.inMilliseconds,
                                _reproductor.state.duration.inMilliseconds,
                              );
                          if (_estaInicializado && !_tieneError && !esCompletado) {
                            _minimizarAPip();
                          } else {
                            _manejarSalida();
                          }
                        },
                        alMinimizar: () => (_estaInicializado && !_tieneError)
                            ? _minimizarAPip()
                            : null,
                        alActivarPipNativo: () => ServicioPipNativo.activarPip(),
                        capitulosNotifier: _capitulosNotifier,
                        alMostrarModalCapitulos: _mostrarModalCapitulos,
                        alSiguienteCapitulo: _irASiguienteCapitulo,
                        alAlternarBloqueo: _alternarBloqueo,
                        alMostrarModalVelocidad: () {
                          ModalVelocidad.mostrar(
                            context,
                            velocidadActual: _velocidadActual,
                            alSeleccionarVelocidad: _cambiarVelocidad,
                          );
                        },
                        alMostrarModalAspecto: () {
                          showDialog(
                            context: context,
                            barrierColor: Colors.black.withValues(alpha: 0.25),
                            builder: (_) => ModalAspecto(
                              aspectoActual: _aspectoActual,
                              alSeleccionarAspecto: _cambiarAspecto,
                            ),
                          );
                        },
                        alMostrarModalPistas: _mostrarModalPistas,
                        alAlternarOrientacion: _alternarOrientacion,
                        alLiberarOrientacion: _liberarOrientacion,
                        alSaltarAdelante: _saltarAdelante,
                        alSaltarAtras: _saltarAtras,
                        alSiguienteVideo: _indiceActual < _playlist.length - 1
                            ? _reproducirSiguienteVideo
                            : null,
                        alVideoAnterior: _indiceActual > 0
                            ? _reproducirVideoAnterior
                            : null,
                        alCapturarPantalla: _capturarPantalla,
                        alMostrarPlaylist: _mostrarHojaPlaylist,
                        alMostrarTemporizadorApagado: _mostrarModalTemporizador,
                        alMostrarSincronizacion: _mostrarModalSincronizacion,
                        alAlternarFavorito: _alternarFavorito,
                        alMarcarPuntoA: _marcarPuntoBucleA,
                        alMarcarPuntoB: _marcarPuntoBucleB,
                        alLimpiarBucle: _limpiarBucleAB,
                        alMostrarInfoVideo: _mostrarInformacionVideo,
                      ),
                    ),
                  ),

                // 3.5 Botón contextual estilo Crunchyroll (Saltar intro / outro / créditos)
                if (_estaInicializado &&
                    !_pantallaBloqueada &&
                    !_mostrandoCuentaRegresivaAutoplay)
                  BotonSaltarCapitulo(
                    capituloSaltarNotifier: _capituloSaltarNotifier,
                    velocidad2xNotifier: _velocidadRapida2xActiva,
                    controlesVisibles: _mostrarControles,
                    alSaltar: _ejecutarSaltoCapituloEspecial,
                  ),

                // 4. Pastilla flotante de velocidad 2x rápida estilo YouTube (aislada con ValueListenableBuilder)
                PastillaVelocidad2x(
                  velocidad2xNotifier: _velocidadRapida2xActiva,
                  velocidadDestinoNotifier: _velocidadRapidaDestino,
                ),

                // 4. Botón de desbloqueo flotante (cuando SÍ está bloqueado)
                if (_pantallaBloqueada) _construirBotonDesbloqueoFlotante(),

                // 5. Superposición de cuenta regresiva estilo YouTube (Autoplay aislada)
                if (_mostrandoCuentaRegresivaAutoplay &&
                    _siguienteVideoAutoplay != null &&
                    !_pantallaBloqueada)
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: ValueListenableBuilder<int>(
                        valueListenable: _segundosRestantesAutoplayNotifier,
                        builder: (context, segundos, _) {
                          return OverlayReproduccionAutomatica(
                            siguienteVideo: _siguienteVideoAutoplay!,
                            segundosRestantes: segundos,
                            totalSegundos: 5,
                            reproduccionAutomaticaActiva:
                                _reproduccionAutomatica,
                            alReproducirAhora: _reproducirAhoraAutoplay,
                            alCancelar: _cancelarCuentaRegresivaAutoplay,
                            alAlternarAutoPlay: _alternarReproduccionAutomatica,
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
  }

  /// Botón de desbloqueo ergonómico en la zona inferior izquierda (alineado con la posición del candado).
  Widget _construirBotonDesbloqueoFlotante() {
    final insets = MediaQuery.paddingOf(context);
    return Positioned(
      bottom: 18 + insets.bottom,
      left: 18 + insets.left,
      child: AnimatedOpacity(
        opacity: _mostrarBotonDesbloqueo ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: IgnorePointer(
          ignoring: !_mostrarBotonDesbloqueo,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _alternarBloqueo,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: ColoresApp.acentoAmbar.withValues(alpha: 0.8),
                    width: 1.4,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      color: ColoresApp.acentoAmbar,
                      size: 18,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'Desbloquear',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget dedicado y aislado para el renderizado del video nativo.
/// Permite mantener estable la instancia de Video y evitar reconstrucciones
/// innecesarias del renderizador cuando cambian otros estados en la pantalla.
class _LienzoVideo extends StatelessWidget {
  final VideoController controlador;
  final ModoRelacionAspecto aspecto;

  const _LienzoVideo({required this.controlador, required this.aspecto});

  @override
  Widget build(BuildContext context) {
    BoxFit fit = BoxFit.contain;

    switch (aspecto) {
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
            controller: controlador,
            fit: BoxFit.fill,
            controls: NoVideoControls,
          ),
        );
      case ModoRelacionAspecto.cuatroTres:
        return AspectRatio(
          aspectRatio: 4 / 3,
          child: Video(
            controller: controlador,
            fit: BoxFit.fill,
            controls: NoVideoControls,
          ),
        );
      case ModoRelacionAspecto.original:
        fit = BoxFit.none;
        break;
    }

    return Video(controller: controlador, fit: fit, controls: NoVideoControls);
  }
}

/// Pastilla flotante OSD para velocidad rápida 2x temporal (al mantener pulsado estilo YouTube).
/// Aislada en su propio RepaintBoundary y ValueListenableBuilder para evitar reconstrucciones.
class PastillaVelocidad2x extends StatelessWidget {
  final ValueNotifier<bool> velocidad2xNotifier;
  final ValueNotifier<double> velocidadDestinoNotifier;

  const PastillaVelocidad2x({
    super.key,
    required this.velocidad2xNotifier,
    required this.velocidadDestinoNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);

    return Positioned(
      top: 24 + insets.top,
      left: 0,
      right: 0,
      child: RepaintBoundary(
        child: Center(
          child: ValueListenableBuilder<bool>(
            valueListenable: velocidad2xNotifier,
            builder: (context, activa, _) {
              return AnimatedOpacity(
                opacity: activa ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeInOut,
                child: IgnorePointer(
                  ignoring: !activa,
                  child: ValueListenableBuilder<double>(
                    valueListenable: velocidadDestinoNotifier,
                    builder: (context, velocidad, _) {
                      final etiqueta =
                          '${velocidad.toStringAsFixed(velocidad % 1 == 0 ? 0 : 1)}x';
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: ColoresApp.acentoPrimario.withValues(alpha: 0.70),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              etiqueta,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.fast_forward_rounded,
                              color: ColoresApp.acentoPrimario,
                              size: 16,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
