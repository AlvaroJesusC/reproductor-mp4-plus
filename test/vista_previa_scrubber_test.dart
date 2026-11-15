import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reproductormp4/widgets/reproductor/vista_previa_scrubber.dart';

void main() {
  group('ControladorVistaPreviaScrubber', () {
    test('muestra vista previa al iniciar, sigue 1:1 y oculta al finalizar', () {
      final controlador = ControladorVistaPreviaScrubber();
      addTearDown(controlador.dispose);

      const duracionMs = 600000; // 10 minutos
      controlador.alIniciarArrastre(0.25, duracionMs);

      expect(controlador.estado.value.visible, isTrue);
      expect(controlador.estado.value.ratio, closeTo(0.25, 1e-6));
      expect(controlador.estado.value.posicionMs, 150000);
      expect(controlador.estado.value.enBusquedaFina, isFalse);

      final nuevoRatio = controlador.alCambiarProgreso(0.5, duracionMs);
      expect(nuevoRatio, closeTo(0.5, 1e-6));
      expect(controlador.estado.value.posicionMs, 300000);

      final destinoMs = controlador.alFinalizarArrastre(
        ratioFallback: 0.0,
        duracionMs: duracionMs,
      );
      expect(destinoMs, 300000);
      expect(controlador.estado.value.visible, isFalse);
      expect(controlador.estado.value.enBusquedaFina, isFalse);
    });

    test('activa búsqueda precisa al deslizar arriba y reduce sensibilidad', () {
      final controlador = ControladorVistaPreviaScrubber();
      addTearDown(controlador.dispose);

      const duracionMs = 600000; // 10 minutos
      controlador.registrarInicioPunteroY(500.0);
      controlador.alIniciarArrastre(0.50, duracionMs);

      // Subir 45 px (>= umbral 38 px) activa modo fino
      controlador.alMoverPuntero(455.0);
      expect(controlador.estado.value.enBusquedaFina, isTrue);

      // Un delta crudo de +0.20 en el slider se atenúa en búsqueda precisa
      final ratioFino = controlador.alCambiarProgreso(0.70, duracionMs);
      expect(ratioFino, greaterThan(0.50));
      expect(ratioFino, lessThan(0.60));

      // Bajar de vuelta a <= 20 px desactiva modo fino
      controlador.alMoverPuntero(490.0);
      expect(controlador.estado.value.enBusquedaFina, isFalse);
    });

    test('cancelarArrastreSiActivo oculta la burbuja de forma segura', () {
      final controlador = ControladorVistaPreviaScrubber();
      addTearDown(controlador.dispose);

      controlador.alIniciarArrastre(0.3, 120000);
      expect(controlador.estado.value.visible, isTrue);

      controlador.cancelarArrastreSiActivo();
      expect(controlador.estado.value.visible, isFalse);
    });
  });

  group('BurbujaVistaPreviaScrubber', () {
    testWidgets('renderiza tarjeta, tiempo y etiqueta de precisión sin overflow', (
      tester,
    ) async {
      final controlador = ControladorVistaPreviaScrubber();
      addTearDown(controlador.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 240,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    BurbujaVistaPreviaScrubber(
                      controlador: controlador,
                      anchoPista: 260,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Oculta inicialmente
      expect(find.text('Desliza arriba para precisión'), findsNothing);

      // Activar arrastre en 3:40 (220000 ms) de 14:24 (864000 ms)
      controlador.registrarInicioPunteroY(400.0);
      controlador.alIniciarArrastre(220000 / 864000, 864000);
      await tester.pump();

      expect(find.text('03:40'), findsOneWidget);
      expect(find.text('Desliza arriba para precisión'), findsOneWidget);

      // Activar búsqueda precisa
      controlador.alMoverPuntero(350.0);
      await tester.pump();

      expect(find.text('Búsqueda precisa'), findsOneWidget);
    });
  });
}
