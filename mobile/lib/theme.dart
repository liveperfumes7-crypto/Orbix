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
      error: Tokens.danger,
    ),
    textTheme: _tight(GoogleFonts.poppinsTextTheme(base.textTheme).apply(bodyColor: Tokens.text, displayColor: Tokens.text)),
    listTileTheme: const ListTileThemeData(dense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12), minVerticalPadding: 4, horizontalTitleGap: 12),
    dividerTheme: const DividerThemeData(color: Tokens.border, space: 1, thickness: 1),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    cardTheme: CardTheme(
      margin: EdgeInsets.zero,
      color: Tokens.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Tokens.border)),
    ),
    appBarTheme: const AppBarTheme(backgroundColor: Tokens.background, elevation: 0, scrolledUnderElevation: 0, centerTitle: false, titleSpacing: 0, toolbarHeight: 52, titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Tokens.text)),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: Tokens.surface, indicatorColor: Tokens.primary),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Tokens.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Tokens.border)),
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
