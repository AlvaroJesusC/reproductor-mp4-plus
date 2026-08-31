import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../modelos/modelo_carpeta_video.dart';
import '../modelos/modelo_video.dart';
import 'servicio_preferencias.dart';

/// Servicio de alto rendimiento para escanear, organizar y explorar jerárquicamente carpetas y videos de forma no bloqueante.
class ServicioAlmacenamientoVideo {
  /// Extensiones de video soportadas.
  static const Set<String> extensionesSoportadas = {
    'mp4',
    'mkv',
    'avi',
    'mov',
    'webm',
    'flv',
    '3gp',
    'm4v',
    'ts',
    'wmv',
    'mpg',
    'mpeg',
    'vob',
    'ogv',
  };

  /// Carpetas comunes del almacenamiento de Android.
  static const List<String> carpetasComunesAndroid = [
    '/storage/emulated/0/Movies',
    '/storage/emulated/0/Download',
    '/storage/emulated/0/DCIM/Camera',
    '/storage/emulated/0/DCIM',
    '/storage/emulated/0/Videos',
    '/storage/emulated/0/WhatsApp/Media/WhatsApp Video',
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video',
    '/storage/emulated/0/Telegram/Telegram Video',
    '/storage/emulated/0/Snapchat',
  ];

  // Caché en memoria para conteos de carpetas (evita re-escanear el disco repetidamente)
  static final Map<String, ({int carpetas, int videos})>
  _cacheConteoDirectorios = {};

  /// Limpia la caché en memoria cuando se fuerza actualización manual.
  static void limpiarCache() {
    _cacheConteoDirectorios.clear();
  }

  /// Abre el selector nativo para que el usuario elija su carpeta personalizada.
  static Future<String?> seleccionarCarpetaPersonalizada() async {
    try {
      final String? rutaSeleccionada = await FilePicker.platform
          .getDirectoryPath();
      if (rutaSeleccionada != null && rutaSeleccionada.isNotEmpty) {
        limpiarCache();
        await ServicioPreferencias.guardarCarpetaRaizPersonalizada(
          rutaSeleccionada,
        );
        return rutaSeleccionada;
      }
    } catch (_) {}
    return null;
  }

  /// Explora un directorio específico de forma jerárquica, rápida y ligera (solo nivel inmediato).
  static Future<ResultadoExploracionDirectorio> explorarDirectorioJerarquico(
    String rutaDirectorio, {
    bool mostrarOcultos = false,
  }) async {
    final dir = Directory(rutaDirectorio);
    final nombreDir = rutaDirectorio.split(Platform.pathSeparator).last;
    final partes = rutaDirectorio.split(Platform.pathSeparator);
    String? rutaPadre;
    if (partes.length > 1) {
      final padre = partes
          .sublist(0, partes.length - 1)
          .join(Platform.pathSeparator);
      if (padre.isNotEmpty) {
        rutaPadre = padre;
      }
    }

    if (!await dir.exists()) {
      return ResultadoExploracionDirectorio(
        rutaActual: rutaDirectorio,
        nombreActual: nombreDir.isEmpty ? 'Carpeta' : nombreDir,
        rutaPadre: rutaPadre,
        subcarpetas: [],
        videosDirectos: [],
      );
    }

    final List<ModeloCarpetaVideo> subcarpetas = [];
    final List<File> archivosVideoDirectos = [];

    try {
      final List<FileSystemEntity> entidades = await dir
          .list(followLinks: false)
          .toList();

      for (final entidad in entidades) {
        final nombreEntidad = entidad.path.split(Platform.pathSeparator).last;

        // Si no se permiten ocultos, saltar los que inician con '.' (excepto si el usuario lo activa)
        if (!mostrarOcultos && nombreEntidad.startsWith('.')) {
          continue;
        }

        if (nombreEntidad.toLowerCase() == 'android/data' ||
            nombreEntidad.toLowerCase() == 'android/obb') {
          continue;
        }

        if (entidad is Directory) {
          ({int carpetas, int videos}) conteo;
          if (_cacheConteoDirectorios.containsKey(entidad.path)) {
            conteo = _cacheConteoDirectorios[entidad.path]!;
          } else {
            conteo = await _obtenerConteoRapidoDirectorio(entidad);
            _cacheConteoDirectorios[entidad.path] = conteo;
          }

          // Mostrar la carpeta si tiene subcarpetas o videos
          if (conteo.carpetas > 0 || conteo.videos > 0 || mostrarOcultos) {
            subcarpetas.add(
              ModeloCarpetaVideo(
                ruta: entidad.path,
                nombre: nombreEntidad,
                videos: [],
                cantidadSubcarpetas: conteo.carpetas,
                cantidadVideosTotal: conteo.videos,
              ),
            );
          }
        } else if (entidad is File) {
          final puntoIndex = nombreEntidad.lastIndexOf('.');
          if (puntoIndex != -1) {
            final ext = nombreEntidad.substring(puntoIndex + 1).toLowerCase();
            if (extensionesSoportadas.contains(ext)) {
              archivosVideoDirectos.add(entidad);
            }
          }
        }
      }
    } catch (_) {}

    final videosDirectos = await _crearModelosEnLotes(archivosVideoDirectos);

    // Ordenar subcarpetas alfabéticamente
    subcarpetas.sort(
      (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
    );

    // Ordenar videos por nombre
    videosDirectos.sort(
      (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
    );

    // Cargar progreso de reproducción de los videos directos
    await ServicioPreferencias.enriquecerVideosConProgreso(videosDirectos);

    return ResultadoExploracionDirectorio(
      rutaActual: rutaDirectorio,
      nombreActual: nombreDir.isEmpty ? 'Carpeta Principal' : nombreDir,
      rutaPadre: rutaPadre,
      subcarpetas: subcarpetas,
      videosDirectos: videosDirectos,
    );
  }

  /// Conteo inmediato y ultra-rápido de elementos dentro de una subcarpeta (sin recorrer todo el árbol innecesariamente).
  static Future<({int carpetas, int videos})> _obtenerConteoRapidoDirectorio(
    Directory dir,
  ) async {
    int conteoCarpetas = 0;
    int conteoVideos = 0;

    try {
      final Stream<FileSystemEntity> stream = dir.list(followLinks: false);
      await for (final ent in stream) {
        final nombre = ent.path.split(Platform.pathSeparator).last;
        if (nombre.startsWith('.')) continue;

        if (ent is Directory) {
          conteoCarpetas++;
          // Si tiene subcarpetas, también revisamos si tiene videos directos en el primer nivel
        } else if (ent is File) {
          final punto = nombre.lastIndexOf('.');
          if (punto != -1) {
            final ext = nombre.substring(punto + 1).toLowerCase();
            if (extensionesSoportadas.contains(ext)) {
              conteoVideos++;
            }
          }
        }
      }
    } catch (_) {}

    return (carpetas: conteoCarpetas, videos: conteoVideos);
  }

  /// Escanea el almacenamiento evitando recorrer más de una vez la misma carpeta.
  static Future<List<ModeloVideo>> escanearTodosLosVideos() async {
    final rutasVideos = <String>{};
    final directoriosVisitados = <String>{};

    // 0. Si hay carpeta personalizada, escanearla primero.
    final rutaPersonalizada =
        await ServicioPreferencias.obtenerCarpetaRaizPersonalizada();
    if (rutaPersonalizada != null && rutaPersonalizada.isNotEmpty) {
      final dirPers = Directory(rutaPersonalizada);
      if (await dirPers.exists()) {
        await _explorarDirectorioAsync(
          dirPers,
          rutasVideos,
          directoriosVisitados,
          profundidadRestante: 5,
        );
      }
    }

    // 1. Escanear carpetas prioritarias.
    for (final ruta in carpetasComunesAndroid) {
      final dir = Directory(ruta);
      if (await dir.exists()) {
        await _explorarDirectorioAsync(
          dir,
          rutasVideos,
          directoriosVisitados,
          profundidadRestante: 4,
        );
      }
    }

    // 2. Escaneo suave de la raíz. Las carpetas anteriores se omiten gracias
    // al conjunto de visitados, evitando repetir la parte más costosa del I/O.
    final raizAlmacenamiento = Directory('/storage/emulated/0');
    if (await raizAlmacenamiento.exists()) {
      await _explorarDirectorioAsync(
        raizAlmacenamiento,
        rutasVideos,
        directoriosVisitados,
        profundidadRestante: 2,
      );
    }

    final archivos = rutasVideos.map(File.new).toList(growable: false);
    final listaResultado = await _crearModelosEnLotes(archivos);
    listaResultado.sort(
      (a, b) => b.fechaModificacion.compareTo(a.fechaModificacion),
    );

    await ServicioPreferencias.enriquecerVideosConProgreso(listaResultado);

    return listaResultado;
  }

  /// Explorador asíncrono que recolecta rutas sin bloquear con estadísticas síncronas.
  static Future<void> _explorarDirectorioAsync(
    Directory dir,
    Set<String> rutasVideos,
    Set<String> directoriosVisitados, {
    required int profundidadRestante,
  }) async {
    if (profundidadRestante < 0) return;

    final rutaDirectorio = dir.absolute.path;
    if (!directoriosVisitados.add(rutaDirectorio)) return;

    try {
      final Stream<FileSystemEntity> stream = dir.list(followLinks: false);
      await for (final entidad in stream) {
        final nombre = entidad.path.split(Platform.pathSeparator).last;
        final rutaMinusculas = entidad.path.toLowerCase();

        if (nombre.startsWith('.') ||
            rutaMinusculas.endsWith('/android/data') ||
            rutaMinusculas.endsWith('/android/obb')) {
          continue;
        }

        if (entidad is File) {
          final puntoIndex = nombre.lastIndexOf('.');
          if (puntoIndex != -1) {
            final ext = nombre.substring(puntoIndex + 1).toLowerCase();
            if (extensionesSoportadas.contains(ext)) {
              rutasVideos.add(entidad.path);
            }
          }
        } else if (entidad is Directory) {
          await _explorarDirectorioAsync(
            entidad,
            rutasVideos,
            directoriosVisitados,
            profundidadRestante: profundidadRestante - 1,
          );
        }
      }
    } catch (_) {}
  }

  /// Obtiene metadatos con concurrencia limitada para no saturar el almacenamiento.
  static Future<List<ModeloVideo>> _crearModelosEnLotes(
    List<File> archivos, {
    int tamanoLote = 20,
  }) async {
    final modelos = <ModeloVideo>[];
    for (var inicio = 0; inicio < archivos.length; inicio += tamanoLote) {
      final fin = (inicio + tamanoLote).clamp(0, archivos.length);
      final lote = archivos.sublist(inicio, fin);
      modelos.addAll(
        await Future.wait(lote.map(ModeloVideo.desdeArchivoAsync)),
      );
    }
    return modelos;
  }

  /// Agrupa videos por carpeta eficientemente.
  static List<ModeloCarpetaVideo> agruparVideosPorCarpeta(
    List<ModeloVideo> videos,
  ) {
    final Map<String, List<ModeloVideo>> mapaCarpetas = {};

    for (final video in videos) {
      final partes = video.ruta.split(Platform.pathSeparator);
      final rutaCarpeta = partes.length > 1
          ? partes.sublist(0, partes.length - 1).join(Platform.pathSeparator)
          : 'Raíz';

      mapaCarpetas.putIfAbsent(rutaCarpeta, () => []).add(video);
    }

    final List<ModeloCarpetaVideo> listaCarpetas = [];
    mapaCarpetas.forEach((ruta, listaVids) {
      final nombreCarpeta = ruta.split(Platform.pathSeparator).last;
      listaCarpetas.add(
        ModeloCarpetaVideo(
          ruta: ruta,
          nombre: nombreCarpeta.isEmpty ? 'Videos' : nombreCarpeta,
          videos: listaVids,
          cantidadVideosTotal: listaVids.length,
        ),
      );
    });

    listaCarpetas.sort((a, b) => b.cantidadVideos.compareTo(a.cantidadVideos));
    return listaCarpetas;
  }

  /// Selector manual de video.
  static Future<ModeloVideo?> seleccionarVideoManual() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensionesSoportadas.toList(),
    );

    if (resultado != null && resultado.files.single.path != null) {
      final archivo = File(resultado.files.single.path!);
      final video = await ModeloVideo.desdeArchivoAsync(archivo);
      await ServicioPreferencias.enriquecerVideosConProgreso([video]);
      return video;
    }
    return null;
  }

  /// Obtiene los videos en proceso.
  static Future<List<ModeloVideo>> obtenerVideosContinuarViendo(
    List<ModeloVideo> todosLosVideos,
  ) async {
    final rutasHistorial = await ServicioPreferencias.obtenerHistorialRutas();
    final Map<String, ModeloVideo> mapaPorRuta = {
      for (final v in todosLosVideos) v.ruta: v,
    };

    final List<ModeloVideo> resultado = [];
    for (final ruta in rutasHistorial) {
      final video = mapaPorRuta[ruta];
      if (video != null && video.tieneProgreso) {
        resultado.add(video);
      }
    }

    return resultado;
  }
}
