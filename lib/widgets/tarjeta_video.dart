import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constantes/colores_app.dart';
import '../modelos/modelo_video.dart';
import '../servicios/servicio_miniaturas_video.dart';
import '../servicios/servicio_preferencias.dart';
import 'dialogo_informacion_video.dart';

/// Elemento de lista minimalista y compacto para videos sueltos (alta densidad y 60/120 FPS).
class TarjetaVideo extends StatelessWidget {
  final ModeloVideo video;
  final VoidCallback alPresionar;
  final VoidCallback? alReiniciarProgreso;
  final VoidCallback? alAlternarFavorito;

  const TarjetaVideo({
    super.key,
    required this.video,
    required this.alPresionar,
    this.alReiniciarProgreso,
    this.alAlternarFavorito,
  });

  @override
  Widget build(BuildContext context) {
    final estaCompletado = video.estaCompletado;
    final tieneProgreso = video.tieneProgreso;
    final porcentaje = video.porcentajeVisto;
    final esFavorito = video.esFavorito;

    return InkWell(
      onTap: alPresionar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Miniatura cuadrada compacta con soporte de caché en RAM instantánea
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      foregroundDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: estaCompletado
                              ? ColoresApp.acentoVerde
                              : (esFavorito
                                    ? const Color(
                                        0xFFFFD700,
                                      ).withValues(alpha: 0.8)
                                    : (tieneProgreso
                                          ? ColoresApp.acentoAmbar.withValues(
                                              alpha: 0.6,
                                            )
                                          : Colors.white.withValues(
                                              alpha: 0.12,
                                            ))),
                          width: estaCompletado ? 1.5 : 1.2,
                        ),
                      ),
                      child: _construirImagenMiniatura(
                        tieneProgreso,
                        estaCompletado,
                      ),
                    ),

                    // Badge de completado: SOLO aparece al completar de ver el capítulo
                    if (estaCompletado)
                      Positioned(
                        top: 2,
                        left: 2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: ColoresApp.acentoVerde,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.black,
                            size: 10,
                          ),
                        ),
                      ),

                    // Badge de favorito
                    if (esFavorito)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Icon(
                            Icons.star_rounded,
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
                      if (estaCompletado)
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: ColoresApp.acentoVerde,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              video.duracionTotalMs > 0
                                  ? 'Completado  •  ${video.duracionTotalLegible}'
                                  : 'Completado',
                              style: const TextStyle(
                                color: ColoresApp.acentoVerde,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      else if (tieneProgreso)
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
                            color: ColoresApp.textoSecundario.withValues(
                              alpha: 0.75,
                            ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onSelected: (opcion) async {
                    if (opcion == 'reproducir') {
                      alPresionar();
                    } else if (opcion == 'favorito') {
                      final nuevo = await ServicioPreferencias.alternarFavorito(
                        video.ruta,
                      );
                      video.esFavorito = nuevo;
                      alAlternarFavorito?.call();
                    } else if (opcion == 'marcar_visto') {
                      final nuevo =
                          await ServicioPreferencias.alternarCompletado(
                            video.ruta,
                            duracionTotalMs: video.duracionTotalMs,
                          );
                      video.estaCompletado = nuevo;
                      if (nuevo) {
                        video.posicionGuardadaMs = 0;
                      }
                      alReiniciarProgreso?.call();
                    } else if (opcion == 'info') {
                      if (context.mounted) {
                        DialogoInformacionVideo.mostrar(context, video);
                      }
                    } else if (opcion == 'reiniciar' &&
                        alReiniciarProgreso != null) {
                      await ServicioPreferencias.borrarProgresoVideo(
                        video.ruta,
                      );
                      video.posicionGuardadaMs = 0;
                      video.estaCompletado = false;
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
                          Icon(
                            Icons.play_arrow_rounded,
                            color: ColoresApp.acentoPrimario,
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Text('Reproducir'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'favorito',
                      child: Row(
                        children: [
                          Icon(
                            video.esFavorito
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: const Color(0xFFFFD700),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            video.esFavorito
                                ? 'Quitar de Favoritos'
                                : 'Añadir a Favoritos',
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'marcar_visto',
                      child: Row(
                        children: [
                          Icon(
                            estaCompletado
                                ? Icons.unpublished_outlined
                                : Icons.check_circle_outline_rounded,
                            color: ColoresApp.acentoVerde,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            estaCompletado
                                ? 'Marcar como no visto'
                                : 'Marcar como visto',
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'info',
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Colors.white70,
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Text('Información del video'),
                        ],
                      ),
                    ),
                    if (tieneProgreso || estaCompletado)
                      const PopupMenuItem(
                        value: 'reiniciar',
                        child: Row(
                          children: [
                            Icon(
                              Icons.replay_rounded,
                              color: ColoresApp.acentoAmbar,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Text('Reiniciar progreso'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'copiar_ruta',
                      child: Row(
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            color: ColoresApp.textoSecundario,
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Text('Copiar ruta'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Barra delgada de progreso si está en reproducción y no completado
            if (tieneProgreso && !estaCompletado) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 62),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: porcentaje,
                    backgroundColor: const Color(0xFF21262D),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      ColoresApp.acentoAmbar,
                    ),
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

  Widget _construirImagenMiniatura(bool tieneProgreso, bool estaCompletado) {
    final enMemoria = ServicioMiniaturasVideo.obtenerMiniaturaEnMemoria(video);
    if (enMemoria != null) {
      return Image.file(
        File(enMemoria),
        fit: BoxFit.cover,
        cacheWidth: 144,
        cacheHeight: 144,
        filterQuality: FilterQuality.low,
        errorBuilder: (context, error, stackTrace) =>
            _iconoVideo(tieneProgreso, estaCompletado),
      );
    }

    return FutureBuilder<String?>(
      future: ServicioMiniaturasVideo.obtenerMiniatura(video),
      builder: (context, snapshot) {
        final rutaMiniatura = snapshot.data;
        if (rutaMiniatura == null) {
          return _iconoVideo(tieneProgreso, estaCompletado);
        }
        return Image.file(
          File(rutaMiniatura),
          fit: BoxFit.cover,
          cacheWidth: 144,
          cacheHeight: 144,
          filterQuality: FilterQuality.low,
          errorBuilder: (context, error, stackTrace) =>
              _iconoVideo(tieneProgreso, estaCompletado),
        );
      },
    );
  }

  Widget _iconoVideo(bool tieneProgreso, bool estaCompletado) {
    return Icon(
      Icons.movie_creation_outlined,
      color: estaCompletado
          ? ColoresApp.acentoVerde
          : (tieneProgreso ? ColoresApp.acentoAmbar : const Color(0xFF8B949E)),
      size: 24,
    );
  }
}

/// Tarjeta visual para el modo de visualización en Cuadrícula de 2 columnas (Grid View).
class TarjetaVideoCuadricula extends StatelessWidget {
  final ModeloVideo video;
  final VoidCallback alPresionar;
  final VoidCallback? alReiniciarProgreso;
  final VoidCallback? alAlternarFavorito;

  const TarjetaVideoCuadricula({
    super.key,
    required this.video,
    required this.alPresionar,
    this.alReiniciarProgreso,
    this.alAlternarFavorito,
  });

  @override
  Widget build(BuildContext context) {
    final estaCompletado = video.estaCompletado;
    final tieneProgreso = video.tieneProgreso;
    final porcentaje = video.porcentajeVisto;
    final esFavorito = video.esFavorito;

    return InkWell(
      onTap: alPresionar,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: estaCompletado
                ? ColoresApp.acentoVerde
                : (esFavorito
                      ? const Color(0xFFFFD700).withValues(alpha: 0.5)
                      : (tieneProgreso
                            ? ColoresApp.acentoAmbar.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.08))),
            width: estaCompletado ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vista previa de miniatura 16:9
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(11),
                    ),
                    child: _construirImagen(tieneProgreso),
                  ),

                  // Insignia de completado en cuadrícula
                  if (estaCompletado)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: ColoresApp.acentoVerde,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.black,
                          size: 12,
                        ),
                      ),
                    ),

                  // Duración en esquina inferior derecha
                  if (video.duracionTotalMs > 0)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          video.duracionTotalLegible,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // Insignia de favorito
                  if (esFavorito)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFD700),
                          size: 14,
                        ),
                      ),
                    ),

                  // Barra de progreso si está en reproducción y no completado
                  if (tieneProgreso && !estaCompletado)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: porcentaje,
                        backgroundColor: Colors.black45,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          ColoresApp.acentoAmbar,
                        ),
                        minHeight: 3,
                      ),
                    ),
                ],
              ),
            ),

            // Título y metadatos
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        estaCompletado ? 'Completado' : video.tamanoLegible,
                        style: TextStyle(
                          color: estaCompletado
                              ? ColoresApp.acentoVerde
                              : const Color(0xFF8B949E),
                          fontSize: 11,
                          fontWeight: estaCompletado
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          DialogoInformacionVideo.mostrar(context, video);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: Color(0xFF8B949E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirImagen(bool tieneProgreso) {
    final enMemoria = ServicioMiniaturasVideo.obtenerMiniaturaEnMemoria(video);
    if (enMemoria != null) {
      return Image.file(
        File(enMemoria),
        fit: BoxFit.cover,
        cacheWidth: 320,
        cacheHeight: 180,
        filterQuality: FilterQuality.low,
        errorBuilder: (context, error, stackTrace) => _fallbackIcono(),
      );
    }

    return FutureBuilder<String?>(
      future: ServicioMiniaturasVideo.obtenerMiniatura(video),
      builder: (context, snapshot) {
        final rutaMiniatura = snapshot.data;
        if (rutaMiniatura == null) {
          return _fallbackIcono();
        }
        return Image.file(
          File(rutaMiniatura),
          fit: BoxFit.cover,
          cacheWidth: 320,
          cacheHeight: 180,
          filterQuality: FilterQuality.low,
          errorBuilder: (context, error, stackTrace) => _fallbackIcono(),
        );
      },
    );
  }

  Widget _fallbackIcono() {
    return Container(
      color: const Color(0xFF0D1117),
      child: const Center(
        child: Icon(Icons.movie_outlined, color: Color(0xFF8B949E), size: 32),
      ),
    );
  }
}
