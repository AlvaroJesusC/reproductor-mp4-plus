import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../modelos/modelo_info_actualizacion.dart';

/// Servicio responsable de comprobar actualizaciones públicas en GitHub Releases.
class ServicioActualizador {
  static const String usuarioGitHub = 'AlvaroJesusC';
  static const String repositorioGitHub = 'reproductor-mp4-plus';

  /// Clave para no saturar consultas en cada inicio (mínimo 4 horas entre chequeos automáticos).
  static const String _prefUltimoChequeo = 'timestamp_ultimo_chequeo_update';

  /// Verifica si existe una versión más reciente publicada en GitHub Releases.
  ///
  /// Si [forzar] es true, ignora el límite de tiempo y consulta directamente la API.
  static Future<ModeloInfoActualizacion?> verificarActualizacion({
    bool forzar = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!forzar) {
        final ultimoChequeo = prefs.getInt(_prefUltimoChequeo) ?? 0;
        final ahora = DateTime.now().millisecondsSinceEpoch;
        const cuatroHorasMs = 4 * 60 * 60 * 1000;

        if (ahora - ultimoChequeo < cuatroHorasMs) {
          return null; // Aún no ha pasado el intervalo mínimo
        }
      }

      // 1. Obtener versión de la app instalada
      final packageInfo = await PackageInfo.fromPlatform();
      final versionActual = packageInfo.version; // ej: "1.0.0"

      // 2. Consultar el último Release en la API de GitHub
      final url = Uri.parse(
        'https://api.github.com/repos/$usuarioGitHub/$repositorioGitHub/releases/latest',
      );

      final respuesta = await http.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'ReproductorMP4-App',
        },
      ).timeout(const Duration(seconds: 10));

      // Guardar timestamp del chequeo exitoso
      await prefs.setInt(_prefUltimoChequeo, DateTime.now().millisecondsSinceEpoch);

      if (respuesta.statusCode == 404) {
        // No hay releases creados todavía
        debugPrint('[ServicioActualizador] No se encontraron releases aún en GitHub.');
        return null;
      }

      if (respuesta.statusCode != 200) {
        debugPrint('[ServicioActualizador] Error al consultar API de GitHub: ${respuesta.statusCode}');
        return null;
      }

      final data = jsonDecode(respuesta.body) as Map<String, dynamic>;
      final rawTag = (data['tag_name'] as String? ?? '').trim();
      final versionRemota = rawTag.replaceAll(RegExp(r'^[vV]'), '');

      if (versionRemota.isEmpty) return null;

      final notas = (data['body'] as String?)?.trim() ??
          'Corrección de errores y mejoras de rendimiento.';

      // Obtener la arquitectura nativa del dispositivo (ej: 'arm64-v8a')
      String? abiPreferida;
      try {
        abiPreferida = await OtaUpdate().getAbi();
      } catch (_) {
        abiPreferida = null;
      }

      // Buscar el archivo APK en los assets del Release
      final assets = data['assets'] as List<dynamic>? ?? [];
      String? urlApk;
      String nombreArchivo = 'reproductor-mp4-plus.apk';
      int? tamanoBytes;

      // 1. Prioridad: Buscar coincidencia exacta con la arquitectura del dispositivo
      if (abiPreferida != null && abiPreferida.isNotEmpty) {
        final abiNormalizada = abiPreferida.toLowerCase();
        for (final asset in assets) {
          final nombre = (asset['name'] as String? ?? '').toLowerCase();
          if (nombre.endsWith('.apk') && nombre.contains(abiNormalizada)) {
            urlApk = asset['browser_download_url'] as String?;
            nombreArchivo = asset['name'] as String? ?? nombreArchivo;
            tamanoBytes = asset['size'] as int?;
            break;
          }
        }
      }

      // 2. Si es dispositivo arm64-v8a y no hay APK arm64, fallback a armeabi-v7a
      if (urlApk == null && abiPreferida?.toLowerCase() == 'arm64-v8a') {
        for (final asset in assets) {
          final nombre = (asset['name'] as String? ?? '').toLowerCase();
          if (nombre.endsWith('.apk') && nombre.contains('armeabi-v7a')) {
            urlApk = asset['browser_download_url'] as String?;
            nombreArchivo = asset['name'] as String? ?? nombreArchivo;
            tamanoBytes = asset['size'] as int?;
            break;
          }
        }
      }

      // 3. Fallback general: tomar el primer APK que exista (ej: universal)
      if (urlApk == null) {
        for (final asset in assets) {
          final nombre = (asset['name'] as String? ?? '').toLowerCase();
          if (nombre.endsWith('.apk')) {
            urlApk = asset['browser_download_url'] as String?;
            nombreArchivo = asset['name'] as String? ?? nombreArchivo;
            tamanoBytes = asset['size'] as int?;
            break;
          }
        }
      }

      if (urlApk == null || urlApk.isEmpty) {
        debugPrint('[ServicioActualizador] El release $versionRemota no tiene ningún archivo .apk adjunto.');
        return null;
      }

      final hayNueva = esVersionMayor(versionRemota, versionActual);

      return ModeloInfoActualizacion(
        versionRemota: versionRemota,
        versionActual: versionActual,
        notasCambios: notas,
        urlDescargaApk: urlApk,
        nombreArchivo: nombreArchivo,
        tamanoBytes: tamanoBytes,
        hayNuevaVersion: hayNueva,
      );
    } catch (e, stack) {
      debugPrint('[ServicioActualizador] Excepción al comprobar versión: $e\n$stack');
      return null;
    }
  }

  /// Compara dos versiones semánticas (ej: "1.0.1" vs "1.0.0").
  /// Retorna true si [versionRemota] es estrictamente mayor que [versionLocal].
  static bool esVersionMayor(String versionRemota, String versionLocal) {
    try {
      // Limpiar prefijos (como 'v' o 'V') y sufijos como +1, -beta, etc.
      String limpiar(String v) =>
          v.replaceAll(RegExp(r'^[vV]'), '').split('+').first.split('-').first.trim();
      final partesRemota = limpiar(versionRemota)
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
      final partesLocal = limpiar(versionLocal)
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();

      final longitud = partesRemota.length > partesLocal.length
          ? partesRemota.length
          : partesLocal.length;

      for (int i = 0; i < longitud; i++) {
        final r = i < partesRemota.length ? partesRemota[i] : 0;
        final l = i < partesLocal.length ? partesLocal[i] : 0;

        if (r > l) return true;
        if (r < l) return false;
      }

      // Si las versiones mayores.menores.parches son iguales, comparar número de build si existe
      final buildRemoto = _obtenerBuildNumber(versionRemota);
      final buildLocal = _obtenerBuildNumber(versionLocal);
      if (buildRemoto != null && buildLocal != null) {
        return buildRemoto > buildLocal;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  static int? _obtenerBuildNumber(String version) {
    if (!version.contains('+')) return null;
    final partes = version.split('+');
    if (partes.length >= 2) {
      return int.tryParse(partes[1]);
    }
    return null;
  }
}
