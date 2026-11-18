import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../modelos/modelo_video.dart';
import 'servicio_preferencias.dart';

/// Extrae y cachea de forma asíncrona y no bloqueante la duración real (en ms)
/// de archivos de video sin necesidad de reproducirlos primero.
class ServicioDuracionVideo {
  static const MethodChannel _canal = MethodChannel(
    'com.example.reproductormp4/metadatos',
  );

  static final Map<String, int> _cacheDuracionesMs = {};
  static final Set<String> _clavesSinDuracionNativa = {};
  static final Map<String, Future<int>> _solicitudesEnCurso = {};

  @visibleForTesting
  static void reiniciarCacheParaPruebas() {
    _cacheDuracionesMs.clear();
    _clavesSinDuracionNativa.clear();
    _solicitudesEnCurso.clear();
  }

  /// Retorna la duración en caché de forma sincrónica si ya es conocida:
  /// - `> 0`: duración válida conocida.
  /// - `0`: ya se intentó leer nativamente en esta sesión sin éxito.
  /// - `null`: aún no se ha consultado en memoria.
  static int? obtenerDuracionEnMemoria(ModeloVideo video) {
    final clave = _crearClaveCache(video);
    if (video.duracionTotalMs > 0) {
      _cacheDuracionesMs[clave] = video.duracionTotalMs;
      _clavesSinDuracionNativa.remove(clave);
      return video.duracionTotalMs;
    }

    final enMemoria = _cacheDuracionesMs[clave];
    if (enMemoria != null && enMemoria > 0) {
      video.duracionTotalMs = enMemoria;
      return enMemoria;
    }

    if (_clavesSinDuracionNativa.contains(clave)) {
      return 0;
    }

    return null;
  }

  /// Registra en memoria una duración descubierta por el reproductor o un escaneo.
  static void registrarDuracionEnMemoria(ModeloVideo video, int duracionMs) {
    if (duracionMs <= 0) return;
    final clave = _crearClaveCache(video);
    video.duracionTotalMs = duracionMs;
    _cacheDuracionesMs[clave] = duracionMs;
    _clavesSinDuracionNativa.remove(clave);
  }

  /// Obtiene la duración en milisegundos del video (desde memoria, preferencias
  /// o el extractor nativo `MediaMetadataRetriever`), deduplicando solicitudes.
  static Future<int> obtenerDuracion(ModeloVideo video) {
    final enMemoria = obtenerDuracionEnMemoria(video);
    if (enMemoria != null) {
      return Future.value(enMemoria);
    }

    final clave = _crearClaveCache(video);
    return _solicitudesEnCurso.putIfAbsent(clave, () async {
      try {
        return await _resolverDuracion(video, clave);
      } finally {
        _solicitudesEnCurso.remove(clave);
      }
    });
  }

  static Future<int> _resolverDuracion(ModeloVideo video, String clave) async {
    try {
      final guardada = await ServicioPreferencias.obtenerDuracionGuardada(
        video.ruta,
      );
      if (guardada > 0) {
        video.duracionTotalMs = guardada;
        _cacheDuracionesMs[clave] = guardada;
        _clavesSinDuracionNativa.remove(clave);
        return guardada;
      }

      final duracionNativa = await _canal.invokeMethod<int>(
        'obtenerDuracionMs',
        <String, dynamic>{'ruta': video.ruta},
      );
      final duracionMs = duracionNativa ?? 0;

      if (duracionMs > 0) {
        video.duracionTotalMs = duracionMs;
        _cacheDuracionesMs[clave] = duracionMs;
        _clavesSinDuracionNativa.remove(clave);
        unawaited(
          ServicioPreferencias.guardarDuracionVideo(
            video.ruta,
            duracionMs,
          ).catchError((_) {}),
        );
        return duracionMs;
      }
    } on MissingPluginException {
      return 0;
    } on PlatformException {
      return 0;
    } catch (_) {
      return 0;
    }

    _clavesSinDuracionNativa.add(clave);
    return 0;
  }

  static String _crearClaveCache(ModeloVideo video) {
    return '${video.ruta}|${video.tamanoBytes}|'
        '${video.fechaModificacion.millisecondsSinceEpoch}';
  }
}
