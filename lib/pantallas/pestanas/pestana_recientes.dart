import 'dart:io';

import 'package:flutter/material.dart';
import '../../constantes/colores_app.dart';
import '../../modelos/modelo_video.dart';
import '../../servicios/servicio_miniaturas_video.dart';
import '../../servicios/servicio_preferencias.dart';
import '../../widgets/tarjeta_video.dart';
import '../pantalla_reproductor.dart';

/// Pestaña de videos recientemente reproducidos con Hero Showcase cinematográfico para reanudar al instante.
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
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: ColoresApp.fondoTarjeta,
                  shape: BoxShape.circle,
                  border: Border.all(color: ColoresApp.bordeSutil, width: 1),
                ),
                child: const Icon(
                  Icons.movie_filter_outlined,
                  color: ColoresApp.textoAtenuado,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Sin videos en progreso',
                style: TextStyle(
                  color: ColoresApp.textoPrincipal,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cuando comiences a ver una película o serie, aparecerá aquí con acceso rápido para continuar donde la dejaste.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ColoresApp.textoSecundario,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final videoHero = videosRecientes.first;
    final otrosVideos = videosRecientes.length > 1
        ? videosRecientes.sublist(1)
        : <ModeloVideo>[];

    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 80),
      children: [
        // 1. HERO SHOWCASE CINEMÁTICO DEL ÚLTIMO VIDEO
        RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _construirHeroCard(context, videoHero),
          ),
        ),

        // 2. LISTA DE OTROS VIDEOS EN PROGRESO (SI EXISTEN)
        if (otrosVideos.isNotEmpty) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Otros en progreso',
                  style: TextStyle(
                    color: ColoresApp.textoPrincipal,
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  '${otrosVideos.length}',
                  style: const TextStyle(
                    color: ColoresApp.textoSecundario,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ...otrosVideos.asMap().entries.map((entry) {
            final index = entry.key + 1; // Índice en videosRecientes
            final video = entry.value;

            return RepaintBoundary(
              key: ValueKey(video.ruta),
              child: TarjetaVideo(
                video: video,
                alPresionar: () async {
                  await PantallaReproductor.abrir(
                    context,
                    video,
                    listaReproduccion: videosRecientes,
                    indiceInicial: index,
                  );
                  alActualizar();
                },
                alReiniciarProgreso: () async {
                  await ServicioPreferencias.borrarProgresoVideo(video.ruta);
                  video.posicionGuardadaMs = 0;
                  alActualizar();
                },
                alAlternarFavorito: alActualizar,
              ),
            );
          }),
        ],
      ],
    );
  }

  /// Construye la tarjeta Hero destacada 16:9 con gradiente, botón de continuar y metadatos.
  Widget _construirHeroCard(BuildContext context, ModeloVideo video) {
    final porcentaje = video.porcentajeVisto;
    final restanteMs = video.duracionTotalMs - video.posicionGuardadaMs;
    final minutosRestantes = restanteMs > 0 ? (restanteMs / 60000).ceil() : 0;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ColoresApp.bordeSutil, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Fondo con miniatura recortada (cache acotado a 640x360 para 60/120 FPS)
            _construirFondoHero(video),

            // Gradiente oscuro cinemático para garantizar contraste
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.45),
                    ColoresApp.fondoPrincipal.withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // Botón central translúcido para continuar
            Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(32),
                  onTap: () async {
                    await PantallaReproductor.abrir(
                      context,
                      video,
                      listaReproduccion: videosRecientes,
                      indiceInicial: 0,
                    );
                    alActualizar();
                  },
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: ColoresApp.acentoPrimario.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: ColoresApp.acentoPrimario.withValues(
                            alpha: 0.35,
                          ),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
              ),
            ),

            // Información inferior: Título, progreso y tiempo restante
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ColoresApp.acentoPrimario.withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: ColoresApp.acentoPrimario.withValues(
                              alpha: 0.5,
                            ),
                            width: 0.8,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history_rounded,
                              color: ColoresApp.acentoPrimario,
                              size: 11,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'CONTINUAR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        minutosRestantes > 0
                            ? 'Faltan $minutosRestantes min'
                            : '${video.tiempoGuardadoLegible} / ${video.duracionTotalLegible}',
                        style: const TextStyle(
                          color: ColoresApp.acentoAmbar,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    video.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),

            // Barra de progreso delgada incrustada en el borde inferior
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(
                value: porcentaje,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  ColoresApp.acentoAmbar,
                ),
                minHeight: 3,
              ),
            ),

            // Todo el Hero es clickeable
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    await PantallaReproductor.abrir(
                      context,
                      video,
                      listaReproduccion: videosRecientes,
                      indiceInicial: 0,
                    );
                    alActualizar();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirFondoHero(ModeloVideo video) {
    final enMemoria = ServicioMiniaturasVideo.obtenerMiniaturaEnMemoria(video);
    if (enMemoria != null) {
      return Image.file(
        File(enMemoria),
        fit: BoxFit.cover,
        cacheWidth: 640,
        cacheHeight: 360,
        filterQuality: FilterQuality.low,
        errorBuilder: (context, error, stackTrace) => _fallbackHero(),
      );
    }

    return FutureBuilder<String?>(
      future: ServicioMiniaturasVideo.obtenerMiniatura(video),
      builder: (context, snapshot) {
        final rutaMiniatura = snapshot.data;
        if (rutaMiniatura == null) {
          return _fallbackHero();
        }
        return Image.file(
          File(rutaMiniatura),
          fit: BoxFit.cover,
          cacheWidth: 640,
          cacheHeight: 360,
          filterQuality: FilterQuality.low,
          errorBuilder: (context, error, stackTrace) => _fallbackHero(),
        );
      },
    );
  }

  Widget _fallbackHero() {
    return Container(
      color: ColoresApp.fondoTarjeta,
      child: const Center(
        child: Icon(
          Icons.movie_filter_rounded,
          color: ColoresApp.textoAtenuado,
          size: 48,
        ),
      ),
    );
  }
}
