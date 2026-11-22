import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reproductormp4/modelos/modelo_video.dart';
import 'package:reproductormp4/servicios/logica_reanudacion_video.dart';
import 'package:reproductormp4/servicios/servicio_almacenamiento_video.dart';
import 'package:reproductormp4/servicios/servicio_preferencias.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ServicioPreferencias.reiniciarInstanciaParaPruebas();
  });

  group('LogicaReanudacionVideo', () {
    test('prioriza la posición persistida en disco sobre un valor obsoleto en memoria', () {
      final objetivo = LogicaReanudacionVideo.calcularObjetivoReanudacionMs(
        posicionDiscoMs: 300000, // 5:00 guardado en disco
        posicionMemoriaMs: 60000, // 1:00 obsoleto en tarjeta
        completadoEnDisco: false,
        duracionConocidaMs: 1200000, // 20:00
      );

      expect(objetivo, 300000);
    });

    test('no reanuda si el video fue marcado completado en disco aunque la memoria tenga posición', () {
      final objetivo = LogicaReanudacionVideo.calcularObjetivoReanudacionMs(
        posicionDiscoMs: 300000,
        posicionMemoriaMs: 300000,
        completadoEnDisco: true,
        duracionConocidaMs: 1200000,
      );

      expect(objetivo, 0);
    });

    test('no marca como completado en 0ms un video corto menor a 4 segundos', () {
      expect(
        LogicaReanudacionVideo.esVideoCompletado(
          posicionMs: 0,
          duracionMs: 3500,
        ),
        isFalse,
      );
      expect(
        LogicaReanudacionVideo.esVideoCompletado(
          posicionMs: 1000,
          duracionMs: 3500,
        ),
        isFalse,
      );
      expect(
        LogicaReanudacionVideo.esVideoCompletado(
          posicionMs: 3400,
          duracionMs: 3500,
        ),
        isTrue,
      );
    });

    test('ajusta el objetivo si la duración real es ligeramente menor a lo guardado', () {
      final ajustado = LogicaReanudacionVideo.ajustarObjetivoADuracionReal(
        objetivoMs: 599000,
        duracionRealMs: 600000,
      );
      // 599s de 600s ya entra en zona de completado (>= 95%), no debe saltar al EOF
      expect(ajustado, 0);

      final valido = LogicaReanudacionVideo.ajustarObjetivoADuracionReal(
        objetivoMs: 300000,
        duracionRealMs: 600000,
      );
      expect(valido, 300000);
    });

    test('confirma reanudación con tolerancia de keyframe y rechaza posición en 0', () {
      expect(
        LogicaReanudacionVideo.estaReanudacionConfirmada(
          posicionActualMs: 0,
          objetivoMs: 300000,
        ),
        isFalse,
      );
      expect(
        LogicaReanudacionVideo.estaReanudacionConfirmada(
          posicionActualMs: 2500,
          objetivoMs: 300000,
        ),
        isFalse,
      );
      // Keyframe 3 segundos antes del minuto 5
      expect(
        LogicaReanudacionVideo.estaReanudacionConfirmada(
          posicionActualMs: 297000,
          objetivoMs: 300000,
        ),
        isTrue,
      );
    });

    test('resolverPosicionParaGuardar conserva la última posición válida si el motor reporta 0', () {
      expect(
        LogicaReanudacionVideo.resolverPosicionParaGuardar(
          posicionMotorMs: 0,
          ultimaPosicionValidaMs: 305000,
        ),
        305000,
      );
      expect(
        LogicaReanudacionVideo.resolverPosicionParaGuardar(
          posicionMotorMs: 310000,
          ultimaPosicionValidaMs: 305000,
        ),
        310000,
      );
      expect(
        LogicaReanudacionVideo.resolverPosicionParaGuardar(
          posicionMotorMs: 12000,
          ultimaPosicionValidaMs: 305000,
          posicionForzadaMs: 420000,
        ),
        420000,
      );
    });
  });

  group('ServicioPreferencias - Persistencia y Continuar viendo', () {
    test('guardarProgresoVideo con duracionTotalMs=0 no borra la duración previa conocida', () async {
      const ruta = '/storage/emulated/0/Movies/peli.mp4';
      await ServicioPreferencias.guardarProgresoVideo(
        rutaVideo: ruta,
        posicionMs: 120000,
        duracionTotalMs: 1800000,
      );

      // Guardado posterior cuando el motor momentáneamente devuelve duración 0
      await ServicioPreferencias.guardarProgresoVideo(
        rutaVideo: ruta,
        posicionMs: 300000,
        duracionTotalMs: 0,
      );

      expect(await ServicioPreferencias.obtenerPosicionGuardada(ruta), 300000);
      expect(await ServicioPreferencias.obtenerDuracionGuardada(ruta), 1800000);
    });

    test('escrituras concurrentes se serializan y la lectura inmediata obtiene el último progreso', () async {
      const ruta = '/storage/emulated/0/Movies/serie_ep1.mp4';
      final versionInicial = ServicioPreferencias.versionProgreso.value;

      // Dispara dos guardados consecutivos sin await intermedio (como al salir tras seek)
      final f1 = ServicioPreferencias.guardarProgresoVideo(
        rutaVideo: ruta,
        posicionMs: 120000,
        duracionTotalMs: 1440000,
      );
      final f2 = ServicioPreferencias.guardarProgresoVideo(
        rutaVideo: ruta,
        posicionMs: 300000,
        duracionTotalMs: 1440000,
      );

      // La lectura espera automáticamente escrituras pendientes
      final posLeida = await ServicioPreferencias.obtenerPosicionGuardada(ruta);
      await Future.wait([f1, f2]);

      expect(posLeida, 300000);
      expect(
        ServicioPreferencias.versionProgreso.value,
        greaterThan(versionInicial),
      );
    });

    test('obtenerVideosContinuarViendo refleja el progreso más reciente en orden de historial', () async {
      final v1 = ModeloVideo(
        id: '/storage/v1.mp4',
        ruta: '/storage/v1.mp4',
        nombre: 'v1.mp4',
        nombreSinExtension: 'v1',
        tamanoBytes: 1000,
        fechaModificacion: DateTime(2026, 1, 1),
        carpetaContenedora: 'storage',
        extension: 'mp4',
      );
      final v2 = ModeloVideo(
        id: '/storage/v2.mp4',
        ruta: '/storage/v2.mp4',
        nombre: 'v2.mp4',
        nombreSinExtension: 'v2',
        tamanoBytes: 1000,
        fechaModificacion: DateTime(2026, 1, 2),
        carpetaContenedora: 'storage',
        extension: 'mp4',
      );

      await ServicioPreferencias.guardarProgresoVideo(
        rutaVideo: v1.ruta,
        posicionMs: 180000,
        duracionTotalMs: 1200000,
      );
      await ServicioPreferencias.guardarProgresoVideo(
        rutaVideo: v2.ruta,
        posicionMs: 300000,
        duracionTotalMs: 1200000,
      );

      await ServicioPreferencias.enriquecerVideosConProgreso([v1, v2]);
      final continuar =
          await ServicioAlmacenamientoVideo.obtenerVideosContinuarViendo([
            v1,
            v2,
          ]);

      expect(continuar.map((v) => v.ruta).toList(), [v2.ruta, v1.ruta]);
      expect(continuar.first.posicionGuardadaMs, 300000);
    });

    test('obtenerCacheBiblioteca no resucita progreso borrado previamente en disco', () async {
      const ruta = '/storage/emulated/0/Movies/reiniciado.mp4';
      final video = ModeloVideo(
        id: ruta,
        ruta: ruta,
        nombre: 'reiniciado.mp4',
        nombreSinExtension: 'reiniciado',
        tamanoBytes: 1000,
        fechaModificacion: DateTime(2026, 1, 1),
        carpetaContenedora: 'Movies',
        extension: 'mp4',
        posicionGuardadaMs: 240000,
        duracionTotalMs: 1200000,
      );

      await ServicioPreferencias.guardarCacheBiblioteca([video]);
      await ServicioPreferencias.borrarProgresoVideo(ruta);

      final cache = await ServicioPreferencias.obtenerCacheBiblioteca();
      expect(cache.length, 1);
      expect(cache.first.posicionGuardadaMs, 0);
    });
  });
}
