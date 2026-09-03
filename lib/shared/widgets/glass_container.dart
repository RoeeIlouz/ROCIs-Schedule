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
    this.opacity = 0.15,
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
    final useGlass = themeProvider.useGlassmorphism && !kIsWeb;

    // Default glass color adapts to theme if not provided, with a beautiful primary/course tint
    final effectiveTint = tintColor ?? color ?? theme.colorScheme.primary;
    final baseColor = isDark
        ? (themeProvider.isAmoled ? Colors.black : const Color(0xFF151824))
        : (themeProvider.useDynamicColor ? theme.colorScheme.surface : Colors.white);
    final glassColor = Color.lerp(baseColor, effectiveTint, isDark ? 0.18 : 0.12)!;

    final radius = borderRadius ?? BorderRadius.circular(20.0);

    // Default border subtly tinted with primary/course color
    final borderTint = effectiveTint;
    final glassBorder = border ?? Border.all(
      color: isSelected
          ? (selectedBorderColor ?? theme.colorScheme.primary)
          : (isDark
              ? borderTint.withValues(alpha: 0.18)
              : borderTint.withValues(alpha: 0.12)),
      width: isSelected ? 2.0 : 1.0,
    );

    final double shadowElevation = elevation ?? (useGlass ? 0.0 : 2.0);
    final List<BoxShadow>? shadow = (!useGlass && shadowElevation > 0.0)
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
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
            ? glassColor.withValues(alpha: isSelected ? opacity + 0.1 : opacity)
            : (isSelected
                ? (color?.withValues(alpha: 0.2) ?? theme.colorScheme.primaryContainer)
                : (color != null ? color!.withValues(alpha: isDark ? 0.15 : 0.1) : theme.colorScheme.surfaceContainerLow)),
        borderRadius: radius,
        border: useGlass ? glassBorder : (isSelected ? glassBorder : Border.all(color: isDark ? Colors.white10 : Colors.black12)),
        boxShadow: shadow,
      ),
      child: child,
    );

    if (!useGlass) {
      return Container(
        margin: margin,
        child: innerContainer,
      );
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
