import 'package:flutter/material.dart';
import 'gestor_pip_global.dart';
import 'mini_reproductor_flotante.dart';

/// Envoltorio reactivo de alto rendimiento para PantallaPrincipal.
/// Superpone el Mini-Reproductor Flotante in-app tipo YouTube justo encima
/// del NavigationBar con animación fluida a 144 FPS y cero rebuilds de listas.
class EnvoltorioPipScaffold extends StatefulWidget {
  final Widget child;

  const EnvoltorioPipScaffold({super.key, required this.child});

  @override
  State<EnvoltorioPipScaffold> createState() => _EnvoltorioPipScaffoldState();
}

class _EnvoltorioPipScaffoldState extends State<EnvoltorioPipScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controladorAnimacion;
  late final Animation<Offset> _animacionSlide;

  @override
  void initState() {
    super.initState();
    _controladorAnimacion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _animacionSlide = Tween<Offset>(
      begin: const Offset(0.0, 1.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controladorAnimacion,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    GestorPipGlobal.instancia.estadoPip.addListener(_alCambiarEstadoPip);
    if (GestorPipGlobal.instancia.estaMinimizado) {
      _controladorAnimacion.value = 1.0;
    }
  }

  void _alCambiarEstadoPip() {
    if (!mounted) return;
    if (GestorPipGlobal.instancia.estaMinimizado) {
      _controladorAnimacion.forward();
    } else {
      _controladorAnimacion.reverse();
    }
  }

  @override
  void dispose() {
    GestorPipGlobal.instancia.estadoPip.removeListener(_alCambiarEstadoPip);
    _controladorAnimacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    // Posicionado justo encima de la barra de navegación NavigationBar (80px en M3 + padding)
    final separacionInferior = insets.bottom + 86.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. ÁRBOL PRINCIPAL DE PANTALLA (CERO REBUILDS)
        widget.child,

        // 2. MINI-REPRODUCTOR FLOTANTE IN-APP REACTIVO
        AnimatedBuilder(
          animation: _controladorAnimacion,
          builder: (context, child) {
            final visible = _controladorAnimacion.value > 0.0 ||
                GestorPipGlobal.instancia.estaMinimizado;
            if (!visible) {
              return const SizedBox.shrink();
            }

            return Positioned(
              left: 12,
              right: 12,
              bottom: separacionInferior,
              child: SlideTransition(
                position: _animacionSlide,
                child: const RepaintBoundary(
                  child: MiniReproductorFlotante(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
