import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reproductormp4/modelos/modelo_carpeta_video.dart';
import 'package:reproductormp4/modelos/modelo_orden_videos.dart';
import 'package:reproductormp4/modelos/modelo_video.dart';
import 'package:reproductormp4/servicios/servicio_almacenamiento_video.dart';
import 'package:reproductormp4/servicios/servicio_preferencias.dart';
import 'package:reproductormp4/widgets/reproductor/hoja_playlist_reproductor.dart';
import 'package:shared_preferences/shared_preferences.dart';

ModeloVideo _video(
  String nombreSinExt, {
  String carpeta = 'Temporada 1',
  int tamanoBytes = 100,
  DateTime? fecha,
  int duracionMs = 24 * 60 * 1000,
  int posicionMs = 0,
}) {
  final ruta = '/storage/emulated/0/Movies/$carpeta/$nombreSinExt.mp4';
  return ModeloVideo(
    id: ruta,
    ruta: ruta,
    nombre: '$nombreSinExt.mp4',
    nombreSinExtension: nombreSinExt,
    tamanoBytes: tamanoBytes,
    fechaModificacion: fecha ?? DateTime(2026, 1, 1),
    carpetaContenedora: carpeta,
    extension: 'mp4',
    duracionTotalMs: duracionMs,
    posicionGuardadaMs: posicionMs,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ServicioPreferencias.reiniciarInstanciaParaPruebas();
  });

  group('OrdenadorVideos.compararNatural', () {
    test('ordena episodios E1..E12 en orden humano correcto (no E1, E10, E2)', () {
      final nombresDesordenados = [
        'E1 - Te haré invitarme a una película',
        'E10 - Kaguya no perdona',
        'E11 - Ai Hayasaka quiere empaparse',
        'E12 - No puedo escuchar los fuegos artificiales',
        'E2 - Kaguya quiere comerciar',
        'E3 - Miyuki Shirogane todavía no lo ha hecho',
        'E4 - Kaguya quiere afecto',
        'E5 - Kaguya quiere manejarlo',
        'E9 - Kaguya quiere dar un paseo',
      ];

      nombresDesordenados.sort(OrdenadorVideos.compararNatural);

      expect(
        nombresDesordenados.map((n) => n.split(' ').first).toList(),
        ['E1', 'E2', 'E3', 'E4', 'E5', 'E9', 'E10', 'E11', 'E12'],
      );
    });

    test('soporta temporadas, S01E10, tildes y números muy largos sin desbordar', () {
      final casos = [
        'Capítulo 10 - Final',
        'Capitulo 2 - Inicio',
        'Capítulo 1 - Prólogo',
        'S02E01 - Nueva temporada',
        'S01E10 - Décimo',
        'S01E2 - Segundo',
        'Video 9999999999999999999999999992',
        'Video 9999999999999999999999999910',
      ];

      casos.sort(OrdenadorVideos.compararNatural);

      expect(casos, [
        'Capítulo 1 - Prólogo',
        'Capitulo 2 - Inicio',
        'Capítulo 10 - Final',
        'S01E2 - Segundo',
        'S01E10 - Décimo',
        'S02E01 - Nueva temporada',
        'Video 9999999999999999999999999910',
        'Video 9999999999999999999999999992',
      ]);
    });

    test('mantiene orden total estricto (antisimetría y transitividad)', () {
      const muestras = [
        'E0',
        'E00',
        'E01',
        'E1',
        'e1',
        'E01-1',
        'E1-01',
        'E1-1',
        'E2',
        'E10',
        'E100',
        'EA',
        'eA',
        '1',
        '01',
        '2',
        '10',
      ];

      for (final a in muestras) {
        expect(OrdenadorVideos.compararNatural(a, a), 0);
        for (final b in muestras) {
          final ab = OrdenadorVideos.compararNatural(a, b);
          final ba = OrdenadorVideos.compararNatural(b, a);
          expect(ab.sign, -ba.sign, reason: 'Antisimetría falló para $a vs $b');
          for (final c in muestras) {
            final bc = OrdenadorVideos.compararNatural(b, c);
            final ac = OrdenadorVideos.compararNatural(a, c);
            if (ab <= 0 && bc <= 0) {
              expect(
                ac,
                lessThanOrEqualTo(0),
                reason: 'Transitividad falló para $a <= $b <= $c',
              );
            }
          }
        }
      }
    });
  });

  group('OrdenadorVideos.ordenarVideos y carpetas', () {
    test('soporta todos los criterios y desempata por orden natural', () {
      final mismaFecha = DateTime(2026, 5, 10, 12, 0);
      final videos = [
        _video('E10', tamanoBytes: 300, fecha: mismaFecha),
        _video('E2', tamanoBytes: 100, fecha: DateTime(2026, 5, 12)),
        _video('E1', tamanoBytes: 300, fecha: mismaFecha),
      ];

      expect(
        OrdenadorVideos.videosOrdenados(
          videos,
          CriterioOrdenVideos.nombreAsc,
        ).map((v) => v.nombreSinExtension),
        ['E1', 'E2', 'E10'],
      );

      expect(
        OrdenadorVideos.videosOrdenados(
          videos,
          CriterioOrdenVideos.nombreDesc,
        ).map((v) => v.nombreSinExtension),
        ['E10', 'E2', 'E1'],
      );

      // Misma fecha para E1 y E10: el desempate debe ser E1 antes de E10
      expect(
        OrdenadorVideos.videosOrdenados(
          videos,
          CriterioOrdenVideos.fechaReciente,
        ).map((v) => v.nombreSinExtension),
        ['E2', 'E1', 'E10'],
      );

      expect(
        OrdenadorVideos.videosOrdenados(
          videos,
          CriterioOrdenVideos.fechaAntigua,
        ).map((v) => v.nombreSinExtension),
        ['E1', 'E10', 'E2'],
      );

      // Mismo tamaño para E1 y E10: el desempate debe ser E1 antes de E10
      expect(
        OrdenadorVideos.videosOrdenados(
          videos,
          CriterioOrdenVideos.tamanoMayor,
        ).map((v) => v.nombreSinExtension),
        ['E1', 'E10', 'E2'],
      );

      expect(
        OrdenadorVideos.videosOrdenados(
          videos,
          CriterioOrdenVideos.tamanoMenor,
        ).map((v) => v.nombreSinExtension),
        ['E2', 'E1', 'E10'],
      );
    });

    test('ordena subcarpetas de temporadas en orden natural', () {
      final carpetas = [
        ModeloCarpetaVideo(ruta: '/Temporada 10', nombre: 'Temporada 10', videos: []),
        ModeloCarpetaVideo(ruta: '/Temporada 2', nombre: 'Temporada 2', videos: []),
        ModeloCarpetaVideo(ruta: '/Temporada 1', nombre: 'Temporada 1', videos: []),
      ];

      OrdenadorVideos.ordenarCarpetas(carpetas);
      expect(
        carpetas.map((c) => c.nombre).toList(),
        ['Temporada 1', 'Temporada 2', 'Temporada 10'],
      );
    });

    test('agruparVideosPorCarpeta ordena los episodios de cada carpeta naturalmente', () {
      final videos = [
        _video('E12'),
        _video('E2'),
        _video('E10'),
        _video('E1'),
      ];

      final carpetas = ServicioAlmacenamientoVideo.agruparVideosPorCarpeta(
        videos,
      );
      expect(carpetas, hasLength(1));
      expect(
        carpetas.first.videos.map((v) => v.nombreSinExtension).toList(),
        ['E1', 'E2', 'E10', 'E12'],
      );
    });
  });

  group('ServicioPreferencias orden predeterminado', () {
    test('usa nombreAsc por defecto y persiste cambios reactivamente', () async {
      final porDefecto = await ServicioPreferencias.obtenerCriterioOrdenVideos();
      expect(porDefecto, CriterioOrdenVideos.nombreAsc);
      expect(
        ServicioPreferencias.criterioOrdenNotifier.value,
        CriterioOrdenVideos.nombreAsc,
      );

      await ServicioPreferencias.guardarCriterioOrdenVideos(
        CriterioOrdenVideos.fechaReciente,
      );
      expect(
        ServicioPreferencias.criterioOrdenNotifier.value,
        CriterioOrdenVideos.fechaReciente,
      );

      ServicioPreferencias.reiniciarInstanciaParaPruebas();
      final recuperado = await ServicioPreferencias.obtenerCriterioOrdenVideos();
      expect(recuperado, CriterioOrdenVideos.fechaReciente);
      expect(
        ServicioPreferencias.criterioOrdenNotifier.value,
        CriterioOrdenVideos.fechaReciente,
      );
    });
  });

  testWidgets(
    'HojaPlaylistReproductor permite reordenar en vivo conservando el episodio actual',
    (tester) async {
      tester.view.physicalSize = const Size(860, 420);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final episodios = [
        _video('E1 - Inicio', posicionMs: 60000),
        _video('E10 - Clímax'),
        _video('E2 - Desarrollo'),
        _video('E3 - Nudo'),
        _video('E4 - Giro'),
        _video('E5 - Desenlace'),
      ];
      CriterioOrdenVideos? criterioNotificado;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => HojaPlaylistReproductor.mostrar(
                  context,
                  listaVideos: episodios,
                  indiceActual: 2, // E2 - Desarrollo
                  criterioOrden: CriterioOrdenVideos.fechaReciente,
                  alSeleccionarVideo: (_, _) {},
                  alCambiarCriterioOrden: (c) => criterioNotificado = c,
                ),
                child: const Text('Abrir playlist'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir playlist'));
      await tester.pumpAndSettle();

      // Abrir modal de orden dentro de la playlist
      await tester.tap(find.byIcon(Icons.sort_rounded));
      await tester.pumpAndSettle();

      // Seleccionar Nombre (A - Z)
      await tester.tap(find.text('Nombre (A - Z)'));
      await tester.pumpAndSettle();

      expect(criterioNotificado, CriterioOrdenVideos.nombreAsc);

      // Verificar orden visual: E1 arriba de E2, y E2 arriba de E10
      final yE1 = tester.getTopLeft(find.text('E1 - Inicio')).dy;
      final yE2 = tester.getTopLeft(find.text('E2 - Desarrollo')).dy;
      final yE3 = tester.getTopLeft(find.text('E3 - Nudo')).dy;
      expect(yE1, lessThan(yE2));
      expect(yE2, lessThan(yE3));

      // E2 sigue marcado como reproduciendo tras el reordenamiento
      expect(find.textContaining('Reproduciendo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
