import 'dart:async';

import 'package:flutter/material.dart';
import '../../constantes/colores_app.dart';
import '../../modelos/modelo_opciones_reproduccion.dart';
import '../../modelos/modelo_video.dart';

/// Indicador flotante en pantalla (OSD) translúcido y no invasivo.
/// - Brillo / Modo Noche: Cápsula vertical animada en el lateral derecho (anti-obstrucción de mano).
/// - Volumen: Cápsula vertical animada en el lateral izquierdo (anti-obstrucción de mano).
/// - Búsqueda de tiempo (Seek): Centro con fondo translúcido sutil.
class IndicadorGestoOSD extends StatefulWidget {
  final TipoGestoOSD tipoGesto;
  final double
  valor; // -1.0 a 1.0 para brillo (<0 es Modo Noche), 0.0 a 1.0 para volumen
  final int diferenciaSegundos; // Para seek (+15s, -10s, +90s)
  final int posicionObjetivoMs; // Tiempo resultante
  final int duracionTotalMs;
  final double porcentajeZoom;
  final String tituloCapitulo;
  final int indiceCapitulo;
  final int totalCapitulos;

  const IndicadorGestoOSD({
    super.key,
    required this.tipoGesto,
    this.valor = 0.0,
    this.diferenciaSegundos = 0,
    this.posicionObjetivoMs = 0,
    this.duracionTotalMs = 0,
    this.porcentajeZoom = 1.0,
    this.tituloCapitulo = '',
    this.indiceCapitulo = 0,
    this.totalCapitulos = 0,
  });

  @override
  State<IndicadorGestoOSD> createState() => _IndicadorGestoOSDState();
}

class _IndicadorGestoOSDState extends State<IndicadorGestoOSD>
    with TickerProviderStateMixin {
  static const Duration _duracionEntrada = Duration(milliseconds: 220);
  static const Duration _duracionSalida = Duration(milliseconds: 240);

  late final AnimationController _controladorBrillo;
  late final AnimationController _controladorVolumen;

  late final Animation<double> _opacidadBrillo;
  late final Animation<Offset> _desplazamientoBrillo;
  late final Animation<double> _escalaBrillo;

  late final Animation<double> _opacidadVolumen;
  late final Animation<Offset> _desplazamientoVolumen;
  late final Animation<double> _escalaVolumen;

  // Conservan el último valor real de cada barra para que durante la animación
  // de salida no salte al valor del otro control.
  double _ultimoValorBrillo = 0.5;
  double _ultimoValorVolumen = 0.5;
  bool _animacionesInicializadas = false;

  @override
  void initState() {
    super.initState();
    _controladorBrillo = AnimationController(
      vsync: this,
      duration: _duracionEntrada,
      reverseDuration: _duracionSalida,
    )..addStatusListener(_alCambiarEstadoAnimacion);

    _controladorVolumen = AnimationController(
      vsync: this,
      duration: _duracionEntrada,
      reverseDuration: _duracionSalida,
    )..addStatusListener(_alCambiarEstadoAnimacion);

    final curvaBrillo = CurvedAnimation(
      parent: _controladorBrillo,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    _opacidadBrillo = CurvedAnimation(
      parent: _controladorBrillo,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeOut,
    );
    _desplazamientoBrillo = Tween<Offset>(
      begin: const Offset(0.42, 0.0),
      end: Offset.zero,
    ).animate(curvaBrillo);
    _escalaBrillo = Tween<double>(begin: 0.92, end: 1.0).animate(curvaBrillo);

    final curvaVolumen = CurvedAnimation(
      parent: _controladorVolumen,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    _opacidadVolumen = CurvedAnimation(
      parent: _controladorVolumen,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeOut,
    );
    _desplazamientoVolumen = Tween<Offset>(
      begin: const Offset(-0.42, 0.0),
      end: Offset.zero,
    ).animate(curvaVolumen);
    _escalaVolumen = Tween<double>(begin: 0.92, end: 1.0).animate(curvaVolumen);

    _actualizarValoresEnCache();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_animacionesInicializadas) {
      _animacionesInicializadas = true;
      _sincronizarAnimaciones(
        reducirMovimiento: MediaQuery.disableAnimationsOf(context),
      );
    }
  }

  @override
  void didUpdateWidget(covariant IndicadorGestoOSD oldWidget) {
    super.didUpdateWidget(oldWidget);
    _actualizarValoresEnCache();
    _sincronizarAnimaciones(
      reducirMovimiento: MediaQuery.disableAnimationsOf(context),
    );
  }

  @override
  void dispose() {
    _controladorBrillo.removeStatusListener(_alCambiarEstadoAnimacion);
    _controladorVolumen.removeStatusListener(_alCambiarEstadoAnimacion);
    _controladorBrillo.dispose();
    _controladorVolumen.dispose();
    super.dispose();
  }

  void _alCambiarEstadoAnimacion(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && mounted) {
      setState(() {});
    }
  }

  void _actualizarValoresEnCache() {
    if (widget.tipoGesto == TipoGestoOSD.brillo) {
      _ultimoValorBrillo = widget.valor;
    } else if (widget.tipoGesto == TipoGestoOSD.volumen) {
      _ultimoValorVolumen = widget.valor;
    }
  }

  void _sincronizarAnimaciones({required bool reducirMovimiento}) {
    final mostrarBrillo = widget.tipoGesto == TipoGestoOSD.brillo;
    final mostrarVolumen = widget.tipoGesto == TipoGestoOSD.volumen;

    _actualizarControlador(
      _controladorBrillo,
      mostrar: mostrarBrillo,
      reducirMovimiento: reducirMovimiento,
    );
    _actualizarControlador(
      _controladorVolumen,
      mostrar: mostrarVolumen,
      reducirMovimiento: reducirMovimiento,
    );
  }

  void _actualizarControlador(
    AnimationController controlador, {
    required bool mostrar,
    required bool reducirMovimiento,
  }) {
    if (reducirMovimiento) {
      controlador.value = mostrar ? 1.0 : 0.0;
      return;
    }

    if (mostrar) {
      if (controlador.status != AnimationStatus.forward &&
          controlador.status != AnimationStatus.completed) {
        unawaited(controlador.forward());
      }
    } else {
      if (controlador.status != AnimationStatus.reverse &&
          controlador.status != AnimationStatus.dismissed) {
        unawaited(controlador.reverse());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brilloActivo =
        widget.tipoGesto == TipoGestoOSD.brillo ||
        !_controladorBrillo.isDismissed;
    final volumenActivo =
        widget.tipoGesto == TipoGestoOSD.volumen ||
        !_controladorVolumen.isDismissed;
    final otroGestoActivo =
        widget.tipoGesto != TipoGestoOSD.ninguno &&
        widget.tipoGesto != TipoGestoOSD.brillo &&
        widget.tipoGesto != TipoGestoOSD.volumen;

    if (!brilloActivo && !volumenActivo && !otroGestoActivo) {
      return const SizedBox.shrink();
    }

    final insets = MediaQuery.paddingOf(context);
    final esLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final separacionDerecha = (esLandscape ? 48.0 : 32.0) + insets.right;
    final separacionIzquierda = (esLandscape ? 48.0 : 32.0) + insets.left;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (brilloActivo)
            _CapsulaLateralAnimada(
              alineacion: Alignment.centerRight,
              paddingLateral: EdgeInsets.only(right: separacionDerecha),
              opacidad: _opacidadBrillo,
              desplazamiento: _desplazamientoBrillo,
              escala: _escalaBrillo,
              child: _ContenidoBrilloOSD(valor: _ultimoValorBrillo),
            ),
          if (volumenActivo)
            _CapsulaLateralAnimada(
              alineacion: Alignment.centerLeft,
              paddingLateral: EdgeInsets.only(left: separacionIzquierda),
              opacidad: _opacidadVolumen,
              desplazamiento: _desplazamientoVolumen,
              escala: _escalaVolumen,
              child: _ContenidoVolumenOSD(valor: _ultimoValorVolumen),
            ),
          if (otroGestoActivo) _construirOtroOSD(context),
        ],
      ),
    );
  }

  Widget _construirOtroOSD(BuildContext context) {
    switch (widget.tipoGesto) {
      case TipoGestoOSD.posicionTiempo:
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: _construirContenidoTiempo(),
          ),
        );

      case TipoGestoOSD.zoom:
        return _construirPastillaZoom(context);

      case TipoGestoOSD.capitulo:
        return _construirPastillaCapitulo(context);

      case TipoGestoOSD.ninguno:
      case TipoGestoOSD.brillo:
      case TipoGestoOSD.volumen:
        return const SizedBox.shrink();
    }
  }

  /// Pastilla OSD flotante superior para cambio de capítulo.
  Widget _construirPastillaCapitulo(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final prefijo = widget.totalCapitulos > 0
        ? 'Cap. ${widget.indiceCapitulo}/${widget.totalCapitulos} · '
        : '';
    final tiempo = ModeloVideo.formatearTiempo(widget.posicionObjetivoMs);

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: insets.top + 28, left: 24, right: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: ColoresApp.fondoOSD,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: ColoresApp.bordeOSD,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.bookmarks_rounded,
                color: ColoresApp.acentoPrimario,
                size: 18,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '$prefijo${widget.tituloCapitulo} ($tiempo)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pastilla OSD flotante superior para el zoom multitáctil (🔍 145%).
  Widget _construirPastillaZoom(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final porcentajeEntero = (widget.porcentajeZoom * 100).round();
    final esOriginal = porcentajeEntero <= 100;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: insets.top + 28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: ColoresApp.fondoOSD,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: ColoresApp.bordeOSD,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                esOriginal ? Icons.zoom_out_map_rounded : Icons.zoom_in_rounded,
                color: esOriginal ? Colors.white70 : ColoresApp.acentoPrimario,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                esOriginal ? 'Ajuste Original (100%)' : '🔍 $porcentajeEntero%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Contenido de Búsqueda de Tiempo (Seek).
  Widget _construirContenidoTiempo() {
    final esAdelantar = widget.diferenciaSegundos >= 0;
    final signo = esAdelantar ? '+' : '-';
    final segAbs = widget.diferenciaSegundos.abs();
    final minutos = segAbs ~/ 60;
    final segundos = segAbs % 60;

    final String textoDiferencia;
    if (minutos > 0) {
      textoDiferencia =
          '$signo${minutos}m ${segundos.toString().padLeft(2, '0')}s';
    } else {
      textoDiferencia = '$signo${segundos}s';
    }

    final ratioProgreso = widget.duracionTotalMs > 0
        ? (widget.posicionObjetivoMs / widget.duracionTotalMs).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          esAdelantar ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
          color: ColoresApp.acentoAmbar,
          size: 40,
        ),
        const SizedBox(height: 6),
        Text(
          textoDiferencia,
          style: const TextStyle(
            color: ColoresApp.acentoAmbar,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${ModeloVideo.formatearTiempo(widget.posicionObjetivoMs)} / ${ModeloVideo.formatearTiempo(widget.duracionTotalMs)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 150,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratioProgreso,
              backgroundColor: ColoresApp.barraFondo,
              valueColor: const AlwaysStoppedAnimation<Color>(
                ColoresApp.barraProgreso,
              ),
              minHeight: 5,
            ),
          ),
        ),
      ],
    );
  }
}

/// Cápsula lateral vertical animada con entrada/salida fluida por GPU
/// (deslizamiento + escala sutil + opacidad) sin reconstruir el contenido
/// en cada fotograma de la transición.
class _CapsulaLateralAnimada extends StatelessWidget {
  final Alignment alineacion;
  final EdgeInsets paddingLateral;
  final Animation<double> opacidad;
  final Animation<Offset> desplazamiento;
  final Animation<double> escala;
  final Widget child;

  const _CapsulaLateralAnimada({
    required this.alineacion,
    required this.paddingLateral,
    required this.opacidad,
    required this.desplazamiento,
    required this.escala,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alineacion,
      child: Padding(
        padding: paddingLateral,
        child: FadeTransition(
          opacity: opacidad,
          child: SlideTransition(
            position: desplazamiento,
            child: ScaleTransition(
              scale: escala,
              child: Container(
                width: 44,
                height: 180,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Contenido de Brillo / Modo Noche en cápsula vertical derecha.
class _ContenidoBrilloOSD extends StatelessWidget {
  final double valor;

  const _ContenidoBrilloOSD({required this.valor});

  @override
  Widget build(BuildContext context) {
    final esModoNoche = valor < 0.0;
    final int porcentaje;
    final double progreso;
    final Color colorAcento;
    final IconData icono;

    if (esModoNoche) {
      porcentaje = ((-valor) * 100).round().clamp(1, 100);
      progreso = (-valor).clamp(0.0, 1.0);
      colorAcento = const Color(0xFF9FA8DA); // Lavanda suave nocturno
      icono = Icons.bedtime_rounded;
    } else {
      porcentaje = (valor * 100).round();
      progreso = valor.clamp(0.0, 1.0);
      colorAcento = ColoresApp.acentoAzul;
      icono = porcentaje > 50
          ? Icons.brightness_high_rounded
          : Icons.brightness_medium_rounded;
    }

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Icon(icono, color: colorAcento, size: 20),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            width: 5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: progreso,
              child: Container(
                decoration: BoxDecoration(
                  color: colorAcento,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$porcentaje%',
          style: TextStyle(
            color: colorAcento,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Contenido de Volumen en cápsula vertical izquierda.
class _ContenidoVolumenOSD extends StatelessWidget {
  final double valor;

  const _ContenidoVolumenOSD({required this.valor});

  @override
  Widget build(BuildContext context) {
    final porcentaje = (valor * 100).round();
    final progreso = valor.clamp(0.0, 1.0);

    IconData iconoVol = Icons.volume_up_rounded;
    if (porcentaje == 0) {
      iconoVol = Icons.volume_off_rounded;
    } else if (porcentaje < 40) {
      iconoVol = Icons.volume_down_rounded;
    }

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Icon(iconoVol, color: ColoresApp.acentoPrimario, size: 20),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            width: 5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: progreso,
              child: Container(
                decoration: BoxDecoration(
                  color: ColoresApp.acentoPrimario,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$porcentaje%',
          style: const TextStyle(
            color: ColoresApp.textoPrincipal,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
