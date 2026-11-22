import 'package:flutter/material.dart';
import '../constantes/colores_app.dart';
import '../modelos/modelo_orden_videos.dart';

/// Hoja modal reutilizable con estética cinemática oscura para elegir el criterio
/// de ordenación predeterminado de los videos.
final class ModalOrdenVideos extends StatelessWidget {
  final CriterioOrdenVideos criterioActual;
  final String titulo;
  final String subtitulo;

  const ModalOrdenVideos({
    super.key,
    required this.criterioActual,
    this.titulo = 'Ordenar videos',
    this.subtitulo = 'Se aplicará por defecto en tus listas y reproducción',
  });

  /// Muestra la hoja modal y devuelve el [CriterioOrdenVideos] seleccionado,
  /// o `null` si el usuario la cerró sin elegir.
  static Future<CriterioOrdenVideos?> mostrar(
    BuildContext context, {
    required CriterioOrdenVideos criterioActual,
    String titulo = 'Ordenar videos',
    String subtitulo = 'Se aplicará por defecto en tus listas y reproducción',
    bool usarNavegadorRaiz = false,
  }) {
    return showModalBottomSheet<CriterioOrdenVideos>(
      context: context,
      useRootNavigator: usarNavegadorRaiz,
      isScrollControlled: true,
      backgroundColor: ColoresApp.fondoSecundario,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: ColoresApp.bordeSutil, width: 1),
      ),
      builder: (ctx) => ModalOrdenVideos(
        criterioActual: criterioActual,
        titulo: titulo,
        subtitulo: subtitulo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alturaMaxima = MediaQuery.sizeOf(context).height * 0.82;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: alturaMaxima),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: SizedBox(
                  width: 38,
                  height: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: ColoresApp.bordeSutil,
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: ColoresApp.acentoPrimario.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.sort_rounded,
                      color: ColoresApp.acentoPrimario,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: const TextStyle(
                            color: ColoresApp.textoPrincipal,
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitulo,
                          style: const TextStyle(
                            color: ColoresApp.textoSecundario,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final criterio in CriterioOrdenVideos.values)
                _OpcionCriterioOrden(
                  criterio: criterio,
                  seleccionado: criterio == criterioActual,
                  alSeleccionar: () => Navigator.of(context).pop(criterio),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _OpcionCriterioOrden extends StatelessWidget {
  final CriterioOrdenVideos criterio;
  final bool seleccionado;
  final VoidCallback alSeleccionar;

  const _OpcionCriterioOrden({
    required this.criterio,
    required this.seleccionado,
    required this.alSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: seleccionado
            ? ColoresApp.acentoPrimario.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: alSeleccionar,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: seleccionado
                    ? ColoresApp.acentoPrimario.withValues(alpha: 0.45)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  criterio.icono,
                  size: 19,
                  color: seleccionado
                      ? ColoresApp.acentoPrimario
                      : ColoresApp.textoSecundario,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        criterio.etiqueta,
                        style: TextStyle(
                          color: seleccionado
                              ? ColoresApp.acentoPrimario
                              : ColoresApp.textoPrincipal,
                          fontSize: 14,
                          fontWeight: seleccionado
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        criterio.descripcion,
                        style: const TextStyle(
                          color: ColoresApp.textoSecundario,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (seleccionado)
                  const Icon(
                    Icons.check_rounded,
                    color: ColoresApp.acentoPrimario,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
