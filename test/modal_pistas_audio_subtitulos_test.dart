import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:reproductormp4/modelos/modelo_pista_media.dart';
import 'package:reproductormp4/widgets/reproductor/modal_pistas_audio_subtitulos.dart';

void main() {
  group('EstadoPistasReproductor.construirDesdeMpv', () {
    test(
      'parsea multiples pistas de audio y subtitulos desde track-list JSON e identifica la activa real',
      () {
        const jsonMpv = '''
        [
          {"id": 1, "type": "video", "selected": true, "codec": "h264"},
          {
            "id": 1,
            "type": "audio",
            "title": "Castellano - Animel-mg.foroactivo.com",
            "lang": "spa",
            "codec": "aac",
            "demux-channels": "stereo",
            "demux-channel-count": 2,
            "default": true,
            "selected": false
          },
          {
            "id": 2,
            "type": "audio",
            "title": "Japonés",
            "lang": "jpn",
            "codec": "opus",
            "demux-channel-count": 6,
            "default": false,
            "selected": true
          },
          {
            "id": 1,
            "type": "sub",
            "title": "Español (Forzados)",
            "lang": "spa",
            "codec": "ass",
            "forced": true,
            "default": true,
            "selected": false
          },
          {
            "id": 2,
            "type": "sub",
            "title": "Español Completo",
            "lang": "spa",
            "codec": "subrip",
            "selected": true
          },
          {
            "id": 3,
            "type": "sub",
            "lang": "eng",
            "codec": "hdmv_pgs_subtitle",
            "selected": false
          }
        ]
        ''';

        final estado = EstadoPistasReproductor.construirDesdeMpv(
          jsonTrackList: jsonMpv,
          aidActual: 'auto',
          sidActual: 'auto',
        );

        expect(estado.pistasAudio.length, 2);
        expect(estado.pistasSubtitulos.length, 3);
        expect(estado.audioActivoId, '2');
        expect(estado.subtituloActivoId, '2');
        expect(estado.pistaAudioActiva?.tituloVisible, 'Japonés');
        expect(estado.pistaAudioActiva?.etiquetasMetadatos, ['OPUS', '5.1']);
        expect(estado.pistaSubtituloActiva?.tituloVisible, 'Español Completo');
        expect(estado.pistasSubtitulos[2].tituloVisible, 'Inglés');
        expect(estado.pistasSubtitulos[2].esSubtituloImagen, isTrue);
        expect(estado.pistasSubtitulos[2].codecLegible, 'PGS');
      },
    );

    test(
      'mantiene pistas reales usando fallback de media_kit cuando track-list JSON falla y descarta centinelas auto/no',
      () {
        final estado = EstadoPistasReproductor.construirDesdeMpv(
          jsonTrackList: '',
          aidActual: '2',
          sidActual: 'no',
          tracksFallback: Tracks(
            audio: [
              AudioTrack.auto(),
              AudioTrack.no(),
              const AudioTrack('1', 'Castellano', 'spa', codec: 'aac'),
              const AudioTrack('2', null, 'jpn', codec: 'ac3'),
            ],
            subtitle: [
              SubtitleTrack.auto(),
              SubtitleTrack.no(),
              const SubtitleTrack('1', 'Español', 'spa', codec: 'ass'),
            ],
          ),
        );

        expect(estado.pistasAudio.map((p) => p.id), ['1', '2']);
        expect(estado.pistasAudio[1].tituloVisible, 'Japonés');
        expect(estado.audioActivoId, '2');
        expect(estado.pistasSubtitulos.length, 1);
        expect(estado.tieneSubtituloActivo, isFalse);
        expect(estado.subtituloActivoId, 'no');
      },
    );

    test(
      'soporta fallback de pistas indexadas (track-list/count) cuando track-list JSON viene vacio',
      () {
        final estado = EstadoPistasReproductor.construirDesdeMpv(
          jsonTrackList: '',
          pistasIndexadas: const [
            {
              'type': 'audio',
              'id': '1',
              'title': 'Latino',
              'lang': 'es-419',
              'codec': 'eac3',
              'selected': 'yes',
            },
            {
              'type': 'sub',
              'id': '1',
              'title': 'Subtítulos ES',
              'lang': 'spa',
              'codec': 'ass',
              'external': 'yes',
              'external-filename': '/storage/video.es.ass',
              'selected': 'yes',
            },
          ],
        );

        expect(estado.pistasAudio.length, 1);
        expect(estado.audioActivoId, '1');
        expect(estado.pistasSubtitulos.length, 1);
        expect(estado.subtituloActivoId, '1');
        expect(estado.pistasSubtitulos.first.esExterna, isTrue);
        expect(
          estado.pistasSubtitulos.first.etiquetasMetadatos,
          contains('Externo'),
        );
      },
    );
  });

  group('ModalPistasAudioSubtitulos UI adaptativa y reactiva', () {
    EstadoPistasReproductor crearEstadoEjemplo() {
      return const EstadoPistasReproductor(
        pistasAudio: [
          PistaMedia(
            id: '1',
            tipo: TipoPistaMedia.audio,
            titulo: 'Castellano - Animel-mg.foroactivo.com',
            idioma: 'spa',
            codec: 'aac',
            cantidadCanales: 2,
            estaSeleccionada: true,
          ),
          PistaMedia(
            id: '2',
            tipo: TipoPistaMedia.audio,
            titulo: 'Japonés',
            idioma: 'jpn',
            codec: 'aac',
            cantidadCanales: 2,
          ),
        ],
        pistasSubtitulos: [
          PistaMedia(
            id: '1',
            tipo: TipoPistaMedia.subtitulo,
            titulo: 'Español (Latino)',
            idioma: 'es-419',
            codec: 'ass',
          ),
          PistaMedia(
            id: '2',
            tipo: TipoPistaMedia.subtitulo,
            titulo: 'Inglés',
            idioma: 'eng',
            codec: 'subrip',
          ),
        ],
        audioActivoId: '1',
        subtituloActivoId: 'no',
      );
    }

    testWidgets(
      'en horizontal se ancla como panel lateral derecho estrecho sin tapar el centro',
      (tester) async {
        tester.view.physicalSize = const Size(840, 390);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final notifier = ValueNotifier<EstadoPistasReproductor>(
          crearEstadoEjemplo(),
        );
        addTearDown(notifier.dispose);

        PistaMedia? audioElegido;
        PistaMedia? subElegido;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    ModalPistasAudioSubtitulos.mostrar(
                      context,
                      estadoPistasListenable: notifier,
                      alSeleccionarAudio: (p) {
                        audioElegido = p;
                        notifier.value = notifier.value.copiarCon(
                          audioActivoId: p?.id ?? 'no',
                        );
                      },
                      alSeleccionarSubtitulo: (p) {
                        subElegido = p;
                        notifier.value = notifier.value.copiarCon(
                          subtituloActivoId: p?.id ?? 'no',
                        );
                      },
                      alCargarSubtituloExterno: () {},
                      alAbrirSincronizacion: () {},
                    );
                  },
                  child: const Text('Abrir Pistas'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Pistas'));
        await tester.pumpAndSettle();

        final rect = tester.getRect(find.byType(ModalPistasAudioSubtitulos));
        expect(rect.right, closeTo(840.0, 0.5));
        expect(rect.width, lessThanOrEqualTo(308.5));
        expect(rect.left, greaterThan(500.0));

        // No debe mostrar centinelas feos de libmpv
        expect(find.textContaining('#auto'), findsNothing);
        expect(find.textContaining('#no'), findsNothing);
        expect(find.text('Castellano - Animel-mg.foroactivo.com'), findsOneWidget);
        expect(find.text('Japonés'), findsOneWidget);

        // Cambiar audio sin cerrar el panel para poder ajustar subtítulos en el mismo flujo
        await tester.tap(find.text('Japonés'));
        await tester.pumpAndSettle();
        expect(audioElegido?.id, '2');
        expect(find.byType(ModalPistasAudioSubtitulos), findsOneWidget);

        // Cambiar a pestaña Subtítulos y activar una pista
        await tester.tap(find.text('Subtítulos'));
        await tester.pumpAndSettle();
        expect(find.text('Desactivados'), findsOneWidget);
        expect(find.text('Español (Latino)'), findsOneWidget);

        await tester.tap(find.text('Español (Latino)'));
        await tester.pumpAndSettle();
        expect(subElegido?.id, '1');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'en vertical se abre como hoja compacta inferior y actualiza pistas en vivo',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final notifier = ValueNotifier<EstadoPistasReproductor>(
          const EstadoPistasReproductor(cargando: true),
        );
        addTearDown(notifier.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    ModalPistasAudioSubtitulos.mostrar(
                      context,
                      estadoPistasListenable: notifier,
                      alSeleccionarAudio: (_) {},
                      alSeleccionarSubtitulo: (_) {},
                      alCargarSubtituloExterno: () {},
                      alAbrirSincronizacion: () {},
                    );
                  },
                  child: const Text('Abrir Vertical'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Vertical'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final rect = tester.getRect(find.byType(ModalPistasAudioSubtitulos));
        expect(rect.bottom, closeTo(844.0, 0.5));
        expect(rect.top, greaterThan(350.0));
        expect(find.text('Detectando pistas de audio...'), findsOneWidget);

        // Simular llegada tardía de pistas desde libmpv mientras el panel está abierto
        notifier.value = crearEstadoEjemplo();
        await tester.pumpAndSettle();

        expect(find.text('Japonés'), findsOneWidget);
        expect(find.text('Castellano - Animel-mg.foroactivo.com'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
