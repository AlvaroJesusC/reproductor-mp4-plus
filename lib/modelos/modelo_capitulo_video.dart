import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'modelo_video.dart';

/// Categoría de segmento saltable detectado en los metadatos del video.
enum TipoCapituloSaltar {
  intro('Saltar intro'),
  outro('Saltar outro'),
  creditos('Saltar créditos');

  final String etiquetaBoton;
  const TipoCapituloSaltar(this.etiquetaBoton);
}

/// Estado inmutable del botón contextual de salto (Skip Intro / Outro / Credits).
@immutable
class CapituloSaltarActivo {
  final CapituloVideo capituloOrigen;
  final TipoCapituloSaltar tipo;
  final int? destinoMs;
  final bool avanzaASiguienteVideo;

  const CapituloSaltarActivo({
    required this.capituloOrigen,
    required this.tipo,
    this.destinoMs,
    this.avanzaASiguienteVideo = false,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is CapituloSaltarActivo &&
            other.capituloOrigen == capituloOrigen &&
            other.tipo == tipo &&
            other.destinoMs == destinoMs &&
            other.avanzaASiguienteVideo == avanzaASiguienteVideo);
  }

  @override
  int get hashCode => Object.hash(
        capituloOrigen,
        tipo,
        destinoMs,
        avanzaASiguienteVideo,
      );
}

/// Representa un capítulo o episodio embebido en los metadatos del video (MKV/MP4).
@immutable
class CapituloVideo {
  static final RegExp _regexCreditos = RegExp(
    r'(?:^|[\s:.\-_/\[\(])(credits|creditos|end\s+credits|closing\s+credits)(?:$|[\s:.\-_\]\)])',
  );
  static final RegExp _regexOutro = RegExp(
    r'(?:^|[\s:.\-_/\[\(])(outro|ending|ed\s*\d*|cierre)(?:$|[\s:.\-_\]\)])',
  );
  static final RegExp _regexIntro = RegExp(
    r'(?:^|[\s:.\-_/\[\(])(intro|introduccion|opening|apertura|op\s*\d*)(?:$|[\s:.\-_\]\)])',
  );

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

  /// Detecta si el título del capítulo corresponde a Intro, Outro o Créditos.
  static TipoCapituloSaltar? detectarTipoSaltar(String titulo) {
    final normalizado = _normalizarTexto(titulo);
    if (normalizado.isEmpty) return null;
    if (_regexCreditos.hasMatch(normalizado)) {
      return TipoCapituloSaltar.creditos;
    }
    if (_regexOutro.hasMatch(normalizado)) {
      return TipoCapituloSaltar.outro;
    }
    if (_regexIntro.hasMatch(normalizado)) {
      return TipoCapituloSaltar.intro;
    }
    return null;
  }

  /// Determina si en [posicionMs] el video está dentro de una intro, outro o créditos.
  static CapituloSaltarActivo? capituloSaltarEnPosicion({
    required List<CapituloVideo> capitulos,
    required int posicionMs,
    required int duracionTotalMs,
    required bool haySiguienteVideo,
  }) {
    if (capitulos.isEmpty || posicionMs < capitulos.first.inicioMs) {
      return null;
    }

    int idxActual = -1;
    for (int i = capitulos.length - 1; i >= 0; i--) {
      if (capitulos[i].inicioMs <= posicionMs) {
        idxActual = i;
        break;
      }
    }
    if (idxActual < 0) return null;

    final cap = capitulos[idxActual];
    final tipo = detectarTipoSaltar(cap.titulo);
    if (tipo == null) return null;

    if (idxActual + 1 < capitulos.length) {
      return CapituloSaltarActivo(
        capituloOrigen: cap,
        tipo: tipo,
        destinoMs: capitulos[idxActual + 1].inicioMs,
      );
    }

    // Último capítulo: solo aplica salto automático para outro o créditos
    if (tipo == TipoCapituloSaltar.intro) return null;

    if (haySiguienteVideo) {
      return CapituloSaltarActivo(
        capituloOrigen: cap,
        tipo: tipo,
        avanzaASiguienteVideo: true,
      );
    }

    if (duracionTotalMs > cap.inicioMs + 3000 &&
        posicionMs < duracionTotalMs - 2000) {
      return CapituloSaltarActivo(
        capituloOrigen: cap,
        tipo: tipo,
        destinoMs: duracionTotalMs - 1000,
      );
    }

    return null;
  }

  static String _normalizarTexto(String texto) {
    return texto
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u');
  }

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
