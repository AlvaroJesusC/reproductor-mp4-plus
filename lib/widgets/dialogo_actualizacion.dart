import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import '../constantes/colores_app.dart';
import '../modelos/modelo_info_actualizacion.dart';

/// Diálogo cinemático para mostrar las novedades de una versión y descargar/instalar el APK.
class DialogoActualizacion extends StatefulWidget {
  final ModeloInfoActualizacion info;

  const DialogoActualizacion({
    super.key,
    required this.info,
  });

  /// Método helper estático para mostrar el diálogo.
  static Future<void> mostrar(
    BuildContext context, {
    required ModeloInfoActualizacion info,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoActualizacion(info: info),
    );
  }

  @override
  State<DialogoActualizacion> createState() => _DialogoActualizacionState();
}

class _DialogoActualizacionState extends State<DialogoActualizacion> {
  StreamSubscription<OtaEvent>? _subscripcion;
  bool _descargando = false;
  double _progreso = 0.0;
  String _estadoMensaje = '';
  String? _errorMensaje;

  @override
  void dispose() {
    _subscripcion?.cancel();
    super.dispose();
  }

  void _iniciarActualizacion() {
    setState(() {
      _descargando = true;
      _errorMensaje = null;
      _progreso = 0.0;
      _estadoMensaje = 'Conectando con el servidor...';
    });

    try {
      _subscripcion = OtaUpdate()
          .execute(
            widget.info.urlDescargaApk,
            destinationFilename: widget.info.nombreArchivo,
          )
          .listen(
            (OtaEvent event) {
              if (!mounted) return;

              switch (event.status) {
                case OtaStatus.DOWNLOADING:
                  final porcentaje = double.tryParse(event.value ?? '0') ?? 0.0;
                  setState(() {
                    _progreso = (porcentaje / 100.0).clamp(0.0, 1.0);
                    _estadoMensaje = 'Descargando actualización: ${porcentaje.toInt()}%';
                  });
                  break;

                case OtaStatus.INSTALLING:
                  setState(() {
                    _progreso = 1.0;
                    _estadoMensaje = 'Abriendo instalador del sistema...';
                  });
                  break;

                case OtaStatus.INSTALLATION_DONE:
                  setState(() {
                    _progreso = 1.0;
                    _estadoMensaje = 'Instalación finalizada.';
                  });
                  break;

                case OtaStatus.INSTALLATION_ERROR:
                  setState(() {
                    _descargando = false;
                    _errorMensaje =
                        'No se pudo completar la instalación. Verifica que el APK sea compatible.';
                  });
                  break;

                case OtaStatus.CANCELED:
                  setState(() {
                    _descargando = false;
                    _estadoMensaje = 'Descarga cancelada.';
                  });
                  break;

                case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                  setState(() {
                    _descargando = false;
                    _errorMensaje =
                        'Permiso denegado para instalar paquetes desconocidos. Actívalo en Ajustes de Android.';
                  });
                  break;

                case OtaStatus.DOWNLOAD_ERROR:
                  setState(() {
                    _descargando = false;
                    _errorMensaje =
                        'Error de red al descargar el APK. Verifica tu conexión a internet.';
                  });
                  break;

                case OtaStatus.INTERNAL_ERROR:
                  setState(() {
                    _descargando = false;
                    _errorMensaje =
                        'Error interno del instalador de Android: ${event.value ?? ""}';
                  });
                  break;

                case OtaStatus.ALREADY_RUNNING_ERROR:
                  setState(() {
                    _estadoMensaje = 'La descarga ya está en progreso...';
                  });
                  break;

                case OtaStatus.CHECKSUM_ERROR:
                  setState(() {
                    _descargando = false;
                    _errorMensaje = 'Error de integridad en el archivo descargado.';
                  });
                  break;
              }
            },
            onError: (dynamic error) {
              if (!mounted) return;
              setState(() {
                _descargando = false;
                _errorMensaje = 'No se pudo completar la actualización: $error';
              });
            },
          );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _descargando = false;
        _errorMensaje = 'Excepción al iniciar la descarga: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tamanoStr = widget.info.tamanoLegible;

    return Dialog(
      backgroundColor: ColoresApp.fondoTarjeta,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: ColoresApp.bordeSutil, width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera con icono distintivo y versión
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ColoresApp.acentoPrimario.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: ColoresApp.acentoPrimario,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nueva versión disponible',
                        style: TextStyle(
                          color: ColoresApp.textoPrincipal,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'v${widget.info.versionActual}  ➜  v${widget.info.versionRemota}${tamanoStr.isNotEmpty ? " ($tamanoStr)" : ""}',
                        style: const TextStyle(
                          color: ColoresApp.textoSecundario,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Contenedor de notas de la versión (Changelog)
            const Text(
              'Novedades y cambios:',
              style: TextStyle(
                color: ColoresApp.textoSecundario,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ColoresApp.fondoSecundario,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColoresApp.bordeSutil),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  widget.info.notasCambios,
                  style: const TextStyle(
                    color: ColoresApp.textoPrincipal,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Barra de progreso y estados durante la descarga
            if (_descargando) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progreso > 0 ? _progreso : null,
                  backgroundColor: ColoresApp.fondoSecundario,
                  color: ColoresApp.acentoPrimario,
                  minHeight: 7,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _estadoMensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ColoresApp.textoSecundario,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Mensaje de error si ocurre alguno
            if (_errorMensaje != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMensaje!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!_descargando)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: ColoresApp.textoSecundario,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('Más tarde'),
                  ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _descargando ? null : _iniciarActualizacion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColoresApp.acentoPrimario,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: ColoresApp.acentoPrimario.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: _descargando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    _descargando
                        ? 'Descargando...'
                        : (_errorMensaje != null ? 'Reintentar' : 'Actualizar ahora'),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
