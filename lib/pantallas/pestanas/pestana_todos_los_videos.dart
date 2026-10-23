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
  todos('Todos'),
  favoritos('Favoritos ⭐'),
  enProgreso('En progreso ⏳'),
  completados('Completados ✅'),
  noVistos('No vistos 🆕');

  final String etiqueta;
  const FiltroCategoria(this.etiqueta);
}

/// Pestaña que lista todos los videos encontrados en el dispositivo con buscador, filtros y cuadrícula.
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
    if (!identical(oldWidget.videos, widget.videos)) {
      _videosVisibles = _calcularVideosVisibles();
    }
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
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...CriterioOrden.values.map((criterio) {
                final seleccionado = criterio == _criterioOrden;
                return ListTile(
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
        // Barra de búsqueda, botón de cuadrícula/lista y botón de ordenamiento
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: ColoresApp.fondoTarjeta,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _controladorBusqueda,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    onChanged: _programarBusqueda,
                    decoration: InputDecoration(
                      hintText: 'Buscar películas o series...',
                      hintStyle: const TextStyle(
                        color: ColoresApp.textoSecundario,
                        fontSize: 14,
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
                  ),
                  padding: const EdgeInsets.all(11),
                ),
                icon: Icon(
                  _modoCuadricula
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                  color: ColoresApp.textoPrincipal,
                  size: 21,
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
                  ),
                  padding: const EdgeInsets.all(11),
                ),
                icon: const Icon(
                  Icons.sort_rounded,
                  color: ColoresApp.textoPrincipal,
                  size: 21,
                ),
                tooltip: 'Ordenar',
                onPressed: _mostrarModalOrden,
              ),
            ],
          ),
        ),

        // Barra de chips de filtros rápidos
        SizedBox(
          height: 38,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            scrollDirection: Axis.horizontal,
            itemCount: FiltroCategoria.values.length,
            separatorBuilder: (_, index) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final cat = FiltroCategoria.values[i];
              final esSeleccionado = cat == _filtroCategoria;

              return ChoiceChip(
                label: Text(cat.etiqueta),
                selected: esSeleccionado,
                selectedColor: ColoresApp.acentoPrimario.withValues(
                  alpha: 0.25,
                ),
                backgroundColor: ColoresApp.fondoSecundario,
                side: BorderSide(
                  color: esSeleccionado
                      ? ColoresApp.acentoPrimario
                      : Colors.white.withValues(alpha: 0.08),
                  width: 1,
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

        // Contador de videos
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${videosFiltrados.length} ${videosFiltrados.length == 1 ? 'video encontrado' : 'videos encontrados'}',
              style: const TextStyle(
                color: ColoresApp.textoSecundario,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),

        // Lista o Cuadrícula de videos con Pull-to-Refresh y optimización de caché
        Expanded(
          child: videosFiltrados.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.video_library_outlined,
                          color: ColoresApp.textoSecundario,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _filtroTexto.isNotEmpty
                              ? 'No se encontraron videos con "$_filtroTexto"'
                              : 'No hay videos para este filtro',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: ColoresApp.textoPrincipal,
                            fontSize: 16,
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
                                    },
                                    alAlternarFavorito: () {
                                      widget.alActualizar();
                                      _actualizarVideosVisibles();
                                    },
                                    alReiniciarProgreso: () {
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
                          itemCount: videosFiltrados.length,
                          itemBuilder: (context, index) {
                            final video = videosFiltrados[index];
                            return RepaintBoundary(
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
