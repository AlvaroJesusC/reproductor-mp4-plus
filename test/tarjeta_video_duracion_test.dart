import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reproductormp4/modelos/modelo_video.dart';
import 'package:reproductormp4/servicios/servicio_duracion_video.dart';
import 'package:reproductormp4/servicios/servicio_preferencias.dart';
import 'package:reproductormp4/widgets/tarjeta_video.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const canalMetadatos = MethodChannel('com.example.reproductormp4/metadatos');

  ModeloVideo crearVideo({
    String ruta = '/storage/emulated/0/Movies/Capitulo 2.mp4',
    int duracionTotalMs = 0,
    bool estaCompletado = false,
  }) {
    return ModeloVideo(
      id: ruta,
      ruta: ruta,
      nombre: 'Capitulo 2.mp4',
      nombreSinExtension: 'Capitulo 2',
      tamanoBytes: (160.5 * 1024 * 1024).round(),
      fechaModificacion: DateTime(2026, 1, 1),
      carpetaContenedora: 'Temporada 2',
      extension: 'mp4',
      duracionTotalMs: duracionTotalMs,
      estaCompletado: estaCompletado,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ServicioPreferencias.reiniciarInstanciaParaPruebas();
    ServicioDuracionVideo.reiniciarCacheParaPruebas();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canalMetadatos, (call) async {
          if (call.method == 'obtenerDuracionMs') {
            return 1441000; // 24:01
          }
          return 0;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canalMetadatos, null);
  });

  testWidgets(
    'TarjetaVideo no muestra el tamaño del archivo y extrae la duración automáticamente',
    (tester) async {
      final video = crearVideo(duracionTotalMs: 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TarjetaVideo(video: video, alPresionar: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('MB'), findsNothing);
      expect(find.text('24:01'), findsWidgets);
      expect(video.duracionTotalMs, 1441000);
    },
  );

  testWidgets(
    'TarjetaVideoCuadricula muestra duración en lugar de tamaño y duración al completar',
    (tester) async {
      final video = crearVideo(duracionTotalMs: 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: 220,
              child: TarjetaVideoCuadricula(video: video, alPresionar: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('MB'), findsNothing);
      expect(find.text('24:01'), findsWidgets);
    },
  );

  testWidgets(
    'Marcar como visto manualmente extrae y conserva la duración junto a Completado',
    (tester) async {
      // Simular que el método nativo primero tarda y el video empieza con duracionTotalMs = 0
      final video = crearVideo(duracionTotalMs: 0);
      var actualizaciones = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return TarjetaVideo(
                  video: video,
                  alPresionar: () {},
                  alActualizar: () {
                    actualizaciones++;
                    setState(() {});
                  },
                );
              },
            ),
          ),
        ),
      );

      // Abrir menú contextual y presionar "Marcar como visto"
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marcar como visto'));
      await tester.pumpAndSettle();

      expect(actualizaciones, 1);
      expect(video.estaCompletado, isTrue);
      expect(video.duracionTotalMs, 1441000);
      expect(find.text('Completado  •  24:01'), findsOneWidget);
      expect(
        await ServicioPreferencias.obtenerDuracionGuardada(video.ruta),
        1441000,
      );
    },
  );
}
