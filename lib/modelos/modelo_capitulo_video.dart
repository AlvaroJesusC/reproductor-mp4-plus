import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'modelo_video.dart';

/// Representa un capítulo o episodio embebido en los metadatos del video (MKV/MP4).
@immutable
class CapituloVideo {
  final int indice;
  final String titulo;
  final int inicioMs;

  const CapituloVideo({
    required this.indice,
    required this.titulo,
    required this.inicioMs,
  });

  /// Tiempo de inicio formateado de forma legible (mm:ss o hh:mm:ss).
  String get tiempoLegible => ModeloVideo.formatearTiempo(inicioMs);

  /// Parsea el JSON devuelto por la propiedad `chapter-list` de libmpv.
  static List<CapituloVideo> parsearDesdeJsonMpv(String jsonCrudo) {
    final limpio = jsonCrudo.trim();
    if (limpio.isEmpty || !limpio.startsWith('[')) {
      return const [];
    }

    try {
      final decoded = jsonDecode(limpio);
      if (decoded is! List || decoded.isEmpty) {
        return const [];
      }

      final temporal = <({String? titulo, int inicioMs})>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final timeRaw = item['time'];
        if (timeRaw is! num || timeRaw.isNaN || timeRaw.isInfinite) continue;

        final inicioMs = (timeRaw * 1000).round().clamp(0, 1 << 31);
        final tituloRaw = item['title']?.toString().trim();
        temporal.add((
          titulo: (tituloRaw != null && tituloRaw.isNotEmpty)
              ? tituloRaw
              : null,
          inicioMs: inicioMs,
        ));
      }

      if (temporal.isEmpty) return const [];

      temporal.sort((a, b) => a.inicioMs.compareTo(b.inicioMs));

      return List<CapituloVideo>.generate(temporal.length, (i) {
        final item = temporal[i];
        return CapituloVideo(
          indice: i,
          titulo: item.titulo ?? 'Capítulo ${i + 1}',
          inicioMs: item.inicioMs,
        );
      }, growable: false);
    } on FormatException {
      return const [];
    }
  }

  /// Devuelve el índice del capítulo activo para [posicionMs], o -1 si no aplica.
  static int indiceEnPosicion(List<CapituloVideo> capitulos, int posicionMs) {
    if (capitulos.isEmpty) return -1;

    // Pequeña tolerancia de 250 ms para que al saltar a un keyframe cercano
    // se resalte de inmediato el capítulo destino.
    final posEfectiva = posicionMs + 250;
    for (int i = capitulos.length - 1; i >= 0; i--) {
      if (capitulos[i].inicioMs <= posEfectiva) {
        return i;
      }
    }
    return -1;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is CapituloVideo &&
            other.indice == indice &&
            other.titulo == titulo &&
            other.inicioMs == inicioMs);
  }

  @override
  int get hashCode => Object.hash(indice, titulo, inicioMs);
}
