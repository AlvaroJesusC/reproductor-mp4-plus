import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

/// Estado de la ventana flotante Picture-in-Picture en Android.
enum EstadoPipAndroid {
  disabled,
  enabled,
}

/// Alias para compatibilidad de nomenclatura.
typedef PiPStatus = EstadoPipAndroid;

/// Servicio de integración para el Picture-in-Picture (PiP) del sistema operativo Android.
/// Implementado directamente mediante MethodChannel nativo para garantizar compatibilidad total
/// con Flutter moderno y compilación release sin dependencias obsoletas.
class ServicioPipNativo {
  static const MethodChannel _canal = MethodChannel('com.example.reproductormp4/pip');
  static final StreamController<EstadoPipAndroid> _controladorStream =
      StreamController<EstadoPipAndroid>.broadcast();
  static bool _estaEnPip = false;
  static bool _canalInicializado = false;

  static void _asegurarCanal() {
    if (_canalInicializado) return;
    _canalInicializado = true;
    _canal.setMethodCallHandler((call) async {
      if (call.method == 'alCambiarEstadoPip') {
        final activo = call.arguments == true;
        _estaEnPip = activo;
        _controladorStream.add(
          activo ? EstadoPipAndroid.enabled : EstadoPipAndroid.disabled,
        );
      }
    });
  }

  /// Indica si la app se encuentra actualmente en modo PiP a nivel de sistema.
  static bool get estaEnPip {
    _asegurarCanal();
    return _estaEnPip;
  }

  /// Comprueba si el dispositivo actual soporta Picture-in-Picture a nivel de sistema.
  static Future<bool> esSoportado() async {
    try {
      if (!Platform.isAndroid) return false;
      _asegurarCanal();
      final bool? soportado = await _canal.invokeMethod<bool>('esSoportado');
      return soportado ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Activa la ventana flotante del sistema Android con relación de aspecto 16:9.
  static Future<bool> activarPip() async {
    try {
      if (!Platform.isAndroid) return false;
      _asegurarCanal();
      final bool? exito = await _canal.invokeMethod<bool>('activarPip');
      _estaEnPip = exito ?? false;
      if (_estaEnPip) {
        _controladorStream.add(EstadoPipAndroid.enabled);
      }
      return _estaEnPip;
    } catch (_) {
      return false;
    }
  }

  /// Stream reactivo de cambios de estado del modo PiP de Android.
  static Stream<EstadoPipAndroid> get streamEstadoPip {
    _asegurarCanal();
    return _controladorStream.stream;
  }

  /// Libera los recursos del servicio flotante.
  static void dispose() {
    _controladorStream.close();
  }
}
