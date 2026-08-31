import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'constantes/temas_app.dart';
import 'pantallas/pantalla_principal.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

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
      home: const PantallaPrincipal(),
    );
  }
}
