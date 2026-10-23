import 'package:flutter/material.dart';
import '../../constantes/colores_app.dart';
import '../../modelos/modelo_opciones_reproduccion.dart';
import '../../modelos/modelo_video.dart';

/// Indicador flotante en pantalla (OSD) translúcido y no invasivo.
/// - Brillo / Modo Noche: Cápsula vertical en el lateral derecho (anti-obstrucción de mano).
/// - Volumen: Cápsula vertical en el lateral izquierdo (anti-obstrucción de mano).
/// - Búsqueda de tiempo (Seek): Centro con fondo translúcido sutil.
class IndicadorGestoOSD extends StatelessWidget {
  final TipoGestoOSD tipoGesto;
  final double
  valor; // -1.0 a 1.0 para brillo (<0 es Modo Noche), 0.0 a 1.0 para volumen
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
    final insets = MediaQuery.paddingOf(context);
    final esLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final separacionDerecha = (esLandscape ? 48.0 : 32.0) + insets.right;
    final separacionIzquierda = (esLandscape ? 48.0 : 32.0) + insets.left;

    switch (tipoGesto) {
      case TipoGestoOSD.ninguno:
        return const SizedBox.shrink();

      case TipoGestoOSD.brillo:
        return _construirCapsulaLateral(
          alineacion: Alignment.centerRight,
          paddingLateral: EdgeInsets.only(right: separacionDerecha),
          child: _construirContenidoBrillo(),
        );

      case TipoGestoOSD.volumen:
        return _construirCapsulaLateral(
          alineacion: Alignment.centerLeft,
          paddingLateral: EdgeInsets.only(left: separacionIzquierda),
          child: _construirContenidoVolumen(),
        );

      case TipoGestoOSD.posicionTiempo:
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: _construirContenidoTiempo(),
          ),
        );
    }
  }

  /// Cápsula vertical delgada y translúcida para los bordes laterales de la pantalla.
  Widget _construirCapsulaLateral({
    required Alignment alineacion,
    required EdgeInsets paddingLateral,
    required Widget child,
  }) {
    return Align(
      alignment: alineacion,
      child: Padding(
        padding: paddingLateral,
        child: Container(
          width: 44,
          height: 180,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(
              alpha: 0.35,
            ), // Fondo translúcido no intrusivo
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  /// Contenido de Brillo / Modo Noche en cápsula vertical derecha.
  Widget _construirContenidoBrillo() {
    final esModoNoche = valor < 0.0;
    final int porcentaje;
    final double progreso;
    final Color colorAcento;
    final IconData icono;

    if (esModoNoche) {
      porcentaje = ((-valor) * 100).round().clamp(1, 100);
      progreso = (-valor).clamp(0.0, 1.0);
      colorAcento = const Color(0xFF9FA8DA); // Lavanda suave nocturno
      icono = Icons.bedtime_rounded;
    } else {
      porcentaje = (valor * 100).round();
      progreso = valor.clamp(0.0, 1.0);
      colorAcento = ColoresApp.acentoAzul;
      icono = porcentaje > 50
          ? Icons.brightness_high_rounded
          : Icons.brightness_medium_rounded;
    }

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Icon(icono, color: colorAcento, size: 20),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            width: 5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: progreso,
              child: Container(
                decoration: BoxDecoration(
                  color: colorAcento,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$porcentaje%',
          style: TextStyle(
            color: colorAcento,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Contenido de Volumen en cápsula vertical izquierda.
  Widget _construirContenidoVolumen() {
    final porcentaje = (valor * 100).round();
    final progreso = valor.clamp(0.0, 1.0);

    IconData iconoVol = Icons.volume_up_rounded;
    if (porcentaje == 0) {
      iconoVol = Icons.volume_off_rounded;
    } else if (porcentaje < 40) {
      iconoVol = Icons.volume_down_rounded;
    }

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Icon(iconoVol, color: ColoresApp.acentoPrimario, size: 20),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            width: 5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: progreso,
              child: Container(
                decoration: BoxDecoration(
                  color: ColoresApp.acentoPrimario,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$porcentaje%',
          style: const TextStyle(
            color: ColoresApp.textoPrincipal,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Contenido de Búsqueda de Tiempo (Seek).
  Widget _construirContenidoTiempo() {
    final esAdelantar = diferenciaSegundos >= 0;
    final signo = esAdelantar ? '+' : '-';
    final segAbs = diferenciaSegundos.abs();
    final minutos = segAbs ~/ 60;
    final segundos = segAbs % 60;

    String textoDiferencia;
    if (minutos > 0) {
      textoDiferencia =
          '$signo${minutos}m ${segundos.toString().padLeft(2, '0')}s';
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
          size: 40,
        ),
        const SizedBox(height: 6),
        Text(
          textoDiferencia,
          style: const TextStyle(
            color: ColoresApp.acentoAmbar,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${ModeloVideo.formatearTiempo(posicionObjetivoMs)} / ${ModeloVideo.formatearTiempo(duracionTotalMs)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 150,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratioProgreso,
              backgroundColor: ColoresApp.barraFondo,
              valueColor: const AlwaysStoppedAnimation<Color>(
                ColoresApp.acentoAmbar,
              ),
              minHeight: 5,
            ),
          ),
        ),
      ],
    );
  }
}
