import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// All colours live here as tokens.
class Tokens {
  static const background = Color(0xFF0A0A14);
  static const surface = Color(0xFF13131F);
  static const border = Color(0xFF24243A);
  static const text = Color(0xFFFFFFFF);
  static const muted = Color(0xFF9A9AB5);
  static const primary = Color(0xFF7C5CFF);
  static const accent = Color(0xFFFF5CA8);
  static const gold = Color(0xFFFFC94D); // Premium only
  static const success = Color(0xFF35D07F);
  static const warning = Color(0xFFFFB020);
  static const danger = Color(0xFFFF4D5E);
  static const gradient = LinearGradient(colors: [Color(0xFF6A5CFF), Color(0xFF9B5CFF), Color(0xFFFF5CA8)]);
}

/// Poppins has tall line metrics; a fixed, tighter line height removes the loose gaps.
TextTheme _tight(TextTheme t) {
  TextStyle? h(TextStyle? s) => s?.copyWith(height: 1.3);
  return t.copyWith(
    headlineLarge: h(t.headlineLarge), headlineMedium: h(t.headlineMedium), headlineSmall: h(t.headlineSmall),
    titleLarge: h(t.titleLarge), titleMedium: h(t.titleMedium), titleSmall: h(t.titleSmall),
    bodyLarge: h(t.bodyLarge), bodyMedium: h(t.bodyMedium), bodySmall: h(t.bodySmall),
    labelLarge: h(t.labelLarge), labelMedium: h(t.labelMedium), labelSmall: h(t.labelSmall),
  );
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Tokens.background,
    colorScheme: const ColorScheme.dark(
      primary: Tokens.primary,
      secondary: Tokens.accent,
      surface: Tokens.surface,
      surfaceContainerHigh: Tokens.surface,
      error: Tokens.danger,
    ),
    textTheme: _tight(GoogleFonts.poppinsTextTheme(base.textTheme).apply(bodyColor: Tokens.text, displayColor: Tokens.text)),
    listTileTheme: const ListTileThemeData(dense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12), minVerticalPadding: 4, horizontalTitleGap: 12),
    dividerTheme: const DividerThemeData(color: Tokens.border, space: 1, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1E1E30),
      contentTextStyle: GoogleFonts.poppins(color: Tokens.text, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Tokens.border)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Tokens.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Tokens.primary,
      foregroundColor: Colors.white,
      elevation: 2,
      highlightElevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      extendedTextStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Tokens.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Tokens.text,
        side: const BorderSide(color: Tokens.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Tokens.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Tokens.primary, linearTrackColor: Tokens.border, linearMinHeight: 4),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? Colors.white : Tokens.muted),
      trackColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? Tokens.primary : Tokens.border),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    cardTheme: CardTheme(
      margin: EdgeInsets.zero,
      color: Tokens.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Tokens.border)),
    ),
    appBarTheme: const AppBarTheme(backgroundColor: Tokens.background, elevation: 0, scrolledUnderElevation: 0, centerTitle: false, titleSpacing: 0, toolbarHeight: 52, titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Tokens.text)),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: Tokens.surface, indicatorColor: Tokens.primary),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0F0F1A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: const TextStyle(color: Tokens.muted, fontSize: 14),
      floatingLabelStyle: const TextStyle(color: Tokens.primary, fontSize: 14),
      hintStyle: const TextStyle(color: Tokens.muted, fontSize: 14),
      helperStyle: const TextStyle(color: Tokens.muted, fontSize: 12),
      counterStyle: const TextStyle(color: Tokens.muted, fontSize: 11),
      prefixIconColor: Tokens.muted,
      suffixIconColor: Tokens.muted,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Tokens.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Tokens.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Tokens.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Tokens.danger)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Tokens.danger, width: 1.5)),
    ),
  );
}

class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onPressed == null ? .5 : 1,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(gradient: Tokens.gradient, borderRadius: BorderRadius.circular(14)),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                child: Center(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
              ),
            ),
          ),
        ),
      );
}
