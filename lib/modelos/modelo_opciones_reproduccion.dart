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
enum TipoGestoOSD {
  ninguno,
  brillo,
  volumen,
  posicionTiempo,
}
