import 'dart:io';
import 'package:flutter/material.dart';
import '../../constantes/colores_app.dart';
import '../../modelos/modelo_carpeta_video.dart';
import '../../servicios/servicio_almacenamiento_video.dart';
import '../../servicios/servicio_preferencias.dart';
import '../../widgets/tarjeta_carpeta.dart';
import '../../widgets/tarjeta_video.dart';
import '../pantalla_reproductor.dart';

/// Pestaña de carpetas estilo colección multimedia con migas de pan y alto rendimiento.
class PestanaCarpetas extends StatefulWidget {
  final List<ModeloCarpetaVideo> carpetasGlobales;
  final Future<void> Function() alRefrescar;
  final VoidCallback alActualizar;

  const PestanaCarpetas({
    super.key,
    required this.carpetasGlobales,
    required this.alRefrescar,
    required this.alActualizar,
  });

  @override
  State<PestanaCarpetas> createState() => PestanaCarpetasState();
}

class PestanaCarpetasState extends State<PestanaCarpetas> {
  String? _rutaRaizPersonalizada;
  String? _rutaActualExploracion;
  final List<String> _pilaNavegacionRutas = [];

  ResultadoExploracionDirectorio? _resultadoActual;
  bool _estaCargandoDirectorio = false;
  bool _modoTodasLasCarpetas = false;
  bool _mostrarCarpetasOcultas = false;

  final ScrollController _scrollControllerMigas = ScrollController();

  @override
  void initState() {
    super.initState();
    _cargarRutaConfigurada();
  }

  @override
  void dispose() {
    _scrollControllerMigas.dispose();
    super.dispose();
  }

  /// Carga la ruta configurada en caché o '/storage/emulated/0/Movies'.
  Future<void> _cargarRutaConfigurada() async {
    final rutaGuardada =
        await ServicioPreferencias.obtenerCarpetaRaizPersonalizada();
    if (rutaGuardada != null && await Directory(rutaGuardada).exists()) {
      _rutaRaizPersonalizada = rutaGuardada;
      _navegarADirectorio(rutaGuardada, limpiarPila: true);
    } else {
      const rutaMovies = '/storage/emulated/0/Movies';
      if (await Directory(rutaMovies).exists()) {
        _rutaRaizPersonalizada = rutaMovies;
        await ServicioPreferencias.guardarCarpetaRaizPersonalizada(rutaMovies);
        _navegarADirectorio(rutaMovies, limpiarPila: true);
      } else {
        setState(() {
          _modoTodasLasCarpetas = true;
        });
      }
    }
  }

  /// Navega a un directorio específico y carga su contenido de forma asíncrona no bloqueante.
  Future<void> _navegarADirectorio(
    String ruta, {
    bool limpiarPila = false,
  }) async {
    setState(() {
      _estaCargandoDirectorio = true;
      _modoTodasLasCarpetas = false;
      if (limpiarPila) {
        _pilaNavegacionRutas.clear();
      }
      if (!_pilaNavegacionRutas.contains(ruta)) {
        _pilaNavegacionRutas.add(ruta);
      }
      _rutaActualExploracion = ruta;
    });

    final resultado =
        await ServicioAlmacenamientoVideo.explorarDirectorioJerarquico(
          ruta,
          mostrarOcultos: _mostrarCarpetasOcultas,
        );

    if (mounted) {
      setState(() {
        _resultadoActual = resultado;
        _estaCargandoDirectorio = false;
      });

      // Auto-scroll al final de las migas de pan
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollControllerMigas.hasClients) {
          _scrollControllerMigas.animateTo(
            _scrollControllerMigas.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  /// Retrocede un nivel en la jerarquía de carpetas.
  void _retrocederNivel() {
    if (_pilaNavegacionRutas.length > 1) {
      _pilaNavegacionRutas.removeLast();
      final rutaAnterior = _pilaNavegacionRutas.last;
      _navegarADirectorio(rutaAnterior);
    }
  }

  /// Método público para retroceder cuando se presiona el botón Atrás del sistema.
  /// Devuelve true si retrocedió dentro de las carpetas, o false si ya está en la raíz.
  bool retrocederSiEsPosible() {
    if (_modoTodasLasCarpetas) {
      if (_rutaRaizPersonalizada != null) {
        _navegarADirectorio(_rutaRaizPersonalizada!, limpiarPila: true);
        return true;
      }
      return false;
    }

    if (_pilaNavegacionRutas.length > 1) {
      _retrocederNivel();
      return true;
    }
    return false;
  }

  /// Abre el selector de directorios para que el usuario elija su carpeta personalizada.
  Future<void> _elegirNuevaCarpetaRaiz() async {
    final nuevaRuta =
        await ServicioAlmacenamientoVideo.seleccionarCarpetaPersonalizada();
    if (nuevaRuta != null && mounted) {
      setState(() {
        _rutaRaizPersonalizada = nuevaRuta;
      });
      await _navegarADirectorio(nuevaRuta, limpiarPila: true);
      widget.alActualizar();
    }
  }

  /// Descompone la ruta actual en segmentos amigables para las migas de pan (Breadcrumbs).
  List<({String etiqueta, String ruta})> _obtenerSegmentosMigas() {
    final List<({String etiqueta, String ruta})> segmentos = [
      (etiqueta: 'Explorar', ruta: '/storage/emulated/0'),
    ];

    if (_rutaActualExploracion == null || _rutaActualExploracion!.isEmpty) {
      return segmentos;
    }

    final ruta = _rutaActualExploracion!;
    final partes = ruta
        .split(Platform.pathSeparator)
        .where((p) => p.isNotEmpty)
        .toList();

    String acumulado = '';
    for (int i = 0; i < partes.length; i++) {
      final parte = partes[i];
      acumulado += Platform.pathSeparator + parte;

      if (parte == 'storage' || parte == 'emulated') {
        continue;
      }

      String etiquetaVisual = parte;
      if (parte == '0') {
        etiquetaVisual = 'Memoria interna';
      }

      segmentos.add((etiqueta: etiquetaVisual, ruta: acumulado));
    }

    return segmentos;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      body: Column(
        children: [
          // 1. BARRA DE MIGAS DE PAN (BREADCRUMBS) ESTILO EXPLORADOR CINEMÁTICO
          _construirBarraMigasDePan(),

          // 2. LISTA DE ELEMENTOS VIRTUALIZADA CON LAZY LOADING
          Expanded(
            child: _modoTodasLasCarpetas
                ? _construirVistaTodasLasCarpetas()
                : _construirVistaJerarquicaLazy(),
          ),
        ],
      ),
    );
  }

  /// Barra de navegación superior con migas de pan estilo "Explorar > Memoria interna > Movies > ..."
  Widget _construirBarraMigasDePan() {
    final segmentos = _obtenerSegmentosMigas();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: ColoresApp.fondoSecundario,
        border: Border(
          bottom: BorderSide(color: ColoresApp.bordeSutil, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollControllerMigas,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  for (int i = 0; i < segmentos.length; i++) ...[
                    if (i > 0)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: ColoresApp.textoAtenuado,
                          size: 16,
                        ),
                      ),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        final seg = segmentos[i];
                        _navegarADirectorio(seg.ruta);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: i == segmentos.length - 1
                              ? ColoresApp.fondoTarjeta
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: i == segmentos.length - 1
                              ? Border.all(
                                  color: ColoresApp.bordeSutil,
                                  width: 0.8,
                                )
                              : null,
                        ),
                        child: Text(
                          segmentos[i].etiqueta,
                          style: TextStyle(
                            color: i == segmentos.length - 1
                                ? ColoresApp.textoPrincipal
                                : ColoresApp.textoSecundario,
                            fontWeight: i == segmentos.length - 1
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Botón directo para seleccionar carpeta raíz
          IconButton(
            icon: const Icon(
              Icons.create_new_folder_outlined,
              color: ColoresApp.textoSecundario,
              size: 20,
            ),
            tooltip: 'Elegir Carpeta Raíz',
            onPressed: _elegirNuevaCarpetaRaiz,
          ),

          // Menú de opciones de la barra de migas
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: ColoresApp.textoSecundario,
              size: 20,
            ),
            color: ColoresApp.fondoTarjeta,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: ColoresApp.bordeSutil, width: 1),
            ),
            onSelected: (opcion) async {
              if (opcion == 'cambiar_raiz') {
                _elegirNuevaCarpetaRaiz();
              } else if (opcion == 'alternar_ocultos') {
                setState(() {
                  _mostrarCarpetasOcultas = !_mostrarCarpetasOcultas;
                });
                if (_rutaActualExploracion != null) {
                  _navegarADirectorio(_rutaActualExploracion!);
                }
              } else if (opcion == 'ver_todas') {
                setState(() {
                  _modoTodasLasCarpetas = true;
                });
              } else if (opcion == 'ir_raiz') {
                if (_rutaRaizPersonalizada != null) {
                  _navegarADirectorio(
                    _rutaRaizPersonalizada!,
                    limpiarPila: true,
                  );
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'cambiar_raiz',
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      color: ColoresApp.acentoPrimario,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text('Elegir Carpeta Raíz'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'alternar_ocultos',
                child: Row(
                  children: [
                    Icon(
                      _mostrarCarpetasOcultas
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _mostrarCarpetasOcultas
                          ? 'Ocultar archivos (.)'
                          : 'Mostrar archivos (.)',
                    ),
                  ],
                ),
              ),
              if (_rutaRaizPersonalizada != null)
                const PopupMenuItem(
                  value: 'ir_raiz',
                  child: Row(
                    children: [
                      Icon(Icons.home_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 10),
                      Text('Ir a Carpeta Raíz Guardada'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'ver_todas',
                child: Row(
                  children: [
                    Icon(
                      Icons.grid_view_rounded,
                      color: ColoresApp.textoSecundario,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text('Ver Todas las Carpetas del Teléfono'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Vista jerárquica con diseño minimalista de colecciones multimedia.
  Widget _construirVistaJerarquicaLazy() {
    if (_estaCargandoDirectorio) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(ColoresApp.acentoPrimario),
        ),
      );
    }

    final resultado = _resultadoActual;
    if (resultado == null || resultado.estaVacia) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: ColoresApp.fondoTarjeta,
                  shape: BoxShape.circle,
                  border: Border.all(color: ColoresApp.bordeSutil, width: 1),
                ),
                child: const Icon(
                  Icons.folder_open_rounded,
                  color: ColoresApp.textoAtenuado,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Carpeta vacía',
                style: TextStyle(
                  color: ColoresApp.textoPrincipal,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'No se encontraron videos o subcarpetas aquí.',
                style: TextStyle(
                  color: ColoresApp.textoSecundario,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              if (_pilaNavegacionRutas.length > 1)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColoresApp.fondoTarjeta,
                    side: const BorderSide(
                      color: ColoresApp.bordeSutil,
                      width: 1,
                    ),
                  ),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    'Subir nivel',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: _retrocederNivel,
                ),
            ],
          ),
        ),
      );
    }

    final subcarpetas = resultado.subcarpetas;
    final videos = resultado.videosDirectos;

    return RefreshIndicator(
      color: ColoresApp.acentoPrimario,
      backgroundColor: ColoresApp.fondoSecundario,
      onRefresh: () async {
        ServicioAlmacenamientoVideo.limpiarCache();
        if (_rutaActualExploracion != null) {
          await _navegarADirectorio(_rutaActualExploracion!);
        }
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // 1. LISTA DE SUBCARPETAS (Colecciones multimedia)
          if (subcarpetas.isNotEmpty)
            SliverList.builder(
              itemCount: subcarpetas.length,
              itemBuilder: (context, index) {
                final subcarpeta = subcarpetas[index];
                return RepaintBoundary(
                  key: ValueKey(subcarpeta.ruta),
                  child: TarjetaCarpeta(
                    carpeta: subcarpeta,
                    alPresionar: () {
                      _navegarADirectorio(subcarpeta.ruta);
                    },
                  ),
                );
              },
            ),

          // 2. LISTA DE VIDEOS EN EL NIVEL ACTUAL
          if (videos.isNotEmpty)
            SliverList.builder(
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                return RepaintBoundary(
                  key: ValueKey(video.ruta),
                  child: TarjetaVideo(
                    video: video,
                    alPresionar: () async {
                      await PantallaReproductor.abrir(
                        context,
                        video,
                        listaReproduccion: videos,
                        indiceInicial: index,
                      );
                      if (mounted) {
                        setState(() {});
                        widget.alActualizar();
                      }
                    },
                    alAlternarFavorito: () {
                      if (mounted) {
                        setState(() {});
                        widget.alActualizar();
                      }
                    },
                    alActualizar: () {
                      if (mounted) {
                        setState(() {});
                        widget.alActualizar();
                      }
                    },
                  ),
                );
              },
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  /// Vista alternativa para mostrar todas las carpetas globales.
  Widget _construirVistaTodasLasCarpetas() {
    if (widget.carpetasGlobales.isEmpty) {
      return const Center(
        child: Text(
          'No se encontraron carpetas con videos',
          style: TextStyle(color: ColoresApp.textoSecundario),
        ),
      );
    }

    return RefreshIndicator(
      color: ColoresApp.acentoPrimario,
      backgroundColor: ColoresApp.fondoSecundario,
      onRefresh: widget.alRefrescar,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: widget.carpetasGlobales.length,
        itemBuilder: (context, index) {
          final carpeta = widget.carpetasGlobales[index];
          return RepaintBoundary(
            key: ValueKey(carpeta.ruta),
            child: TarjetaCarpeta(
              carpeta: carpeta,
              alPresionar: () {
                _navegarADirectorio(carpeta.ruta);
              },
            ),
          );
        },
      ),
    );
  }
}
