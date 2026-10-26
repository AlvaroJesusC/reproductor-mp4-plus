import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constantes/colores_app.dart';
import '../modelos/modelo_carpeta_video.dart';
import '../modelos/modelo_video.dart';
import '../servicios/servicio_almacenamiento_video.dart';
import '../servicios/servicio_permisos.dart';
import '../servicios/servicio_preferencias.dart';
import '../modulos/pip/envoltorio_pip_scaffold.dart';
import '../modulos/pip/gestor_pip_global.dart';
import 'pantalla_reproductor.dart';
import 'pestanas/pestana_carpetas.dart';
import 'pestanas/pestana_recientes.dart';
import 'pestanas/pestana_todos_los_videos.dart';

/// Pantalla principal con navegación por pestañas y persistencia de memoria (cero recargas al salir de un video).
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _indicePestana = 1; // Iniciar por defecto en "Videos"
  bool _estaCargando = true;
  bool _estaActualizando = false;
  bool _tienePermiso = false;

  List<ModeloVideo> _todosLosVideos = [];
  List<ModeloVideo> _videosRecientes = [];
  List<ModeloCarpetaVideo> _carpetasVideos = [];

  // Clave para controlar la navegación interna de la pestaña Carpetas
  final GlobalKey<PestanaCarpetasState> _clavePestanaCarpetas =
      GlobalKey<PestanaCarpetasState>();

  // Control de doble toque para salir de la app
  DateTime? _ultimoToqueAtras;

  @override
  void initState() {
    super.initState();
    _verificarPermisosYRecargar();
  }

  Future<void> _verificarPermisosYRecargar() async {
    // 1. Cargar caché instantáneo (< 50ms) para que la pantalla NUNCA se quede en blanco
    final videosEnCache = await ServicioPreferencias.obtenerCacheBiblioteca();
    if (videosEnCache.isNotEmpty && mounted) {
      final carpetasEnCache =
          ServicioAlmacenamientoVideo.agruparVideosPorCarpeta(videosEnCache);
      final recientesEnCache =
          await ServicioAlmacenamientoVideo.obtenerVideosContinuarViendo(
            videosEnCache,
          );
      setState(() {
        _todosLosVideos = videosEnCache;
        _carpetasVideos = carpetasEnCache;
        _videosRecientes = recientesEnCache;
        _estaCargando = false;
      });
    } else if (mounted) {
      setState(() {
        _estaCargando = true;
      });
    }

    final tienePermiso = await ServicioPermisos.tienePermisosAlmacenamiento();
    if (!mounted) return;

    if (tienePermiso) {
      _tienePermiso = true;
      await _cargarVideos();
    } else {
      final solicitado =
          await ServicioPermisos.solicitarPermisosAlmacenamiento();
      if (!mounted) return;
      _tienePermiso = solicitado;
      if (solicitado) {
        await _cargarVideos();
      } else {
        setState(() {
          _estaCargando = false;
        });
      }
    }
  }

  /// Escaneo completo de almacenamiento (actualiza en background si ya había caché).
  Future<void> _cargarVideos({bool forzarLimpiezaCache = false}) async {
    if (_estaActualizando) return;

    setState(() {
      _estaCargando = _todosLosVideos.isEmpty;
      _estaActualizando = true;
    });

    if (forzarLimpiezaCache) {
      ServicioAlmacenamientoVideo.limpiarCache();
    }

    try {
      final videos = await ServicioAlmacenamientoVideo.escanearTodosLosVideos();
      final carpetas = ServicioAlmacenamientoVideo.agruparVideosPorCarpeta(
        videos,
      );
      final recientes =
          await ServicioAlmacenamientoVideo.obtenerVideosContinuarViendo(
            videos,
          );

      if (!mounted) return;
      setState(() {
        _todosLosVideos = videos;
        _carpetasVideos = carpetas;
        _videosRecientes = recientes;
        _estaCargando = false;
        _estaActualizando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _estaCargando = false;
        _estaActualizando = false;
      });
    }
  }

  /// Actualización instantánea en memoria sin pantalla de carga (se usa al salir de un video o cambiar favoritos/completados).
  Future<void> _actualizarProgresoEnMemoria() async {
    try {
      await ServicioPreferencias.enriquecerVideosConProgreso(_todosLosVideos);
      final recientes =
          await ServicioAlmacenamientoVideo.obtenerVideosContinuarViendo(
            _todosLosVideos,
          );
      if (mounted) {
        setState(() {
          _videosRecientes = recientes;
        });
      }
    } catch (_) {}
  }

  Future<void> _abrirSelectorManual() async {
    final video = await ServicioAlmacenamientoVideo.seleccionarVideoManual();
    if (video != null && mounted) {
      await PantallaReproductor.abrir(
        context,
        video,
        listaReproduccion: [video],
        indiceInicial: 0,
      );
      _actualizarProgresoEnMemoria();
    }
  }

  /// Manejo inteligente del botón de retroceso (Atrás) de Android.
  void _manejarRetroceso(bool didPop) {
    if (didPop) return;

    // 0. Si el mini-reproductor está activo, cerrarlo primero antes de salir
    if (GestorPipGlobal.instancia.estaMinimizado) {
      GestorPipGlobal.instancia.cerrar();
      return;
    }

    // 1. Si estamos en la pestaña Carpetas, retroceder dentro de las subcarpetas/series/temporadas
    if (_indicePestana == 2) {
      final seManejoInternamente =
          _clavePestanaCarpetas.currentState?.retrocederSiEsPosible() ?? false;
      if (seManejoInternamente) {
        return;
      }
    }

    // 2. Si estamos en otra pestaña ("Carpetas" o "Continuar" en su raíz), volver a la pestaña de "Videos"
    if (_indicePestana != 1) {
      setState(() {
        _indicePestana = 1;
      });
      return;
    }

    // 3. Si ya estamos en la pestaña raíz de "Videos", pedir confirmación de doble toque para no salir accidentalmente
    final ahora = DateTime.now();
    if (_ultimoToqueAtras == null ||
        ahora.difference(_ultimoToqueAtras!) > const Duration(seconds: 2)) {
      _ultimoToqueAtras = ahora;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Presiona atrás nuevamente para salir'),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: ColoresApp.bordeSutil, width: 1),
          ),
          backgroundColor: ColoresApp.fondoTarjeta,
        ),
      );
      return;
    }

    // Salir limpiamente si presionó 2 veces
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_tienePermiso && !_estaCargando) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ColoresApp.acentoPrimario.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.folder_special_rounded,
                    color: ColoresApp.acentoPrimario,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Permiso de Almacenamiento Necesario',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ColoresApp.textoPrincipal,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Para reproducir tus películas y series descargadas, necesitamos acceso al almacenamiento de tu dispositivo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ColoresApp.textoSecundario,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColoresApp.acentoPrimario,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(
                    Icons.lock_open_rounded,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Conceder Permiso',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _verificarPermisosYRecargar,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => ServicioPermisos.abrirAjustesApp(),
                  child: const Text(
                    'Abrir Ajustes del Sistema',
                    style: TextStyle(color: ColoresApp.textoSecundario),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _manejarRetroceso(didPop),
      child: EnvoltorioPipScaffold(
        child: Scaffold(
          appBar: AppBar(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ColoresApp.acentoPrimario,
                      Color(0xFFD61E47),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: ColoresApp.acentoPrimario.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Reproductor MP4',
                style: TextStyle(
                  color: ColoresApp.textoPrincipal,
                  fontWeight: FontWeight.bold,
                  fontSize: 19,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          actions: [
            if (_estaActualizando)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      ColoresApp.acentoPrimario,
                    ),
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Actualizar lista',
                onPressed: () => _cargarVideos(forzarLimpiezaCache: true),
              ),
          ],
        ),
        body: _estaCargando
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    ColoresApp.acentoPrimario,
                  ),
                ),
              )
            : IndexedStack(
                index: _indicePestana,
                children: [
                  PestanaRecientes(
                    videosRecientes: _videosRecientes,
                    alActualizar: _actualizarProgresoEnMemoria,
                  ),
                  PestanaTodosLosVideos(
                    videos: _todosLosVideos,
                    alRefrescar: () => _cargarVideos(forzarLimpiezaCache: true),
                    alActualizar: _actualizarProgresoEnMemoria,
                  ),
                  PestanaCarpetas(
                    key: _clavePestanaCarpetas,
                    carpetasGlobales: _carpetasVideos,
                    alRefrescar: () => _cargarVideos(forzarLimpiezaCache: true),
                    alActualizar: _actualizarProgresoEnMemoria,
                  ),
                ],
              ),
        floatingActionButton: ValueListenableBuilder<EstadoPip>(
          valueListenable: GestorPipGlobal.instancia.estadoPip,
          builder: (context, estado, child) {
            if (estado == EstadoPip.minimizadoInApp) {
              return const SizedBox.shrink();
            }
            return child!;
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: ColoresApp.acentoPrimario.withValues(alpha: 0.35),
                  blurRadius: 14,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: FloatingActionButton(
              elevation: 0,
              backgroundColor: ColoresApp.acentoPrimario,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              tooltip: 'Abrir archivo de video',
              onPressed: _abrirSelectorManual,
              child: const Icon(Icons.folder_open_rounded, size: 24),
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _indicePestana,
          onDestinationSelected: (idx) {
            setState(() {
              _indicePestana = idx;
            });
          },
          destinations: [
            NavigationDestination(
              icon: Badge(
                isLabelVisible: _videosRecientes.isNotEmpty,
                label: Text('${_videosRecientes.length}'),
                backgroundColor: ColoresApp.acentoPrimario,
                child: const Icon(Icons.history_rounded),
              ),
              selectedIcon: Badge(
                isLabelVisible: _videosRecientes.isNotEmpty,
                label: Text('${_videosRecientes.length}'),
                backgroundColor: ColoresApp.acentoPrimario,
                child: const Icon(
                  Icons.history_rounded,
                  color: ColoresApp.acentoPrimario,
                ),
              ),
              label: 'Continuar',
            ),
            NavigationDestination(
              icon: const Icon(Icons.movie_filter_outlined),
              selectedIcon: const Icon(
                Icons.movie_filter_rounded,
                color: ColoresApp.acentoPrimario,
              ),
              label: 'Videos (${_todosLosVideos.length})',
            ),
            NavigationDestination(
              icon: const Icon(Icons.folder_outlined),
              selectedIcon: const Icon(
                Icons.folder_rounded,
                color: ColoresApp.acentoPrimario,
              ),
              label: 'Carpetas (${_carpetasVideos.length})',
            ),
          ],
        ),
      ),
    ),
  );
}
}
