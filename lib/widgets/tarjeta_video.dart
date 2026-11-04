import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constantes/colores_app.dart';
import '../modelos/modelo_video.dart';
import '../servicios/servicio_miniaturas_video.dart';
import '../servicios/servicio_preferencias.dart';
import 'dialogo_informacion_video.dart';

/// Elemento de lista cinemático con miniatura 16:9, duración sobrepuesta
/// y progreso incrustado (60/120 FPS y decodificación acotada).
class TarjetaVideo extends StatelessWidget {
  final ModeloVideo video;
  final VoidCallback alPresionar;
  final VoidCallback? alReiniciarProgreso;
  final VoidCallback? alAlternarFavorito;
  final VoidCallback? alActualizar;

  const TarjetaVideo({
    super.key,
    required this.video,
    required this.alPresionar,
    this.alReiniciarProgreso,
    this.alAlternarFavorito,
    this.alActualizar,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Miniatura 16:9 panorámica (104 x 58.5 px) con pastilla de duración y barra incrustada
            SizedBox(
              width: 104,
              height: 58.5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      color: ColoresApp.fondoTarjeta,
                      child: _construirImagenMiniatura(
                        tieneProgreso,
                        estaCompletado,
                      ),
                    ),
                  ),

                  // Micro-borde sutil
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: estaCompletado
                              ? ColoresApp.acentoVerde.withValues(alpha: 0.5)
                              : (esFavorito
                                    ? const Color(
                                        0xFFFFD700,
                                      ).withValues(alpha: 0.4)
                                    : ColoresApp.bordeSutil),
                          width: 1,
                        ),
                      ),
                    ),
                  ),

                  // Badge sutil de favorito en esquina superior derecha
                  if (esFavorito)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFD700),
                          size: 11,
                        ),
                      ),
                    ),

                  // Badge sutil de completado en esquina superior izquierda
                  if (estaCompletado)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: ColoresApp.acentoVerde.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.black,
                          size: 10,
                        ),
                      ),
                    ),

                  // Pastilla de duración en esquina inferior derecha
                  if (video.duracionTotalMs > 0 && !estaCompletado)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: ColoresApp.fondoPastillaTiempo,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          video.duracionTotalLegible,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ),

                  // Barra delgada de progreso (2 px) incrustada en la base de la miniatura
                  if (tieneProgreso && !estaCompletado)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(8),
                        ),
                        child: LinearProgressIndicator(
                          value: porcentaje,
                          backgroundColor: Colors.black54,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            ColoresApp.acentoAmbar,
                          ),
                          minHeight: 2.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Título y metadatos limpios
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    video.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ColoresApp.textoPrincipal,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (estaCompletado)
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: ColoresApp.acentoVerde,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          video.duracionTotalMs > 0
                              ? 'Completado  •  ${video.duracionTotalLegible}'
                              : 'Completado',
                          style: const TextStyle(
                            color: ColoresApp.acentoVerde,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  else if (tieneProgreso)
                    Row(
                      children: [
                        const Icon(
                          Icons.timelapse_rounded,
                          color: ColoresApp.acentoAmbar,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${video.tiempoGuardadoLegible} / ${video.duracionTotalLegible}',
                          style: const TextStyle(
                            color: ColoresApp.acentoAmbar,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      video.duracionTotalMs > 0
                          ? '${video.duracionTotalLegible}  •  ${video.tamanoLegible}'
                          : video.tamanoLegible,
                      style: const TextStyle(
                        color: ColoresApp.textoSecundario,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),

            // Menú contextual refinado (⋮)
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
                if (opcion == 'reproducir') {
                  alPresionar();
                } else if (opcion == 'favorito') {
                  final nuevo = await ServicioPreferencias.alternarFavorito(
                    video.ruta,
                  );
                  video.esFavorito = nuevo;
                  alAlternarFavorito?.call();
                  alActualizar?.call();
                } else if (opcion == 'marcar_visto') {
                  final nuevo = await ServicioPreferencias.alternarCompletado(
                    video.ruta,
                    duracionTotalMs: video.duracionTotalMs,
                  );
                  video.estaCompletado = nuevo;
                  video.posicionGuardadaMs = 0;
                  alActualizar?.call();
                  alReiniciarProgreso?.call();
                } else if (opcion == 'info') {
                  if (context.mounted) {
                    DialogoInformacionVideo.mostrar(context, video);
                  }
                } else if (opcion == 'reiniciar') {
                  await ServicioPreferencias.borrarProgresoVideo(video.ruta);
                  video.posicionGuardadaMs = 0;
                  video.estaCompletado = false;
                  alActualizar?.call();
                  alReiniciarProgreso?.call();
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
      ),
    );
  }

  Widget _construirImagenMiniatura(bool tieneProgreso, bool estaCompletado) {
    final enMemoria = ServicioMiniaturasVideo.obtenerMiniaturaEnMemoria(video);
    if (enMemoria != null) {
      return Image.file(
        File(enMemoria),
        fit: BoxFit.cover,
        cacheWidth: 260,
        cacheHeight: 146,
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
          cacheWidth: 260,
          cacheHeight: 146,
          filterQuality: FilterQuality.low,
          errorBuilder: (context, error, stackTrace) =>
              _iconoVideo(tieneProgreso, estaCompletado),
        );
      },
    );
  }

  Widget _iconoVideo(bool tieneProgreso, bool estaCompletado) {
    return Center(
      child: Icon(
        Icons.movie_filter_outlined,
        color: estaCompletado
            ? ColoresApp.acentoVerde
            : (tieneProgreso
                  ? ColoresApp.acentoAmbar
                  : ColoresApp.textoAtenuado),
        size: 26,
      ),
    );
  }
}

/// Tarjeta visual para el modo de visualización en Cuadrícula de 2 columnas (Grid View).
class TarjetaVideoCuadricula extends StatelessWidget {
  final ModeloVideo video;
  final VoidCallback alPresionar;
  final VoidCallback? alReiniciarProgreso;
  final VoidCallback? alAlternarFavorito;
  final VoidCallback? alActualizar;

  const TarjetaVideoCuadricula({
    super.key,
    required this.video,
    required this.alPresionar,
    this.alReiniciarProgreso,
    this.alAlternarFavorito,
    this.alActualizar,
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
          color: ColoresApp.fondoTarjeta,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: estaCompletado
                ? ColoresApp.acentoVerde.withValues(alpha: 0.5)
                : (esFavorito
                      ? const Color(0xFFFFD700).withValues(alpha: 0.5)
                      : ColoresApp.bordeSutil),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vista previa de miniatura 16:9 con duración y badges sobrepuestos
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(11),
                    ),
                    child: Container(
                      color: ColoresApp.fondoSecundario,
                      child: _construirImagen(tieneProgreso),
                    ),
                  ),

                  // Insignia sutil de completado en cuadrícula
                  if (estaCompletado)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ColoresApp.acentoVerde,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.black,
                          size: 11,
                        ),
                      ),
                    ),

                  // Duración en esquina inferior derecha estilo YouTube/Netflix
                  if (video.duracionTotalMs > 0)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ColoresApp.fondoPastillaTiempo,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          video.duracionTotalLegible,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
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
                          size: 13,
                        ),
                      ),
                    ),

                  // Barra de progreso incrustada en la base de la miniatura
                  if (tieneProgreso && !estaCompletado)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: porcentaje,
                        backgroundColor: Colors.black54,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          ColoresApp.acentoAmbar,
                        ),
                        minHeight: 2.5,
                      ),
                    ),
                ],
              ),
            ),

            // Título y metadatos limpios
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
                      color: ColoresApp.textoPrincipal,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        estaCompletado
                            ? 'Completado'
                            : (tieneProgreso
                                  ? video.tiempoGuardadoLegible
                                  : video.tamanoLegible),
                        style: TextStyle(
                          color: estaCompletado
                              ? ColoresApp.acentoVerde
                              : (tieneProgreso
                                    ? ColoresApp.acentoAmbar
                                    : ColoresApp.textoSecundario),
                          fontSize: 11,
                          fontWeight: estaCompletado || tieneProgreso
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          size: 16,
                          color: ColoresApp.textoSecundario,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Opciones',
                        color: ColoresApp.fondoTarjeta,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: ColoresApp.bordeSutil,
                            width: 1,
                          ),
                        ),
                        onSelected: (opcion) async {
                          if (opcion == 'reproducir') {
                            alPresionar();
                          } else if (opcion == 'favorito') {
                            final nuevo =
                                await ServicioPreferencias.alternarFavorito(
                              video.ruta,
                            );
                            video.esFavorito = nuevo;
                            alAlternarFavorito?.call();
                            alActualizar?.call();
                          } else if (opcion == 'marcar_visto') {
                            final nuevo =
                                await ServicioPreferencias.alternarCompletado(
                              video.ruta,
                              duracionTotalMs: video.duracionTotalMs,
                            );
                            video.estaCompletado = nuevo;
                            video.posicionGuardadaMs = 0;
                            alActualizar?.call();
                            alReiniciarProgreso?.call();
                          } else if (opcion == 'info') {
                            if (context.mounted) {
                              DialogoInformacionVideo.mostrar(context, video);
                            }
                          } else if (opcion == 'reiniciar') {
                            await ServicioPreferencias.borrarProgresoVideo(
                              video.ruta,
                            );
                            video.posicionGuardadaMs = 0;
                            video.estaCompletado = false;
                            alActualizar?.call();
                            alReiniciarProgreso?.call();
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
                                SizedBox(width: 10),
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
                                SizedBox(width: 10),
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
      color: ColoresApp.fondoSecundario,
      child: const Center(
        child: Icon(
          Icons.movie_outlined,
          color: ColoresApp.textoAtenuado,
          size: 32,
        ),
      ),
    );
  }
}
