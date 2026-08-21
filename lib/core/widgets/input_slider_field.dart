import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'custom_slider.dart';
import 'custom_text_field.dart';

class InputSliderField extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String? prefixText;
  final String? suffixText;
  final String? prefix;
  final String? suffix;
  final ValueChanged<double> onChanged;

  const InputSliderField({
    Key? key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.prefixText,
    this.suffixText,
    this.prefix,
    this.suffix,
  }) : super(key: key);

  @override
  State<InputSliderField> createState() => _InputSliderFieldState();
}

class _InputSliderFieldState extends State<InputSliderField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatValue(widget.value));
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant InputSliderField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (!_focusNode.hasFocus) {
        _controller.text = _formatValue(widget.value);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _formatValue(double value) {
    if (value == value.truncateToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  void _onTextChanged(String text) {
    final val = double.tryParse(text.replaceAll(',', ''));
    if (val != null && val >= widget.min && val <= widget.max) {
      widget.onChanged(val);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.label, style: Theme.of(context).textTheme.titleSmall),
            SizedBox(
              width: 120,
              child: CustomTextField(
                controller: _controller,
                focusNode: _focusNode,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                prefixText: widget.prefix ?? widget.prefixText,
                suffixText: widget.suffix ?? widget.suffixText,
                onChanged: _onTextChanged,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        CustomSlider(
          value: widget.value,
          min: widget.min,
          max: widget.max,
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}
