import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppDesignTokens extends ThemeExtension<AppDesignTokens> {
  final double glassBlur;
  final double glassOpacity;
  final Color glassBorderColor;
  final Color examUrgent;
  final Color examUpcoming;
  final BorderRadius cardRadius;

  const AppDesignTokens({
    required this.glassBlur,
    required this.glassOpacity,
    required this.glassBorderColor,
    required this.examUrgent,
    required this.examUpcoming,
    required this.cardRadius,
  });

  @override
  ThemeExtension<AppDesignTokens> copyWith({
    double? glassBlur,
    double? glassOpacity,
    Color? glassBorderColor,
    Color? examUrgent,
    Color? examUpcoming,
    BorderRadius? cardRadius,
  }) {
    return AppDesignTokens(
      glassBlur: glassBlur ?? this.glassBlur,
      glassOpacity: glassOpacity ?? this.glassOpacity,
      glassBorderColor: glassBorderColor ?? this.glassBorderColor,
      examUrgent: examUrgent ?? this.examUrgent,
      examUpcoming: examUpcoming ?? this.examUpcoming,
      cardRadius: cardRadius ?? this.cardRadius,
    );
  }

  @override
  ThemeExtension<AppDesignTokens> lerp(
    covariant ThemeExtension<AppDesignTokens>? other,
    double t,
  ) {
    if (other is! AppDesignTokens) return this;
    return AppDesignTokens(
      glassBlur: ui.lerpDouble(glassBlur, other.glassBlur, t) ?? glassBlur,
      glassOpacity:
          ui.lerpDouble(glassOpacity, other.glassOpacity, t) ?? glassOpacity,
      glassBorderColor:
          Color.lerp(glassBorderColor, other.glassBorderColor, t) ??
          glassBorderColor,
      examUrgent: Color.lerp(examUrgent, other.examUrgent, t) ?? examUrgent,
      examUpcoming:
          Color.lerp(examUpcoming, other.examUpcoming, t) ?? examUpcoming,
      cardRadius:
          BorderRadius.lerp(cardRadius, other.cardRadius, t) ?? cardRadius,
    );
  }
}

class AppTheme {
  // ROCI's Standard Color Tokens
  static const Color primaryIndigo = Color(0xFF6366F1);

  // Brand palette, taken from the app logo: an ocean-blue badge fading to
  // cyan, with a green "today" cell.
  static const Color brandOcean = Color(0xFF0E6FA8);
  static const Color brandTeal = Color(0xFF16B5C9);
  static const Color brandGreen = Color(0xFF3CC44A);

  /// Logo-matched scheme: ocean-blue primary (fidelity keeps the logo hue),
  /// cyan-teal secondary and the logo's green as tertiary.
  static ColorScheme brandScheme(Brightness brightness) {
    ColorScheme seeded(Color seed) => ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    final teal = seeded(brandTeal);
    final green = seeded(brandGreen);
    return seeded(brandOcean).copyWith(
      secondary: teal.primary,
      onSecondary: teal.onPrimary,
      secondaryContainer: teal.primaryContainer,
      onSecondaryContainer: teal.onPrimaryContainer,
      tertiary: green.primary,
      onTertiary: green.onPrimary,
      tertiaryContainer: green.primaryContainer,
      onTertiaryContainer: green.onPrimaryContainer,
    );
  }

  static const Color successEmerald = Color(0xFF10B981);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color dangerRed = Color(0xFFEF4444);

  // Surface Tokens (Preserved for backwards compatibility)
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF0F172A);

  static const Color slateDarkBg = Color(0xFF0F172A);
  static const Color slateDarkCard = Color(0xFF1E293B);
  static const Color textLight = Color(0xFFF8FAFC);

  /// Outfit has no Hebrew glyphs; Rubik (a close match with Hebrew support)
  /// renders them at the same weight instead of an unrelated system font.
  static List<String> _hebrewFallback([FontWeight? fontWeight]) => [
    GoogleFonts.rubik(fontWeight: fontWeight).fontFamily!,
  ];

  static TextStyle _outfit({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) => GoogleFonts.outfit(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
  ).copyWith(fontFamilyFallback: _hebrewFallback(fontWeight));

  // Typography Scale Generator using Outfit
  static TextTheme _buildTextTheme(
    Brightness brightness,
    Color textColor,
    Color variantColor,
  ) {
    final baseTheme = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;

    return GoogleFonts.outfitTextTheme(baseTheme)
        .apply(fontFamilyFallback: _hebrewFallback())
        .copyWith(
          displayLarge: _outfit(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            color: textColor,
          ),
          displayMedium: _outfit(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            color: textColor,
          ),
          headlineMedium: _outfit(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: textColor,
          ),
          headlineSmall: _outfit(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: textColor,
          ),
          titleLarge: _outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: textColor,
          ),
          titleMedium: _outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: textColor,
          ),
          titleSmall: _outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
            color: variantColor,
          ),
          bodyLarge: _outfit(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
            color: textColor,
          ),
          bodyMedium: _outfit(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
            color: textColor,
          ),
          bodySmall: _outfit(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.1,
            color: variantColor,
          ),
          labelLarge: _outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
            color: textColor,
          ),
          labelMedium: _outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: variantColor,
          ),
          labelSmall: _outfit(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: variantColor,
          ),
        );
  }

  static ThemeData lightTheme(ColorScheme? dynamicColorScheme) {
    final baseScheme = dynamicColorScheme ?? brandScheme(Brightness.light);

    // Harmonized surface tones derived from seed
    final colorScheme = baseScheme.copyWith(
      surface: baseScheme.surface,
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: Color.alphaBlend(
        baseScheme.primary.withValues(alpha: 0.02),
        const Color(0xFFF8FAFC),
      ),
      surfaceContainer: Color.alphaBlend(
        baseScheme.primary.withValues(alpha: 0.04),
        const Color(0xFFF1F5F9),
      ),
      surfaceContainerHigh: Color.alphaBlend(
        baseScheme.primary.withValues(alpha: 0.06),
        const Color(0xFFE2E8F0),
      ),
      surfaceContainerHighest: Color.alphaBlend(
        baseScheme.primary.withValues(alpha: 0.09),
        const Color(0xFFCBD5E1),
      ),
      onSurface: textDark,
      onSurfaceVariant: const Color(0xFF64748B),
      outline: Color.alphaBlend(
        baseScheme.primary.withValues(alpha: 0.08),
        const Color(0xFFCBD5E1),
      ),
      outlineVariant: Color.alphaBlend(
        baseScheme.primary.withValues(alpha: 0.05),
        const Color(0xFFE2E8F0),
      ),
    );

    final textTheme = _buildTextTheme(
      Brightness.light,
      colorScheme.onSurface,
      colorScheme.onSurfaceVariant,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
      scaffoldBackgroundColor: colorScheme.surfaceContainerLow,
      textTheme: textTheme,
      extensions: [
        AppDesignTokens(
          glassBlur: 12.0,
          glassOpacity: 0.16,
          glassBorderColor: colorScheme.outlineVariant.withValues(alpha: 0.4),
          examUrgent: colorScheme.error,
          examUpcoming: colorScheme.tertiary,
          cardRadius: BorderRadius.circular(20),
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: _outfit(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLowest,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          textStyle: _outfit(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: _outfit(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          side: BorderSide(color: colorScheme.outlineVariant, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: _outfit(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: _outfit(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 3,
        focusElevation: 4,
        hoverElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.15),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary, size: 24);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            );
          }
          return _outfit(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          );
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        selectedColor: colorScheme.primary.withValues(alpha: 0.14),
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: _outfit(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        secondaryLabelStyle: _outfit(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        checkmarkColor: colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: _outfit(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          fontSize: 14,
        ),
        labelStyle: _outfit(
          color: colorScheme.onSurfaceVariant,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: _outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        contentTextStyle: _outfit(
          fontSize: 14,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        modalBackgroundColor: colorScheme.surfaceContainerLowest,
        elevation: 8,
        showDragHandle: true,
        dragHandleColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: _outfit(
          color: colorScheme.onInverseSurface,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 24,
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        titleTextStyle: _outfit(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        subtitleTextStyle: _outfit(
          fontSize: 13,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surfaceContainerLowest,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        textStyle: _outfit(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return const Color(0xFF64748B);
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return colorScheme.outline.withValues(alpha: 0.6);
        }),
      ),
    );
  }

  static ThemeData darkTheme(
    ColorScheme? dynamicColorScheme, {
    bool isAmoled = false,
  }) {
    final baseScheme = dynamicColorScheme ?? brandScheme(Brightness.dark);

    final Color bgColor;
    final Color surfaceColor;
    final Color surfaceLow;
    final Color surfaceCont;
    final Color surfaceHigh;
    final Color surfaceHighest;
    final Color outlineColor;
    final Color outlineVariantColor;

    if (isAmoled) {
      bgColor = Colors.black;
      surfaceColor = const Color(0xFF0A0C12);
      surfaceLow = const Color(0xFF0E1118);
      surfaceCont = const Color(0xFF141822);
      surfaceHigh = const Color(0xFF1B202D);
      surfaceHighest = const Color(0xFF242B3C);
      outlineColor = Colors.white.withValues(alpha: 0.16);
      outlineVariantColor = Colors.white.withValues(alpha: 0.08);
    } else {
      // Premium neutral dark charcoal/zinc (eliminates blueish cast)
      bgColor = const Color(0xFF121316);
      surfaceColor = const Color(0xFF1B1C21);
      surfaceLow = const Color(0xFF16171B);
      surfaceCont = const Color(0xFF22242A);
      surfaceHigh = const Color(0xFF2B2D35);
      surfaceHighest = const Color(0xFF353842);
      outlineColor = const Color(0xFF717684);
      outlineVariantColor = const Color(0xFF2E313A);
    }

    final colorScheme = baseScheme.copyWith(
      surface: surfaceColor,
      surfaceContainerLowest: isAmoled ? Colors.black : const Color(0xFF0F1013),
      surfaceContainerLow: surfaceLow,
      surfaceContainer: surfaceCont,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: surfaceHighest,
      onSurface: textLight,
      onSurfaceVariant: const Color(0xFFA1A1AA),
      outline: outlineColor,
      outlineVariant: outlineVariantColor,
    );

    final textTheme = _buildTextTheme(
      Brightness.dark,
      colorScheme.onSurface,
      colorScheme.onSurfaceVariant,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgColor,
      textTheme: textTheme,
      extensions: [
        AppDesignTokens(
          glassBlur: 12.0,
          glassOpacity: isAmoled ? 0.22 : 0.18,
          glassBorderColor: outlineVariantColor,
          examUrgent: colorScheme.error,
          examUpcoming: colorScheme.tertiary,
          cardRadius: BorderRadius.circular(20),
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: _outfit(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: isAmoled ? 0.6 : 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: outlineVariantColor, width: 1.0),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          // Fixed contrast bug: use onPrimary instead of hardcoded dark #0F172A
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          textStyle: _outfit(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: _outfit(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          side: BorderSide(color: outlineColor, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: _outfit(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: _outfit(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        // Fixed contrast bug: use onPrimary instead of hardcoded dark #0F172A
        foregroundColor: colorScheme.onPrimary,
        elevation: 3,
        focusElevation: 4,
        hoverElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.22),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary, size: 24);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            );
          }
          return _outfit(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          );
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceCont,
        selectedColor: colorScheme.primary.withValues(alpha: 0.25),
        side: BorderSide(color: outlineVariantColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: _outfit(
          color: textLight,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        secondaryLabelStyle: _outfit(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        checkmarkColor: colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: _outfit(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          fontSize: 14,
        ),
        labelStyle: _outfit(
          color: colorScheme.onSurfaceVariant,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outlineColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outlineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceCont,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: _outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        contentTextStyle: _outfit(
          fontSize: 14,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceCont,
        modalBackgroundColor: surfaceCont,
        elevation: 8,
        showDragHandle: true,
        dragHandleColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.surfaceContainerHigh,
        contentTextStyle: _outfit(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 24,
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        titleTextStyle: _outfit(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        subtitleTextStyle: _outfit(
          fontSize: 13,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceCont,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: outlineVariantColor),
        ),
        textStyle: _outfit(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: outlineVariantColor,
        thickness: 1,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return const Color(0xFFE2E8F0);
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return isAmoled ? const Color(0xFF242B3C) : surfaceHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return outlineColor.withValues(alpha: 0.6);
        }),
      ),
    );
  }
}
