import 'package:flutter/material.dart';
import '../../constantes/colores_app.dart';

/// Diálogo modal en español para elegir la velocidad de reproducción.
class ModalVelocidad extends StatelessWidget {
  final double velocidadActual;
  final ValueChanged<double> alSeleccionarVelocidad;

  static const List<double> velocidadesDisponibles = [
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
  ];

  const ModalVelocidad({
    super.key,
    required this.velocidadActual,
    required this.alSeleccionarVelocidad,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ColoresApp.fondoSecundario,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speed_rounded, color: ColoresApp.acentoPrimario),
                const SizedBox(width: 10),
                const Text(
                  'Velocidad de Reproducción',
                  style: TextStyle(
                    color: ColoresApp.textoPrincipal,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: velocidadesDisponibles.map((v) {
                final esSeleccionada = (v - velocidadActual).abs() < 0.01;
                final etiqueta = v == 1.0 ? '1.0x (Normal)' : '${v}x';

                return ChoiceChip(
                  label: Text(
                    etiqueta,
                    style: TextStyle(
                      color: esSeleccionada ? Colors.white : ColoresApp.textoPrincipal,
                      fontWeight: esSeleccionada ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: esSeleccionada,
                  selectedColor: ColoresApp.acentoPrimario,
                  backgroundColor: ColoresApp.fondoTarjeta,
                  onSelected: (seleccionado) {
                    if (seleccionado) {
                      alSeleccionarVelocidad(v);
                      Navigator.of(context).pop();
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cerrar',
                  style: TextStyle(color: ColoresApp.textoSecundario),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
