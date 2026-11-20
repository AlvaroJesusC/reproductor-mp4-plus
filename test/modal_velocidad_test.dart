import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reproductormp4/widgets/reproductor/modal_velocidad.dart';

void main() {
  final List<MethodCall> llamadasHapticas = [];

  setUp(() {
    llamadasHapticas.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            llamadasHapticas.add(call);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets(
    'se abre anclado en el lateral derecho sin tapar el centro en horizontal',
    (tester) async {
      tester.view.physicalSize = const Size(800, 360);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      double velocidadSeleccionada = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  ModalVelocidad.mostrar(
                    context,
                    velocidadActual: velocidadSeleccionada,
                    alSeleccionarVelocidad: (v) => velocidadSeleccionada = v,
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      final rectPanel = tester.getRect(find.byType(ModalVelocidad));
      expect(rectPanel.right, closeTo(800.0, 0.5));
      expect(rectPanel.left, greaterThan(450.0));
      expect(find.text('Velocidad'), findsOneWidget);
      expect(find.text('En 1.0x'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'al girar la rueda cambia la velocidad y dispara vibracion haptica breve',
    (tester) async {
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final List<double> velocidadesEmitidas = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.centerRight,
              child: ModalVelocidad(
                velocidadActual: 1.0,
                alSeleccionarVelocidad: velocidadesEmitidas.add,
              ),
            ),
          ),
        ),
      );

      final rueda = find.byType(ListWheelScrollView);
      expect(rueda, findsOneWidget);

      await tester.drag(rueda, const Offset(0, -92));
      await tester.pumpAndSettle();

      expect(velocidadesEmitidas, isNotEmpty);
      expect(velocidadesEmitidas.last, greaterThan(1.0));
      expect(llamadasHapticas, isNotEmpty);
      expect(
        llamadasHapticas.every(
          (c) => c.arguments == 'HapticFeedbackType.selectionClick',
        ),
        isTrue,
      );
      expect(find.text('Normal 1.0x'), findsOneWidget);
    },
  );

  testWidgets(
    'el boton Normal 1.0x restablece con una sola vibracion sin overflow en vertical',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      double velocidad = 1.75;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.centerRight,
              child: ModalVelocidad(
                velocidadActual: velocidad,
                alSeleccionarVelocidad: (v) => velocidad = v,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Normal 1.0x'), findsOneWidget);

      await tester.tap(find.text('Normal 1.0x'));
      await tester.pumpAndSettle();

      expect(velocidad, 1.0);
      expect(llamadasHapticas.length, 1);
      expect(
        llamadasHapticas.first.arguments,
        'HapticFeedbackType.lightImpact',
      );
      expect(find.text('En 1.0x'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'la rueda hace bucle infinito al superar 3.0x y al retroceder desde 0.25x',
    (tester) async {
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final List<double> velocidadesEmitidas = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.centerRight,
              child: ModalVelocidad(
                velocidadActual: 3.0,
                alSeleccionarVelocidad: velocidadesEmitidas.add,
              ),
            ),
          ),
        ),
      );

      final rueda = find.byType(ListWheelScrollView);

      // Avanzar más allá de 3.0x debe volver a 0.25x (bucle hacia adelante)
      await tester.drag(rueda, const Offset(0, -46));
      await tester.pumpAndSettle();

      expect(velocidadesEmitidas, isNotEmpty);
      expect(velocidadesEmitidas.last, 0.25);

      // Retroceder desde 0.25x debe volver a 3.0x (bucle hacia atrás)
      await tester.drag(rueda, const Offset(0, 46));
      await tester.pumpAndSettle();

      expect(velocidadesEmitidas.last, 3.0);
      expect(tester.takeException(), isNull);
    },
  );
}
