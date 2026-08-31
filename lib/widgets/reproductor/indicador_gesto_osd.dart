import 'package:flutter/material.dart';
import '../../constantes/colores_app.dart';
import '../../modelos/modelo_opciones_reproduccion.dart';
import '../../modelos/modelo_video.dart';

/// Indicador flotante en pantalla (OSD) optimizado para gestos estilo VLC/MX Player (Brillo, Volumen y Búsqueda por Deslizamiento).
class IndicadorGestoOSD extends StatelessWidget {
  final TipoGestoOSD tipoGesto;
  final double valor; // 0.0 a 1.0 para brillo y volumen
  final int diferenciaSegundos; // Para seek (+15s, -10s, +90s)
  final int posicionObjetivoMs; // Tiempo resultante
  final int duracionTotalMs;

  const IndicadorGestoOSD({
    super.key,
    required this.tipoGesto,
    this.valor = 0.0,
    this.diferenciaSegundos = 0,
    this.posicionObjetivoMs = 0,
    this.duracionTotalMs = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (tipoGesto == TipoGestoOSD.ninguno) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: ColoresApp.fondoOSD,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ColoresApp.bordeOSD, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: _construirContenido(),
      ),
    );
  }

  Widget _construirContenido() {
    switch (tipoGesto) {
      case TipoGestoOSD.brillo:
        final porcentaje = (valor * 100).round();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              porcentaje > 50 ? Icons.brightness_high_rounded : Icons.brightness_medium_rounded,
              color: ColoresApp.acentoAzul,
              size: 42,
            ),
            const SizedBox(height: 10),
            Text(
              'Brillo: $porcentaje%',
              style: const TextStyle(
                color: ColoresApp.textoPrincipal,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: valor.clamp(0.0, 1.0),
                  backgroundColor: ColoresApp.barraFondo,
                  valueColor: const AlwaysStoppedAnimation<Color>(ColoresApp.acentoAzul),
                  minHeight: 6,
                ),
              ),
            ),
          ],
        );

      case TipoGestoOSD.volumen:
        final porcentaje = (valor * 100).round();
        IconData iconoVol = Icons.volume_up_rounded;
        if (porcentaje == 0) {
          iconoVol = Icons.volume_off_rounded;
        } else if (porcentaje < 40) {
          iconoVol = Icons.volume_down_rounded;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              iconoVol,
              color: ColoresApp.acentoPrimario,
              size: 42,
            ),
            const SizedBox(height: 10),
            Text(
              'Volumen: $porcentaje%',
              style: const TextStyle(
                color: ColoresApp.textoPrincipal,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: valor.clamp(0.0, 1.0),
                  backgroundColor: ColoresApp.barraFondo,
                  valueColor: const AlwaysStoppedAnimation<Color>(ColoresApp.acentoPrimario),
                  minHeight: 6,
                ),
              ),
            ),
          ],
        );

      case TipoGestoOSD.posicionTiempo:
        final esAdelantar = diferenciaSegundos >= 0;
        final signo = esAdelantar ? '+' : '-';
        final segAbs = diferenciaSegundos.abs();
        final minutos = segAbs ~/ 60;
        final segundos = segAbs % 60;

        String textoDiferencia;
        if (minutos > 0) {
          textoDiferencia = '$signo${minutos}m ${segundos.toString().padLeft(2, '0')}s';
        } else {
          textoDiferencia = '$signo${segundos}s';
        }

        final ratioProgreso = duracionTotalMs > 0
            ? (posicionObjetivoMs / duracionTotalMs).clamp(0.0, 1.0)
            : 0.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              esAdelantar ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
              color: ColoresApp.acentoAmbar,
              size: 44,
            ),
            const SizedBox(height: 6),
            Text(
              textoDiferencia,
              style: const TextStyle(
                color: ColoresApp.acentoAmbar,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${ModeloVideo.formatearTiempo(posicionObjetivoMs)} / ${ModeloVideo.formatearTiempo(duracionTotalMs)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratioProgreso,
                  backgroundColor: ColoresApp.barraFondo,
                  valueColor: const AlwaysStoppedAnimation<Color>(ColoresApp.acentoAmbar),
                  minHeight: 5,
                ),
              ),
            ),
          ],
        );

      case TipoGestoOSD.ninguno:
        return const SizedBox.shrink();
    }
  }
}
