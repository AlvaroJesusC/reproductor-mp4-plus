import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constantes/colores_app.dart';
import '../modelos/modelo_carpeta_video.dart';

/// Elemento de lista minimalista de carpeta estilo explorador de archivos.
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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: alPresionar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Icono de carpeta outline estilo explorador (como en la captura)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF1E232B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.folder_outlined,
                color: Color(0xFFD0D7DE),
                size: 26,
              ),
            ),
            const SizedBox(width: 16),

            // Nombre y contador de elementos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    carpeta.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    carpeta.resumenElementos,
                    style: TextStyle(
                      color: ColoresApp.textoSecundario.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // Menú contextual de 3 puntos (⋮)
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: Color(0xFF8B949E),
                size: 20,
              ),
              color: ColoresApp.fondoTarjeta,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      Icon(Icons.folder_open_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 10),
                      Text('Abrir carpeta'),
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
      ),
    );
  }
}
