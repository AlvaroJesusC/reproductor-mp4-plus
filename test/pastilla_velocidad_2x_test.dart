import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reproductormp4/pantallas/pantalla_reproductor.dart';

void main() {
  testWidgets('PastillaVelocidad2x se monta directamente en Stack sin errores de ParentData y conmuta visibilidad', (tester) async {
    final velocidad2xNotifier = ValueNotifier<bool>(false);
    final velocidadDestinoNotifier = ValueNotifier<double>(2.0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              PastillaVelocidad2x(
                velocidad2xNotifier: velocidad2xNotifier,
                velocidadDestinoNotifier: velocidadDestinoNotifier,
              ),
            ],
          ),
        ),
      ),
    );

    // Inicialmente la pastilla tiene opacidad 0.0 (oculta)
    final animatedOpacityFinder = find.byType(AnimatedOpacity);
    expect(animatedOpacityFinder, findsOneWidget);
    AnimatedOpacity opacityWidget = tester.widget(animatedOpacityFinder);
    expect(opacityWidget.opacity, 0.0);

    // Activamos la velocidad rápida 2x
    velocidad2xNotifier.value = true;
    await tester.pumpAndSettle();

    opacityWidget = tester.widget(animatedOpacityFinder);
    expect(opacityWidget.opacity, 1.0);
    expect(find.text('2x'), findsOneWidget);
    expect(find.byIcon(Icons.fast_forward_rounded), findsOneWidget);

    // Probamos cambiar a 3x
    velocidadDestinoNotifier.value = 3.0;
    await tester.pumpAndSettle();
    expect(find.text('3x'), findsOneWidget);

    // Desactivamos la velocidad rápida (al soltar el dedo)
    velocidad2xNotifier.value = false;
    await tester.pumpAndSettle();

    opacityWidget = tester.widget(animatedOpacityFinder);
    expect(opacityWidget.opacity, 0.0);

    velocidad2xNotifier.dispose();
    velocidadDestinoNotifier.dispose();
  });
}
