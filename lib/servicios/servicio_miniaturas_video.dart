import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../modelos/modelo_video.dart';

/// Genera miniaturas pequeñas bajo demanda y conserva el resultado en disco.
class ServicioMiniaturasVideo {
  // Cuatro extracciones permiten llenar de inmediato la zona visible sin
  // disparar un decodificador por cada elemento de una biblioteca grande.
  static const int _maximoTrabajosSimultaneos = 4;
  static int _trabajosActivos = 0;
  static final Queue<Completer<void>> _trabajosEnEspera = Queue();
  static final Map<String, Future<String?>> _solicitudes = {};
  static final Map<String, String> _cacheRutasMemoria = {};
  static Future<Directory>? _directorioCache;
  static String? _rutaDirectorioCache;

  /// Inicializa la ruta base de la caché de miniaturas para permitir consultas sincrónicas ultrarrápidas.
  static Future<void> inicializar() async {
    await (_directorioCache ??= _prepararDirectorioCache());
  }

  /// Retorna la ruta en memoria o disco sincrónicamente si ya existe el archivo generado.
  static String? obtenerMiniaturaEnMemoria(ModeloVideo video) {
    final clave = _crearClaveCache(video);
    final enMemoria = _cacheRutasMemoria[clave];
    if (enMemoria != null) return enMemoria;

    final rutaBase = _rutaDirectorioCache;
    if (rutaBase != null) {
      final rutaMiniatura = p.join(rutaBase, '$clave.jpg');
      if (File(rutaMiniatura).existsSync()) {
        _cacheRutasMemoria[clave] = rutaMiniatura;
        return rutaMiniatura;
      }
    }
    return null;
  }

  static Future<String?> obtenerMiniatura(ModeloVideo video) {
    final clave = _crearClaveCache(video);
    final enMemoria = _cacheRutasMemoria[clave];
    if (enMemoria != null) {
      return Future.value(enMemoria);
    }
    return _solicitudes.putIfAbsent(
      clave,
      () => _obtenerOGenerar(video, clave),
    );
  }

  static Future<String?> _obtenerOGenerar(
    ModeloVideo video,
    String clave,
  ) async {
    final directorio = await (_directorioCache ??= _prepararDirectorioCache());
    final rutaMiniatura = p.join(directorio.path, '$clave.jpg');
    final archivoMiniatura = File(rutaMiniatura);

    if (await archivoMiniatura.exists()) {
      _cacheRutasMemoria[clave] = rutaMiniatura;
      return rutaMiniatura;
    }

    await _adquirirTurno();
    try {
      // Otra solicitud pudo completar el archivo mientras esta esperaba turno.
      if (await archivoMiniatura.exists()) {
        _cacheRutasMemoria[clave] = rutaMiniatura;
        return rutaMiniatura;
      }

      Uint8List? bytes = await VideoThumbnail.thumbnailData(
        video: video.ruta,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 160,
        quality: 58,
        timeMs: _calcularFotogramaMs(video),
      );

      // Algunos videos cortos no tienen un fotograma en el tiempo elegido.
      bytes ??= await VideoThumbnail.thumbnailData(
        video: video.ruta,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 160,
        quality: 58,
        timeMs: 1000,
      );

      if (bytes == null || bytes.isEmpty) return null;
      await archivoMiniatura.writeAsBytes(bytes, flush: false);
      _cacheRutasMemoria[clave] = rutaMiniatura;
      return rutaMiniatura;
    } catch (_) {
      return null;
    } finally {
      _liberarTurno();
    }
  }

  static Future<Directory> _prepararDirectorioCache() async {
    // A diferencia del directorio temporal, este sobrevive a limpiezas
    // automáticas frecuentes y permite aperturas posteriores instantáneas.
    final soporteApp = await getApplicationSupportDirectory();
    final directorio = Directory(
      p.join(soporteApp.path, 'cache_miniaturas_video'),
    );
    if (!await directorio.exists()) {
      await directorio.create(recursive: true);
    }
    _rutaDirectorioCache = directorio.path;
    return directorio;
  }

  /// Elige un punto reproducible entre videos y estable entre reconstrucciones.
  static int _calcularFotogramaMs(ModeloVideo video) {
    final semilla = _hashEstable(video.ruta);
    if (video.duracionTotalMs > 10000) {
      final inicio = (video.duracionTotalMs * 0.12).round();
      final rango = (video.duracionTotalMs * 0.58).round();
      return inicio + (semilla % rango);
    }
    return 5000 + (semilla % 30000);
  }

  static String _crearClaveCache(ModeloVideo video) {
    final contenido =
        '${video.ruta}|${video.tamanoBytes}|'
        '${video.fechaModificacion.millisecondsSinceEpoch}';
    return _hashEstable(contenido).toRadixString(16).padLeft(8, '0');
  }

  static int _hashEstable(String valor) {
    var hash = 0x811C9DC5;
    for (final unidad in valor.codeUnits) {
      hash ^= unidad;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  static Future<void> _adquirirTurno() async {
    if (_trabajosActivos < _maximoTrabajosSimultaneos) {
      _trabajosActivos++;
      return;
    }

    final completer = Completer<void>();
    _trabajosEnEspera.add(completer);
    await completer.future;
  }

  static void _liberarTurno() {
    if (_trabajosEnEspera.isNotEmpty) {
      // Las solicitudes recientes suelen corresponder a la zona actualmente
      // visible después de un desplazamiento rápido.
      _trabajosEnEspera.removeLast().complete();
      return;
    }
    _trabajosActivos--;
  }
}
