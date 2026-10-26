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
  static final StreamController<void> _controladorCierrePip =
      StreamController<void>.broadcast();
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
      } else if (call.method == 'alCerrarPipNativo') {
        _controladorCierrePip.add(null);
      }
    });
  }

  static bool _autoPipHabilitado = false;

  /// Indica si la entrada automática a PiP está actualmente habilitada.
  static bool get autoPipHabilitado => _autoPipHabilitado;

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

  /// Habilita o deshabilita la entrada automática a PiP al salir de la aplicación (Home o cambio de app).
  static Future<void> configurarAutoPip(
    bool habilitado, {
    int ancho = 16,
    int alto = 9,
  }) async {
    try {
      if (!Platform.isAndroid) return;
      _asegurarCanal();
      _autoPipHabilitado = habilitado;
      await _canal.invokeMethod<void>('configurarAutoPip', {
        'habilitado': habilitado,
        'ancho': ancho > 0 ? ancho : 16,
        'alto': alto > 0 ? alto : 9,
      });
    } catch (_) {}
  }

  /// Stream reactivo de cambios de estado del modo PiP de Android.
  static Stream<EstadoPipAndroid> get streamEstadoPip {
    _asegurarCanal();
    return _controladorStream.stream;
  }

  /// Stream reactivo para cuando el usuario cierra deliberadamente la ventana flotante de PiP.
  static Stream<void> get streamCierrePip {
    _asegurarCanal();
    return _controladorCierrePip.stream;
  }

  /// Libera los recursos del servicio flotante.
  static void dispose() {
    _controladorStream.close();
    _controladorCierrePip.close();
  }
}
