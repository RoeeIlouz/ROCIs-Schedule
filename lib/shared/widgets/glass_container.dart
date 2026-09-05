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
    this.opacity = 0.92,
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

    // Build modern base surface with subtle, elegant ambient tint
    final Color baseSurface;
    if (isAmoled) {
      baseSurface = const Color(0xFF10131B);
    } else if (isDark) {
      baseSurface = const Color(0xFF1E293B);
    } else {
      baseSurface = Colors.white;
    }

    final Color tintedSurface = Color.lerp(
      baseSurface,
      effectiveTint,
      isDark ? 0.08 : 0.04,
    )!;

    final glassOpacity = isDark ? 0.72 : 0.78;
    final Color surfaceColor = useGlass
        ? tintedSurface.withValues(alpha: isSelected ? 0.92 : glassOpacity)
        : (isSelected
              ? Color.lerp(tintedSurface, theme.colorScheme.primary, 0.15)!
              : tintedSurface);

    final radius = borderRadius ?? BorderRadius.circular(20.0);

    // Modern crisp border
    final BoxBorder glassBorder =
        border ??
        Border.all(
          color: isSelected
              ? (selectedBorderColor ?? theme.colorScheme.primary)
              : (isAmoled
                    ? Colors.white12
                    : (isDark
                          ? effectiveTint.withValues(alpha: 0.22)
                          : effectiveTint.withValues(alpha: 0.14))),
          width: isSelected ? 2.0 : 1.0,
        );

    // Soft diffused modern shadow
    final double shadowElevation = elevation ?? 2.0;
    final List<BoxShadow>? shadow = shadowElevation > 0.0
        ? [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: isAmoled ? 0.5 : 0.25)
                  : effectiveTint.withValues(alpha: 0.05),
              blurRadius: shadowElevation * 3.0 + 4.0,
              spreadRadius: 0.0,
              offset: Offset(0, shadowElevation + 1.0),
            ),
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 3.0,
                spreadRadius: 0.0,
                offset: const Offset(0, 1),
              ),
          ]
        : null;

    final innerContainer = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: radius,
        border: glassBorder,
        boxShadow: shadow,
      ),
      child: child,
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
