import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reproductormp4/modelos/modelo_video.dart';
import 'package:reproductormp4/servicios/servicio_preferencias.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ServicioPreferencias.reiniciarInstanciaParaPruebas();
  });

  group('ServicioPreferencias - Completado y Visto / No Visto', () {
    test('marcarVideoCompletado(true) agrega a completados y borra pos', () async {
      const ruta = '/storage/video1.mp4';
      await ServicioPreferencias.guardarProgresoVideo(
        rutaVideo: ruta,
        posicionMs: 45000,
        duracionTotalMs: 90000,
      );

      expect(await ServicioPreferencias.obtenerPosicionGuardada(ruta), 45000);
      expect(await ServicioPreferencias.esVideoCompletado(ruta), false);

      await ServicioPreferencias.marcarVideoCompletado(ruta, completado: true);

      expect(await ServicioPreferencias.esVideoCompletado(ruta), true);
      expect(await ServicioPreferencias.obtenerPosicionGuardada(ruta), 0);
    });

    test('marcarVideoCompletado(false) elimina de completados y borra posición', () async {
      const ruta = '/storage/video2.mp4';
      await ServicioPreferencias.marcarVideoCompletado(ruta, completado: true);
      expect(await ServicioPreferencias.esVideoCompletado(ruta), true);

      await ServicioPreferencias.marcarVideoCompletado(ruta, completado: false);
      expect(await ServicioPreferencias.esVideoCompletado(ruta), false);
      expect(await ServicioPreferencias.obtenerPosicionGuardada(ruta), 0);
    });

    test('alternarCompletado alterna correctamente el estado', () async {
      const ruta = '/storage/video3.mp4';
      final estado1 = await ServicioPreferencias.alternarCompletado(ruta);
      expect(estado1, true);
      expect(await ServicioPreferencias.esVideoCompletado(ruta), true);

      final estado2 = await ServicioPreferencias.alternarCompletado(ruta);
      expect(estado2, false);
      expect(await ServicioPreferencias.esVideoCompletado(ruta), false);
    });

    test('enriquecerVideosConProgreso limpia posicionGuardadaMs de videos completados', () async {
      const ruta = '/storage/video4.mp4';
      final video = ModeloVideo(
        id: 'video4',
        ruta: ruta,
        nombre: 'video4.mp4',
        nombreSinExtension: 'video4',
        tamanoBytes: 1024,
        fechaModificacion: DateTime.now(),
        carpetaContenedora: 'storage',
        extension: 'mp4',
        posicionGuardadaMs: 60000,
      );

      await ServicioPreferencias.marcarVideoCompletado(ruta, completado: true);
      await ServicioPreferencias.enriquecerVideosConProgreso([video]);

      expect(video.estaCompletado, true);
      expect(video.posicionGuardadaMs, 0);
      expect(video.tieneProgreso, false);
    });

    test('obtenerCacheBiblioteca no bloquea desmarcar completado si caché tenía estaCompletado: true', () async {
      const ruta = '/storage/video5.mp4';

      final video = ModeloVideo(
        id: 'video5',
        ruta: ruta,
        nombre: 'video5.mp4',
        nombreSinExtension: 'video5',
        tamanoBytes: 1024,
        fechaModificacion: DateTime.now(),
        carpetaContenedora: 'storage',
        extension: 'mp4',
        estaCompletado: true,
      );

      // Guardar en la caché de biblioteca
      await ServicioPreferencias.guardarCacheBiblioteca([video]);

      // Asegurar que en SharedPreferences los completados no lo contienen
      await ServicioPreferencias.marcarVideoCompletado(ruta, completado: false);

      final lista = await ServicioPreferencias.obtenerCacheBiblioteca();
      expect(lista.length, 1);
      expect(lista.first.estaCompletado, false);
      expect(lista.first.posicionGuardadaMs, 0);
    });
  });
}
