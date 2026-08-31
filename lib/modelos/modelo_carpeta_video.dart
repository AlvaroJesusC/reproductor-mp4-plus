import 'modelo_video.dart';

/// Representa una carpeta en el explorador de archivos.
class ModeloCarpetaVideo {
  final String ruta;
  final String nombre;
  final List<ModeloVideo> videos;
  final int cantidadVideosTotal;
  final int cantidadSubcarpetas;

  ModeloCarpetaVideo({
    required this.ruta,
    required this.nombre,
    required this.videos,
    this.cantidadVideosTotal = 0,
    this.cantidadSubcarpetas = 0,
  });

  /// Cantidad de videos directos en la carpeta.
  int get cantidadVideos => videos.length;

  /// Cantidad total de videos a mostrar.
  int get totalVideosMostrar => cantidadVideosTotal > 0 ? cantidadVideosTotal : videos.length;

  /// Resumen visual de elementos estilo explorador (ej. "4 📁 • 1 📄" o "14 🎬").
  String get resumenElementos {
    if (cantidadSubcarpetas > 0 && totalVideosMostrar > 0) {
      return '$cantidadSubcarpetas 📁 • $totalVideosMostrar 📄';
    } else if (cantidadSubcarpetas > 0) {
      return '$cantidadSubcarpetas 📁';
    } else if (totalVideosMostrar > 0) {
      return '$totalVideosMostrar 📄';
    }
    return '0 elementos';
  }

  /// Tamaño total acumulado en bytes.
  int get tamanoTotalBytes {
    return videos.fold<int>(0, (total, video) => total + video.tamanoBytes);
  }

  /// Tamaño legible total de la carpeta.
  String get tamanoTotalLegible {
    final bytes = tamanoTotalBytes;
    if (bytes == 0) return '0 B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Resultado de explorar un directorio específico de forma jerárquica.
class ResultadoExploracionDirectorio {
  final String rutaActual;
  final String nombreActual;
  final String? rutaPadre;
  final List<ModeloCarpetaVideo> subcarpetas;
  final List<ModeloVideo> videosDirectos;

  ResultadoExploracionDirectorio({
    required this.rutaActual,
    required this.nombreActual,
    this.rutaPadre,
    required this.subcarpetas,
    required this.videosDirectos,
  });

  bool get estaVacia => subcarpetas.isEmpty && videosDirectos.isEmpty;
  int get totalElementos => subcarpetas.length + videosDirectos.length;
}
