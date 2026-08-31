import 'package:flutter/material.dart';
import '../../constantes/colores_app.dart';
import '../../modelos/modelo_video.dart';
import '../../servicios/servicio_preferencias.dart';
import '../../widgets/tarjeta_video.dart';
import '../pantalla_reproductor.dart';

/// Pestaña de videos recientemente reproducidos o en progreso ("Continuar Viendo").
class PestanaRecientes extends StatelessWidget {
  final List<ModeloVideo> videosRecientes;
  final VoidCallback alActualizar;

  const PestanaRecientes({
    super.key,
    required this.videosRecientes,
    required this.alActualizar,
  });

  @override
  Widget build(BuildContext context) {
    if (videosRecientes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: ColoresApp.fondoSecundario,
                  shape: BoxShape.circle,
                  border: Border.all(color: ColoresApp.bordeOSD),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: ColoresApp.textoSecundario,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sin videos en progreso',
                style: TextStyle(
                  color: ColoresApp.textoPrincipal,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cuando comiences a ver una película o serie, aparecerá aquí para que puedas continuar donde la dejaste.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ColoresApp.textoSecundario,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: videosRecientes.length,
      itemBuilder: (context, index) {
        final video = videosRecientes[index];
        return TarjetaVideo(
          video: video,
          alPresionar: () async {
            await PantallaReproductor.abrir(context, video);
            alActualizar();
          },
          alReiniciarProgreso: () async {
            await ServicioPreferencias.borrarProgresoVideo(video.ruta);
            video.posicionGuardadaMs = 0;
            alActualizar();
          },
        );
      },
    );
  }
}
