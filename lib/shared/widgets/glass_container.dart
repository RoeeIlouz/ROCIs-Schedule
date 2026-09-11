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
    this.blur = 10.0,
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

    // Ambient surface base matching AMOLED or standard Material 3
    final Color baseSurface = isAmoled
        ? const Color(0xFF0B0D13)
        : (isDark
            ? theme.colorScheme.surface
            : Colors.white);

    // 12-18% subtle tint of the course/category color into the frosted backdrop
    final glassColor = Color.lerp(baseSurface, effectiveTint, isDark ? 0.18 : 0.12)!;

    final radius = borderRadius ?? BorderRadius.circular(20.0);

    // Default border if not provided, subtly tinted with the course/event color
    final borderTint = tintColor ?? color ?? theme.colorScheme.primary;
    final BoxBorder glassBorder =
        border ??
        Border.all(
          color: isSelected
              ? (selectedBorderColor ?? theme.colorScheme.primary)
              : (isAmoled
                    ? borderTint.withValues(alpha: useGlass ? 0.15 : 0.22)
                    : (isDark
                          ? borderTint.withValues(alpha: useGlass ? 0.14 : 0.20)
                          : borderTint.withValues(alpha: useGlass ? 0.08 : 0.14))),
          width: isSelected ? 1.5 : 1.0,
        );

    final double shadowElevation = elevation ?? (useGlass ? 0.0 : 2.0);
    final List<BoxShadow>? shadow = (!useGlass && shadowElevation > 0.0)
        ? [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDark ? (isAmoled ? 0.4 : 0.25) : 0.05,
              ),
              blurRadius: shadowElevation * 2.0 + 2.0,
              spreadRadius: 0.0,
              offset: Offset(0, shadowElevation),
            ),
          ]
        : null;

    final innerContainer = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: useGlass
            ? glassColor.withValues(
                alpha: isSelected ? (opacity + 0.1).clamp(0.0, 1.0) : opacity,
              )
            : (isSelected
                  ? (color?.withValues(alpha: 0.2) ??
                        (tintColor?.withValues(alpha: 0.2) ??
                            theme.colorScheme.primary.withValues(alpha: 0.12)))
                  : (color ?? theme.colorScheme.surfaceContainerLow)),
        borderRadius: radius,
        border: glassBorder,
        boxShadow: shadow,
      ),
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
