import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../constantes/colores_app.dart';
import '../../modelos/modelo_video.dart';
import '../../servicios/servicio_almacenamiento_video.dart';
import '../../servicios/servicio_duracion_video.dart';
import '../../servicios/servicio_miniaturas_video.dart';
import '../../servicios/servicio_preferencias.dart';

/// Hoja deslizable inferior (Bottom Sheet) compacta y expandible que muestra la
/// lista de reproducción con miniaturas 16:9, duración y progreso en tiempo real.
class HojaPlaylistReproductor extends StatefulWidget {
  final List<ModeloVideo> listaVideos;
  final int indiceActual;
  final bool reproduccionAutomatica;
  final ScrollController? scrollController;
  final DraggableScrollableController? sheetController;
  final ValueNotifier<bool>? expandidoNotifier;
  final double tamanoInicial;
  final double tamanoMinimo;
  final double tamanoMaximo;
  final void Function(ModeloVideo video, int nuevoIndice) alSeleccionarVideo;
  final ValueChanged<bool>? alAlternarReproduccionAutomatica;

  const HojaPlaylistReproductor({
    super.key,
    required this.listaVideos,
    required this.indiceActual,
    this.reproduccionAutomatica = true,
    this.scrollController,
    this.sheetController,
    this.expandidoNotifier,
    this.tamanoInicial = 0.56,
    this.tamanoMinimo = 0.34,
    this.tamanoMaximo = 0.94,
    required this.alSeleccionarVideo,
    this.alAlternarReproduccionAutomatica,
  });

  static void mostrar(
    BuildContext context, {
    required List<ModeloVideo> listaVideos,
    required int indiceActual,
    bool reproduccionAutomatica = true,
    required void Function(ModeloVideo video, int nuevoIndice)
        alSeleccionarVideo,
    ValueChanged<bool>? alAlternarReproduccionAutomatica,
  }) {
    final tamano = MediaQuery.sizeOf(context);
    final esHorizontal = tamano.width > tamano.height;
    final anchoMaximo = esHorizontal
        ? (tamano.width * 0.54).clamp(340.0, 440.0)
        : (tamano.width * 0.94).clamp(300.0, 440.0);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(maxWidth: anchoMaximo),
      isScrollControlled: true,
      builder: (_) => _ContenedorHojaPlaylist(
        listaVideos: listaVideos,
        indiceActual: indiceActual,
        reproduccionAutomatica: reproduccionAutomatica,
        alSeleccionarVideo: alSeleccionarVideo,
        alAlternarReproduccionAutomatica: alAlternarReproduccionAutomatica,
      ),
    );
  }

  @override
  State<HojaPlaylistReproductor> createState() =>
      _HojaPlaylistReproductorState();
}

class _ContenedorHojaPlaylist extends StatefulWidget {
  final List<ModeloVideo> listaVideos;
  final int indiceActual;
  final bool reproduccionAutomatica;
  final void Function(ModeloVideo video, int nuevoIndice) alSeleccionarVideo;
  final ValueChanged<bool>? alAlternarReproduccionAutomatica;

  const _ContenedorHojaPlaylist({
    required this.listaVideos,
    required this.indiceActual,
    required this.reproduccionAutomatica,
    required this.alSeleccionarVideo,
    this.alAlternarReproduccionAutomatica,
  });

  @override
  State<_ContenedorHojaPlaylist> createState() =>
      _ContenedorHojaPlaylistState();
}

class _ContenedorHojaPlaylistState extends State<_ContenedorHojaPlaylist> {
  static const double _tamanoInicial = 0.56;
  static const double _tamanoMinimo = 0.34;
  static const double _tamanoMaximo = 0.94;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final ValueNotifier<bool> _expandidoNotifier = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_alCambiarTamanoSheet);
  }

  void _alCambiarTamanoSheet() {
    if (!mounted || !_sheetController.isAttached) return;
    final expandido = _sheetController.size >= 0.74;
    if (_expandidoNotifier.value != expandido) {
      _expandidoNotifier.value = expandido;
    }
  }

  @override
  void dispose() {
    _sheetController.removeListener(_alCambiarTamanoSheet);
    _sheetController.dispose();
    _expandidoNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: _tamanoInicial,
      minChildSize: _tamanoMinimo,
      maxChildSize: _tamanoMaximo,
      snap: true,
      snapSizes: const [_tamanoInicial, _tamanoMaximo],
      expand: false,
      builder: (ctx, scrollController) => HojaPlaylistReproductor(
        listaVideos: widget.listaVideos,
        indiceActual: widget.indiceActual,
        reproduccionAutomatica: widget.reproduccionAutomatica,
        scrollController: scrollController,
        sheetController: _sheetController,
        expandidoNotifier: _expandidoNotifier,
        tamanoInicial: _tamanoInicial,
        tamanoMinimo: _tamanoMinimo,
        tamanoMaximo: _tamanoMaximo,
        alSeleccionarVideo: widget.alSeleccionarVideo,
        alAlternarReproduccionAutomatica:
            widget.alAlternarReproduccionAutomatica,
      ),
    );
  }
}

class _HojaPlaylistReproductorState extends State<HojaPlaylistReproductor> {
  final TextEditingController _controladorFiltro = TextEditingController();
  String _filtroTexto = '';
  late bool _reproduccionAutomatica;

  @override
  void initState() {
    super.initState();
    _reproduccionAutomatica = widget.reproduccionAutomatica;
    unawaited(_refrescarMetadatosYProgreso());
  }

  Future<void> _refrescarMetadatosYProgreso() async {
    try {
      await ServicioMiniaturasVideo.inicializar();
      if (!mounted) return;

      // Guardar el estado en vivo del video actual antes de enriquecer desde disco
      final actual =
          (widget.indiceActual >= 0 &&
              widget.indiceActual < widget.listaVideos.length)
          ? widget.listaVideos[widget.indiceActual]
          : null;
      final posVivo = actual?.posicionGuardadaMs ?? 0;
      final durVivo = actual?.duracionTotalMs ?? 0;

      await ServicioPreferencias.enriquecerVideosConProgreso(
        widget.listaVideos,
      );

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
            widget.listaVideos,
          );
      if (huboCambios && mounted) {
        setState(() {});
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _controladorFiltro.dispose();
    super.dispose();
  }

  void _alternarExpansion() {
    final controller = widget.sheetController;
    if (controller == null || !controller.isAttached) return;
    final destino = controller.size >= 0.74
        ? widget.tamanoInicial
        : widget.tamanoMaximo;
    unawaited(
      controller.animateTo(
        destino,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _alArrastrarEncabezado(DragUpdateDetails details) {
    final controller = widget.sheetController;
    if (controller == null || !controller.isAttached) return;
    final altoPantalla = MediaQuery.sizeOf(context).height;
    if (altoPantalla <= 0) return;

    final deltaFraccion = -details.delta.dy / altoPantalla;
    final nuevoTamano = (controller.size + deltaFraccion).clamp(
      widget.tamanoMinimo,
      widget.tamanoMaximo,
    );
    controller.jumpTo(nuevoTamano);
  }

  void _alSoltarEncabezado(DragEndDetails details) {
    final controller = widget.sheetController;
    if (controller == null || !controller.isAttached) return;
    final velocidadY = details.primaryVelocity ?? 0.0;

    if (velocidadY > 750 && controller.size <= widget.tamanoInicial + 0.04) {
      Navigator.of(context).pop();
      return;
    }

    final expandir = velocidadY < -280 ||
        (velocidadY <= 280 &&
            controller.size >=
                (widget.tamanoInicial + widget.tamanoMaximo) / 2);

    final destino = expandir ? widget.tamanoMaximo : widget.tamanoInicial;
    unawaited(
      controller.animateTo(
        destino,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtro = _filtroTexto.trim().toLowerCase();
    final listaFiltrada = widget.listaVideos.where((v) {
      if (filtro.isEmpty) return true;
      return v.nombreSinExtension.toLowerCase().contains(filtro);
    }).toList();

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 14, 6),
      child: Column(
        children: [
          // Zona arrastrable superior (tirador + título) para subir/expandir fácilmente
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: _alArrastrarEncabezado,
            onVerticalDragEnd: _alSoltarEncabezado,
            child: _EncabezadoHojaPlaylist(
              cantidadVideos: widget.listaVideos.length,
              reproduccionAutomatica: _reproduccionAutomatica,
              expandidoNotifier: widget.expandidoNotifier,
              alAlternarExpansion: widget.sheetController != null
                  ? _alternarExpansion
                  : null,
              alAlternarAuto: (val) {
                setState(() => _reproduccionAutomatica = val);
                widget.alAlternarReproduccionAutomatica?.call(val);
              },
            ),
          ),
          const SizedBox(height: 10),

          // Buscador rápido si hay más de 5 videos
          if (widget.listaVideos.length > 5) ...[
            _BuscadorHojaPlaylist(
              controlador: _controladorFiltro,
              alCambiar: (val) => setState(() => _filtroTexto = val),
            ),
            const SizedBox(height: 8),
          ],

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
                    controller: widget.scrollController,
                    cacheExtent: 320,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    itemCount: listaFiltrada.length,
                    itemBuilder: (context, index) {
                      final video = listaFiltrada[index];
                      final indiceReal = widget.listaVideos.indexOf(video);
                      final esActual = indiceReal == widget.indiceActual;

                      return RepaintBoundary(
                        key: ValueKey(video.ruta),
                        child: _ElementoVideoPlaylist(
                          video: video,
                          esActual: esActual,
                          expandidoNotifier: widget.expandidoNotifier,
                          alPresionar: () {
                            Navigator.of(context).pop();
                            if (!esActual) {
                              widget.alSeleccionarVideo(video, indiceReal);
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EncabezadoHojaPlaylist extends StatelessWidget {
  final int cantidadVideos;
  final bool reproduccionAutomatica;
  final ValueNotifier<bool>? expandidoNotifier;
  final VoidCallback? alAlternarExpansion;
  final ValueChanged<bool> alAlternarAuto;

  const _EncabezadoHojaPlaylist({
    required this.cantidadVideos,
    required this.reproduccionAutomatica,
    this.expandidoNotifier,
    this.alAlternarExpansion,
    required this.alAlternarAuto,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tirador visual interactivo
        InkWell(
          onTap: alAlternarExpansion,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.30),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(
              Icons.playlist_play_rounded,
              color: ColoresApp.acentoPrimario,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Lista de Videos ($cantidadVideos)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (expandidoNotifier != null && alAlternarExpansion != null)
              ValueListenableBuilder<bool>(
                valueListenable: expandidoNotifier!,
                builder: (context, expandido, _) {
                  return IconButton(
                    icon: Icon(
                      expandido
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      color: Colors.white70,
                      size: 22,
                    ),
                    tooltip: expandido ? 'Contraer lista' : 'Ampliar lista',
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: alAlternarExpansion,
                  );
                },
              ),
            const SizedBox(width: 4),
            Text(
              'Auto',
              style: TextStyle(
                color: reproduccionAutomatica ? Colors.white : Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Transform.scale(
              scale: 0.76,
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
          ],
        ),
      ],
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
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextField(
        controller: controlador,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        onChanged: alCambiar,
        decoration: const InputDecoration(
          hintText: 'Filtrar episodio o película...',
          hintStyle: TextStyle(color: Color(0xFF8B949E), fontSize: 12.5),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Color(0xFF8B949E),
            size: 18,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }
}

class _ElementoVideoPlaylist extends StatelessWidget {
  final ModeloVideo video;
  final bool esActual;
  final ValueNotifier<bool>? expandidoNotifier;
  final VoidCallback alPresionar;

  const _ElementoVideoPlaylist({
    required this.video,
    required this.esActual,
    this.expandidoNotifier,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    if (expandidoNotifier == null) {
      return _construirContenido(expandido: false);
    }
    return ValueListenableBuilder<bool>(
      valueListenable: expandidoNotifier!,
      builder: (context, expandido, _) =>
          _construirContenido(expandido: expandido),
    );
  }

  Widget _construirContenido({required bool expandido}) {
    final enMemoria = ServicioDuracionVideo.obtenerDuracionEnMemoria(video);
    if (enMemoria != null) {
      return _construirContenidoConDuracion(
        expandido: expandido,
        duracionMs: enMemoria,
      );
    }

    return FutureBuilder<int>(
      future: ServicioDuracionVideo.obtenerDuracion(video),
      builder: (context, snapshot) {
        final duracionMs = snapshot.data ?? video.duracionTotalMs;
        return _construirContenidoConDuracion(
          expandido: expandido,
          duracionMs: duracionMs,
        );
      },
    );
  }

  Widget _construirContenidoConDuracion({
    required bool expandido,
    required int duracionMs,
  }) {
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

    final anchoMiniatura = expandido ? 114.0 : 96.0;
    final altoMiniatura = expandido ? 64.0 : 54.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3.5),
      decoration: BoxDecoration(
        color: esActual
            ? ColoresApp.acentoPrimario.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: esActual
              ? ColoresApp.acentoPrimario.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.06),
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
                  ancho: anchoMiniatura,
                  alto: altoMiniatura,
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
                        maxLines: expandido ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: esActual
                              ? Colors.white
                              : const Color(0xFFF0F6FC),
                          fontSize: 13,
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
                        expandido: expandido,
                      ),
                      if (expandido &&
                          (video.extension.isNotEmpty || video.esFavorito)) ...[
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
                                  color: Colors.white.withValues(alpha: 0.08),
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
  final bool expandido;

  const _EstadoProgresoTexto({
    required this.video,
    required this.duracionMs,
    required this.esActual,
    required this.estaCompletado,
    required this.tieneProgreso,
    required this.porcentajeEntero,
    required this.expandido,
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
      final sufijoPorcentaje = expandido ? ' ($porcentajeEntero%)' : '';
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
                  ? '${video.tiempoGuardadoLegible} / $textoDuracion$sufijoPorcentaje'
                  : '${video.tiempoGuardadoLegible}$sufijoPorcentaje',
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
      duracionMs > 0
          ? (expandido ? 'Duración $textoDuracion' : textoDuracion)
          : '--:--',
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
