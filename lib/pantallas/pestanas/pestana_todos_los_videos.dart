import 'dart:async';

import 'package:flutter/material.dart';
import '../../constantes/colores_app.dart';
import '../../modelos/modelo_video.dart';
import '../../servicios/servicio_preferencias.dart';
import '../../widgets/tarjeta_video.dart';
import '../pantalla_reproductor.dart';

enum CriterioOrden {
  fechaReciente('Más recientes'),
  fechaAntigua('Más antiguos'),
  nombreAz('Nombre (A - Z)'),
  tamanoMayor('Mayor tamaño');

  final String etiqueta;
  const CriterioOrden(this.etiqueta);
}

enum FiltroCategoria {
  todos('Todos', Icons.apps_rounded),
  favoritos('Favoritos', Icons.star_rounded),
  enProgreso('En progreso', Icons.timelapse_rounded),
  completados('Completados', Icons.check_circle_rounded),
  noVistos('No vistos', Icons.fiber_new_rounded);

  final String etiqueta;
  final IconData icono;
  const FiltroCategoria(this.etiqueta, this.icono);
}

/// Pestaña que lista todos los videos encontrados en el dispositivo con buscador,
/// chips con iconos vectoriales (cero emojis), selector de vista y ordenación.
class PestanaTodosLosVideos extends StatefulWidget {
  final List<ModeloVideo> videos;
  final Future<void> Function() alRefrescar;
  final VoidCallback alActualizar;

  const PestanaTodosLosVideos({
    super.key,
    required this.videos,
    required this.alRefrescar,
    required this.alActualizar,
  });

  @override
  State<PestanaTodosLosVideos> createState() => _PestanaTodosLosVideosState();
}

class _PestanaTodosLosVideosState extends State<PestanaTodosLosVideos> {
  final TextEditingController _controladorBusqueda = TextEditingController();
  Timer? _temporizadorBusqueda;
  String _filtroTexto = '';
  CriterioOrden _criterioOrden = CriterioOrden.fechaReciente;
  FiltroCategoria _filtroCategoria = FiltroCategoria.todos;
  bool _modoCuadricula = false;
  late List<ModeloVideo> _videosVisibles;

  @override
  void initState() {
    super.initState();
    _videosVisibles = _calcularVideosVisibles();
    ServicioPreferencias.obtenerModoVistaCuadricula().then((esCuadricula) {
      if (mounted) {
        setState(() {
          _modoCuadricula = esCuadricula;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant PestanaTodosLosVideos oldWidget) {
    super.didUpdateWidget(oldWidget);
    _videosVisibles = _calcularVideosVisibles();
  }

  @override
  void dispose() {
    _temporizadorBusqueda?.cancel();
    _controladorBusqueda.dispose();
    super.dispose();
  }

  List<ModeloVideo> _calcularVideosVisibles() {
    final filtroNormalizado = _filtroTexto.trim().toLowerCase();
    final lista = widget.videos.where((v) {
      // 1. Filtro por categoría rápida
      if (_filtroCategoria == FiltroCategoria.favoritos && !v.esFavorito) {
        return false;
      }
      if (_filtroCategoria == FiltroCategoria.enProgreso && !v.tieneProgreso) {
        return false;
      }
      if (_filtroCategoria == FiltroCategoria.completados &&
          !v.estaCompletado) {
        return false;
      }
      if (_filtroCategoria == FiltroCategoria.noVistos &&
          (v.posicionGuardadaMs > 0 || v.estaCompletado)) {
        return false;
      }

      // 2. Filtro por texto
      if (filtroNormalizado.isEmpty) return true;
      return v.nombreSinExtension.toLowerCase().contains(filtroNormalizado) ||
          v.carpetaContenedora.toLowerCase().contains(filtroNormalizado);
    }).toList();

    switch (_criterioOrden) {
      case CriterioOrden.fechaReciente:
        lista.sort(
          (a, b) => b.fechaModificacion.compareTo(a.fechaModificacion),
        );
        break;
      case CriterioOrden.fechaAntigua:
        lista.sort(
          (a, b) => a.fechaModificacion.compareTo(b.fechaModificacion),
        );
        break;
      case CriterioOrden.nombreAz:
        lista.sort(
          (a, b) => a.nombreSinExtension.toLowerCase().compareTo(
            b.nombreSinExtension.toLowerCase(),
          ),
        );
        break;
      case CriterioOrden.tamanoMayor:
        lista.sort((a, b) => b.tamanoBytes.compareTo(a.tamanoBytes));
        break;
    }

    return lista;
  }

  void _actualizarVideosVisibles() {
    setState(() {
      _videosVisibles = _calcularVideosVisibles();
    });
  }

  void _programarBusqueda(String valor) {
    _temporizadorBusqueda?.cancel();
    _temporizadorBusqueda = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      _filtroTexto = valor;
      _actualizarVideosVisibles();
    });
  }

  void _alternarModoVista() {
    setState(() {
      _modoCuadricula = !_modoCuadricula;
    });
    ServicioPreferencias.guardarModoVistaCuadricula(_modoCuadricula);
  }

  void _mostrarModalOrden() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ColoresApp.fondoSecundario,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: ColoresApp.bordeSutil, width: 1),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ordenar videos por:',
                style: TextStyle(
                  color: ColoresApp.textoPrincipal,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 12),
              ...CriterioOrden.values.map((criterio) {
                final seleccionado = criterio == _criterioOrden;
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  title: Text(
                    criterio.etiqueta,
                    style: TextStyle(
                      color: seleccionado
                          ? ColoresApp.acentoPrimario
                          : ColoresApp.textoPrincipal,
                      fontWeight: seleccionado
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: seleccionado
                      ? const Icon(
                          Icons.check_rounded,
                          color: ColoresApp.acentoPrimario,
                        )
                      : null,
                  onTap: () {
                    _criterioOrden = criterio;
                    _actualizarVideosVisibles();
                    Navigator.of(ctx).pop();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final videosFiltrados = _videosVisibles;

    return Column(
      children: [
        // 1. BARRA DE BÚSQUEDA Y ACCIONES (ESTILIZADA CON MICRO-BORDES)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: ColoresApp.fondoTarjeta,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ColoresApp.bordeSutil, width: 1),
                  ),
                  child: TextField(
                    controller: _controladorBusqueda,
                    style: const TextStyle(
                      color: ColoresApp.textoPrincipal,
                      fontSize: 13.5,
                    ),
                    onChanged: _programarBusqueda,
                    decoration: InputDecoration(
                      hintText: 'Buscar películas o series...',
                      hintStyle: const TextStyle(
                        color: ColoresApp.textoSecundario,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: ColoresApp.textoSecundario,
                        size: 20,
                      ),
                      suffixIcon: _filtroTexto.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear_rounded,
                                color: ColoresApp.textoSecundario,
                                size: 18,
                              ),
                              onPressed: () {
                                _temporizadorBusqueda?.cancel();
                                _controladorBusqueda.clear();
                                _filtroTexto = '';
                                _actualizarVideosVisibles();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Botón alternar Cuadrícula / Lista
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: ColoresApp.fondoTarjeta,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(
                      color: ColoresApp.bordeSutil,
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(10),
                ),
                icon: Icon(
                  _modoCuadricula
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                  color: ColoresApp.textoPrincipal,
                  size: 20,
                ),
                tooltip: _modoCuadricula
                    ? 'Vista en lista'
                    : 'Vista en cuadrícula',
                onPressed: _alternarModoVista,
              ),
              const SizedBox(width: 6),

              // Botón de ordenamiento
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: ColoresApp.fondoTarjeta,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(
                      color: ColoresApp.bordeSutil,
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(10),
                ),
                icon: const Icon(
                  Icons.sort_rounded,
                  color: ColoresApp.textoPrincipal,
                  size: 20,
                ),
                tooltip: 'Ordenar',
                onPressed: _mostrarModalOrden,
              ),
            ],
          ),
        ),

        // 2. BARRA DE CHIPS CON ICONOS VECTORIALES (ANTI-AI-SLOP: CERO EMOJIS)
        SizedBox(
          height: 38,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: FiltroCategoria.values.length,
            separatorBuilder: (_, index) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final cat = FiltroCategoria.values[i];
              final esSeleccionado = cat == _filtroCategoria;

              return ChoiceChip(
                showCheckmark: false,
                avatar: Icon(
                  cat.icono,
                  size: 15,
                  color: esSeleccionado
                      ? Colors.white
                      : ColoresApp.textoSecundario,
                ),
                label: Text(cat.etiqueta),
                selected: esSeleccionado,
                selectedColor: ColoresApp.acentoPrimario.withValues(alpha: 0.22),
                backgroundColor: ColoresApp.fondoTarjeta,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: esSeleccionado
                        ? ColoresApp.acentoPrimario.withValues(alpha: 0.6)
                        : ColoresApp.bordeSutil,
                    width: 1,
                  ),
                ),
                labelStyle: TextStyle(
                  color: esSeleccionado
                      ? Colors.white
                      : ColoresApp.textoSecundario,
                  fontWeight: esSeleccionado
                      ? FontWeight.bold
                      : FontWeight.w500,
                  fontSize: 12,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _filtroCategoria = cat;
                    });
                    _actualizarVideosVisibles();
                  }
                },
              );
            },
          ),
        ),

        // 3. CONTADOR Y ESTADO DE FILTRADO
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text(
                '${videosFiltrados.length} ${videosFiltrados.length == 1 ? 'video' : 'videos'}',
                style: const TextStyle(
                  color: ColoresApp.textoSecundario,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_filtroTexto.isNotEmpty ||
                  _filtroCategoria != FiltroCategoria.todos) ...[
                const SizedBox(width: 6),
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: ColoresApp.acentoPrimario,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'filtrados',
                  style: TextStyle(
                    color: ColoresApp.acentoPrimario.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),

        // 4. LISTA O CUADRÍCULA DE VIDEOS
        Expanded(
          child: videosFiltrados.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: ColoresApp.fondoTarjeta,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: ColoresApp.bordeSutil,
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.video_library_outlined,
                            color: ColoresApp.textoAtenuado,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _filtroTexto.isNotEmpty
                              ? 'No se encontraron videos con "$_filtroTexto"'
                              : 'No hay videos en esta sección',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: ColoresApp.textoPrincipal,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: ColoresApp.acentoPrimario,
                  backgroundColor: ColoresApp.fondoSecundario,
                  onRefresh: widget.alRefrescar,
                  child: _modoCuadricula
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            final columnas = constraints.maxWidth >= 840
                                ? 4
                                : (constraints.maxWidth >= 540 ? 3 : 2);
                            return GridView.builder(
                              key: const PageStorageKey('grid_videos'),
                              padding: const EdgeInsets.fromLTRB(14, 6, 14, 80),
                              cacheExtent: 600,
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columnas,
                                    childAspectRatio: 0.84,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                              itemCount: videosFiltrados.length,
                              itemBuilder: (context, index) {
                                final video = videosFiltrados[index];
                                return RepaintBoundary(
                                  key: ValueKey(video.ruta),
                                  child: TarjetaVideoCuadricula(
                                    video: video,
                                    alPresionar: () async {
                                      await PantallaReproductor.abrir(
                                        context,
                                        video,
                                        listaReproduccion: videosFiltrados,
                                        indiceInicial: index,
                                      );
                                      widget.alActualizar();
                                      _actualizarVideosVisibles();
                                    },
                                    alAlternarFavorito: () {
                                      widget.alActualizar();
                                      _actualizarVideosVisibles();
                                    },
                                    alReiniciarProgreso: () {
                                      widget.alActualizar();
                                      _actualizarVideosVisibles();
                                    },
                                    alActualizar: () {
                                      widget.alActualizar();
                                      _actualizarVideosVisibles();
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        )
                      : ListView.builder(
                          key: const PageStorageKey('lista_videos'),
                          padding: const EdgeInsets.only(top: 4, bottom: 80),
                          cacheExtent: 600,
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          itemCount: videosFiltrados.length,
                          itemBuilder: (context, index) {
                            final video = videosFiltrados[index];
                            return RepaintBoundary(
                              key: ValueKey(video.ruta),
                              child: TarjetaVideo(
                                video: video,
                                alPresionar: () async {
                                  await PantallaReproductor.abrir(
                                    context,
                                    video,
                                    listaReproduccion: videosFiltrados,
                                    indiceInicial: index,
                                  );
                                  widget.alActualizar();
                                  _actualizarVideosVisibles();
                                },
                                alAlternarFavorito: () {
                                  widget.alActualizar();
                                  _actualizarVideosVisibles();
                                },
                                alReiniciarProgreso: () {
                                  widget.alActualizar();
                                  _actualizarVideosVisibles();
                                },
                                alActualizar: () {
                                  widget.alActualizar();
                                  _actualizarVideosVisibles();
                                },
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}
