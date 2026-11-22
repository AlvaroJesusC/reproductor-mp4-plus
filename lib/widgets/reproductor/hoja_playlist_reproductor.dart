import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../constantes/colores_app.dart';
import '../../modelos/modelo_orden_videos.dart';
import '../../modelos/modelo_video.dart';
import '../../servicios/servicio_almacenamiento_video.dart';
import '../../servicios/servicio_duracion_video.dart';
import '../../servicios/servicio_miniaturas_video.dart';
import '../../servicios/servicio_preferencias.dart';
import '../modal_orden_videos.dart';

/// Panel lateral izquierdo cinemático que muestra la lista de reproducción con
/// miniaturas 16:9, duración, progreso en tiempo real y animación fluida de
/// entrada y salida desde el borde izquierdo (opuesto al panel de ajustes).
class HojaPlaylistReproductor extends StatefulWidget {
  final List<ModeloVideo> listaVideos;
  final int indiceActual;
  final bool reproduccionAutomatica;
  final CriterioOrdenVideos? criterioOrden;
  final void Function(ModeloVideo video, int nuevoIndice) alSeleccionarVideo;
  final ValueChanged<bool>? alAlternarReproduccionAutomatica;
  final ValueChanged<CriterioOrdenVideos>? alCambiarCriterioOrden;

  const HojaPlaylistReproductor({
    super.key,
    required this.listaVideos,
    required this.indiceActual,
    this.reproduccionAutomatica = true,
    this.criterioOrden,
    required this.alSeleccionarVideo,
    this.alAlternarReproduccionAutomatica,
    this.alCambiarCriterioOrden,
  });

  /// Despliega la lista de reproducción desde el lateral izquierdo con
  /// animación fluida de deslizamiento y desvanecimiento.
  static Future<void> mostrar(
    BuildContext context, {
    required List<ModeloVideo> listaVideos,
    required int indiceActual,
    bool reproduccionAutomatica = true,
    CriterioOrdenVideos? criterioOrden,
    required void Function(ModeloVideo video, int nuevoIndice)
    alSeleccionarVideo,
    ValueChanged<bool>? alAlternarReproduccionAutomatica,
    ValueChanged<CriterioOrdenVideos>? alCambiarCriterioOrden,
  }) {
    final reducirMovimiento = MediaQuery.disableAnimationsOf(context);
    return Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierLabel: 'Cerrar lista de videos',
        // Barrera transparente para mantener el video visible en el centro y derecha
        barrierColor: Colors.transparent,
        transitionDuration: reducirMovimiento
            ? Duration.zero
            : const Duration(milliseconds: 240),
        reverseTransitionDuration: reducirMovimiento
            ? Duration.zero
            : const Duration(milliseconds: 280),
        pageBuilder: (ctx, anim, secondaryAnim) {
          return Align(
            alignment: Alignment.centerLeft,
            child: RepaintBoundary(
              child: HojaPlaylistReproductor(
                listaVideos: listaVideos,
                indiceActual: indiceActual,
                reproduccionAutomatica: reproduccionAutomatica,
                criterioOrden: criterioOrden,
                alSeleccionarVideo: alSeleccionarVideo,
                alAlternarReproduccionAutomatica:
                    alAlternarReproduccionAutomatica,
                alCambiarCriterioOrden: alCambiarCriterioOrden,
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
          final opacidad = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOut,
            reverseCurve: Curves.easeOut,
          );

          return FadeTransition(
            opacity: opacidad,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-1.0, 0.0),
                end: Offset.zero,
              ).animate(animacionCurva),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  State<HojaPlaylistReproductor> createState() =>
      _HojaPlaylistReproductorState();
}

class _HojaPlaylistReproductorState extends State<HojaPlaylistReproductor> {
  static const double _alturaEstimadaFila = 76.0;

  final TextEditingController _controladorFiltro = TextEditingController();
  late final ScrollController _controladorScroll;
  late List<ModeloVideo> _listaVideos;
  late int _indiceActual;
  late CriterioOrdenVideos _criterioOrden;
  String _filtroTexto = '';
  late bool _reproduccionAutomatica;

  @override
  void initState() {
    super.initState();
    _reproduccionAutomatica = widget.reproduccionAutomatica;
    _listaVideos = List<ModeloVideo>.from(widget.listaVideos);
    _criterioOrden =
        widget.criterioOrden ?? ServicioPreferencias.criterioOrdenNotifier.value;
    _indiceActual = widget.indiceActual.clamp(
      0,
      _listaVideos.isEmpty ? 0 : _listaVideos.length - 1,
    );
    _controladorScroll = ScrollController(
      initialScrollOffset: _indiceActual > 1
          ? (_indiceActual - 1) * _alturaEstimadaFila
          : 0.0,
    );
    unawaited(_refrescarMetadatosYProgreso());
  }

  Future<void> _mostrarSelectorOrden() async {
    final seleccionado = await ModalOrdenVideos.mostrar(
      context,
      criterioActual: _criterioOrden,
      usarNavegadorRaiz: true,
    );
    if (seleccionado == null || !mounted) return;

    final rutaActual =
        (_indiceActual >= 0 && _indiceActual < _listaVideos.length)
        ? _listaVideos[_indiceActual].ruta
        : null;

    OrdenadorVideos.ordenarVideos(_listaVideos, seleccionado);
    final nuevoIndice = rutaActual == null
        ? 0
        : _listaVideos.indexWhere((v) => v.ruta == rutaActual);

    setState(() {
      _criterioOrden = seleccionado;
      _indiceActual = nuevoIndice >= 0 ? nuevoIndice : 0;
    });
    widget.alCambiarCriterioOrden?.call(seleccionado);
  }

  Future<void> _refrescarMetadatosYProgreso() async {
    try {
      await ServicioMiniaturasVideo.inicializar();
      if (!mounted) return;

      // Guardar el estado en vivo del video actual antes de enriquecer desde disco
      final actual = (_indiceActual >= 0 && _indiceActual < _listaVideos.length)
          ? _listaVideos[_indiceActual]
          : null;
      final posVivo = actual?.posicionGuardadaMs ?? 0;
      final durVivo = actual?.duracionTotalMs ?? 0;

      await ServicioPreferencias.enriquecerVideosConProgreso(_listaVideos);

      if (actual != null) {
        if (durVivo > 0) actual.duracionTotalMs = durVivo;
        if (posVivo > 0 && !actual.estaCompletado) {
          actual.posicionGuardadaMs = posVivo;
        }
      }
      if (!mounted) return;
      setState(() {});

      final huboCambios =
          await ServicioAlmacenamientoVideo.completarDuracionesFaltantes(
            _listaVideos,
          );
      if (huboCambios && mounted) {
        setState(() {});
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _controladorFiltro.dispose();
    _controladorScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tamano = MediaQuery.sizeOf(context);
    final esHorizontal = tamano.width > tamano.height;
    final anchoPanel = esHorizontal
        ? (tamano.width * 0.44).clamp(300.0, 380.0)
        : (tamano.width * 0.82).clamp(280.0, 360.0);

    final filtro = _filtroTexto.trim().toLowerCase();
    final listaFiltrada = _listaVideos.where((v) {
      if (filtro.isEmpty) return true;
      return v.nombreSinExtension.toLowerCase().contains(filtro);
    }).toList();

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0.0) < -450.0) {
            Navigator.of(context).pop();
          }
        },
        child: Container(
          width: anchoPanel,
          height: double.infinity,
          decoration: BoxDecoration(
            // Misma translucidez cinemática que el panel derecho de ajustes
            color: ColoresApp.fondoModalTranslucido,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(18),
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(4, 0),
              ),
            ],
          ),
          child: SafeArea(
            right: false,
            child: Column(
              children: [
                _EncabezadoHojaPlaylist(
                  cantidadVideos: _listaVideos.length,
                  reproduccionAutomatica: _reproduccionAutomatica,
                  alAlternarAuto: (val) {
                    setState(() => _reproduccionAutomatica = val);
                    widget.alAlternarReproduccionAutomatica?.call(val);
                  },
                ),
                Divider(
                  height: 1,
                  thickness: 0.8,
                  color: Colors.white.withValues(alpha: 0.12),
                ),

                // Buscador rápido y/o selector de ordenación de la lista
                if (_listaVideos.length > 5)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _BuscadorHojaPlaylist(
                            controlador: _controladorFiltro,
                            alCambiar: (val) =>
                                setState(() => _filtroTexto = val),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _BotonOrdenHojaPlaylist(
                          criterio: _criterioOrden,
                          alPresionar: _mostrarSelectorOrden,
                        ),
                      ],
                    ),
                  )
                else if (_listaVideos.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                    child: _BarraOrdenCompactaPlaylist(
                      criterio: _criterioOrden,
                      alPresionar: _mostrarSelectorOrden,
                    ),
                  ),

                // Lista de videos con miniaturas 16:9, duración y progreso
                Expanded(
                  child: listaFiltrada.isEmpty
                      ? const Center(
                          child: Text(
                            'No se encontraron videos',
                            style: TextStyle(color: ColoresApp.textoSecundario),
                          ),
                        )
                      : ListView.builder(
                          controller: _controladorScroll,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          cacheExtent: 320,
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          itemCount: listaFiltrada.length,
                          itemBuilder: (context, index) {
                            final video = listaFiltrada[index];
                            final indiceReal = _listaVideos.indexOf(video);
                            final esActual = indiceReal == _indiceActual;

                            return RepaintBoundary(
                              key: ValueKey(video.ruta),
                              child: _ElementoVideoPlaylist(
                                video: video,
                                esActual: esActual,
                                alPresionar: () {
                                  Navigator.of(context).pop();
                                  if (!esActual) {
                                    widget.alSeleccionarVideo(
                                      video,
                                      indiceReal,
                                    );
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EncabezadoHojaPlaylist extends StatelessWidget {
  final int cantidadVideos;
  final bool reproduccionAutomatica;
  final ValueChanged<bool> alAlternarAuto;

  const _EncabezadoHojaPlaylist({
    required this.cantidadVideos,
    required this.reproduccionAutomatica,
    required this.alAlternarAuto,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: ColoresApp.acentoPrimario.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.playlist_play_rounded,
              color: ColoresApp.acentoPrimario,
              size: 17,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Lista de Videos ($cantidadVideos)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Auto',
            style: TextStyle(
              color: reproduccionAutomatica ? Colors.white : Colors.white54,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(
            width: 44,
            height: 28,
            child: Transform.scale(
              scale: 0.72,
              child: Switch(
                value: reproduccionAutomatica,
                activeThumbColor: ColoresApp.acentoPrimario,
                activeTrackColor: ColoresApp.acentoPrimario.withValues(
                  alpha: 0.4,
                ),
                inactiveThumbColor: const Color(0xFF8B949E),
                inactiveTrackColor: const Color(0xFF21262D),
                onChanged: alAlternarAuto,
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

class _BuscadorHojaPlaylist extends StatelessWidget {
  final TextEditingController controlador;
  final ValueChanged<String> alCambiar;

  const _BuscadorHojaPlaylist({
    required this.controlador,
    required this.alCambiar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: TextField(
        controller: controlador,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        onChanged: alCambiar,
        decoration: const InputDecoration(
          hintText: 'Filtrar episodio o película...',
          hintStyle: TextStyle(color: ColoresApp.textoSecundario, fontSize: 12),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: ColoresApp.textoSecundario,
            size: 17,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }
}

final class _BotonOrdenHojaPlaylist extends StatelessWidget {
  final CriterioOrdenVideos criterio;
  final VoidCallback alPresionar;

  const _BotonOrdenHojaPlaylist({
    required this.criterio,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Ordenar (${criterio.etiqueta})',
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: alPresionar,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Icon(
              Icons.sort_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

final class _BarraOrdenCompactaPlaylist extends StatelessWidget {
  final CriterioOrdenVideos criterio;
  final VoidCallback alPresionar;

  const _BarraOrdenCompactaPlaylist({
    required this.criterio,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Material(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: alPresionar,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.sort_rounded,
                  color: ColoresApp.textoSecundario,
                  size: 14,
                ),
                const SizedBox(width: 5),
                Text(
                  criterio.etiqueta,
                  style: const TextStyle(
                    color: ColoresApp.textoSecundario,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ElementoVideoPlaylist extends StatelessWidget {
  final ModeloVideo video;
  final bool esActual;
  final VoidCallback alPresionar;

  const _ElementoVideoPlaylist({
    required this.video,
    required this.esActual,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    final enMemoria = ServicioDuracionVideo.obtenerDuracionEnMemoria(video);
    if (enMemoria != null) {
      return _construirContenidoConDuracion(duracionMs: enMemoria);
    }

    return FutureBuilder<int>(
      future: ServicioDuracionVideo.obtenerDuracion(video),
      builder: (context, snapshot) {
        final duracionMs = snapshot.data ?? video.duracionTotalMs;
        return _construirContenidoConDuracion(duracionMs: duracionMs);
      },
    );
  }

  Widget _construirContenidoConDuracion({required int duracionMs}) {
    final estaCompletado = video.estaCompletado;
    final tieneProgreso =
        video.tieneProgreso ||
        (esActual &&
            !estaCompletado &&
            duracionMs > 0 &&
            video.posicionGuardadaMs > 0);
    final porcentaje = duracionMs > 0 && video.posicionGuardadaMs > 0
        ? (video.posicionGuardadaMs / duracionMs).clamp(0.0, 1.0)
        : video.porcentajeVisto;
    final porcentajeEntero = (porcentaje * 100).round().clamp(1, 99);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3.5),
      decoration: BoxDecoration(
        color: esActual
            ? ColoresApp.acentoPrimario.withValues(alpha: 0.20)
            : Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: esActual
              ? ColoresApp.acentoPrimario.withValues(alpha: 0.58)
              : Colors.white.withValues(alpha: 0.10),
          width: esActual ? 1.1 : 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: alPresionar,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _MiniaturaPlaylist(
                  video: video,
                  duracionMs: duracionMs,
                  ancho: 96.0,
                  alto: 54.0,
                  esActual: esActual,
                  estaCompletado: estaCompletado,
                  tieneProgreso: tieneProgreso,
                  porcentaje: porcentaje,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        video.nombreSinExtension,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: esActual
                              ? Colors.white
                              : const Color(0xFFF0F6FC),
                          fontSize: 12.5,
                          fontWeight: esActual
                              ? FontWeight.bold
                              : FontWeight.w500,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _EstadoProgresoTexto(
                        video: video,
                        duracionMs: duracionMs,
                        esActual: esActual,
                        estaCompletado: estaCompletado,
                        tieneProgreso: tieneProgreso,
                        porcentajeEntero: porcentajeEntero,
                      ),
                      if (video.extension.isNotEmpty || video.esFavorito) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (video.extension.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  video.extension.toUpperCase(),
                                  style: const TextStyle(
                                    color: ColoresApp.textoSecundario,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (video.esFavorito)
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFFFD700),
                                size: 12.5,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniaturaPlaylist extends StatelessWidget {
  final ModeloVideo video;
  final int duracionMs;
  final double ancho;
  final double alto;
  final bool esActual;
  final bool estaCompletado;
  final bool tieneProgreso;
  final double porcentaje;

  const _MiniaturaPlaylist({
    required this.video,
    required this.duracionMs,
    required this.ancho,
    required this.alto,
    required this.esActual,
    required this.estaCompletado,
    required this.tieneProgreso,
    required this.porcentaje,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ancho,
      height: alto,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ColoredBox(
              color: ColoresApp.fondoTarjeta,
              child: _ImagenMiniaturaPlaylist(video: video),
            ),
          ),
          if (esActual)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.black.withValues(alpha: 0.25),
                  border: Border.all(
                    color: ColoresApp.acentoPrimario,
                    width: 1.4,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.equalizer_rounded,
                    color: ColoresApp.acentoPrimario,
                    size: 22,
                  ),
                ),
              ),
            )
          else
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: estaCompletado
                        ? ColoresApp.acentoVerde.withValues(alpha: 0.5)
                        : ColoresApp.bordeSutil,
                    width: 0.9,
                  ),
                ),
              ),
            ),
          if (estaCompletado)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: ColoresApp.acentoVerde.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(3.5),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.black,
                  size: 10,
                ),
              ),
            ),
          if (duracionMs > 0)
            Positioned(
              bottom: tieneProgreso ? 5 : 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4.5,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: ColoresApp.fondoPastillaTiempo,
                  borderRadius: BorderRadius.circular(3.5),
                ),
                child: Text(
                  ModeloVideo.formatearTiempo(duracionMs),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          if (tieneProgreso && !estaCompletado)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(8),
                ),
                child: LinearProgressIndicator(
                  value: math.max(0.03, porcentaje),
                  backgroundColor: Colors.black54,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    ColoresApp.barraProgreso,
                  ),
                  minHeight: 2.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImagenMiniaturaPlaylist extends StatelessWidget {
  final ModeloVideo video;

  const _ImagenMiniaturaPlaylist({required this.video});

  @override
  Widget build(BuildContext context) {
    final enMemoria = ServicioMiniaturasVideo.obtenerMiniaturaEnMemoria(video);
    if (enMemoria != null) {
      return Image.file(
        File(enMemoria),
        fit: BoxFit.cover,
        cacheWidth: 260,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) =>
            const _PlaceholderMiniaturaPlaylist(),
      );
    }

    return FutureBuilder<String?>(
      future: ServicioMiniaturasVideo.obtenerMiniatura(video),
      builder: (context, snapshot) {
        final rutaMiniatura = snapshot.data;
        if (rutaMiniatura == null) {
          return const _PlaceholderMiniaturaPlaylist();
        }
        return Image.file(
          File(rutaMiniatura),
          fit: BoxFit.cover,
          cacheWidth: 260,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) =>
              const _PlaceholderMiniaturaPlaylist(),
        );
      },
    );
  }
}

class _PlaceholderMiniaturaPlaylist extends StatelessWidget {
  const _PlaceholderMiniaturaPlaylist();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.movie_outlined,
        color: ColoresApp.textoAtenuado,
        size: 22,
      ),
    );
  }
}

class _EstadoProgresoTexto extends StatelessWidget {
  final ModeloVideo video;
  final int duracionMs;
  final bool esActual;
  final bool estaCompletado;
  final bool tieneProgreso;
  final int porcentajeEntero;

  const _EstadoProgresoTexto({
    required this.video,
    required this.duracionMs,
    required this.esActual,
    required this.estaCompletado,
    required this.tieneProgreso,
    required this.porcentajeEntero,
  });

  @override
  Widget build(BuildContext context) {
    final textoDuracion = ModeloVideo.formatearTiempo(duracionMs);

    if (esActual) {
      final textoTiempo = duracionMs > 0
          ? 'Reproduciendo · ${video.tiempoGuardadoLegible} / $textoDuracion'
          : 'Reproduciendo ahora';
      return Text(
        textoTiempo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: ColoresApp.acentoPrimario,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      );
    }

    if (estaCompletado) {
      return Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: ColoresApp.acentoVerde,
            size: 12,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              duracionMs > 0 ? 'Completado · $textoDuracion' : 'Completado',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ColoresApp.acentoVerde,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      );
    }

    if (tieneProgreso) {
      return Row(
        children: [
          const Icon(
            Icons.play_circle_outline_rounded,
            color: ColoresApp.acentoAmbar,
            size: 12,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              duracionMs > 0
                  ? '${video.tiempoGuardadoLegible} / $textoDuracion ($porcentajeEntero%)'
                  : '${video.tiempoGuardadoLegible} ($porcentajeEntero%)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ColoresApp.acentoAmbar,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      );
    }

    return Text(
      duracionMs > 0 ? textoDuracion : '--:--',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: ColoresApp.textoSecundario,
        fontSize: 11,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}
