/// Reglas puras y deterministas para calcular, validar y persistir la reanudación
/// del progreso de reproducción de video.
class LogicaReanudacionVideo {
  const LogicaReanudacionVideo._();

  /// Posición mínima en milisegundos para considerar que un video tiene progreso reanudable.
  static const int umbralMinimoProgresoMs = 5000;

  /// Margen de seguridad antes del final del video al reanudar para evitar saltar directo al EOF.
  static const int margenFinalReanudacionMs = 2000;

  /// Determina si un video debe considerarse completado según su posición y duración.
  static bool esVideoCompletado({
    required int posicionMs,
    required int duracionMs,
  }) {
    if (duracionMs <= 0 || posicionMs <= 0) return false;
    if (duracionMs <= 10000) {
      return posicionMs >= (duracionMs * 0.95);
    }
    return posicionMs >= (duracionMs * 0.95) ||
        (duracionMs - posicionMs <= 4000);
  }

  /// Calcula la posición objetivo inicial (en ms) al abrir un video.
  ///
  /// El almacenamiento persistente (`posicionDiscoMs` y `completadoEnDisco`)
  /// tiene prioridad absoluta sobre cualquier copia en memoria del modelo para
  /// evitar reanudar con valores obsoletos (por ejemplo tras usar PiP o cambiar
  /// entre pestañas).
  static int calcularObjetivoReanudacionMs({
    required int posicionDiscoMs,
    required int posicionMemoriaMs,
    required bool completadoEnDisco,
    required int duracionConocidaMs,
  }) {
    if (completadoEnDisco) return 0;

    final candidatoMs = posicionDiscoMs > umbralMinimoProgresoMs
        ? posicionDiscoMs
        : (posicionMemoriaMs > umbralMinimoProgresoMs ? posicionMemoriaMs : 0);

    if (candidatoMs <= umbralMinimoProgresoMs) return 0;

    return ajustarObjetivoADuracionReal(
      objetivoMs: candidatoMs,
      duracionRealMs: duracionConocidaMs,
    );
  }

  /// Ajusta el punto objetivo cuando ya se conoce la duración real del medio.
  static int ajustarObjetivoADuracionReal({
    required int objetivoMs,
    required int duracionRealMs,
  }) {
    if (objetivoMs <= umbralMinimoProgresoMs) return 0;
    if (duracionRealMs <= 0) return objetivoMs;

    if (esVideoCompletado(posicionMs: objetivoMs, duracionMs: duracionRealMs)) {
      return 0;
    }

    final limiteSeguroMs = duracionRealMs - margenFinalReanudacionMs;
    if (limiteSeguroMs <= umbralMinimoProgresoMs) {
      return 0;
    }

    if (objetivoMs > limiteSeguroMs) {
      return limiteSeguroMs;
    }
    return objetivoMs;
  }

  /// Evalúa si el motor ya alcanzó el punto de reanudación dentro de una tolerancia
  /// compatible con saltos por keyframe (GOP de hasta 5s en videos largos).
  static bool estaReanudacionConfirmada({
    required int posicionActualMs,
    required int objetivoMs,
  }) {
    if (objetivoMs <= umbralMinimoProgresoMs) return true;
    if (posicionActualMs <= 0) return false;
    final toleranciaMs = objetivoMs > 15000 ? 5000 : 2500;
    return posicionActualMs >= (objetivoMs - toleranciaMs);
  }

  /// Selecciona la posición más confiable al persistir, protegiendo contra
  /// lecturas transitorias en 0ms emitidas durante pausas, errores o cierre del motor.
  static int resolverPosicionParaGuardar({
    required int posicionMotorMs,
    required int ultimaPosicionValidaMs,
    int? posicionForzadaMs,
  }) {
    if (posicionForzadaMs != null) {
      return posicionForzadaMs < 0 ? 0 : posicionForzadaMs;
    }
    if (posicionMotorMs > 0) {
      return posicionMotorMs;
    }
    return ultimaPosicionValidaMs > 0 ? ultimaPosicionValidaMs : 0;
  }
}
