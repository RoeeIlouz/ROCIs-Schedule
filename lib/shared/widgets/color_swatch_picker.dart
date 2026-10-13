import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/widgets/app_color_picker_sheet.dart';

/// A row of color swatches plus a "more colors" swatch that opens the full
/// picker (presets, sliders, hex). With [autoColor] set, a first swatch
/// stands for "no color of its own" (e.g. follow the course), reported as
/// null.
class ColorSwatchPicker extends StatelessWidget {
  final List<Color> presets;
  final Color? selected;
  final ValueChanged<Color?> onChanged;
  final String sheetTitle;
  final Color? autoColor;
  final String? autoLabel;

  const ColorSwatchPicker({
    super.key,
    required this.presets,
    required this.selected,
    required this.onChanged,
    required this.sheetTitle,
    this.autoColor,
    this.autoLabel,
  });

  bool _same(Color? a, Color? b) =>
      a != null && b != null && a.toARGB32() == b.toARGB32();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final selected = this.selected;
    final isCustom =
        selected != null && !presets.any((c) => _same(c, selected));

    Widget swatch({
      required Color? color,
      required bool isSelected,
      required String label,
      required VoidCallback onTap,
      IconData? icon,
    }) {
      final fill = color ?? theme.colorScheme.surfaceContainerHighest;
      final onFill = color == null
          ? theme.colorScheme.onSurfaceVariant
          : (ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
                ? Colors.white
                : Colors.black87);
      return Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: Tooltip(
          message: label,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: theme.colorScheme.onSurface, width: 2.5)
                    : (color == null
                          ? Border.all(color: theme.colorScheme.outlineVariant)
                          : null),
                boxShadow: color == null
                    ? null
                    : [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: isSelected && icon == null
                  ? Icon(Icons.check_rounded, size: 18, color: onFill)
                  : (icon == null ? null : Icon(icon, size: 16, color: onFill)),
            ),
          ),
        ),
      );
    }

    final colorLabel = l10n.translate('color');
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (autoColor != null)
          swatch(
            color: autoColor,
            isSelected: selected == null,
            label: autoLabel ?? colorLabel,
            icon: Icons.school_outlined,
            onTap: () => onChanged(null),
          ),
        for (final color in presets)
          swatch(
            color: color,
            isSelected: _same(color, selected),
            label: colorLabel,
            onTap: () => onChanged(color),
          ),
        swatch(
          color: isCustom ? selected : null,
          isSelected: isCustom,
          label: l10n.translate('more_colors'),
          icon: Icons.palette_outlined,
          onTap: () async {
            final initial = selected ?? autoColor ?? presets.first;
            final picked = await AppColorPickerSheet.show(
              context: context,
              title: sheetTitle,
              initialColor: initial,
            );
            if (picked != null && !_same(picked, initial)) onChanged(picked);
          },
        ),
      ],
    );
  }
}
