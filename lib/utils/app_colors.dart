import 'package:flutter/material.dart';

/// Token warna dari design.md §3. Pakai token ini, jangan hardcode Color.
/// Warna semantik selalu bersama teks dan ikon, [ready] hanya bila pemeriksaan lolos.
abstract final class AppColors {
  // Latar, permukaan, dan tombol utama.
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF171717);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF3F3F3);

  // Teks, garis, dan fokus.
  static const Color textPrimary = Color(0xFF171717);
  static const Color textSecondary = Color(0xFF595959);
  static const Color divider = Color(0xFFD6D6D6);
  static const Color ruleStrong = Color(0xFF171717);
  static const Color inputBorder = Color(0xFF737373);
  static const Color focusLink = Color(0xFF234A78);

  // Status siap, peringatan, dan bahaya.
  static const Color ready = Color(0xFF216E4E);
  static const Color readySoft = Color(0xFFEDF7F1);
  static const Color warning = Color(0xFF8A4B08);
  static const Color warningSoft = Color(0xFFFFF4DF);
  static const Color danger = Color(0xFFB42318);
  static const Color dangerSoft = Color(0xFFFEF3F2);

  // Scrim hitam 60% untuk lapisan pengunci soal.
  static const Color scrim = Color(0x99000000);

  // Skema Material dari token di atas.
  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    secondary: focusLink,
    onSecondary: onPrimary,
    error: danger,
    onError: onPrimary,
    surface: surface,
    onSurface: textPrimary,
    surfaceContainerLowest: background,
    surfaceContainerLow: surfaceSubtle,
    outline: inputBorder,
    outlineVariant: divider,
  );
}
