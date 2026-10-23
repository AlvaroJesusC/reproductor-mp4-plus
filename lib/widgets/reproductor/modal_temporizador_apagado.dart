import 'package:flutter/material.dart';
import '../../constantes/colores_app.dart';

/// Modal para configurar el temporizador de apagado automático (Sleep Timer).
class ModalTemporizadorApagado extends StatelessWidget {
  final int? segundosRestantes;
  final bool apagarAlTerminarVideo;
  final ValueChanged<int?> alSeleccionarMinutos;
  final ValueChanged<bool> alAlternarFinVideo;

  const ModalTemporizadorApagado({
    super.key,
    required this.segundosRestantes,
    required this.apagarAlTerminarVideo,
    required this.alSeleccionarMinutos,
    required this.alAlternarFinVideo,
  });

  @override
  Widget build(BuildContext context) {
    final tieneTemporizadorActivo =
        (segundosRestantes != null && segundosRestantes! > 0) ||
        apagarAlTerminarVideo;

    return Dialog(
      backgroundColor: ColoresApp.fondoModalTranslucido,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.15),
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
                      Icons.bedtime_rounded,
                      color: ColoresApp.acentoPrimario,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Temporizador de Apagado',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Pausa el video y ahorra batería al dormir',
                          style: TextStyle(
                            color: Color(0xFF8B949E),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Estado activo si hay temporizador
              if (tieneTemporizadorActivo)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: ColoresApp.acentoAmbar.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: ColoresApp.acentoAmbar.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        color: ColoresApp.acentoAmbar,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          apagarAlTerminarVideo
                              ? 'Activo: Al terminar el video actual'
                              : 'Tiempo restante: ${_formatearSegundos(segundosRestantes!)}',
                          style: const TextStyle(
                            color: ColoresApp.acentoAmbar,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          alSeleccionarMinutos(null);
                          alAlternarFinVideo(false);
                          Navigator.of(context).pop();
                        },
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              // Opciones predeterminadas en minutos
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [15, 30, 45, 60, 90, 120].map((minutos) {
                  return OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () {
                      alSeleccionarMinutos(minutos);
                      alAlternarFinVideo(false);
                      Navigator.of(context).pop();
                    },
                    child: Text('$minutos min'),
                  );
                }).toList(),
              ),

              const SizedBox(height: 14),

              // Opción: Al finalizar video
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  apagarAlTerminarVideo
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_off_rounded,
                  color: apagarAlTerminarVideo
                      ? ColoresApp.acentoPrimario
                      : Colors.white54,
                ),
                title: const Text(
                  'Al terminar el video actual',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  alAlternarFinVideo(!apagarAlTerminarVideo);
                  Navigator.of(context).pop();
                },
              ),

              const SizedBox(height: 10),

              // Botón cerrar
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(color: Color(0xFF8B949E)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatearSegundos(int seg) {
    final m = seg ~/ 60;
    final s = seg % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
