import 'package:flutter/material.dart';

/// Warna tema Kosku: dusty pink lembut di atas dasar cream hangat.
abstract final class WarnaKosku {
  /// Pink debu utama (tombol, aksen).
  static const primary = Color(0xFFB26676);

  /// Cream hangat, warna dasar layar.
  static const krem = Color(0xFFFDF6EF);

  /// Cream lebih terang untuk kartu.
  static const permukaan = Color(0xFFFFFBF7);

  /// Tinta cokelat hangat (teks utama).
  static const tinta = Color(0xFF38292C);

  /// Pink container untuk lingkaran brand.
  static const pinkLembut = Color(0xFFFFD9E0);
}

/// Tema M3 dusty pink + cream: hanya keluarga pink dan cream,
/// tanpa hijau atau warna lain di seluruh aplikasi.
ThemeData buildTemaKosku() {
  const cs = ColorScheme.light(
    primary: Color(0xFFB26676),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFFD9E0),
    onPrimaryContainer: Color(0xFF55202C),
    secondary: Color(0xFF9E7C86),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFF7E4E6),
    onSecondaryContainer: Color(0xFF452A31),
    // Tertiary dipakai untuk status "ok/positif": tetap keluarga pink,
    // bukan hijau.
    tertiary: Color(0xFFB5808D),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFF7DFE6),
    onTertiaryContainer: Color(0xFF4E2A34),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF9DAD9),
    onErrorContainer: Color(0xFF410E0B),
    surface: Color(0xFFFFFBF7),
    onSurface: Color(0xFF38292C),
    onSurfaceVariant: Color(0xFF8A7074),
    outline: Color(0xFFC0A5A9),
    outlineVariant: Color(0xFFE8D8D6),
    inverseSurface: Color(0xFF38292C),
    onInverseSurface: Color(0xFFFFFBF7),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFFF5EF),
    surfaceContainer: Color(0xFFFCEFE9),
    surfaceContainerHigh: Color(0xFFF7E8E2),
    surfaceContainerHighest: Color(0xFFF2E2DC),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: WarnaKosku.krem,
    visualDensity: VisualDensity.comfortable,
    appBarTheme: AppBarTheme(
      backgroundColor: WarnaKosku.krem,
      surfaceTintColor: Colors.transparent,
      foregroundColor: cs.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: cs.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: WarnaKosku.permukaan,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: cs.inverseSurface,
      contentTextStyle: TextStyle(color: cs.onInverseSurface, fontSize: 13.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: DividerThemeData(color: cs.outlineVariant, thickness: 1),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
