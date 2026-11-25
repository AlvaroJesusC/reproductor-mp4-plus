import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Tipo de pista multimedia soportada por el selector de pistas.
enum TipoPistaMedia { audio, subtitulo }

/// Representación inmutable y enriquecida de una pista de audio o subtítulo
/// detectada en libmpv (incrustada o externa).
@immutable
final class PistaMedia {
  final String id;
  final TipoPistaMedia tipo;
  final String? titulo;
  final String? idioma;
  final String? codec;
  final String? canales;
  final int? cantidadCanales;
  final int? frecuenciaHz;
  final bool esPredeterminada;
  final bool esForzada;
  final bool esExterna;
  final String? rutaExterna;
  final bool estaSeleccionada;

  const PistaMedia({
    required this.id,
    required this.tipo,
    this.titulo,
    this.idioma,
    this.codec,
    this.canales,
    this.cantidadCanales,
    this.frecuenciaHz,
    this.esPredeterminada = false,
    this.esForzada = false,
    this.esExterna = false,
    this.rutaExterna,
    this.estaSeleccionada = false,
  });

  /// Indica si es un identificador centinela de libmpv (`auto` o `no`).
  bool get esEspecial {
    final limpio = id.trim().toLowerCase();
    return limpio.isEmpty || limpio == 'auto' || limpio == 'no' || limpio == 'false';
  }

  /// Indica si la pista de subtítulo está basada en mapas de bits (PGS/VobSub/DVB),
  /// los cuales requieren renderizado nativo de libmpv (`sub-visibility=yes`).
  bool get esSubtituloImagen {
    if (tipo != TipoPistaMedia.subtitulo) return false;
    final c = (codec ?? '').trim().toLowerCase();
    if (c.isEmpty) return false;
    return c.contains('pgs') ||
        c.contains('dvd_subtitle') ||
        c.contains('dvdsub') ||
        c.contains('vobsub') ||
        c.contains('dvb_subtitle') ||
        c.contains('dvbsub') ||
        c.contains('xsub');
  }

  /// Nombre legible del idioma en español a partir del código ISO-639.
  String get nombreIdiomaLegible => mapearCodigoIdioma(idioma);

  /// Nombre corto y limpio del códec para mostrar como insignia técnica.
  String get codecLegible => mapearNombreCodec(codec);

  /// Descripción compacta de canales de audio (ej. `2.0`, `5.1`, `7.1`, `Mono`).
  String get canalesLegible {
    if (tipo != TipoPistaMedia.audio) return '';
    final count = cantidadCanales;
    if (count != null && count > 0) {
      return switch (count) {
        1 => 'Mono',
        2 => '2.0',
        6 => '5.1',
        8 => '7.1',
        _ => '${count}ch',
      };
    }
    final raw = (canales ?? '').trim().toLowerCase();
    if (raw.isEmpty) return '';
    if (raw == 'mono' || raw == '1.0') return 'Mono';
    if (raw == 'stereo' || raw == '2.0') return '2.0';
    if (raw.contains('5.1')) return '5.1';
    if (raw.contains('7.1')) return '7.1';
    if (raw.contains('2.1')) return '2.1';
    return raw.toUpperCase();
  }

  /// Título principal limpio para mostrar al usuario sin valores crudos técnicos.
  String get tituloVisible {
    final t = titulo?.trim() ?? '';
    if (t.isNotEmpty) return t;

    final lang = nombreIdiomaLegible;
    if (lang.isNotEmpty) {
      return esForzada ? '$lang (Forzados)' : lang;
    }

    final extPath = rutaExterna?.trim() ?? '';
    if (extPath.isNotEmpty) {
      final partes = extPath.split(RegExp(r'[/\\]'));
      if (partes.isNotEmpty && partes.last.trim().isNotEmpty) {
        return partes.last.trim();
      }
    }

    return tipo == TipoPistaMedia.audio
        ? 'Pista de audio #$id'
        : 'Subtítulo #$id';
  }

  /// Lista compacta de metadatos no redundantes (idioma, códec, canales, rol).
  List<String> get etiquetasMetadatos {
    final etiquetas = <String>[];
    final tituloNormalizado = _normalizar(tituloVisible);

    final lang = nombreIdiomaLegible;
    if (lang.isNotEmpty) {
      final langNorm = _normalizar(lang);
      final yaIncluido =
          tituloNormalizado.contains(langNorm) ||
          (langNorm == 'espanol' &&
              (tituloNormalizado.contains('castellano') ||
                  tituloNormalizado.contains('latino')));
      if (!yaIncluido) {
        etiquetas.add(lang);
      }
    }

    final codecTxt = codecLegible;
    if (codecTxt.isNotEmpty) {
      etiquetas.add(codecTxt);
    }

    final canalesTxt = canalesLegible;
    if (canalesTxt.isNotEmpty) {
      etiquetas.add(canalesTxt);
    }

    if (esForzada && !tituloNormalizado.contains('forzad')) {
      etiquetas.add('Forzados');
    }

    if (esExterna) {
      etiquetas.add('Externo');
    }

    if (esPredeterminada && etiquetas.length < 3) {
      etiquetas.add('Por defecto');
    }

    return etiquetas;
  }

  AudioTrack aAudioTrack() {
    return AudioTrack(
      id,
      titulo,
      idioma,
      isDefault: esPredeterminada,
      codec: codec,
      channels: canales,
      channelscount: cantidadCanales,
      samplerate: frecuenciaHz,
    );
  }

  SubtitleTrack aSubtitleTrack() {
    return SubtitleTrack(
      id,
      titulo,
      idioma,
      isDefault: esPredeterminada,
      codec: codec,
    );
  }

  PistaMedia copiarCon({
    String? titulo,
    String? idioma,
    String? codec,
    String? canales,
    int? cantidadCanales,
    int? frecuenciaHz,
    bool? esPredeterminada,
    bool? esForzada,
    bool? esExterna,
    String? rutaExterna,
    bool? estaSeleccionada,
  }) {
    return PistaMedia(
      id: id,
      tipo: tipo,
      titulo: titulo ?? this.titulo,
      idioma: idioma ?? this.idioma,
      codec: codec ?? this.codec,
      canales: canales ?? this.canales,
      cantidadCanales: cantidadCanales ?? this.cantidadCanales,
      frecuenciaHz: frecuenciaHz ?? this.frecuenciaHz,
      esPredeterminada: esPredeterminada ?? this.esPredeterminada,
      esForzada: esForzada ?? this.esForzada,
      esExterna: esExterna ?? this.esExterna,
      rutaExterna: rutaExterna ?? this.rutaExterna,
      estaSeleccionada: estaSeleccionada ?? this.estaSeleccionada,
    );
  }

  /// Convierte un código ISO-639 (2 o 3 letras o con región) en un nombre legible en español.
  static String mapearCodigoIdioma(String? codigoCrudo) {
    final limpio = (codigoCrudo ?? '').trim().toLowerCase().replaceAll('_', '-');
    if (limpio.isEmpty ||
        limpio == 'und' ||
        limpio == 'unknown' ||
        limpio == 'mul' ||
        limpio == 'zxx' ||
        limpio == 'auto') {
      return '';
    }

    const especificos = <String, String>{
      'es-419': 'Español (Latino)',
      'es-mx': 'Español (Latino)',
      'es-la': 'Español (Latino)',
      'es-es': 'Español (España)',
      'pt-br': 'Portugués (Brasil)',
      'pt-pt': 'Portugués',
      'zh-hans': 'Chino (Simplificado)',
      'zh-cn': 'Chino (Simplificado)',
      'zh-hant': 'Chino (Tradicional)',
      'zh-tw': 'Chino (Tradicional)',
      'en-us': 'Inglés (EE. UU.)',
      'en-gb': 'Inglés (Reino Unido)',
    };
    final exacto = especificos[limpio];
    if (exacto != null) return exacto;

    final base = limpio.split('-').first;
    const idiomas = <String, String>{
      'es': 'Español',
      'spa': 'Español',
      'lat': 'Español (Latino)',
      'en': 'Inglés',
      'eng': 'Inglés',
      'ja': 'Japonés',
      'jp': 'Japonés',
      'jpn': 'Japonés',
      'fr': 'Francés',
      'fra': 'Francés',
      'fre': 'Francés',
      'de': 'Alemán',
      'deu': 'Alemán',
      'ger': 'Alemán',
      'it': 'Italiano',
      'ita': 'Italiano',
      'pt': 'Portugués',
      'por': 'Portugués',
      'ko': 'Coreano',
      'kor': 'Coreano',
      'zh': 'Chino',
      'zho': 'Chino',
      'chi': 'Chino',
      'ru': 'Ruso',
      'rus': 'Ruso',
      'ar': 'Árabe',
      'ara': 'Árabe',
      'hi': 'Hindi',
      'hin': 'Hindi',
      'ca': 'Catalán',
      'cat': 'Catalán',
      'eu': 'Euskera',
      'eus': 'Euskera',
      'baq': 'Euskera',
      'gl': 'Gallego',
      'glg': 'Gallego',
      'pl': 'Polaco',
      'pol': 'Polaco',
      'nl': 'Neerlandés',
      'nld': 'Neerlandés',
      'dut': 'Neerlandés',
      'tr': 'Turco',
      'tur': 'Turco',
      'vi': 'Vietnamita',
      'vie': 'Vietnamita',
      'th': 'Tailandés',
      'tha': 'Tailandés',
      'id': 'Indonesio',
      'ind': 'Indonesio',
      'uk': 'Ucraniano',
      'ukr': 'Ucraniano',
      'sv': 'Sueco',
      'swe': 'Sueco',
      'no': 'Noruego',
      'nor': 'Noruego',
      'da': 'Danés',
      'dan': 'Danés',
      'fi': 'Finés',
      'fin': 'Finés',
      'cs': 'Checo',
      'ces': 'Checo',
      'cze': 'Checo',
      'el': 'Griego',
      'ell': 'Griego',
      'gre': 'Griego',
      'he': 'Hebreo',
      'heb': 'Hebreo',
      'hu': 'Húngaro',
      'hun': 'Húngaro',
      'ro': 'Rumano',
      'ron': 'Rumano',
      'rum': 'Rumano',
    };
    return idiomas[base] ?? base.toUpperCase();
  }

  /// Formatea el identificador técnico de códec de FFmpeg/libmpv en una etiqueta limpia.
  static String mapearNombreCodec(String? codecCrudo) {
    final c = (codecCrudo ?? '').trim().toLowerCase();
    if (c.isEmpty) return '';
    if (c.startsWith('pcm_')) return 'PCM';

    const mapa = <String, String>{
      'aac': 'AAC',
      'ac3': 'AC3',
      'eac3': 'EAC3',
      'dts': 'DTS',
      'dca': 'DTS',
      'truehd': 'TrueHD',
      'opus': 'OPUS',
      'flac': 'FLAC',
      'mp3': 'MP3',
      'mp2': 'MP2',
      'vorbis': 'OGG',
      'alac': 'ALAC',
      'wmav2': 'WMA',
      'ass': 'ASS',
      'ssa': 'SSA',
      'subrip': 'SRT',
      'srt': 'SRT',
      'webvtt': 'VTT',
      'vtt': 'VTT',
      'mov_text': 'TXT',
      'tx3g': 'TXT',
      'text': 'TXT',
      'utf8': 'TXT',
      'hdmv_pgs_subtitle': 'PGS',
      'pgssub': 'PGS',
      'dvd_subtitle': 'VobSub',
      'dvdsub': 'VobSub',
      'vobsub': 'VobSub',
      'dvb_subtitle': 'DVB',
      'dvbsub': 'DVB',
      'eia_608': 'CC',
    };

    return mapa[c] ?? (c.length <= 6 ? c.toUpperCase() : '');
  }

  static String _normalizar(String texto) {
    return texto
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is PistaMedia &&
            other.id == id &&
            other.tipo == tipo &&
            other.titulo == titulo &&
            other.idioma == idioma &&
            other.codec == codec &&
            other.canales == canales &&
            other.cantidadCanales == cantidadCanales &&
            other.frecuenciaHz == frecuenciaHz &&
            other.esPredeterminada == esPredeterminada &&
            other.esForzada == esForzada &&
            other.esExterna == esExterna &&
            other.rutaExterna == rutaExterna &&
            other.estaSeleccionada == estaSeleccionada);
  }

  @override
  int get hashCode => Object.hash(
    id,
    tipo,
    titulo,
    idioma,
    codec,
    canales,
    cantidadCanales,
    frecuenciaHz,
    esPredeterminada,
    esForzada,
    esExterna,
    rutaExterna,
    estaSeleccionada,
  );
}

/// Estado inmutable de todas las pistas de audio y subtítulos disponibles y activas.
@immutable
final class EstadoPistasReproductor {
  final List<PistaMedia> pistasAudio;
  final List<PistaMedia> pistasSubtitulos;
  final String audioActivoId;
  final String subtituloActivoId;
  final bool cargando;

  const EstadoPistasReproductor({
    this.pistasAudio = const [],
    this.pistasSubtitulos = const [],
    this.audioActivoId = 'auto',
    this.subtituloActivoId = 'no',
    this.cargando = false,
  });

  /// Devuelve la pista de audio actualmente activa, o `null` si está silenciada o no hay coincidencia.
  PistaMedia? get pistaAudioActiva {
    for (final p in pistasAudio) {
      if (p.id == audioActivoId) return p;
    }
    return null;
  }

  /// Devuelve la pista de subtítulo actualmente activa, o `null` si están desactivados.
  PistaMedia? get pistaSubtituloActiva {
    if (!tieneSubtituloActivo) return null;
    for (final p in pistasSubtitulos) {
      if (p.id == subtituloActivoId) return p;
    }
    return null;
  }

  bool get tieneSubtituloActivo {
    final limpio = subtituloActivoId.trim().toLowerCase();
    return limpio.isNotEmpty && limpio != 'no' && limpio != 'false';
  }

  bool get audioSilenciado {
    final limpio = audioActivoId.trim().toLowerCase();
    return limpio == 'no' || limpio == 'false';
  }

  EstadoPistasReproductor copiarCon({
    List<PistaMedia>? pistasAudio,
    List<PistaMedia>? pistasSubtitulos,
    String? audioActivoId,
    String? subtituloActivoId,
    bool? cargando,
  }) {
    return EstadoPistasReproductor(
      pistasAudio: pistasAudio ?? this.pistasAudio,
      pistasSubtitulos: pistasSubtitulos ?? this.pistasSubtitulos,
      audioActivoId: audioActivoId ?? this.audioActivoId,
      subtituloActivoId: subtituloActivoId ?? this.subtituloActivoId,
      cargando: cargando ?? this.cargando,
    );
  }

  /// Construye un estado completo y consistente combinando:
  /// 1. El JSON directo de `track-list` de libmpv (fuente autoritativa con `selected`, `forced`, `external`).
  /// 2. Entradas indexadas de fallback (`track-list/count` + `track-list/i/*`).
  /// 3. El estado de `media_kit` (`Tracks` / `Track`) para cubrir cualquier pista adicional.
  static EstadoPistasReproductor construirDesdeMpv({
    String? jsonTrackList,
    List<Map<String, dynamic>>? pistasIndexadas,
    String? aidActual,
    String? sidActual,
    Tracks? tracksFallback,
    Track? trackFallback,
    bool cargando = false,
  }) {
    final audiosPorId = <String, PistaMedia>{};
    final subsPorId = <String, PistaMedia>{};

    // 1. Parsear JSON directo de `track-list`
    final itemsCrudos = _decodificarTrackListJson(jsonTrackList);
    final fuentePrincipal = itemsCrudos.isNotEmpty
        ? itemsCrudos
        : (pistasIndexadas ?? const <Map<String, dynamic>>[]);

    for (final mapa in fuentePrincipal) {
      final pista = _parsearMapaMpv(mapa);
      if (pista == null || pista.esEspecial) continue;
      if (pista.tipo == TipoPistaMedia.audio) {
        audiosPorId[pista.id] = pista;
      } else {
        subsPorId[pista.id] = pista;
      }
    }

    // 2. Fusionar pistas de `media_kit` solo si faltan o enriquecen campos vacíos
    if (tracksFallback != null) {
      for (final a in tracksFallback.audio) {
        final id = a.id.trim();
        if (_esIdEspecial(id)) continue;
        final existente = audiosPorId[id];
        if (existente == null) {
          audiosPorId[id] = PistaMedia(
            id: id,
            tipo: TipoPistaMedia.audio,
            titulo: _limpiarOpcional(a.title),
            idioma: _limpiarOpcional(a.language),
            codec: _limpiarOpcional(a.codec),
            canales: _limpiarOpcional(a.channels),
            cantidadCanales: a.channelscount ?? a.audiochannels,
            frecuenciaHz: a.samplerate,
            esPredeterminada: a.isDefault ?? false,
          );
        } else {
          audiosPorId[id] = existente.copiarCon(
            titulo: existente.titulo ?? _limpiarOpcional(a.title),
            idioma: existente.idioma ?? _limpiarOpcional(a.language),
            codec: existente.codec ?? _limpiarOpcional(a.codec),
            canales: existente.canales ?? _limpiarOpcional(a.channels),
            cantidadCanales:
                existente.cantidadCanales ?? a.channelscount ?? a.audiochannels,
            frecuenciaHz: existente.frecuenciaHz ?? a.samplerate,
          );
        }
      }

      for (final s in tracksFallback.subtitle) {
        final id = s.id.trim();
        if (_esIdEspecial(id)) continue;
        final existente = subsPorId[id];
        if (existente == null) {
          subsPorId[id] = PistaMedia(
            id: id,
            tipo: TipoPistaMedia.subtitulo,
            titulo: _limpiarOpcional(s.title),
            idioma: _limpiarOpcional(s.language),
            codec: _limpiarOpcional(s.codec),
            esPredeterminada: s.isDefault ?? false,
          );
        } else {
          subsPorId[id] = existente.copiarCon(
            titulo: existente.titulo ?? _limpiarOpcional(s.title),
            idioma: existente.idioma ?? _limpiarOpcional(s.language),
            codec: existente.codec ?? _limpiarOpcional(s.codec),
          );
        }
      }
    }

    final listaAudio = audiosPorId.values.toList()..sort(_compararPistasPorId);
    final listaSubs = subsPorId.values.toList()..sort(_compararPistasPorId);

    // 3. Resolver la pista realmente activa en libmpv
    final audioActivo = _resolverActivoId(
      pistas: listaAudio,
      propiedadMpv: aidActual,
      fallbackId: trackFallback?.audio.id,
      esSubtitulo: false,
    );
    final subActivo = _resolverActivoId(
      pistas: listaSubs,
      propiedadMpv: sidActual,
      fallbackId: trackFallback?.subtitle.id,
      esSubtitulo: true,
    );

    final audiosNormalizados = listaAudio
        .map((p) => p.copiarCon(estaSeleccionada: p.id == audioActivo))
        .toList(growable: false);
    final subsNormalizados = listaSubs
        .map((p) => p.copiarCon(estaSeleccionada: p.id == subActivo))
        .toList(growable: false);

    return EstadoPistasReproductor(
      pistasAudio: audiosNormalizados,
      pistasSubtitulos: subsNormalizados,
      audioActivoId: audioActivo,
      subtituloActivoId: subActivo,
      cargando: cargando,
    );
  }

  static List<Map<String, dynamic>> _decodificarTrackListJson(String? crudo) {
    final limpio = (crudo ?? '').trim();
    if (limpio.isEmpty || !limpio.startsWith('[')) return const [];
    try {
      final decoded = jsonDecode(limpio);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  static PistaMedia? _parsearMapaMpv(Map<String, dynamic> mapa) {
    final tipoRaw = mapa['type']?.toString().trim().toLowerCase() ?? '';
    final TipoPistaMedia? tipo = switch (tipoRaw) {
      'audio' => TipoPistaMedia.audio,
      'sub' || 'subtitle' => TipoPistaMedia.subtitulo,
      _ => null,
    };
    if (tipo == null) return null;

    final idRaw = mapa['id']?.toString().trim() ?? '';
    if (_esIdEspecial(idRaw)) return null;

    return PistaMedia(
      id: idRaw,
      tipo: tipo,
      titulo: _limpiarOpcional(mapa['title']?.toString()),
      idioma: _limpiarOpcional(mapa['lang']?.toString()),
      codec: _limpiarOpcional(mapa['codec']?.toString()),
      canales: _limpiarOpcional(mapa['demux-channels']?.toString()),
      cantidadCanales:
          _parsearEntero(mapa['demux-channel-count']) ??
          _parsearEntero(mapa['audio-channels']),
      frecuenciaHz: _parsearEntero(mapa['demux-samplerate']),
      esPredeterminada: _parsearBool(mapa['default']),
      esForzada: _parsearBool(mapa['forced']),
      esExterna: _parsearBool(mapa['external']),
      rutaExterna: _limpiarOpcional(mapa['external-filename']?.toString()),
      estaSeleccionada: _parsearBool(mapa['selected']),
    );
  }

  static String _resolverActivoId({
    required List<PistaMedia> pistas,
    required String? propiedadMpv,
    required String? fallbackId,
    required bool esSubtitulo,
  }) {
    // 1. Prioridad máxima: la bandera `selected: true` devuelta por libmpv en `track-list`
    for (final p in pistas) {
      if (p.estaSeleccionada) return p.id;
    }

    // 2. Propiedad directa `aid` / `sid` de libmpv
    final mpvNorm = _normalizarValorPropiedad(propiedadMpv);
    if (mpvNorm == 'no') return 'no';
    if (mpvNorm != null && mpvNorm != 'auto') {
      if (pistas.any((p) => p.id == mpvNorm)) return mpvNorm;
    }

    // 3. Fallback del estado de `media_kit`
    final fbNorm = _normalizarValorPropiedad(fallbackId);
    if (fbNorm == 'no') return 'no';
    if (fbNorm != null && fbNorm != 'auto') {
      if (pistas.any((p) => p.id == fbNorm)) return fbNorm;
    }

    // 4. Si en subtítulos libmpv no tiene ninguno seleccionado, mostrar "Desactivados"
    if (esSubtitulo) {
      return 'no';
    }

    // 5. En audio, si está en `auto` y hay pistas reales, usar la predeterminada o primera
    if (pistas.isNotEmpty) {
      final pred = pistas.where((p) => p.esPredeterminada).firstOrNull;
      return (pred ?? pistas.first).id;
    }

    return 'auto';
  }

  static String? _normalizarValorPropiedad(String? valor) {
    final limpio = (valor ?? '').trim().toLowerCase();
    if (limpio.isEmpty) return null;
    if (limpio == 'no' || limpio == 'false' || limpio == '0') return 'no';
    if (limpio == 'auto' || limpio == 'yes' || limpio == 'true') return 'auto';
    return valor!.trim();
  }

  static bool _esIdEspecial(String id) {
    final limpio = id.trim().toLowerCase();
    return limpio.isEmpty ||
        limpio == 'auto' ||
        limpio == 'no' ||
        limpio == 'false';
  }

  static String? _limpiarOpcional(String? valor) {
    final limpio = valor?.trim();
    if (limpio == null || limpio.isEmpty) return null;
    return limpio;
  }

  static int? _parsearEntero(dynamic valor) {
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    if (valor is String) return int.tryParse(valor.trim());
    return null;
  }

  static bool _parsearBool(dynamic valor) {
    if (valor is bool) return valor;
    if (valor is num) return valor != 0;
    if (valor is String) {
      final v = valor.trim().toLowerCase();
      return v == 'true' || v == 'yes' || v == '1';
    }
    return false;
  }

  static int _compararPistasPorId(PistaMedia a, PistaMedia b) {
    final numA = int.tryParse(a.id);
    final numB = int.tryParse(b.id);
    if (numA != null && numB != null) return numA.compareTo(numB);
    if (numA != null) return -1;
    if (numB != null) return 1;
    return a.id.compareTo(b.id);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is EstadoPistasReproductor &&
            other.audioActivoId == audioActivoId &&
            other.subtituloActivoId == subtituloActivoId &&
            other.cargando == cargando &&
            listEquals(other.pistasAudio, pistasAudio) &&
            listEquals(other.pistasSubtitulos, pistasSubtitulos));
  }

  @override
  int get hashCode => Object.hash(
    audioActivoId,
    subtituloActivoId,
    cargando,
    Object.hashAll(pistasAudio),
    Object.hashAll(pistasSubtitulos),
  );
}
