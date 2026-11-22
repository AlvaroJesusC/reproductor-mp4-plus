import 'package:flutter/material.dart';
import 'modelo_carpeta_video.dart';
import 'modelo_video.dart';

/// Criterios de ordenación disponibles para listas de videos y playlists.
///
/// El valor por defecto del reproductor es [nombreAsc], que utiliza ordenación
/// natural (alfanumérica) para que episodios como E1, E2, E10 o Cap 1, Cap 2,
/// Cap 10 se muestren siempre en orden lógico humano.
enum CriterioOrdenVideos {
  nombreAsc(
    clave: 'nombre_asc',
    etiqueta: 'Nombre (A - Z)',
    descripcion: 'Orden natural (E1, E2, E10...)',
    icono: Icons.sort_by_alpha_rounded,
  ),
  nombreDesc(
    clave: 'nombre_desc',
    etiqueta: 'Nombre (Z - A)',
    descripcion: 'Orden natural inverso (E10, E2, E1...)',
    icono: Icons.sort_by_alpha_rounded,
  ),
  fechaReciente(
    clave: 'fecha_reciente',
    etiqueta: 'Más recientes',
    descripcion: 'Modificados recientemente primero',
    icono: Icons.schedule_rounded,
  ),
  fechaAntigua(
    clave: 'fecha_antigua',
    etiqueta: 'Más antiguos',
    descripcion: 'Modificados anteriormente primero',
    icono: Icons.history_rounded,
  ),
  tamanoMayor(
    clave: 'tamano_mayor',
    etiqueta: 'Mayor tamaño',
    descripcion: 'Archivos más pesados primero',
    icono: Icons.data_usage_rounded,
  ),
  tamanoMenor(
    clave: 'tamano_menor',
    etiqueta: 'Menor tamaño',
    descripcion: 'Archivos más ligeros primero',
    icono: Icons.sd_storage_outlined,
  );

  final String clave;
  final String etiqueta;
  final String descripcion;
  final IconData icono;

  const CriterioOrdenVideos({
    required this.clave,
    required this.etiqueta,
    required this.descripcion,
    required this.icono,
  });

  /// Reconstruye el criterio desde su clave persistida.
  /// Devuelve [nombreAsc] si la clave es nula o desconocida.
  static CriterioOrdenVideos desdeClave(String? clave) {
    if (clave == null || clave.isEmpty) return CriterioOrdenVideos.nombreAsc;
    for (final criterio in CriterioOrdenVideos.values) {
      if (criterio.clave == clave) return criterio;
    }
    return CriterioOrdenVideos.nombreAsc;
  }
}

/// Utilidad pura de ordenación natural (alfanumérica) y por metadatos para
/// videos y carpetas. Garantiza un orden total estricto y cero asignaciones
/// innecesarias por comparación.
final class OrdenadorVideos {
  OrdenadorVideos._();

  /// Compara dos cadenas en orden natural (humano):
  /// - Secuencias de dígitos se comparan por su valor numérico real
  ///   (`E1 < E2 < E10`, `S01E02 < S01E10`, `Temporada 2 < Temporada 10`).
  /// - Ignora diferencias de mayúsculas/minúsculas y tildes comunes
  ///   (`Capítulo 1 < Capitulo 2`).
  /// - Mantiene desempate determinista para garantizar transitividad estricta.
  static int compararNatural(String a, String b) {
    if (identical(a, b) || a == b) return 0;

    var i = 0;
    var j = 0;
    final lenA = a.length;
    final lenB = b.length;
    var primerDesempateCeros = 0;

    while (i < lenA && j < lenB) {
      final codeA = a.codeUnitAt(i);
      final codeB = b.codeUnitAt(j);

      if (_esDigitoAscii(codeA) && _esDigitoAscii(codeB)) {
        final inicioA = i;
        while (i < lenA && _esDigitoAscii(a.codeUnitAt(i))) {
          i++;
        }
        final inicioB = j;
        while (j < lenB && _esDigitoAscii(b.codeUnitAt(j))) {
          j++;
        }

        var sigA = inicioA;
        while (sigA < i && a.codeUnitAt(sigA) == 0x30) {
          sigA++;
        }
        var sigB = inicioB;
        while (sigB < j && b.codeUnitAt(sigB) == 0x30) {
          sigB++;
        }

        final digitosSigA = i - sigA;
        final digitosSigB = j - sigB;
        if (digitosSigA != digitosSigB) {
          return digitosSigA.compareTo(digitosSigB);
        }

        for (var k = 0; k < digitosSigA; k++) {
          final dA = a.codeUnitAt(sigA + k);
          final dB = b.codeUnitAt(sigB + k);
          if (dA != dB) {
            return dA.compareTo(dB);
          }
        }

        if (primerDesempateCeros == 0) {
          final largoA = i - inicioA;
          final largoB = j - inicioB;
          if (largoA != largoB) {
            primerDesempateCeros = largoA.compareTo(largoB);
          }
        }
        continue;
      }

      final normA = _normalizarCaracter(codeA);
      final normB = _normalizarCaracter(codeB);
      if (normA != normB) {
        return normA.compareTo(normB);
      }
      i++;
      j++;
    }

    if (i < lenA) return 1;
    if (j < lenB) return -1;
    if (primerDesempateCeros != 0) return primerDesempateCeros;
    return a.compareTo(b);
  }

  /// Compara dos videos aplicando el [criterio] elegido, con desempate
  /// determinista por nombre natural y ruta.
  static int compararVideos(
    ModeloVideo a,
    ModeloVideo b,
    CriterioOrdenVideos criterio,
  ) {
    final resultado = switch (criterio) {
      CriterioOrdenVideos.nombreAsc => _compararPorNombreNatural(a, b),
      CriterioOrdenVideos.nombreDesc => _compararPorNombreNatural(b, a),
      CriterioOrdenVideos.fechaReciente => b.fechaModificacion.compareTo(
        a.fechaModificacion,
      ),
      CriterioOrdenVideos.fechaAntigua => a.fechaModificacion.compareTo(
        b.fechaModificacion,
      ),
      CriterioOrdenVideos.tamanoMayor => b.tamanoBytes.compareTo(a.tamanoBytes),
      CriterioOrdenVideos.tamanoMenor => a.tamanoBytes.compareTo(b.tamanoBytes),
    };

    if (resultado != 0) return resultado;
    final desempateNombre = _compararPorNombreNatural(a, b);
    if (desempateNombre != 0) return desempateNombre;
    return a.ruta.compareTo(b.ruta);
  }

  /// Ordena en sitio una lista de videos según el [criterio].
  static void ordenarVideos(
    List<ModeloVideo> videos,
    CriterioOrdenVideos criterio,
  ) {
    if (videos.length < 2) return;
    videos.sort((a, b) => compararVideos(a, b, criterio));
  }

  /// Devuelve una nueva lista ordenada sin mutar la colección original.
  static List<ModeloVideo> videosOrdenados(
    Iterable<ModeloVideo> videos,
    CriterioOrdenVideos criterio,
  ) {
    final copia = List<ModeloVideo>.from(videos);
    ordenarVideos(copia, criterio);
    return copia;
  }

  /// Ordena en sitio una lista de carpetas por nombre natural.
  static void ordenarCarpetas(
    List<ModeloCarpetaVideo> carpetas, {
    bool descendente = false,
  }) {
    if (carpetas.length < 2) return;
    carpetas.sort((a, b) {
      final res = descendente
          ? compararNatural(b.nombre, a.nombre)
          : compararNatural(a.nombre, b.nombre);
      if (res != 0) return res;
      return a.ruta.compareTo(b.ruta);
    });
  }

  static int _compararPorNombreNatural(ModeloVideo a, ModeloVideo b) {
    final porNombreBase = compararNatural(
      a.nombreSinExtension,
      b.nombreSinExtension,
    );
    if (porNombreBase != 0) return porNombreBase;
    return compararNatural(a.nombre, b.nombre);
  }

  static bool _esDigitoAscii(int codeUnit) =>
      codeUnit >= 0x30 && codeUnit <= 0x39;

  static int _normalizarCaracter(int codeUnit) {
    if (codeUnit >= 0x41 && codeUnit <= 0x5A) {
      return codeUnit + 0x20;
    }
    return switch (codeUnit) {
      0xC0 || 0xC1 || 0xC2 || 0xC3 || 0xC4 || 0xC5 ||
      0xE0 || 0xE1 || 0xE2 || 0xE3 || 0xE4 || 0xE5 => 0x61, // a
      0xC8 || 0xC9 || 0xCA || 0xCB || 0xE8 || 0xE9 || 0xEA || 0xEB => 0x65, // e
      0xCC || 0xCD || 0xCE || 0xCF || 0xEC || 0xED || 0xEE || 0xEF => 0x69, // i
      0xD2 || 0xD3 || 0xD4 || 0xD5 || 0xD6 ||
      0xF2 || 0xF3 || 0xF4 || 0xF5 || 0xF6 => 0x6F, // o
      0xD9 || 0xDA || 0xDB || 0xDC || 0xF9 || 0xFA || 0xFB || 0xFC => 0x75, // u
      0xC7 || 0xE7 => 0x63, // c
      0xD1 => 0xF1, // Ñ -> ñ
      0xDD || 0xFD || 0xFF => 0x79, // y
      _ => codeUnit,
    };
  }
}
