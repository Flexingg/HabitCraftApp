import 'package:flutter/material.dart';

/// Blocky, Minecraft-inspired dark theme.
/// Emerald = "XP green", stone/gravel greys, classic dirt-browns for accents.
class HabitTheme {
  static const emerald = Color(0xFF22C55E); // reward/XP green
  static const emeraldBright = Color(0xFF6EE7B7);
  static const stone = Color(0xFF3F3F3F); // deep gravel
  static const stoneLight = Color(0xFF6B7280);
  static const dirt = Color(0xFF8B5A2B); // terracotta/dirt
  static const coal = Color(0xFF17191C);
  static const panel = Color(0xFF23272B);
  static const gold = Color(0xFFFACC15); // coin
  static const diamond = Color(0xFF4FC3F7);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: emerald,
      brightness: Brightness.dark,
      primary: emerald,
      surface: panel,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: coal,
      canvasColor: coal,
      splashFactory: InkRipple.splashFactory,
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(color: Color(0xFFD1D5DB)),
        bodySmall: TextStyle(color: stoneLight),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: panel,
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4), // boxy = pixel-y
          side: const BorderSide(color: Color(0xFF3A3F45)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: panel,
        selectedItemColor: emeraldBright,
        unselectedItemColor: stoneLight,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2E33),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFF4B5563)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFF4B5563)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: emerald, width: 2),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: emerald),
      chipTheme: const ChipThemeData(backgroundColor: Color(0xFF2A2E33), side: BorderSide(color: Color(0xFF4B5563))),
      dividerTheme: const DividerThemeData(color: Color(0xFF3A3F45), thickness: 1),
    );
  }
}
