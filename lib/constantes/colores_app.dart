import 'package:flutter/material.dart';

/// Paleta de colores cinemáticos oscuros (OLED Obsidian Studio) para el Reproductor MP4.
class ColoresApp {
  // Fondos principales (Modo Cine Oscuro OLED Obsidian)
  static const Color fondoPrincipal = Color(0xFF0A0D14);
  static const Color fondoSecundario = Color(0xFF121622);
  static const Color fondoTarjeta = Color(0xFF181E2B);
  static const Color fondoReproductor = Color(0xFF000000);

  // Acentos y marcas
  static const Color acentoPrimario = Color(
    0xFFFF2A54,
  ); // Carmesí cinemático vibrante
  static const Color acentoSecundario = Color(0xFFFF5252);
  static const Color acentoAmbar = Color(
    0xFFF59E0B,
  ); // Ámbar dorado cálido para barras de progreso y tiempo
  static const Color acentoAzul = Color(
    0xFF2979FF,
  ); // Azul para brillo/indicadores
  static const Color acentoVerde = Color(
    0xFF10B981,
  ); // Verde esmeralda moderno para completados

  // Textos
  static const Color textoPrincipal = Color(0xFFF8FAFC); // Blanco slate nítido
  static const Color textoSecundario = Color(
    0xFF94A3B8,
  ); // Gris pizarra refinado
  static const Color textoAtenuado = Color(
    0xFF64748B,
  ); // Atenuado para badges y metadatos

  // Estados de reproducción
  static const Color barraProgreso = Color(0xFFFF2A54);
  static const Color barraBuffer = Color(0x66FFFFFF);
  static const Color barraFondo = Color(0x33FFFFFF);

  // Superposiciones de controles (Glassmorphism & OSD)
  static const Color superposicionControles = Color(0x99000000);
  static const Color fondoOSD = Color(0xCC121622);
  static const Color bordeOSD = Color(0x44FFFFFF);

  // Acabado cinemático premium
  static const Color bordeSutil = Color(
    0x1AFFFFFF,
  ); // Micro-borde translúcido (10% blanco)
  static const Color fondoPastillaTiempo = Color(
    0xCC000000,
  ); // Pastilla oscura semitransparente sobre miniatura
}
