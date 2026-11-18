import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../constantes/colores_app.dart';
import '../../modelos/modelo_capitulo_video.dart';

/// Botón contextual estilo Crunchyroll ("Saltar intro" / "Saltar outro" / "Saltar créditos")
/// posicionado abajo a la derecha encima de la línea de tiempo del video.
/// Aparece únicamente cuando los metadatos indican que inició la intro, outro o créditos.
class BotonSaltarCapitulo extends StatelessWidget {
  final ValueListenable<CapituloSaltarActivo?> capituloSaltarNotifier;
  final ValueListenable<bool>? velocidad2xNotifier;
  final bool controlesVisibles;
  final ValueChanged<CapituloSaltarActivo> alSaltar;

  const BotonSaltarCapitulo({
    super.key,
    required this.capituloSaltarNotifier,
    required this.controlesVisibles,
    required this.alSaltar,
    this.velocidad2xNotifier,
  });

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final sinAnimacion = MediaQuery.disableAnimationsOf(context);
    final duracionMovimiento = sinAnimacion
        ? Duration.zero
        : const Duration(milliseconds: 240);
    final duracionAparicion = sinAnimacion
        ? Duration.zero
        : const Duration(milliseconds: 180);

    // Encima de la línea de tiempo cuando el HUD está visible; esquina inferior
    // derecha sobre el video cuando los controles están ocultos.
    final bottomOffset = (controlesVisibles ? 106.0 : 24.0) + insets.bottom;
    final rightOffset = 16.0 + insets.right;

    return AnimatedPositioned(
      duration: duracionMovimiento,
      curve: Curves.easeInOut,
      bottom: bottomOffset,
      right: rightOffset,
      child: RepaintBoundary(
        child: ValueListenableBuilder<CapituloSaltarActivo?>(
          valueListenable: capituloSaltarNotifier,
          builder: (context, activo, _) {
            if (activo == null) {
              return AnimatedSwitcher(
                duration: duracionAparicion,
                child: const SizedBox.shrink(),
              );
            }

            if (velocidad2xNotifier != null) {
              return ValueListenableBuilder<bool>(
                valueListenable: velocidad2xNotifier!,
                builder: (context, velocidad2x, _) {
                  return AnimatedSwitcher(
                    duration: duracionAparicion,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: velocidad2x
                        ? const SizedBox.shrink()
                        : _CapsulaSaltarCrunchyroll(
                            key: ValueKey(
                              '${activo.capituloOrigen.indice}_${activo.tipo.name}',
                            ),
                            etiqueta: activo.tipo.etiquetaBoton,
                            alPresionar: () => alSaltar(activo),
                          ),
                  );
                },
              );
            }

            return AnimatedSwitcher(
              duration: duracionAparicion,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _CapsulaSaltarCrunchyroll(
                key: ValueKey(
                  '${activo.capituloOrigen.indice}_${activo.tipo.name}',
                ),
                etiqueta: activo.tipo.etiquetaBoton,
                alPresionar: () => alSaltar(activo),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CapsulaSaltarCrunchyroll extends StatelessWidget {
  final String etiqueta;
  final VoidCallback alPresionar;

  const _CapsulaSaltarCrunchyroll({
    super.key,
    required this.etiqueta,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: alPresionar,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xDB0A0D14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: ColoresApp.acentoPrimario.withValues(alpha: 0.85),
              width: 1.3,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x88000000),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 12, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  etiqueta,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.fast_forward_rounded,
                  color: ColoresApp.acentoPrimario,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
