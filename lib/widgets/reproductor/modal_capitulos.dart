import 'package:flutter/material.dart';
import '../../constantes/colores_app.dart';
import '../../modelos/modelo_capitulo_video.dart';

/// Ventana modal estilo VLC ("Ir al capítulo...") para explorar y saltar entre
/// capítulos/episodios incrustados en los metadatos del video.
class ModalCapitulos extends StatefulWidget {
  final List<CapituloVideo> capitulos;
  final int indiceActual;
  final ValueChanged<CapituloVideo> alSeleccionarCapitulo;

  const ModalCapitulos({
    super.key,
    required this.capitulos,
    required this.indiceActual,
    required this.alSeleccionarCapitulo,
  });

  /// Muestra el diálogo modal de capítulos con fondo translúcido cinemático.
  static Future<void> mostrar(
    BuildContext context, {
    required List<CapituloVideo> capitulos,
    required int indiceActual,
    required ValueChanged<CapituloVideo> alSeleccionarCapitulo,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (_) => ModalCapitulos(
        capitulos: capitulos,
        indiceActual: indiceActual,
        alSeleccionarCapitulo: alSeleccionarCapitulo,
      ),
    );
  }

  @override
  State<ModalCapitulos> createState() => _ModalCapitulosState();
}

class _ModalCapitulosState extends State<ModalCapitulos> {
  static const double _alturaEstimadaFila = 54.0;
  late final ScrollController _controladorScroll;

  @override
  void initState() {
    super.initState();
    final indiceInicial = widget.indiceActual.clamp(
      0,
      widget.capitulos.isEmpty ? 0 : widget.capitulos.length - 1,
    );
    _controladorScroll = ScrollController(
      initialScrollOffset: indiceInicial > 2
          ? (indiceInicial - 1) * _alturaEstimadaFila
          : 0.0,
    );
  }

  @override
  void dispose() {
    _controladorScroll.dispose();
    super.dispose();
  }

  void _seleccionarYCerrar(CapituloVideo capitulo) {
    Navigator.of(context).pop();
    widget.alSeleccionarCapitulo(capitulo);
  }

  @override
  Widget build(BuildContext context) {
    final capitulos = widget.capitulos;
    final indiceActual = widget.indiceActual;
    final hayCapitulos = capitulos.isNotEmpty;
    final hayAnterior = hayCapitulos && indiceActual > 0;
    final haySiguiente = hayCapitulos && (indiceActual + 1) < capitulos.length;

    final maxAlto = MediaQuery.sizeOf(context).height * 0.78;

    return Dialog(
      backgroundColor: ColoresApp.fondoModalTranslucido,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.16),
          width: 1.0,
        ),
      ),
      child: RepaintBoundary(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 440, maxHeight: maxAlto),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _EncabezadoModalCapitulos(cantidadCapitulos: capitulos.length),
              Divider(
                height: 1,
                thickness: 0.8,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              if (!hayCapitulos)
                const _EstadoVacioCapitulos()
              else ...[
                Flexible(
                  child: ListView.builder(
                    controller: _controladorScroll,
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    itemCount: capitulos.length,
                    itemBuilder: (ctx, i) {
                      final cap = capitulos[i];
                      return _FilaCapitulo(
                        key: ValueKey(cap.indice),
                        capitulo: cap,
                        esActual: i == indiceActual,
                        alPresionar: () => _seleccionarYCerrar(cap),
                      );
                    },
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 0.8,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                _BarraNavegacionCapitulos(
                  indiceActual: indiceActual,
                  totalCapitulos: capitulos.length,
                  hayAnterior: hayAnterior,
                  haySiguiente: haySiguiente,
                  alIrAnterior: hayAnterior
                      ? () => _seleccionarYCerrar(capitulos[indiceActual - 1])
                      : null,
                  alIrSiguiente: haySiguiente
                      ? () => _seleccionarYCerrar(
                          capitulos[indiceActual < 0 ? 0 : indiceActual + 1],
                        )
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EncabezadoModalCapitulos extends StatelessWidget {
  final int cantidadCapitulos;

  const _EncabezadoModalCapitulos({required this.cantidadCapitulos});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: ColoresApp.acentoPrimario.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.bookmarks_rounded,
              color: ColoresApp.acentoPrimario,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ir al capítulo...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
                if (cantidadCapitulos > 0)
                  Text(
                    '$cantidadCapitulos ${cantidadCapitulos == 1 ? 'episodio o parte' : 'episodios o partes'}',
                    style: const TextStyle(
                      color: ColoresApp.textoSecundario,
                      fontSize: 11.5,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white70,
              size: 20,
            ),
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _FilaCapitulo extends StatelessWidget {
  final CapituloVideo capitulo;
  final bool esActual;
  final VoidCallback alPresionar;

  const _FilaCapitulo({
    super.key,
    required this.capitulo,
    required this.esActual,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: alPresionar,
          child: Ink(
            decoration: BoxDecoration(
              color: esActual
                  ? ColoresApp.acentoPrimario.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: esActual
                    ? ColoresApp.acentoPrimario.withValues(alpha: 0.70)
                    : Colors.white.withValues(alpha: 0.06),
                width: esActual ? 1.2 : 0.8,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: esActual
                        ? const Icon(
                            Icons.play_arrow_rounded,
                            color: ColoresApp.acentoPrimario,
                            size: 20,
                          )
                        : Text(
                            '${capitulo.indice + 1}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: ColoresApp.textoSecundario,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      capitulo.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: esActual
                            ? Colors.white
                            : ColoresApp.textoPrincipal,
                        fontSize: 13.5,
                        fontWeight:
                            esActual ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: esActual
                          ? ColoresApp.acentoPrimario.withValues(alpha: 0.30)
                          : Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      capitulo.tiempoLegible,
                      style: TextStyle(
                        color: esActual
                            ? Colors.white
                            : ColoresApp.textoSecundario,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarraNavegacionCapitulos extends StatelessWidget {
  final int indiceActual;
  final int totalCapitulos;
  final bool hayAnterior;
  final bool haySiguiente;
  final VoidCallback? alIrAnterior;
  final VoidCallback? alIrSiguiente;

  const _BarraNavegacionCapitulos({
    required this.indiceActual,
    required this.totalCapitulos,
    required this.hayAnterior,
    required this.haySiguiente,
    this.alIrAnterior,
    this.alIrSiguiente,
  });

  @override
  Widget build(BuildContext context) {
    final textoEstado = indiceActual >= 0
        ? '${indiceActual + 1} / $totalCapitulos'
        : '— / $totalCapitulos';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: alIrAnterior,
              icon: const Icon(Icons.skip_previous_rounded, size: 18),
              label: const Text(
                'Anterior',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: hayAnterior ? Colors.white : Colors.white24,
                side: BorderSide(
                  color: hayAnterior
                      ? Colors.white.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.08),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              textoEstado,
              style: const TextStyle(
                color: ColoresApp.textoSecundario,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: alIrSiguiente,
              icon: const Icon(Icons.skip_next_rounded, size: 18),
              label: const Text(
                'Siguiente',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: haySiguiente
                    ? ColoresApp.acentoPrimario
                    : Colors.white.withValues(alpha: 0.08),
                foregroundColor: haySiguiente ? Colors.white : Colors.white24,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoVacioCapitulos extends StatelessWidget {
  const _EstadoVacioCapitulos();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bookmarks_outlined,
            color: Colors.white.withValues(alpha: 0.35),
            size: 40,
          ),
          const SizedBox(height: 12),
          const Text(
            'Sin capítulos disponibles',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Este archivo de video no contiene marcadores de episodios o capítulos en sus metadatos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ColoresApp.textoSecundario,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cerrar',
                style: TextStyle(color: ColoresApp.acentoPrimario),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
