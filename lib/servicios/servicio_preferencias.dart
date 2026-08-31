import 'dart:convert';
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
    for (final video in videos) {
      final pos = prefs.getInt('pos_${video.ruta}');
      if (pos != null && pos > 0) {
        video.posicionGuardadaMs = pos;
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
}
