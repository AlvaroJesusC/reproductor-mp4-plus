import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reproductormp4/modelos/modelo_capitulo_video.dart';
import 'package:reproductormp4/widgets/reproductor/modal_capitulos.dart';

void main() {
  group('CapituloVideo', () {
    test('parsea JSON de libmpv ordenado por tiempo y asigna título por defecto', () {
      const jsonMpv = '''
        [
          {"title": "Intro", "time": 120.0},
          {"title": "", "time": 0.0},
          {"title": "Episode", "time": 195.5},
          {"title": "Credits", "time": 1298.0}
        ]
      ''';

      final capitulos = CapituloVideo.parsearDesdeJsonMpv(jsonMpv);

      expect(capitulos, hasLength(4));
      expect(capitulos[0].indice, 0);
      expect(capitulos[0].titulo, 'Capítulo 1');
      expect(capitulos[0].inicioMs, 0);
      expect(capitulos[1].titulo, 'Intro');
      expect(capitulos[1].inicioMs, 120000);
      expect(capitulos[2].titulo, 'Episode');
      expect(capitulos[2].inicioMs, 195500);
      expect(capitulos[3].titulo, 'Credits');
      expect(capitulos[3].tiempoLegible, '21:38');
    });

    test('devuelve lista vacía ante entrada vacía o inválida', () {
      expect(CapituloVideo.parsearDesdeJsonMpv(''), isEmpty);
      expect(CapituloVideo.parsearDesdeJsonMpv('[]'), isEmpty);
      expect(CapituloVideo.parsearDesdeJsonMpv('{invalido'), isEmpty);
    });

    test('indiceEnPosicion resuelve capítulo activo con tolerancia de keyframe', () {
      const capitulos = [
        CapituloVideo(indice: 0, titulo: 'Episode', inicioMs: 0),
        CapituloVideo(indice: 1, titulo: 'Intro', inicioMs: 120000),
        CapituloVideo(indice: 2, titulo: 'Credits', inicioMs: 1298000),
      ];

      expect(CapituloVideo.indiceEnPosicion(capitulos, 0), 0);
      expect(CapituloVideo.indiceEnPosicion(capitulos, 119850), 1);
      expect(CapituloVideo.indiceEnPosicion(capitulos, 300000), 1);
      expect(CapituloVideo.indiceEnPosicion(capitulos, 1300000), 2);
      expect(CapituloVideo.indiceEnPosicion(const [], 10000), -1);
    });
  });

  group('ModalCapitulos', () {
    const capitulos = [
      CapituloVideo(indice: 0, titulo: 'Episode', inicioMs: 0),
      CapituloVideo(indice: 1, titulo: 'Intro', inicioMs: 120000),
      CapituloVideo(indice: 2, titulo: 'Credits', inicioMs: 1298000),
    ];

    testWidgets('muestra capítulos y permite saltar a uno o al siguiente', (
      tester,
    ) async {
      CapituloVideo? seleccionado;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ModalCapitulos.mostrar(
                  context,
                  capitulos: capitulos,
                  indiceActual: 0,
                  alSeleccionarCapitulo: (c) => seleccionado = c,
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Ir al capítulo...'), findsOneWidget);
      expect(find.text('Intro'), findsOneWidget);
      expect(find.text('02:00'), findsOneWidget);

      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      expect(seleccionado, capitulos[1]);
    });

    testWidgets('muestra estado vacío cuando no hay capítulos', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModalCapitulos(
              capitulos: const [],
              indiceActual: -1,
              alSeleccionarCapitulo: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Sin capítulos disponibles'), findsOneWidget);
    });
  });
}
