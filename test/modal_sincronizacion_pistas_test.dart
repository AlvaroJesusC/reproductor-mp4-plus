import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reproductormp4/widgets/reproductor/modal_sincronizacion_pistas.dart';

void main() {
  testWidgets('ModalSincronizacionPistas ajusta desfases y se renderiza compacto', (tester) async {
    double desfaseSub = 0.0;
    double desfaseAudio = 0.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => ModalSincronizacionPistas(
                      desfaseSubtitulosSegundos: desfaseSub,
                      desfaseAudioSegundos: desfaseAudio,
                      alCambiarDesfaseSubtitulos: (val) => desfaseSub = val,
                      alCambiarDesfaseAudio: (val) => desfaseAudio = val,
                    ),
                  );
                },
                child: const Text('Abrir'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    // Comprobar que los títulos de pistas y badges iniciales se muestran
    expect(find.text('Sincronización de Pistas'), findsOneWidget);
    expect(find.text('Subtítulos'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('0.0s'), findsNWidgets(2));

    // Ajustar subtítulos con el primer botón '+0.1s'
    final botonesMas01 = find.text('+0.1s');
    expect(botonesMas01, findsNWidgets(2));
    await tester.tap(botonesMas01.first);
    await tester.pumpAndSettle();

    expect(desfaseSub, 0.1);
    expect(find.text('+0.1s'), findsNWidgets(3)); // 2 en botones + 1 en pastilla

    // Ajustar audio con el segundo botón '-0.5s'
    final botonesMenos05 = find.text('-0.5s');
    await tester.tap(botonesMenos05.last);
    await tester.pumpAndSettle();

    expect(desfaseAudio, -0.5);

    // Botones de restablecer
    expect(find.text('Restablecer'), findsOneWidget);

    // Cerrar el modal mediante el botón de la cabecera
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Sincronización de Pistas'), findsNothing);
  });
}
