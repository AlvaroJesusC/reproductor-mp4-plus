import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constantes/colores_app.dart';
import '../modelos/modelo_video.dart';
import '../servicios/servicio_duracion_video.dart';
import '../servicios/servicio_miniaturas_video.dart';
import '../servicios/servicio_preferencias.dart';
import 'dialogo_informacion_video.dart';

/// Maneja de forma compartida las acciones del menú contextual de una tarjeta de video.
Future<void> _manejarOpcionMenuVideo({
  required BuildContext context,
  required String opcion,
  required ModeloVideo video,
  required VoidCallback alPresionar,
  VoidCallback? alReiniciarProgreso,
  VoidCallback? alAlternarFavorito,
  VoidCallback? alActualizar,
}) async {
  if (opcion == 'reproducir') {
    alPresionar();
    return;
  }

  if (opcion == 'favorito') {
    final nuevo = await ServicioPreferencias.alternarFavorito(video.ruta);
    video.esFavorito = nuevo;
    alAlternarFavorito?.call();
    alActualizar?.call();
    return;
  }

  if (opcion == 'marcar_visto') {
    if (video.duracionTotalMs <= 0) {
      final duracionDetectada = await ServicioDuracionVideo.obtenerDuracion(
        video,
      );
      if (duracionDetectada > 0) {
        video.duracionTotalMs = duracionDetectada;
      }
    }
    final nuevo = await ServicioPreferencias.alternarCompletado(
      video.ruta,
      duracionTotalMs: video.duracionTotalMs,
    );
    video.estaCompletado = nuevo;
    video.posicionGuardadaMs = 0;
    alActualizar?.call();
    alReiniciarProgreso?.call();
    return;
  }

  if (opcion == 'info') {
    if (video.duracionTotalMs <= 0) {
      final duracionDetectada = await ServicioDuracionVideo.obtenerDuracion(
        video,
      );
      if (duracionDetectada > 0) {
        video.duracionTotalMs = duracionDetectada;
      }
    }
    if (context.mounted) {
      await DialogoInformacionVideo.mostrar(context, video);
    }
    return;
  }

  if (opcion == 'reiniciar') {
    await ServicioPreferencias.borrarProgresoVideo(video.ruta);
    video.posicionGuardadaMs = 0;
    video.estaCompletado = false;
    alActualizar?.call();
    alReiniciarProgreso?.call();
    return;
  }

  if (opcion == 'copiar_ruta') {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: video.ruta));
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Ruta copiada al portapapeles'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

/// Construye las opciones compartidas del menú contextual de tarjetas de video.
List<PopupMenuEntry<String>> _construirOpcionesMenuVideo({
  required ModeloVideo video,
  required bool estaCompletado,
  required bool tieneProgreso,
}) {
  return [
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
          Flexible(
            child: Text('Reproducir', overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    ),
    PopupMenuItem(
      value: 'favorito',
      child: Row(
        children: [
          Icon(
            video.esFavorito ? Icons.star_rounded : Icons.star_outline_rounded,
            color: const Color(0xFFFFD700),
            size: 18,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              video.esFavorito ? 'Quitar de Favoritos' : 'Añadir a Favoritos',
              overflow: TextOverflow.ellipsis,
            ),
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
          Flexible(
            child: Text(
              estaCompletado ? 'Marcar como no visto' : 'Marcar como visto',
              overflow: TextOverflow.ellipsis,
            ),
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
          Flexible(
            child: Text(
              'Información del video',
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
            Flexible(
              child: Text(
                'Reiniciar progreso',
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
          Flexible(
            child: Text('Copiar ruta', overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    ),
  ];
}

/// Resuelve la duración de un video de forma sincrónica si está en caché
/// o mediante un único FutureBuilder por tarjeta si aún debe extraerse.
class _ResolvedorDuracionVideo extends StatelessWidget {
  final ModeloVideo video;
  final Widget Function(BuildContext context, int duracionMs) builder;

  const _ResolvedorDuracionVideo({
    required this.video,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final enMemoria = ServicioDuracionVideo.obtenerDuracionEnMemoria(video);
    if (enMemoria != null) {
      return builder(context, enMemoria);
    }

    return FutureBuilder<int>(
      future: ServicioDuracionVideo.obtenerDuracion(video),
      builder: (context, snapshot) {
        final duracionMs = snapshot.data ?? video.duracionTotalMs;
        return builder(context, duracionMs);
      },
    );
  }
}

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

    return _ResolvedorDuracionVideo(
      video: video,
      builder: (context, duracionMs) {
        final textoDuracion = ModeloVideo.formatearTiempo(duracionMs);

        return InkWell(
          onTap: alPresionar,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Miniatura 16:9 panorámica (112 x 63 px) con pastilla de duración y barra incrustada
                SizedBox(
                  width: 112,
                  height: 63,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
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
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: estaCompletado
                                  ? ColoresApp.acentoVerde.withValues(
                                      alpha: 0.5,
                                    )
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
                              color: ColoresApp.acentoVerde.withValues(
                                alpha: 0.9,
                              ),
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
                      if (duracionMs > 0 && !estaCompletado)
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: ColoresApp.fondoPastillaTiempo,
                              borderRadius: BorderRadius.circular(3.5),
                            ),
                            child: Text(
                              textoDuracion,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ),

                      // Barra delgada de progreso (2.5 px) incrustada en la base de la miniatura
                      if (tieneProgreso && !estaCompletado)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(9),
                            ),
                            child: LinearProgressIndicator(
                              value: porcentaje,
                              backgroundColor: Colors.black54,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                ColoresApp.barraProgreso,
                              ),
                              minHeight: 2.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Título y metadatos de duración (sin peso/tamaño de archivo)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        video.nombreSinExtension,
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
                            Flexible(
                              child: Text(
                                duracionMs > 0
                                    ? 'Completado  •  $textoDuracion'
                                    : 'Completado',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: ColoresApp.acentoVerde,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ],
                        )
                      else if (tieneProgreso)
                        Row(
                          children: [
                            const Icon(
                              Icons.play_circle_outline_rounded,
                              color: ColoresApp.acentoAmbar,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                duracionMs > 0
                                    ? '${video.tiempoGuardadoLegible} / $textoDuracion'
                                    : video.tiempoGuardadoLegible,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: ColoresApp.acentoAmbar,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              color: ColoresApp.textoSecundario,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              duracionMs > 0 ? textoDuracion : '--:--',
                              style: const TextStyle(
                                color: ColoresApp.textoSecundario,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
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
                    side: const BorderSide(
                      color: ColoresApp.bordeSutil,
                      width: 1,
                    ),
                  ),
                  onSelected: (opcion) => _manejarOpcionMenuVideo(
                    context: context,
                    opcion: opcion,
                    video: video,
                    alPresionar: alPresionar,
                    alReiniciarProgreso: alReiniciarProgreso,
                    alAlternarFavorito: alAlternarFavorito,
                    alActualizar: alActualizar,
                  ),
                  itemBuilder: (ctx) => _construirOpcionesMenuVideo(
                    video: video,
                    estaCompletado: estaCompletado,
                    tieneProgreso: tieneProgreso,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _construirImagenMiniatura(bool tieneProgreso, bool estaCompletado) {
    final enMemoria = ServicioMiniaturasVideo.obtenerMiniaturaEnMemoria(video);
    if (enMemoria != null) {
      return Image.file(
        File(enMemoria),
        fit: BoxFit.cover,
        cacheWidth: 320,
        filterQuality: FilterQuality.medium,
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
          cacheWidth: 320,
          filterQuality: FilterQuality.medium,
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

    return _ResolvedorDuracionVideo(
      video: video,
      builder: (context, duracionMs) {
        final textoDuracion = ModeloVideo.formatearTiempo(duracionMs);
        final String textoMeta;
        if (estaCompletado) {
          textoMeta = duracionMs > 0
              ? 'Completado • $textoDuracion'
              : 'Completado';
        } else if (tieneProgreso) {
          textoMeta = duracionMs > 0
              ? '${video.tiempoGuardadoLegible} / $textoDuracion'
              : video.tiempoGuardadoLegible;
        } else {
          textoMeta = duracionMs > 0 ? textoDuracion : '--:--';
        }

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
                      if (duracionMs > 0)
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
                              textoDuracion,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                fontFeatures: [FontFeature.tabularFigures()],
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
                              ColoresApp.barraProgreso,
                            ),
                            minHeight: 2.5,
                          ),
                        ),
                    ],
                  ),
                ),

                // Título y metadatos limpios (duración, sin tamaño de archivo)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.nombreSinExtension,
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
                          Expanded(
                            child: Text(
                              textoMeta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: estaCompletado
                                    ? ColoresApp.acentoVerde
                                    : (tieneProgreso
                                          ? ColoresApp.acentoAmbar
                                          : ColoresApp.textoSecundario),
                                fontSize: 11,
                                fontWeight: estaCompletado || tieneProgreso
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
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
                            onSelected: (opcion) => _manejarOpcionMenuVideo(
                              context: context,
                              opcion: opcion,
                              video: video,
                              alPresionar: alPresionar,
                              alReiniciarProgreso: alReiniciarProgreso,
                              alAlternarFavorito: alAlternarFavorito,
                              alActualizar: alActualizar,
                            ),
                            itemBuilder: (ctx) => _construirOpcionesMenuVideo(
                              video: video,
                              estaCompletado: estaCompletado,
                              tieneProgreso: tieneProgreso,
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
      },
    );
  }

  Widget _construirImagen(bool tieneProgreso) {
    final enMemoria = ServicioMiniaturasVideo.obtenerMiniaturaEnMemoria(video);
    if (enMemoria != null) {
      return Image.file(
        File(enMemoria),
        fit: BoxFit.cover,
        cacheWidth: 480,
        filterQuality: FilterQuality.medium,
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
          cacheWidth: 480,
          filterQuality: FilterQuality.medium,
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
