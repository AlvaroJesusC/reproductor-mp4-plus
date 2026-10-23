import 'package:flutter/material.dart';
import '../../constantes/colores_app.dart';

/// Modal para ajustar la sincronización (delay/desfase) de audio y subtítulos en tiempo real.
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
    setState(() {
      _desfaseSubtitulos = (_desfaseSubtitulos + delta).clamp(-10.0, 10.0);
    });
    widget.alCambiarDesfaseSubtitulos(_desfaseSubtitulos);
  }

  void _ajustarAudio(double delta) {
    setState(() {
      _desfaseAudio = (_desfaseAudio + delta).clamp(-5.0, 5.0);
    });
    widget.alCambiarDesfaseAudio(_desfaseAudio);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1.0,
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ColoresApp.acentoPrimario.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.sync_rounded,
                      color: ColoresApp.acentoPrimario,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Sincronización de Pistas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 1. SECCIÓN SUBTÍTULOS
              _construirControlDesfase(
                icono: Icons.subtitles_rounded,
                titulo: 'Retardo de Subtítulos',
                valorSegundos: _desfaseSubtitulos,
                alAjustar: _ajustarSubtitulos,
                alReiniciar: () => _ajustarSubtitulos(-_desfaseSubtitulos),
              ),

              const Divider(color: Color(0xFF21262D), height: 32),

              // 2. SECCIÓN AUDIO
              _construirControlDesfase(
                icono: Icons.audiotrack_rounded,
                titulo: 'Retardo de Audio',
                valorSegundos: _desfaseAudio,
                alAjustar: _ajustarAudio,
                alReiniciar: () => _ajustarAudio(-_desfaseAudio),
              ),

              const SizedBox(height: 18),

              // Botón Aceptar
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: ColoresApp.acentoPrimario,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Listo',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirControlDesfase({
    required IconData icono,
    required String titulo,
    required double valorSegundos,
    required ValueChanged<double> alAjustar,
    required VoidCallback alReiniciar,
  }) {
    final valorStr = valorSegundos == 0.0
        ? '0.0s (Sincronizado)'
        : '${valorSegundos > 0 ? "+" : ""}${valorSegundos.toStringAsFixed(1)}s';

    final estaDesfasado = valorSegundos.abs() > 0.05;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icono, size: 18, color: const Color(0xFF8B949E)),
                const SizedBox(width: 8),
                Text(
                  titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (estaDesfasado)
              InkWell(
                onTap: alReiniciar,
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'Restablecer',
                    style: TextStyle(
                      color: ColoresApp.acentoAmbar,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Visualización del valor
        Center(
          child: Text(
            valorStr,
            style: TextStyle(
              color: estaDesfasado
                  ? ColoresApp.acentoAmbar
                  : ColoresApp.textoPrincipal,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Botonera de ajuste fino (-0.5s, -0.1s, +0.1s, +0.5s)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _botonPaso('-0.5s', () => alAjustar(-0.5)),
            const SizedBox(width: 8),
            _botonPaso('-0.1s', () => alAjustar(-0.1)),
            const SizedBox(width: 14),
            _botonPaso('+0.1s', () => alAjustar(0.1)),
            const SizedBox(width: 8),
            _botonPaso('+0.5s', () => alAjustar(0.5)),
          ],
        ),
      ],
    );
  }

  Widget _botonPaso(String etiqueta, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF21262D),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(
          etiqueta,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
