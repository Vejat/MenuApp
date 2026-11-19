import 'package:flutter/material.dart';

ThemeData nightTheme() {
  const background = Color(0xff171622);
  const surface = Color(0xff232030);
  const violet = Color(0xff352a49);
  const lime = Color(0xffd9fa77);
  const outline = Color(0xff4a405d);
  const ink = Color(0xfffaf7ff);
  const muted = Color(0xffcbbfda);
  const scheme = ColorScheme.dark(
    primary: lime,
    onPrimary: Color(0xff252816),
    primaryContainer: Color(0xff394421),
    onPrimaryContainer: lime,
    secondary: Color(0xffcdb6f8),
    onSecondary: background,
    secondaryContainer: violet,
    onSecondaryContainer: ink,
    surface: surface,
    onSurface: ink,
    onSurfaceVariant: muted,
    surfaceContainerLowest: background,
    surfaceContainerLow: surface,
    surfaceContainer: surface,
    surfaceContainerHigh: violet,
    outline: Color(0xff8e7ea6),
    outlineVariant: outline,
    error: Color(0xffffb4b4),
  );
  final data = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ink,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: outline),
      ),
      margin: const EdgeInsets.only(bottom: 10),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: const StadiumBorder(),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: outline),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: violet,
      height: 70,
    ),
  );
  return data.copyWith(
    textTheme: data.textTheme.copyWith(
      headlineMedium: data.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      titleLarge: data.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleMedium: data.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
