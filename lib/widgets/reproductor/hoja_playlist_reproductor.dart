import 'package:flutter/material.dart';
import '../../constantes/colores_app.dart';
import '../../modelos/modelo_video.dart';

/// Hoja deslizable inferior (Bottom Sheet) que permite explorar y cambiar de episodio/video
/// dentro de la misma carpeta sin tener que salir del reproductor.
class HojaPlaylistReproductor extends StatefulWidget {
  final List<ModeloVideo> listaVideos;
  final int indiceActual;
  final bool reproduccionAutomatica;
  final void Function(ModeloVideo video, int nuevoIndice) alSeleccionarVideo;
  final ValueChanged<bool>? alAlternarReproduccionAutomatica;

  const HojaPlaylistReproductor({
    super.key,
    required this.listaVideos,
    required this.indiceActual,
    this.reproduccionAutomatica = true,
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => HojaPlaylistReproductor(
          listaVideos: listaVideos,
          indiceActual: indiceActual,
          reproduccionAutomatica: reproduccionAutomatica,
          alSeleccionarVideo: alSeleccionarVideo,
          alAlternarReproduccionAutomatica: alAlternarReproduccionAutomatica,
        ),
      ),
    );
  }

  @override
  State<HojaPlaylistReproductor> createState() =>
      _HojaPlaylistReproductorState();
}

class _HojaPlaylistReproductorState extends State<HojaPlaylistReproductor> {
  final TextEditingController _controladorFiltro = TextEditingController();
  String _filtroTexto = '';
  late bool _reproduccionAutomatica;

  @override
  void initState() {
    super.initState();
    _reproduccionAutomatica = widget.reproduccionAutomatica;
  }

  @override
  void dispose() {
    _controladorFiltro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtro = _filtroTexto.trim().toLowerCase();
    final listaFiltrada = widget.listaVideos.where((v) {
      if (filtro.isEmpty) return true;
      return v.nombreSinExtension.toLowerCase().contains(filtro);
    }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          // Tirador de arrastre superior
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Título de la lista y Switch Auto estilo YouTube
          Row(
            children: [
              const Icon(
                Icons.playlist_play_rounded,
                color: ColoresApp.acentoPrimario,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Lista de Videos (${widget.listaVideos.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Auto',
                    style: TextStyle(
                      color: _reproduccionAutomatica
                          ? Colors.white
                          : Colors.white54,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _reproduccionAutomatica,
                      activeThumbColor: ColoresApp.acentoPrimario,
                      activeTrackColor: ColoresApp.acentoPrimario.withValues(
                        alpha: 0.4,
                      ),
                      inactiveThumbColor: const Color(0xFF8B949E),
                      inactiveTrackColor: const Color(0xFF21262D),
                      onChanged: (val) {
                        setState(() => _reproduccionAutomatica = val);
                        widget.alAlternarReproduccionAutomatica?.call(val);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Buscador rápido si hay más de 5 videos
          if (widget.listaVideos.length > 5) ...[
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: TextField(
                controller: _controladorFiltro,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                onChanged: (val) => setState(() => _filtroTexto = val),
                decoration: const InputDecoration(
                  hintText: 'Filtrar episodio o película...',
                  hintStyle: TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 12.5,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Color(0xFF8B949E),
                    size: 18,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 9),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Lista de elementos con scroll
          Expanded(
            child: listaFiltrada.isEmpty
                ? const Center(
                    child: Text(
                      'No se encontraron videos',
                      style: TextStyle(color: Color(0xFF8B949E)),
                    ),
                  )
                : ListView.builder(
                    itemCount: listaFiltrada.length,
                    itemBuilder: (context, index) {
                      final video = listaFiltrada[index];
                      final indiceReal = widget.listaVideos.indexOf(video);
                      final esActual = indiceReal == widget.indiceActual;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          color: esActual
                              ? ColoresApp.acentoPrimario.withValues(
                                  alpha: 0.15,
                                )
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: esActual
                              ? Border.all(
                                  color: ColoresApp.acentoPrimario.withValues(
                                    alpha: 0.5,
                                  ),
                                  width: 1,
                                )
                              : null,
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            esActual
                                ? Icons.play_circle_fill_rounded
                                : Icons.play_circle_outline_rounded,
                            color: esActual
                                ? ColoresApp.acentoPrimario
                                : const Color(0xFF8B949E),
                            size: 24,
                          ),
                          title: Text(
                            video.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: esActual
                                  ? Colors.white
                                  : const Color(0xFFF0F6FC),
                              fontSize: 13.5,
                              fontWeight: esActual
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            video.duracionTotalMs > 0
                                ? '${video.duracionTotalLegible} • ${video.tamanoLegible}'
                                : video.tamanoLegible,
                            style: TextStyle(
                              color: esActual
                                  ? ColoresApp.acentoPrimario.withValues(
                                      alpha: 0.8,
                                    )
                                  : const Color(0xFF8B949E),
                              fontSize: 11,
                            ),
                          ),
                          onTap: () {
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
