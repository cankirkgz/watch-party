import 'package:flutter/material.dart';

abstract final class PartyColors {
  static const paper = Color(0xFFF5F2EB);
  static const ink = Color(0xFF202823);
  static const orange = Color(0xFFE15A36);
  static const muted = Color(0xFF72796F);
  static const line = Color(0xFFDFE1D7);
  static const night = Color(0xFF151D19);
  static const panel = Color(0xFF212B25);
  static const lime = Color(0xFFD9E7A5);
}

abstract final class PartyTheme {
  static ThemeData get light => _theme(Brightness.light);
  static ThemeData get dark => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors = ColorScheme.fromSeed(
      seedColor: PartyColors.orange,
      brightness: brightness,
      primary: dark ? PartyColors.lime : PartyColors.ink,
      onPrimary: dark ? PartyColors.ink : Colors.white,
      secondary: PartyColors.orange,
      surface: dark ? PartyColors.night : PartyColors.paper,
      onSurface: dark ? PartyColors.paper : PartyColors.ink,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Manrope',
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? PartyColors.panel : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        hintStyle: TextStyle(
            color: dark ? Colors.white38 : PartyColors.muted, fontSize: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide:
                BorderSide(color: dark ? Colors.white10 : PartyColors.line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide:
                const BorderSide(color: PartyColors.orange, width: 1.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        minimumSize: const Size(48, 54),
        textStyle: const TextStyle(
            fontFamily: 'Manrope', fontSize: 15, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 54),
        side: BorderSide(color: dark ? Colors.white24 : PartyColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      )),
      bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: colors.surface, showDragHandle: true),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: dark ? PartyColors.lime : PartyColors.ink,
          contentTextStyle: TextStyle(
              color: dark ? PartyColors.ink : PartyColors.paper,
              fontFamily: 'Manrope')),
      dividerTheme: DividerThemeData(
          color: dark ? Colors.white10 : PartyColors.line, thickness: 1),
    );
  }
}
