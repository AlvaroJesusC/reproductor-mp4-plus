import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constantes/colores_app.dart';
import '../modelos/modelo_carpeta_video.dart';

/// Elemento de lista estilizado para carpetas con estética de colecciones multimedia.
class TarjetaCarpeta extends StatelessWidget {
  final ModeloCarpetaVideo carpeta;
  final VoidCallback alPresionar;
  final VoidCallback? alReproducirTodo;

  const TarjetaCarpeta({
    super.key,
    required this.carpeta,
    required this.alPresionar,
    this.alReproducirTodo,
  });

  String _construirTextoResumen() {
    if (carpeta.cantidadSubcarpetas > 0 && carpeta.totalVideosMostrar > 0) {
      final subStr = carpeta.cantidadSubcarpetas == 1
          ? '1 carpeta'
          : '${carpeta.cantidadSubcarpetas} carpetas';
      final vidStr = carpeta.totalVideosMostrar == 1
          ? '1 video'
          : '${carpeta.totalVideosMostrar} videos';
      return '$subStr  •  $vidStr';
    } else if (carpeta.cantidadSubcarpetas > 0) {
      return carpeta.cantidadSubcarpetas == 1
          ? '1 subcarpeta'
          : '${carpeta.cantidadSubcarpetas} subcarpetas';
    } else if (carpeta.totalVideosMostrar > 0) {
      return carpeta.totalVideosMostrar == 1
          ? '1 video'
          : '${carpeta.totalVideosMostrar} videos';
    }
    return 'Sin contenido multimedia';
  }

  @override
  Widget build(BuildContext context) {
    final resumen = _construirTextoResumen();

    return InkWell(
      onTap: alPresionar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            // Icono de carpeta de colección multimedia con gradiente sutil y micro-borde
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ColoresApp.acentoAzul.withValues(alpha: 0.18),
                    ColoresApp.fondoTarjeta,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: ColoresApp.acentoAzul.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.folder_rounded,
                color: Color(0xFF60A5FA),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // Nombre y contador de elementos limpio (sin emojis)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    carpeta.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ColoresApp.textoPrincipal,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    resumen,
                    style: const TextStyle(
                      color: ColoresApp.textoSecundario,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // Badge pastilla para el conteo de videos si hay
            if (carpeta.totalVideosMostrar > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: ColoresApp.fondoTarjeta,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ColoresApp.bordeSutil, width: 1),
                ),
                child: Text(
                  '${carpeta.totalVideosMostrar}',
                  style: const TextStyle(
                    color: ColoresApp.textoSecundario,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],

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
              onSelected: (opcion) {
                if (opcion == 'abrir') {
                  alPresionar();
                } else if (opcion == 'copiar_ruta') {
                  Clipboard.setData(ClipboardData(text: carpeta.ruta));
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
                  value: 'abrir',
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_open_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Text('Abrir carpeta'),
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
}
