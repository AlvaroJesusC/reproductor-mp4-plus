import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../constantes/colores_app.dart';
import '../modelos/modelo_video.dart';

/// Diálogo con estilo cinemático OLED que muestra la ficha técnica completa del video.
class DialogoInformacionVideo extends StatelessWidget {
  final ModeloVideo video;

  const DialogoInformacionVideo({super.key, required this.video});

  static Future<void> mostrar(BuildContext context, ModeloVideo video) {
    return showDialog(
      context: context,
      builder: (ctx) => DialogoInformacionVideo(video: video),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatoFecha = DateFormat('dd/MM/yyyy • HH:mm');
    final fechaStr = formatoFecha.format(video.fechaModificacion);

    return Dialog(
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1.0,
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ColoresApp.acentoPrimario.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      color: ColoresApp.acentoPrimario,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Información del Video',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Contenedor de detalles
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: [
                    _filaDetalle('Nombre:', video.nombre),
                    const Divider(color: Color(0xFF21262D), height: 16),
                    _filaDetalle(
                      'Duración:',
                      video.duracionTotalMs > 0
                          ? video.duracionTotalLegible
                          : 'Desconocida',
                    ),
                    const Divider(color: Color(0xFF21262D), height: 16),
                    _filaDetalle(
                      'Tamaño:',
                      '${video.tamanoLegible} (${NumberFormat('#,###').format(video.tamanoBytes)} bytes)',
                    ),
                    const Divider(color: Color(0xFF21262D), height: 16),
                    _filaDetalle(
                      'Formato:',
                      video.extension.toUpperCase().isEmpty
                          ? 'VIDEO'
                          : video.extension.toUpperCase(),
                    ),
                    const Divider(color: Color(0xFF21262D), height: 16),
                    _filaDetalle('Carpeta:', video.carpetaContenedora),
                    const Divider(color: Color(0xFF21262D), height: 16),
                    _filaDetalle('Modificado:', fechaStr),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Ruta completa con botón de copia
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_open_rounded,
                      size: 16,
                      color: Color(0xFF8B949E),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        video.ruta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8B949E),
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: Colors.white70,
                      ),
                      tooltip: 'Copiar ruta',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: video.ruta));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ruta copiada al portapapeles'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Botón Cerrar
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: ColoresApp.acentoPrimario,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filaDetalle(String etiqueta, String valor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 85,
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
