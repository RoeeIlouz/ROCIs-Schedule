import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

/// The direction a paragraph of user text reads in, taken from its first
/// letter with a direction (Hebrew/Arabic vs Latin and friends), so a Hebrew
/// sentence with English words in it stays right-to-left and vice versa.
/// Null when the text has no such letter (empty, digits, emoji).
TextDirection? textDirectionOf(String text) {
  if (intl.Bidi.startsWithRtl(text)) return TextDirection.rtl;
  if (intl.Bidi.startsWithLtr(text)) return TextDirection.ltr;
  return null;
}

/// [Text] for user-written content (titles, notes, places): reads in the
/// content's own direction but still lines up with the surrounding layout.
class BidiText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  const BidiText(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });

  @override
  Widget build(BuildContext context) {
    final layout = Directionality.of(context);
    return Text(
      data,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      textDirection: textDirectionOf(data) ?? layout,
      textAlign: layout == TextDirection.rtl ? TextAlign.right : TextAlign.left,
    );
  }
}

/// Rebuilds [builder] with the direction of [controller]'s text as the user
/// types, for text fields that take free text.
class BidiFieldBuilder extends StatelessWidget {
  final TextEditingController? controller;
  final Widget Function(BuildContext context, TextDirection direction) builder;

  const BidiFieldBuilder({
    super.key,
    required this.controller,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final layout = Directionality.of(context);
    final controller = this.controller;
    if (controller == null) return builder(context, layout);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) =>
          builder(context, textDirectionOf(value.text) ?? layout),
    );
  }
}
