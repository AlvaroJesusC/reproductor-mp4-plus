import 'package:flutter/material.dart';
import '../constantes/colores_app.dart';
import '../modelos/modelo_carpeta_video.dart';
import '../modelos/modelo_orden_videos.dart';
import '../modelos/modelo_video.dart';
import '../servicios/servicio_preferencias.dart';
import '../widgets/modal_orden_videos.dart';
import '../widgets/tarjeta_video.dart';
import 'pantalla_reproductor.dart';

/// Pantalla que muestra los videos contenidos dentro de una carpeta seleccionada.
class PantallaDetalleCarpeta extends StatefulWidget {
  final ModeloCarpetaVideo carpeta;

  const PantallaDetalleCarpeta({super.key, required this.carpeta});

  @override
  State<PantallaDetalleCarpeta> createState() => _PantallaDetalleCarpetaState();
}

class _PantallaDetalleCarpetaState extends State<PantallaDetalleCarpeta> {
  late CriterioOrdenVideos _criterioOrden;
  late List<ModeloVideo> _videosOrdenados;

  @override
  void initState() {
    super.initState();
    _criterioOrden = ServicioPreferencias.criterioOrdenNotifier.value;
    _videosOrdenados = OrdenadorVideos.videosOrdenados(
      widget.carpeta.videos,
      _criterioOrden,
    );
    ServicioPreferencias.criterioOrdenNotifier.addListener(
      _alCambiarCriterioGlobal,
    );
  }

  @override
  void dispose() {
    ServicioPreferencias.criterioOrdenNotifier.removeListener(
      _alCambiarCriterioGlobal,
    );
    super.dispose();
  }

  void _alCambiarCriterioGlobal() {
    final nuevo = ServicioPreferencias.criterioOrdenNotifier.value;
    if (!mounted || nuevo == _criterioOrden) return;
    setState(() {
      _criterioOrden = nuevo;
      _videosOrdenados = OrdenadorVideos.videosOrdenados(
        widget.carpeta.videos,
        _criterioOrden,
      );
    });
  }

  Future<void> _mostrarModalOrden() async {
    final seleccionado = await ModalOrdenVideos.mostrar(
      context,
      criterioActual: _criterioOrden,
    );
    if (seleccionado != null && seleccionado != _criterioOrden) {
      if (mounted) {
        setState(() {
          _criterioOrden = seleccionado;
          _videosOrdenados = OrdenadorVideos.videosOrdenados(
            widget.carpeta.videos,
            _criterioOrden,
          );
        });
      }
      await ServicioPreferencias.guardarCriterioOrdenVideos(seleccionado);
    }
  }

  @override
  Widget build(BuildContext context) {
    final videos = _videosOrdenados;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.carpeta.nombre,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '${videos.length} ${videos.length == 1 ? 'video' : 'videos'} • ${widget.carpeta.tamanoTotalLegible}',
              style: const TextStyle(
                fontSize: 12,
                color: ColoresApp.textoSecundario,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Ordenar (${_criterioOrden.etiqueta})',
            onPressed: _mostrarModalOrden,
          ),
        ],
      ),
      body: ListView.builder(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        cacheExtent: 500,
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
                  await ServicioPreferencias.enriquecerVideosConProgreso(
                    videos,
                  );
                  setState(() {});
                }
              },
              alAlternarFavorito: () {
                if (mounted) setState(() {});
              },
              alReiniciarProgreso: () {
                if (mounted) setState(() {});
              },
              alActualizar: () {
                if (mounted) setState(() {});
              },
            ),
          );
        },
      ),
    );
  }
}
