import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reproductormp4/modelos/modelo_video.dart';
import 'package:reproductormp4/widgets/reproductor/hoja_playlist_reproductor.dart';

void main() {
  final fecha = DateTime(2026, 1, 1);
  final videos = [
    ModeloVideo(
      id: '1',
      ruta: '/tmp/ep1.mp4',
      nombre: 'BlueBox Cap 01.mp4',
      nombreSinExtension: 'BlueBox Cap 01',
      tamanoBytes: 180 * 1024 * 1024,
      fechaModificacion: fecha,
      carpetaContenedora: 'BlueBox',
      extension: 'mp4',
      duracionTotalMs: 24 * 60 * 1000,
      posicionGuardadaMs: 12 * 60 * 1000,
    ),
    ModeloVideo(
      id: '2',
      ruta: '/tmp/ep2.mp4',
      nombre: 'BlueBox Cap 02.mp4',
      nombreSinExtension: 'BlueBox Cap 02',
      tamanoBytes: 200 * 1024 * 1024,
      fechaModificacion: fecha,
      carpetaContenedora: 'BlueBox',
      extension: 'mp4',
      duracionTotalMs: 24 * 60 * 1000,
      posicionGuardadaMs: 6 * 60 * 1000,
    ),
    ModeloVideo(
      id: '3',
      ruta: '/tmp/ep3.mp4',
      nombre: 'BlueBox Cap 03.mp4',
      nombreSinExtension: 'BlueBox Cap 03',
      tamanoBytes: 190 * 1024 * 1024,
      fechaModificacion: fecha,
      carpetaContenedora: 'BlueBox',
      extension: 'mp4',
      duracionTotalMs: 24 * 60 * 1000,
      estaCompletado: true,
    ),
  ];

  testWidgets(
    'se abre anclado al lateral izquierdo con animación y muestra progreso completo en horizontal',
    (tester) async {
      tester.view.physicalSize = const Size(860, 420);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => HojaPlaylistReproductor.mostrar(
                  context,
                  listaVideos: videos,
                  indiceActual: 0,
                  alSeleccionarVideo: (_, _) {},
                ),
                child: const Text('Abrir playlist'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir playlist'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      // Durante la entrada animada el panel se desliza desde la izquierda
      final rectEnEntrada = tester.getRect(
        find.byType(HojaPlaylistReproductor),
      );
      expect(rectEnEntrada.left, lessThan(0.0));

      await tester.pumpAndSettle();

      // Anclado al borde izquierdo, altura completa y ancho compacto (<= 380px)
      final rectPanel = tester.getRect(find.byType(HojaPlaylistReproductor));
      expect(rectPanel.left, closeTo(0.0, 0.5));
      expect(rectPanel.height, closeTo(420.0, 0.5));
      expect(rectPanel.width, lessThanOrEqualTo(380.0));

      // Muestra duraciones, barras de progreso, porcentajes y badges
      expect(find.text('24:00'), findsWidgets);
      expect(find.text('Reproduciendo · 12:00 / 24:00'), findsOneWidget);
      expect(find.text('06:00 / 24:00 (25%)'), findsOneWidget);
      expect(find.text('Completado · 24:00'), findsOneWidget);
      expect(find.text('MP4'), findsNWidgets(3));
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));

      // Al cerrar, sale deslizándose hacia la izquierda sin errores
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final rectEnSalida = tester.getRect(find.byType(HojaPlaylistReproductor));
      expect(rectEnSalida.left, lessThan(0.0));

      await tester.pumpAndSettle();
      expect(find.byType(HojaPlaylistReproductor), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('se adapta sin overflow en orientación vertical', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => HojaPlaylistReproductor.mostrar(
                context,
                listaVideos: videos,
                indiceActual: 0,
                alSeleccionarVideo: (_, _) {},
              ),
              child: const Text('Abrir playlist'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir playlist'));
    await tester.pumpAndSettle();

    final rectPanel = tester.getRect(find.byType(HojaPlaylistReproductor));
    expect(rectPanel.left, closeTo(0.0, 0.5));
    expect(rectPanel.width, lessThan(360.0));
    expect(tester.takeException(), isNull);
  });
}
