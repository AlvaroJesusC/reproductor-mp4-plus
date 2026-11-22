import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../modelos/modelo_video.dart';
import '../../pantallas/pantalla_reproductor.dart';
import '../../servicios/logica_reanudacion_video.dart';
import '../../servicios/servicio_preferencias.dart';
import 'servicio_pip_nativo.dart';

/// Estados posibles del ciclo de vida del Picture-in-Picture.
enum EstadoPip {
  cerrado,
  reproductorCompleto,
  minimizadoInApp,
  pipNativoSistema,
}

/// Gestor global singleton y reactivo para el sistema de Picture-in-Picture
/// (Mini-reproductor in-app y PiP de Android) sin recargas ni jank a 144 FPS.
class GestorPipGlobal {
  static final GestorPipGlobal instancia = GestorPipGlobal._interno();

  GestorPipGlobal._interno() {
    ServicioPipNativo.streamEstadoPip.listen((estadoAndroid) {
      if (estadoAndroid == EstadoPipAndroid.enabled) {
        if (estadoPip.value != EstadoPip.cerrado) {
          _estadoPrevioAlPip = estadoPip.value;
          estadoPip.value = EstadoPip.pipNativoSistema;
        }
      } else {
        if (estadoPip.value == EstadoPip.pipNativoSistema) {
          // El usuario expandió la ventana flotante PiP de vuelta a la app:
          // Restauramos el estado previo sin destruir ni pausar la reproducción.
          estadoPip.value = _estadoPrevioAlPip;
        }
      }
    });

    // Solo cerrar y liberar recursos si el usuario descartó la ventana PiP desde Android
    ServicioPipNativo.streamCierrePip.listen((_) {
      unawaited(cerrar());
    });
  }

  EstadoPip _estadoPrevioAlPip = EstadoPip.reproductorCompleto;

  /// Estado actual del Picture-in-Picture.
  final ValueNotifier<EstadoPip> estadoPip = ValueNotifier(EstadoPip.cerrado);

  /// Estado reactivo de reproducción (play/pause) para el mini-reproductor.
  final ValueNotifier<bool> estaReproduciendo = ValueNotifier(false);

  /// Título reactivo del video actual.
  final ValueNotifier<String> tituloVideo = ValueNotifier('');

  /// Progreso reactivo de 0.0 a 1.0 para la barra de avance del mini-reproductor.
  final ValueNotifier<double> ratioProgreso = ValueNotifier(0.0);

  ModeloVideo? videoActual;
  List<ModeloVideo>? playlist;
  int indiceActual = 0;
  Player? reproductor;
  VideoController? controladorVideo;

  StreamSubscription? _subscripcionPlaying;
  StreamSubscription? _subscripcionPosition;
  int _ultimoGuardadoTimestamp = 0;
  int _ultimaPosicionValidaMs = 0;
  bool _estabaReproduciendoAnterior = false;

  bool get estaMinimizado => estadoPip.value == EstadoPip.minimizadoInApp;
  bool get estaActivo =>
      estadoPip.value != EstadoPip.cerrado && reproductor != null;

  /// Registra una sesión de reproducción activa iniciada desde PantallaReproductor.
  void registrarSesion({
    required ModeloVideo video,
    required Player reproductor,
    required VideoController controladorVideo,
    List<ModeloVideo>? playlist,
    int indiceActual = 0,
  }) {
    videoActual = video;
    this.reproductor = reproductor;
    this.controladorVideo = controladorVideo;
    this.playlist = playlist;
    this.indiceActual = indiceActual;
    tituloVideo.value = video.nombreSinExtension;
    estadoPip.value = EstadoPip.reproductorCompleto;
    _ultimoGuardadoTimestamp = DateTime.now().millisecondsSinceEpoch;
    _ultimaPosicionValidaMs = reproductor.state.position.inMilliseconds > 0
        ? reproductor.state.position.inMilliseconds
        : video.posicionGuardadaMs;
    _estabaReproduciendoAnterior = reproductor.state.playing;

    _subscripcionPlaying?.cancel();
    estaReproduciendo.value = reproductor.state.playing;
    _subscripcionPlaying = reproductor.stream.playing.listen((reproduciendo) {
      estaReproduciendo.value = reproduciendo;
      final w = reproductor.state.width ?? 16;
      final h = reproductor.state.height ?? 9;
      unawaited(
        ServicioPipNativo.configurarAutoPip(
          reproduciendo,
          ancho: w,
          alto: h,
        ),
      );
      if (_estabaReproduciendoAnterior &&
          !reproduciendo &&
          (estadoPip.value == EstadoPip.minimizadoInApp ||
              estadoPip.value == EstadoPip.pipNativoSistema)) {
        unawaited(guardarProgresoActual().catchError((_) {}));
      }
      _estabaReproduciendoAnterior = reproduciendo;
    });
    final w = reproductor.state.width ?? 16;
    final h = reproductor.state.height ?? 9;
    unawaited(
      ServicioPipNativo.configurarAutoPip(
        reproductor.state.playing,
        ancho: w,
        alto: h,
      ),
    );

    _subscripcionPosition?.cancel();
    _subscripcionPosition = reproductor.stream.position.listen((pos) {
      final posMs = pos.inMilliseconds;
      final durMotorMs = reproductor.state.duration.inMilliseconds;
      final videoRef = videoActual;
      final durMs = durMotorMs > 0
          ? durMotorMs
          : (videoRef?.duracionTotalMs ?? 0);

      if (posMs > 0) {
        _ultimaPosicionValidaMs = posMs;
      }
      if (durMs > 0) {
        ratioProgreso.value = (posMs / durMs).clamp(0.0, 1.0);
      }

      // Mientras se reproduce en mini-reproductor o PiP nativo, persistir
      // progreso cada 5s para que un cierre abrupto o cambio de app no lo pierda.
      if (videoRef != null &&
          (estadoPip.value == EstadoPip.minimizadoInApp ||
              estadoPip.value == EstadoPip.pipNativoSistema)) {
        final ahora = DateTime.now().millisecondsSinceEpoch;
        if (ahora - _ultimoGuardadoTimestamp >= 5000) {
          _ultimoGuardadoTimestamp = ahora;
          unawaited(guardarProgresoActual().catchError((_) {}));
        }
      }
    });
  }

  /// Actualiza los metadatos cuando se cambia de video dentro de una lista de reproducción.
  void actualizarVideoActual(ModeloVideo video, int indice) {
    videoActual = video;
    indiceActual = indice;
    tituloVideo.value = video.nombreSinExtension;
    _ultimaPosicionValidaMs = video.posicionGuardadaMs;
    _ultimoGuardadoTimestamp = DateTime.now().millisecondsSinceEpoch;
  }

  /// Contrae el reproductor a la mini-ventana acoplada in-app estilo YouTube.
  void minimizar() {
    if (reproductor != null && videoActual != null) {
      estadoPip.value = EstadoPip.minimizadoInApp;
    }
  }

  /// Marca que el reproductor está en pantalla completa.
  void marcarReproductorCompleto() {
    if (reproductor != null) {
      estadoPip.value = EstadoPip.reproductorCompleto;
    }
  }

  /// Expande el mini-reproductor a pantalla completa de forma instantánea sin recargar el video.
  Future<void> expandir(BuildContext context) async {
    if (videoActual == null || reproductor == null || controladorVideo == null) {
      return;
    }
    estadoPip.value = EstadoPip.reproductorCompleto;
    await PantallaReproductor.abrir(
      context,
      videoActual!,
      listaReproduccion: playlist,
      indiceInicial: indiceActual,
      reproductorExistente: reproductor,
      controladorExistente: controladorVideo,
    );
    ServicioPreferencias.notificarCambioProgreso();
  }

  /// Alterna entre reproducir y pausar en el mini-reproductor.
  void alternarPlayPause() {
    final rep = reproductor;
    if (rep == null) return;
    final estabaReproduciendo = rep.state.playing;
    unawaited(rep.playOrPause());
    if (estabaReproduciendo) {
      unawaited(guardarProgresoActual().catchError((_) {}));
    }
  }

  /// Persiste la posición actual del video en PiP/mini-reproductor capturando
  /// los valores de forma sincrónica antes de cualquier operación asíncrona.
  Future<void> guardarProgresoActual() {
    final video = videoActual;
    final rep = reproductor;
    if (video == null || rep == null) {
      return Future<void>.value();
    }

    final posMs = LogicaReanudacionVideo.resolverPosicionParaGuardar(
      posicionMotorMs: rep.state.position.inMilliseconds,
      ultimaPosicionValidaMs: _ultimaPosicionValidaMs,
    );
    final durMotorMs = rep.state.duration.inMilliseconds;
    final durMs = durMotorMs > 0 ? durMotorMs : video.duracionTotalMs;
    final esCompletado = video.estaCompletado ||
        rep.state.completed ||
        LogicaReanudacionVideo.esVideoCompletado(
          posicionMs: posMs,
          duracionMs: durMs,
        );

    Future<void> operacion;
    if (esCompletado) {
      video.estaCompletado = true;
      video.posicionGuardadaMs = 0;
      if (durMs > 0) video.duracionTotalMs = durMs;
      operacion = ServicioPreferencias.marcarVideoCompletado(
        video.ruta,
        duracionTotalMs: durMs,
        completado: true,
      );
    } else if (posMs > LogicaReanudacionVideo.umbralMinimoProgresoMs) {
      video.estaCompletado = false;
      video.posicionGuardadaMs = posMs;
      if (durMs > 0) video.duracionTotalMs = durMs;
      operacion = ServicioPreferencias.guardarProgresoVideo(
        rutaVideo: video.ruta,
        posicionMs: posMs,
        duracionTotalMs: durMs,
      );
    } else if (durMs > 0) {
      video.duracionTotalMs = durMs;
      operacion = ServicioPreferencias.guardarDuracionVideo(video.ruta, durMs);
    } else {
      return Future<void>.value();
    }

    PantallaReproductor.ultimoGuardadoFuture = operacion;
    return operacion;
  }

  /// Cierra el mini-reproductor, persiste la última posición vista y libera la memoria.
  Future<void> cerrar({
    bool guardarProgreso = true,
    bool disponerReproductor = true,
  }) async {
    Future<void>? futuroGuardado;
    if (guardarProgreso && videoActual != null && reproductor != null) {
      futuroGuardado = guardarProgresoActual();
    }

    _subscripcionPlaying?.cancel();
    _subscripcionPlaying = null;
    _subscripcionPosition?.cancel();
    _subscripcionPosition = null;
    unawaited(ServicioPipNativo.configurarAutoPip(false));

    final playerADispose = disponerReproductor ? reproductor : null;
    reproductor = null;
    controladorVideo = null;
    videoActual = null;
    playlist = null;
    indiceActual = 0;
    _ultimaPosicionValidaMs = 0;
    _estabaReproduciendoAnterior = false;
    tituloVideo.value = '';
    estaReproduciendo.value = false;
    ratioProgreso.value = 0.0;
    estadoPip.value = EstadoPip.cerrado;

    if (futuroGuardado != null) {
      try {
        await futuroGuardado;
      } catch (_) {}
    }

    try {
      await playerADispose?.dispose();
    } catch (_) {}
  }
}
