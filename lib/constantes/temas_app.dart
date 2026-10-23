import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colores_app.dart';

/// Configuración de temas visuales en español para el Reproductor MP4.
class TemasApp {
  static ThemeData get temaOscuroCine {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ColoresApp.fondoPrincipal,
      primaryColor: ColoresApp.acentoPrimario,
      colorScheme: const ColorScheme.dark(
        primary: ColoresApp.acentoPrimario,
        secondary: ColoresApp.acentoSecundario,
        surface: ColoresApp.fondoSecundario,
        onSurface: ColoresApp.textoPrincipal,
        onPrimary: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ColoresApp.fondoSecundario,
        foregroundColor: ColoresApp.textoPrincipal,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: ColoresApp.fondoPrincipal,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          color: ColoresApp.textoPrincipal,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: ColoresApp.fondoTarjeta,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ColoresApp.fondoSecundario,
        indicatorColor: ColoresApp.acentoPrimario.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
              color: ColoresApp.acentoPrimario,
              size: 26,
            );
          }
          return const IconThemeData(
            color: ColoresApp.textoSecundario,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: ColoresApp.acentoPrimario,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            );
          }
          return const TextStyle(
            color: ColoresApp.textoSecundario,
            fontWeight: FontWeight.normal,
            fontSize: 12,
          );
        }),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: ColoresApp.acentoPrimario,
        inactiveTrackColor: ColoresApp.barraFondo,
        thumbColor: ColoresApp.acentoPrimario,
        overlayColor: Color(0x33E50914),
        trackHeight: 4,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ColoresApp.fondoSecundario,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
          color: ColoresApp.textoPrincipal,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
