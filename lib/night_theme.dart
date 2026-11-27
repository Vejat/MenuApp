import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colores de estado que cambian con el modo (Noche / Día).
extension StatusColors on ColorScheme {
  bool get _dark => brightness == Brightness.dark;
  Color get warning =>
      _dark ? const Color(0xffffce8b) : const Color(0xff8a5300);
  Color get success =>
      _dark ? const Color(0xffa6e6c0) : const Color(0xff1f7a4d);
  Color get preparing =>
      _dark ? const Color(0xffcdb6f8) : const Color(0xff2b4bb8);
  Color get occupied =>
      _dark ? const Color(0xff9cc3ff) : const Color(0xff5b3fa0);

  /// Precios y totales: lima de noche, tinta de día.
  Color get price => _dark ? primary : onSurface;
}

/// Noche (paleta A) y Día (paleta B) comparten formas y tamaños.
ThemeData appTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final background = dark ? const Color(0xff171622) : const Color(0xfff3f4f6);
  final surface = dark ? const Color(0xff232030) : Colors.white;
  final tonal = dark ? const Color(0xff352a49) : const Color(0xfffce9e5);
  final outline = dark ? const Color(0xff4a405d) : const Color(0xffe3e5ea);
  final ink = dark ? const Color(0xfffaf7ff) : const Color(0xff17191e);
  final muted = dark ? const Color(0xffcbbfda) : const Color(0xff5d6470);
  final scheme = dark
      ? ColorScheme.dark(
          primary: const Color(0xffd9fa77),
          onPrimary: const Color(0xff252816),
          primaryContainer: const Color(0xff394421),
          onPrimaryContainer: const Color(0xffd9fa77),
          secondary: const Color(0xffcdb6f8),
          onSecondary: background,
          secondaryContainer: tonal,
          onSecondaryContainer: ink,
          surface: surface,
          onSurface: ink,
          onSurfaceVariant: muted,
          surfaceContainerLowest: background,
          surfaceContainerLow: surface,
          surfaceContainer: surface,
          surfaceContainerHigh: const Color(0xff2a2638),
          outline: const Color(0xff8e7ea6),
          outlineVariant: outline,
          error: const Color(0xffffb4b4),
        )
      : ColorScheme.light(
          primary: const Color(0xffd8432a),
          onPrimary: Colors.white,
          primaryContainer: tonal,
          onPrimaryContainer: const Color(0xffc23a22),
          secondary: const Color(0xff5b3fa0),
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xffefeafb),
          onSecondaryContainer: ink,
          surface: surface,
          onSurface: ink,
          onSurfaceVariant: muted,
          surfaceContainerLowest: background,
          surfaceContainerLow: surface,
          surfaceContainer: surface,
          surfaceContainerHigh: Colors.white,
          outline: const Color(0xff8a909c),
          outlineVariant: outline,
          error: const Color(0xffa3221a),
        );
  final data = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: GoogleFonts.manrope().fontFamily,
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: ink,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: dark ? 0 : 1,
      shadowColor: const Color(0x2214161e),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 10),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(40, 40),
        foregroundColor: dark ? scheme.primary : scheme.onPrimaryContainer,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: tonal,
      height: 64,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      iconColor: scheme.secondary,
      subtitleTextStyle: TextStyle(color: muted, fontSize: 13, height: 1.35),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      shape: const RoundedRectangleBorder(),
      collapsedShape: const RoundedRectangleBorder(),
      iconColor: scheme.primary,
      collapsedIconColor: muted,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      dragHandleColor: muted,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
  return data.copyWith(
    textTheme: data.textTheme.copyWith(
      headlineMedium: data.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.12,
      ),
      titleLarge: GoogleFonts.manrope(textStyle: data.textTheme.titleLarge)
          .copyWith(fontWeight: FontWeight.w700),
      titleMedium: GoogleFonts.manrope(textStyle: data.textTheme.titleMedium)
          .copyWith(fontWeight: FontWeight.w600),
    ),
  );
}

class ScreenColumn extends StatelessWidget {
  const ScreenColumn({super.key, required this.child, this.width = 680});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.description});

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.headlineMedium),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(
              description!,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class StatusLabel extends StatelessWidget {
  const StatusLabel(this.label, {super.key, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    ),
  );
}
