import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constantes/colores_app.dart';

/// Panel lateral con rueda de selección cinemática para la velocidad de reproducción.
///
/// Se despliega en el mismo lateral derecho que [PanelLateralOpciones] para no
/// obstruir el centro del video, aplica los cambios en tiempo real y emite una
/// vibración háptica breve al pasar por cada velocidad.
class ModalVelocidad extends StatefulWidget {
  final double velocidadActual;
  final ValueChanged<double> alSeleccionarVelocidad;

  static const List<double> velocidadesDisponibles = [
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
    2.25,
    2.5,
    2.75,
    3.0,
  ];

  static const int _indiceVelocidadNormal = 3; // 1.0x

  const ModalVelocidad({
    super.key,
    required this.velocidadActual,
    required this.alSeleccionarVelocidad,
  });

  /// Devuelve el índice de [velocidadesDisponibles] más cercano a [velocidad].
  static int indiceMasCercano(double velocidad) {
    var mejorIndice = _indiceVelocidadNormal;
    var menorDiferencia = double.infinity;
    for (var i = 0; i < velocidadesDisponibles.length; i++) {
      final diferencia = (velocidadesDisponibles[i] - velocidad).abs();
      if (diferencia < menorDiferencia) {
        menorDiferencia = diferencia;
        mejorIndice = i;
      }
    }
    return mejorIndice;
  }

  /// Formatea la velocidad de forma limpia (ej. `0.25x`, `1.0x`, `1.5x`).
  static String formatearVelocidad(double velocidad) => '${velocidad}x';

  /// Despliega el panel lateral de velocidad desde el borde derecho.
  static Future<void> mostrar(
    BuildContext context, {
    required double velocidadActual,
    required ValueChanged<double> alSeleccionarVelocidad,
  }) {
    final reducirMovimiento = MediaQuery.disableAnimationsOf(context);
    return Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierLabel: 'Cerrar selector de velocidad',
        barrierColor: Colors.transparent,
        transitionDuration: reducirMovimiento
            ? Duration.zero
            : const Duration(milliseconds: 220),
        reverseTransitionDuration: reducirMovimiento
            ? Duration.zero
            : const Duration(milliseconds: 260),
        pageBuilder: (ctx, anim, secondaryAnim) {
          return Align(
            alignment: Alignment.centerRight,
            child: RepaintBoundary(
              child: ModalVelocidad(
                velocidadActual: velocidadActual,
                alSeleccionarVelocidad: alSeleccionarVelocidad,
              ),
            ),
          );
        },
        transitionsBuilder: (ctx, anim, secondaryAnim, child) {
          if (reducirMovimiento) return child;
          final animacionCurva = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInOutCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(animacionCurva),
            child: child,
          );
        },
      ),
    );
  }

  @override
  State<ModalVelocidad> createState() => _ModalVelocidadState();
}

class _ModalVelocidadState extends State<ModalVelocidad> {
  late final FixedExtentScrollController _controladorRueda;
  late final ValueNotifier<int> _indiceSeleccionadoNotifier;
  bool _animandoProgramaticamente = false;

  @override
  void initState() {
    super.initState();
    final indiceInicial = ModalVelocidad.indiceMasCercano(
      widget.velocidadActual,
    );
    _controladorRueda = FixedExtentScrollController(initialItem: indiceInicial);
    _indiceSeleccionadoNotifier = ValueNotifier<int>(indiceInicial);
  }

  @override
  void dispose() {
    _controladorRueda.dispose();
    _indiceSeleccionadoNotifier.dispose();
    super.dispose();
  }

  void _alCambiarIndiceRueda(int indiceReal) {
    if (_animandoProgramaticamente) return;
    final total = ModalVelocidad.velocidadesDisponibles.length;
    final nuevoIndice = indiceReal % total;
    if (_indiceSeleccionadoNotifier.value == nuevoIndice) return;

    _indiceSeleccionadoNotifier.value = nuevoIndice;
    unawaited(HapticFeedback.selectionClick());
    widget.alSeleccionarVelocidad(
      ModalVelocidad.velocidadesDisponibles[nuevoIndice],
    );
  }

  /// Calcula el índice real más cercano en el bucle infinito para llegar al
  /// [indiceObjetivoNormalizado] recorriendo la distancia más corta.
  int _indiceRealMasCercano(int indiceObjetivoNormalizado) {
    final total = ModalVelocidad.velocidadesDisponibles.length;
    final actualReal = _controladorRueda.hasClients
        ? _controladorRueda.selectedItem
        : _indiceSeleccionadoNotifier.value;
    final actualNormalizado = actualReal % total;
    var delta = indiceObjetivoNormalizado - actualNormalizado;
    if (delta > total / 2) {
      delta -= total;
    } else if (delta < -total / 2) {
      delta += total;
    }
    return actualReal + delta;
  }

  Future<void> _seleccionarIndiceRealProgramaticamente(
    int indiceRealDestino, {
    bool esRestablecer = false,
  }) async {
    final total = ModalVelocidad.velocidadesDisponibles.length;
    final indiceNormalizado = indiceRealDestino % total;
    if (_indiceSeleccionadoNotifier.value == indiceNormalizado) return;

    _indiceSeleccionadoNotifier.value = indiceNormalizado;
    unawaited(
      esRestablecer
          ? HapticFeedback.lightImpact()
          : HapticFeedback.selectionClick(),
    );
    widget.alSeleccionarVelocidad(
      ModalVelocidad.velocidadesDisponibles[indiceNormalizado],
    );

    final reducirMovimiento = MediaQuery.disableAnimationsOf(context);
    if (reducirMovimiento) {
      _controladorRueda.jumpToItem(indiceRealDestino);
      return;
    }

    _animandoProgramaticamente = true;
    try {
      await _controladorRueda.animateToItem(
        indiceRealDestino,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } finally {
      if (mounted) {
        _animandoProgramaticamente = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final anchoPantalla = MediaQuery.sizeOf(context).width;
    final anchoPanel = (anchoPantalla * 0.36).clamp(204.0, 244.0);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: anchoPanel,
        height: double.infinity,
        decoration: BoxDecoration(
          color: ColoresApp.fondoModalTranslucido,
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(18),
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(-4, 0),
            ),
          ],
        ),
        child: SafeArea(
          left: false,
          child: Column(
            children: [
              const _EncabezadoPanelVelocidad(),
              Divider(
                height: 1,
                thickness: 0.8,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final alturaDisponible = constraints.maxHeight;
                    final alturaRueda = alturaDisponible > 140.0
                        ? alturaDisponible.clamp(140.0, 320.0)
                        : alturaDisponible;
                    final alturaItem = alturaRueda < 215.0 ? 40.0 : 46.0;

                    return Center(
                      child: SizedBox(
                        height: alturaRueda,
                        width: double.infinity,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            _VisorSeleccionCentral(alturaItem: alturaItem),
                            ListWheelScrollView.useDelegate(
                              controller: _controladorRueda,
                              itemExtent: alturaItem,
                              physics: const FixedExtentScrollPhysics(),
                              diameterRatio: 1.48,
                              perspective: 0.0032,
                              squeeze: 1.06,
                              overAndUnderCenterOpacity: 0.42,
                              useMagnifier: true,
                              magnification: 1.15,
                              onSelectedItemChanged: _alCambiarIndiceRueda,
                              childDelegate: ListWheelChildBuilderDelegate(
                                builder: (context, indiceReal) {
                                  final total = ModalVelocidad
                                      .velocidadesDisponibles
                                      .length;
                                  final indiceNormalizado = indiceReal % total;
                                  final velocidad = ModalVelocidad
                                      .velocidadesDisponibles[indiceNormalizado];
                                  return _ElementoVelocidadRueda(
                                    indice: indiceNormalizado,
                                    velocidad: velocidad,
                                    indiceSeleccionadoNotifier:
                                        _indiceSeleccionadoNotifier,
                                    alTocar: () =>
                                        _seleccionarIndiceRealProgramaticamente(
                                          indiceReal,
                                        ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.8,
                color: Colors.white.withValues(alpha: 0.10),
              ),
              _PiePanelVelocidad(
                indiceSeleccionadoNotifier: _indiceSeleccionadoNotifier,
                alRestablecerNormal: () =>
                    _seleccionarIndiceRealProgramaticamente(
                      _indiceRealMasCercano(
                        ModalVelocidad._indiceVelocidadNormal,
                      ),
                      esRestablecer: true,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EncabezadoPanelVelocidad extends StatelessWidget {
  const _EncabezadoPanelVelocidad();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: ColoresApp.acentoPrimario.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.speed_rounded,
              color: ColoresApp.acentoPrimario,
              size: 15,
            ),
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              'Velocidad',
              style: TextStyle(
                color: ColoresApp.textoPrincipal,
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white70,
              size: 19,
            ),
            visualDensity: VisualDensity.compact,
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _VisorSeleccionCentral extends StatelessWidget {
  final double alturaItem;

  const _VisorSeleccionCentral({required this.alturaItem});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: alturaItem,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: ColoresApp.acentoPrimario.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ColoresApp.acentoPrimario.withValues(alpha: 0.55),
            width: 1.0,
          ),
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            width: 3,
            height: 18,
            margin: const EdgeInsetsDirectional.only(start: 6),
            decoration: BoxDecoration(
              color: ColoresApp.acentoPrimario,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

class _ElementoVelocidadRueda extends StatelessWidget {
  final int indice;
  final double velocidad;
  final ValueNotifier<int> indiceSeleccionadoNotifier;
  final VoidCallback alTocar;

  const _ElementoVelocidadRueda({
    required this.indice,
    required this.velocidad,
    required this.indiceSeleccionadoNotifier,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    final esNormal = (velocidad - 1.0).abs() < 0.001;
    final etiqueta = ModalVelocidad.formatearVelocidad(velocidad);

    return ValueListenableBuilder<int>(
      valueListenable: indiceSeleccionadoNotifier,
      builder: (context, indiceSeleccionado, _) {
        final estaSeleccionado = indice == indiceSeleccionado;
        return Semantics(
          button: true,
          selected: estaSeleccionado,
          label: esNormal
              ? 'Velocidad $etiqueta, normal'
              : 'Velocidad $etiqueta',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: alTocar,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      etiqueta,
                      style: TextStyle(
                        color: estaSeleccionado
                            ? Colors.white
                            : ColoresApp.textoSecundario,
                        fontSize: estaSeleccionado ? 17.5 : 14.5,
                        fontWeight: estaSeleccionado
                            ? FontWeight.w700
                            : FontWeight.w500,
                        letterSpacing: 0.3,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  if (esNormal) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: estaSeleccionado
                            ? ColoresApp.acentoPrimario.withValues(alpha: 0.30)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Normal',
                        style: TextStyle(
                          color: estaSeleccionado
                              ? Colors.white
                              : ColoresApp.textoSecundario,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PiePanelVelocidad extends StatelessWidget {
  final ValueNotifier<int> indiceSeleccionadoNotifier;
  final VoidCallback alRestablecerNormal;

  const _PiePanelVelocidad({
    required this.indiceSeleccionadoNotifier,
    required this.alRestablecerNormal,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Center(
          child: ValueListenableBuilder<int>(
            valueListenable: indiceSeleccionadoNotifier,
            builder: (context, indiceSeleccionado, _) {
              final esNormal =
                  indiceSeleccionado == ModalVelocidad._indiceVelocidadNormal;

              if (esNormal) {
                return const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: ColoresApp.textoSecundario,
                    ),
                    SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'En 1.0x',
                        style: TextStyle(
                          color: ColoresApp.textoSecundario,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: alRestablecerNormal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ColoresApp.acentoPrimario.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: ColoresApp.acentoPrimario.withValues(alpha: 0.45),
                        width: 0.9,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.restart_alt_rounded,
                          size: 15,
                          color: ColoresApp.acentoPrimario,
                        ),
                        SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'Normal 1.0x',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
