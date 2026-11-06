/// Modelo inmutable con la información de una versión disponible en GitHub Releases.
class ModeloInfoActualizacion {
  /// Versión en el release remoto (ej: "1.0.1").
  final String versionRemota;

  /// Versión instalada actualmente en la app (ej: "1.0.0").
  final String versionActual;

  /// Notas o cambios de la versión (changelog en Markdown / texto plano).
  final String notasCambios;

  /// URL directa de descarga del archivo .apk.
  final String urlDescargaApk;

  /// Nombre del archivo descargable (ej: "reproductor-mp4-v1.0.1.apk").
  final String nombreArchivo;

  /// Tamaño en bytes del APK si está disponible en GitHub.
  final int? tamanoBytes;

  /// Indica si la versión remota es estrictamente más reciente que la instalada.
  final bool hayNuevaVersion;

  const ModeloInfoActualizacion({
    required this.versionRemota,
    required this.versionActual,
    required this.notasCambios,
    required this.urlDescargaApk,
    required this.nombreArchivo,
    this.tamanoBytes,
    required this.hayNuevaVersion,
  });

  /// Formatea el tamaño en MB para mostrarlo amigablemente al usuario.
  String get tamanoLegible {
    if (tamanoBytes == null || tamanoBytes! <= 0) return '';
    final megas = tamanoBytes! / (1024 * 1024);
    return '${megas.toStringAsFixed(1)} MB';
  }
}

