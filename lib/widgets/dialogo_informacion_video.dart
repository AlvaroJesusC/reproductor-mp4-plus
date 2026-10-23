import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constantes/colores_app.dart';
import '../modelos/modelo_video.dart';

/// Diálogo con estilo cinemático OLED que muestra la ficha técnica completa del video.
class DialogoInformacionVideo extends StatelessWidget {
  final ModeloVideo video;
  final int? ancho;
  final int? alto;
  final double? fps;

  const DialogoInformacionVideo({
    super.key,
    required this.video,
    this.ancho,
    this.alto,
    this.fps,
  });

  static Future<void> mostrar(
    BuildContext context,
    ModeloVideo video, {
    int? ancho,
    int? alto,
    double? fps,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (ctx) => DialogoInformacionVideo(
        video: video,
        ancho: ancho,
        alto: alto,
        fps: fps,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatoFecha = DateFormat('dd/MM/yyyy • HH:mm');
    final fechaStr = formatoFecha.format(video.fechaModificacion);

    // Formateo de calidad (resolución) y FPS
    final String textoCalidad;
    if (ancho != null && alto != null && ancho! > 0 && alto! > 0) {
      if (fps != null && fps! > 0) {
        final fpsNum = fps! % 1 == 0
            ? fps!.toInt().toString()
            : fps!.toStringAsFixed(fps! >= 100 ? 0 : 2);
        textoCalidad = '$ancho × $alto • $fpsNum fps';
      } else {
        textoCalidad = '$ancho × $alto';
      }
    } else if (fps != null && fps! > 0) {
      final fpsNum = fps! % 1 == 0
          ? fps!.toInt().toString()
          : fps!.toStringAsFixed(fps! >= 100 ? 0 : 2);
      textoCalidad = '$fpsNum fps';
    } else {
      textoCalidad = 'No disponible';
    }

    final formatoStr = video.extension.isNotEmpty
        ? video.extension.toUpperCase()
        : 'VIDEO';
    final duracionStr = video.duracionTotalMs > 0
        ? video.duracionTotalLegible
        : 'Desconocida';
    final tamanoStr =
        '${video.tamanoLegible} (${NumberFormat('#,###').format(video.tamanoBytes)} B)';

    return Dialog(
      backgroundColor: ColoresApp.fondoModalTranslucido,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.0,
        ),
      ),
      child: RepaintBoundary(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final esHorizontal = constraints.maxWidth >= 420;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. ENCABEZADO COMPACTO CON BOTÓN CERRAR INTEGRADO
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: ColoresApp.acentoPrimario.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.info_outline_rounded,
                            color: ColoresApp.acentoPrimario,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Información del Video',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                          tooltip: 'Cerrar',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 2. CONTENEDOR DE DETALLES ACOPLADO (CERO SCROLL)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Nombre en ancho completo
                          _filaDetalle('Nombre:', video.nombre, maxLines: 2),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Divider(
                              color: Colors.white.withValues(alpha: 0.08),
                              height: 1,
                            ),
                          ),

                          // En pantallas anchas/horizontal usamos 2 columnas ergonómicas
                          if (esHorizontal)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _filaDetalle('Calidad:', textoCalidad),
                                      const SizedBox(height: 8),
                                      _filaDetalle('Formato:', formatoStr),
                                      const SizedBox(height: 8),
                                      _filaDetalle(
                                        'Carpeta:',
                                        video.carpetaContenedora,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _filaDetalle('Duración:', duracionStr),
                                      const SizedBox(height: 8),
                                      _filaDetalle('Tamaño:', tamanoStr),
                                      const SizedBox(height: 8),
                                      _filaDetalle('Modificado:', fechaStr),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _filaDetalle('Calidad:', textoCalidad),
                                const SizedBox(height: 8),
                                _filaDetalle('Duración:', duracionStr),
                                const SizedBox(height: 8),
                                _filaDetalle('Tamaño:', tamanoStr),
                                const SizedBox(height: 8),
                                _filaDetalle('Formato:', formatoStr),
                                const SizedBox(height: 8),
                                _filaDetalle('Carpeta:', video.carpetaContenedora),
                                const SizedBox(height: 8),
                                _filaDetalle('Modificado:', fechaStr),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _filaDetalle(String etiqueta, String valor, {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(
            etiqueta,
            style: const TextStyle(
              color: Color(0xFF8B949E),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            valor,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
