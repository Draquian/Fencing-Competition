import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta "Escrime Precision" (DESIGN.md)
class AppColors {
  static const green = Color(0xFF124E3F); // Imperial Racing Green (primario)
  static const greenDark = Color(0xFF0F382C); // cabeceras / estado pulsado
  static const gold = Color(0xFFC59B27); // Champagne Gold (acentos, podio, semillas)
  static const goldLight = Color(0xFFD4AF37); // tipografía dorada sobre verde oscuro
  static const goldDeep = Color(0xFF9E7B1A); // texto dorado sobre claro
  static const goldWash = Color(0xFFF9F4E8); // fondo de insignias de semilla
  static const mint = Color(0xFFE8F2EC); // verde menta (seleccionado, éxito)
  static const sage = Color(0xFF7CA982);
  static const ink = Color(0xFF1C2421); // negro bosque (texto)
  static const canvas = Color(0xFFF8FAF8); // fondo alabastro
  static const garnet = Color(0xFFA63A3A); // avisos / errores
  static const hair = Color(0x14124E3F); // borde fino 8 %
  static const hairStrong = Color(0x29124E3F); // borde 16 %
  static const input = Color(0x1F124E3F); // borde de campos 12 %
  static const divider = Color(0xFFEEF2EE);
  static const muted = Color(0xFF707975);
}

const tabular = [FontFeature.tabularFigures()];

final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.hair));
final dialogShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
final _r8 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));

/// Marcador grande (numeric-score)
const numericScore = TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w700,
    height: 48 / 44,
    letterSpacing: -1.76,
    fontFeatures: tabular,
    color: AppColors.green);

InputDecoration deco({String? label, String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: AppColors.canvas,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.input)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.input)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.green, width: 2)),
    );

/// Cabecera verde oscuro con tipografía dorada (Piste Status Header)
PreferredSizeWidget appBar(String title, {List<Widget>? actions, PreferredSizeWidget? bottom}) => AppBar(
      backgroundColor: AppColors.greenDark,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text(title, style: const TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      actions: actions,
      bottom: bottom,
    );

ThemeData buildTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.green,
    onPrimary: Colors.white,
    primaryContainer: AppColors.mint,
    onPrimaryContainer: AppColors.green,
    secondary: AppColors.gold,
    onSecondary: AppColors.ink,
    secondaryContainer: AppColors.mint,
    onSecondaryContainer: AppColors.green,
    tertiary: AppColors.sage,
    onTertiary: Colors.white,
    error: AppColors.garnet,
    onError: Colors.white,
    surface: AppColors.canvas,
    onSurface: AppColors.ink,
    onSurfaceVariant: Color(0xFF404945),
    outline: AppColors.muted,
    outlineVariant: Color(0xFFBFC9C3),
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: AppColors.canvas);
  final t = GoogleFonts.spaceGroteskTextTheme(base.textTheme).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
  TextStyle s(TextStyle? b, double size, FontWeight w, {double ls = 0, double? h}) =>
      b!.copyWith(fontSize: size, fontWeight: w, letterSpacing: ls, height: h == null ? null : h / size);
  final tt = t.copyWith(
    displayLarge: s(t.displayLarge, 48, FontWeight.w700, ls: -1.44, h: 56),
    headlineLarge: s(t.headlineLarge, 32, FontWeight.w600, ls: -0.64, h: 40),
    headlineMedium: s(t.headlineMedium, 24, FontWeight.w600, ls: -0.24, h: 32),
    headlineSmall: s(t.headlineSmall, 20, FontWeight.w600, h: 28),
    titleLarge: s(t.titleLarge, 20, FontWeight.w600, h: 28),
    titleMedium: s(t.titleMedium, 16, FontWeight.w600, h: 24),
    titleSmall: s(t.titleSmall, 14, FontWeight.w600, h: 20),
    bodyLarge: s(t.bodyLarge, 16, FontWeight.w400, h: 24),
    bodyMedium: s(t.bodyMedium, 14, FontWeight.w400, h: 20),
    bodySmall: s(t.bodySmall, 12, FontWeight.w400, h: 16),
    labelLarge: s(t.labelLarge, 14, FontWeight.w600, ls: 0.28, h: 20),
    labelMedium: s(t.labelMedium, 12, FontWeight.w600, ls: 0.48, h: 16),
    labelSmall: s(t.labelSmall, 10, FontWeight.w700, ls: 0.6, h: 14),
  );
  return base.copyWith(
    textTheme: tt,
    primaryTextTheme: tt,
    dividerTheme: const DividerThemeData(color: AppColors.divider, space: 1, thickness: 1),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: _r8, textStyle: tt.labelLarge)),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.green, side: const BorderSide(color: AppColors.green), shape: _r8, textStyle: tt.labelLarge)),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.green, shape: _r8, textStyle: tt.labelLarge)),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: AppColors.mint,
      checkmarkColor: AppColors.green,
      side: const BorderSide(color: AppColors.hairStrong),
      shape: _r8,
      labelStyle: tt.labelLarge?.copyWith(color: AppColors.ink),
    ),
  );
}
