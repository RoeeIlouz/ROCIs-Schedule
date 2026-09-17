import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BoxBorder? border;
  final Color? color;
  final Color? tintColor;
  final bool isSelected;
  final Color? selectedBorderColor;
  final double? elevation;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 12.0,
    this.opacity = 0.18,
    this.borderRadius,
    this.padding,
    this.margin,
    this.border,
    this.color,
    this.tintColor,
    this.isSelected = false,
    this.selectedBorderColor,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = theme.brightness == Brightness.dark;
    final isAmoled = themeProvider.isAmoled && isDark;
    final useGlass = themeProvider.useGlassmorphism && !kIsWeb;

    final effectiveTint = tintColor ?? color ?? theme.colorScheme.primary;

    // Ambient surface base matching AMOLED, dark zinc, or clean light card
    final Color baseSurface = isAmoled
        ? const Color(0xFF000000)
        : (isDark
              ? (kIsWeb
                    ? const Color(0xFF18181B)
                    : theme.colorScheme.surfaceContainer)
              : Colors.white);

    final radius = borderRadius ?? BorderRadius.circular(16.0);

    // Dynamic hairline border with high contrast on web/desktop
    final BoxBorder glassBorder =
        border ??
        Border.all(
          color: isSelected
              ? (selectedBorderColor ?? theme.colorScheme.primary)
              : (isAmoled
                    ? const Color(0xFF27272A)
                    : (isDark
                          ? (kIsWeb
                                ? const Color(0xFF27272A)
                                : effectiveTint.withValues(
                                    alpha: useGlass ? 0.24 : 0.18,
                                  ))
                          : (kIsWeb
                                ? const Color(0xFFE4E4E7)
                                : effectiveTint.withValues(
                                    alpha: useGlass ? 0.18 : 0.14,
                                  )))),
          width: isSelected ? 1.5 : 1.0,
        );

    final double shadowElevation =
        elevation ?? (useGlass ? 0.0 : (kIsWeb ? 1.0 : 2.0));
    final List<BoxShadow>? shadow = shadowElevation > 0.0
        ? [
            BoxShadow(
              color: isDark
                  ? (isAmoled
                        ? Colors.black.withValues(alpha: 0.6)
                        : Colors.black.withValues(alpha: 0.35))
                  : (kIsWeb
                        ? const Color(0x0A000000)
                        : effectiveTint.withValues(alpha: 0.06)),
              blurRadius: shadowElevation * 3.0 + 4.0,
              spreadRadius: 0.0,
              offset: Offset(0, shadowElevation * 1.5),
            ),
          ]
        : null;

    final double effectiveOpacity = isSelected
        ? (opacity + 0.08).clamp(0.0, 1.0)
        : opacity;

    // High-fidelity gradient for frosted glass simulating top specular lighting
    final Decoration containerDecoration = useGlass
        ? BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(
                  baseSurface,
                  effectiveTint,
                  isDark ? 0.22 : 0.14,
                )!.withValues(alpha: effectiveOpacity + 0.05),
                Color.lerp(
                  baseSurface,
                  effectiveTint,
                  isDark ? 0.15 : 0.08,
                )!.withValues(alpha: effectiveOpacity),
              ],
            ),
            borderRadius: radius,
            border: glassBorder,
            boxShadow: shadow,
          )
        : BoxDecoration(
            color: isSelected
                ? Color.alphaBlend(
                    effectiveTint.withValues(alpha: 0.14),
                    baseSurface,
                  )
                : (color ??
                      (kIsWeb
                          ? baseSurface
                          : Color.alphaBlend(
                              effectiveTint.withValues(
                                alpha: isDark ? 0.07 : 0.04,
                              ),
                              theme.colorScheme.surfaceContainerLow,
                            ))),
            borderRadius: radius,
            border: glassBorder,
            boxShadow: shadow,
          );

    final innerContainer = Container(
      padding: padding,
      decoration: containerDecoration,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );

    if (!useGlass) {
      return Container(margin: margin, child: innerContainer);
    }

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: innerContainer,
        ),
      ),
    );
  }
}
