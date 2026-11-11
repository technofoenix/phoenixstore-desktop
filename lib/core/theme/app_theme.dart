import 'package:flutter/material.dart';

import '../i18n/languages.dart';

/// PhoenixStore brand palette shared with the mobile app and backoffice.
/// Red is the only accent; everything else is warm neutral.
class AppColors {
  static const primary = Color(0xFFD32E2E);
  static const primaryHover = Color(0xFFB92525);
  static const primaryDeep = Color(0xFF8E1B1B);
  static const primarySoft = Color(0xFFFBE9E9);
  static const ink = Color(0xFF1C1414);
  static const inkMuted = Color(0xFF6B5F5C);
  static const paper = Color(0xFFF6F3F1);
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xFFF2EDEA);
  static const line = Color(0xFFE6DEDA);

  static const sidebar = Color(0xFF1E1616);
  static const sidebarText = Color(0xFFF3ECEA);
  static const sidebarMuted = Color(0xFFB3A6A3);
  static const sidebarHover = Color(0xFF2D2322);

  static const success = Color(0xFF1E7A46);
  static const successSoft = Color(0xFFE4F3EA);
  static const warning = Color(0xFF8F5300);
  static const warningSoft = Color(0xFFFCEFD9);
  static const danger = Color(0xFFB42318);
  static const dangerSoft = Color(0xFFFDECEA);
}

/// Spacing scale (4-point).
class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Radius scale: controls, cards, dialogs. Pills are fully round.
class Radii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const pill = 999.0;
}

/// Window widths where the layout changes.
class Breakpoints {
  static const wideSidebar = 1180.0;
  static const roomy = 1100.0;
}

class AppTheme {
  static ThemeData build(AppLanguage language) {
    final font = language.font;
    final fallback = AppLanguages.fallbackFonts(font);

    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          primaryContainer: AppColors.primarySoft,
          onPrimaryContainer: AppColors.primaryDeep,
          secondary: AppColors.ink,
          onSecondary: Colors.white,
          secondaryContainer: AppColors.surfaceMuted,
          onSecondaryContainer: AppColors.ink,
          surface: AppColors.surface,
          onSurface: AppColors.ink,
          onSurfaceVariant: AppColors.inkMuted,
          surfaceContainerLowest: AppColors.surface,
          surfaceContainerLow: AppColors.paper,
          surfaceContainer: AppColors.surfaceMuted,
          surfaceContainerHigh: AppColors.surfaceMuted,
          surfaceContainerHighest: AppColors.surfaceMuted,
          outline: const Color(0xFF9C8F8B),
          outlineVariant: AppColors.line,
          error: AppColors.danger,
          onError: Colors.white,
          errorContainer: AppColors.dangerSoft,
          onErrorContainer: AppColors.danger,
        );

    TextStyle style(
      double size,
      FontWeight weight, {
      double? height,
      Color? color,
    }) => TextStyle(
      fontFamily: font,
      fontFamilyFallback: fallback,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color ?? AppColors.ink,
      letterSpacing: language.rtl ? 0 : (size >= 20 ? -0.3 : 0),
    );

    // One type scale for the whole app.
    final text = TextTheme(
      displaySmall: style(30, FontWeight.w700, height: 1.15),
      headlineSmall: style(24, FontWeight.w700, height: 1.2),
      titleLarge: style(20, FontWeight.w700, height: 1.25),
      titleMedium: style(16, FontWeight.w600, height: 1.3),
      titleSmall: style(14, FontWeight.w600, height: 1.3),
      bodyLarge: style(15, FontWeight.w400, height: 1.45),
      bodyMedium: style(14, FontWeight.w400, height: 1.45),
      bodySmall: style(
        12.5,
        FontWeight.w400,
        height: 1.4,
        color: AppColors.inkMuted,
      ),
      labelLarge: style(14, FontWeight.w600, height: 1.2),
      labelMedium: style(12.5, FontWeight.w600, height: 1.2),
      labelSmall: style(11.5, FontWeight.w600, height: 1.2),
    );

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.md),
    );
    const controlSize = Size(44, 44);
    const controlPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 12);

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: font,
      fontFamilyFallback: fallback,
      textTheme: text,
      primaryTextTheme: text,
      scaffoldBackgroundColor: AppColors.paper,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.constantTurbulenceSeedSplashFactory,
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hoverColor: AppColors.paper,
        border: border(AppColors.line),
        enabledBorder: border(AppColors.line),
        focusedBorder: border(AppColors.primary, 1.6),
        errorBorder: border(AppColors.danger),
        focusedErrorBorder: border(AppColors.danger, 1.6),
        labelStyle: text.bodyMedium!.copyWith(color: AppColors.inkMuted),
        floatingLabelStyle: text.labelMedium!.copyWith(
          color: AppColors.inkMuted,
        ),
        hintStyle: text.bodyMedium!.copyWith(color: AppColors.inkMuted),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall!.copyWith(color: AppColors.danger),
        prefixIconColor: AppColors.inkMuted,
        suffixIconColor: AppColors.inkMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              minimumSize: controlSize,
              padding: controlPadding,
              shape: controlShape,
              textStyle: text.labelLarge,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.surfaceMuted,
              disabledForegroundColor: AppColors.inkMuted,
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.pressed)
                    ? Colors.black.withValues(alpha: 0.16)
                    : states.contains(WidgetState.hovered)
                    ? Colors.black.withValues(alpha: 0.08)
                    : null,
              ),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: controlSize,
          padding: controlPadding,
          shape: controlShape,
          textStyle: text.labelLarge,
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.line),
          backgroundColor: AppColors.surface,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: controlSize,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: controlShape,
          textStyle: text.labelLarge,
          foregroundColor: AppColors.ink,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: controlSize,
          shape: controlShape,
          foregroundColor: AppColors.ink,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(0, 44),
          textStyle: text.labelMedium,
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.ink,
          selectedBackgroundColor: AppColors.ink,
          selectedForegroundColor: Colors.white,
          side: const BorderSide(color: AppColors.line),
          shape: controlShape,
          visualDensity: VisualDensity.standard,
        ),
      ),
      chipTheme: ChipThemeData(
        labelStyle: text.labelMedium,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.ink,
        secondarySelectedColor: AppColors.ink,
        checkmarkColor: Colors.white,
        secondaryLabelStyle: text.labelMedium!.copyWith(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.ink
              : AppColors.surfaceMuted,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? AppColors.ink : AppColors.line,
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.inkMuted,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: text.bodyMedium!.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        width: 460,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        textStyle: text.labelMedium!.copyWith(color: Colors.white),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.md),
            ),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          AppColors.ink.withValues(alpha: 0.25),
        ),
        radius: const Radius.circular(Radii.pill),
      ),
    );
  }
}
