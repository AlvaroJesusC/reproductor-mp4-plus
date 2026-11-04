import 'package:flutter/material.dart';
import '../constantes/colores_app.dart';
import '../modelos/modelo_carpeta_video.dart';
import '../servicios/servicio_preferencias.dart';
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
  @override
  Widget build(BuildContext context) {
    final videos = widget.carpeta.videos;

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
