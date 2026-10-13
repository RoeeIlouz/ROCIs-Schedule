import 'package:flutter/material.dart';
import 'package:rocis_schedule/shared/utils/bidi.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final int maxLines;
  final FocusNode? focusNode;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.prefixIcon,
    this.maxLines = 1,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        // Free text follows its own direction, so Hebrew typed into an
        // English UI (or English into a Hebrew one) reads correctly.
        BidiFieldBuilder(
          controller: isPassword ? null : controller,
          builder: (context, direction) => TextFormField(
            controller: controller,
            focusNode: focusNode,
            obscureText: isPassword,
            keyboardType: keyboardType,
            validator: validator,
            maxLines: maxLines,
            textDirection: direction,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
            ),
          ),
        ),
      ],
    );
  }
}
