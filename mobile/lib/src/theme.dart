import 'package:flutter/material.dart';

/// HomeLife OS brand tokens (logo colors) with accessible action tones.
const brandCoral = Color(0xFFFF6548);
const brandTeal = Color(0xFF18BFAE);
const brandYellow = Color(0xFFFFC83D);
const brandIvory = Color(0xFFFFF8ED);
const brandNavy = Color(0xFF17324D);

/// Soft surfaces used in prototype-style cards.
const brandMist = Color(0xFFE8F6F3);
const brandPeach = Color(0xFFFFE9E2);
const brandCream = Color(0xFFF7F5F0);
const brandSage = Color(0xFFE8EFE6);

/// Darker action tones that keep white text above WCAG AA.
const brandCoralDeep = Color(0xFFC23D2A);
const brandTealDeep = Color(0xFF0E8A7C);
const brandInk = Color(0xFF17324D);
const brandMuted = Color(0xFF4A5C66);

ThemeData buildFamilyTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: dark ? const Color(0xFF28D7C3) : brandTealDeep,
    onPrimary: dark ? brandNavy : Colors.white,
    secondary: dark ? const Color(0xFFFF765B) : brandCoralDeep,
    onSecondary: Colors.white,
    tertiary: dark ? const Color(0xFFFFD15C) : brandYellow,
    onTertiary: brandNavy,
    error: const Color(0xFFBA1A1A),
    onError: Colors.white,
    surface: dark ? const Color(0xFF14283A) : Colors.white,
    onSurface: dark ? const Color(0xFFF7FAFC) : brandInk,
    surfaceContainerHighest: dark ? const Color(0xFF203A4E) : brandSage,
    onSurfaceVariant: dark ? const Color(0xFFC7D5DD) : brandMuted,
    outline: dark ? const Color(0xFF496477) : const Color(0xFFDDE7E3),
    outlineVariant: dark ? const Color(0xFF29465A) : const Color(0xFFE8EEEB),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: dark ? brandIvory : brandNavy,
    onInverseSurface: dark ? brandNavy : brandIvory,
    inversePrimary: brandTeal,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'NotoSansSC',
  );
  final textTheme = base.textTheme.copyWith(
    displaySmall: base.textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w800,
      height: 1.15,
      color: scheme.onSurface,
    ),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      height: 1.2,
      color: scheme.onSurface,
    ),
    headlineSmall: base.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      color: scheme.onSurface,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    ),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(
      height: 1.5,
      color: scheme.onSurface,
    ),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(
      height: 1.45,
      color: scheme.onSurfaceVariant,
    ),
    bodySmall: base.textTheme.bodySmall?.copyWith(
      height: 1.4,
      color: scheme.onSurfaceVariant,
    ),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: dark ? const Color(0xFF0E1D2A) : brandIvory,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      titleTextStyle: textTheme.headlineSmall,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: dark ? const Color(0xFF14283A) : Colors.white,
      indicatorColor: dark ? brandTeal.withValues(alpha: 0.22) : brandMist,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          color: states.contains(WidgetState.selected)
              ? (dark ? scheme.primary : brandTealDeep)
              : scheme.onSurfaceVariant,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? (dark ? scheme.primary : brandTealDeep)
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? scheme.surfaceContainerHighest : brandCream,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: brandTealDeep, width: 1.4),
      ),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: dark ? const Color(0xFFFF765B) : brandCoralDeep,
        foregroundColor: dark ? brandNavy : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        minimumSize: const Size.fromHeight(52),
        backgroundColor: dark ? const Color(0xFFFF765B) : brandCoralDeep,
        foregroundColor: dark ? brandNavy : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: dark ? const Color(0xFFFF765B) : brandCoralDeep,
      foregroundColor: dark ? brandNavy : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      side: BorderSide.none,
      backgroundColor: dark ? scheme.surfaceContainerHighest : brandSage,
      selectedColor: dark ? scheme.primary.withValues(alpha: 0.24) : brandMist,
      labelStyle: TextStyle(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: brandInk,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
