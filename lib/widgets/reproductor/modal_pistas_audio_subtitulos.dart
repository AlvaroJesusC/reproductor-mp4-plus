import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constantes/colores_app.dart';
import '../../modelos/modelo_pista_media.dart';

/// Panel adaptativo y reactivo para seleccionar pistas de audio y subtítulos.
///
/// - En horizontal (`width > height`): se ancla como panel lateral estrecho en el
///   borde derecho (`256–308 px`) para dejar libre el centro del video y los subtítulos.
/// - En vertical (`height >= width`): se despliega como hoja compacta inferior para
///   mantener visible el video en la mitad superior.
/// - Reactivo en tiempo real mediante [ValueListenable<EstadoPistasReproductor>]:
///   cualquier pista detectada tardíamente o cargada externamente aparece al instante.
class ModalPistasAudioSubtitulos extends StatefulWidget {
  final ValueListenable<EstadoPistasReproductor> estadoPistasListenable;
  final ValueChanged<PistaMedia?> alSeleccionarAudio;
  final ValueChanged<PistaMedia?> alSeleccionarSubtitulo;
  final VoidCallback? alCargarSubtituloExterno;
  final VoidCallback? alAbrirSincronizacion;
  final Future<void> Function()? alRecargarPistas;
  final int pestanaInicial;

  const ModalPistasAudioSubtitulos({
    super.key,
    required this.estadoPistasListenable,
    required this.alSeleccionarAudio,
    required this.alSeleccionarSubtitulo,
    this.alCargarSubtituloExterno,
    this.alAbrirSincronizacion,
    this.alRecargarPistas,
    this.pestanaInicial = 0,
  });

  /// Despliega el panel adaptativo: lateral derecho estrecho en horizontal
  /// o hoja inferior compacta en vertical, sin bloquear el centro del video.
  static Future<void> mostrar(
    BuildContext context, {
    required ValueListenable<EstadoPistasReproductor> estadoPistasListenable,
    required ValueChanged<PistaMedia?> alSeleccionarAudio,
    required ValueChanged<PistaMedia?> alSeleccionarSubtitulo,
    VoidCallback? alCargarSubtituloExterno,
    VoidCallback? alAbrirSincronizacion,
    Future<void> Function()? alRecargarPistas,
    int pestanaInicial = 0,
  }) {
    final reducirMovimiento = MediaQuery.disableAnimationsOf(context);
    final tamanoInicial = MediaQuery.sizeOf(context);
    final esHorizontalInicial = tamanoInicial.width > tamanoInicial.height;

    return Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierLabel: 'Cerrar audio y subtítulos',
        barrierColor: Colors.black.withValues(alpha: 0.18),
        transitionDuration: reducirMovimiento
            ? Duration.zero
            : const Duration(milliseconds: 220),
        reverseTransitionDuration: reducirMovimiento
            ? Duration.zero
            : const Duration(milliseconds: 240),
        pageBuilder: (ctx, anim, secondaryAnim) {
          final size = MediaQuery.sizeOf(ctx);
          final esHorizontal = size.width > size.height;
          return Align(
            alignment: esHorizontal
                ? AlignmentDirectional.centerEnd
                : Alignment.bottomCenter,
            child: RepaintBoundary(
              child: ModalPistasAudioSubtitulos(
                estadoPistasListenable: estadoPistasListenable,
                alSeleccionarAudio: alSeleccionarAudio,
                alSeleccionarSubtitulo: alSeleccionarSubtitulo,
                alCargarSubtituloExterno: alCargarSubtituloExterno,
                alAbrirSincronizacion: alAbrirSincronizacion,
                alRecargarPistas: alRecargarPistas,
                pestanaInicial: pestanaInicial,
              ),
            ),
          );
        },
        transitionsBuilder: (ctx, anim, secondaryAnim, child) {
          if (reducirMovimiento) return child;
          final curva = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInOutCubic,
          );
          final origen = esHorizontalInicial
              ? const Offset(1.0, 0.0)
              : const Offset(0.0, 1.0);
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: anim,
              curve: Curves.easeOut,
              reverseCurve: Curves.easeIn,
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: origen,
                end: Offset.zero,
              ).animate(curva),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  State<ModalPistasAudioSubtitulos> createState() =>
      _ModalPistasAudioSubtitulosState();
}

class _ModalPistasAudioSubtitulosState
    extends State<ModalPistasAudioSubtitulos> {
  static const Color _fondoPanelObsidian = Color(0xEB0A0E17);

  late int _indicePestana;
  bool _recargandoManual = false;

  @override
  void initState() {
    super.initState();
    _indicePestana = widget.pestanaInicial.clamp(0, 1);
  }

  Future<void> _ejecutarRecarga() async {
    final recargar = widget.alRecargarPistas;
    if (recargar == null || _recargandoManual) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _recargandoManual = true);
    try {
      await recargar();
    } finally {
      if (mounted) {
        setState(() => _recargandoManual = false);
      }
    }
  }

  void _cambiarPestana(int nuevoIndice) {
    if (_indicePestana == nuevoIndice) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _indicePestana = nuevoIndice);
  }

  void _seleccionarAudio(PistaMedia? pista) {
    unawaited(HapticFeedback.selectionClick());
    widget.alSeleccionarAudio(pista);
  }

  void _seleccionarSubtitulo(PistaMedia? pista) {
    unawaited(HapticFeedback.selectionClick());
    widget.alSeleccionarSubtitulo(pista);
  }

  @override
  Widget build(BuildContext context) {
    final tamano = MediaQuery.sizeOf(context);
    final esHorizontal = tamano.width > tamano.height;

    final double anchoPanel = esHorizontal
        ? (tamano.width * 0.36).clamp(256.0, 308.0)
        : tamano.width.clamp(280.0, 460.0);
    final double altoMaximoVertical = (tamano.height * 0.56).clamp(
      300.0,
      440.0,
    );

    final borde = esHorizontal
        ? const BorderRadiusDirectional.horizontal(start: Radius.circular(18))
        : const BorderRadius.vertical(top: Radius.circular(20));

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onHorizontalDragEnd: esHorizontal
            ? (details) {
                if ((details.primaryVelocity ?? 0.0) > 420.0) {
                  Navigator.of(context).pop();
                }
              }
            : null,
        onVerticalDragEnd: !esHorizontal
            ? (details) {
                if ((details.primaryVelocity ?? 0.0) > 420.0) {
                  Navigator.of(context).pop();
                }
              }
            : null,
        child: Container(
          width: anchoPanel,
          height: esHorizontal ? double.infinity : null,
          constraints: esHorizontal
              ? null
              : BoxConstraints(maxHeight: altoMaximoVertical),
          decoration: BoxDecoration(
            color: _fondoPanelObsidian,
            borderRadius: borde,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 20,
                offset: esHorizontal ? const Offset(-6, 0) : const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            left: !esHorizontal,
            top: esHorizontal,
            right: true,
            bottom: true,
            child: ValueListenableBuilder<EstadoPistasReproductor>(
              valueListenable: widget.estadoPistasListenable,
              builder: (context, estado, _) {
                return Column(
                  mainAxisSize:
                      esHorizontal ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    if (!esHorizontal) const _TiradorHojaInferior(),
                    _EncabezadoPanelPistas(
                      recargando: _recargandoManual || estado.cargando,
                      alRecargar: widget.alRecargarPistas != null
                          ? _ejecutarRecarga
                          : null,
                      alCerrar: () => Navigator.of(context).pop(),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
                      child: _SelectorSegmentadoPistas(
                        indiceActivo: _indicePestana,
                        cantidadAudio: estado.pistasAudio.length,
                        cantidadSubtitulos: estado.pistasSubtitulos.length,
                        alCambiar: _cambiarPestana,
                      ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 0.8,
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                    if (esHorizontal)
                      Expanded(
                        child: _construirContenidoPestana(estado),
                      )
                    else
                      Flexible(
                        child: _construirContenidoPestana(estado),
                      ),
                    if (widget.alAbrirSincronizacion != null ||
                        (_indicePestana == 1 &&
                            widget.alCargarSubtituloExterno != null)) ...[
                      Divider(
                        height: 1,
                        thickness: 0.8,
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                      _PieAccionesPistas(
                        mostrarCargarExterno:
                            _indicePestana == 1 &&
                            widget.alCargarSubtituloExterno != null,
                        alCargarExterno: () {
                          Navigator.of(context).pop();
                          widget.alCargarSubtituloExterno?.call();
                        },
                        alAbrirSincronizacion:
                            widget.alAbrirSincronizacion != null
                            ? () {
                                Navigator.of(context).pop();
                                widget.alAbrirSincronizacion?.call();
                              }
                            : null,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirContenidoPestana(EstadoPistasReproductor estado) {
    if (_indicePestana == 0) {
      return _ListaPistasAudio(
        estado: estado,
        alSeleccionarAudio: _seleccionarAudio,
        alRecargar: widget.alRecargarPistas != null ? _ejecutarRecarga : null,
      );
    }
    return _ListaPistasSubtitulos(
      estado: estado,
      alSeleccionarSubtitulo: _seleccionarSubtitulo,
      alRecargar: widget.alRecargarPistas != null ? _ejecutarRecarga : null,
    );
  }
}

class _TiradorHojaInferior extends StatelessWidget {
  const _TiradorHojaInferior();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Center(
        child: Container(
          width: 34,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _EncabezadoPanelPistas extends StatelessWidget {
  final bool recargando;
  final VoidCallback? alRecargar;
  final VoidCallback alCerrar;

  const _EncabezadoPanelPistas({
    required this.recargando,
    this.alRecargar,
    required this.alCerrar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: ColoresApp.acentoPrimario.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.subtitles_rounded,
              color: ColoresApp.acentoPrimario,
              size: 15,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Audio y Subtítulos',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ColoresApp.textoPrincipal,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.15,
              ),
            ),
          ),
          if (alRecargar != null)
            IconButton(
              icon: recargando
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          ColoresApp.acentoAmbar,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
              visualDensity: VisualDensity.compact,
              tooltip: 'Volver a detectar pistas',
              onPressed: recargando ? null : alRecargar,
            ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white70,
              size: 19,
            ),
            visualDensity: VisualDensity.compact,
            tooltip: 'Cerrar',
            onPressed: alCerrar,
          ),
        ],
      ),
    );
  }
}

class _SelectorSegmentadoPistas extends StatelessWidget {
  final int indiceActivo;
  final int cantidadAudio;
  final int cantidadSubtitulos;
  final ValueChanged<int> alCambiar;

  const _SelectorSegmentadoPistas({
    required this.indiceActivo,
    required this.cantidadAudio,
    required this.cantidadSubtitulos,
    required this.alCambiar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.09),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _BotonSegmentoPista(
              icono: Icons.audiotrack_rounded,
              etiqueta: 'Audio',
              conteo: cantidadAudio,
              seleccionado: indiceActivo == 0,
              alPresionar: () => alCambiar(0),
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: _BotonSegmentoPista(
              icono: Icons.subtitles_outlined,
              etiqueta: 'Subtítulos',
              conteo: cantidadSubtitulos,
              seleccionado: indiceActivo == 1,
              alPresionar: () => alCambiar(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonSegmentoPista extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final int conteo;
  final bool seleccionado;
  final VoidCallback alPresionar;

  const _BotonSegmentoPista({
    required this.icono,
    required this.etiqueta,
    required this.conteo,
    required this.seleccionado,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: seleccionado,
      label: '$etiqueta, $conteo disponibles',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: alPresionar,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: seleccionado
                  ? ColoresApp.acentoPrimario.withValues(alpha: 0.22)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: seleccionado
                    ? ColoresApp.acentoPrimario.withValues(alpha: 0.55)
                    : Colors.transparent,
                width: 0.9,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icono,
                  size: 14,
                  color: seleccionado
                      ? ColoresApp.acentoPrimario
                      : ColoresApp.textoSecundario,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    etiqueta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: seleccionado
                          ? Colors.white
                          : ColoresApp.textoSecundario,
                      fontSize: 12,
                      fontWeight:
                          seleccionado ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (conteo > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: seleccionado
                          ? ColoresApp.acentoPrimario.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$conteo',
                      style: TextStyle(
                        color: seleccionado
                            ? Colors.white
                            : ColoresApp.textoSecundario,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
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

class _ListaPistasAudio extends StatelessWidget {
  final EstadoPistasReproductor estado;
  final ValueChanged<PistaMedia?> alSeleccionarAudio;
  final VoidCallback? alRecargar;

  const _ListaPistasAudio({
    required this.estado,
    required this.alSeleccionarAudio,
    this.alRecargar,
  });

  @override
  Widget build(BuildContext context) {
    final audios = estado.pistasAudio;
    if (audios.isEmpty) {
      return _EstadoVacioPistas(
        icono: Icons.volume_off_rounded,
        titulo: estado.cargando
            ? 'Detectando pistas de audio...'
            : 'Sin pistas de audio detectadas',
        subtitulo:
            'Si el archivo tiene varios idiomas, toca reintentar para volver a leer el contenedor.',
        cargando: estado.cargando,
        alRecargar: alRecargar,
      );
    }

    // Lista de pistas reales + opción discreta al final para silenciar audio
    final totalItems = audios.length + 1;
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        if (index == audios.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _TarjetaOpcionEspecial(
              icono: Icons.volume_off_rounded,
              titulo: 'Silenciar audio',
              seleccionada: estado.audioSilenciado,
              alPresionar: () => alSeleccionarAudio(null),
            ),
          );
        }

        final pista = audios[index];
        final seleccionada = !estado.audioSilenciado &&
            pista.id == estado.audioActivoId;
        return _TarjetaPistaMedia(
          key: ValueKey('audio_${pista.id}'),
          pista: pista,
          indiceVisual: index + 1,
          seleccionada: seleccionada,
          alPresionar: () => alSeleccionarAudio(pista),
        );
      },
    );
  }
}

class _ListaPistasSubtitulos extends StatelessWidget {
  final EstadoPistasReproductor estado;
  final ValueChanged<PistaMedia?> alSeleccionarSubtitulo;
  final VoidCallback? alRecargar;

  const _ListaPistasSubtitulos({
    required this.estado,
    required this.alSeleccionarSubtitulo,
    this.alRecargar,
  });

  @override
  Widget build(BuildContext context) {
    final subs = estado.pistasSubtitulos;
    final subtitulosDesactivados = !estado.tieneSubtituloActivo;

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: subs.isEmpty ? 2 : subs.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _TarjetaOpcionEspecial(
            icono: Icons.subtitles_off_rounded,
            titulo: 'Desactivados',
            seleccionada: subtitulosDesactivados,
            alPresionar: () => alSeleccionarSubtitulo(null),
          );
        }

        if (subs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _EstadoVacioPistas(
              icono: Icons.closed_caption_disabled_rounded,
              titulo: estado.cargando
                  ? 'Buscando subtítulos...'
                  : 'Sin subtítulos incrustados',
              subtitulo:
                  'Puedes volver a escanear el archivo o cargar un subtítulo externo (.srt, .ass, .vtt).',
              cargando: estado.cargando,
              alRecargar: alRecargar,
            ),
          );
        }

        final pista = subs[index - 1];
        final seleccionada =
            !subtitulosDesactivados && pista.id == estado.subtituloActivoId;
        return _TarjetaPistaMedia(
          key: ValueKey('sub_${pista.id}'),
          pista: pista,
          indiceVisual: index,
          seleccionada: seleccionada,
          alPresionar: () => alSeleccionarSubtitulo(pista),
        );
      },
    );
  }
}

class _TarjetaPistaMedia extends StatelessWidget {
  final PistaMedia pista;
  final int indiceVisual;
  final bool seleccionada;
  final VoidCallback alPresionar;

  const _TarjetaPistaMedia({
    super.key,
    required this.pista,
    required this.indiceVisual,
    required this.seleccionada,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    final etiquetas = pista.etiquetasMetadatos;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Semantics(
        button: true,
        selected: seleccionada,
        label:
            '${pista.tituloVisible}${etiquetas.isNotEmpty ? ", ${etiquetas.join(", ")}" : ""}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: alPresionar,
            child: Ink(
              decoration: BoxDecoration(
                color: seleccionada
                    ? ColoresApp.acentoPrimario.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: seleccionada
                      ? ColoresApp.acentoPrimario.withValues(alpha: 0.65)
                      : Colors.white.withValues(alpha: 0.08),
                  width: seleccionada ? 1.1 : 0.8,
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        seleccionada
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_off_rounded,
                        color: seleccionada
                            ? ColoresApp.acentoPrimario
                            : ColoresApp.textoSecundario,
                        size: 18,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              pista.tituloVisible,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: seleccionada
                                    ? Colors.white
                                    : ColoresApp.textoPrincipal,
                                fontSize: 12.5,
                                fontWeight: seleccionada
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                height: 1.25,
                              ),
                            ),
                            if (etiquetas.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: etiquetas
                                    .map(
                                      (tag) => _PastillaMetadato(
                                        texto: tag,
                                        destacada: seleccionada,
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '#$indiceVisual',
                        style: TextStyle(
                          color: seleccionada
                              ? ColoresApp.acentoPrimario
                              : ColoresApp.textoAtenuado,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TarjetaOpcionEspecial extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final bool seleccionada;
  final VoidCallback alPresionar;

  const _TarjetaOpcionEspecial({
    required this.icono,
    required this.titulo,
    required this.seleccionada,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Semantics(
        button: true,
        selected: seleccionada,
        label: titulo,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: alPresionar,
            child: Ink(
              decoration: BoxDecoration(
                color: seleccionada
                    ? ColoresApp.acentoPrimario.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: seleccionada
                      ? ColoresApp.acentoPrimario.withValues(alpha: 0.60)
                      : Colors.white.withValues(alpha: 0.07),
                  width: seleccionada ? 1.1 : 0.8,
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        seleccionada ? Icons.check_circle_rounded : icono,
                        color: seleccionada
                            ? ColoresApp.acentoPrimario
                            : ColoresApp.textoSecundario,
                        size: 18,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: seleccionada
                                ? Colors.white
                                : ColoresApp.textoSecundario,
                            fontSize: 12.5,
                            fontWeight: seleccionada
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PastillaMetadato extends StatelessWidget {
  final String texto;
  final bool destacada;

  const _PastillaMetadato({required this.texto, required this.destacada});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
      decoration: BoxDecoration(
        color: destacada
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: destacada ? Colors.white : ColoresApp.textoSecundario,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
      ),
    );
  }
}

class _EstadoVacioPistas extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final bool cargando;
  final VoidCallback? alRecargar;

  const _EstadoVacioPistas({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.cargando,
    this.alRecargar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (cargando)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(
                  ColoresApp.acentoPrimario,
                ),
              ),
            )
          else
            Icon(
              icono,
              size: 28,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          const SizedBox(height: 10),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ColoresApp.textoPrincipal,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ColoresApp.textoSecundario,
              fontSize: 11,
              height: 1.3,
            ),
          ),
          if (!cargando && alRecargar != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: alRecargar,
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: const Text('Reintentar', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PieAccionesPistas extends StatelessWidget {
  final bool mostrarCargarExterno;
  final VoidCallback alCargarExterno;
  final VoidCallback? alAbrirSincronizacion;

  const _PieAccionesPistas({
    required this.mostrarCargarExterno,
    required this.alCargarExterno,
    this.alAbrirSincronizacion,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          if (mostrarCargarExterno) ...[
            Expanded(
              child: _BotonAccionPie(
                icono: Icons.file_open_rounded,
                etiqueta: 'Subtítulo externo',
                colorIcono: ColoresApp.acentoPrimario,
                alPresionar: alCargarExterno,
              ),
            ),
            if (alAbrirSincronizacion != null) const SizedBox(width: 8),
          ],
          if (alAbrirSincronizacion != null)
            Expanded(
              child: _BotonAccionPie(
                icono: Icons.sync_rounded,
                etiqueta: 'Sincronizar',
                colorIcono: ColoresApp.acentoAmbar,
                alPresionar: alAbrirSincronizacion!,
              ),
            ),
        ],
      ),
    );
  }
}

class _BotonAccionPie extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final Color colorIcono;
  final VoidCallback alPresionar;

  const _BotonAccionPie({
    required this.icono,
    required this.etiqueta,
    required this.colorIcono,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: alPresionar,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 0.8,
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 38),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icono, size: 15, color: colorIcono),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      etiqueta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
