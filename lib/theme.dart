import 'package:flutter/material.dart';

/// Material 3 theme tuned for the 4.7 accessibility baseline: ≥ 48 dp touch
/// targets, ≥ 4.5:1 contrast on text, visible focus, large text option.
class AppTheme {
  const AppTheme._();

  static const Color primary = Color(0xFF0B3C5D); // dark blue, 10.4:1 on white
  static const Color secondary = Color(0xFFB85C00); // dark amber, 5.0:1 on white
  static const Color success = Color(0xFF1B6B3A);
  static const Color danger = Color(0xFFB3261E);
  static const Color surfaceMuted = Color(0xFFF2F4F7);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      error: danger,
    );
    const minTarget = Size(48, 48);
    final focusBorder = BorderSide(color: scheme.primary, width: 3);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minTarget,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ).copyWith(side: _focusSide(focusBorder)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: minTarget,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          side: BorderSide(color: scheme.primary, width: 1.5),
        ).copyWith(side: _focusSide(focusBorder, fallback: BorderSide(color: scheme.primary, width: 1.5))),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: minTarget,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: minTarget),
      ),
      chipTheme: ChipThemeData(
        labelStyle: TextStyle(fontSize: 14, color: scheme.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        side: BorderSide(color: scheme.outline),
        selectedColor: scheme.primaryContainer,
        showCheckmark: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(borderSide: focusBorder),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.primary : scheme.surfaceContainerHighest,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16),
        bodyMedium: TextStyle(fontSize: 15),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  static WidgetStateProperty<BorderSide?> _focusSide(BorderSide focused,
      {BorderSide? fallback}) {
    return WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.focused) ? focused : fallback,
    );
  }
}
