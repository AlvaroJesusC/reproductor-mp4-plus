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

  testWidgets('renderiza duración, progreso, ancho compacto y expande al deslizar', (
    tester,
  ) async {
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
    await tester.pumpAndSettle();

    // Ancho más compacto en horizontal (<= 440px)
    final sheetInicial = tester.getSize(find.byType(HojaPlaylistReproductor));
    expect(sheetInicial.width, lessThanOrEqualTo(440.0));

    // Muestra duraciones, barra de progreso y estado en la vista inicial
    expect(find.text('24:00'), findsWidgets);
    expect(find.text('Reproduciendo · 12:00 / 24:00'), findsOneWidget);
    expect(find.text('06:00 / 24:00'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));

    // Deslizar hacia arriba desde el encabezado expande el modal y muestra más detalle
    await tester.drag(
      find.text('Lista de Videos (3)'),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();

    final sheetExpandido = tester.getSize(find.byType(HojaPlaylistReproductor));
    expect(sheetExpandido.height, greaterThan(sheetInicial.height));

    expect(find.text('Completado · 24:00'), findsOneWidget);
    expect(find.text('MP4'), findsNWidgets(3));
    expect(find.text('06:00 / 24:00 (25%)'), findsOneWidget);
  });
}
