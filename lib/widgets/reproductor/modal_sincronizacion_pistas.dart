import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constantes/colores_app.dart';

/// Modal compacto y optimizado para ajustar la sincronización (delay/desfase) de audio y subtítulos en tiempo real.
///
/// Diseñado con formato acoplado y mínima superficie para permitir visualizar el video
/// y leer subtítulos mientras se calibra la pista en horizontal y vertical sin obstruir la pantalla.
class ModalSincronizacionPistas extends StatefulWidget {
  final double desfaseSubtitulosSegundos;
  final double desfaseAudioSegundos;
  final ValueChanged<double> alCambiarDesfaseSubtitulos;
  final ValueChanged<double> alCambiarDesfaseAudio;

  const ModalSincronizacionPistas({
    super.key,
    required this.desfaseSubtitulosSegundos,
    required this.desfaseAudioSegundos,
    required this.alCambiarDesfaseSubtitulos,
    required this.alCambiarDesfaseAudio,
  });

  @override
  State<ModalSincronizacionPistas> createState() =>
      _ModalSincronizacionPistasState();
}

class _ModalSincronizacionPistasState extends State<ModalSincronizacionPistas> {
  late double _desfaseSubtitulos;
  late double _desfaseAudio;

  @override
  void initState() {
    super.initState();
    _desfaseSubtitulos = widget.desfaseSubtitulosSegundos;
    _desfaseAudio = widget.desfaseAudioSegundos;
  }

  void _ajustarSubtitulos(double delta) {
    HapticFeedback.selectionClick();
    setState(() {
      final nuevo = ((_desfaseSubtitulos + delta) * 10).round() / 10.0;
      _desfaseSubtitulos = nuevo.clamp(-10.0, 10.0);
      if (_desfaseSubtitulos.abs() < 0.05) _desfaseSubtitulos = 0.0;
    });
    widget.alCambiarDesfaseSubtitulos(_desfaseSubtitulos);
  }

  void _ajustarAudio(double delta) {
    HapticFeedback.selectionClick();
    setState(() {
      final nuevo = ((_desfaseAudio + delta) * 10).round() / 10.0;
      _desfaseAudio = nuevo.clamp(-5.0, 5.0);
      if (_desfaseAudio.abs() < 0.05) _desfaseAudio = 0.0;
    });
    widget.alCambiarDesfaseAudio(_desfaseAudio);
  }

  bool get _hayDesfaseGlobal =>
      _desfaseSubtitulos.abs() > 0.05 || _desfaseAudio.abs() > 0.05;

  void _restablecerTodo() {
    HapticFeedback.mediumImpact();
    setState(() {
      _desfaseSubtitulos = 0.0;
      _desfaseAudio = 0.0;
    });
    widget.alCambiarDesfaseSubtitulos(0.0);
    widget.alCambiarDesfaseAudio(0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Center(
        child: Container(
          width: 380,
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            // Fondo translúcido (40% de opacidad) que permite ver el video y los subtítulos por debajo
            color: ColoresApp.fondoModalTranslucido,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabecera compacta con título, reinicio global y botón cerrar
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: ColoresApp.acentoPrimario.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(
                        Icons.sync_rounded,
                        color: ColoresApp.acentoPrimario,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Sincronización de Pistas',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ColoresApp.textoPrincipal,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                    if (_hayDesfaseGlobal) ...[
                      InkWell(
                        onTap: _restablecerTodo,
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.refresh_rounded,
                                size: 12,
                                color: ColoresApp.acentoAmbar,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Restablecer',
                                style: TextStyle(
                                  color: ColoresApp.acentoAmbar,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.white70,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      splashRadius: 16,
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // 1. SECCIÓN RETARDO DE SUBTÍTULOS
                _construirTarjetaPista(
                  icono: Icons.subtitles_rounded,
                  titulo: 'Subtítulos',
                  valorSegundos: _desfaseSubtitulos,
                  alAjustar: _ajustarSubtitulos,
                  alReiniciar: () => _ajustarSubtitulos(-_desfaseSubtitulos),
                ),

                const SizedBox(height: 7),

                // 2. SECCIÓN RETARDO DE AUDIO
                _construirTarjetaPista(
                  icono: Icons.audiotrack_rounded,
                  titulo: 'Audio',
                  valorSegundos: _desfaseAudio,
                  alAjustar: _ajustarAudio,
                  alReiniciar: () => _ajustarAudio(-_desfaseAudio),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirTarjetaPista({
    required IconData icono,
    required String titulo,
    required double valorSegundos,
    required ValueChanged<double> alAjustar,
    required VoidCallback alReiniciar,
  }) {
    final estaDesfasado = valorSegundos.abs() > 0.05;
    final valorStr = !estaDesfasado
        ? '0.0s'
        : '${valorSegundos > 0 ? "+" : ""}${valorSegundos.toStringAsFixed(1)}s';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: estaDesfasado
              ? ColoresApp.acentoAmbar.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.08),
          width: 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila superior: Título e Icono a la izquierda | Botón restablecer y Pastilla a la derecha
          Row(
            children: [
              Icon(icono, size: 15, color: ColoresApp.textoSecundario),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ColoresApp.textoPrincipal,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (estaDesfasado) ...[
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    alReiniciar();
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.replay_rounded,
                          size: 11,
                          color: ColoresApp.acentoAmbar,
                        ),
                        SizedBox(width: 2),
                        Text(
                          '0.0s',
                          style: TextStyle(
                            color: ColoresApp.acentoAmbar,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              // Pastilla indicadora del desfase
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: estaDesfasado
                      ? ColoresApp.acentoAmbar.withValues(alpha: 0.16)
                      : ColoresApp.acentoVerde.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: estaDesfasado
                        ? ColoresApp.acentoAmbar.withValues(alpha: 0.35)
                        : ColoresApp.acentoVerde.withValues(alpha: 0.30),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!estaDesfasado) ...[
                      const Icon(
                        Icons.check_rounded,
                        size: 10,
                        color: ColoresApp.acentoVerde,
                      ),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      valorStr,
                      style: TextStyle(
                        color: estaDesfasado
                            ? ColoresApp.acentoAmbar
                            : ColoresApp.acentoVerde,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          // Fila inferior: Botonera segmentada y acoplada a todo el ancho
          Row(
            children: [
              _botonPaso('-0.5s', () => alAjustar(-0.5)),
              const SizedBox(width: 4),
              _botonPaso('-0.1s', () => alAjustar(-0.1)),
              const SizedBox(width: 6),
              _botonPaso('+0.1s', () => alAjustar(0.1)),
              const SizedBox(width: 4),
              _botonPaso('+0.5s', () => alAjustar(0.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _botonPaso(String etiqueta, VoidCallback onPressed) {
    final esPositivo = etiqueta.startsWith('+');
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 0.8,
              ),
            ),
            child: Center(
              child: Text(
                etiqueta,
                style: TextStyle(
                  color: esPositivo ? Colors.white : ColoresApp.textoPrincipal,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
