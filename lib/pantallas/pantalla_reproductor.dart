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
import '../modelos/modelo_opciones_reproduccion.dart';
import '../modelos/modelo_video.dart';
import '../servicios/servicio_almacenamiento_video.dart';
import '../servicios/servicio_preferencias.dart';
import '../widgets/dialogo_informacion_video.dart';
import '../widgets/reproductor/controles_reproductor.dart';
import '../widgets/reproductor/hoja_playlist_reproductor.dart';
import '../widgets/reproductor/indicador_gesto_osd.dart';
import '../widgets/reproductor/modal_aspecto.dart';
import '../widgets/reproductor/modal_pistas_audio_subtitulos.dart';
import '../widgets/reproductor/modal_sincronizacion_pistas.dart';
import '../widgets/reproductor/modal_temporizador_apagado.dart';
import '../widgets/reproductor/modal_velocidad.dart';
import '../modulos/pip/gestor_pip_global.dart';
import '../modulos/pip/servicio_pip_nativo.dart';
import '../widgets/reproductor/overlay_reproduccion_automatica.dart';

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

  /// Control reactivo de la opacidad del filtro de atenuación nocturna (sub-cero).
  final ValueNotifier<double> _opacidadFiltroNoche = ValueNotifier(0.0);

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
  ModoRelacionAspecto _aspectoActual = ModoRelacionAspecto.ajustar;

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
  Timer? _temporizadorOcultarOSD;

  // Fast-Seeking por Keyframes para scrubber y gestos a 144Hz sin micro-congelamientos
  bool _arrastrandoScrubber = false;
  DateTime _ultimoFastSeekTimestamp = DateTime.fromMillisecondsSinceEpoch(0);

  // Optimización de I/O en disco (Throttling)
  int _ultimoGuardadoTimestamp = 0;
  int _ultimaPosicionMs = 0;
  bool _progresoFinalizadoLimpiado = false;
  bool _reanudacionAplicada = false;

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

    // Escuchar cambios de estado en PiP nativo de Android para ocultar controles
    _subscripcionPipNativo = ServicioPipNativo.streamEstadoPip.listen((status) {
      if (!mounted) return;
      if (status == PiPStatus.enabled) {
        setState(() {
          _mostrarControles = false;
        });
      }
    });

    _configurarModoInmersivo();
    _inicializarBrilloYVolumen();
    _inicializarMotorReproduccion();
  }

  /// Configura pantalla completa inmersiva permitiendo orientación natural.
  Future<void> _configurarModoInmersivo() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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

    // 1. Escuchar posición
    _suscripciones.add(
      _reproductor.stream.position.listen((pos) {
        if (!mounted || _estaSaliendo || _arrastrandoScrubber) return;
        final posMs = pos.inMilliseconds;
        final durMs = _reproductor.state.duration.inMilliseconds;

        // Bucle A-B activo
        if (_buclePuntoA != null && _buclePuntoB != null) {
          if (posMs >= _buclePuntoB!) {
            _reproductor.seek(Duration(milliseconds: _buclePuntoA!));
            return;
          }
        }

        final videoCompletado = _esVideoCompletado(posMs, durMs);
        if (_reanudacionAplicada) {
          if (videoCompletado) {
            _videoActual.estaCompletado = true;
            _videoActual.posicionGuardadaMs = 0;
          } else {
            _videoActual.estaCompletado = false;
            _videoActual.posicionGuardadaMs = posMs;
          }
          _videoActual.duracionTotalMs = durMs;
          if (!videoCompletado) {
            _progresoFinalizadoLimpiado = false;
          }
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

        // Throttling de disco cada 5s
        final ahora = DateTime.now().millisecondsSinceEpoch;
        if (_reanudacionAplicada &&
            ahora - _ultimoGuardadoTimestamp >= 5000 &&
            _reproductor.state.playing) {
          _ultimoGuardadoTimestamp = ahora;
          if (videoCompletado) {
            if (!_progresoFinalizadoLimpiado) {
              _progresoFinalizadoLimpiado = true;
              _videoActual.estaCompletado = true;
              ServicioPreferencias.marcarVideoCompletado(
                _videoActual.ruta,
                duracionTotalMs: durMs,
                completado: true,
              );
            }
          } else {
            ServicioPreferencias.guardarProgresoVideo(
              rutaVideo: _videoActual.ruta,
              posicionMs: posMs,
              duracionTotalMs: durMs,
            );
          }
        }
      }),
    );

    // 2. Escuchar fin de video y estado de reproducción
    _suscripciones.add(
      _reproductor.stream.completed.listen((completado) {
        if (!mounted || _estaSaliendo || !completado) return;
        final durMs = _reproductor.state.duration.inMilliseconds;
        _videoActual.estaCompletado = true;
        _videoActual.posicionGuardadaMs = 0;
        _progresoFinalizadoLimpiado = true;
        ServicioPreferencias.marcarVideoCompletado(
          _videoActual.ruta,
          duracionTotalMs: durMs,
          completado: true,
        );
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
        if (mounted && !_estaSaliendo) {
          _actualizarReproduccion(reproduciendo: reproduciendo);
        }
      }),
    );

    // 3. Escuchar buffering
    _suscripciones.add(
      _reproductor.stream.buffering.listen((cargando) {
        if (mounted && !_estaSaliendo) {
          _actualizarReproduccion(cargando: cargando);
        }
      }),
    );

    // 4. Escuchar duración
    _suscripciones.add(
      _reproductor.stream.duration.listen((dur) {
        if (mounted && dur > Duration.zero && !_estaSaliendo) {
          _videoActual.duracionTotalMs = dur.inMilliseconds;
          _actualizarProgreso(duracionMs: dur.inMilliseconds);
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
            await _reproductor.open(Media(_videoActual.ruta), play: true);
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
    try {
      final archivo = File(_videoActual.ruta);
      if (!await archivo.exists()) {
        setState(() {
          _tieneError = true;
          _mensajeError = 'El archivo de video no existe o no se puede leer.';
        });
        return;
      }

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

      // Leer el progreso antes de abrir el medio. Así los eventos iniciales en
      // posición cero no pueden reemplazar el punto que se debe restaurar.
      final posicionGuardada = _videoActual.posicionGuardadaMs > 5000
          ? _videoActual.posicionGuardadaMs
          : await ServicioPreferencias.obtenerPosicionGuardada(
              _videoActual.ruta,
            );

      // Configurar suscripciones reactivas del motor
      _configurarSuscripcionesMotor();

      // Abrir pausado, esperar sus metadatos y restaurar antes de reproducir.
      await _reproductor.open(Media(_videoActual.ruta), play: false);

      // Cargar subtítulos locales automáticamente si existen
      unawaited(_buscarYCargarSubtitulosLocales());

      final objetivoReanudacionMs = await _aplicarReanudacionInicial(
        posicionGuardada,
      );

      // Evita que el primer evento del motor escriba 0 sobre el progreso.
      _ultimoGuardadoTimestamp = DateTime.now().millisecondsSinceEpoch;
      _reanudacionAplicada = objetivoReanudacionMs == 0;
      await _reproductor.play();

      if (!mounted) return;
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

      if (objetivoReanudacionMs > 0) {
        unawaited(_verificarReanudacion(objetivoReanudacionMs));
      }
      _reiniciarTemporizadorOcultarControles();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tieneError = true;
        _mensajeError = 'Error al decodificar el video: $e';
      });
    }
  }

  Future<int> _aplicarReanudacionInicial(int posicionGuardadaMs) async {
    if (posicionGuardadaMs <= 5000) return 0;

    var duracion = _reproductor.state.duration;
    if (duracion <= Duration.zero) {
      duracion = await _reproductor.stream.duration
          .firstWhere((valor) => valor > Duration.zero)
          .timeout(
            const Duration(milliseconds: 900),
            onTimeout: () => Duration.zero,
          );
    }

    var objetivoMs = posicionGuardadaMs;
    final duracionMs = duracion.inMilliseconds;
    if (duracionMs > 1000 && objetivoMs >= duracionMs) {
      objetivoMs = duracionMs - 1000;
    }

    await _reproductor.seek(Duration(milliseconds: objetivoMs));
    return objetivoMs;
  }

  /// Algunos decodificadores aceptan el primer seek antes de preparar el
  /// video pero no lo aplican. Se verifica una vez iniciada la reproducción.
  Future<void> _verificarReanudacion(int objetivoMs) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || _estaSaliendo || !_reproductorCreado) return;

    final posicionActualMs = _reproductor.state.position.inMilliseconds;
    if (posicionActualMs + 2000 < objetivoMs) {
      await _reproductor.seek(Duration(milliseconds: objetivoMs));
    }

    if (!mounted || _estaSaliendo) return;
    _reanudacionAplicada = true;
    _videoActual.posicionGuardadaMs = objetivoMs;
    _ultimoGuardadoTimestamp = DateTime.now().millisecondsSinceEpoch;
    _sincronizarEstadoInterfaz();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _guardarProgresoInmediato();
      if (!ServicioPipNativo.estaEnPip) {
        if (_estaInicializado && _reproductor.state.playing) {
          _reproductor.pause();
        }
      }
    }
  }

  bool _esVideoCompletado(int posicionMs, int duracionMs) {
    return duracionMs > 0 && posicionMs >= (duracionMs * 0.95);
  }

  Future<void> _guardarProgresoInmediato() async {
    if (!_estaInicializado || !_reanudacionAplicada) return;

    final posMs = _reproductor.state.position.inMilliseconds;
    final durMs = _reproductor.state.duration.inMilliseconds;
    if (_esVideoCompletado(posMs, durMs)) {
      _videoActual.posicionGuardadaMs = 0;
      _videoActual.estaCompletado = true;
      _progresoFinalizadoLimpiado = true;
      await ServicioPreferencias.marcarVideoCompletado(
        _videoActual.ruta,
        duracionTotalMs: durMs,
        completado: true,
      );
      return;
    }

    if (posMs > 5000) {
      _videoActual.posicionGuardadaMs = posMs;
      _videoActual.duracionTotalMs = durMs;
      _videoActual.estaCompletado = false;
      await ServicioPreferencias.guardarProgresoVideo(
        rutaVideo: _videoActual.ruta,
        posicionMs: posMs,
        duracionTotalMs: durMs,
      );
    }
  }

  /// Regresa inmediatamente y deja que la biblioteca absorba la rotación.
  void _manejarSalida() {
    if (_estaSaliendo) return;
    _estaSaliendo = true;
    _cancelarCuentaRegresivaAutoplay();

    // Cerrar sesión en PiP si el usuario cerró el reproductor completamente
    unawaited(GestorPipGlobal.instancia.cerrar());

    // La posición y duración se capturan antes del primer await del guardado.
    // La escritura continúa en segundo plano sin retrasar el cierre de la ruta.
    if (_estaInicializado) {
      unawaited(_guardarProgresoInmediato());
    }

    try {
      unawaited(ScreenBrightness.instance.resetApplicationScreenBrightness());
    } catch (_) {}
    unawaited(WakelockPlus.disable());
    unawaited(
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
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
    _cancelarCuentaRegresivaAutoplay();
    unawaited(_guardarProgresoInmediato());

    try {
      unawaited(ScreenBrightness.instance.resetApplicationScreenBrightness());
    } catch (_) {}
    unawaited(WakelockPlus.disable());
    unawaited(
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
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
  }

  /// Cambia la posición mediante la barra de deslizamiento con Fast-Seeking por Keyframes.
  void _cambiarProgreso(double ratio) {
    if (!_estaInicializado || _estaSaliendo) return;
    _arrastrandoScrubber = true;
    final duracionMs = _reproductor.state.duration.inMilliseconds;
    final objetivoMs = (ratio * duracionMs).round();
    _posicionSeekArrastreMs = objetivoMs;
    _actualizarProgreso(posicionMs: objetivoMs);
    _ejecutarFastSeek(Duration(milliseconds: objetivoMs));
  }

  Future<void> _finalizarCambioProgreso(double ratio) async {
    if (!_estaInicializado || _estaSaliendo) return;
    _arrastrandoScrubber = false;
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

  /// Alterna el bloqueo de pantalla y ancla o libera la orientación.
  Future<void> _alternarBloqueo() async {
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

  /// Muestra el modal de sincronización fina de audio y subtítulos.
  void _mostrarModalSincronizacion() {
    if (!_estaInicializado || _estaSaliendo) return;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
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
    HojaPlaylistReproductor.mostrar(
      context,
      listaVideos: _playlist,
      indiceActual: _indiceActual,
      reproduccionAutomatica: _reproduccionAutomatica,
      alSeleccionarVideo: (video, _) {
        _cambiarDeVideo(video);
      },
      alAlternarReproduccionAutomatica: _alternarReproduccionAutomatica,
    );
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

    final nuevoIndice = _playlist.indexWhere((v) => v.ruta == nuevoVideo.ruta);
    _restablecerZoom(animado: false);
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

    // 3. 1 dedo en modo normal (zoom 1.0x) -> Brillo, Volumen o Seek
    if (_modoGestoActivo == _ModoGestoTactil.indeterminado) {
      final dx = details.localFocalPoint.dx - _focalInicial.dx;
      final dy = details.localFocalPoint.dy - _focalInicial.dy;

      if (dx.abs() > 10.0 || dy.abs() > 10.0) {
        if (dy.abs() > dx.abs()) {
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
    if (_modoGestoActivo == _ModoGestoTactil.seek) {
      _arrastrandoScrubber = false;
      await _reproductor.seek(Duration(milliseconds: _posicionSeekArrastreMs));
      _reiniciarTemporizadorOcultarControles();
    }

    _modoGestoActivo = _ModoGestoTactil.ninguno;
    _programarOcultarOSD();
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
    _subscripcionPipNativo?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _temporizadorOcultarControles?.cancel();
    _temporizadorOcultarOSD?.cancel();
    _temporizadorOcultarBotonDesbloqueo?.cancel();
    _temporizadorApagadoTimer?.cancel();
    _temporizadorAutoplay?.cancel();

    for (final s in _suscripciones) {
      s.cancel();
    }
    _controladorAnimacionResetZoom?.dispose();
    _matrizTransformacionZoom.dispose();
    _nivelZoomNotifier.dispose();
    _estadoProgreso.dispose();
    _estadoReproduccion.dispose();
    _segundosRestantesAutoplayNotifier.dispose();
    _versionOSD.dispose();
    _opacidadFiltroNoche.dispose();

    try {
      ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {}
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

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
          if (_estaInicializado && !_tieneError) {
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
                      ),
                    );
                  },
                ),

                // 3. Controles cinemáticos con desvanecimiento fluido (Curves.easeInOut)
                RepaintBoundary(
                  child: AnimatedOpacity(
                    opacity:
                        (_mostrarControles &&
                            !_pantallaBloqueada &&
                            _estaInicializado)
                        ? 1.0
                        : 0.0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: IgnorePointer(
                      ignoring:
                          !_mostrarControles ||
                          _pantallaBloqueada ||
                          !_estaInicializado,
                      child: ControlesReproductor(
                        tituloVideo: _videoActual.nombreSinExtension,
                        estadoProgreso: _estadoProgreso,
                        estadoReproduccion: _estadoReproduccion,
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
                        alRegresar: () => (_estaInicializado && !_tieneError)
                            ? _minimizarAPip()
                            : _manejarSalida(),
                        alMinimizar: () => (_estaInicializado && !_tieneError)
                            ? _minimizarAPip()
                            : null,
                        alActivarPipNativo: () => ServicioPipNativo.activarPip(),
                        alAlternarBloqueo: _alternarBloqueo,
                        alMostrarModalVelocidad: () {
                          showDialog(
                            context: context,
                            barrierColor: Colors.black.withValues(alpha: 0.25),
                            builder: (_) => ModalVelocidad(
                              velocidadActual: _velocidadActual,
                              alSeleccionarVelocidad: _cambiarVelocidad,
                            ),
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
          );
        },
      ),
    );
  }

  /// Botón de desbloqueo que se oculta o muestra al tocar en cualquier parte de la pantalla.
  Widget _construirBotonDesbloqueoFlotante() {
    final insets = MediaQuery.paddingOf(context);
    return Positioned(
      top: 16 + insets.top,
      left: 16 + insets.left,
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
