/// Modos de ajuste de relación de aspecto para la pantalla del reproductor.
enum ModoRelacionAspecto {
  ajustar('Ajustar a Pantalla (Fit)'),
  rellenar('Rellenar Pantalla (Crop/Fill)'),
  dieciseisNueve('16:9 Estándar'),
  cuatroTres('4:3 Clásico'),
  original('Tamaño Original 1:1');

  final String etiqueta;
  const ModoRelacionAspecto(this.etiqueta);
}

/// Estado de los gestos táctiles en pantalla (OSD).
enum TipoGestoOSD { ninguno, brillo, volumen, posicionTiempo }

/// Estado reactivo exclusivo para el avance y scrubber de la barra de progreso.
class EstadoProgresoReproductor {
  final int posicionMs;
  final int duracionMs;
  final int bufferMs;

  const EstadoProgresoReproductor({
    this.posicionMs = 0,
    this.duracionMs = 0,
    this.bufferMs = 0,
  });

  EstadoProgresoReproductor copiarCon({
    int? posicionMs,
    int? duracionMs,
    int? bufferMs,
  }) {
    return EstadoProgresoReproductor(
      posicionMs: posicionMs ?? this.posicionMs,
      duracionMs: duracionMs ?? this.duracionMs,
      bufferMs: bufferMs ?? this.bufferMs,
    );
  }
}

/// Estado reactivo exclusivo para reproducción y buffering (play / pause / loader).
class EstadoReproduccionVideo {
  final bool reproduciendo;
  final bool cargando;

  const EstadoReproduccionVideo({
    this.reproduciendo = false,
    this.cargando = false,
  });

  EstadoReproduccionVideo copiarCon({bool? reproduciendo, bool? cargando}) {
    return EstadoReproduccionVideo(
      reproduciendo: reproduciendo ?? this.reproduciendo,
      cargando: cargando ?? this.cargando,
    );
  }
}

/// Estado reactivo de la reproducción para actualizar componentes de UI de forma aislada.
class EstadoInterfazReproductor {
  final bool reproduciendo;
  final bool cargando;
  final int posicionMs;
  final int duracionMs;
  final int bufferMs;

  const EstadoInterfazReproductor({
    this.reproduciendo = false,
    this.cargando = false,
    this.posicionMs = 0,
    this.duracionMs = 0,
    this.bufferMs = 0,
  });

  EstadoInterfazReproductor copiarCon({
    bool? reproduciendo,
    bool? cargando,
    int? posicionMs,
    int? duracionMs,
    int? bufferMs,
  }) {
    return EstadoInterfazReproductor(
      reproduciendo: reproduciendo ?? this.reproduciendo,
      cargando: cargando ?? this.cargando,
      posicionMs: posicionMs ?? this.posicionMs,
      duracionMs: duracionMs ?? this.duracionMs,
      bufferMs: bufferMs ?? this.bufferMs,
    );
  }
}
