import 'dart:io';

import 'package:flutter/material.dart';
import '../../constantes/colores_app.dart';
import '../../modelos/modelo_video.dart';
import '../../servicios/servicio_miniaturas_video.dart';
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
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.only(top: 10, bottom: 84),
      children: [
        // Encabezado de sección principal
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: ColoresApp.acentoPrimario,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Seguir viendo',
                style: TextStyle(
                  color: ColoresApp.textoPrincipal,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              if (videoHero.carpetaContenedora.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: ColoresApp.fondoTarjeta,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: ColoresApp.bordeSutil, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.folder_outlined,
                        color: ColoresApp.textoSecundario,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Text(
                          videoHero.carpetaContenedora,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ColoresApp.textoSecundario,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // 1. HERO SHOWCASE CINEMÁTICO DEL ÚLTIMO VIDEO
        RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _construirHeroCard(context, videoHero),
          ),
        ),

        // 2. LISTA DE OTROS VIDEOS EN PROGRESO (SI EXISTEN)
        if (otrosVideos.isNotEmpty) ...[
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'También en progreso',
                  style: TextStyle(
                    color: ColoresApp.textoPrincipal,
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: ColoresApp.fondoTarjeta,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ColoresApp.bordeSutil, width: 1),
                  ),
                  child: Text(
                    '${otrosVideos.length}',
                    style: const TextStyle(
                      color: ColoresApp.textoSecundario,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
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
                alReiniciarProgreso: alActualizar,
                alAlternarFavorito: alActualizar,
                alActualizar: alActualizar,
              ),
            );
          }),
        ],
      ],
    );
  }

  /// Construye la tarjeta Hero destacada 16:9 con miniatura HD nítida, gradiente cinemático y barra carmesí.
  Widget _construirHeroCard(BuildContext context, ModeloVideo video) {
    final porcentaje = video.porcentajeVisto;
    final porcentajeEntero = (porcentaje * 100).round().clamp(1, 99);
    final restanteMs = video.duracionTotalMs - video.posicionGuardadaMs;
    final minutosRestantes = restanteMs > 0 ? (restanteMs / 60000).ceil() : 0;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Fondo con miniatura HD nítida (640p preservando relación de aspecto real)
            _construirFondoHero(video),

            // Gradiente cinemático calibrado: deja limpio y nítido el 65% superior de la imagen
            // y oscurece suavemente la base para máxima legibilidad del texto.
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                    ColoresApp.fondoPrincipal.withValues(alpha: 0.96),
                  ],
                  stops: const [0.0, 0.42, 0.72, 1.0],
                ),
              ),
            ),

            // Pastilla superior derecha con marca de tiempo exacta
            if (video.duracionTotalMs > 0)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xBF0A0D14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    '${video.tiempoGuardadoLegible} / ${video.duracionTotalLegible}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),

            // Botón central refinado con anillo sutil y gradiente carmesí
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ColoresApp.acentoPrimario,
                      Color(0xFFD91642),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ColoresApp.acentoPrimario.withValues(alpha: 0.40),
                      blurRadius: 18,
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

            // Información inferior: Insignia, tiempo restante, porcentaje y título limpio
            Positioned(
              left: 14,
              right: 14,
              bottom: 13,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: ColoresApp.acentoPrimario.withValues(
                            alpha: 0.24,
                          ),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: ColoresApp.acentoPrimario.withValues(
                              alpha: 0.65,
                            ),
                            width: 0.8,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_circle_fill_rounded,
                              color: ColoresApp.acentoPrimario,
                              size: 11,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'CONTINUAR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
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
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$porcentajeEntero%',
                        style: const TextStyle(
                          color: ColoresApp.textoSecundario,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    video.nombreSinExtension,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),

            // Barra de línea de tiempo cinemática con gradiente carmesí-rosa (reemplaza el naranja)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 4,
              child: ColoredBox(
                color: Colors.white.withValues(alpha: 0.14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: porcentaje.clamp(0.0, 1.0),
                    heightFactor: 1.0,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ColoresApp.acentoPrimario,
                            ColoresApp.acentoSecundario,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Todo el Hero es clickeable con efecto ripple sutil
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
        filterQuality: FilterQuality.medium,
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
          filterQuality: FilterQuality.medium,
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
