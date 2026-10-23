import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:media_kit/media_kit.dart';
import 'constantes/temas_app.dart';
import 'pantallas/pantalla_principal.dart';
import 'servicios/servicio_miniaturas_video.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Desbloqueo de la tasa de refresco máxima del hardware (144Hz / 120Hz)
  // en paneles compatibles para fluidez absoluta a 6.9ms por fotograma.
  if (Platform.isAndroid) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (_) {
      // Silencioso en emuladores o dispositivos sin soporte
    }
  }

  // Optimización de memoria RAM: acotar la caché de imágenes decodificadas de Flutter
  // para evitar picos de memoria (OOM) al navegar por listas extensas de videos.
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      40 * 1024 * 1024; // 40 MB
  PaintingBinding.instance.imageCache.maximumSize = 150;

  // Inicializar directorio de caché de miniaturas para acceso sincrónico ultrarrápido
  unawaited(ServicioMiniaturasVideo.inicializar());

  // Configuración de estilo de la barra de estado y navegación
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D1117),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const AplicacionReproductorMP4());
}

/// Widget raíz de la aplicación de reproducción de video.
class AplicacionReproductorMP4 extends StatelessWidget {
  const AplicacionReproductorMP4({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reproductor MP4',
      debugShowCheckedModeBanner: false,
      theme: TemasApp.temaOscuroCine,
      // Físicas de scroll elásticas con alta inercia para navegación fluida a 144Hz
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
      ),
      home: const PantallaPrincipal(),
    );
  }
}

