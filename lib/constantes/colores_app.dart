import 'package:flutter/material.dart';

/// Paleta de colores cinemáticos oscuros para el Reproductor MP4.
class ColoresApp {
  // Fondos principales (Modo Cine Oscuro OLED)
  static const Color fondoPrincipal = Color(0xFF0D1117);
  static const Color fondoSecundario = Color(0xFF161B22);
  static const Color fondoTarjeta = Color(0xFF21262D);
  static const Color fondoReproductor = Color(0xFF000000);

  // Acentos y marcas
  static const Color acentoPrimario = Color(0xFFE50914); // Rojo Cine estilo Netflix/VLC
  static const Color acentoSecundario = Color(0xFFFF5252);
  static const Color acentoAmbar = Color(0xFFFFB300); // Ámbar para advertencias/tiempos
  static const Color acentoAzul = Color(0xFF2979FF); // Azul para brillo/indicadores

  // Textos
  static const Color textoPrincipal = Color(0xFFF0F6FC);
  static const Color textoSecundario = Color(0xFF8B949E);
  static const Color textoAtenuado = Color(0xFF484F58);

  // Estados de reproducción
  static const Color barraProgreso = Color(0xFFE50914);
  static const Color barraBuffer = Color(0x66FFFFFF);
  static const Color barraFondo = Color(0x33FFFFFF);

  // Superposiciones de controles (Glassmorphism & OSD)
  static const Color superposicionControles = Color(0x99000000);
  static const Color fondoOSD = Color(0xCC161B22);
  static const Color bordeOSD = Color(0x44FFFFFF);
}
