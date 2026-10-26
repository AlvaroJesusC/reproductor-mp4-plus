import 'package:flutter/material.dart';
import '../../constantes/colores_app.dart';

/// Panel lateral de ajustes y opciones ultraligero a 60/120 FPS sin jank ni lag.
/// Utiliza baja opacidad (45%) para no tapar el video, micro-bordes y cero BackdropFilter.
class PanelLateralOpciones extends StatelessWidget {
  final double velocidadActual;
  final bool esPantallaCompletaHorizontal;
  final bool zoomActivo;
  final VoidCallback? alRestablecerZoom;
  final VoidCallback? alActivarPipNativo;
  final VoidCallback alMostrarModalVelocidad;
  final VoidCallback? alMostrarSincronizacion;
  final VoidCallback? alMostrarInfoVideo;
  final VoidCallback alAlternarOrientacion;
  final VoidCallback? alLiberarOrientacion;

  const PanelLateralOpciones({
    super.key,
    required this.velocidadActual,
    required this.esPantallaCompletaHorizontal,
    this.zoomActivo = false,
    this.alRestablecerZoom,
    this.alActivarPipNativo,
    required this.alMostrarModalVelocidad,
    this.alMostrarSincronizacion,
    this.alMostrarInfoVideo,
    required this.alAlternarOrientacion,
    this.alLiberarOrientacion,
  });

  /// Despliega el panel lateral desde la derecha a la izquierda de forma instantánea y fluida.
  static Future<void> mostrar(
    BuildContext context, {
    required double velocidadActual,
    required bool esPantallaCompletaHorizontal,
    bool zoomActivo = false,
    VoidCallback? alRestablecerZoom,
    VoidCallback? alActivarPipNativo,
    required VoidCallback alMostrarModalVelocidad,
    VoidCallback? alMostrarSincronizacion,
    VoidCallback? alMostrarInfoVideo,
    required VoidCallback alAlternarOrientacion,
    VoidCallback? alLiberarOrientacion,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar opciones',
      // Barrera sin oscurecer para que el resto del video siga viéndose al 100%
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim, secondaryAnim) {
        return Align(
          alignment: Alignment.centerRight,
          child: RepaintBoundary(
            child: PanelLateralOpciones(
              velocidadActual: velocidadActual,
              esPantallaCompletaHorizontal: esPantallaCompletaHorizontal,
              zoomActivo: zoomActivo,
              alRestablecerZoom: alRestablecerZoom,
              alActivarPipNativo: alActivarPipNativo,
              alMostrarModalVelocidad: alMostrarModalVelocidad,
              alMostrarSincronizacion: alMostrarSincronizacion,
              alMostrarInfoVideo: alMostrarInfoVideo,
              alAlternarOrientacion: alAlternarOrientacion,
              alLiberarOrientacion: alLiberarOrientacion,
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final animacionCurva = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(animacionCurva),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final anchoPantalla = MediaQuery.sizeOf(context).width;
    final anchoPanel = (anchoPantalla * 0.44).clamp(250.0, 310.0);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: anchoPanel,
        height: double.infinity,
        decoration: BoxDecoration(
          // Fondo con baja opacidad (40% negro obsidian) para que el video NUNCA se tape
          color: ColoresApp.fondoModalTranslucido,
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(16),
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(-4, 0),
            ),
          ],
        ),
        child: SafeArea(
          left: false,
          child: Column(
            children: [
              // 1. ENCABEZADO MINIMALISTA
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: ColoresApp.acentoPrimario.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: ColoresApp.acentoPrimario,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Ajustes',
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
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              Divider(
                height: 1,
                thickness: 0.8,
                color: Colors.white.withValues(alpha: 0.12),
              ),

              // 2. LISTA DE ACCIONES ESENCIALES (CERO BUCLE, CERO LAG)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 6,
                  ),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    if (zoomActivo && alRestablecerZoom != null)
                      _construirElemento(
                        context,
                        icono: Icons.zoom_out_map_rounded,
                        colorIcono: ColoresApp.acentoPrimario,
                        titulo: 'Restablecer Zoom (100%)',
                        alPresionar: () {
                          Navigator.of(context).pop();
                          alRestablecerZoom?.call();
                        },
                      ),

                    _construirElemento(
                      context,
                      icono: Icons.speed_rounded,
                      colorIcono: Colors.white,
                      titulo: 'Velocidad',
                      subtitulo: '${velocidadActual}x',
                      alPresionar: () {
                        Navigator.of(context).pop();
                        alMostrarModalVelocidad();
                      },
                    ),

                    if (alMostrarSincronizacion != null)
                      _construirElemento(
                        context,
                        icono: Icons.sync_rounded,
                        colorIcono: ColoresApp.acentoAmbar,
                        titulo: 'Sincronizar Audio / Subs',
                        alPresionar: () {
                          Navigator.of(context).pop();
                          alMostrarSincronizacion?.call();
                        },
                      ),

                    if (alMostrarInfoVideo != null)
                      _construirElemento(
                        context,
                        icono: Icons.info_outline_rounded,
                        colorIcono: Colors.white70,
                        titulo: 'Información del Video',
                        alPresionar: () {
                          Navigator.of(context).pop();
                          alMostrarInfoVideo?.call();
                        },
                      ),

                    _construirElemento(
                      context,
                      icono: esPantallaCompletaHorizontal
                          ? Icons.screen_lock_portrait_rounded
                          : Icons.screen_lock_landscape_rounded,
                      colorIcono: Colors.white,
                      titulo: esPantallaCompletaHorizontal
                          ? 'Fijar en vertical'
                          : 'Fijar en horizontal',
                      alPresionar: () {
                        Navigator.of(context).pop();
                        alAlternarOrientacion();
                      },
                    ),

                    if (alLiberarOrientacion != null)
                      _construirElemento(
                        context,
                        icono: Icons.screen_rotation_rounded,
                        colorIcono: Colors.white,
                        titulo: 'Auto-rotación libre',
                        alPresionar: () {
                          Navigator.of(context).pop();
                          alLiberarOrientacion?.call();
                        },
                      ),

                    if (alActivarPipNativo != null)
                      _construirElemento(
                        context,
                        icono: Icons.picture_in_picture_alt_rounded,
                        colorIcono: ColoresApp.acentoAzul,
                        titulo: 'Ventana flotante (PiP Android)',
                        alPresionar: () {
                          Navigator.of(context).pop();
                          alActivarPipNativo?.call();
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirElemento(
    BuildContext context, {
    required IconData icono,
    required Color colorIcono,
    required String titulo,
    String? subtitulo,
    required VoidCallback alPresionar,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: alPresionar,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(icono, color: colorIcono, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (subtitulo != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      subtitulo,
                      style: const TextStyle(
                        color: ColoresApp.acentoPrimario,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
