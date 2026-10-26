import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../constantes/colores_app.dart';
import 'gestor_pip_global.dart';

/// Mini-reproductor flotante in-app tipo YouTube para reproductormp4.
/// Muestra video nativo 16:9, título, botones de control y barra de progreso inferior
/// a 144 FPS con aislamiento en RepaintBoundary y cero interferencia con la navegación.
class MiniReproductorFlotante extends StatelessWidget {
  const MiniReproductorFlotante({super.key});

  @override
  Widget build(BuildContext context) {
    final gestor = GestorPipGlobal.instancia;

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: ColoresApp.fondoTarjeta,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 14,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Cuerpo interactivo de la tarjeta flotante
                InkWell(
                  onTap: () => gestor.expandir(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Row(
                      children: [
                        // 1. LIENZO DE VIDEO EN VIVO 16:9
                        if (gestor.controladorVideo != null)
                          RepaintBoundary(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Container(
                                  color: Colors.black,
                                  child: Video(
                                    controller: gestor.controladorVideo!,
                                    fit: BoxFit.cover,
                                    controls: NoVideoControls,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Container(
                                color: Colors.black,
                                child: const Icon(
                                  Icons.movie_rounded,
                                  color: Colors.white38,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(width: 10),

                        // 2. TÍTULO DEL VIDEO (ELIPSIS A 1 LÍNEA)
                        Expanded(
                          child: ValueListenableBuilder<String>(
                            valueListenable: gestor.tituloVideo,
                            builder: (context, titulo, _) {
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    titulo.isEmpty ? 'Reproduciendo video' : titulo,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: ColoresApp.textoPrincipal,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Toca para expandir',
                                    style: TextStyle(
                                      color: ColoresApp.textoAtenuado,
                                      fontSize: 11,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),

                        // 3. BOTÓN PLAY / PAUSE
                        ValueListenableBuilder<bool>(
                          valueListenable: gestor.estaReproduciendo,
                          builder: (context, reproduciendo, _) {
                            return IconButton(
                              icon: Icon(
                                reproduciendo
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              tooltip: reproduciendo ? 'Pausar' : 'Reproducir',
                              onPressed: gestor.alternarPlayPause,
                            );
                          },
                        ),

                        const SizedBox(width: 4),

                        // 4. BOTÓN CERRAR MINI-REPRODUCTOR
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          tooltip: 'Cerrar reproductor',
                          onPressed: gestor.cerrar,
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),

                // 5. BARRA DE PROGRESO INFERIOR ULTRA-DELGADA ESTILO YOUTUBE
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ValueListenableBuilder<double>(
                    valueListenable: gestor.ratioProgreso,
                    builder: (context, ratio, _) {
                      return LinearProgressIndicator(
                        value: ratio,
                        minHeight: 2.2,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          ColoresApp.acentoPrimario,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
