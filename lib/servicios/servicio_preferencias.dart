import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../modelos/modelo_video.dart';

/// Servicio optimizado de almacenamiento local de preferencias y progreso de reproducción con caché de instancia.
class ServicioPreferencias {
  static const String _prefClaveHistorial = 'historial_videos_reproducidos_v1';
  static const String _prefClavePrefVelocidad =
      'preferencia_velocidad_reproduccion';
  static const String _prefClavePrefAspecto = 'preferencia_modo_aspecto';
  static const String _prefClaveCarpetaRaiz = 'carpeta_raiz_personalizada_v1';

  // Caché de la instancia de SharedPreferences para evitar llamadas repetidas a disco
  static SharedPreferences? _instanciaPrefs;

  @visibleForTesting
  static void reiniciarInstanciaParaPruebas() {
    _instanciaPrefs = null;
  }

  static Future<SharedPreferences> _obtenerInstancia() async {
    _instanciaPrefs ??= await SharedPreferences.getInstance();
    return _instanciaPrefs!;
  }

  /// Guarda la posición actual de reproducción y la duración de un video.
  static Future<void> guardarProgresoVideo({
    required String rutaVideo,
    required int posicionMs,
    required int duracionTotalMs,
  }) async {
    final prefs = await _obtenerInstancia();
    final completados = await obtenerCompletados();
    if (completados.contains(rutaVideo)) {
      completados.remove(rutaVideo);
      await prefs.setString(
        _prefClaveCompletados,
        jsonEncode(completados.toList()),
      );
    }

    await Future.wait([
      prefs.setInt('pos_$rutaVideo', posicionMs),
      prefs.setInt('dur_$rutaVideo', duracionTotalMs),
      prefs.setInt('fecha_$rutaVideo', DateTime.now().millisecondsSinceEpoch),
    ]);

    // Esperar el historial evita que la pantalla de recientes lea datos antiguos.
    await _agregarAlHistorial(rutaVideo, prefs);
  }

  /// Obtiene la posición guardada de un video en milisegundos (0 si no existe).
  static Future<int> obtenerPosicionGuardada(String rutaVideo) async {
    final prefs = await _obtenerInstancia();
    return prefs.getInt('pos_$rutaVideo') ?? 0;
  }

  /// Obtiene la duración guardada de un video en milisegundos.
  static Future<int> obtenerDuracionGuardada(String rutaVideo) async {
    final prefs = await _obtenerInstancia();
    return prefs.getInt('dur_$rutaVideo') ?? 0;
  }

  /// Borra el progreso guardado de un video específico.
  static Future<void> borrarProgresoVideo(String rutaVideo) async {
    final prefs = await _obtenerInstancia();
    final completados = await obtenerCompletados();
    if (completados.contains(rutaVideo)) {
      completados.remove(rutaVideo);
      await prefs.setString(
        _prefClaveCompletados,
        jsonEncode(completados.toList()),
      );
    }
    await Future.wait([
      prefs.remove('pos_$rutaVideo'),
      prefs.remove('dur_$rutaVideo'),
      prefs.remove('fecha_$rutaVideo'),
    ]);
  }

  /// Agrega una ruta de video a la lista de videos recientes.
  static Future<void> _agregarAlHistorial(
    String rutaVideo,
    SharedPreferences prefs,
  ) async {
    final jsonStr = prefs.getString(_prefClaveHistorial);
    List<String> rutas = [];
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final dec = jsonDecode(jsonStr);
        if (dec is List) {
          rutas = dec.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    rutas.remove(rutaVideo);
    rutas.insert(0, rutaVideo);

    if (rutas.length > 50) {
      rutas = rutas.sublist(0, 50);
    }

    await prefs.setString(_prefClaveHistorial, jsonEncode(rutas));
  }

  /// Obtiene la lista de rutas de videos en el historial de recientes.
  static Future<List<String>> obtenerHistorialRutas() async {
    final prefs = await _obtenerInstancia();
    final jsonStr = prefs.getString(_prefClaveHistorial);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final dec = jsonDecode(jsonStr);
        if (dec is List) {
          return dec.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  /// Carga el progreso guardado para una lista de modelos de video de forma rápida en memoria.
  static Future<void> enriquecerVideosConProgreso(
    List<ModeloVideo> videos,
  ) async {
    if (videos.isEmpty) return;
    final prefs = await _obtenerInstancia();
    final completados = await obtenerCompletados();
    final favoritos = await obtenerFavoritos();

    for (final video in videos) {
      video.estaCompletado = completados.contains(video.ruta);
      video.esFavorito = favoritos.contains(video.ruta);

      if (video.estaCompletado) {
        video.posicionGuardadaMs = 0;
      } else {
        video.posicionGuardadaMs = prefs.getInt('pos_${video.ruta}') ?? 0;
      }
      final dur = prefs.getInt('dur_${video.ruta}');
      if (dur != null && dur > 0) {
        video.duracionTotalMs = dur;
      }
    }
  }

  /// Guarda la última velocidad de reproducción elegida por el usuario.
  static Future<void> guardarVelocidadPreferida(double velocidad) async {
    final prefs = await _obtenerInstancia();
    await prefs.setDouble(_prefClavePrefVelocidad, velocidad);
  }

  /// Obtiene la velocidad de reproducción preferida (por defecto 1.0).
  static Future<double> obtenerVelocidadPreferida() async {
    final prefs = await _obtenerInstancia();
    return prefs.getDouble(_prefClavePrefVelocidad) ?? 1.0;
  }

  /// Guarda el modo de relación de aspecto preferido.
  static Future<void> guardarAspectoPreferido(String aspecto) async {
    final prefs = await _obtenerInstancia();
    await prefs.setString(_prefClavePrefAspecto, aspecto);
  }

  /// Obtiene el modo de relación de aspecto preferido.
  static Future<String> obtenerAspectoPreferido() async {
    final prefs = await _obtenerInstancia();
    return prefs.getString(_prefClavePrefAspecto) ?? '';
  }

  /// Guarda la ruta de la carpeta raíz personalizada elegida por el usuario.
  static Future<void> guardarCarpetaRaizPersonalizada(String ruta) async {
    final prefs = await _obtenerInstancia();
    await prefs.setString(_prefClaveCarpetaRaiz, ruta);
  }

  /// Obtiene la ruta de la carpeta raíz personalizada (null si no se ha configurado).
  static Future<String?> obtenerCarpetaRaizPersonalizada() async {
    final prefs = await _obtenerInstancia();
    return prefs.getString(_prefClaveCarpetaRaiz);
  }

  /// Borra la ruta de carpeta raíz personalizada para volver al escaneo general.
  static Future<void> borrarCarpetaRaizPersonalizada() async {
    final prefs = await _obtenerInstancia();
    await prefs.remove(_prefClaveCarpetaRaiz);
  }

  // ===================== SISTEMA DE FAVORITOS =====================
  static const String _prefClaveFavoritos = 'videos_favoritos_v1';

  /// Obtiene el conjunto de rutas de videos favoritos.
  static Future<Set<String>> obtenerFavoritos() async {
    final prefs = await _obtenerInstancia();
    final jsonStr = prefs.getString(_prefClaveFavoritos);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final dec = jsonDecode(jsonStr);
        if (dec is List) {
          return dec.map((e) => e.toString()).toSet();
        }
      } catch (_) {}
    }
    return <String>{};
  }

  /// Alterna el estado de favorito de un video y retorna el nuevo estado.
  static Future<bool> alternarFavorito(String rutaVideo) async {
    final prefs = await _obtenerInstancia();
    final favoritos = await obtenerFavoritos();
    final nuevoEstado = !favoritos.contains(rutaVideo);
    if (nuevoEstado) {
      favoritos.add(rutaVideo);
    } else {
      favoritos.remove(rutaVideo);
    }
    await prefs.setString(_prefClaveFavoritos, jsonEncode(favoritos.toList()));
    return nuevoEstado;
  }

  /// Verifica si un video es favorito.
  static Future<bool> esFavorito(String rutaVideo) async {
    final favoritos = await obtenerFavoritos();
    return favoritos.contains(rutaVideo);
  }

  // ===================== SISTEMA DE COMPLETADOS / VISTOS =====================
  static const String _prefClaveCompletados = 'videos_completados_v1';

  /// Obtiene el conjunto de rutas de videos completados (vistos en su totalidad).
  static Future<Set<String>> obtenerCompletados() async {
    final prefs = await _obtenerInstancia();
    final jsonStr = prefs.getString(_prefClaveCompletados);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final dec = jsonDecode(jsonStr);
        if (dec is List) {
          return dec.map((e) => e.toString()).toSet();
        }
      } catch (_) {}
    }
    return <String>{};
  }

  /// Marca un video como completado (o no completado) y limpia su posición guardada.
  static Future<void> marcarVideoCompletado(
    String rutaVideo, {
    int? duracionTotalMs,
    bool completado = true,
  }) async {
    final prefs = await _obtenerInstancia();
    final completados = await obtenerCompletados();
    if (completado) {
      completados.add(rutaVideo);
      await prefs.remove('pos_$rutaVideo');
      if (duracionTotalMs != null && duracionTotalMs > 0) {
        await prefs.setInt('dur_$rutaVideo', duracionTotalMs);
      }
    } else {
      completados.remove(rutaVideo);
      await prefs.remove('pos_$rutaVideo');
    }
    await prefs.setString(
      _prefClaveCompletados,
      jsonEncode(completados.toList()),
    );
  }

  /// Verifica si un video ha sido completado.
  static Future<bool> esVideoCompletado(String rutaVideo) async {
    final completados = await obtenerCompletados();
    return completados.contains(rutaVideo);
  }

  /// Alterna el estado de completado de un video y retorna el nuevo estado.
  static Future<bool> alternarCompletado(
    String rutaVideo, {
    int? duracionTotalMs,
  }) async {
    final completados = await obtenerCompletados();
    final nuevoEstado = !completados.contains(rutaVideo);
    await marcarVideoCompletado(
      rutaVideo,
      duracionTotalMs: duracionTotalMs,
      completado: nuevoEstado,
    );
    return nuevoEstado;
  }

  // ===================== CACHÉ INSTANTÁNEA DE BIBLIOTECA (< 50ms) =====================
  static const String _prefClaveCacheBiblioteca = 'cache_biblioteca_videos_v1';

  /// Guarda en disco la lista de videos escaneados para arranque instantáneo.
  static Future<void> guardarCacheBiblioteca(List<ModeloVideo> videos) async {
    if (videos.isEmpty) return;
    try {
      final prefs = await _obtenerInstancia();
      final listaMapas = videos.map((v) => v.aMapa()).toList();
      await prefs.setString(_prefClaveCacheBiblioteca, jsonEncode(listaMapas));
    } catch (_) {}
  }

  /// Obtiene de forma instantánea la biblioteca guardada previamente.
  static Future<List<ModeloVideo>> obtenerCacheBiblioteca() async {
    try {
      final prefs = await _obtenerInstancia();
      final jsonStr = prefs.getString(_prefClaveCacheBiblioteca);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final dec = jsonDecode(jsonStr);
        if (dec is List) {
          final favoritos = await obtenerFavoritos();
          final completados = await obtenerCompletados();
          return dec.map((item) {
            final mapa = Map<String, dynamic>.from(item as Map);
            final video = ModeloVideo.desdeMapa(mapa);
            video.esFavorito = favoritos.contains(video.ruta);
            video.estaCompletado = completados.contains(video.ruta);
            if (video.estaCompletado) {
              video.posicionGuardadaMs = 0;
            }
            return video;
          }).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  // ===================== MODO DE VISTA (LISTA / CUADRÍCULA) =====================
  static const String _prefClaveModoCuadricula = 'modo_vista_cuadricula_v1';

  /// Guarda la preferencia de vista (true = cuadrícula, false = lista compacta).
  static Future<void> guardarModoVistaCuadricula(bool esCuadricula) async {
    final prefs = await _obtenerInstancia();
    await prefs.setBool(_prefClaveModoCuadricula, esCuadricula);
  }

  /// Obtiene la preferencia de vista (por defecto false = lista compacta).
  static Future<bool> obtenerModoVistaCuadricula() async {
    final prefs = await _obtenerInstancia();
    return prefs.getBool(_prefClaveModoCuadricula) ?? false;
  }

  // ===================== SINCRONIZACIÓN DE SUBTÍTULOS Y AUDIO =====================
  static const String _prefClaveDesfaseSubtitulos =
      'desfase_subtitulos_segundos';
  static const String _prefClaveDesfaseAudio = 'desfase_audio_segundos';

  static Future<void> guardarDesfaseSubtitulos(double segundos) async {
    final prefs = await _obtenerInstancia();
    await prefs.setDouble(_prefClaveDesfaseSubtitulos, segundos);
  }

  static Future<double> obtenerDesfaseSubtitulos() async {
    final prefs = await _obtenerInstancia();
    return prefs.getDouble(_prefClaveDesfaseSubtitulos) ?? 0.0;
  }

  static Future<void> guardarDesfaseAudio(double segundos) async {
    final prefs = await _obtenerInstancia();
    await prefs.setDouble(_prefClaveDesfaseAudio, segundos);
  }

  static Future<double> obtenerDesfaseAudio() async {
    final prefs = await _obtenerInstancia();
    return prefs.getDouble(_prefClaveDesfaseAudio) ?? 0.0;
  }

  // ===================== REPRODUCCIÓN AUTOMÁTICA (AUTOPLAY SIGUIENTE VIDEO) =====================
  static const String _prefClaveReproduccionAutomatica =
      'reproduccion_automatica_v1';

  /// Guarda la preferencia de reproducción automática del siguiente video (por defecto true).
  static Future<void> guardarReproduccionAutomatica(bool activa) async {
    final prefs = await _obtenerInstancia();
    await prefs.setBool(_prefClaveReproduccionAutomatica, activa);
  }

  /// Obtiene si la reproducción automática está activa (true por defecto).
  static Future<bool> obtenerReproduccionAutomatica() async {
    final prefs = await _obtenerInstancia();
    return prefs.getBool(_prefClaveReproduccionAutomatica) ?? true;
  }
}
