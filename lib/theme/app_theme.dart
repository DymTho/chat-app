import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPageTransitionsBuilder;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_palette.dart';

/// Builds a complete Material 3 [ThemeData] from a palette and brightness.
class AppTheme {
  static ThemeData build(PaletteSpec spec, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final palette = AppPalette.resolve(spec, brightness);
    final background = dark ? spec.darkBackground : spec.lightBackground;
    final surface = dark ? spec.darkSurface : spec.lightSurface;
    final onSurface = dark ? const Color(0xFFF2F2F5) : const Color(0xFF1E1E22);

    final scheme = ColorScheme.fromSeed(
      seedColor: spec.primary,
      brightness: brightness,
    ).copyWith(
      primary: spec.primary,
      onPrimary: Colors.white,
      secondary: spec.secondary,
      onSecondary: dark ? Colors.black : Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest:
          dark ? Color.lerp(surface, Colors.white, 0.06) : const Color(0xFFF1F0F3),
      outlineVariant: dark ? const Color(0xFF34343B) : const Color(0xFFE9E7EC),
      error: const Color(0xFFE5484D),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      splashFactory: InkSparkle.splashFactory,
    );

    final text = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: onSurface,
      displayColor: onSurface,
    );

    final radius = BorderRadius.circular(18);

    return base.copyWith(
      textTheme: text,
      extensions: [palette],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: onSurface,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        systemOverlayStyle:
            dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF3F2F5),
        hintStyle: TextStyle(color: palette.muted, fontSize: 14),
        labelStyle: TextStyle(color: palette.muted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        enabledBorder:
            OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: spec.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: spec.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: spec.primary,
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: spec.primary.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: spec.primary,
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface,
        selectedColor: spec.primary,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: GoogleFonts.poppins(fontSize: 13, color: onSurface),
        secondaryLabelStyle:
            GoogleFonts.poppins(fontSize: 13, color: Colors.white),
        showCheckmark: false,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: palette.muted.withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.header,
        contentTextStyle: GoogleFonts.poppins(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? spec.primary : null,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
