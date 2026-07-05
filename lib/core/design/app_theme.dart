import 'package:flutter/material.dart';

import 'cutter_colors.dart';
import 'tokens.dart';

/// Design system do Video Cutter.
///
/// Identidade: rosa framboesa como seed, tipografia Nunito (arredondada e
/// simpática), cantos generosos e componentes Material 3 configurados num
/// lugar só. As telas nunca definem cor/forma na mão — usam o tema, os
/// tokens ([AppSpacing], [AppRadii], [AppMotion]) e a extensão
/// [CutterColors].
abstract final class AppTheme {
  static const _seed = Color(0xFFE2557B);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
      // Mantém o rosa vivo do seed em vez do tom lavado do algoritmo padrão.
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );

    final base = ThemeData(
      colorScheme: scheme,
      fontFamily: 'Nunito',
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF1A111A) : const Color(0xFFFFF5F8),
    );

    final textTheme = base.textTheme.copyWith(
      headlineMedium:
          base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      titleLarge:
          base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      titleMedium:
          base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      labelLarge:
          base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),
      extensions: [isDark ? CutterColors.dark : CutterColors.light],
    );
  }

  /// Botões de ação principal: mais altos, ocupam a largura do pai.
  static ButtonStyle get primaryAction => FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      );
}
