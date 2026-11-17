import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextField extends StatelessWidget {

  const CustomTextField({
    Key? key,
    this.controller,
    this.labelText,
    this.hintText,
    this.helperText,
    this.prefixText,
    this.suffixText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.isRequired = false,
    this.semanticLabel,
    this.onChanged,
    this.validator,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.inputFormatters,
    this.focusNode,
  }) : super(key: key);
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? prefixText;
  final String? suffixText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool isRequired;
  final String? semanticLabel;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final EdgeInsetsGeometry contentPadding;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;

  static List<TextInputFormatter>? _defaultFormatters(TextInputType type) {
    if (type == TextInputType.number) {
      return [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    }
    if (type == const TextInputType.numberWithOptions(decimal: true)) {
      return [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = labelText != null
        ? (isRequired ? '$labelText *' : labelText)
        : null;

    return Semantics(
      label: semanticLabel ?? (labelText != null ? (isRequired ? '$labelText, required' : labelText!) : hintText),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: obscureText,
        onChanged: onChanged,
        validator: validator,
        inputFormatters: inputFormatters ?? _defaultFormatters(keyboardType),
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          labelText: effectiveLabel,
          hintText: hintText,
          helperText: helperText,
          prefixText: prefixText,
          suffixText: suffixText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          contentPadding: contentPadding,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 1.5),
          ),
        ),
      ),
    );
  }
}
