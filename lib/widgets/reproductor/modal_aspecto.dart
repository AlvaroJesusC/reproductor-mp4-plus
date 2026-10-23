import 'package:flutter/material.dart';
import '../../constantes/colores_app.dart';
import '../../modelos/modelo_opciones_reproduccion.dart';

/// Diálogo modal en español para elegir la relación de aspecto del video.
class ModalAspecto extends StatelessWidget {
  final ModoRelacionAspecto aspectoActual;
  final ValueChanged<ModoRelacionAspecto> alSeleccionarAspecto;

  const ModalAspecto({
    super.key,
    required this.aspectoActual,
    required this.alSeleccionarAspecto,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ColoresApp.fondoSecundario,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.aspect_ratio_rounded,
                    color: ColoresApp.acentoPrimario,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Ajuste de Pantalla / Aspecto',
                    style: TextStyle(
                      color: ColoresApp.textoPrincipal,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...ModoRelacionAspecto.values.map((modo) {
                final esSeleccionado = modo == aspectoActual;
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  decoration: BoxDecoration(
                    color: esSeleccionado
                        ? ColoresApp.acentoPrimario.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      esSeleccionado
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: esSeleccionado
                          ? ColoresApp.acentoPrimario
                          : ColoresApp.textoSecundario,
                      size: 20,
                    ),
                    title: Text(
                      modo.etiqueta,
                      style: TextStyle(
                        color: esSeleccionado
                            ? Colors.white
                            : ColoresApp.textoPrincipal,
                        fontWeight: esSeleccionado
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      alSeleccionarAspecto(modo);
                      Navigator.of(context).pop();
                    },
                  ),
                );
              }),
              const SizedBox(height: 10),
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
      ),
    );
  }
}
