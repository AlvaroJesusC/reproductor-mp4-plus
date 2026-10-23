import 'dart:io';

/// Representa un archivo de video en el dispositivo (película, episodio de serie, etc.).
class ModeloVideo {
  final String id;
  final String ruta;
  final String nombre;
  final String nombreSinExtension;
  final int tamanoBytes;
  final DateTime fechaModificacion;
  final String carpetaContenedora;
  final String extension;

  // Posición guardada en milisegundos (para reanudar reproducción)
  int posicionGuardadaMs;
  int duracionTotalMs;
  bool esFavorito;
  bool estaCompletado;

  ModeloVideo({
    required this.id,
    required this.ruta,
    required this.nombre,
    required this.nombreSinExtension,
    required this.tamanoBytes,
    required this.fechaModificacion,
    required this.carpetaContenedora,
    required this.extension,
    this.posicionGuardadaMs = 0,
    this.duracionTotalMs = 0,
    this.esFavorito = false,
    this.estaCompletado = false,
  });

  /// Crea un objeto ModeloVideo a partir de un archivo del sistema de archivos.
  factory ModeloVideo.desdeArchivo(File archivo) {
    FileStat? estadisticas;
    try {
      estadisticas = archivo.statSync();
    } catch (_) {}
    return _desdeArchivoYEstadisticas(archivo, estadisticas);
  }

  /// Variante no bloqueante para escaneos de bibliotecas grandes.
  static Future<ModeloVideo> desdeArchivoAsync(File archivo) async {
    FileStat? estadisticas;
    try {
      estadisticas = await archivo.stat();
    } catch (_) {}
    return _desdeArchivoYEstadisticas(archivo, estadisticas);
  }

  static ModeloVideo _desdeArchivoYEstadisticas(
    File archivo,
    FileStat? estadisticas,
  ) {
    final rutaCompleta = archivo.path;
    final nombreArchivo = rutaCompleta.split(Platform.pathSeparator).last;
    final puntoIndex = nombreArchivo.lastIndexOf('.');
    final nombreBase = puntoIndex != -1
        ? nombreArchivo.substring(0, puntoIndex)
        : nombreArchivo;
    final ext = puntoIndex != -1
        ? nombreArchivo.substring(puntoIndex + 1).toLowerCase()
        : '';

    final partesRuta = rutaCompleta.split(Platform.pathSeparator);
    final nombreCarpeta = partesRuta.length > 1
        ? partesRuta[partesRuta.length - 2]
        : 'Desconocido';

    return ModeloVideo(
      id: rutaCompleta,
      ruta: rutaCompleta,
      nombre: nombreArchivo,
      nombreSinExtension: nombreBase,
      tamanoBytes: estadisticas?.size ?? 0,
      fechaModificacion: estadisticas?.modified ?? DateTime.now(),
      carpetaContenedora: nombreCarpeta,
      extension: ext,
    );
  }

  /// Formatea el tamaño en bytes a formato legible en español (MB, GB, KB).
  String get tamanoLegible {
    if (tamanoBytes <= 0) return '0 B';
    if (tamanoBytes < 1024) return '$tamanoBytes B';
    if (tamanoBytes < 1024 * 1024) {
      return '${(tamanoBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (tamanoBytes < 1024 * 1024 * 1024) {
      return '${(tamanoBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(tamanoBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Porcentaje de reproducción visto (de 0.0 a 1.0).
  double get porcentajeVisto {
    if (duracionTotalMs <= 0 || posicionGuardadaMs <= 0) return 0.0;
    final ratio = posicionGuardadaMs / duracionTotalMs;
    return ratio.clamp(0.0, 1.0);
  }

  /// Indica si el video ya se empezó a reproducir pero no ha terminado.
  bool get tieneProgreso =>
      !estaCompletado && posicionGuardadaMs > 5000 && porcentajeVisto < 0.95;

  /// Formatea una duración en milisegundos a texto hh:mm:ss o mm:ss.
  static String formatearTiempo(int milisegundos) {
    if (milisegundos <= 0) return '00:00';
    final duracion = Duration(milliseconds: milisegundos);
    final horas = duracion.inHours;
    final minutos = duracion.inMinutes.remainder(60);
    final segundos = duracion.inSeconds.remainder(60);

    final strMinutos = minutos.toString().padLeft(2, '0');
    final strSegundos = segundos.toString().padLeft(2, '0');

    if (horas > 0) {
      final strHoras = horas.toString().padLeft(2, '0');
      return '$strHoras:$strMinutos:$strSegundos';
    }
    return '$strMinutos:$strSegundos';
  }

  /// Formato legible del tiempo guardado actual.
  String get tiempoGuardadoLegible => formatearTiempo(posicionGuardadaMs);

  /// Formato legible de la duración total.
  String get duracionTotalLegible => formatearTiempo(duracionTotalMs);

  /// Serialización a Map para persistencia JSON.
  Map<String, dynamic> aMapa() {
    return {
      'id': id,
      'ruta': ruta,
      'nombre': nombre,
      'nombreSinExtension': nombreSinExtension,
      'tamanoBytes': tamanoBytes,
      'fechaModificacion': fechaModificacion.toIso8601String(),
      'carpetaContenedora': carpetaContenedora,
      'extension': extension,
      'posicionGuardadaMs': posicionGuardadaMs,
      'duracionTotalMs': duracionTotalMs,
      'esFavorito': esFavorito,
      'estaCompletado': estaCompletado,
    };
  }

  /// Deserialización desde Map.
  factory ModeloVideo.desdeMapa(Map<String, dynamic> mapa) {
    return ModeloVideo(
      id: mapa['id'] as String,
      ruta: mapa['ruta'] as String,
      nombre: mapa['nombre'] as String,
      nombreSinExtension: mapa['nombreSinExtension'] as String,
      tamanoBytes: mapa['tamanoBytes'] as int? ?? 0,
      fechaModificacion:
          DateTime.tryParse(mapa['fechaModificacion'] as String? ?? '') ??
          DateTime.now(),
      carpetaContenedora: mapa['carpetaContenedora'] as String? ?? '',
      extension: mapa['extension'] as String? ?? '',
      posicionGuardadaMs: mapa['posicionGuardadaMs'] as int? ?? 0,
      duracionTotalMs: mapa['duracionTotalMs'] as int? ?? 0,
      esFavorito: mapa['esFavorito'] as bool? ?? false,
      estaCompletado: mapa['estaCompletado'] as bool? ?? false,
    );
  }
}
