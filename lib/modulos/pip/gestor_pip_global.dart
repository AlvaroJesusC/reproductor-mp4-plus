import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../modelos/modelo_video.dart';
import '../../pantallas/pantalla_reproductor.dart';
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
      final durMs = reproductor.state.duration.inMilliseconds;
      if (durMs > 0) {
        ratioProgreso.value = (pos.inMilliseconds / durMs).clamp(0.0, 1.0);
      }
    });
  }

  /// Actualiza los metadatos cuando se cambia de video dentro de una lista de reproducción.
  void actualizarVideoActual(ModeloVideo video, int indice) {
    videoActual = video;
    indiceActual = indice;
    tituloVideo.value = video.nombreSinExtension;
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
  }

  /// Alterna entre reproducir y pausar en el mini-reproductor.
  void alternarPlayPause() {
    reproductor?.playOrPause();
  }

  /// Cierra el mini-reproductor, persiste la última posición vista y libera la memoria.
  Future<void> cerrar() async {
    if (videoActual != null && reproductor != null) {
      final posMs = reproductor!.state.position.inMilliseconds;
      final durMs = reproductor!.state.duration.inMilliseconds;
      if (durMs > 0 && posMs > 0) {
        unawaited(
          ServicioPreferencias.guardarProgresoVideo(
            rutaVideo: videoActual!.ruta,
            posicionMs: posMs,
            duracionTotalMs: durMs,
          ),
        );
      }
    }

    _subscripcionPlaying?.cancel();
    _subscripcionPlaying = null;
    _subscripcionPosition?.cancel();
    _subscripcionPosition = null;
    unawaited(ServicioPipNativo.configurarAutoPip(false));

    final playerADispose = reproductor;
    reproductor = null;
    controladorVideo = null;
    videoActual = null;
    playlist = null;
    indiceActual = 0;
    tituloVideo.value = '';
    estaReproduciendo.value = false;
    ratioProgreso.value = 0.0;
    estadoPip.value = EstadoPip.cerrado;

    try {
      await playerADispose?.dispose();
    } catch (_) {}
  }
}
