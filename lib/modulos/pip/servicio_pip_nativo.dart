import 'dart:async';
import 'dart:io';
import 'package:floating/floating.dart';

export 'package:floating/floating.dart';

/// Servicio de integración para el Picture-in-Picture (PiP) del sistema operativo Android.
class ServicioPipNativo {
  static final Floating _floating = Floating();
  static bool _estaEnPip = false;
  static StreamSubscription<PiPStatus>? _subscripcionEstado;

  static void _iniciarEscuchaSiEsNecesario() {
    if (_subscripcionEstado != null) return;
    _subscripcionEstado = _floating.pipStatus$.listen((status) {
      _estaEnPip = status == PiPStatus.enabled;
    });
  }

  /// Indica si la app se encuentra actualmente en modo PiP a nivel de sistema.
  static bool get estaEnPip {
    _iniciarEscuchaSiEsNecesario();
    return _estaEnPip;
  }

  /// Comprueba si el dispositivo actual soporta Picture-in-Picture a nivel de sistema.
  static Future<bool> esSoportado() async {
    try {
      if (!Platform.isAndroid) return false;
      return await _floating.isPipAvailable;
    } catch (_) {
      return false;
    }
  }

  /// Activa la ventana flotante del sistema Android con relación de aspecto 16:9.
  static Future<bool> activarPip({
    Rational aspectRatio = const Rational.landscape(),
  }) async {
    try {
      if (!Platform.isAndroid) return false;
      _iniciarEscuchaSiEsNecesario();
      final status = await _floating.enable(aspectRatio: aspectRatio);
      _estaEnPip = status == PiPStatus.enabled;
      return _estaEnPip;
    } catch (_) {
      return false;
    }
  }

  /// Stream reactivo de cambios de estado del modo PiP de Android.
  static Stream<PiPStatus> get streamEstadoPip {
    _iniciarEscuchaSiEsNecesario();
    return _floating.pipStatus$;
  }

  /// Libera los recursos del servicio flotante.
  static void dispose() {
    _subscripcionEstado?.cancel();
    _subscripcionEstado = null;
    _floating.dispose();
  }
}
