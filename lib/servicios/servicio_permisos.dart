import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Servicio para verificar y solicitar permisos de almacenamiento y medios en Android.
class ServicioPermisos {
  /// Solicita los permisos adecuados según la versión del sistema operativo.
  static Future<bool> solicitarPermisosAlmacenamiento() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 33) {
      // Android 13+ utiliza permisos granulares de medios
      final estados = await [
        Permission.videos,
        Permission.audio,
      ].request();

      final videosOtorgado = estados[Permission.videos]?.isGranted ?? false;
      final audioOtorgado = estados[Permission.audio]?.isGranted ?? false;

      return videosOtorgado || audioOtorgado;
    } else {
      // Android 12 o inferior utiliza el permiso de almacenamiento general
      final estado = await Permission.storage.request();
      if (estado.isGranted) {
        return true;
      }
      
      // En Android 11 (API 30) se puede intentar solicitar gestión si storage falla
      if (sdkInt >= 30) {
        final estadoManage = await Permission.manageExternalStorage.request();
        return estadoManage.isGranted;
      }

      return false;
    }
  }

  /// Verifica si los permisos ya están concedidos sin solicitarlos.
  static Future<bool> tienePermisosAlmacenamiento() async {
    if (!Platform.isAndroid) return true;

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 33) {
      final videosConcedido = await Permission.videos.isGranted;
      return videosConcedido;
    } else {
      final almacenamientoConcedido = await Permission.storage.isGranted;
      if (almacenamientoConcedido) return true;
      if (sdkInt >= 30) {
        return await Permission.manageExternalStorage.isGranted;
      }
      return false;
    }
  }

  /// Abre la configuración del sistema para que el usuario active los permisos manualmente.
  static Future<bool> abrirAjustesApp() async {
    return await openAppSettings();
  }
}
