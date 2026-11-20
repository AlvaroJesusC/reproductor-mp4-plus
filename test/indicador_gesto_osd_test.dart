import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reproductormp4/modelos/modelo_opciones_reproduccion.dart';
import 'package:reproductormp4/widgets/reproductor/indicador_gesto_osd.dart';

void main() {
  Finder buscarFadesDelOsd() => find.descendant(
    of: find.byType(IndicadorGestoOSD),
    matching: find.byType(FadeTransition),
  );

  testWidgets(
    'barra de brillo anima entrada y salida preservando su ultimo porcentaje',
    (tester) async {
      var tipo = TipoGestoOSD.ninguno;
      var valor = 0.0;
      late StateSetter actualizar;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                actualizar = setState;
                return IndicadorGestoOSD(tipoGesto: tipo, valor: valor);
              },
            ),
          ),
        ),
      );

      // Oculto inicialmente sin capas animadas activas dentro del OSD
      expect(buscarFadesDelOsd(), findsNothing);

      // Activa brillo al 80%
      actualizar(() {
        tipo = TipoGestoOSD.brillo;
        valor = 0.8;
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));

      final fadeEnEntrada = tester.widget<FadeTransition>(buscarFadesDelOsd());
      expect(fadeEnEntrada.opacity.value, greaterThan(0.0));
      expect(fadeEnEntrada.opacity.value, lessThan(1.0));
      expect(find.text('80%'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(
        tester.widget<FadeTransition>(buscarFadesDelOsd()).opacity.value,
        1.0,
      );

      // Al ocultar, incluso si valor cambia (como ocurre al volver a ninguno),
      // mantiene 80% durante la salida y desmonta al finalizar.
      actualizar(() {
        tipo = TipoGestoOSD.ninguno;
        valor = 0.25;
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 95));

      expect(find.text('80%'), findsOneWidget);
      expect(find.text('25%'), findsNothing);
      final fadeEnSalida = tester.widget<FadeTransition>(buscarFadesDelOsd());
      expect(fadeEnSalida.opacity.value, lessThan(1.0));
      expect(fadeEnSalida.opacity.value, greaterThan(0.0));

      await tester.pumpAndSettle();
      expect(buscarFadesDelOsd(), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'barra de volumen anima entrada, permite cambio fluido a brillo y se oculta',
    (tester) async {
      var tipo = TipoGestoOSD.volumen;
      var valor = 0.65;
      late StateSetter actualizar;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                actualizar = setState;
                return IndicadorGestoOSD(tipoGesto: tipo, valor: valor);
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('65%'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

      // Cambio directo de volumen a brillo: ambas barras cruzan entrada/salida
      actualizar(() {
        tipo = TipoGestoOSD.brillo;
        valor = 0.4;
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));

      expect(buscarFadesDelOsd(), findsNWidgets(2));
      expect(find.text('65%'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(buscarFadesDelOsd(), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('65%'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
