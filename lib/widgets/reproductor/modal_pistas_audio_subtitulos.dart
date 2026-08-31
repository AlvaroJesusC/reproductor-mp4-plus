import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../constantes/colores_app.dart';

/// Modal para seleccionar pistas de audio y subtítulos incrustados o externos.
class ModalPistasAudioSubtitulos extends StatelessWidget {
  final Tracks pistas;
  final AudioTrack pistaAudioActual;
  final SubtitleTrack pistaSubtituloActual;
  final ValueChanged<AudioTrack> alSeleccionarAudio;
  final ValueChanged<SubtitleTrack> alSeleccionarSubtitulo;

  const ModalPistasAudioSubtitulos({
    super.key,
    required this.pistas,
    required this.pistaAudioActual,
    required this.pistaSubtituloActual,
    required this.alSeleccionarAudio,
    required this.alSeleccionarSubtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Dialog(
        backgroundColor: ColoresApp.fondoSecundario,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 380,
          constraints: const BoxConstraints(maxHeight: 450),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra de pestañas (Audio / Subtítulos)
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: ColoresApp.bordeOSD, width: 1)),
                ),
                child: const TabBar(
                  indicatorColor: ColoresApp.acentoPrimario,
                  labelColor: Colors.white,
                  unselectedLabelColor: ColoresApp.textoSecundario,
                  tabs: [
                    Tab(icon: Icon(Icons.audiotrack_rounded, size: 20), text: 'Pistas de Audio'),
                    Tab(icon: Icon(Icons.subtitles_rounded, size: 20), text: 'Subtítulos'),
                  ],
                ),
              ),

              // Contenido de las pestañas
              Flexible(
                child: TabBarView(
                  children: [
                    // 1. Pistas de Audio
                    _construirListaAudio(context),

                    // 2. Subtítulos
                    _construirListaSubtitulos(context),
                  ],
                ),
              ),

              // Botón cerrar
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar', style: TextStyle(color: ColoresApp.acentoPrimario)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirListaAudio(BuildContext context) {
    final audios = pistas.audio;
    if (audios.isEmpty) {
      return const Center(
        child: Text('No hay pistas de audio disponibles', style: TextStyle(color: ColoresApp.textoSecundario)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: audios.length,
      itemBuilder: (ctx, i) {
        final track = audios[i];
        final esActual = track.id == pistaAudioActual.id;
        final etiqueta = track.title ?? track.language ?? 'Pista de audio #${track.id}';

        return ListTile(
          dense: true,
          leading: Icon(
            esActual ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
            color: esActual ? ColoresApp.acentoPrimario : ColoresApp.textoSecundario,
            size: 20,
          ),
          title: Text(
            etiqueta,
            style: TextStyle(
              color: esActual ? Colors.white : ColoresApp.textoSecundario,
              fontWeight: esActual ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          onTap: () {
            alSeleccionarAudio(track);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  Widget _construirListaSubtitulos(BuildContext context) {
    final subtitulos = [
      SubtitleTrack.no(),
      SubtitleTrack.auto(),
      ...pistas.subtitle.where((s) => s.id != 'no' && s.id != 'auto'),
    ];

    return ListView.builder(
      shrinkWrap: true,
      itemCount: subtitulos.length,
      itemBuilder: (ctx, i) {
        final track = subtitulos[i];
        final esActual = track.id == pistaSubtituloActual.id;
        String etiqueta = 'Desactivados';
        if (track.id == 'auto') {
          etiqueta = 'Automático';
        } else if (track.id != 'no') {
          etiqueta = track.title ?? track.language ?? 'Subtítulo #${track.id}';
        }

        return ListTile(
          dense: true,
          leading: Icon(
            esActual ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
            color: esActual ? ColoresApp.acentoPrimario : ColoresApp.textoSecundario,
            size: 20,
          ),
          title: Text(
            etiqueta,
            style: TextStyle(
              color: esActual ? Colors.white : ColoresApp.textoSecundario,
              fontWeight: esActual ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          onTap: () {
            alSeleccionarSubtitulo(track);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }
}
