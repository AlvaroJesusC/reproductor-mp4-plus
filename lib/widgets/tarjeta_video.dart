import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constantes/colores_app.dart';
import '../modelos/modelo_video.dart';

/// Elemento de lista minimalista y compacto para videos sueltos (alta densidad y 60/120 FPS).
class TarjetaVideo extends StatelessWidget {
  final ModeloVideo video;
  final VoidCallback alPresionar;
  final VoidCallback? alReiniciarProgreso;

  const TarjetaVideo({
    super.key,
    required this.video,
    required this.alPresionar,
    this.alReiniciarProgreso,
  });

  @override
  Widget build(BuildContext context) {
    final tieneProgreso = video.tieneProgreso;
    final porcentaje = video.porcentajeVisto;

    return InkWell(
      onTap: alPresionar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Miniatura cuadrada compacta estilo explorador
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: tieneProgreso ? ColoresApp.acentoAmbar.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.12),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        Icons.movie_creation_outlined,
                        color: tieneProgreso ? ColoresApp.acentoAmbar : const Color(0xFF8B949E),
                        size: 24,
                      ),
                    ),

                    // Badge de visto / en progreso si ya se empezó
                    if (tieneProgreso)
                      Positioned(
                        top: 2,
                        left: 2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: ColoresApp.acentoAmbar,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.black,
                            size: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // Título y duración / progreso
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (tieneProgreso)
                        Text(
                          '${video.tiempoGuardadoLegible} / ${video.duracionTotalLegible}',
                          style: const TextStyle(
                            color: ColoresApp.acentoAmbar,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else
                        Text(
                          video.duracionTotalMs > 0
                              ? '${video.duracionTotalLegible}  •  ${video.tamanoLegible}'
                              : video.tamanoLegible,
                          style: TextStyle(
                            color: ColoresApp.textoSecundario.withValues(alpha: 0.75),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),

                // Menú de opciones (⋮)
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Color(0xFF8B949E),
                    size: 20,
                  ),
                  color: ColoresApp.fondoTarjeta,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (opcion) {
                    if (opcion == 'reproducir') {
                      alPresionar();
                    } else if (opcion == 'reiniciar' && alReiniciarProgreso != null) {
                      alReiniciarProgreso!();
                    } else if (opcion == 'copiar_ruta') {
                      Clipboard.setData(ClipboardData(text: video.ruta));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ruta copiada al portapapeles'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'reproducir',
                      child: Row(
                        children: [
                          Icon(Icons.play_arrow_rounded, color: ColoresApp.acentoPrimario, size: 18),
                          SizedBox(width: 10),
                          Text('Reproducir'),
                        ],
                      ),
                    ),
                    if (tieneProgreso)
                      const PopupMenuItem(
                        value: 'reiniciar',
                        child: Row(
                          children: [
                            Icon(Icons.replay_rounded, color: ColoresApp.acentoAmbar, size: 18),
                            SizedBox(width: 10),
                            Text('Reiniciar progreso'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'copiar_ruta',
                      child: Row(
                        children: [
                          Icon(Icons.copy_rounded, color: ColoresApp.textoSecundario, size: 18),
                          SizedBox(width: 10),
                          Text('Copiar ruta'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Barra delgada de progreso si está en reproducción
            if (tieneProgreso) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 62),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: porcentaje,
                    backgroundColor: const Color(0xFF21262D),
                    valueColor: const AlwaysStoppedAnimation<Color>(ColoresApp.acentoAmbar),
                    minHeight: 2.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
