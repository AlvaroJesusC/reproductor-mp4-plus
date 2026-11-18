import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reproductormp4/modelos/modelo_capitulo_video.dart';
import 'package:reproductormp4/widgets/reproductor/boton_saltar_capitulo.dart';
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

    test('detectarTipoSaltar clasifica intro, outro y créditos sin falsos positivos', () {
      expect(
        CapituloVideo.detectarTipoSaltar('Chapter: Intro'),
        TipoCapituloSaltar.intro,
      );
      expect(
        CapituloVideo.detectarTipoSaltar('02. Opening'),
        TipoCapituloSaltar.intro,
      );
      expect(
        CapituloVideo.detectarTipoSaltar('OP 1'),
        TipoCapituloSaltar.intro,
      );
      expect(
        CapituloVideo.detectarTipoSaltar('Outro'),
        TipoCapituloSaltar.outro,
      );
      expect(
        CapituloVideo.detectarTipoSaltar('Ending'),
        TipoCapituloSaltar.outro,
      );
      expect(
        CapituloVideo.detectarTipoSaltar('ED1'),
        TipoCapituloSaltar.outro,
      );
      expect(
        CapituloVideo.detectarTipoSaltar('Chapter: Credits'),
        TipoCapituloSaltar.creditos,
      );
      expect(
        CapituloVideo.detectarTipoSaltar('Créditos finales'),
        TipoCapituloSaltar.creditos,
      );

      expect(CapituloVideo.detectarTipoSaltar('Episode'), isNull);
      expect(CapituloVideo.detectarTipoSaltar('Prologue'), isNull);
      expect(CapituloVideo.detectarTipoSaltar('Stop'), isNull);
      expect(CapituloVideo.detectarTipoSaltar('Red'), isNull);
    });

    test('capituloSaltarEnPosicion activa solo dentro de intro/outro/créditos', () {
      const capitulos = [
        CapituloVideo(indice: 0, titulo: 'Episode', inicioMs: 0),
        CapituloVideo(indice: 1, titulo: 'Intro', inicioMs: 66000),
        CapituloVideo(indice: 2, titulo: 'Episode', inicioMs: 197000),
        CapituloVideo(indice: 3, titulo: 'Credits', inicioMs: 1298000),
      ];

      expect(
        CapituloVideo.capituloSaltarEnPosicion(
          capitulos: capitulos,
          posicionMs: 10000,
          duracionTotalMs: 1400000,
          haySiguienteVideo: true,
        ),
        isNull,
      );

      final enIntro = CapituloVideo.capituloSaltarEnPosicion(
        capitulos: capitulos,
        posicionMs: 70000,
        duracionTotalMs: 1400000,
        haySiguienteVideo: true,
      );
      expect(enIntro, isNotNull);
      expect(enIntro!.tipo, TipoCapituloSaltar.intro);
      expect(enIntro.destinoMs, 197000);
      expect(enIntro.avanzaASiguienteVideo, isFalse);

      expect(
        CapituloVideo.capituloSaltarEnPosicion(
          capitulos: capitulos,
          posicionMs: 200000,
          duracionTotalMs: 1400000,
          haySiguienteVideo: true,
        ),
        isNull,
      );

      final enCreditosConSiguiente = CapituloVideo.capituloSaltarEnPosicion(
        capitulos: capitulos,
        posicionMs: 1300000,
        duracionTotalMs: 1400000,
        haySiguienteVideo: true,
      );
      expect(enCreditosConSiguiente, isNotNull);
      expect(enCreditosConSiguiente!.tipo, TipoCapituloSaltar.creditos);
      expect(enCreditosConSiguiente.avanzaASiguienteVideo, isTrue);

      final enCreditosSinSiguiente = CapituloVideo.capituloSaltarEnPosicion(
        capitulos: capitulos,
        posicionMs: 1300000,
        duracionTotalMs: 1400000,
        haySiguienteVideo: false,
      );
      expect(enCreditosSinSiguiente, isNotNull);
      expect(enCreditosSinSiguiente!.avanzaASiguienteVideo, isFalse);
      expect(enCreditosSinSiguiente.destinoMs, 1399000);
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

  group('BotonSaltarCapitulo', () {
    testWidgets('se oculta sin intro/outro y aparece con etiqueta correcta al activarse', (
      tester,
    ) async {
      final notifier = ValueNotifier<CapituloSaltarActivo?>(null);
      final vel2x = ValueNotifier<bool>(false);
      CapituloSaltarActivo? saltado;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                BotonSaltarCapitulo(
                  capituloSaltarNotifier: notifier,
                  velocidad2xNotifier: vel2x,
                  controlesVisibles: true,
                  alSaltar: (s) => saltado = s,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Saltar intro'), findsNothing);

      notifier.value = const CapituloSaltarActivo(
        capituloOrigen: CapituloVideo(
          indice: 1,
          titulo: 'Intro',
          inicioMs: 66000,
        ),
        tipo: TipoCapituloSaltar.intro,
        destinoMs: 197000,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Saltar intro'), findsOneWidget);

      await tester.tap(find.text('Saltar intro'));
      await tester.pump();

      expect(saltado?.destinoMs, 197000);

      notifier.value = const CapituloSaltarActivo(
        capituloOrigen: CapituloVideo(
          indice: 3,
          titulo: 'Credits',
          inicioMs: 1298000,
        ),
        tipo: TipoCapituloSaltar.creditos,
        avanzaASiguienteVideo: true,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Saltar créditos'), findsOneWidget);

      notifier.dispose();
      vel2x.dispose();
    });
  });
}
